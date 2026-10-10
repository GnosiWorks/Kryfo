// SPDX-License-Identifier: GPL-3.0-or-later
// the way out of a send stuck on tor: nothing for the first minute, then a
// plain line and a reconnect. a reconnect tor will not take, or one that
// brings nothing back within a minute, turns the button into a restart that
// keeps the queue. never in a decoy, never outside onion, and the same with
// the phone asking for no movement
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/tor_valve.dart';
import 'package:kryfo/widgets/reconnect_valve.dart';

void main() {
  final t0 = DateTime(2026, 10, 10, 12);

  ValveStage at(
    Duration waited, {
    bool private = true,
    bool quiet = false,
    bool linkUp = false,
    bool busy = false,
    Duration? triedAgo,
    bool failed = false,
  }) => valveStageAt(
    private: private,
    quiet: quiet,
    waitingSince: t0,
    now: t0.add(waited),
    linkUp: linkUp,
    busy: busy,
    triedAt: triedAgo == null ? null : t0.add(waited).subtract(triedAgo),
    triedFailed: failed,
  );

  test('nothing in the first minute, a reconnect after it', () {
    expect(at(const Duration(seconds: 59)), ValveStage.hidden);
    expect(at(const Duration(seconds: 61)), ValveStage.offer);
    expect(
      valveStageAt(
        private: true,
        quiet: false,
        waitingSince: null,
        now: t0,
        linkUp: false,
        busy: false,
        triedAt: null,
        triedFailed: false,
      ),
      ValveStage.hidden,
    );
  });

  test('never in a decoy, never outside onion', () {
    expect(at(const Duration(minutes: 5), quiet: true), ValveStage.hidden);
    expect(at(const Duration(minutes: 5), private: false), ValveStage.hidden);
  });

  test('a reconnect tor would not take offers the restart at once', () {
    expect(
      at(
        const Duration(minutes: 2),
        triedAgo: const Duration(seconds: 1),
        failed: true,
      ),
      ValveStage.restart,
    );
  });

  test('one that took but brought nothing back offers it after a minute', () {
    final tried = const Duration(minutes: 3);
    expect(at(tried, triedAgo: const Duration(seconds: 30)), ValveStage.offer);
    expect(
      at(tried, triedAgo: const Duration(seconds: 61)),
      ValveStage.restart,
    );
    // the route came back: a restart would help nothing
    expect(
      at(tried, triedAgo: const Duration(seconds: 61), linkUp: true),
      ValveStage.offer,
    );
  });

  test('the engine saying tor sleeps on purpose is not a failure', () async {
    var now = t0;
    final v = TorValve(
      reconnect: () async => 'error: tor is asleep',
      restart: () async {},
      clock: () => now,
    );
    await v.tryReconnect();
    expect(v.triedFailed, isFalse);
    final w = TorValve(
      reconnect: () async => 'error: control port timeout on DisableNetwork 1',
      restart: () async {},
      clock: () => now,
    );
    await w.tryReconnect();
    expect(w.triedFailed, isTrue);
    // and the route coming back clears it for the next wait
    w.sawLink(true);
    expect(w.triedAt, isNull);
    expect(w.triedFailed, isFalse);
  });

  for (final still in [false, true]) {
    testWidgets('the strip, reconnect then restart (no movement: $still)', (
      tester,
    ) async {
      var now = t0;
      final calls = <String>[];
      var answer = 'error: control port timeout on DisableNetwork 1';
      final v = TorValve(
        reconnect: () async {
          calls.add('reconnect');
          return answer;
        },
        restart: () async => calls.add('restart'),
        clock: () => now,
      );
      Widget strip({bool waiting = true, bool linkUp = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: Scaffold(
            body: ReconnectValve(
              valve: v,
              waiting: waiting,
              private: true,
              quiet: false,
              linkUp: linkUp,
            ),
          ),
        ),
      );
      await tester.pumpWidget(strip());
      expect(find.text(l10n.valveStillConnecting), findsNothing);

      now = t0.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.valveStillConnecting), findsOneWidget);
      expect(find.text(l10n.homeReconnect), findsOneWidget);

      await tester.tap(find.text(l10n.homeReconnect));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, ['reconnect']);
      expect(find.text(l10n.valveCouldNotReconnect), findsOneWidget);
      expect(find.text(l10n.valveRestartKryfo), findsOneWidget);

      await tester.tap(find.text(l10n.valveRestartKryfo));
      await tester.pump();
      expect(calls, ['reconnect', 'restart']);

      // the message went: the strip folds away
      answer = 'ok';
      await tester.pumpWidget(strip(waiting: false, linkUp: true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.valveCouldNotReconnect), findsNothing);
      expect(find.text(l10n.valveStillConnecting), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a reconnect that worked leaves the plain line', (tester) async {
    var now = t0;
    final v = TorValve(
      reconnect: () async => 'ok',
      restart: () async {},
      clock: () => now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReconnectValve(
            valve: v,
            waiting: true,
            private: true,
            quiet: false,
            linkUp: false,
          ),
        ),
      ),
    );
    now = t0.add(const Duration(seconds: 70));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(l10n.homeReconnect));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.valveStillConnecting), findsOneWidget);
    expect(find.text(l10n.valveRestartKryfo), findsNothing);
    // a minute on with nothing back: now the restart
    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.valveRestartKryfo), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
