// SPDX-License-Identifier: GPL-3.0-or-later
// an app icon as a home screen draws it: the plain ones from the same
// shapes android's art is written from (app_icon_art.dart), kryfo's as its
// amber ring on ink. the same in either theme, like the phone's icons
import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../app_icon_art.dart';

class AppFaceIcon extends StatelessWidget {
  final AppFace face;
  final double size;
  const AppFaceIcon({super.key, required this.face, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: CustomPaint(painter: _FacePainter(face)),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final AppFace face;
  const _FacePainter(this.face);

  @override
  void paint(Canvas canvas, Size size) {
    final art = plainArt[face.name];
    if (art == null) return _ring(canvas, size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Color(art.background));
    // a launcher shows the middle 72 of the 108 the art is drawn on
    final k = size.width / 72;
    canvas.save();
    canvas.scale(k);
    canvas.translate(-18, -18);
    for (final s in art.front) {
      _shape(canvas, s);
    }
    canvas.restore();
  }

  void _ring(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D0B09),
    );
    final c = size.center(Offset.zero);
    // kryfo_ring.svg: r 184.3 and a 38.4 stroke on 512, in the middle two
    // thirds an adaptive icon keeps
    final r = size.width * 0.26;
    final w = size.width * 0.054;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 1.33
        ..color = const Color(0x59F59E0B)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.03),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBC56B), Color(0xFFF59E0B), Color(0xFFC96A06)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.face != face;
}

void _shape(Canvas canvas, ArtShape s) {
  switch (s) {
    case ArtCircle c:
      canvas.drawCircle(
        Offset(c.cx, c.cy),
        c.r,
        Paint()..color = Color(c.color),
      );
    case ArtRect r:
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(r.x, r.y, r.w, r.h),
        Radius.circular(r.r),
      );
      final p = Paint()..color = Color(r.color);
      if (r.stroke != null) {
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.stroke!;
      }
      canvas.drawRRect(rr, p);
    case ArtLine l:
      canvas.drawLine(
        Offset(l.x1, l.y1),
        Offset(l.x2, l.y2),
        Paint()
          ..color = Color(l.color)
          ..strokeWidth = l.width
          ..strokeCap = StrokeCap.round,
      );
  }
}

/// the glyph a plain notification wears, in [color]
class AppFaceGlyph extends StatelessWidget {
  final AppFace face;
  final double size;
  final Color color;
  const AppFaceGlyph({
    super.key,
    required this.face,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _GlyphPainter(face, color)),
  );
}

class _GlyphPainter extends CustomPainter {
  final AppFace face;
  final Color color;
  const _GlyphPainter(this.face, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final shapes = plainArt[face.name]?.glyph ?? dotGlyph;
    canvas.save();
    canvas.scale(size.width / 24);
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
    for (final s in shapes) {
      _shape(canvas, s);
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 24, 24),
      Paint()
        ..color = color
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.face != face || old.color != color;
}
