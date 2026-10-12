// SPDX-License-Identifier: GPL-3.0-or-later
// who read our pair address is kept for the phone. one let go of while the
// stored list could not be read is taken out once it can be, and two first
// reads at once are one read. secure storage's channel is a stand-in
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

// rows whose added-back answer waits until the test lets it go
class _SlowRows extends ArrivalRows {
  _SlowRows() : super(HaloContainer.everyday);
  final asked = Completer<void>();
  final go = Completer<void>();
  @override
  Future<bool> isBackPaired(String peerId) async {
    if (!asked.isCompleted) asked.complete();
    await go.future;
    return super.isBackPaired(peerId);
  }
}

class _Engine implements HaloEngine {
  final listened = <int>[];
  @override
  Future<String> subscribeFirstContact(int counter) async {
    listened.add(counter);
    return 'ok';
  }

  @override
  int firstContactRelays() => 1;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> kept;
  var failPairRead = false;
  var pairReads = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    kept = {'pair_read': '["gone-one","stays-here"]'};
    failPairRead = false;
    pairReads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              if (key == 'pair_read') {
                pairReads++;
                if (failPairRead) {
                  throw PlatformException(code: 'Exception', message: 'no');
                }
              }
              return kept[key];
            case 'write':
              kept[key!] = args['value'] as String;
              return null;
            case 'delete':
              kept.remove(key);
              return null;
          }
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  test('one let go of while the list did not read is taken out once it '
      'does', () async {
    final app = AppState();
    failPairRead = true;
    await app.forgetPeerFc('gone-one');
    expect(kept['pair_read'], '["gone-one","stays-here"]');
    failPairRead = false;
    await app.forgetPeerFc('someone-else');
    expect(kept['pair_read'], '["stays-here"]');
  });

  test('two first reads at once are one read', () async {
    final app = AppState();
    await Future.wait([
      app.forgetPeerFc('gone-one'),
      app.forgetPeerFc('someone-else'),
    ]);
    expect(pairReads, 1);
    expect(kept['pair_read'], '["stays-here"]');
  });

  test('a read that works drops whoever the vault keeps or added us back, '
      'whatever a process before missed', () async {
    kept['pair_read'] = '["hidden-one","paired-one","stays-here"]';
    final store = ArrivalStore();
    await store.putHidden(
      'hidden-one',
      kHiddenPeer,
      peerCard(RouterCard('hidden-one', 'o-h', 'x-h', backPaired: false)),
      1,
    );
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    final rows = ArrivalRows(HaloContainer.everyday)
      ..person('paired-one')
      ..person('stays-here', backPaired: 0);
    useDatabasesForTest(rows, Session(rows));
    final app = AppState(io: ArrivalIo(), router: router);
    await app.forgetPeerFc('someone-else');
    expect(kept['pair_read'], '["stays-here"]');
  });

  test('a forget while the read is still checking who added us back waits '
      'for it: nothing throws, the invite is listened on, and the forget '
      'holds', () async {
    kept['pair_read'] = '["gone-one","stays-here","third-one"]';
    kept['fc_counter'] = '3';
    final engine = _Engine();
    useEngineForTest(engine);
    final rows = _SlowRows()
      ..person('gone-one', backPaired: 0)
      ..person('stays-here', backPaired: 0)
      ..person('third-one', backPaired: 0);
    useDatabasesForTest(rows, Session(rows));
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    final app = AppState(io: ArrivalIo(), router: router);
    final loading = app.loadFirstContact();
    await rows.asked.future;
    // it comes while the first answer is awaited
    final forget = app.forgetPeerFc('gone-one');
    rows.go.complete();
    await loading;
    await forget;
    expect(engine.listened, [3]);
    expect(kept['pair_read'], '["stays-here","third-one"]');
  });
}
