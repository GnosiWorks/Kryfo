import 'dart:math';
import 'package:flutter/material.dart';

// big animated onion for the tor send / loading state. our own mark, not the
// tor logo. inner layers pulse outward; bulb and sprouts hold still.
class OnionLoader extends StatefulWidget {
  final double size;
  final Color color;
  const OnionLoader({super.key, this.size = 120, this.color = const Color(0xFFF59E0B)});

  @override
  State<OnionLoader> createState() => _OnionLoaderState();
}

class _OnionLoaderState extends State<OnionLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size(widget.size, widget.size * 150 / 120),
          painter: _OnionPainter(_c.value, widget.color),
        ),
      );
}

class _OnionPainter extends CustomPainter {
  final double t;
  final Color color;
  _OnionPainter(this.t, this.color);

  double _pulse(double phase) => 0.25 + ((sin((t - phase) * 2 * pi) + 1) / 2) * 0.75;

  Paint _stroke(double w, double a) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = w
    ..color = color.withOpacity(a);

  Path _p(void Function(Path) build) {
    final p = Path();
    build(p);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 150);

    canvas.drawPath(
        _p((p) => p
          ..moveTo(58, 56)
          ..cubicTo(38, 58, 24, 76, 24, 100)
          ..cubicTo(24, 126, 40, 140, 58, 140)
          ..cubicTo(76, 140, 92, 126, 92, 100)
          ..cubicTo(92, 76, 78, 58, 58, 56)
          ..close()),
        _stroke(2.6, 1));

    canvas.drawPath(
        _p((p) => p
          ..moveTo(50, 60)
          ..cubicTo(54, 56, 62, 56, 67, 61)),
        _stroke(1.8, 1));

    final List<List<double>> blades = [
      [56, 56, 52, 42, 50, 32, 53, 20],
      [58, 55, 57, 38, 59, 26, 64, 15],
      [59, 55, 63, 37, 70, 24, 79, 13],
      [60, 56, 67, 41, 78, 32, 89, 26],
    ];
    for (final b in blades) {
      canvas.drawPath(
          _p((p) => p
            ..moveTo(b[0], b[1])
            ..cubicTo(b[2], b[3], b[4], b[5], b[6], b[7])),
          _stroke(2.2, 1));
    }

    final outer = _pulse(0.4);
    canvas.drawPath(_p((p) => p..moveTo(49, 70)..cubicTo(37, 84, 35, 104, 41, 124)), _stroke(1.6, outer));
    canvas.drawPath(_p((p) => p..moveTo(67, 70)..cubicTo(79, 84, 81, 104, 75, 124)), _stroke(1.6, outer));

    final mid = _pulse(0.2);
    canvas.drawPath(_p((p) => p..moveTo(58, 64)..cubicTo(50, 82, 49, 108, 55, 130)), _stroke(1.6, mid));
    canvas.drawPath(_p((p) => p..moveTo(58, 64)..cubicTo(66, 82, 67, 108, 61, 130)), _stroke(1.6, mid));

    canvas.drawPath(_p((p) => p..moveTo(58, 62)..lineTo(58, 132)), _stroke(1.6, _pulse(0)));
  }

  @override
  bool shouldRepaint(covariant _OnionPainter old) => old.t != t || old.color != color;
}
