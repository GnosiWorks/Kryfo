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

import '../main.dart' show appState;
import '../open_file.dart';
import '../theme.dart';
import '../l10n/l10n.dart';
import 'video_bubble.dart' show openReceivedFile;
import '../lock_guard.dart' show LockGuard, lockGuard;
import '../dlog.dart';

const _channel = MethodChannel('kryfo/video');

// the lock nothing plays under. tests stand in for it
@visibleForTesting
LockGuard videoGuard = lockGuard;

/// the bubble and the player share this, so the frame flies between them
Object videoHeroTag(String path) => 'video:$path';

Future<void> openVideo(
  BuildContext context, {
  required String path,
  String? fileName,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final still = MediaQuery.disableAnimationsOf(context);
  final wasForced = appState.secureForced;
  if (!wasForced) await appState.forceSecure(true);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Duration(milliseconds: still ? 0 : 280),
      reverseTransitionDuration: Duration(milliseconds: still ? 0 : 240),
      pageBuilder: (_, anim, _) =>
          _VideoViewer(path: path, fileName: fileName, route: anim),
    ),
  );
  if (!wasForced) await appState.forceSecure(false);
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
          ? Image.memory(jpeg, fit: BoxFit.cover, gaplessPlayback: true)
          : const ColoredBox(color: Colors.black),
    ),
  );
}

class _VideoViewer extends StatefulWidget {
  final String path;
  final String? fileName;
  final Animation<double> route;
  const _VideoViewer({required this.path, this.fileName, required this.route});
  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int? _id;
  double _aspect = 16 / 9;
  Duration _length = Duration.zero;
  Duration _pos = Duration.zero;
  bool _playing = false;
  bool _done = false;
  bool _failed = false;
  bool _started = false;
  bool _controls = true;
  bool _closing = false;
  // a scrub in progress: where the thumb is, 0 to 1
  double? _scrub;
  double _drag = 0;
  bool _pastClose = false;
  // made up front: made lazily, a player closed without a pull would make
  // it in dispose, off a tree that is going away
  late final AnimationController _settle;
  Timer? _poll;
  Timer? _hide;

  static const _closeAt = 110.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settle = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() => _drag = _settle.value));
    final info = videoInfoNow(widget.path);
    if (info != null) {
      _aspect = info.aspect;
      _length = info.length;
    }
    widget.route.addStatusListener(_routeStatus);
    _open();
  }

  @override
  void dispose() {
    _unguard?.call();
    WidgetsBinding.instance.removeObserver(this);
    widget.route.removeStatusListener(_routeStatus);
    _poll?.cancel();
    _hide?.cancel();
    _settle.dispose();
    final id = _id;
    if (id != null) _channel.invokeMethod('close', {'id': id});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _playing) _pause();
  }

  void _routeStatus(AnimationStatus s) {
    // plays once it has landed, not while it flies
    if (s == AnimationStatus.completed && _id != null && !_started) _play();
  }

  Future<void> _open() async {
    Map<String, dynamic>? m;
    try {
      m = await _channel.invokeMapMethod<String, dynamic>('open', {
        'path': widget.path,
      });
    } catch (e) {
      dlog('video: not opened (${e.runtimeType})');
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
    final w = (m['w'] as num?)?.toInt() ?? 0;
    final h = (m['h'] as num?)?.toInt() ?? 0;
    setState(() {
      _id = (m!['id'] as num).toInt();
      if (w > 0 && h > 0) _aspect = w / h;
      final ms = (m['ms'] as num?)?.toInt() ?? 0;
      if (ms > 0) _length = Duration(milliseconds: ms);
    });
    if (widget.route.status == AnimationStatus.completed) _play();
  }

  // the lock pauses a video that is playing
  VoidCallback? _unguard;

  Future<void> _play() async {
    final id = _id;
    if (id == null || videoGuard.isLocked()) return;
    await _channel.invokeMethod('play', {'id': id});
    if (!mounted) return;
    setState(() {
      _started = true;
      _playing = true;
      _done = false;
    });
    _unguard ??= videoGuard.closeOnLock(() {
      _unguard = null;
      if (mounted && _playing) _pause();
    });
    _poll ??= Timer.periodic(const Duration(milliseconds: 200), (_) => _read());
    _hideSoon();
  }

  // asks the player where it is only while it plays: a paused or finished
  // video, or one behind the app, costs nothing
  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _pause() async {
    final id = _id;
    if (id == null) return;
    _stopPoll();
    await _channel.invokeMethod('pause', {'id': id});
    if (!mounted) return;
    setState(() {
      _playing = false;
      _controls = true;
    });
    _hide?.cancel();
  }

  void _toggle() {
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
        _controls = true;
        _pos = _length;
      }
    });
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

  void _seekTo(double f) {
    final id = _id;
    if (id == null) return;
    final ms = (f * _length.inMilliseconds).round();
    _channel.invokeMethod('seek', {'id': id, 'ms': ms});
  }

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
        // the swipe down wraps everything, buttons included: a pull that
        // starts on the play mark still pulls
        return GestureDetector(
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
                    color: Colors.black.withValues(
                      alpha: shown * (1 - pulled * 0.75),
                    ),
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
                      child: Center(child: _failed ? _cannotPlay() : _video()),
                    ),
                  ),
                ),
              ),
              if (!_failed) ..._chrome(pad, shown * (1 - pulled)),
            ],
          ),
        );
      },
    );
  }

  Widget _video() {
    final jpeg = videoInfoNow(widget.path)?.jpeg;
    final id = _id;
    return Hero(
      tag: videoHeroTag(widget.path),
      flightShuttleBuilder: (c, a, dir, from, to) =>
          videoFlight(c, a, dir, from, to, widget.path),
      child: AspectRatio(
        aspectRatio: _aspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (jpeg != null)
              Image.memory(jpeg, fit: BoxFit.cover, gaplessPlayback: true)
            else
              const ColoredBox(color: Colors.black),
            if (id != null && _started) Texture(textureId: id),
          ],
        ),
      ),
    );
  }

  List<Widget> _chrome(EdgeInsets pad, double fade) {
    final visible = _controls || !_playing;
    final len = _length.inMilliseconds;
    final at = _scrub ?? (len <= 0 ? 0.0 : _pos.inMilliseconds / len);
    return [
      // close
      PositionedDirectional(
        top: pad.top + 8,
        start: 12,
        child: _Fade(
          visible: visible,
          opacity: fade,
          child: _Round(
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
          ignoring: _playing || _id == null,
          child: Center(
            child: _Fade(
              visible: !_playing && _id != null && _drag == 0,
              opacity: fade,
              child: _Round(
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
                  _Round(
                    size: 40,
                    plain: true,
                    label: _playing
                        ? l10n.videoViewerPause
                        : l10n.videoViewerPlay,
                    onTap: _id == null ? null : _toggle,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (c, a) => ScaleTransition(
                        scale: a,
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
                  _Time(
                    Duration(
                      milliseconds: (at * len).round().clamp(0, len.abs()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Scrubber(
                      value: at.clamp(0.0, 1.0),
                      enabled: _id != null && len > 0,
                      onStart: (f) {
                        HapticFeedback.selectionClick();
                        _hide?.cancel();
                        setState(() => _scrub = f);
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
                        if (_playing) _hideSoon();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Time(_length),
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
            l10n.videoViewerCannotPlay,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 14, color: Colors.white, height: 1.45),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () async {
              final nav = Navigator.of(context);
              await openReceivedFile(context, widget.path, widget.fileName);
              if (mounted) nav.pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: HaloColors.amber, width: 1),
              ),
              child: Text(
                l10n.videoViewerOpenElsewhere,
                style: HaloType.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: HaloColors.amber,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _close,
            child: Text(
              l10n.commonClose,
              style: HaloType.sans(size: 13, color: HaloColors.text2),
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

// a round button on the video: a dark disc, or nothing behind it (plain)
class _Round extends StatefulWidget {
  final double size;
  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool plain;
  const _Round({
    required this.size,
    required this.label,
    required this.onTap,
    required this.child,
    this.plain = false,
  });
  @override
  State<_Round> createState() => _RoundState();
}

class _RoundState extends State<_Round> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: widget.plain
                ? null
                : BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _Time extends StatelessWidget {
  final Duration d;
  const _Time(this.d);
  @override
  Widget build(BuildContext context) => Text(
    videoLength(d),
    style: HaloType.mono(size: 11, color: Colors.white, letter: 0.2),
  );
}

// the timeline: a thin track, the played part in amber, a thumb that grows
// while it is held. a tap jumps, a drag scrubs.
class _Scrubber extends StatefulWidget {
  final double value;
  final bool enabled;
  final ValueChanged<double> onStart;
  final ValueChanged<double> onChange;
  final VoidCallback onEnd;
  const _Scrubber({
    required this.value,
    required this.enabled,
    required this.onStart,
    required this.onChange,
    required this.onEnd,
  });
  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
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
