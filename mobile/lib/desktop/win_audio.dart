// SPDX-License-Identifier: GPL-3.0-or-later
// voice notes on windows: the runner's wasapi calls (kryfo_audio.cpp) over
// ffi. the mic hands 16-bit pcm into a buffer of ours, which is zeroed once
// it is written; a note plays from pcm copied to the runner, which zeroes
// its copy when the note goes. the sniff and the fixed decode are linux's:
// ogg opus through the engine's own decoder, wav as 16-bit pcm, nothing else
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import '../dlog.dart';
import '../voice_mask.dart' show wavPcmAt;
import '../voice_opus.dart' show wavBytesOfOgg;
import 'desktop_audio.dart';
import 'desktop_run.dart' show runChannel;

/// what opening the mic or the speakers says
enum AudioWord { ok, blocked, none, failed }

AudioWord audioWordOf(int w) => switch (w) {
  0 => AudioWord.ok,
  1 => AudioWord.blocked,
  2 => AudioWord.none,
  _ => AudioWord.failed,
};

/// the mic as the recorder takes it, a seam for the tests
abstract class MicSource {
  /// whether the mic opens now, without recording
  AudioWord probe();
  AudioWord open(int rate, int channels);

  /// up to [cap] bytes of pcm into [into]; -1 once the device is gone
  int take(Pointer<Uint8> into, int cap);
  void close();
}

/// the speakers for one note, a seam for the tests
abstract class PcmOut {
  /// [n] bytes of 16-bit pcm at [data], copied by the callee
  AudioWord load(Pointer<Uint8> data, int n, int rate, int channels);
  void play(bool on);
  void seek(Duration to);
  void volume(double v);
  Duration position();

  /// 1 the end was reached, 2 the device failed, since the last ask
  int state();
  void dispose();
}

typedef _I32V = Int32 Function();
typedef _I32I32I32 = Int32 Function(Int32, Int32);
typedef _TakeC = Int32 Function(Pointer<Uint8>, Int32);
typedef _VV = Void Function();
typedef _I64V = Int64 Function();
typedef _LoadC = Int32 Function(Int64, Pointer<Uint8>, Int64, Int32, Int32);
typedef _LoadD = int Function(int, Pointer<Uint8>, int, int, int);
typedef _OnC = Void Function(Int64, Int32);
typedef _OnD = void Function(int, int);
typedef _SeekC = Void Function(Int64, Int64);
typedef _VolC = Void Function(Int64, Double);
typedef _VolD = void Function(int, double);
typedef _AtC = Int64 Function(Int64);
typedef _AtD = int Function(int);
typedef _StateC = Int32 Function(Int64);
typedef _FreeC = Void Function(Int64);
typedef _FreeD = void Function(int);

/// the runner's calls, by the addresses its channel gives
class WinAudioCalls {
  WinAudioCalls._(List<int> a)
    : _probe = Pointer<NativeFunction<_I32V>>.fromAddress(
        a[0],
      ).asFunction<int Function()>(),
      _open = Pointer<NativeFunction<_I32I32I32>>.fromAddress(
        a[1],
      ).asFunction<int Function(int, int)>(),
      _take = Pointer<NativeFunction<_TakeC>>.fromAddress(
        a[2],
      ).asFunction<int Function(Pointer<Uint8>, int)>(),
      _close = Pointer<NativeFunction<_VV>>.fromAddress(
        a[3],
      ).asFunction<void Function()>(),
      _new = Pointer<NativeFunction<_I64V>>.fromAddress(
        a[4],
      ).asFunction<int Function()>(),
      _load = Pointer<NativeFunction<_LoadC>>.fromAddress(
        a[5],
      ).asFunction<_LoadD>(),
      _on = Pointer<NativeFunction<_OnC>>.fromAddress(a[6]).asFunction<_OnD>(),
      _seek = Pointer<NativeFunction<_SeekC>>.fromAddress(
        a[7],
      ).asFunction<_OnD>(),
      _vol = Pointer<NativeFunction<_VolC>>.fromAddress(
        a[8],
      ).asFunction<_VolD>(),
      _at = Pointer<NativeFunction<_AtC>>.fromAddress(a[9]).asFunction<_AtD>(),
      _state = Pointer<NativeFunction<_StateC>>.fromAddress(
        a[10],
      ).asFunction<_AtD>(),
      _free = Pointer<NativeFunction<_FreeC>>.fromAddress(
        a[11],
      ).asFunction<_FreeD>();

  static const _count = 12;

  final int Function() _probe;
  final int Function(int, int) _open;
  final int Function(Pointer<Uint8>, int) _take;
  final void Function() _close;
  final int Function() _new;
  final _LoadD _load;
  final _OnD _on;
  final _OnD _seek;
  final _VolD _vol;
  final _AtD _at;
  final _AtD _state;
  final _FreeD _free;

  /// null off windows, or when the runner has no audio calls
  static Future<WinAudioCalls?> fetch({
    MethodChannel channel = runChannel,
  }) async {
    if (!Platform.isWindows) return null;
    try {
      final a = await channel.invokeMethod<List<Object?>>('audio');
      if (a == null || a.length != _count) return null;
      final at = a.whereType<int>().toList();
      if (at.length != _count || at.any((v) => v == 0)) return null;
      return WinAudioCalls._(at);
    } catch (e) {
      dlog('voice: no audio calls (${e.runtimeType})');
      return null;
    }
  }

  MicSource get mic => _WinMic(this);
  PcmOut speaker() => _WinOut(this, _new());
}

class _WinMic implements MicSource {
  _WinMic(this._c);
  final WinAudioCalls _c;
  @override
  AudioWord probe() => audioWordOf(_c._probe());
  @override
  AudioWord open(int rate, int channels) =>
      audioWordOf(_c._open(rate, channels));
  @override
  int take(Pointer<Uint8> into, int cap) => _c._take(into, cap);
  @override
  void close() => _c._close();
}

class _WinOut implements PcmOut {
  _WinOut(this._c, this._h);
  final WinAudioCalls _c;
  int _h;
  @override
  AudioWord load(Pointer<Uint8> data, int n, int rate, int channels) => _h == 0
      ? AudioWord.failed
      : audioWordOf(_c._load(_h, data, n, rate, channels));
  @override
  void play(bool on) => _h == 0 ? null : _c._on(_h, on ? 1 : 0);
  @override
  void seek(Duration to) => _h == 0 ? null : _c._seek(_h, to.inMilliseconds);
  @override
  void volume(double v) => _h == 0 ? null : _c._vol(_h, v);
  @override
  Duration position() =>
      _h == 0 ? Duration.zero : Duration(milliseconds: _c._at(_h));
  @override
  int state() => _h == 0 ? 0 : _c._state(_h);
  @override
  void dispose() {
    if (_h == 0) return;
    _c._free(_h);
    _h = 0;
  }
}

/// the pcm of a voice note's bytes: (start, length, channels, rate) of its
/// samples in [wav], or null when it is not one this plays
(int, int, int, int)? notePcm(Uint8List wav) {
  final p = wavPcmAt(wav);
  if (p == null) return null;
  final (_, len, channels, rate) = p;
  if (channels > 2 || rate > 48000 || len <= 0) return null;
  return p;
}

/// one note through the runner's speakers. the file is read through the
/// seal; its plaintext, and the pcm made of it, are zeroed once the runner
/// has its copy
class WasapiPipe implements AudioPipe {
  WasapiPipe(this._out, {Future<Uint8List?> Function(Uint8List ogg)? decode})
    : _decode = decode ?? wavBytesOfOgg;

  final PcmOut _out;
  final Future<Uint8List?> Function(Uint8List ogg) _decode;
  double _volume = 1;
  bool _gone = false;
  String? _failed;

  @override
  Future<Duration?> load(String path) async {
    if (_gone) return null;
    Uint8List? file, wav;
    try {
      file = await File(path).readAsBytes();
      final kind = voiceKindOf(file.length < 12 ? file : file.sublist(0, 12));
      if (kind == null) return null;
      wav = kind == VoiceKind.wav ? file : await _decode(file);
      if (wav == null) return null;
      final pcm = notePcm(wav);
      if (pcm == null) return null;
      final (start, len, channels, rate) = pcm;
      final word = _withC(
        wav,
        start,
        len,
        (p) => _out.load(p, len, rate, channels),
      );
      if (word != AudioWord.ok) {
        dlog('voice: speakers did not open (${word.name})');
        return null;
      }
      _out.volume(_volume);
      return Duration(microseconds: len ~/ (2 * channels) * 1000000 ~/ rate);
    } catch (e) {
      dlog('voice: did not load (${e.runtimeType})');
      return null;
    } finally {
      file?.fillRange(0, file.length, 0);
      if (!identical(wav, file)) wav?.fillRange(0, wav.length, 0);
    }
  }

  @override
  void play() => _out.play(true);

  @override
  void pause() => _out.play(false);

  @override
  void seek(Duration to) => _out.seek(to);

  @override
  void volume(double v) {
    _volume = v.clamp(0, 1).toDouble();
    _out.volume(_volume);
  }

  @override
  Duration position() => _out.position();

  int _pending = 0;
  int _ask() => _pending |= _out.state();

  @override
  bool ended() {
    final s = _ask();
    _pending &= ~1;
    return s & 1 != 0;
  }

  @override
  String? failed() {
    final s = _ask();
    _pending &= ~2;
    if (s & 2 != 0) _failed = 'playback failed';
    final f = _failed;
    _failed = null;
    return f;
  }

  @override
  void dispose() {
    if (_gone) return;
    _gone = true;
    _out.dispose();
  }
}

// [n] bytes of [b] from [start] in C memory for [call], zeroed after
T _withC<T>(Uint8List b, int start, int n, T Function(Pointer<Uint8>) call) {
  final p = calloc.allocate<Uint8>(n < 1 ? 1 : n);
  final view = p.asTypedList(n);
  try {
    view.setRange(0, n, b, start);
    return call(p);
  } finally {
    view.fillRange(0, n, 0);
    calloc.free(p);
  }
}
