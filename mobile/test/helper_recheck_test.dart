// SPDX-License-Identifier: GPL-3.0-or-later
// getting messages asks our relay about the helper app again each time tor
// on the onion route turns ready, once per turn, and stops when it closes
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloEngine, appState, useEngineForTest;
import 'package:kryfo/ready_edge.dart';
import 'package:kryfo/screens/getting_messages_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

// counts the relay asks. an answer that is not yes or no is never kept, so
// every ask reaches the engine
class _Engine implements HaloEngine {
  int asks = 0;
  @override
  Future<String> knockCheck() async {
    asks++;
    return 'unreachable';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  group('ready edge', () {
    test('once per turn to ready, never while it holds', () {
      final source = ValueNotifier(false);
      var calls = 0;
      final edge = ReadyEdge(source, () => source.value, () => calls++);
      source.value = true;
      expect(calls, 1);
      // the source notifies again with nothing moved
      source.notifyListeners();
      source.notifyListeners();
      expect(calls, 1);
      source.value = false;
      expect(calls, 1);
      source.value = true;
      expect(calls, 2);
      edge.dispose();
      source.value = false;
      source.value = true;
      expect(calls, 2);
    });

    test('ready from the start is not a turn', () {
      final source = ValueNotifier(true);
      var calls = 0;
      final edge = ReadyEdge(source, () => source.value, () => calls++);
      source.notifyListeners();
      expect(calls, 0);
      edge.dispose();
    });
  });

  group('the page', () {
    late Directory docs;
    late _Engine engine;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      engine = _Engine();
      useEngineForTest(engine);
      docs = Directory.systemTemp.createTempSync('recheck');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => docs.path,
          );
      appState.sendModeForTest = 'private';
      appState.setRouteOKForTest(false);
      appState.setTorStatusForTest(TorStatus.starting);
    });

    tearDown(() {
      appState.setTorStatusForTest(TorStatus.off);
      appState.setRouteOKForTest(false);
      appState.sendModeForTest = 'private';
      docs.deleteSync(recursive: true);
    });

    Widget framed() => MaterialApp(
      theme: buildHaloTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const GettingMessagesScreen(),
    );

    Future<void> settle(WidgetTester t) async {
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('tor turning ready asks once; status updates while it '
        'holds ask nothing', (t) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(framed());
      await settle(t);
      // tor still coming up: nothing to ask over
      expect(engine.asks, 0);

      appState.setRouteOKForTest(true);
      appState.setTorStatusForTest(TorStatus.bootstrapped);
      await settle(t);
      expect(engine.asks, 1);

      // tor moving on while ready is not a new turn
      appState.setTorStatusForTest(TorStatus.publishing);
      appState.setTorStatusForTest(TorStatus.reachable);
      await settle(t);
      expect(engine.asks, 1);

      // down and up again is
      appState.setRouteOKForTest(false);
      appState.setRouteOKForTest(true);
      await settle(t);
      expect(engine.asks, 2);

      // closed: no more asks
      await t.pumpWidget(const SizedBox());
      appState.setRouteOKForTest(false);
      appState.setRouteOKForTest(true);
      await settle(t);
      expect(engine.asks, 2);
    });

    testWidgets('off the onion route tor turning ready asks nothing', (
      t,
    ) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      appState.sendModeForTest = 'balanced';
      await t.pumpWidget(framed());
      await settle(t);
      appState.setRouteOKForTest(true);
      appState.setTorStatusForTest(TorStatus.bootstrapped);
      await settle(t);
      expect(engine.asks, 0);
      await t.pumpWidget(const SizedBox());
    });
  });
}
