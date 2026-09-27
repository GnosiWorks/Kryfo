// SPDX-License-Identifier: GPL-3.0-or-later
// a screen's timers run only while it is seen: nothing in the background or
// under a page pushed over it, everything that fell due at once on the way
// back, and a burn never a moment later than its deadline.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/seen_timers.dart';

class _Probe extends StatefulWidget {
  const _Probe(this.clock, this.setup);
  final int Function() clock;
  final void Function(SeenTimers timers) setup;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final _timers = SeenTimers(clock: widget.clock);

  @override
  void initState() {
    super.initState();
    widget.setup(_timers);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timers.watch(context);
  }

  @override
  void dispose() {
    _timers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

int _now(WidgetTester t) => t.binding.clock.now().millisecondsSinceEpoch;

Future<void> _leave(WidgetTester t) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    t.binding.handleAppLifecycleStateChanged(s);
  }
  await t.pump();
}

Future<void> _return(WidgetTester t) async {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    t.binding.handleAppLifecycleStateChanged(s);
  }
  await t.pump();
}

// a chat's burn in small: deadlines, burnt when their time comes
class _Burns {
  _Burns(this.t, this.start);
  final WidgetTester t;
  final int start;
  final deadlines = <int>[];
  // (ms since start, ran as the catch-up)
  final burnt = <(int, bool)>[];
  int looks = 0;
  late SeenJob job;

  void add(int msFromStart) => deadlines.add(start + msFromStart);

  void setup(SeenTimers timers) {
    job = timers.until(
      () => burnWait(
        _now(t),
        ghosts: deadlines.isNotEmpty,
        soonest: deadlines.isEmpty ? null : deadlines.reduce(math.min),
      ),
      (back) {
        looks++;
        final now = _now(t);
        deadlines.removeWhere((d) {
          if (d > now) return false;
          burnt.add((now - start, back));
          return true;
        });
      },
    );
  }
}

void main() {
  testWidgets('in the background nothing runs; back in front it catches up', (
    t,
  ) async {
    final runs = <int>[];
    await t.pumpWidget(
      MaterialApp(
        home: _Probe(
          () => _now(t),
          (s) => s.every(const Duration(seconds: 1), () => runs.add(_now(t))),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 3));
    expect(runs.length, 3);

    await _leave(t);
    await t.pump(const Duration(minutes: 10));
    expect(runs.length, 3);

    await _return(t);
    // at once, not a second later
    expect(runs.length, 4);
    await t.pump(const Duration(seconds: 1));
    expect(runs.length, 5);
  });

  testWidgets('a page over it stops it; popping back catches up', (t) async {
    final runs = <int>[];
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: _Probe(
          () => _now(t),
          (s) => s.every(const Duration(seconds: 1), () => runs.add(_now(t))),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 2));
    expect(runs.length, 2);

    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await t.pumpAndSettle();
    final covered = runs.length;
    await t.pump(const Duration(minutes: 5));
    expect(runs.length, covered);

    nav.currentState!.pop();
    // the page starts to leave: the screen under it is seen again
    await t.pump();
    expect(runs.length, covered + 1);
    await t.pumpAndSettle();
    final back = runs.length;
    await t.pump(const Duration(seconds: 1));
    expect(runs.length, back + 1);
  });

  testWidgets('a sheet over it leaves it running: the screen is in view', (
    t,
  ) async {
    final runs = <int>[];
    late BuildContext home;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            home = c;
            return _Probe(
              () => _now(t),
              (s) =>
                  s.every(const Duration(seconds: 1), () => runs.add(_now(t))),
            );
          },
        ),
      ),
    );
    showModalBottomSheet<void>(
      context: home,
      builder: (_) => const SizedBox(height: 200),
    );
    await t.pumpAndSettle();
    final open = runs.length;
    await t.pump(const Duration(seconds: 3));
    expect(runs.length, open + 3);
  });

  testWidgets('a slow beat keeps its time after a short look away', (t) async {
    final start = _now(t);
    final runs = <int>[];
    await t.pumpWidget(
      MaterialApp(
        home: _Probe(
          () => _now(t),
          (s) => s.every(
            const Duration(seconds: 30),
            () => runs.add(_now(t) - start),
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 30));
    expect(runs, [30000]);

    // away for five seconds, not yet due: no extra run on return
    await t.pump(const Duration(seconds: 5));
    await _leave(t);
    await t.pump(const Duration(seconds: 5));
    await _return(t);
    expect(runs, [30000]);
    await t.pump(const Duration(seconds: 20));
    expect(runs, [30000, 60000]);

    // away past its time: once at once, then on its beat from there
    await t.pump(const Duration(seconds: 5));
    await _leave(t);
    await t.pump(const Duration(seconds: 35));
    await _return(t);
    expect(runs, [30000, 60000, 100000]);
    await t.pump(const Duration(seconds: 30));
    expect(runs, [30000, 60000, 100000, 130000]);
  });

  testWidgets('a burn due while away goes at once, the next one on time', (
    t,
  ) async {
    final b = _Burns(t, _now(t));
    b
      ..add(5000)
      ..add(15000);
    await t.pumpWidget(MaterialApp(home: _Probe(() => _now(t), b.setup)));
    await t.pump(const Duration(seconds: 2));
    expect(b.burnt, isEmpty);

    await _leave(t);
    final looked = b.looks;
    expect(b.job.pending, false);
    await t.pump(const Duration(seconds: 8));
    // nothing woke while away
    expect(b.looks, looked);
    expect(b.burnt, isEmpty);

    await _return(t);
    // due at 5 s, gone the moment the chat is back at 10 s
    expect(b.burnt, [(10000, true)]);

    final back = b.looks;
    await t.pump(const Duration(seconds: 5));
    // the pause did not push the other one out by a millisecond
    expect(b.burnt, [(10000, true), (15000, false)]);
    // a look a second for the countdown, not ten
    expect(b.looks - back, lessThanOrEqualTo(6));
    // nothing left to count down: nothing waits
    expect(b.job.pending, false);
  });

  testWidgets('a page over a burn: it goes at once when the page leaves', (
    t,
  ) async {
    final b = _Burns(t, _now(t))..add(3000);
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      MaterialApp(navigatorKey: nav, home: _Probe(() => _now(t), b.setup)),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await t.pumpAndSettle();
    final looked = b.looks;
    await t.pump(const Duration(seconds: 10));
    expect(b.looks, looked);
    expect(b.burnt, isEmpty);

    nav.currentState!.pop();
    await t.pump();
    expect(b.burnt.single.$2, true);
    await t.pumpAndSettle();
  });

  testWidgets('a deadline added later is poked in and kept to the ms', (
    t,
  ) async {
    final b = _Burns(t, _now(t));
    await t.pumpWidget(MaterialApp(home: _Probe(() => _now(t), b.setup)));
    await t.pump(const Duration(seconds: 1));
    // no countdown: no timer at all
    expect(b.job.pending, false);
    expect(b.looks, 0);

    b.add(1300);
    b.job.poke();
    expect(b.job.pending, true);
    await t.pump(const Duration(milliseconds: 300));
    expect(b.burnt, [(1300, false)]);
    expect(b.job.pending, false);
  });

  testWidgets('a poke on the way back does not cut the catch-up short', (
    t,
  ) async {
    final b = _Burns(t, _now(t))..add(2000);
    await t.pumpWidget(MaterialApp(home: _Probe(() => _now(t), b.setup)));
    await _leave(t);
    await t.pump(const Duration(seconds: 5));
    // the screen builds in the same frame it comes back in
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    b.job.poke();
    await t.pump();
    expect(b.burnt, [(5000, true)]);
  });

  test('burnWait: the next second, or a sooner deadline, or nothing', () {
    expect(burnWait(10250, ghosts: false), isNull);
    expect(burnWait(10250, ghosts: true), const Duration(milliseconds: 750));
    expect(
      burnWait(10250, ghosts: true, soonest: 10400),
      const Duration(milliseconds: 150),
    );
    expect(
      burnWait(10250, ghosts: true, soonest: 99999),
      const Duration(milliseconds: 750),
    );
    expect(burnWait(10250, ghosts: true, soonest: 9000), Duration.zero);
    expect(burnWait(10000, ghosts: true), const Duration(seconds: 1));
  });
}
