// SPDX-License-Identifier: GPL-3.0-or-later
// the atmosphere behind a conversation. yours, on this phone, never sent:
// the other person sees their own. a gradient wash or a quiet pattern as
// before, or a mood: a base tint, a bubble tint, how dim the room sits,
// and for some a very slow drift that stops the moment the app is away.
// every one keeps message text at full contrast; a mood that would not is
// not in this list.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

enum Atmo {
  none,
  ember,
  dusk,
  moss,
  rose,
  dots,
  grid,
  waves,
  rain,
  lateNight,
  warmAfternoon,
  snow,
  desert,
  paper,
}

Atmo atmoFromName(String? n) => switch (n) {
  'ember' => Atmo.ember,
  'dusk' => Atmo.dusk,
  'moss' => Atmo.moss,
  'rose' => Atmo.rose,
  'dots' => Atmo.dots,
  'grid' => Atmo.grid,
  'waves' => Atmo.waves,
  'rain' => Atmo.rain,
  'lateNight' => Atmo.lateNight,
  'warmAfternoon' => Atmo.warmAfternoon,
  'snow' => Atmo.snow,
  'desert' => Atmo.desert,
  'paper' => Atmo.paper,
  _ => Atmo.none,
};

bool atmoIsPattern(Atmo a) =>
    a == Atmo.dots || a == Atmo.grid || a == Atmo.waves;

bool atmoIsMood(Atmo a) => moodOf(a) != null;

Color atmoAccent(Atmo a) => switch (a) {
  Atmo.ember => HaloColors.amber,
  Atmo.dusk => HaloColors.violet,
  Atmo.moss => HaloColors.green,
  Atmo.rose => HaloColors.rose,
  Atmo.dots || Atmo.grid || Atmo.waves => HaloColors.text2,
  Atmo.none => HaloColors.surface,
  _ => moodOf(a)!.base,
};

String atmoLabel(Atmo a) => switch (a) {
  Atmo.none => 'none',
  Atmo.ember => 'ember',
  Atmo.dusk => 'dusk',
  Atmo.moss => 'moss',
  Atmo.rose => 'rose',
  Atmo.dots => 'dots',
  Atmo.grid => 'grid',
  Atmo.waves => 'waves',
  Atmo.rain => 'rain',
  Atmo.lateNight => 'late night',
  Atmo.warmAfternoon => 'warm afternoon',
  Atmo.snow => 'snow',
  Atmo.desert => 'desert',
  Atmo.paper => 'paper',
};

enum AtmoDrift { none, rain, snow, glow }

// a mood is a handful of values, not an asset. base is the room's tint,
// wash how strongly it lies over the surface, bubble how far the incoming
// bubble leans toward it, dim how much ink lies over everything. these are
// the only colours in the app that are not palette tokens, and they are
// tints laid over the palette at low alpha, never something text sits on
// at full strength.
class AtmoMood {
  final Color base;
  final double wash;
  final double bubble;
  final double dim;
  final AtmoDrift drift;
  const AtmoMood({
    required this.base,
    required this.wash,
    required this.bubble,
    this.dim = 0,
    this.drift = AtmoDrift.none,
  });
}

const _moods = <Atmo, AtmoMood>{
  Atmo.rain: AtmoMood(
    base: Color(0xFF2E3B4A),
    wash: 0.52,
    bubble: 0.35,
    dim: 0.12,
    drift: AtmoDrift.rain,
  ),
  Atmo.lateNight: AtmoMood(
    base: Color(0xFF1D1B33),
    wash: 0.68,
    bubble: 0.45,
    dim: 0.30,
  ),
  Atmo.warmAfternoon: AtmoMood(
    base: Color(0xFF6B4416),
    wash: 0.26,
    bubble: 0.28,
    drift: AtmoDrift.glow,
  ),
  Atmo.snow: AtmoMood(
    base: Color(0xFF9FB3C8),
    wash: 0.10,
    bubble: 0.16,
    drift: AtmoDrift.snow,
  ),
  Atmo.desert: AtmoMood(base: Color(0xFF9A7040), wash: 0.20, bubble: 0.26),
  Atmo.paper: AtmoMood(base: Color(0xFFE9DEC6), wash: 0.07, bubble: 0.12),
};

AtmoMood? moodOf(Atmo a) => _moods[a];

// the incoming bubble colour under the atmosphere in force here, or the
// palette's own when there is none
Color atmoBubbleIn(BuildContext context, [Color? fallback]) {
  final plain = fallback ?? HaloColors.bubbleIn;
  final atmo = AtmoScope.of(context);
  final mood = atmo == null ? null : moodOf(atmo);
  if (mood == null) return plain;
  return Color.lerp(plain, mood.base, mood.bubble)!;
}

// tells the bubbles which atmosphere the conversation is under
class AtmoScope extends InheritedWidget {
  final Atmo atmo;
  const AtmoScope({super.key, required this.atmo, required super.child});
  static Atmo? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AtmoScope>()?.atmo;
  @override
  bool updateShouldNotify(AtmoScope old) => old.atmo != atmo;
}

// the patterns, drawn in the line colour so they sit behind the bubbles
// without competing with them. scale lets the picker swatch show the same
// thing smaller.
class PatternPainter extends CustomPainter {
  final Atmo atmo;
  final double scale;
  PatternPainter(this.atmo, {this.scale = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = HaloColors.line2.withValues(alpha: 0.55)
      ..strokeWidth = 1 * scale
      ..style = PaintingStyle.stroke;
    switch (atmo) {
      case Atmo.dots:
        final step = 26.0 * scale;
        final fill = Paint()..color = HaloColors.line2.withValues(alpha: 0.7);
        for (var y = step / 2; y < size.height; y += step) {
          for (var x = step / 2; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), 1.2 * scale, fill);
          }
        }
      case Atmo.grid:
        final step = 34.0 * scale;
        for (var x = 0.0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (var y = 0.0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case Atmo.waves:
        final step = 30.0 * scale;
        final amp = 5.0 * scale;
        final len = 48.0 * scale;
        for (var y = step / 2; y < size.height + amp; y += step) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x <= size.width; x += 4) {
            path.lineTo(x, y + amp * math.sin(x / len * 2 * math.pi));
          }
          canvas.drawPath(path, p);
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(PatternPainter old) =>
      old.atmo != atmo || old.scale != scale;
}

// the slow element of a mood. phase runs 0..1 over about a minute and the
// painter only redraws eight times a second, so an hour of staring costs
// almost nothing and nothing moves fast enough to catch the eye
class _DriftPainter extends CustomPainter {
  final AtmoMood mood;
  final ValueListenable<double> phase;
  _DriftPainter(this.mood, this.phase) : super(repaint: phase);

  @override
  void paint(Canvas canvas, Size size) {
    final t = phase.value;
    final rnd = math.Random(7);
    switch (mood.drift) {
      case AtmoDrift.rain:
        final p = Paint()
          ..color = mood.base.withValues(alpha: 0.35)
          ..strokeWidth = 1;
        for (var i = 0; i < 36; i++) {
          final x0 = rnd.nextDouble() * size.width;
          final y0 = rnd.nextDouble() * size.height;
          final len = 14 + rnd.nextDouble() * 18;
          final speed = 0.6 + rnd.nextDouble() * 0.6;
          final y = (y0 + t * size.height * speed * 4) % (size.height + len);
          final x = x0 - (y - y0) * 0.08;
          canvas.drawLine(Offset(x, y - len), Offset(x - len * 0.08, y), p);
        }
      case AtmoDrift.snow:
        final p = Paint()..color = mood.base.withValues(alpha: 0.45);
        for (var i = 0; i < 28; i++) {
          final x0 = rnd.nextDouble() * size.width;
          final y0 = rnd.nextDouble() * size.height;
          final r = 1.2 + rnd.nextDouble() * 1.8;
          final speed = 0.4 + rnd.nextDouble() * 0.5;
          final sway = rnd.nextDouble() * 12;
          final y = (y0 + t * size.height * speed * 2) % (size.height + 8);
          final x = x0 + math.sin((t * 6 + i) * math.pi) * sway;
          canvas.drawCircle(Offset(x, y), r, p);
        }
      case AtmoDrift.glow:
        final cx =
            size.width * (0.2 + 0.6 * (0.5 + 0.5 * math.sin(t * 2 * math.pi)));
        final cy = size.height * 0.15;
        final radius = size.shortestSide * 0.9;
        final glow = Paint()
          ..shader =
              RadialGradient(
                colors: [
                  mood.base.withValues(alpha: 0.22),
                  mood.base.withValues(alpha: 0.0),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset(cx, cy), radius: radius),
              );
        canvas.drawCircle(Offset(cx, cy), radius, glow);
      case AtmoDrift.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_DriftPainter old) => old.mood != mood;
}

// paper's grain, static: a few faint fibres in the line colour
class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final p = Paint()
      ..color = HaloColors.line2.withValues(alpha: 0.35)
      ..strokeWidth = 0.6;
    for (var i = 0; i < 120; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final len = 6 + rnd.nextDouble() * 14;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + len, y + rnd.nextDouble() * 2 - 1),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}

class AtmosphereWash extends StatefulWidget {
  final Atmo atmo;
  const AtmosphereWash(this.atmo, {super.key});
  @override
  State<AtmosphereWash> createState() => _AtmosphereWashState();
}

class _AtmosphereWashState extends State<AtmosphereWash>
    with WidgetsBindingObserver {
  final _phase = ValueNotifier<double>(0);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didUpdateWidget(AtmosphereWash old) {
    super.didUpdateWidget(old);
    if (old.atmo != widget.atmo) _start();
  }

  void _start() {
    _tick?.cancel();
    _tick = null;
    final mood = moodOf(widget.atmo);
    if (mood == null || mood.drift == AtmoDrift.none) return;
    _tick = Timer.periodic(const Duration(milliseconds: 125), (_) {
      _phase.value = (_phase.value + 1 / 480) % 1.0;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atmo = widget.atmo;
    if (atmo == Atmo.none) return const SizedBox.shrink();
    if (atmoIsPattern(atmo)) {
      return IgnorePointer(
        child: CustomPaint(painter: PatternPainter(atmo), size: Size.infinite),
      );
    }
    final mood = moodOf(atmo);
    if (mood != null) {
      return IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: mood.base.withValues(alpha: mood.wash)),
            ),
            if (mood.dim > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: HaloColors.ink.withValues(alpha: mood.dim),
                ),
              ),
            if (atmo == Atmo.paper)
              Positioned.fill(
                child: CustomPaint(
                  painter: _GrainPainter(),
                  size: Size.infinite,
                ),
              ),
            if (mood.drift != AtmoDrift.none)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DriftPainter(mood, _phase),
                  size: Size.infinite,
                ),
              ),
          ],
        ),
      );
    }
    final accent = atmoAccent(atmo);
    final deep = Color.lerp(accent, HaloColors.ink, 0.55)!;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.17),
                    accent.withValues(alpha: 0.05),
                    deep.withValues(alpha: 0.13),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -1.0),
                  radius: 1.2,
                  colors: [
                    accent.withValues(alpha: 0.15),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
