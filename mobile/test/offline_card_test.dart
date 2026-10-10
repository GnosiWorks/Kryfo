// SPDX-License-Identifier: GPL-3.0-or-later
// the home card for a tor that has not connected in five minutes: a
// reconnect, then a restart when tor will not take it. never in a decoy,
// and never a restart with no network at all
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, torValve, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/home_screen.dart' show OfflineCard;
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

class _Engine implements HaloEngine {
  int reconnects = 0;
  @override
  Map<String, dynamic> transportState() => const {};
  @override
  Future<String> reconnectNow() async {
    reconnects++;
    return 'error: control port timeout on DisableNetwork 1';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _Engine eng;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    eng = _Engine();
    useEngineForTest(eng);
    final live = ArrivalRows(HaloContainer.everyday);
    useDatabasesForTest(live, Session(live));
    appState
      ..sendModeForTest = 'private'
      ..deliveryModeForTest = DeliveryMode.always;
    appState.noteOnline(true);
    // tor off for six minutes
    appState.takeTorStatus(
      'off|0|0|0|1',
      now: DateTime.now().subtract(const Duration(minutes: 6)),
    );
  });

  Widget card() => const MaterialApp(home: Scaffold(body: OfflineCard()));

  testWidgets('reconnect, then a restart tor would not take', (t) async {
    await t.pumpWidget(card());
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.homeKryfoIsOffline), findsOneWidget);
    await t.tap(find.text(l10n.homeReconnect));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(eng.reconnects, 1);
    expect(find.text(l10n.valveRestartKryfo), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('airplane mode: never a restart', (t) async {
    await torValve.tryReconnect();
    appState.noteOnline(false);
    await t.pumpWidget(card());
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.valveRestartKryfo), findsNothing);
    await t.pumpWidget(const SizedBox());
    appState.noteOnline(true);
  });

  testWidgets('in a decoy: no card, no reconnect, no restart', (t) async {
    final decoy = ArrivalRows(HaloContainer.decoy);
    useDatabasesForTest(decoy, Session(decoy));
    await t.pumpWidget(card());
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.homeKryfoIsOffline), findsNothing);
    expect(find.text(l10n.homeReconnect), findsNothing);
    expect(find.text(l10n.valveRestartKryfo), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
