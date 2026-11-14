// SPDX-License-Identifier: GPL-3.0-or-later
// fast on a wi-fi that wants a sign-in: what is down is the wi-fi. home
// says sign in, as private does, and never offers private as the way out
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        appState,
        useEngineForTest,
        AppStateRoute,
        AppStateBridges;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp, devHome, devWorld;

class _Engine implements HaloEngine {
  List<Object?> relays = const [];
  @override
  Map<String, dynamic> transportState() => {'relays': relays};
  @override
  void networkDetail(String json) {}
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

const _down = [
  {'url': 'wss://relay.kryfo.app', 'fails': 2, 'benched': true},
  {'url': 'wss://relay2.kryfo.app', 'fails': 1},
];
const _up = [
  {'url': 'wss://relay.kryfo.app', 'fails': 0, 'up': true},
  {'url': 'wss://relay2.kryfo.app', 'fails': 0, 'up': true},
];
const _portal = '{"on":true,"validated":false,"limited":true,"kind":"wifi"}';
const _signedIn = '{"on":true,"validated":true,"limited":false,"kind":"wifi"}';

void main() {
  late _Engine eng;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    eng = _Engine();
    useEngineForTest(eng);
  });

  final t0 = DateTime(2026, 11, 14, 12);

  AppState fastOn(String detail) {
    final app = AppState()..sendModeForTest = 'balanced';
    app.noteOnline(true, now: t0);
    app.netDetailEvent(detail);
    return app;
  }

  test('behind a portal: the sign-in card, never private', () {
    final app = fastOn(_portal);
    eng.relays = _down;
    app.sampleRelayHealth(now: t0);
    expect(app.fastCaptive, isTrue);
    expect(app.captiveWait, isTrue);
    expect(app.homeBridgeCard, 'auto');
    final late = t0.add(const Duration(seconds: 95));
    app.sampleRelayHealth(now: late);
    expect(app.suggestPrivateFallbackAt(late), isFalse);
  });

  test('signed in: the card goes, and our servers are ours again', () {
    final app = fastOn(_portal);
    eng.relays = _down;
    app.sampleRelayHealth(now: t0);
    app.netDetailEvent(_signedIn);
    expect(app.fastCaptive, isFalse);
    expect(app.homeBridgeCard, isNull);
    // still not answering on a wi-fi that lets everything through
    final late = t0.add(const Duration(seconds: 95));
    app.sampleRelayHealth(now: late);
    expect(app.suggestPrivateFallbackAt(late), isTrue);
    eng.relays = _up;
    app.sampleRelayHealth(now: late);
    expect(app.relayDownSince, isNull);
    expect(app.homeBridgeCard, isNull);
  });

  test('a portal our servers answer through says nothing', () {
    final app = fastOn(_portal);
    eng.relays = _up;
    app.sampleRelayHealth(now: t0);
    expect(app.fastCaptive, isFalse);
    expect(app.homeBridgeCard, isNull);
  });

  test('private keeps the engine\'s word', () {
    final app = AppState()..sendModeForTest = 'private';
    app.noteOnline(true, now: t0);
    app.netDetailEvent(_portal);
    expect(app.fastCaptive, isFalse);
    expect(app.captiveWait, isFalse);
    app.setBridgeStatusForTest(const BridgeStatus(phase: 'captive'));
    expect(app.captiveWait, isTrue);
  });

  group('home', () {
    setUp(() async {
      await devWorld();
      lockState.openForTest();
    });

    tearDown(() {
      appState.relayDownSinceForTest = null;
      appState.netDetailEvent(_signedIn);
      appState.sendModeForTest = 'private';
    });

    testWidgets('says sign in, with the wi-fi settings', (t) async {
      t.view.physicalSize = const Size(411, 891);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      eng.relays = _down;
      appState.sendModeForTest = 'balanced';
      appState.noteOnline(true);
      appState.netDetailEvent(_portal);
      appState.relayDownSinceForTest = DateTime.now().subtract(
        const Duration(minutes: 3),
      );
      await t.pumpWidget(devApp(devHome()));
      await t.pump(const Duration(seconds: 2));
      expect(find.text(l10n.bridgesSignInToThisWifi), findsOneWidget);
      expect(find.text(l10n.bridgesOpenWifiSettings), findsOneWidget);
      expect(find.text(l10n.homeOursDownTitle), findsNothing);
      expect(find.text(l10n.homeUsePrivate), findsNothing);
      expect(find.text(l10n.bridgesNotNeededRightNow), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    });
  });
}
