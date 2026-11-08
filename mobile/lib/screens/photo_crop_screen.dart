// SPDX-License-Identifier: GPL-3.0-or-later
// a profile photo's round crop: the picture moves and scales under a
// circle, and always covers it. pops the square it chose, in the
// picture's own pixels, or null
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime, motionStill;
import '../widgets/press_scale.dart';

/// the square a crop chose, in the picture's pixels
typedef PhotoSquare = ({int left, int top, int side});

/// how far past the cover a picture scales
const kCropZoomMost = 6.0;

/// the circle's gap to the screen's sides
const kCropInset = 24.0;

/// where the picture sits under a circle of [circle] across: [scale] over
/// the one that just covers it, the picture's centre [offset] from the
/// circle's. what the crop keeps of a [w] by [h] picture
PhotoSquare cropSquare({
  required double w,
  required double h,
  required double circle,
  required double scale,
  required Offset offset,
}) {
  final px = circle / math.min(w, h) * scale;
  final side = (circle / px).clamp(1.0, math.min(w, h));
  final cx = w / 2 - offset.dx / px;
  final cy = h / 2 - offset.dy / px;
  final left = (cx - side / 2).clamp(0.0, w - side);
  final top = (cy - side / 2).clamp(0.0, h - side);
  return (left: left.round(), top: top.round(), side: side.floor());
}

/// [o] held so the picture still covers the circle
Offset cropClamp({
  required double w,
  required double h,
  required double circle,
  required double scale,
  required Offset o,
}) {
  final px = circle / math.min(w, h) * scale;
  final mx = math.max(0.0, (w * px - circle) / 2);
  final my = math.max(0.0, (h * px - circle) / 2);
  return Offset(o.dx.clamp(-mx, mx), o.dy.clamp(-my, my));
}

class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.bytes});

  /// an upright picture with no tags
  final Uint8List bytes;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen>
    with SingleTickerProviderStateMixin {
  ui.Size? _size;
  bool _failed = false;
  double _scale = 1;
  Offset _offset = Offset.zero;
  // where a gesture began
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  double _circle = 300;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: kHouseTime,
  );
  Animation<double>? _scaleAnim;
  Animation<Offset>? _offsetAnim;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      setState(() {
        _scale = _scaleAnim?.value ?? _scale;
        _offset = _offsetAnim?.value ?? _offset;
      });
    });
    _read();
  }

  Future<void> _read() async {
    try {
      final buf = await ui.ImmutableBuffer.fromUint8List(widget.bytes);
      final desc = await ui.ImageDescriptor.encoded(buf);
      final s = ui.Size(desc.width.toDouble(), desc.height.toDouble());
      desc.dispose();
      buf.dispose();
      if (!mounted) return;
      setState(() => _size = s.isEmpty ? null : s);
      if (s.isEmpty) setState(() => _failed = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  Offset _held(double scale, Offset o) {
    final s = _size!;
    return cropClamp(
      w: s.width,
      h: s.height,
      circle: _circle,
      scale: scale,
      o: o,
    );
  }

  // to [scale] and [o], eased on the house curve, or at once when motion
  // is still
  void _goTo(double scale, Offset o) {
    if (motionStill(context)) {
      setState(() {
        _scale = scale;
        _offset = o;
      });
      return;
    }
    final curve = CurvedAnimation(parent: _settle, curve: kHouseCurve);
    _scaleAnim = Tween(begin: _scale, end: scale).animate(curve);
    _offsetAnim = Tween(begin: _offset, end: o).animate(curve);
    _settle.forward(from: 0);
  }

  void _start(ScaleStartDetails d, Offset centre) {
    _settle.stop();
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = d.localFocalPoint - centre;
  }

  void _update(ScaleUpdateDetails d, Offset centre) {
    final focal = d.localFocalPoint - centre;
    // past the ends it gives a little, and settles back on release
    var next = _startScale * d.scale;
    if (next < 1) next = 1 - (1 - next) * 0.35;
    if (next > kCropZoomMost) {
      next = kCropZoomMost + (next - kCropZoomMost) * 0.35;
    }
    // the point under the fingers stays under them
    final o = focal - (_startFocal - _startOffset) * (next / _startScale);
    final held = _held(next, o);
    setState(() {
      _scale = next;
      _offset = held + (o - held) * 0.35;
    });
  }

  void _end() {
    final scale = _scale.clamp(1.0, kCropZoomMost);
    final o = _held(scale, _offset);
    if (scale != _scale || o != _offset) _goTo(scale, o);
  }

  // a double tap goes in on that point, or back out to the cover
  void _doubleTap(Offset at, Offset centre) {
    if (_scale > 1.5) {
      _goTo(1, _held(1, Offset.zero));
      return;
    }
    const to = 2.5;
    final focal = at - centre;
    final o = focal - (focal - _offset) * (to / _scale);
    _goTo(to, _held(to, o));
  }

  void _zoomBy(double f) {
    final next = (_scale * f).clamp(1.0, kCropZoomMost);
    _goTo(next, _held(next, _offset * (next / _scale)));
  }

  int _pctAt(double s) => (s.clamp(1.0, kCropZoomMost) * 100).round();

  void _use() {
    final s = _size;
    if (s == null) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop<PhotoSquare>(
      cropSquare(
        w: s.width,
        h: s.height,
        circle: _circle,
        scale: _scale.clamp(1.0, kCropZoomMost),
        offset: _held(_scale.clamp(1.0, kCropZoomMost), _offset),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: haloOverlayOnDark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.photoCropTitle,
                    textAlign: TextAlign.center,
                    style: HaloType.sans(
                      size: 17,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(child: _stage()),
              _bar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage() {
    final s = _size;
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.photoCouldNotUse,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 15, color: Colors.white),
          ),
        ),
      );
    }
    if (s == null) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, box) {
        _circle = math.max(
          120.0,
          math.min(box.maxWidth, box.maxHeight) - 2 * kCropInset,
        );
        final centre = Offset(box.maxWidth / 2, box.maxHeight / 2);
        final px = _circle / math.min(s.width, s.height) * _scale;
        final pct = (_scale * 100).round();
        return Semantics(
          label: l10n.photoCropLabel,
          value: '$pct%',
          increasedValue: '${_pctAt(_scale * 1.25)}%',
          decreasedValue: '${_pctAt(_scale / 1.25)}%',
          onIncrease: () => _zoomBy(1.25),
          onDecrease: () => _zoomBy(1 / 1.25),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) => _start(d, centre),
            onScaleUpdate: (d) => _update(d, centre),
            onScaleEnd: (_) => _end(),
            onDoubleTapDown: (d) => _startFocal = d.localPosition,
            onDoubleTap: () => _doubleTap(_startFocal, centre),
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: centre.dx + _offset.dx - s.width * px / 2,
                    top: centre.dy + _offset.dy - s.height * px / 2,
                    width: s.width * px,
                    height: s.height * px,
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CirclePainter(circle: _circle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Row(
      children: [
        Expanded(
          child: PressScale(
            onTap: () => Navigator.of(context).pop(),
            scale: 0.96,
            label: l10n.commonCancel,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                l10n.commonCancel,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 16,
                  weight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PressScale(
            onTap: _size == null ? null : _use,
            scale: 0.96,
            label: l10n.photoCropUse,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                l10n.photoCropUse,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: HaloColors.onAmber,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// the dim around the circle and its thin ring
class _CirclePainter extends CustomPainter {
  _CirclePainter({required this.circle});
  final double circle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final hole = Rect.fromCircle(center: c, radius: circle / 2);
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(hole);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.62));
    canvas.drawOval(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_CirclePainter old) => old.circle != circle;
}
