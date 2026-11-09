// SPDX-License-Identifier: GPL-3.0-or-later
// a clip played in place before it goes, on the camera's review and the
// send screen. android's player draws into a texture (VideoPlayers.kt), and
// the timeline runs left to right in every language

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../open_file.dart';
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import 'motion.dart' show kHouseCurve, kHouseTime, motionStill;
import 'decode_px.dart';
import 'sealed_picture.dart';
import 'video_frame.dart';
import 'video_viewer.dart' show ViewerRound, ViewerScrubber, ViewerTime;
import '../lock_guard.dart' show LockGuard, lockGuard;
import '../video_playback.dart';

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

class _ClipPreviewState extends State<ClipPreview> {
  late VideoInfo? _info = videoInfoNow(widget.path);
  // the one player every screen shares
  late final VideoPlayback _v = VideoPlayback(
    widget.path,
    aspect: _info?.aspect ?? 16 / 9,
    length: _info?.length ?? Duration.zero,
    guard: clipGuard,
  );
  bool _done = false;
  // a scrub in progress: where the thumb is, 0 to 1
  double? _scrub;

  bool get _playing => _v.playing;
  bool get _failed => _v.failed;
  int? get _id => _v.textureId;

  @override
  void initState() {
    super.initState();
    if (_info == null) _askInfo();
    _v.addListener(_moved);
    picturesShut.addListener(_lockChanged);
    _v.open().then((opened) {
      if (opened && mounted && widget.autoplay && !motionStill(context)) {
        _v.play();
      }
    });
  }

  void _askInfo() => videoInfoFor(widget.path).then((i) {
    if (mounted && i != null) setState(() => _info = i);
  });

  // the first frame the lock took comes back under the blur after it
  void _lockChanged() {
    if (!picturesShut.value) _askInfo();
  }

  void _moved() {
    if (mounted) setState(() => _done = _v.done);
  }

  @override
  void dispose() {
    picturesShut.removeListener(_lockChanged);
    _v.removeListener(_moved);
    _v.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_id == null && !_v.failed) {
      // asleep: another player took the turn; it opens where it was
      HapticFeedback.selectionClick();
      _v.play();
      return;
    }
    if (_id == null) return;
    HapticFeedback.selectionClick();
    _v.toggle();
  }

  void _seekTo(double f) => _v.seekShare(f);

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final aspect = (_id != null ? _v.aspect : _info?.aspect ?? 16 / 9).clamp(
      0.4,
      2.6,
    );
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
      aspect: _id != null ? _v.aspect : _info?.aspect ?? 16 / 9,
      turns: _v.turns,
      under: SealedPicture(
        path: widget.path,
        image: jpeg == null ? null : frameImage(jpeg, screenPx(context)),
        ground: Colors.black,
      ),
      texture: id != null && _v.started ? Texture(textureId: id) : null,
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
    final len = _v.length.inMilliseconds;
    final at = _scrub ?? _v.share;
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
                  _v.holdReads = true;
                  setState(() => _scrub = f);
                  // the frame under the thumb shows while it moves
                  _v.showFrames();
                  _seekTo(f);
                },
                onChange: (f) {
                  setState(() => _scrub = f);
                  _seekTo(f);
                },
                onEnd: () {
                  _v.holdReads = false;
                  setState(() => _scrub = null);
                },
              ),
            ),
            const SizedBox(width: 10),
            ViewerTime(_v.length),
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
            l10n.videoViewerCannotPlayShown,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 13, color: Colors.white, height: 1.4),
          ),
        ],
      ),
    ),
  );
}
