// SPDX-License-Identifier: GPL-3.0-or-later
// geometric marks for the avatar picker. drawn, not shipped - no image
// assets, nothing to license, and the whole space exists in about a hundred
// lines. twelve marks x four rotations x the palette list is over a thousand
// distinct avatars, which is what the spec asked for without a folder of
// generated faces in the apk.
//
// they are stamps, not portraits: thick strokes, lots of air, the sort of
// thing that would be pressed into wax.

import 'dart:math' as math;

import 'package:flutter/material.dart';

const int markCount = 12;
const int rotCount = 4;

class AvatarMarkPainter extends CustomPainter {
  final int mark;
  final int rot;
  final Color color;
  const AvatarMarkPainter({
    required this.mark,
    required this.rot,
    required this.color,
  });

  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    // one stroke weight for everything, scaled - mixed weights read as an
    // accident rather than a set.
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    c.save();
    c.translate(w / 2, w / 2);
    c.rotate(rot * math.pi / 2);
    c.translate(-w / 2, -w / 2);

    final r = w * 0.26;
    final cx = w / 2, cy = w / 2;

    switch (mark % markCount) {
      case 0: // ring
        c.drawCircle(Offset(cx, cy), r, p);
        break;
      case 1: // crescent - a ring with a bite taken out
        c.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          -math.pi * 0.35,
          math.pi * 1.35,
          false,
          p,
        );
        break;
      case 2: // two arcs facing away
        for (final dir in [0.0, math.pi]) {
          c.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r),
            dir + math.pi * 0.15,
            math.pi * 0.7,
            false,
            p,
          );
        }
        break;
      case 3: // triangle
        final path = Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r * 0.92, cy + r * 0.6)
          ..lineTo(cx - r * 0.92, cy + r * 0.6)
          ..close();
        c.drawPath(path, p);
        break;
      case 4: // chevron pair
        for (var i = 0; i < 2; i++) {
          final o = (i - 0.5) * r * 0.75;
          c.drawPath(
            Path()
              ..moveTo(cx - r * 0.6, cy + o - r * 0.28)
              ..lineTo(cx, cy + o + r * 0.28)
              ..lineTo(cx + r * 0.6, cy + o - r * 0.28),
            p,
          );
        }
        break;
      case 5: // diamond
        c.drawPath(
          Path()
            ..moveTo(cx, cy - r)
            ..lineTo(cx + r * 0.8, cy)
            ..lineTo(cx, cy + r)
            ..lineTo(cx - r * 0.8, cy)
            ..close(),
          p,
        );
        break;
      case 6: // three dots, a slight arc
        for (var i = -1; i <= 1; i++) {
          c.drawCircle(
            Offset(
              cx + i * r * 0.75,
              cy + (i.abs() == 1 ? r * 0.22 : -r * 0.2),
            ),
            w * 0.062,
            fill,
          );
        }
        break;
      case 7: // bars
        for (var i = -1; i <= 1; i++) {
          final y = cy + i * r * 0.62;
          final half = r * (i == 0 ? 0.95 : 0.62);
          c.drawLine(Offset(cx - half, y), Offset(cx + half, y), p);
        }
        break;
      case 8: // cross, offset so it is a mark not a plus sign
        c.drawLine(Offset(cx - r * 0.85, cy), Offset(cx + r * 0.85, cy), p);
        c.drawLine(Offset(cx, cy - r * 0.85), Offset(cx, cy + r * 0.55), p);
        break;
      case 9: // wave
        final path = Path()..moveTo(cx - r, cy);
        path.cubicTo(
          cx - r * 0.4,
          cy - r * 0.85,
          cx + r * 0.4,
          cy + r * 0.85,
          cx + r,
          cy,
        );
        c.drawPath(path, p);
        break;
      case 10: // ring with a dot at the centre - an eye, barely
        c.drawCircle(Offset(cx, cy), r, p);
        c.drawCircle(Offset(cx, cy), w * 0.06, fill);
        break;
      default: // spiral hint: two nested arcs
        c.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          math.pi * 0.1,
          math.pi * 1.5,
          false,
          p,
        );
        c.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.48),
          math.pi * 1.1,
          math.pi * 1.4,
          false,
          p,
        );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant AvatarMarkPainter o) =>
      o.mark != mark || o.rot != rot || o.color != color;
}
