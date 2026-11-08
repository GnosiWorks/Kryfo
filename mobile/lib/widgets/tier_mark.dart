// SPDX-License-Identifier: GPL-3.0-or-later
// a supporter tier's mark (dot, diamond, star), drawn: the text glyphs are
// missing from our fonts and from some phones', which show an empty box
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../supporter.dart' show SupporterTier;

class TierMark extends StatelessWidget {
  final SupporterTier tier;
  final Color color;
  // the font size the glyph had: the mark fills a square that size
  final double size;
  const TierMark({
    super.key,
    required this.tier,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) => tier == SupporterTier.none
      ? const SizedBox.shrink()
      : CustomPaint(
          size: Size.square(size),
          painter: _TierPainter(tier, color),
        );
}

class _TierPainter extends CustomPainter {
  final SupporterTier tier;
  final Color color;
  _TierPainter(this.tier, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final u = s.shortestSide;
    final p = Paint()
      ..color = color
      ..isAntiAlias = true;
    switch (tier) {
      case SupporterTier.supporter:
        canvas.drawCircle(c, u * 0.3, p);
      case SupporterTier.patron:
        final r = u * 0.38;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r * 0.8, c.dy)
            ..lineTo(c.dx, c.dy + r)
            ..lineTo(c.dx - r * 0.8, c.dy)
            ..close(),
          p,
        );
      case SupporterTier.guardian:
        // four points, pinched in between
        final out = u * 0.46, inner = u * 0.13;
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final r = i.isEven ? out : inner;
          final a = -math.pi / 2 + i * math.pi / 4;
          final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path..close(), p);
      case SupporterTier.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_TierPainter old) =>
      old.tier != tier || old.color != color;
}
