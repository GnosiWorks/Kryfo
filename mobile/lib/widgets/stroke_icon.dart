// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

class StrokeIcon extends StatelessWidget {
  final List<String> paths;
  final double size;
  final Color color;
  final double stroke;
  // an arrow or a chevron: drawn the other way round in a right-to-left
  // language, as material's own arrows are
  final bool pointing;
  const StrokeIcon(
    this.paths, {
    super.key,
    this.size = 21,
    required this.color,
    this.stroke = 1.6,
    this.pointing = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StrokePainter(paths, color, stroke)),
    );
    if (!pointing || Directionality.of(context) != TextDirection.rtl) {
      return icon;
    }
    return Transform.flip(flipX: true, child: icon);
  }
}

class _StrokePainter extends CustomPainter {
  final List<String> paths;
  final Color color;
  final double stroke;
  _StrokePainter(this.paths, this.color, this.stroke);

  static final Map<String, Path> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k, k);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (final d in paths) {
      canvas.drawPath(_cache[d] ??= parseSvgPath(d), paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) =>
      old.color != color || old.stroke != stroke || old.paths != paths;
}

String svgCircle(double cx, double cy, double r) =>
    'M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0z';

String svgRect(double x, double y, double w, double h, [double rx = 0]) {
  if (rx <= 0) return 'M$x ${y}h${w}v${h}h${-w}z';
  return 'M${x + rx} ${y}h${w - 2 * rx}a$rx $rx 0 0 1 $rx ${rx}v${h - 2 * rx}'
      'a$rx $rx 0 0 1 ${-rx} ${rx}h${-(w - 2 * rx)}a$rx $rx 0 0 1 ${-rx} ${-rx}'
      'v${-(h - 2 * rx)}a$rx $rx 0 0 1 $rx ${-rx}z';
}

Path parseSvgPath(String d) {
  final path = Path();
  var i = 0;
  var cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0;
  double? px, py;
  var cmd = '';

  void skip() {
    while (i < d.length && (d[i] == ' ' || d[i] == ',' || d[i] == '\n')) {
      i++;
    }
  }

  double num() {
    skip();
    final start = i;
    if (i < d.length && (d[i] == '-' || d[i] == '+')) i++;
    var dot = false;
    while (i < d.length) {
      final c = d[i];
      if (c == '.') {
        if (dot) break;
        dot = true;
      } else if (c.codeUnitAt(0) < 48 || c.codeUnitAt(0) > 57) {
        break;
      }
      i++;
    }
    if (start == i) throw FormatException('number expected at $start in $d');
    return double.parse(d.substring(start, i));
  }

  bool flag() {
    skip();
    final c = d[i++];
    if (c != '0' && c != '1') throw FormatException('flag expected in $d');
    return c == '1';
  }

  while (true) {
    skip();
    if (i >= d.length) break;
    final c = d[i];
    if (RegExp('[a-zA-Z]').hasMatch(c)) {
      cmd = c;
      i++;
    } else if (cmd.isEmpty) {
      throw FormatException('command expected in $d');
    } else if (cmd == 'M') {
      cmd = 'L';
    } else if (cmd == 'm') {
      cmd = 'l';
    }
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? cx : 0.0, oy = rel ? cy : 0.0;
    var keep = false;
    switch (cmd.toUpperCase()) {
      case 'M':
        cx = ox + num();
        cy = oy + num();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
      case 'L':
        cx = ox + num();
        cy = oy + num();
        path.lineTo(cx, cy);
      case 'H':
        cx = ox + num();
        path.lineTo(cx, cy);
      case 'V':
        cy = oy + num();
        path.lineTo(cx, cy);
      case 'C':
        final x1 = ox + num(), y1 = oy + num();
        final x2 = ox + num(), y2 = oy + num();
        cx = ox + num();
        cy = oy + num();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
        px = x2;
        py = y2;
        keep = true;
      case 'S':
        final x1 = px == null ? cx : 2 * cx - px;
        final y1 = py == null ? cy : 2 * cy - py;
        final x2 = ox + num(), y2 = oy + num();
        cx = ox + num();
        cy = oy + num();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
        px = x2;
        py = y2;
        keep = true;
      case 'A':
        final rx = num(), ry = num(), rot = num();
        final large = flag(), sweep = flag();
        cx = ox + num();
        cy = oy + num();
        path.arcToPoint(
          Offset(cx, cy),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        cx = sx;
        cy = sy;
      default:
        throw FormatException('unsupported command $cmd in $d');
    }
    if (!keep) {
      px = null;
      py = null;
    }
  }
  return path;
}
