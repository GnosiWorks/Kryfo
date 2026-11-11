// SPDX-License-Identifier: GPL-3.0-or-later
// the video player. it opens out of the bubble, plays in the app, and closes
// back into it, by the close button or a swipe down. android's own player
// draws into a texture (VideoPlayers.kt): the file is never handed to
// another app, and screenshots and the recents preview are blocked while it
// is up. the timeline runs left to right in every language, as a tape does.
import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import '../main.dart' show appState, AppStateScreen;
import '../open_file.dart';
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import 'halo_hero.dart';
import 'key_ring.dart' show HoverTip;
import 'motion.dart' show kText2, motionStill;
import 'press_scale.dart';
import 'sealed_picture.dart';
import 'text_ground.dart';
import '../l10n/l10n.dart';
import 'shots_line.dart' show KeptIn, keptOpenLine;
import 'file_actions.dart' show openFileOutside;
import 'video_frame.dart';
import '../lock_guard.dart' show LockGuard, lockGuard;
import '../video_playback.dart';
import 'pictures_gate.dart' show PicturesGate;

// the lock nothing plays under. tests stand in for it
@visibleForTesting
LockGuard videoGuard = lockGuard;

/// the bubble and the player share this, so the frame flies between them
Object videoHeroTag(String path) => 'video:$path';

Future<void> openVideo(
  BuildContext context, {
  required String path,
  String? fileName,
  // the other person's, in a chat that blocks: no other app (shotsKeeps)
  bool kept = false,
  KeptIn where = KeptIn.chat,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final still = MediaQuery.disableAnimationsOf(context);
  // its own hold, let go however the viewer ends
  await appState.forceSecure(true);
  try {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: Duration(milliseconds: still ? 0 : 280),
        reverseTransitionDuration: Duration(milliseconds: still ? 0 : 240),
        pageBuilder: (_, anim, _) => TextGround(
          child: _VideoViewer(
            path: path,
            fileName: fileName,
            route: anim,
            kept: kept,
            where: where,
          ),
        ),
      ),
    );
  } finally {
    await appState.forceSecure(false);
  }
  FocusManager.instance.primaryFocus?.unfocus();
}

/// the flight between bubble and player: the first frame, its corners
/// easing from the bubble's to the screen's
Widget videoFlight(
  BuildContext _,
  Animation<double> anim,
  HeroFlightDirection dir,
  BuildContext from,
  BuildContext to,
  String path,
) {
  final jpeg = videoInfoNow(path)?.jpeg;
  return AnimatedBuilder(
    animation: anim,
    builder: (_, _) => ClipRRect(
      borderRadius: BorderRadius.circular(lerpDouble(14, 0, anim.value)!),
      child: jpeg != null
          ? PicturesGate(
              shut: const ColoredBox(color: Colors.black),
              child: Image.memory(
                jpeg,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            )
          : const ColoredBox(color: Colors.black),
    ),
  );
}

class _VideoViewer extends StatefulWidget {
  final String path;
  final String? fileName;
  final Animation<double> route;
  final bool kept;
  final KeptIn where;
  const _VideoViewer({
    required this.path,
    this.fileName,
    required this.route,
    this.kept = false,
    this.where = KeptIn.chat,
  });
  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer>
    with SingleTickerProviderStateMixin {
  // the one player every screen shares
  late final VideoPlayback _v = VideoPlayback(
    widget.path,
    aspect: videoInfoNow(widget.path)?.aspect ?? 16 / 9,
    length: videoInfoNow(widget.path)?.length ?? Duration.zero,
    guard: videoGuard,
  );
  bool _done = false;
  bool _controls = true;
  bool _closing = false;
  // a scrub in progress: where the thumb is, 0 to 1
  double? _scrub;
  double _drag = 0;
  bool _pastClose = false;
  // made up front: made lazily, a player closed without a pull would make
  // it in dispose, off a tree that is going away
  late final AnimationController _settle;
  Timer? _hide;

  bool get _playing => _v.playing;
  bool get _failed => _v.failed;
  int? get _id => _v.textureId;

  static const _closeAt = 110.0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() => _drag = _settle.value));
    widget.route.addStatusListener(_routeStatus);
    _v.addListener(_moved);
    picturesShut.addListener(_lockChanged);
    // plays once it has landed, not while it flies
    _v.open(play: widget.route.status == AnimationStatus.completed);
  }

  @override
  void dispose() {
    widget.route.removeStatusListener(_routeStatus);
    _v.removeListener(_moved);
    picturesShut.removeListener(_lockChanged);
    _v.dispose();
    _hide?.cancel();
    _settle.dispose();
    super.dispose();
  }

  void _moved() {
    if (!mounted) return;
    setState(() {
      // at its end the controls come back
      if (_v.done && !_done) _controls = true;
      _done = _v.done;
      if (!_v.playing) _controls = _controls || !_v.started;
    });
  }

  // the first frame the lock took comes back under the blur after it
  void _lockChanged() {
    if (picturesShut.value) return;
    videoInfoFor(widget.path).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _routeStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && !_v.started) _play();
  }

  Future<void> _play() async {
    await _v.play();
    if (mounted && _v.playing) _hideSoon();
  }

  Future<void> _pause() async {
    await _v.pause();
    if (!mounted) return;
    setState(() => _controls = true);
    _hide?.cancel();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    _playing ? _pause() : _play();
  }

  // controls go while it plays, and come back on a tap
  void _hideSoon() {
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 2600), () {
      if (mounted && _playing && _scrub == null) {
        setState(() => _controls = false);
      }
    });
  }

  void _tapVideo() {
    setState(() => _controls = !_controls);
    if (_controls) _hideSoon();
  }

  void _seekTo(double f) => _v.seekShare(f);

  void _close() {
    if (_closing) return;
    _closing = true;
    _pause();
    Navigator.of(context).pop();
  }

  void _dragUpdate(DragUpdateDetails d) {
    _settle.stop();
    setState(() => _drag += d.delta.dy);
    final past = _drag.abs() > _closeAt;
    if (past != _pastClose) {
      _pastClose = past;
      if (past) HapticFeedback.lightImpact();
    }
  }

  void _dragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (_drag.abs() > _closeAt || v.abs() > 900) {
      _close();
      return;
    }
    _pastClose = false;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _drag = 0);
      return;
    }
    _settle.value = _drag;
    _settle.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 520, damping: 34),
        _drag,
        0,
        v,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final pulled = (_drag.abs() / 420).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: widget.route,
      builder: (context, _) {
        final shown = widget.route.value;
        final dark = shown * (1 - pulled * 0.75);
        // light bar icons while the black is behind them. the swipe down
        // wraps everything, buttons included: a pull that starts on the
        // play mark still pulls
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark > 0.5
              ? haloOverlayOnDark
              : haloOverlayStyle(
                  underNav: MediaQuery.viewPaddingOf(context).bottom > 0,
                ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: _dragUpdate,
            onVerticalDragEnd: _dragEnd,
            child: Stack(
              children: [
                // the dark behind it thins as it is pulled down
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _tapVideo,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: dark),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _tapVideo,
                    onDoubleTap: _failed ? null : _toggle,
                    child: Transform.translate(
                      offset: Offset(0, _drag),
                      child: Transform.scale(
                        scale: 1 - pulled * 0.12,
                        child: Center(
                          child: _failed ? _cannotPlay() : _video(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_failed) ..._chrome(pad, shown * (1 - pulled)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _video() {
    final jpeg = videoInfoNow(widget.path)?.jpeg;
    final id = _id;
    return HaloHero(
      tag: videoHeroTag(widget.path),
      flightShuttleBuilder: (c, a, dir, from, to) =>
          videoFlight(c, a, dir, from, to, widget.path),
      child: VideoFrame(
        aspect: _v.aspect,
        turns: _v.turns,
        // its blur, the first frame fading up over it
        under: SealedPicture(
          path: widget.path,
          image: jpeg == null ? null : MemoryImage(jpeg),
          ground: Colors.black,
        ),
        texture: id != null && _v.started ? Texture(textureId: id) : null,
      ),
    );
  }

  List<Widget> _chrome(EdgeInsets pad, double fade) {
    final visible = _controls || !_playing;
    final len = _v.length.inMilliseconds;
    final at = _scrub ?? _v.share;
    return [
      // close
      PositionedDirectional(
        top: pad.top + 8,
        start: 12,
        child: _Fade(
          visible: visible,
          opacity: fade,
          child: ViewerRound(
            size: 40,
            label: l10n.commonClose,
            onTap: _close,
            child: const Icon(
              Icons.close_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
      // the big mark while it is not playing
      Positioned.fill(
        child: IgnorePointer(
          ignoring: _playing || (_id == null && !_v.asleep),
          child: Center(
            child: _Fade(
              visible: !_playing && (_id != null || _v.asleep) && _drag == 0,
              opacity: fade,
              child: ViewerRound(
                size: 66,
                label: _done ? l10n.videoViewerPlayAgain : l10n.videoViewerPlay,
                onTap: _toggle,
                child: Icon(
                  _done ? Icons.replay_rounded : Icons.play_arrow_rounded,
                  size: 38,
                  color: HaloColors.amber,
                ),
              ),
            ),
          ),
        ),
      ),
      // the timeline, left to right in every language
      PositionedDirectional(
        start: 0,
        end: 0,
        bottom: 0,
        child: _Fade(
          visible: visible,
          opacity: fade,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              padding: EdgeInsets.fromLTRB(8, 28, 16, pad.bottom + 12),
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
                    label: _playing
                        ? l10n.videoViewerPause
                        : l10n.videoViewerPlay,
                    onTap: _id == null ? null : _toggle,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (c, a) => ScaleTransition(
                        scale: motionStill(context)
                            ? const AlwaysStoppedAnimation(1.0)
                            : a,
                        child: FadeTransition(opacity: a, child: c),
                      ),
                      child: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(_playing),
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ViewerTime(
                    Duration(
                      milliseconds: (at * len).round().clamp(0, len.abs()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ViewerScrubber(
                      value: at.clamp(0.0, 1.0),
                      enabled: _id != null && len > 0,
                      onStart: (f) {
                        HapticFeedback.selectionClick();
                        _hide?.cancel();
                        _v.holdReads = true;
                        setState(() => _scrub = f);
                        _seekTo(f);
                      },
                      onChange: (f) {
                        setState(() => _scrub = f);
                        _seekTo(f);
                      },
                      onEnd: () {
                        _v.holdReads = false;
                        setState(() => _scrub = null);
                        if (_playing) _hideSoon();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ViewerTime(_v.length),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _cannotPlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 40, color: HaloColors.amber),
          const SizedBox(height: 14),
          Text(
            l10n.videoViewerCannotPlayShown,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 14, color: Colors.white, height: 1.45),
          ),
          const SizedBox(height: 18),
          // the other person's, in a chat that blocks: no other app
          if (widget.kept)
            Text(
              keptOpenLine(widget.where),
              textAlign: TextAlign.center,
              style: HaloType.sans(size: 13, color: Colors.white, height: 1.4),
            )
          else
            PressScale(
              scale: 0.96,
              onTap: () async {
                final nav = Navigator.of(context);
                await openFileOutside(context, widget.path, widget.fileName);
                if (mounted) nav.pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: HaloColors.amber, width: 1),
                ),
                child: Text(
                  l10n.videoViewerOpenElsewhere,
                  style: HaloType.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: HaloColors.amberText,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          // the dark theme's text2 on the viewer's black in both themes, a
          // full finger wide
          PressScale(
            scale: 0.96,
            onTap: _close,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                l10n.commonClose,
                style: HaloType.sans(size: 13, color: kText2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// shows and hides the controls: a fade, and no taps while hidden
class _Fade extends StatelessWidget {
  final bool visible;
  final double opacity;
  final Widget child;
  const _Fade({
    required this.visible,
    required this.opacity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedOpacity(
      opacity: visible ? opacity.clamp(0.0, 1.0) : 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: child,
    ),
  );
}

// a round button on a video: a dark disc, or nothing behind it (plain).
// the album viewer's video pages use it too
class ViewerRound extends StatefulWidget {
  final double size;
  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool plain;
  const ViewerRound({
    super.key,
    required this.size,
    required this.label,
    required this.onTap,
    required this.child,
    this.plain = false,
  });
  @override
  State<ViewerRound> createState() => _ViewerRoundState();
}

class _ViewerRoundState extends State<ViewerRound> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    Widget w = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: still ? Duration.zero : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 120),
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: widget.plain
              ? null
              : BoxDecoration(
                  shape: BoxShape.circle,
                  // a computer: a little deeper under the mouse
                  color: Colors.black.withValues(alpha: _hover ? 0.62 : 0.45),
                ),
          child: widget.child,
        ),
      ),
    );
    if (onDesktop && widget.onTap != null) {
      w = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: w,
      );
      w = HoverTip(message: widget.label, child: w);
    }
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: w,
    );
  }
}

class ViewerTime extends StatelessWidget {
  final Duration d;
  const ViewerTime(this.d, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    videoLength(d),
    style: HaloType.mono(size: 11, color: Colors.white, letter: 0.2),
  );
}

// the timeline: a thin track, the played part in amber, a thumb that grows
// while it is held. a tap jumps, a drag scrubs.
class ViewerScrubber extends StatefulWidget {
  final double value;
  final bool enabled;
  final ValueChanged<double> onStart;
  final ValueChanged<double> onChange;
  final VoidCallback onEnd;
  const ViewerScrubber({
    super.key,
    required this.value,
    required this.enabled,
    required this.onStart,
    required this.onChange,
    required this.onEnd,
  });
  @override
  State<ViewerScrubber> createState() => _ViewerScrubberState();
}

class _ViewerScrubberState extends State<ViewerScrubber> {
  bool _held = false;

  double _at(Offset local, double width) =>
      (local.dx / (width <= 0 ? 1 : width)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: !widget.enabled
              ? null
              : (d) {
                  setState(() => _held = true);
                  widget.onStart(_at(d.localPosition, w));
                },
          onHorizontalDragUpdate: !widget.enabled
              ? null
              : (d) => widget.onChange(_at(d.localPosition, w)),
          onHorizontalDragEnd: !widget.enabled
              ? null
              : (_) {
                  setState(() => _held = false);
                  widget.onEnd();
                },
          onTapUp: !widget.enabled
              ? null
              : (d) {
                  widget.onStart(_at(d.localPosition, w));
                  widget.onEnd();
                },
          child: SizedBox(
            height: 36,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: w * widget.value,
                  height: 3,
                  decoration: BoxDecoration(
                    color: HaloColors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Positioned(
                  left: w * widget.value - (_held ? 9 : 6),
                  child: AnimatedContainer(
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 140),
                    curve: Curves.easeOutBack,
                    width: _held ? 18 : 12,
                    height: _held ? 18 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HaloColors.amber,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
