// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's photo, or a video's first frame, as the lock allows. while the
// lock is up nothing of it is decoded or drawn and it keeps its size. once
// it lifts the blur is there in the first frame, at the photo's shape, and
// the photo fades up over it when decoded; under reduced motion it swaps
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../devices/history_files.dart' show historyFilesComing;
import '../l10n/l10n.dart';
import '../media_trace.dart' show traceDecode;
import '../photo_blur.dart';
import '../picture_lock.dart';
import '../theme.dart';
import 'motion.dart' show motionStill;

const kPictureFade = Duration(milliseconds: 200);

/// a media file decoded [width] pixels across at most
ImageProvider mediaImage(String path, [int? width]) =>
    ResizeImage.resizeIfNeeded(width, null, FileImage(File(path)));

class SealedPicture extends StatefulWidget {
  const SealedPicture({
    super.key,
    required this.path,
    required this.image,
    this.fit = BoxFit.cover,
    this.shaped = false,
    this.decodeWidth,
    this.ground,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.errorBuilder,
    this.framed,
  });

  /// the media file: its blur is kept next to it
  final String path;

  /// what is decoded and drawn. null while there is nothing yet, as a
  /// video's first frame on its way
  final ImageProvider? image;
  final BoxFit fit;

  /// sized by the blur at the shape the decoded picture will have, so
  /// nothing moves when it comes. otherwise the parent gives the size
  final bool shaped;

  /// the width the picture is decoded at, which a small one does not reach
  final int? decodeWidth;

  /// under the picture when it has no blur
  final Color? ground;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final ImageErrorWidgetBuilder? errorBuilder;

  /// around the picture while it shows, never around [errorBuilder]'s
  final Widget Function(Widget picture)? framed;

  @override
  State<SealedPicture> createState() => _SealedPictureState();
}

class _SealedPictureState extends State<SealedPicture> {
  bool _asked = false;
  // what would not decode, drawn without the frame from the next build
  (Object, StackTrace?)? _failed;
  // the history copy still brings this file: it waits, never "unavailable"
  late bool _coming = historyFilesComing.coming(widget.path);

  @override
  void initState() {
    super.initState();
    picturesShut.addListener(_changed);
    historyFilesComing.addListener(_comingChanged);
  }

  @override
  void didUpdateWidget(SealedPicture old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.image != widget.image) {
      _asked = false;
      _failed = null;
      _coming = historyFilesComing.coming(widget.path);
    }
  }

  @override
  void dispose() {
    picturesShut.removeListener(_changed);
    historyFilesComing.removeListener(_comingChanged);
    super.dispose();
  }

  void _comingChanged() {
    final now = historyFilesComing.coming(widget.path);
    if (now == _coming || !mounted) return;
    // landed: a failed try from before it came is not kept
    if (!now) unawaited(widget.image?.evict());
    setState(() {
      _coming = now;
      _failed = null;
      _asked = false;
    });
  }

  void _changed() {
    if (!mounted) return;
    if (picturesShut.value) _asked = false;
    setState(() {});
  }

  // seen without a blur while unlocked: one is made for the next time
  void _ask() {
    if (_asked) return;
    _asked = true;
    makeBlurSoon(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    final shut = picturesShut.value;
    return HeldSize(
      held: shut,
      child: shut ? const SizedBox.shrink() : _open(context),
    );
  }

  Widget? _error(BuildContext context, Object e, StackTrace? st) {
    traceDecode(widget.path, error: e);
    final b = widget.errorBuilder;
    if (b == null) return null;
    if (widget.framed != null && _failed == null) {
      _failed = (e, st);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    return b(context, e, st);
  }

  Widget _open(BuildContext context) {
    if (_coming) {
      final framed = widget.framed ?? (Widget w) => w;
      return framed(const MediaArriving());
    }
    final f = _failed;
    if (f != null && widget.framed != null) {
      return _error(context, f.$1, f.$2)!;
    }
    final framed = widget.framed ?? (Widget w) => w;
    return framed(_picture(context));
  }

  Widget _picture(BuildContext context) {
    final blur = blurNow(widget.path);
    final still = motionStill(context);
    final image = widget.image;
    final picture = image == null
        ? const SizedBox.shrink()
        : Image(
            image: image,
            fit: widget.fit,
            gaplessPlayback: true,
            filterQuality: widget.filterQuality,
            semanticLabel: widget.semanticLabel,
            excludeFromSemantics: widget.excludeFromSemantics,
            errorBuilder: widget.errorBuilder == null
                ? null
                : (c, e, st) => _error(c, e, st)!,
            frameBuilder: (_, child, frame, sync) {
              final shown = sync || frame != null;
              if (shown) traceDecode(widget.path);
              if (shown && blur == null) _ask();
              return PictureFade(shown: shown, still: still, child: child);
            },
          );
    if (blur == null) {
      final ground = ColoredBox(
        color: widget.ground ?? HaloColors.surface2,
        child: picture,
      );
      if (widget.shaped || image != null) return ground;
      return SizedBox.expand(child: ground);
    }
    final layers = Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: BlurPainter(blur, widget.fit)),
        picture,
      ],
    );
    if (!widget.shaped) return layers;
    final w = blur.width.toDouble(), h = blur.height.toDouble();
    final across = widget.decodeWidth == null
        ? w
        : math.min(widget.decodeWidth!.toDouble(), w);
    return ShapedBox(natural: Size(across, across * h / w), child: layers);
  }
}

/// a file the history copy still brings: a quiet ring where it will be, the
/// size of a photo when nothing gives one. still under reduced motion
class MediaArriving extends StatelessWidget {
  const MediaArriving({super.key});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.hasBoundedWidth ? c.maxWidth : 220.0;
        final h = c.hasBoundedHeight
            ? c.maxHeight
            : (w * 0.75).clamp(120.0, 240.0);
        return Semantics(
          label: l10n.albumOnItsWay,
          child: SizedBox(
            width: w,
            height: h,
            child: ColoredBox(
              color: HaloColors.surface2,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: still ? 0.3 : null,
                    color: HaloColors.amber,
                    backgroundColor: HaloColors.line,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// the picture fading up once decoded; under reduced motion, at once
class PictureFade extends StatelessWidget {
  const PictureFade({
    super.key,
    required this.shown,
    required this.still,
    required this.child,
  });
  final bool shown;
  final bool still;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: shown ? 1 : 0,
    duration: still ? Duration.zero : kPictureFade,
    curve: Curves.easeOut,
    child: child,
  );
}

/// a blur drawn as a mesh whose corners carry its colours, blended between
class BlurPainter extends CustomPainter {
  BlurPainter(this.blur, [this.fit = BoxFit.cover]);
  final PhotoBlur blur;
  final BoxFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fitted = applyBoxFit(
      fit,
      Size(blur.width.toDouble(), blur.height.toDouble()),
      size,
    );
    final at = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final cols = blur.cols, rows = blur.rows;
    final pos = Float32List((cols + 1) * (rows + 1) * 2);
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= cols; x++) {
        final k = (y * (cols + 1) + x) * 2;
        pos[k] = at.left + at.width * x / cols;
        pos[k + 1] = at.top + at.height * y / rows;
      }
    }
    final idx = Uint16List(cols * rows * 6);
    var n = 0;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final a = y * (cols + 1) + x, b = a + 1;
        final c = a + cols + 1, d = c + 1;
        idx
          ..[n++] = a
          ..[n++] = b
          ..[n++] = c
          ..[n++] = b
          ..[n++] = d
          ..[n++] = c;
      }
    }
    final v = ui.Vertices.raw(
      ui.VertexMode.triangles,
      pos,
      colors: blur.colors,
      indices: idx,
    );
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..drawVertices(v, BlendMode.dst, Paint())
      ..restore();
    v.dispose();
  }

  @override
  bool shouldRepaint(BlurPainter old) => old.blur != blur || old.fit != fit;
}

/// sized as an image of [natural] size would be in these constraints
class ShapedBox extends SingleChildRenderObjectWidget {
  const ShapedBox({super.key, required this.natural, super.child});
  final Size natural;

  @override
  RenderObject createRenderObject(BuildContext context) => _Shaped(natural);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _Shaped).natural = natural;
  }
}

class _Shaped extends RenderProxyBox {
  _Shaped(this._natural);
  Size _natural;
  set natural(Size v) {
    if (v == _natural) return;
    _natural = v;
    markNeedsLayout();
  }

  Size _sized(BoxConstraints c) =>
      c.constrainSizeAndAttemptToPreserveAspectRatio(_natural);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sized(constraints);

  @override
  double computeMinIntrinsicWidth(double height) =>
      _sized(BoxConstraints.tightForFinite(height: height)).width;
  @override
  double computeMaxIntrinsicWidth(double height) =>
      computeMinIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) =>
      _sized(BoxConstraints.tightForFinite(width: width)).height;
  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  void performLayout() {
    size = _sized(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}

/// keeps the size it last had while [held], drawing nothing, so a list
/// does not move under the lock
class HeldSize extends SingleChildRenderObjectWidget {
  const HeldSize({super.key, required this.held, super.child});
  final bool held;

  @override
  RenderObject createRenderObject(BuildContext context) => _Held(held);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _Held).held = held;
  }
}

class _Held extends RenderProxyBox {
  _Held(this._held);
  bool _held;
  Size? _last;
  set held(bool v) {
    if (v == _held) return;
    _held = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final last = _last;
    if (_held && last != null) {
      size = constraints.constrain(last);
      child?.layout(BoxConstraints.tight(size));
      return;
    }
    final c = child;
    if (c == null) {
      size = constraints.smallest;
    } else {
      c.layout(constraints, parentUsesSize: true);
      size = c.size;
    }
    if (!_held) _last = size;
  }

  // asked for its width or height while held: what it last had
  Size? get _kept => _held ? _last : null;

  @override
  Size computeDryLayout(BoxConstraints constraints) => switch (_kept) {
    final k? => constraints.constrain(k),
    null => super.computeDryLayout(constraints),
  };

  @override
  double computeMinIntrinsicWidth(double height) =>
      _kept?.width ?? super.computeMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicWidth(double height) =>
      _kept?.width ?? super.computeMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) =>
      _kept?.height ?? super.computeMinIntrinsicHeight(width);
  @override
  double computeMaxIntrinsicHeight(double width) =>
      _kept?.height ?? super.computeMaxIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_held) super.paint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      !_held && super.hitTestChildren(result, position: position);
}
