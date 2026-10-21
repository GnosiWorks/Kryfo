// SPDX-License-Identifier: GPL-3.0-or-later
// the home pill holds "Tor ready" through a blip shorter than kPillGrace: a
// network handover or a bounce does not flicker it to connecting. the send
// checks still go by the route itself
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, TorHalo, appState, useEngineForTest;
import 'package:kryfo/pill_grace.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app;

class _Engine implements HaloEngine {
  @override
  Map<String, dynamic> transportState() => {};
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t0 = DateTime(2026, 10, 21, 12);

  bool holds({
    bool usable = false,
    DateTime? at,
    TorStatus status = TorStatus.starting,
    bool online = true,
    Duration after = Duration.zero,
  }) => pillHoldsReady(
    usable: usable,
    usableAt: at,
    status: status,
    online: online,
    now: t0.add(after),
  );

  group('the grace', () {
    test('a route that carries is ready', () {
      expect(holds(usable: true), isTrue);
    });

    test('a drop shorter than the grace stays ready', () {
      expect(holds(at: t0, after: const Duration(seconds: 1)), isTrue);
      expect(
        holds(at: t0, after: kPillGrace - const Duration(milliseconds: 1)),
        isTrue,
      );
    });

    test('past the grace it is not', () {
      expect(holds(at: t0, after: kPillGrace), isFalse);
      expect(holds(at: t0, after: const Duration(minutes: 5)), isFalse);
    });

    test('never ready that never carried, offline or off', () {
      expect(holds(), isFalse);
      expect(holds(at: t0, online: false), isFalse);
      expect(holds(at: t0, status: TorStatus.off), isFalse);
    });

    test('the end of a held ready, none for one not held', () {
      DateTime? end({bool usable = false, DateTime? at, Duration? after}) =>
          pillGraceEnds(
            usable: usable,
            usableAt: at,
            status: TorStatus.starting,
            online: true,
            now: t0.add(after ?? Duration.zero),
          );
      expect(end(at: t0), t0.add(kPillGrace));
      expect(end(usable: true, at: t0), isNull);
      expect(end(at: t0, after: kPillGrace), isNull);
      expect(end(), isNull);
    });
  });

  group('the app', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '.',
          );
      useEngineForTest(_Engine());
    });

    test('a bounce right after the route carried keeps the pill ready, '
        'and only the pill', () {
      final a = AppState()..sendModeForTest = 'private';
      a.takeTorStatus('publishing|100|1|1|3');
      expect(a.torUsable, isTrue);
      // the bounce: starting, no relay through the new route yet
      a.takeTorStatus('starting|0|0|0|4');
      expect(a.torUsable, isFalse);
      expect(a.linkUp, isFalse);
      expect(a.pillReady, isTrue);
      expect(a.pillGraceEnd, isNotNull);
    });

    test('a start that never carried is not held', () {
      final a = AppState()..sendModeForTest = 'private';
      a.takeTorStatus('starting|40|0|0|0');
      expect(a.pillReady, isFalse);
    });
  });

  group('the pill', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      appState.sendModeForTest = 'private';
      appState.noteOnline(true);
    });

    tearDown(() {
      appState.usableAtForTest = null;
      appState.setTorStatusForTest(TorStatus.off);
      appState.setRouteOKForTest(true);
    });

    testWidgets('says ready through a blip and connecting after it', (t) async {
      appState.setTorStatusForTest(TorStatus.starting);
      appState.setRouteOKForTest(false);
      appState.usableAtForTest = DateTime.now();
      await t.pumpWidget(
        app(const Center(child: TorHalo(label: true)), still: true),
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.appTorReady), findsOneWidget);
      expect(find.text(l10n.appConnecting2), findsNothing);

      // the same drop, longer than the grace
      appState.usableAtForTest = DateTime.now().subtract(
        kPillGrace + const Duration(seconds: 1),
      );
      appState.setTorStatusForTest(TorStatus.starting);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.appTorReady), findsNothing);
      expect(find.text(l10n.appConnecting2), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });
}
