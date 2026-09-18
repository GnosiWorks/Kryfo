// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tools/geo.dart';

class OfflineMap extends StatefulWidget {
  final GeoWorld world;
  final GeoPlaces places;
  final double lat;
  final double lon;
  final Animation<double> reveal;
  final String label;
  const OfflineMap({
    super.key,
    required this.world,
    required this.places,
    required this.lat,
    required this.lon,
    required this.reveal,
    required this.label,
  });

  @override
  State<OfflineMap> createState() => _OfflineMapState();
}

class _OfflineMapState extends State<OfflineMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  _Scene? _scene;
  Size? _sceneSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  _Scene _build(Size size) {
    final hit = widget.world.at(widget.lat, widget.lon);
    final v = viewFor(
      widget.lat,
      widget.lon,
      hit?.ring,
      size.width / size.height,
    );
    Offset at(double lon, double lat) => Offset(
      (lon - v.west) / (v.east - v.west) * size.width,
      (v.north - lat) / (v.north - v.south) * size.height,
    );
    final land = Path(), home = Path();
    for (final c in widget.world.countries) {
      for (final r in c.rings) {
        if (r.east < v.west ||
            r.west > v.east ||
            r.north < v.south ||
            r.south > v.north) {
          continue;
        }
        final into = identical(c, hit?.country) ? home : land;
        for (var i = 0; i < r.length; i++) {
          final p = at(r.lon[i], r.lat[i]);
          i == 0 ? into.moveTo(p.dx, p.dy) : into.lineTo(p.dx, p.dy);
        }
        into.close();
      }
    }
    final span = v.east - v.west;
    final step = span > 60
        ? 20.0
        : span > 25
        ? 10.0
        : span > 10
        ? 5.0
        : 2.0;
    final grid = Path();
    for (var x = (v.west / step).ceil() * step; x < v.east; x += step) {
      final p = at(x, 0);
      grid
        ..moveTo(p.dx, 0)
        ..lineTo(p.dx, size.height);
    }
    for (var y = (v.south / step).ceil() * step; y < v.north; y += step) {
      final p = at(0, y);
      grid
        ..moveTo(0, p.dy)
        ..lineTo(size.width, p.dy);
    }
    final pin = at(widget.lon, widget.lat);
    final towns = <_Town>[];
    for (final t in widget.places.biggestIn(
      v.west,
      v.east,
      v.south,
      v.north,
      count: 8,
      apart: span / 7,
    )) {
      final p = at(t.lon, t.lat);
      if ((p - pin).distance < 46) continue;
      if (p.dx < 14 || p.dx > size.width - 70) continue;
      if (p.dy < 40 || p.dy > size.height - 44) continue;
      towns.add(_Town(t.name.toUpperCase(), p));
      if (towns.length == 4) break;
    }
    return _Scene(land, home, grid, pin, towns);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      image: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          if (_scene == null || _sceneSize != size) {
            _scene = _build(size);
            _sceneSize = size;
          }
          return RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: _MapPainter(
                scene: _scene!,
                reveal: widget.reveal,
                pulse: _pulse,
                ground: HaloColors.ink,
                landFill: HaloColors.surface2,
                landLine: HaloColors.warm.withValues(alpha: 0.38),
                gridLine: HaloColors.line.withValues(alpha: 0.7),
                amber: HaloColors.amber,
                warm: HaloColors.warm,
                ink: HaloColors.amberInk,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Town {
  final String name;
  final Offset at;
  const _Town(this.name, this.at);
}

class _Scene {
  final Path land;
  final Path home;
  final Path grid;
  final Offset pin;
  final List<_Town> towns;
  const _Scene(this.land, this.home, this.grid, this.pin, this.towns);
}

double _span(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

class _MapPainter extends CustomPainter {
  final _Scene scene;
  final Animation<double> reveal;
  final Animation<double> pulse;
  final Color ground, landFill, landLine, gridLine, amber, warm, ink;
  _MapPainter({
    required this.scene,
    required this.reveal,
    required this.pulse,
    required this.ground,
    required this.landFill,
    required this.landLine,
    required this.gridLine,
    required this.amber,
    required this.warm,
    required this.ink,
  }) : super(repaint: Listenable.merge([reveal, pulse]));

  @override
  void paint(Canvas canvas, Size size) {
    final t = reveal.value;
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    canvas.drawPath(
      scene.grid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = gridLine,
    );

    final land = Curves.easeOutCubic.transform(_span(t, 0, 0.5));
    canvas.drawPath(
      scene.land,
      Paint()..color = landFill.withValues(alpha: landFill.a * land),
    );
    canvas.drawPath(
      scene.home,
      Paint()
        ..color = Color.alphaBlend(
          amber.withValues(alpha: 0.10),
          landFill,
        ).withValues(alpha: land),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1
      ..color = landLine.withValues(alpha: landLine.a * land);
    canvas.drawPath(scene.land, line);
    canvas.drawPath(
      scene.home,
      line
        ..strokeWidth = 1.3
        ..color = amber.withValues(alpha: 0.55 * land),
    );

    final names = _span(t, 0.45, 0.7);
    if (names > 0) {
      for (final town in scene.towns) {
        canvas.drawCircle(
          town.at,
          2,
          Paint()..color = warm.withValues(alpha: 0.7 * names),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: town.name,
            style: HaloType.mono(
              size: 8.5,
              letter: 0.06,
              color: warm.withValues(alpha: names),
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 110);
        tp.paint(canvas, town.at + Offset(5, -tp.height / 2));
      }
    }

    final drop = _span(t, 0.55, 0.9);
    if (drop <= 0) return;
    final p = scene.pin;
    if (drop >= 1 && pulse.isAnimating) {
      final k = pulse.value;
      canvas.drawCircle(
        p,
        4 + 22 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = amber.withValues(alpha: 0.9 * (1 - k)),
      );
    }
    final fall = Curves.easeOutBack.transform(drop);
    final tip = p + Offset(0, -34 * (1 - fall));
    final head = tip + const Offset(0, -15);
    final body = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(head.dx - 10, head.dy + 5, head.dx - 8, head.dy)
      ..arcToPoint(head + const Offset(8, 0), radius: const Radius.circular(8))
      ..quadraticBezierTo(head.dx + 10, head.dy + 5, tip.dx, tip.dy)
      ..close();
    final seen = math.min(1.0, drop * 3);
    canvas.drawCircle(
      p,
      2.2,
      Paint()..color = amber.withValues(alpha: 0.5 * seen),
    );
    canvas.drawPath(body, Paint()..color = amber.withValues(alpha: seen));
    canvas.drawCircle(head, 3, Paint()..color = ink.withValues(alpha: seen));
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      !identical(old.scene, scene) || old.ground != ground;
}
