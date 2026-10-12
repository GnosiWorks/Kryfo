// SPDX-License-Identifier: GPL-3.0-or-later
// the handle goes back to the registry in turn: a release waits for a claim
// already on its way and goes a second after it, and nothing claims the
// handle again once a release or a wipe has begun. the engine and secure
// storage are stand-ins
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/handle_repoint.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, engine, useEngineForTest;
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:kryfo/wipe.dart' show haloWiping;
import 'package:shared_preferences/shared_preferences.dart';

class _Engine implements HaloEngine {
  // a claim answers when the test says
  Completer<String>? claimGate;
  final calls = <(String, DateTime)>[];

  @override
  Future<String> handleClaim(String h, String invite, String bio) {
    calls.add(('claim $h', DateTime.now()));
    return claimGate?.future ?? Future.value('ok');
  }

  @override
  Future<String> handleRelease(String h) async {
    calls.add(('release $h', DateTime.now()));
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Engine e;
  late AppState app;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'my_handle': 'wren'});
    e = _Engine();
    useEngineForTest(e);
    app = AppState()
      ..myId = 'amber-fox-run'
      ..myOnion = 'abc.onion';
    app.setTorStatusForTest(TorStatus.bootstrapped);
    await app.loadMyHandle();
    // the invite and the marks without signal or secure storage behind them
    final kept = <String, String>{};
    app.handleRepointForTest = HandleRepoint(
      invite: () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'kryfo://share?id=amber-fox-run';
      },
      claim: (h, i, b) => engine.handleClaim(h, i, b),
      lookup: (url) async => '',
      myKey: () => 'ab',
      read: (k) async => kept[k],
      write: (k, v) async => v == null ? kept.remove(k) : kept[k] = v,
    );
    haloWiping = false;
  });

  tearDown(() => haloWiping = false);

  test('a release waits for the claim on its way, goes a second after it, '
      'and the handle is let go of', () async {
    e.claimGate = Completer<String>();
    final claiming = app.repointForTest();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(e.calls.map((c) => c.$1), ['claim wren']);
    final released = app.releaseHandle('wren');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // still behind the claim
    expect(e.calls.map((c) => c.$1), ['claim wren']);
    final claimedAt = DateTime.now();
    e.claimGate!.complete('ok');
    await claiming;
    expect(await released, 'ok');
    expect(e.calls.map((c) => c.$1), ['claim wren', 'release wren']);
    expect(
      e.calls.last.$2.difference(claimedAt),
      greaterThanOrEqualTo(const Duration(milliseconds: 1100)),
    );
    expect(app.myHandle, isNull);
  });

  test('a wipe stops a repoint armed before it, and one already reading '
      'claims nothing', () async {
    // already reading the invite when the wipe begins
    final claiming = app.repointForTest();
    haloWiping = true;
    app.stopRepoint();
    await claiming;
    expect(e.calls, isEmpty);
    expect(app.myHandle, isNull);
    // and one asked after it does nothing at all
    await app.repointForTest();
    expect(e.calls, isEmpty);
  });

  test(
    'during a wipe nothing is claimed, the handle still held or not',
    () async {
      haloWiping = true;
      await app.repointForTest();
      expect(e.calls, isEmpty);
      // and one already reading when the wipe begins stops before its claim
      haloWiping = false;
      final claiming = app.repointForTest();
      haloWiping = true;
      await claiming;
      expect(e.calls, isEmpty);
    },
  );
}
