// SPDX-License-Identifier: GPL-3.0-or-later
// the one player for sound files: the bubble's play mark and the full
// player drive the same one, so a song goes on when the player closes. one
// sound at a time, voice notes included (VoiceTurn). the file is read
// through the seal into memory (plainViewOf), held so it is not shredded
// under the player, and the lock stops it and lets it go
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'dlog.dart';
import 'lock_guard.dart' show LockGuard, lockGuard;
import 'phone_seal.dart' show PlainView, plainViewOf;
import 'widgets/voice_parts.dart' show VoiceTurn, holdVoiceFile, letVoiceFileGo;

/// one sound to play: a file, who sent it and when
class SoundItem {
  final String path;
  final String? name;
  final String? from;
  final DateTime? when;
  // a voice note: no name of its own
  final bool voice;
  // the other side's, in a chat that blocks screenshots: it goes to no
  // other app, is not saved and not forwarded
  final bool kept;
  const SoundItem(
    this.path, {
    this.name,
    this.from,
    this.when,
    this.voice = false,
    this.kept = false,
  });

  @override
  bool operator ==(Object other) => other is SoundItem && other.path == path;
  @override
  int get hashCode => path.hashCode;
}

/// what plays the sound: just_audio on a phone, a stand-in in tests
abstract class SoundEngine {
  Future<Duration?> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration to);
  Future<void> setSpeed(double s);
  Stream<Duration> get positions;
  Stream<bool> get playings;
  Stream<void> get ends;
  Future<void> dispose();
}

class _JustAudio implements SoundEngine {
  final _p = AudioPlayer();
  @override
  Future<Duration?> load(String path) => _p.setFilePath(path);
  @override
  Future<void> play() async {
    // play() answers only once the sound ends
    unawaited(_p.play());
  }

  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> stop() => _p.stop();
  @override
  Future<void> seek(Duration to) => _p.seek(to);
  @override
  Future<void> setSpeed(double s) => _p.setSpeed(s);
  @override
  Stream<Duration> get positions => _p.positionStream;
  @override
  Stream<bool> get playings => _p.playingStream;
  @override
  Stream<void> get ends => _p.processingStateStream
      .where((s) => s == ProcessingState.completed)
      .map((_) {});
  @override
  Future<void> dispose() => _p.dispose();
}

/// the speeds the player steps through
const kSoundSpeeds = [1.0, 1.5, 2.0, 0.75];

class SoundPlayer extends ChangeNotifier {
  SoundPlayer._();
  static final instance = SoundPlayer._();

  @visibleForTesting
  static SoundEngine Function() engineMaker = _JustAudio.new;
  @visibleForTesting
  static LockGuard guard = lockGuard;

  SoundEngine? _engine;
  final List<StreamSubscription<Object?>> _subs = [];

  SoundItem? _item;
  List<SoundItem> _next = const [];
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;
  bool _loading = false;
  double _speed = 1;
  bool _repeat = false;
  PlainView? _view;
  String? _held;
  VoidCallback? _unguard;

  SoundItem? get item => _item;
  List<SoundItem> get upNext => _next;
  Duration get position => _pos;
  Duration get length => _dur;
  bool get playing => _playing;
  bool get loading => _loading;
  double get speed => _speed;
  bool get repeat => _repeat;

  bool isOn(String path) => _item?.path == path;
  double get share => _dur.inMilliseconds <= 0
      ? 0
      : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);

  SoundEngine _made() {
    final e = _engine;
    if (e != null) return e;
    final n = engineMaker();
    _engine = n;
    _subs.add(
      n.positions.listen((p) {
        if (!_playing && p == _pos) return;
        _pos = p;
        notifyListeners();
      }),
    );
    _subs.add(
      n.playings.listen((on) {
        if (on == _playing) return;
        _playing = on;
        notifyListeners();
      }),
    );
    _subs.add(n.ends.listen((_) => _ended()));
    return n;
  }

  /// [it] from the start, or on from where it is when it is the one loaded.
  /// [next] plays after it
  Future<void> play(SoundItem it, {List<SoundItem>? next}) async {
    if (guard.isLocked()) return;
    if (next != null) _next = next.where((x) => x != it).toList();
    if (_item != it || _view == null) {
      if (!await _load(it)) return;
    }
    _resume();
  }

  Future<bool> _load(SoundItem it) async {
    final e = _made();
    // from the first byte read until stop, played or paused: the lock takes
    // the plaintext, the name and what plays next
    _unguard ??= guard.closeOnLock(() {
      _unguard = null;
      stop();
    });
    _loading = true;
    _item = it;
    _pos = Duration.zero;
    _dur = Duration.zero;
    notifyListeners();
    _letGo();
    PlainView? v;
    try {
      v = plainViewOf(it.path);
      final d = await e.load(v.path);
      if (_item != it) {
        v.close();
        return false;
      }
      _view = v;
      holdVoiceFile(_held = it.path);
      _dur = d ?? Duration.zero;
      await e.setSpeed(_speed);
      return true;
    } catch (err) {
      dlog('sound: not loaded (${err.runtimeType})');
      v?.close();
      if (_item == it) stop();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _resume() {
    final e = _engine;
    if (e == null || guard.isLocked()) return;
    // a voice note playing stops where it is
    VoiceTurn.take(this, pause);
    _playing = true;
    notifyListeners();
    e.play();
  }

  // paused, it stays loaded: the lock still takes it (_load)
  void pause() {
    _engine?.pause();
    _playing = false;
    VoiceTurn.letGo(this);
    notifyListeners();
  }

  void toggle() {
    final it = _item;
    if (it == null) return;
    _playing ? pause() : play(it);
  }

  Future<void> seek(Duration to) async {
    final d = _dur;
    final at = to < Duration.zero
        ? Duration.zero
        : (d > Duration.zero && to > d ? d : to);
    _pos = at;
    notifyListeners();
    await _engine?.seek(at);
  }

  Future<void> seekShare(double s) =>
      seek(Duration(milliseconds: (_dur.inMilliseconds * s).round()));

  Future<void> skip(Duration by) => seek(_pos + by);

  /// the next speed of [kSoundSpeeds]
  Future<void> nextSpeed() async {
    final i = kSoundSpeeds.indexOf(_speed);
    _speed = kSoundSpeeds[(i + 1) % kSoundSpeeds.length];
    notifyListeners();
    await _engine?.setSpeed(_speed);
  }

  void toggleRepeat() {
    _repeat = !_repeat;
    notifyListeners();
  }

  Future<void> playNext() async {
    if (_next.isEmpty) return;
    final n = _next.first;
    _next = _next.sublist(1);
    await play(n);
  }

  void _ended() {
    if (_repeat) {
      seek(Duration.zero).then((_) => _resume());
      return;
    }
    if (_next.isNotEmpty) {
      playNext();
      return;
    }
    pause();
    seek(Duration.zero);
  }

  /// the sound stops and its file is let go; nothing stays loaded
  void stop() {
    VoiceTurn.letGo(this);
    _unguard?.call();
    _unguard = null;
    _playing = false;
    _engine?.stop();
    _letGo();
    _item = null;
    _next = const [];
    _pos = Duration.zero;
    _dur = Duration.zero;
    notifyListeners();
  }

  /// [path] is going: it stops first if it is the one playing
  void forget(String path) {
    if (_item?.path == path) stop();
    _next = _next.where((x) => x.path != path).toList();
  }

  void _letGo() {
    _view?.close();
    _view = null;
    final h = _held;
    _held = null;
    if (h != null) letVoiceFileGo(h);
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    stop();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _engine?.dispose();
    _engine = null;
    _speed = 1;
    _repeat = false;
  }
}
