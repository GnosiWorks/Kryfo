// SPDX-License-Identifier: GPL-3.0-or-later
// a computer offers every route the phone has: private and fast, and on
// private every bridge, obfs4, webtunnel and snowflake included. the
// transports run inside the engine, so no build lacks one
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute;
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_chat_fakes.dart' show DevTestDb, devApp, devMem, devWorld;

class _Engine implements HaloEngine {
  final modes = <String>[];
  @override
  String setTransportMode(String mode) {
    modes.add(mode);
    return 'ok';
  }

  @override
  String nostrInit(String relaysCSV) => 'ok';
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  Map<String, dynamic> transportState() => {'relays': const []};
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// shown and fully faded in
void _seen(WidgetTester t, String text) {
  final f = find.text(text);
  expect(f, findsOneWidget, reason: text);
  for (final o in t.widgetList<AnimatedOpacity>(
    find.ancestor(of: f, matching: find.byType(AnimatedOpacity)),
  )) {
    expect(o.opacity, 1, reason: text);
  }
}

late _Engine _eng;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    _eng = _Engine();
    useEngineForTest(_eng);
    await devWorld();
    final db = DevTestDb(devMem);
    useDatabasesForTest(db, Session(db));
    onDesktop = true;
  });

  tearDown(() {
    onDesktop = false;
    appState.sendModeForTest = 'private';
  });

  void window(WidgetTester t, Size s) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = s;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  for (final size in const [Size(1280, 800), Size(800, 600)]) {
    testWidgets('both routes show and switch on a ${size.width.toInt()} '
        'window', (t) async {
      window(t, size);
      appState.sendModeForTest = 'private';
      await t.pumpWidget(devApp(const ModesScreen()));
      await t.pump(const Duration(seconds: 1));
      _seen(t, l10n.modesPrivate);
      _seen(t, l10n.modesFast);

      await t.tap(find.text(l10n.modesFast));
      for (var i = 0; i < 20 && appState.sendMode != 'balanced'; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(appState.sendMode, 'balanced');
      expect(_eng.modes, contains('balanced'));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('every bridge is offered on a computer', (t) async {
    window(t, const Size(1280, 2400));
    lockState.openForTest();
    await t.pumpWidget(devApp(const BridgesScreen()));
    await t.pump(const Duration(seconds: 1));
    _seen(t, l10n.bridgesAutomatic);
    _seen(t, l10n.bridgesDirect);
    _seen(t, l10n.bridgesBridgeFromAFriend);
    _seen(t, l10n.bridgesPasteOrScanALineShown);
    expect(find.text(l10n.bridgesPasteOrScanALine), findsNothing);

    await t.tap(find.text(l10n.bridgesMore));
    await t.pump(const Duration(seconds: 1));
    _seen(t, l10n.bridgesBuiltInBridges);
    expect(l10n.bridgesObfs4BridgesThatCome, contains('obfs4'));
    _seen(t, 'Snowflake');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  test('the engine carries every transport on every platform', () {
    final pt = File('../engine/pt.go').readAsStringSync();
    for (final name in ['obfs4', 'webtunnel', 'snowflake', 'meek_lite']) {
      expect(pt, contains('case "$name":'), reason: name);
    }
    // no build tag keeps a transport off linux or windows
    expect(pt, isNot(contains('//go:build')));
    for (final f in ['bridges.go', 'pt.go']) {
      expect(
        File('../engine/$f').readAsStringSync(),
        isNot(contains('//go:build')),
        reason: f,
      );
    }
  });

  test('no route or bridge is kept from a computer', () {
    for (final f in [
      'lib/screens/modes_screen.dart',
      'lib/screens/bridges_screen.dart',
      'lib/app/state_route.dart',
      'lib/app/state_bridges.dart',
      'lib/bridge_mode.dart',
    ]) {
      final s = File(f).readAsStringSync();
      expect(s, isNot(contains('onDesktop')), reason: f);
      expect(s, isNot(contains('isAndroid')), reason: f);
    }
  });
}
