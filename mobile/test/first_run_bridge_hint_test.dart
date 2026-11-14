// SPDX-License-Identifier: GPL-3.0-or-later
// automatic on a first run, nothing through after a while: the home's
// automatic card says one way out first or a pasted bridge gets in. never
// once tor has carried, never on fast
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useEngineForTest, AppStateRoute, AppStateBridges;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp, devHome, devWorld;

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  String restoreBridgeMode(String mode, String opts) => 'ok';
  @override
  String bridgeLineChecks() => '[]';
  @override
  List<String> builtinBridges(String transport) => const [];
  @override
  String setAutoMemory(String mem) => 'ok';
  @override
  String setBridgeCache(String cache) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    useEngineForTest(_Engine());
    await devWorld();
    appState.sendModeForTest = 'private';
    appState.bridgeSetupForTest = const BridgeSetup();
    appState.torUpOnceForTest = false;
    appState.torTryingSinceForTest = DateTime.now().subtract(
      const Duration(minutes: 5),
    );
  });

  tearDown(() {
    appState.torTryingSinceForTest = null;
    appState.torUpOnceForTest = false;
    appState.setBridgeStatusForTest(BridgeStatus.none);
    appState.sendModeForTest = 'private';
  });

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(411, 891);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  Future<void> done(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  final hint = find.textContaining('VPN', findRichText: true);

  test('waits out the usual ways first', () {
    final now = DateTime.now();
    appState.torTryingSinceForTest = now.subtract(const Duration(minutes: 3));
    expect(appState.firstAutoStuckAt(now), isFalse);
    expect(
      appState.firstAutoStuckAt(now.add(const Duration(minutes: 1))),
      isTrue,
    );
  });

  test('only automatic, only private', () {
    expect(appState.firstAutoStuck, isTrue);
    appState.sendModeForTest = 'balanced';
    expect(appState.firstAutoStuck, isFalse);
    expect(appState.homeBridgeCard, isNot('auto'));
    appState.sendModeForTest = 'private';
    appState.bridgeSetupForTest = const BridgeSetup(
      choice: BridgeChoice.direct,
    );
    expect(appState.firstAutoStuck, isFalse);
  });

  testWidgets('a first run not through: the hint and paste', (t) async {
    phone(t);
    expect(appState.homeBridgeCard, 'auto');
    await t.pumpWidget(devApp(devHome()));
    await t.pump(const Duration(seconds: 2));
    expect(hint, findsOneWidget);
    expect(find.textContaining(l10n.homeFirstRunBridgeHint), findsOneWidget);
    await t.tap(find.text(l10n.bridgesPasteABridge));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    // the paste sheet, with its own clipboard button
    expect(find.text(l10n.bridgesPasteFromClipboard), findsOneWidget);
    await done(t);
  });

  testWidgets('nothing got through yet: the bridge way stays first', (
    t,
  ) async {
    phone(t);
    appState.setBridgeStatusForTest(
      const BridgeStatus(mode: 'auto', phase: 'exhausted'),
    );
    await t.pumpWidget(devApp(devHome()));
    await t.pump(const Duration(seconds: 2));
    expect(find.textContaining(l10n.bridgesRelayThisNetworkSees), findsOne);
    expect(hint, findsOneWidget);
    final ask = t.getRect(find.text(l10n.bridgesGetABridge));
    final paste = t.getRect(find.text(l10n.bridgesPasteABridge));
    expect(
      ask.top < paste.top - 1 ||
          ((ask.top - paste.top).abs() <= 1 && ask.left < paste.left),
      isTrue,
    );
    await done(t);
  });

  testWidgets('never on fast', (t) async {
    phone(t);
    appState.sendModeForTest = 'balanced';
    await t.pumpWidget(devApp(devHome()));
    await t.pump(const Duration(seconds: 2));
    expect(hint, findsNothing);
    await done(t);
  });

  testWidgets('gone for good once tor has carried', (t) async {
    phone(t);
    expect(appState.firstAutoStuck, isTrue);
    appState.takeTorStatus('bootstrapped|100|0|1|1');
    expect(appState.torUpOnce, isTrue);
    // kept: the next start reads it back
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      const st = FlutterSecureStorage();
      expect(await st.read(key: 'tor_up_once'), '1');
    });
    // tor down again, trying long: still no hint
    appState.takeTorStatus('starting|10|0|0|2');
    appState.torTryingSinceForTest = DateTime.now().subtract(
      const Duration(minutes: 10),
    );
    expect(appState.firstAutoStuck, isFalse);
    await t.pumpWidget(devApp(devHome()));
    await t.pump(const Duration(seconds: 2));
    expect(hint, findsNothing);
    await done(t);
  });

  test('read back at start, and from automatic\'s memory', () async {
    for (final key in ['tor_up_once', 'bridge_auto_mem']) {
      FlutterSecureStorage.setMockInitialValues({key: '1'});
      appState.torUpOnceForTest = false;
      await appState.loadBridgesForTest();
      appState.dropBridgeHooks();
      expect(appState.torUpOnce, isTrue, reason: key);
    }
  });
}
