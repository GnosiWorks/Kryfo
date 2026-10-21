// SPDX-License-Identifier: GPL-3.0-or-later
// a clip played in place before it goes, on the camera's review and the
// send screen. android's own player draws into a texture (VideoPlayers.kt),
// as in the viewer. a tap on the picture plays or pauses, and the timeline
// runs left to right in every language, as a tape does.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../open_file.dart';
import '../theme.dart';
import 'motion.dart' show kHouseCurve, kHouseTime, motionStill;
import 'video_frame.dart';
import 'video_viewer.dart' show ViewerRound, ViewerScrubber, ViewerTime;
import '../lock_guard.dart' show LockGuard, lockGuard;

const _channel = MethodChannel('kryfo/video');

// the lock nothing plays under. tests stand in for it
@visibleForTesting
LockGuard clipGuard = lockGuard;

class ClipPreview extends StatefulWidget {
  final String path;
  // plays once open, unless the phone asks for no movement
  final bool autoplay;
  // over the picture's top corner: the clip's size, a warning
  final Widget? badge;
  final double radius;
  const ClipPreview({
    super.key,
    required this.path,
    this.autoplay = false,
    this.badge,
    this.radius = 14,
  });
  @override
  State<ClipPreview> createState() => _ClipPreviewState();
}

class _ClipPreviewState extends State<ClipPreview> with WidgetsBindingObserver {
  int? _id;
  late VideoInfo? _info = videoInfoNow(widget.path);
  // as shown, from the player once it answers
  double? _shape;
  int _turns = 0;
  Duration _length = Duration.zero;
  Duration _pos = Duration.zero;
  bool _playing = false;
  bool _done = false;
  bool _failed = false;
  // the texture goes over the still once it has something to draw
  bool _started = false;
  // a scrub in progress: where the thumb is, 0 to 1
  double? _scrub;
  Timer? _poll;
  // the lock pauses it
  VoidCallback? _unguard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final i = _info;
    if (i != null) _length = i.length;
    if (i == null) {
      videoInfoFor(widget.path).then((i) {
        if (!mounted || i == null) return;
        setState(() {
          _info = i;
          if (_length == Duration.zero) _length = i.length;
        });
      });
    }
    _open();
  }

  @override
  void dispose() {
    _unguard?.call();
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    final id = _id;
    if (id != null) _channel.invokeMethod('close', {'id': id});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _playing) _pause();
  }

  Future<void> _open() async {
    Map<String, dynamic>? m;
    try {
      m = await _channel.invokeMapMethod<String, dynamic>('open', {
        'path': widget.path,
      });
    } catch (e) {
      dlog('clip: not opened (${e.runtimeType})');
    }
    if (!mounted) {
      final id = (m?['id'] as num?)?.toInt();
      if (id != null) _channel.invokeMethod('close', {'id': id});
      return;
    }
    if (m == null) {
      setState(() => _failed = true);
      return;
    }
    final shape = VideoShape.from(m, _info?.aspect ?? 16 / 9);
    setState(() {
      _id = (m!['id'] as num).toInt();
      _shape = shape.aspect;
      _turns = shape.turns;
      final ms = (m['ms'] as num?)?.toInt() ?? 0;
      if (ms > 0) _length = Duration(milliseconds: ms);
    });
    if (widget.autoplay && !motionStill(context)) unawaited(_play());
  }

  Future<void> _play() async {
    final id = _id;
    if (id == null || clipGuard.isLocked()) return;
    // a finished clip plays again from the start
    if (_done) {
      await _channel.invokeMethod('seek', {'id': id, 'ms': 0});
    }
    await _channel.invokeMethod('play', {'id': id});
    if (!mounted) return;
    setState(() {
      _started = true;
      _playing = true;
      if (_done) _pos = Duration.zero;
      _done = false;
    });
    _unguard ??= clipGuard.closeOnLock(() {
      _unguard = null;
      if (mounted && _playing) _pause();
    });
    _poll ??= Timer.periodic(const Duration(milliseconds: 200), (_) => _read());
  }

  // asks the player where it is only while it plays
  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _pause() async {
    final id = _id;
    if (id == null) return;
    _stopPoll();
    await _channel.invokeMethod('pause', {'id': id});
    if (mounted) setState(() => _playing = false);
  }

  void _toggle() {
    if (_id == null) return;
    HapticFeedback.selectionClick();
    _playing ? _pause() : _play();
  }

  Future<void> _read() async {
    final id = _id;
    if (id == null || _scrub != null) return;
    final m = await _channel.invokeMapMethod<String, dynamic>('state', {
      'id': id,
    });
    if (!mounted || m == null || _scrub != null) return;
    final done = m['done'] == true;
    if (done) _stopPoll();
    setState(() {
      _pos = Duration(milliseconds: (m['ms'] as num?)?.toInt() ?? 0);
      _playing = m['playing'] == true;
      if (done && !_done) {
        _done = true;
        _playing = false;
        _pos = _length;
      }
    });
  }

  void _seekTo(double f) {
    final id = _id;
    if (id == null) return;
    final ms = (f * _length.inMilliseconds).round();
    _channel.invokeMethod('seek', {'id': id, 'ms': ms});
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final aspect = (_shape ?? _info?.aspect ?? 16 / 9).clamp(0.4, 2.6);
    // the box eases to the clip's own shape once the player says it
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: aspect),
        duration: still ? Duration.zero : kHouseTime,
        curve: Curves.easeOutCubic,
        builder: (_, a, child) => AspectRatio(aspectRatio: a, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  label: l10n.videoBubbleVideo,
                  image: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _failed ? null : _toggle,
                    child: _failed ? _cannotPlay() : _picture(),
                  ),
                ),
                if (!_failed) _mark(still),
                if (!_failed)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    child: _timeline(still),
                  ),
                if (widget.badge != null)
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    end: 10,
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: widget.badge,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _picture() {
    final jpeg = _info?.jpeg;
    final id = _id;
    return VideoFrame(
      aspect: _shape ?? _info?.aspect ?? 16 / 9,
      turns: _turns,
      under: jpeg != null
          ? Image.memory(jpeg, fit: BoxFit.cover, gaplessPlayback: true)
          : const ColoredBox(color: Colors.black),
      texture: id != null && _started ? Texture(textureId: id) : null,
    );
  }

  // the big mark while it is not playing: it grows in on the house curve
  Widget _mark(bool still) {
    final up = !_playing && _id != null && _scrub == null;
    final d = still ? Duration.zero : const Duration(milliseconds: 200);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !up,
        child: Center(
          child: AnimatedOpacity(
            opacity: up ? 1 : 0,
            duration: d,
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: up ? 1 : 0.82,
              duration: still ? Duration.zero : kHouseTime,
              curve: kHouseCurve,
              child: ViewerRound(
                size: 62,
                label: _done ? l10n.videoViewerPlayAgain : l10n.videoViewerPlay,
                onTap: _toggle,
                child: Icon(
                  _done ? Icons.replay_rounded : Icons.play_arrow_rounded,
                  size: 36,
                  color: HaloColors.amber,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeline(bool still) {
    final len = _length.inMilliseconds;
    final at = _scrub ?? (len <= 0 ? 0.0 : _pos.inMilliseconds / len);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 22, 12, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.55),
            ],
          ),
        ),
        child: Row(
          children: [
            ViewerRound(
              size: 40,
              plain: true,
              label: _playing ? l10n.videoViewerPause : l10n.videoViewerPlay,
              onTap: _id == null ? null : _toggle,
              child: AnimatedSwitcher(
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: still ? const AlwaysStoppedAnimation(1.0) : a,
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(_playing),
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ),
            ViewerTime(
              Duration(milliseconds: (at * len).round().clamp(0, len.abs())),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ViewerScrubber(
                value: at.clamp(0.0, 1.0),
                enabled: _id != null && len > 0,
                onStart: (f) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _scrub = f;
                    // the frame under the thumb shows while it moves
                    _started = true;
                  });
                  _seekTo(f);
                },
                onChange: (f) {
                  setState(() => _scrub = f);
                  _seekTo(f);
                },
                onEnd: () {
                  final f = _scrub;
                  setState(() {
                    if (f != null) {
                      _pos = Duration(milliseconds: (f * len).round());
                      _done = false;
                    }
                    _scrub = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            ViewerTime(_length),
          ],
        ),
      ),
    );
  }

  Widget _cannotPlay() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 36, color: HaloColors.amber),
          const SizedBox(height: 12),
          Text(
            l10n.videoViewerCannotPlay,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 13, color: Colors.white, height: 1.4),
          ),
        ],
      ),
    ),
  );
}
