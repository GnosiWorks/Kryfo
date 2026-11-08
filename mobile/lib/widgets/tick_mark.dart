// SPDX-License-Identifier: GPL-3.0-or-later
// the sent tick, drawn. a text check mark is left to whatever font the
// device finds for it, and some have none and draw an empty box
import 'package:flutter/widgets.dart';

class TickMark extends StatelessWidget {
  final Color color;
  // the font size the glyph had: the mark fills the same line box
  final double size;
  final String semanticLabel;
  const TickMark({
    super.key,
    required this.color,
    this.size = 11,
    this.semanticLabel = '✓',
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: CustomPaint(
      size: Size(size * 0.64, size),
      painter: _TickPainter(color),
    ),
  );
}

class _TickPainter extends CustomPainter {
  final Color color;
  _TickPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // as heavy as the bold glyph, short arm low, long arm up to cap height
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.1, h * 0.53)
        ..lineTo(w * 0.4, h * 0.78)
        ..lineTo(w * 0.92, h * 0.2),
      p,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.color != color;
}
