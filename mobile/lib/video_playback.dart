// SPDX-License-Identifier: GPL-3.0-or-later
// the one video player every screen uses: the chat's viewer, an album's
// video pages, a clip before it goes, and files. android's own player
// draws into a texture (VideoPlayers.kt); this is what each screen used to
// repeat: opening it, play and pause, where it is, the lock and the app
// going behind. one player is alive at a time: one that opens puts the one
// before to sleep (its native player closed, its place kept), and the
// sleeper opens again where it was when it is played
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'dlog.dart';
import 'lock_guard.dart' show LockGuard, lockGuard;
import 'phone_seal.dart' show withFileKey;
import 'picture_lock.dart' show picturesShut;
import 'widgets/video_frame.dart' show VideoShape;

const _channel = MethodChannel('kryfo/video');

class VideoPlayback extends ChangeNotifier with WidgetsBindingObserver {
  VideoPlayback(
    this.path, {
    double aspect = 16 / 9,
    Duration length = Duration.zero,
    LockGuard? guard,
  }) : _aspect = aspect,
       _length = length,
       _guard = guard ?? lockGuard {
    WidgetsBinding.instance.addObserver(this);
    picturesShut.addListener(_lockChanged);
  }

  final String path;
  final LockGuard _guard;

  static VideoPlayback? _live;

  /// how many native players are open now, for the memory tests
  @visibleForTesting
  static int get liveCount => _open.length;
  static final Set<VideoPlayback> _open = {};

  int? _id;
  double _aspect;
  int _turns = 0;
  Duration _length;
  Duration _pos = Duration.zero;
  bool _playing = false;
  bool _done = false;
  bool _failed = false;
  bool _started = false;
  bool _opening = false;
  int _openingAt = -1;
  // closed by the lock, or by another player taking the turn: it opens
  // again where it was
  bool _resting = false;
  bool _asleep = false;
  // each rest counts up: an open still on its way from before one is closed
  int _rests = 0;
  bool _gone = false;
  Timer? _poll;
  VoidCallback? _unguard;

  /// a scrub in progress: what the player says is not read meanwhile
  bool holdReads = false;

  /// whether it opens again once the lock lifts (an album page out of view
  /// does not)
  bool wanted = true;

  int? get textureId => _id;
  double get aspect => _aspect;
  int get turns => _turns;
  Duration get length => _length;
  Duration get position => _pos;
  bool get playing => _playing;
  bool get done => _done;
  bool get failed => _failed;

  /// another player took the turn: a play opens it again where it was
  bool get asleep => _asleep;

  /// the texture has something to draw
  bool get started => _started;

  /// a scrub before it played: the frame under the thumb is drawn
  void showFrames() {
    if (_id == null || _started) return;
    _started = true;
    _changed();
  }

  double get share => _length.inMilliseconds <= 0
      ? 0
      : (_pos.inMilliseconds / _length.inMilliseconds).clamp(0.0, 1.0);

  void _changed() {
    if (!_gone) notifyListeners();
  }

  /// the native player, opened if it is not; [play] starts it once open.
  /// true when this call left it open: an open the lock overtook is not
  Future<bool> open({bool play = false}) async {
    if (_gone) return false;
    if (_id != null) {
      if (play) await this.play();
      return true;
    }
    // an open from before a lock does not count: it closes what it gets
    if ((_opening && _openingAt == _rests) || _failed) return false;
    _opening = true;
    final rests = _rests;
    _openingAt = rests;
    // one that slept or rested opens again where it was
    final back = (_asleep || _resting) && !_done ? _pos : Duration.zero;
    Map<String, dynamic>? m;
    try {
      m = await _channel.invokeMapMethod<String, dynamic>(
        'open',
        withFileKey(path, {'path': path}),
      );
    } catch (e) {
      dlog('video: not opened (${e.runtimeType})');
    }
    if (_openingAt == rests) _opening = false;
    // gone, or the lock went up while it opened: a lock and an unlock on
    // the way leave a newer open, so this one never holds a second player
    if (_gone || picturesShut.value || rests != _rests) {
      if (!_gone && picturesShut.value) _resting = true;
      final id = (m?['id'] as num?)?.toInt();
      if (id != null) _channel.invokeMethod('close', {'id': id});
      return false;
    }
    if (m == null) {
      _failed = true;
      _changed();
      return false;
    }
    final shape = VideoShape.from(m, _aspect);
    _id = (m['id'] as num).toInt();
    _open.add(this);
    _aspect = shape.aspect;
    _turns = shape.turns;
    final ms = (m['ms'] as num?)?.toInt() ?? 0;
    if (ms > 0) _length = Duration(milliseconds: ms);
    // one player alive: the one before sleeps
    final before = _live;
    _live = this;
    if (before != null && !identical(before, this)) before._sleep();
    _asleep = false;
    _resting = false;
    _changed();
    if (back > Duration.zero) await seek(back);
    if (play) await this.play();
    return true;
  }

  Future<void> play() async {
    if (_gone || _guard.isLocked()) return;
    if (_id == null) {
      await open();
      if (_id == null) return;
    }
    final id = _id;
    if (id == null || _gone || _guard.isLocked()) return;
    _live = this;
    // a finished one plays again from the start
    if (_done) {
      await _channel.invokeMethod('seek', {'id': id, 'ms': 0});
      _pos = Duration.zero;
    }
    await _channel.invokeMethod('play', {'id': id});
    if (_gone) return;
    _started = true;
    _playing = true;
    _done = false;
    _unguard ??= _guard.closeOnLock(() {
      _unguard = null;
      if (_playing) pause();
    });
    _poll ??= Timer.periodic(const Duration(milliseconds: 200), (_) => _read());
    _changed();
    // the app went behind while the player was asked: it does not play on
    // from a hidden screen
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) unawaited(pause());
  }

  Future<void> pause() async {
    _stopPoll();
    final id = _id;
    _playing = false;
    _changed();
    if (id != null) await _channel.invokeMethod('pause', {'id': id});
  }

  void toggle() => _playing ? pause() : play();

  Future<void> seek(Duration to) async {
    _pos = to;
    _changed();
    final id = _id;
    if (id != null) {
      await _channel.invokeMethod('seek', {'id': id, 'ms': to.inMilliseconds});
    }
  }

  Future<void> seekShare(double f) =>
      seek(Duration(milliseconds: (f * _length.inMilliseconds).round()));

  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  // asks the player where it is only while it plays: a paused or finished
  // video, or one behind the app, costs nothing
  Future<void> _read() async {
    final id = _id;
    if (id == null || holdReads) return;
    final m = await _channel.invokeMapMethod<String, dynamic>('state', {
      'id': id,
    });
    if (_gone || m == null || holdReads || id != _id) return;
    final done = m['done'] == true;
    if (done) _stopPoll();
    _pos = Duration(milliseconds: (m['ms'] as num?)?.toInt() ?? 0);
    _playing = m['playing'] == true;
    if (done && !_done) {
      _done = true;
      _playing = false;
      _pos = _length;
    }
    _changed();
  }

  void _closeNative() {
    _stopPoll();
    _unguard?.call();
    _unguard = null;
    final id = _id;
    _id = null;
    _open.remove(this);
    if (identical(_live, this)) _live = null;
    if (id != null) _channel.invokeMethod('close', {'id': id});
    _started = false;
    _playing = false;
  }

  // another player took the turn
  void _sleep() {
    if (_id == null) return;
    _closeNative();
    _asleep = true;
    _changed();
  }

  // the lock closes the player, so no frame of it is held behind the pin,
  // and it comes back paused where it was once the lock lifts
  void _lockChanged() {
    if (picturesShut.value) {
      _rests++;
      if (_id != null || _opening) _resting = true;
      _closeNative();
      _changed();
    } else {
      unawaited(_wake());
    }
  }

  Future<void> _wake() async {
    if (!_resting || _gone) return;
    if (!wanted) {
      _resting = false;
      _asleep = true;
      return;
    }
    await open();
    _resting = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _playing) pause();
  }

  @override
  void dispose() {
    _gone = true;
    picturesShut.removeListener(_lockChanged);
    WidgetsBinding.instance.removeObserver(this);
    _closeNative();
    super.dispose();
  }
}
