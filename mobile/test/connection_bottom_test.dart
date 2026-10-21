// SPDX-License-Identifier: GPL-3.0-or-later
// the transport page and the connection page with more open rest at the end
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart' show HaloScrollBehavior;
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart' show HaloEngine, appState, useEngineForTest;
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/screens/transport_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';

class _Engine implements HaloEngine {
  @override
  Map<String, dynamic> transportState() => {
    'relays': [
      {'url': 'wss://relay.example', 'fails': 0},
    ],
    'sub_count': 37,
    'secs_since_recv': 4,
    'secs_since_send': 9,
    'hsdir_uploads': 3,
    'publishing_secs': 600,
  };
  @override
  Map<String, dynamic> memStats() => {
    'lastEvRecv': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 30,
  };
  @override
  String lastReconnect() => '';
  @override
  String bridgeLineChecks() => '[]';
  @override
  String autoMemory() => '{}';
  @override
  String bridgeCache() => '{}';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// the app's own scroll feel: the bounce is part of the loop
Future<void> openOnPhone(WidgetTester t, Widget page) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildHaloTheme(),
      scrollBehavior: const HaloScrollBehavior(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: page,
    ),
  );
  await t.pump(const Duration(seconds: 1));
}

// held at the end, then watched: nothing moves after it has settled
Future<void> restsAtEnd(WidgetTester t) async {
  final pos = t.state<ScrollableState>(find.byType(Scrollable).first).position;
  expect(pos.maxScrollExtent, greaterThan(0), reason: 'the page scrolls');
  pos.jumpTo(pos.maxScrollExtent);
  await t.pump();
  await t.pump(const Duration(seconds: 2));
  final seen = <String>{};
  for (var i = 0; i < 300; i++) {
    await t.pump(const Duration(milliseconds: 16));
    seen.add('${pos.pixels.round()}/${pos.maxScrollExtent.round()}');
  }
  expect(seen, hasLength(1), reason: 'still moving: $seen');
  // a row that unfolds late may leave room below; never past the end
  expect(pos.pixels, lessThanOrEqualTo(pos.maxScrollExtent + 0.5));
}

void main() {
  late Directory docs;
  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('transport_bottom');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });
  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() {
    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'hb.drain': now - 3 * 60000,
      'hb.listen': now - 5000,
      'hb.jobs': 41,
      'hb.jobAt': now - 600000,
    });
    FlutterSecureStorage.setMockInitialValues({});
    useEngineForTest(_Engine());
    lockState.openForTest();
  });

  testWidgets('the transport page rests at its end', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('halo/platform'),
      (c) async => switch (c.method) {
        'isBatteryExempt' => true,
        'processUptimeMs' => 3600000,
        _ => null,
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('halo/platform'),
        null,
      ),
    );
    await devWorld();
    await openOnPhone(t, const TransportScreen());
    await restsAtEnd(t);
    await devClose(t);
  });

  testWidgets('the connection page with more open rests at its end', (t) async {
    appState.bridgeSetupForTest = const BridgeSetup();
    appState.setBridgeStatusForTest(
      const BridgeStatus(
        mode: 'auto',
        phase: 'trying',
        method: 'snowflake',
        source: 'builtin',
        blocked: true,
        attempt: 2,
        attempts: 3,
        sinceMs: 1000,
      ),
    );
    addTearDown(() => appState.setBridgeStatusForTest(BridgeStatus.none));
    await openOnPhone(t, const BridgesScreen());
    await t.tap(find.text(l10n.bridgesMore));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await restsAtEnd(t);
    await devClose(t);
  });
}
