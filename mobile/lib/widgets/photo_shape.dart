// SPDX-License-Identifier: GPL-3.0-or-later
// a photo or a gif in a bubble at its own shape, as wide and as tall as it
// is within the bubble's bounds. the blur says the shape before the file
// decodes, the decoded picture when there is no blur yet. one past the
// floors, very tall or very wide, fills them and is cropped to them
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../photo_blur.dart' show blurNow;
import '../picture_lock.dart' show picturesShut;

/// the widest a photo in a bubble gets, on a computer's wide column too
const kPhotoMaxWidth = 420.0;

/// the tallest a photo in a bubble gets
const kPhotoMaxHeight = 360.0;

/// the narrowest and the flattest: past these it is cropped
const kPhotoMinWidth = 140.0;
const kPhotoMinHeight = 96.0;

/// the shape a picture is drawn at until its own is known
const kPhotoGuess = 4 / 3;

/// how wide a photo in a 1:1 bubble may get here
double photoMaxWidth(BuildContext context) =>
    math.min(MediaQuery.sizeOf(context).width * 0.78, kPhotoMaxWidth);

// the shapes read, for the life of the process: the box keeps its size
// under the lock and after it, as the remembered heights do
final Map<String, double> _aspects = {};

/// the width over the height of the picture at [path], when known
double? photoAspectOf(String path) {
  final b = blurNow(path);
  if (b != null && b.width > 0 && b.height > 0) {
    return _aspects[path] = b.width / b.height;
  }
  return _aspects[path];
}

@visibleForTesting
void rememberPhotoAspect(String path, double aspect) => _aspects[path] = aspect;

@visibleForTesting
void forgetPhotoAspects() => _aspects.clear();

/// the size of a picture of [aspect] in [maxWidth] by [maxHeight]: its own
/// shape, the floors past it
Size photoBoxSize(
  double aspect, {
  required double maxWidth,
  required double maxHeight,
  double minWidth = kPhotoMinWidth,
  double minHeight = kPhotoMinHeight,
}) {
  final a = aspect.isFinite && aspect > 0 ? aspect : kPhotoGuess;
  var w = maxWidth, h = maxWidth / a;
  if (h > maxHeight) {
    h = maxHeight;
    w = h * a;
  }
  w = math.max(w, math.min(minWidth, maxWidth));
  h = math.max(h, math.min(minHeight, maxHeight));
  return Size(w, h);
}

/// [child] at the shape of the picture at [path], which it fills
class PhotoShape extends StatefulWidget {
  const PhotoShape({
    super.key,
    required this.path,
    required this.image,
    required this.maxWidth,
    this.maxHeight = kPhotoMaxHeight,
    required this.child,
  });

  final String path;

  /// what the bubble decodes: its size is the shape when there is no blur
  final ImageProvider? image;
  final double maxWidth;
  final double maxHeight;
  final Widget child;

  @override
  State<PhotoShape> createState() => _PhotoShapeState();
}

class _PhotoShapeState extends State<PhotoShape> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    picturesShut.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _learn();
  }

  @override
  void didUpdateWidget(PhotoShape old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.image != widget.image) {
      _stop();
      _learn();
    }
  }

  @override
  void dispose() {
    picturesShut.removeListener(_changed);
    _stop();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (!picturesShut.value) _learn();
    setState(() {});
  }

  // no blur: the shape comes from the decode the picture makes anyway
  void _learn() {
    final image = widget.image;
    if (image == null || picturesShut.value || _stream != null) return;
    if (photoAspectOf(widget.path) != null) return;
    final path = widget.path;
    final l = ImageStreamListener(
      (info, _) {
        final w = info.image.width, h = info.image.height;
        info.dispose();
        _stop();
        if (w <= 0 || h <= 0 || path != widget.path) return;
        _aspects[path] = w / h;
        if (mounted) setState(() {});
      },
      // the picture draws its own error in the box
      onError: (_, _) => _stop(),
    );
    _listener = l;
    _stream = image.resolve(createLocalImageConfiguration(context))
      ..addListener(l);
  }

  void _stop() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
    _stream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    return _Shape(
      aspect: photoAspectOf(widget.path) ?? kPhotoGuess,
      maxWidth: widget.maxWidth,
      maxHeight: widget.maxHeight,
      child: widget.child,
    );
  }
}

class _Shape extends SingleChildRenderObjectWidget {
  const _Shape({
    required this.aspect,
    required this.maxWidth,
    required this.maxHeight,
    super.child,
  });
  final double aspect;
  final double maxWidth;
  final double maxHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShape(aspect, maxWidth, maxHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderShape)
      ..aspect = aspect
      ..maxWidth = maxWidth
      ..maxHeight = maxHeight;
  }
}

class _RenderShape extends RenderProxyBox {
  _RenderShape(this._aspect, this._maxWidth, this._maxHeight);
  double _aspect, _maxWidth, _maxHeight;

  set aspect(double v) {
    if (v == _aspect) return;
    _aspect = v;
    markNeedsLayout();
  }

  set maxWidth(double v) {
    if (v == _maxWidth) return;
    _maxWidth = v;
    markNeedsLayout();
  }

  set maxHeight(double v) {
    if (v == _maxHeight) return;
    _maxHeight = v;
    markNeedsLayout();
  }

  Size _sized(BoxConstraints c) => c.constrain(
    photoBoxSize(
      _aspect,
      maxWidth: math.min(_maxWidth, c.maxWidth),
      maxHeight: math.min(_maxHeight, c.maxHeight),
    ),
  );

  // asked by the bubble's IntrinsicWidth: the width it will take
  @override
  double computeMinIntrinsicWidth(double height) =>
      _sized(BoxConstraints(maxHeight: height)).width;
  @override
  double computeMaxIntrinsicWidth(double height) =>
      computeMinIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) =>
      _sized(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sized(constraints);

  @override
  void performLayout() {
    size = _sized(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}

/// words under a photo wrap at the photo's width instead of widening the
/// bubble past it
class PhotoLedWidth extends SingleChildRenderObjectWidget {
  const PhotoLedWidth({super.key, this.on = true, super.child});

  /// off: as the words would be without it
  final bool on;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLed(on);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderLed).on = on;
  }
}

class _RenderLed extends RenderProxyBox {
  _RenderLed(this._on);
  bool _on;
  set on(bool v) {
    if (v == _on) return;
    _on = v;
    markNeedsLayout();
  }

  @override
  double computeMaxIntrinsicWidth(double height) => _on
      ? super.computeMinIntrinsicWidth(height)
      : super.computeMaxIntrinsicWidth(height);
}
