// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

// self-drawing onion for the tor boot screen. realistic bulb with fanned
// shoots and a root tuft; the outline sketches itself first, then the inner
// layers fill in, over a faint guide. our own mark, not the tor logo.
class OnionLoader extends StatefulWidget {
  final double size;
  final Color color;
  const OnionLoader({
    super.key,
    this.size = 120,
    this.color = const Color(0xFFF59E0B),
  });

  @override
  State<OnionLoader> createState() => _OnionLoaderState();
}

class _OnionLoaderState extends State<OnionLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => CustomPaint(
      size: Size(widget.size, widget.size * 162 / 120),
      painter: _OnionPainter(_c.value, widget.color),
    ),
  );
}

class _OnionPainter extends CustomPainter {
  final double t;
  final Color color;
  _OnionPainter(this.t, this.color);

  Path _structure() {
    final p = Path();
    p.moveTo(60, 50);
    p.cubicTo(40, 52, 26, 70, 26, 96);
    p.cubicTo(26, 120, 42, 134, 60, 134);
    p.cubicTo(78, 134, 94, 120, 94, 96);
    p.cubicTo(94, 70, 80, 52, 60, 50);
    p.close();
    p.moveTo(57, 50);
    p.cubicTo(51, 38, 48, 28, 50, 16);
    p.moveTo(59, 49);
    p.cubicTo(58, 34, 59, 24, 63, 13);
    p.moveTo(60, 49);
    p.cubicTo(62, 33, 66, 22, 72, 12);
    p.moveTo(61, 50);
    p.cubicTo(67, 37, 75, 28, 83, 21);
    p.moveTo(62, 51);
    p.cubicTo(70, 42, 78, 36, 86, 33);
    p.moveTo(54, 134);
    p.cubicTo(52, 141, 50, 146, 48, 151);
    p.moveTo(58, 134);
    p.cubicTo(57, 142, 56, 148, 55, 155);
    p.moveTo(60, 134);
    p.cubicTo(60, 143, 60, 150, 60, 157);
    p.moveTo(62, 134);
    p.cubicTo(63, 142, 64, 148, 65, 155);
    p.moveTo(66, 134);
    p.cubicTo(68, 141, 70, 146, 72, 151);
    return p;
  }

  Path _layers() {
    final p = Path();
    p.moveTo(52, 58);
    p.cubicTo(38, 70, 34, 94, 42, 122);
    p.moveTo(68, 58);
    p.cubicTo(82, 70, 86, 94, 78, 122);
    p.moveTo(57, 60);
    p.cubicTo(49, 72, 48, 96, 53, 120);
    p.moveTo(63, 60);
    p.cubicTo(71, 72, 72, 96, 67, 120);
    p.moveTo(60, 60);
    p.cubicTo(59, 86, 59, 108, 60, 128);
    return p;
  }

  void _drawPartial(Canvas c, Path path, double frac, Paint paint) {
    if (frac <= 0) return;
    if (frac >= 1) {
      c.drawPath(path, paint);
      return;
    }
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var budget = total * frac;
    for (final m in metrics) {
      if (budget <= 0) break;
      final take = budget >= m.length ? m.length : budget;
      c.drawPath(m.extractPath(0, take), paint);
      budget -= take;
    }
  }

  Paint _p(double w, Color col) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = col;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 162);
    final st = _structure();
    final ly = _layers();

    final guide = color.withValues(alpha: 0.18);
    canvas.drawPath(st, _p(1.5, guide));
    canvas.drawPath(ly, _p(1.3, guide));

    final fStruct = (t / 0.55).clamp(0.0, 1.0);
    final fLayer = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
    _drawPartial(canvas, st, fStruct, _p(2.2, const Color(0xFFFFD27A)));
    _drawPartial(canvas, ly, fLayer, _p(1.5, const Color(0xFFFBBF4D)));
  }

  @override
  bool shouldRepaint(covariant _OnionPainter old) =>
      old.t != t || old.color != color;
}
