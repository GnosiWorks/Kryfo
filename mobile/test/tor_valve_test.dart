// SPDX-License-Identifier: GPL-3.0-or-later
// the way out of a send stuck on tor: nothing until the oldest waiting send
// is a minute old, then a plain line and a reconnect. the button rests after
// a reconnect tor took. a reconnect tor would not take, or one that brings
// nothing back within a minute, turns it into a restart that keeps the queue
// and the drafts, never while a file moves or a voice note records. never in
// a decoy, never outside onion, never with no network at all, and the same
// with the phone asking for no movement
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/drafts.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/tor_valve.dart';
import 'package:kryfo/widgets/card_action.dart';
import 'package:kryfo/widgets/reconnect_valve.dart';

void main() {
  final t0 = DateTime(2026, 10, 10, 12);

  ValveStage at(
    Duration waited, {
    bool private = true,
    bool quiet = false,
    bool online = true,
    bool linkUp = false,
    bool busy = false,
    Duration? triedAgo,
    bool failed = false,
    bool blocked = false,
  }) => valveStageAt(
    private: private,
    quiet: quiet,
    online: online,
    waitingSince: t0,
    now: t0.add(waited),
    linkUp: linkUp,
    busy: busy,
    triedAt: triedAgo == null ? null : t0.add(waited).subtract(triedAgo),
    triedFailed: failed,
    restartBlocked: blocked,
  );

  test('nothing in the first minute, a reconnect after it', () {
    expect(at(const Duration(seconds: 59)), ValveStage.hidden);
    expect(at(const Duration(seconds: 61)), ValveStage.offer);
  });

  test('never in a decoy, never outside onion, never offline', () {
    expect(at(const Duration(minutes: 5), quiet: true), ValveStage.hidden);
    expect(at(const Duration(minutes: 5), private: false), ValveStage.hidden);
    // airplane mode: no restart line, whatever the last reconnect said
    expect(
      at(
        const Duration(minutes: 5),
        online: false,
        triedAgo: const Duration(seconds: 1),
        failed: true,
      ),
      ValveStage.hidden,
    );
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
    // not while a file moves or a voice note records
    expect(
      at(
        const Duration(minutes: 2),
        triedAgo: const Duration(seconds: 1),
        failed: true,
        blocked: true,
      ),
      ValveStage.offer,
    );
  });

  test('one tor took rests a minute, then offers the restart', () {
    const w = Duration(minutes: 3);
    expect(at(w, triedAgo: const Duration(seconds: 30)), ValveStage.cooling);
    expect(at(w, triedAgo: const Duration(seconds: 61)), ValveStage.restart);
    expect(
      at(w, triedAgo: const Duration(seconds: 61), linkUp: true),
      ValveStage.offer,
    );
  });

  test(
    'no hammering: a second reconnect inside the rest is not sent',
    () async {
      var now = t0;
      var calls = 0;
      final v = TorValve(
        reconnect: () async {
          calls++;
          return 'ok';
        },
        restart: () async {},
        clock: () => now,
      );
      await v.tryReconnect();
      now = now.add(const Duration(seconds: 20));
      await v.tryReconnect();
      expect(calls, 1);
      // the route came back inside the rest: still resting
      v.sawLink(true);
      expect(v.triedAt, isNotNull);
      now = now.add(const Duration(seconds: 50));
      await v.tryReconnect();
      expect(calls, 2);
    },
  );

  test('the engine saying tor sleeps on purpose is not a failure', () async {
    final v = TorValve(
      reconnect: () async => 'error: tor is asleep',
      restart: () async {},
      clock: () => t0,
    );
    await v.tryReconnect();
    expect(v.triedFailed, isFalse);
  });

  test('the restart keeps the drafts first, and waits for files', () async {
    final order = <String>[];
    var moving = true;
    final v = TorValve(
      reconnect: () async => 'error: control port timeout',
      restart: () async => order.add('restart'),
      beforeRestart: () async => order.add('drafts'),
      busyElsewhere: () => moving,
      clock: () => t0,
    );
    await v.tryRestart();
    expect(order, isEmpty);
    moving = false;
    final mic = Object();
    restartHolds.add(mic);
    await v.tryRestart();
    expect(order, isEmpty);
    restartHolds.remove(mic);
    await v.tryRestart();
    expect(order, ['drafts', 'restart']);
  });

  test(
    'drafts kept for a restart: the everyday ones only, read back once',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final every = '${HaloContainer.everyday.id}|alice';
      final hidden = '${HaloContainer.vault.id}|bob';
      final decoy = '${HaloContainer.decoy.id}|carol';
      draftPerPeer
        ..clear()
        ..addAll({every: 'half a thought', hidden: 'secret', decoy: 'x'});
      draftPerGroup
        ..clear()
        ..addAll({'${HaloContainer.everyday.id}|g1': 'see you'});
      await keepDrafts();
      draftPerPeer.clear();
      draftPerGroup.clear();
      await restoreKeptDrafts();
      expect(draftPerPeer, {every: 'half a thought'});
      expect(draftPerGroup, {'${HaloContainer.everyday.id}|g1': 'see you'});
      draftPerPeer.clear();
      await restoreKeptDrafts();
      expect(draftPerPeer, isEmpty);
    },
  );

  Widget strip(
    TorValve v, {
    DateTime? since,
    bool online = true,
    bool linkUp = false,
    bool still = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Scaffold(
        body: ReconnectValve(
          valve: v,
          waitingSince: since,
          private: true,
          quiet: false,
          online: online,
          linkUp: linkUp,
        ),
      ),
    ),
  );

  for (final still in [false, true]) {
    testWidgets('the strip, reconnect then restart (no movement: $still)', (
      tester,
    ) async {
      var now = t0;
      final calls = <String>[];
      final v = TorValve(
        reconnect: () async {
          calls.add('reconnect');
          return 'error: control port timeout on DisableNetwork 1';
        },
        restart: () async => calls.add('restart'),
        clock: () => now,
      );
      // the oldest waiting send was written 50s ago: not yet
      now = t0.add(const Duration(seconds: 50));
      await tester.pumpWidget(strip(v, since: t0, still: still));
      expect(find.text(l10n.valveStillConnecting), findsNothing);
      // its own clock, not the screen's: ten seconds on, it shows
      now = t0.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.valveStillConnecting), findsOneWidget);

      await tester.tap(find.text(l10n.homeReconnect));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, ['reconnect']);
      expect(find.text(l10n.valveRestartKryfo), findsOneWidget);
      await tester.tap(find.text(l10n.valveRestartKryfo));
      await tester.pump();
      expect(calls, ['reconnect', 'restart']);

      await tester.pumpWidget(strip(v, linkUp: true, still: still));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.valveStillConnecting), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a send written long ago shows the way out at once', (
    tester,
  ) async {
    final v = TorValve(
      reconnect: () async => 'ok',
      restart: () async {},
      clock: () => t0,
    );
    await tester.pumpWidget(
      strip(v, since: t0.subtract(const Duration(minutes: 3))),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.valveStillConnecting), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('airplane mode: no line, no restart', (tester) async {
    final v = TorValve(
      reconnect: () async => 'error: control port timeout',
      restart: () async {},
      clock: () => t0,
    );
    await v.tryReconnect();
    await tester.pumpWidget(
      strip(v, since: t0.subtract(const Duration(minutes: 3)), online: false),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.valveStillConnecting), findsNothing);
    expect(find.text(l10n.valveCouldNotReconnect), findsNothing);
    expect(find.text(l10n.valveRestartKryfo), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('after a reconnect tor took, the button rests', (tester) async {
    var now = t0;
    var calls = 0;
    final v = TorValve(
      reconnect: () async {
        calls++;
        return 'ok';
      },
      restart: () async {},
      clock: () => now,
    );
    await tester.pumpWidget(
      strip(v, since: t0.subtract(const Duration(minutes: 2))),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(l10n.homeReconnect));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.homeReconnect), findsNothing);
    await tester.tap(find.text(l10n.homeReconnecting));
    await tester.pump();
    expect(calls, 1);
    // a minute on with nothing back: now the restart
    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.valveRestartKryfo), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a card answer that changes its words with no movement asked', (
    tester,
  ) async {
    Widget card(String label) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: Center(
            child: CardAction(
              label: label,
              onTap: () {},
              fill: Colors.red,
              ink: Colors.black,
              swap: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(card('Reconnect'));
    await tester.pumpWidget(card('Restart Kryfo'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Restart Kryfo'), findsOneWidget);
  });
}
