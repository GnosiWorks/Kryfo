// SPDX-License-Identifier: GPL-3.0-or-later
// voice notes on linux. just_audio has no linux side; gstreamer is on every
// linux desktop that plays sound, so a playbin per player plays the file,
// driven over ffi. nothing is written anywhere: the file is read in place
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// one player's pipeline, behind a seam for the tests
abstract class AudioPipe {
  /// the file set and ready to play: its length, null when it would not load
  Future<Duration?> load(String path);
  void play();
  void pause();
  void seek(Duration to);
  void volume(double v);
  Duration position();

  /// true once the end was reached since the last ask
  bool ended();

  /// a message the pipeline gave up with since the last ask
  String? failed();
  void dispose();
}

// gstreamer's numbers
const _stateNull = 1;
const _statePaused = 3;
const _statePlaying = 4;
const _formatTime = 3;
const _seekFlush = 1;
const _seekAccurate = 2;
const _msgEos = 1;
const _msgError = 2;
const _changeFailure = 0;
const _changeSuccess = 1;

typedef _InitC = Void Function(Pointer<Void>, Pointer<Void>);
typedef _Init = void Function(Pointer<Void>, Pointer<Void>);
typedef _MakeC = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _SetStateC = Int32 Function(Pointer<Void>, Int32);
typedef _SetState = int Function(Pointer<Void>, int);
typedef _GetStateC =
    Int32 Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>, Uint64);
typedef _GetState =
    int Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>, int);
typedef _QueryC = Int32 Function(Pointer<Void>, Int32, Pointer<Int64>);
typedef _Query = int Function(Pointer<Void>, int, Pointer<Int64>);
typedef _SeekC = Int32 Function(Pointer<Void>, Int32, Int32, Int64);
typedef _Seek = int Function(Pointer<Void>, int, int, int);
typedef _PtrC = Pointer<Void> Function(Pointer<Void>);
typedef _UnrefC = Void Function(Pointer<Void>);
typedef _Unref = void Function(Pointer<Void>);
typedef _PopC = Pointer<Void> Function(Pointer<Void>, Uint32);
typedef _Pop = Pointer<Void> Function(Pointer<Void>, int);
typedef _SetStrC =
    Void Function(
      Pointer<Void>,
      Pointer<Utf8>,
      VarArgs<(Pointer<Utf8>, Pointer<Void>)>,
    );
typedef _SetStr =
    void Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>);
typedef _SetDblC =
    Void Function(
      Pointer<Void>,
      Pointer<Utf8>,
      VarArgs<(Double, Pointer<Void>)>,
    );
typedef _SetDbl =
    void Function(Pointer<Void>, Pointer<Utf8>, double, Pointer<Void>);

/// libgstreamer, loaded once. null when the system has none
class Gst {
  Gst._(DynamicLibrary l)
    : _make = l.lookupFunction<_MakeC, _MakeC>('gst_element_factory_make'),
      _setState = l.lookupFunction<_SetStateC, _SetState>(
        'gst_element_set_state',
      ),
      _getState = l.lookupFunction<_GetStateC, _GetState>(
        'gst_element_get_state',
      ),
      _queryPosition = l.lookupFunction<_QueryC, _Query>(
        'gst_element_query_position',
      ),
      _queryDuration = l.lookupFunction<_QueryC, _Query>(
        'gst_element_query_duration',
      ),
      _seek = l.lookupFunction<_SeekC, _Seek>('gst_element_seek_simple'),
      _bus = l.lookupFunction<_PtrC, _PtrC>('gst_element_get_bus'),
      _pop = l.lookupFunction<_PopC, _Pop>('gst_bus_pop_filtered'),
      _unref = l.lookupFunction<_UnrefC, _Unref>('gst_object_unref'),
      _unrefMessage = l.lookupFunction<_UnrefC, _Unref>(
        'gst_mini_object_unref',
      ),
      _setString = l.lookupFunction<_SetStrC, _SetStr>('g_object_set'),
      _setDouble = l.lookupFunction<_SetDblC, _SetDbl>('g_object_set') {
    l.lookupFunction<_InitC, _Init>('gst_init')(nullptr, nullptr);
  }

  final Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>) _make;
  final _SetState _setState;
  final _GetState _getState;
  final _Query _queryPosition;
  final _Query _queryDuration;
  final _Seek _seek;
  final Pointer<Void> Function(Pointer<Void>) _bus;
  final _Pop _pop;
  final _Unref _unref;
  final _Unref _unrefMessage;
  final _SetStr _setString;
  final _SetDbl _setDouble;

  static Gst? _one;
  static bool _tried = false;

  static Gst? get instance {
    if (_tried) return _one;
    _tried = true;
    try {
      _one = Gst._(DynamicLibrary.open('libgstreamer-1.0.so.0'));
    } catch (_) {
      _one = null;
    }
    return _one;
  }

  /// true when a message of [type] waited on [busPtr]; it is dropped
  bool took(Pointer<Void> busPtr, int type) {
    final m = _pop(busPtr, type);
    if (m == nullptr) return false;
    _unrefMessage(m);
    return true;
  }
}

/// a gstreamer playbin
class GstPipe implements AudioPipe {
  GstPipe(this._gst, {String element = 'playbin'}) {
    final name = element.toNativeUtf8();
    try {
      _el = _gst._make(name, nullptr);
    } finally {
      calloc.free(name);
    }
    if (_el == nullptr) throw StateError('no $element in gstreamer');
    _bus = _gst._bus(_el);
  }

  final Gst _gst;
  late final Pointer<Void> _el;
  late final Pointer<Void> _bus;
  String? _failed;
  bool _gone = false;

  void _set(String prop, String value) {
    final k = prop.toNativeUtf8(), v = value.toNativeUtf8();
    try {
      _gst._setString(_el, k, v, nullptr);
    } finally {
      calloc.free(k);
      calloc.free(v);
    }
  }

  int? _query(bool duration) {
    final out = calloc<Int64>();
    try {
      final ok = duration
          ? _gst._queryDuration(_el, _formatTime, out)
          : _gst._queryPosition(_el, _formatTime, out);
      return ok != 0 && out.value >= 0 ? out.value : null;
    } finally {
      calloc.free(out);
    }
  }

  @override
  Future<Duration?> load(String path) async {
    _gst._setState(_el, _stateNull);
    _set('uri', Uri.file(path).toString());
    if (_gst._setState(_el, _statePaused) == _changeFailure) return null;
    final st = calloc<Int32>(), pend = calloc<Int32>();
    try {
      // preroll runs on gstreamer's threads: asked without waiting until it
      // has a word, never holding a frame
      for (var i = 0; i < 250; i++) {
        final r = _gst._getState(_el, st, pend, 0);
        if (r == _changeFailure || _gst.took(_bus, _msgError)) return null;
        if (r == _changeSuccess && st.value == _statePaused) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      if (st.value != _statePaused) return null;
    } finally {
      calloc.free(st);
      calloc.free(pend);
    }
    final d = _query(true);
    return d == null ? null : Duration(microseconds: d ~/ 1000);
  }

  @override
  void play() => _gst._setState(_el, _statePlaying);

  @override
  void pause() => _gst._setState(_el, _statePaused);

  @override
  void seek(Duration to) => _gst._seek(
    _el,
    _formatTime,
    _seekFlush | _seekAccurate,
    to.inMicroseconds * 1000,
  );

  @override
  void volume(double v) {
    final k = 'volume'.toNativeUtf8();
    try {
      _gst._setDouble(_el, k, v.clamp(0, 1).toDouble(), nullptr);
    } finally {
      calloc.free(k);
    }
  }

  @override
  Duration position() => Duration(microseconds: (_query(false) ?? 0) ~/ 1000);

  @override
  bool ended() => _gst.took(_bus, _msgEos);

  @override
  String? failed() {
    if (_gst.took(_bus, _msgError)) _failed = 'playback failed';
    final f = _failed;
    _failed = null;
    return f;
  }

  @override
  void dispose() {
    if (_gone) return;
    _gone = true;
    _gst._setState(_el, _stateNull);
    _gst._unref(_bus);
    _gst._unref(_el);
  }
}

/// just_audio's player over one pipe
class DesktopPlayer extends AudioPlayerPlatform {
  DesktopPlayer(super.id, this._pipe, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AudioPipe _pipe;
  final DateTime Function() _clock;
  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final _data = StreamController<PlayerDataMessage>.broadcast();
  var _state = ProcessingStateMessage.idle;
  Duration? _duration;
  bool _playing = false;
  Timer? _watch;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => _data.stream;

  void _say([Duration? at, String? error]) {
    if (_events.isClosed) return;
    _events.add(
      PlaybackEventMessage(
        processingState: _state,
        updateTime: _clock(),
        updatePosition: at ?? _pipe.position(),
        bufferedPosition: _duration ?? Duration.zero,
        duration: _duration,
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
        errorCode: error == null ? null : 1,
        errorMessage: error,
      ),
    );
  }

  // the end and a failure come on gstreamer's bus, looked at while playing
  @visibleForTesting
  void look() {
    final f = _pipe.failed();
    if (f != null) {
      _stopWatch();
      // just_audio reads a failure from the event, as its error stream
      _state = ProcessingStateMessage.idle;
      _say(Duration.zero, f);
      return;
    }
    if (_pipe.ended()) {
      _stopWatch();
      _state = ProcessingStateMessage.completed;
      _say(_duration);
    }
  }

  void _stopWatch() {
    _watch?.cancel();
    _watch = null;
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    var src = request.audioSourceMessage;
    // just_audio hands a single file in as a list of one
    while (src is ConcatenatingAudioSourceMessage && src.children.isNotEmpty) {
      src =
          src.children[(request.initialIndex ?? 0).clamp(
            0,
            src.children.length - 1,
          )];
    }
    if (src is! UriAudioSourceMessage) {
      throw UnsupportedError('only files play here');
    }
    final uri = Uri.parse(src.uri);
    if (uri.scheme != 'file') throw UnsupportedError('only files play here');
    _state = ProcessingStateMessage.loading;
    _say(Duration.zero);
    final d = await _pipe.load(uri.toFilePath());
    if (d == null) {
      _state = ProcessingStateMessage.idle;
      _say(Duration.zero);
      throw StateError('this file does not play here');
    }
    _duration = d;
    final at = request.initialPosition;
    if (at != null && at > Duration.zero) _pipe.seek(at);
    _state = ProcessingStateMessage.ready;
    _say(at ?? Duration.zero);
    if (_playing) _start();
    return LoadResponse(duration: d);
  }

  void _start() {
    _pipe.play();
    _watch ??= Timer.periodic(const Duration(milliseconds: 100), (_) => look());
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _playing = true;
    _data.add(PlayerDataMessage(playing: true));
    if (_state == ProcessingStateMessage.ready) _start();
    _say();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _playing = false;
    _stopWatch();
    _pipe.pause();
    _data.add(PlayerDataMessage(playing: false));
    _say();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    final to = request.position ?? Duration.zero;
    _pipe.seek(to);
    if (_state == ProcessingStateMessage.completed) {
      _state = ProcessingStateMessage.ready;
      if (_playing) _start();
    }
    _say(to);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    _pipe.volume(request.volume);
    _data.add(PlayerDataMessage(volume: request.volume));
    return SetVolumeResponse();
  }

  // voice notes play at their own speed here
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    _stopWatch();
    _pipe.dispose();
    await _events.close();
    await _data.close();
    return DisposeResponse();
  }
}

/// just_audio's linux side
class DesktopAudio extends JustAudioPlatform {
  DesktopAudio({AudioPipe Function()? pipe}) : _pipe = pipe ?? _gstPipe;

  final AudioPipe Function() _pipe;
  final _players = <String, DesktopPlayer>{};

  static AudioPipe _gstPipe() {
    final g = Gst.instance;
    if (g == null || !Platform.isLinux) {
      throw StateError('no gstreamer here');
    }
    return GstPipe(g);
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      _players[request.id] = DesktopPlayer(request.id, _pipe());

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    await _players.remove(request.id)?.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    for (final p in _players.values.toList()) {
      await p.dispose(DisposeRequest());
    }
    _players.clear();
    return DisposeAllPlayersResponse();
  }
}
