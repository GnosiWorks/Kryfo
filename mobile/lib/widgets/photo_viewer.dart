// SPDX-License-Identifier: GPL-3.0-or-later
// the photo viewer. it opens out of the photo that was tapped, closes back
// into it by a tap or a swipe down, and pinches to zoom. the dark behind it
// thins as it is pulled, the way the video player's does.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appState;
import '../theme.dart';
import 'decode_px.dart';
import 'motion.dart' show houseSpring, motionStill;

/// the tag a photo and the viewer share, so the photo flies between them.
/// [id] tells the chat's copy from the shared photos' copy
Object photoHeroTag(String path, [Object? id]) => ('photo', path, id);

/// opens [path] full screen. [tag] is the hero the photo flies out of, and
/// [radius] its corners there. [secure] blocks screenshots while it is up
Future<void> openPhoto(
  BuildContext context,
  String path, {
  Object? tag,
  double radius = 0,
  bool secure = false,
}) {
  final image = ResizeImage.resizeIfNeeded(
    screenPx(context, times: 2),
    null,
    FileImage(File(path)),
  );
  return openPhotoImage(
    context,
    image,
    tag: tag,
    radius: radius,
    secure: secure,
  );
}

// a photo on its way up: a second tap while it decodes opens nothing more
bool _opening = false;

/// the same, for an image already in hand
Future<void> openPhotoImage(
  BuildContext context,
  ImageProvider image, {
  Object? tag,
  double radius = 0,
  bool secure = false,
}) async {
  if (_opening) return;
  // drop the composer's focus first, else popping the viewer brings the
  // keyboard back up over the chat
  FocusManager.instance.primaryFocus?.unfocus();
  final still = motionStill(context);
  // decoded before the flight, so it knows where it lands. a slow file
  // opens anyway after a moment
  _opening = true;
  try {
    await _decoded(image, context);
  } finally {
    _opening = false;
  }
  if (!context.mounted) return;
  // the flag is per window, so the photo is protected and the chat around
  // it is not. the viewer lets go of its own hold, never a screen's
  if (secure) appState.forceSecure(true);
  try {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: Duration(milliseconds: still ? 0 : 280),
        reverseTransitionDuration: Duration(milliseconds: still ? 0 : 240),
        pageBuilder: (_, anim, _) =>
            PhotoViewer(image: image, tag: tag, radius: radius, route: anim),
      ),
    );
  } finally {
    if (secure) appState.forceSecure(false);
  }
  FocusManager.instance.primaryFocus?.unfocus();
}

Future<void> _decoded(ImageProvider image, BuildContext context) {
  final done = Completer<void>();
  final wait = Timer(const Duration(milliseconds: 300), () {
    if (!done.isCompleted) done.complete();
  });
  // a wait only: the viewer's own image reports a failure to decode
  precacheImage(image, context, onError: (_, _) {}).whenComplete(() {
    wait.cancel();
    if (!done.isCompleted) done.complete();
  });
  return done.future;
}

class PhotoViewer extends StatefulWidget {
  final ImageProvider image;
  final Object? tag;
  final double radius;
  final Animation<double> route;
  const PhotoViewer({
    super.key,
    required this.image,
    required this.route,
    this.tag,
    this.radius = 0,
  });

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer>
    with SingleTickerProviderStateMixin {
  final _zoom = TransformationController();
  bool _zoomed = false;
  bool _closing = false;
  double _drag = 0;
  bool _pastClose = false;
  late final AnimationController _settle;

  static const _closeAt = 110.0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() => _drag = _settle.value));
  }

  @override
  void dispose() {
    _settle.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    // back to the whole photo first, so it flies home as it came
    _zoom.value = Matrix4.identity();
    Navigator.of(context).pop();
  }

  void _zoomEnded(ScaleEndDetails _) {
    final z = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (z != _zoomed) setState(() => _zoomed = z);
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
    if (motionStill(context)) {
      setState(() => _drag = 0);
      return;
    }
    _settle.value = _drag;
    // the spring stops within a hair of home: home is exact
    _settle.animateWith(houseSpring(_drag, 0, v)).then((_) {
      if (mounted) setState(() => _drag = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pulled = (_drag.abs() / 420).clamp(0.0, 1.0);
    final photo = InteractiveViewer(
      transformationController: _zoom,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomed,
      onInteractionEnd: _zoomEnded,
      child: Image(image: widget.image, gaplessPlayback: true),
    );
    final tag = widget.tag;
    return AnimatedBuilder(
      animation: widget.route,
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        // a zoomed photo pans instead
        onVerticalDragUpdate: _zoomed ? null : _dragUpdate,
        onVerticalDragEnd: _zoomed ? null : _dragEnd,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: widget.route.value * (1 - pulled * 0.75),
                ),
              ),
            ),
            Positioned.fill(child: child!),
          ],
        ),
      ),
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: Transform.scale(
          scale: 1 - pulled * 0.12,
          child: SafeArea(
            child: Center(
              child: tag == null
                  ? photo
                  : Hero(
                      tag: tag,
                      flightShuttleBuilder: (_, a, _, _, _) =>
                          photoFlight(a, widget.image, widget.radius),
                      child: photo,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// the photo between bubble and viewer: its crop opening out to the whole
/// frame, its corners easing from the bubble's to none
Widget photoFlight(Animation<double> a, ImageProvider image, double radius) =>
    AnimatedBuilder(
      animation: a,
      builder: (_, _) => ClipRRect(
        borderRadius: BorderRadius.circular(lerpDouble(radius, 0, a.value)!),
        child: Image(image: image, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );

/// a tile of photos: a quiet square until its photo is decoded, then the
/// photo fades up over it
class PhotoTileFade extends StatelessWidget {
  final bool shown;
  final Widget child;
  const PhotoTileFade({super.key, required this.shown, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HaloColors.surface2,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}
