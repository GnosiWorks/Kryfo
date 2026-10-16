// SPDX-License-Identifier: GPL-3.0-or-later
// a new install says nothing to the engine about the network until the
// first-run question is answered: no mode, no tor, no relay. a kill at any
// write of the answer either asks again or never asks again
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, bridgeWriteTap, useEngineForTest;
import 'package:shared_preferences/shared_preferences.dart';

class _Engine implements HaloEngine {
  final calls = <String>[];
  final restores = <String>[];
  @override
  String restoreBridgeMode(String mode, String opts) {
    calls.add('restoreBridgeMode');
    restores.add('$mode $opts');
    return 'ok';
  }

  @override
  List<String> builtinBridges(String transport) => const [];
  @override
  String bridgeLineChecks() => '[]';
  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName.toString().split('"')[1]);
    return 'ok';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final risky in [false, true]) {
    test(
      'the engine hears nothing before the answer (risky: $risky)',
      () async {
        final e = _Engine();
        useEngineForTest(e);
        final app = AppState();
        addTearDown(app.dropBridgeHooks);
        await app.markReady();
        expect(app.firstRunAsk, isTrue);
        var done = false;
        unawaited(app.loadBridgesForTest().then((_) => done = true));
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(done, isFalse);
        expect(app.firstRunAsk, isTrue);
        // the only call is the decoy flag, which is local
        expect(e.calls.where((c) => c != 'setDecoy'), isEmpty);
        expect(e.restores, isEmpty);
        await app.pickFirstRun(risky: risky);
        for (var i = 0; i < 50 && !done; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(done, isTrue);
        expect(e.restores, hasLength(1));
        expect(e.restores.single, startsWith('auto '));
        expect(
          e.restores.single.contains('"skip_direct":true'),
          risky,
          reason: e.restores.single,
        );
      },
    );
  }

  test('a kill at any write of the answer: asked again or never', () async {
    addTearDown(() => bridgeWriteTap = null);
    for (var n = 0; ; n++) {
      FlutterSecureStorage.setMockInitialValues({});
      final first = AppState();
      await first.readBridgeSetup(firstStart: true);
      expect(first.firstRunAsk, isTrue);
      var i = 0;
      bridgeWriteTap = (k) {
        if (i++ == n) throw StateError('killed at $k');
      };
      var whole = true;
      try {
        await first.pickFirstRun(risky: true);
      } on StateError {
        whole = false;
      }
      bridgeWriteTap = null;
      const st = FlutterSecureStorage();
      final kept = await st.read(key: 'bridge_mode');
      final next = AppState();
      final again = await next.firstRunWanted();
      // the mode is written last of the answer: without it, asked again
      expect(again, kept == null, reason: 'kill $n');
      if (!again) {
        // answered: never asked, on any later start, onboarding done or not
        final b = await next.readBridgeSetup(firstStart: true);
        expect(next.firstRunAsk, isFalse, reason: 'kill $n');
        expect(b.skipDirect, isTrue, reason: 'kill $n');
        final done = AppState()..onboardingComplete = true;
        expect(await done.firstRunWanted(), isFalse, reason: 'kill $n');
      }
      if (whole) break;
    }
  });
}
