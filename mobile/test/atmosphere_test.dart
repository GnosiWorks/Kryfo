// SPDX-License-Identifier: GPL-3.0-or-later
// the drift behind a chat: a still with reduced motion, nothing under a
// covering page or out of the app, and only the steps a slow drift needs,
// each drawn where the frame by frame drift would have been.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/atmosphere.dart';

const _frame = Duration(microseconds: 16667);

Widget _host(Atmo a, {bool reduce = false, bool ticking = true}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: reduce,
        ),
        child: TickerMode(enabled: ticking, child: AtmosphereWash(a)),
      ),
    );

Finder get _drift => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint && w.painter.runtimeType.toString() == '_DriftPainter',
);

double _phase(WidgetTester t) {
  final p = t.widget<CustomPaint>(_drift).painter! as dynamic;
  return (p.phase as ValueNotifier<double>).value;
}

Future<void> _frames(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    await t.pump(_frame);
  }
}

void main() {
  setUp(() => AtmosphereWash.frames = 0);

  testWidgets('reduced motion: the rain stands still and asks for no frame', (
    t,
  ) async {
    await t.pumpWidget(_host(Atmo.rain, reduce: true));
    await _frames(t, 60);
    expect(AtmosphereWash.frames, 0);
    expect(t.binding.hasScheduledFrame, false);
    // still there, as a still
    expect(_drift, findsOneWidget);
    expect(_phase(t), 0);
  });

  testWidgets('reduced motion switched on mid drift: it stops where it is', (
    t,
  ) async {
    await t.pumpWidget(_host(Atmo.snow));
    await _frames(t, 60);
    final at = _phase(t);
    expect(at, greaterThan(0));
    await t.pumpWidget(_host(Atmo.snow, reduce: true));
    final steps = AtmosphereWash.frames;
    await _frames(t, 120);
    expect(AtmosphereWash.frames, steps);
    expect(_phase(t), at);
    expect(t.binding.hasScheduledFrame, false);
  });

  testWidgets('each drift steps only as often as it needs', (t) async {
    for (final (a, fps) in [
      (Atmo.rain, 30),
      (Atmo.snow, 20),
      (Atmo.warmAfternoon, 20),
    ]) {
      await t.pumpWidget(const SizedBox());
      AtmosphereWash.frames = 0;
      await t.pumpWidget(_host(a));
      var waiting = 0;
      for (var i = 0; i < 120; i++) {
        await t.pump(_frame);
        // between steps nothing asks for a frame: the screen rests
        if (t.binding.hasScheduledFrame) waiting++;
      }
      expect(AtmosphereWash.frames, inInclusiveRange(2 * fps - 2, 2 * fps));
      expect(waiting, 0, reason: '$a');
    }
  });

  testWidgets('the drift is where a frame by frame one would be', (t) async {
    await t.pumpWidget(_host(Atmo.rain));
    await _frames(t, 180);
    // three seconds of a drift that turns once a minute, within one step
    expect(_phase(t), closeTo(3 / 60, (1 / 30) / 60 + 1e-9));
  });

  testWidgets('under a covering page nothing runs; it goes on from there', (
    t,
  ) async {
    await t.pumpWidget(_host(Atmo.rain));
    await _frames(t, 60);
    await t.pumpWidget(_host(Atmo.rain, ticking: false));
    await _frames(t, 3);
    final steps = AtmosphereWash.frames;
    final at = _phase(t);
    await _frames(t, 600);
    expect(AtmosphereWash.frames, steps);
    expect(t.binding.hasScheduledFrame, false);

    await t.pumpWidget(_host(Atmo.rain));
    await _frames(t, 2);
    // on from where it stood, not ten seconds on
    expect(_phase(t) - at, lessThan(0.2 / 60));
    await _frames(t, 30);
    expect(AtmosphereWash.frames, greaterThan(steps + 10));
  });

  testWidgets('out of the app nothing runs; back in, it goes on', (t) async {
    await t.pumpWidget(_host(Atmo.warmAfternoon));
    await _frames(t, 30);
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    final steps = AtmosphereWash.frames;
    await _frames(t, 600);
    expect(AtmosphereWash.frames, steps);
    expect(t.binding.hasScheduledFrame, false);
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    await _frames(t, 60);
    expect(AtmosphereWash.frames, greaterThan(steps + 15));
  });

  testWidgets('a still atmosphere never ticks', (t) async {
    for (final a in [Atmo.none, Atmo.ember, Atmo.dots, Atmo.lateNight]) {
      await t.pumpWidget(_host(a));
      await _frames(t, 10);
      expect(t.binding.hasScheduledFrame, false, reason: '$a');
    }
    expect(AtmosphereWash.frames, 0);
  });
}
