// SPDX-License-Identifier: GPL-3.0-or-later
// the house inline notice: a 14px stroked glyph, terse lowercase text, on a
// faint tint of one accent colour. no border, no pill, no emoji. used for
// vouches, the scam shield and burner rooms so they all read as one voice.
import 'package:flutter/material.dart';
import '../theme.dart';

enum NoticeGlyph { people, shield, clock, link }

class NoticeBanner extends StatefulWidget {
  final NoticeGlyph glyph;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  final Duration delay;
  final EdgeInsets margin;
  const NoticeBanner({
    super.key,
    required this.glyph,
    required this.text,
    required this.color,
    this.onTap,
    this.delay = Duration.zero,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<NoticeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _in.forward();
    });
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(
      parent: _in,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    );
    final body = Container(
      margin: widget.margin,
      padding: const EdgeInsets.fromLTRB(11, 9, 12, 9),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(14, 14),
            painter: _GlyphPainter(widget.glyph, widget.color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              widget.text,
              style: HaloType.sans(
                size: 12.5,
                weight: FontWeight.w500,
                color: widget.color,
                height: 1.35,
              ),
            ),
          ),
          if (widget.onTap != null)
            Icon(Icons.chevron_right, size: 16, color: widget.color),
        ],
      ),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(rise),
        alignment: Alignment.topCenter,
        child: widget.onTap == null
            ? body
            : GestureDetector(
                onTapDown: (_) => setState(() => _down = true),
                onTapUp: (_) => setState(() => _down = false),
                onTapCancel: () => setState(() => _down = false),
                onTap: widget.onTap,
                child: AnimatedScale(
                  scale: _down ? 0.98 : 1,
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOut,
                  child: body,
                ),
              ),
      ),
    );
  }
}

// stroke 2, round caps, drawn in the banner colour. 14px box.
class _GlyphPainter extends CustomPainter {
  final NoticeGlyph glyph;
  final Color color;
  _GlyphPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    switch (glyph) {
      case NoticeGlyph.people:
        canvas.drawCircle(Offset(w * 0.36, h * 0.3), w * 0.16, p);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.08, h * 0.92)
            ..quadraticBezierTo(w * 0.1, h * 0.55, w * 0.36, h * 0.55)
            ..quadraticBezierTo(w * 0.62, h * 0.55, w * 0.64, h * 0.92),
          p,
        );
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w * 0.7, h * 0.32), radius: w * 0.14),
          -1.9,
          3.5,
          false,
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.74, h * 0.58)
            ..quadraticBezierTo(w * 0.92, h * 0.62, w * 0.94, h * 0.92),
          p,
        );
      case NoticeGlyph.shield:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.08)
            ..lineTo(w * 0.88, h * 0.24)
            ..cubicTo(w * 0.88, h * 0.62, w * 0.72, h * 0.82, w * 0.5, h * 0.94)
            ..cubicTo(
              w * 0.28,
              h * 0.82,
              w * 0.12,
              h * 0.62,
              w * 0.12,
              h * 0.24,
            )
            ..close(),
          p,
        );
      case NoticeGlyph.clock:
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.42, p);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.26)
            ..lineTo(w * 0.5, h * 0.52)
            ..lineTo(w * 0.7, h * 0.64),
          p,
        );
      case NoticeGlyph.link:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.42, h * 0.3)
            ..lineTo(w * 0.56, h * 0.16)
            ..arcToPoint(
              Offset(w * 0.84, h * 0.44),
              radius: Radius.circular(w * 0.2),
            )
            ..lineTo(w * 0.7, h * 0.58),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.58, h * 0.7)
            ..lineTo(w * 0.44, h * 0.84)
            ..arcToPoint(
              Offset(w * 0.16, h * 0.56),
              radius: Radius.circular(w * 0.2),
            )
            ..lineTo(w * 0.3, h * 0.42),
          p,
        );
        canvas.drawLine(
          Offset(w * 0.38, h * 0.62),
          Offset(w * 0.62, h * 0.38),
          p,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
