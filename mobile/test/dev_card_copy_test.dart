// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's card as his own phone copies it: the v3 card on the kept
// invite keys, on his everyday identity alone
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devchat/dev_lane.dart' show devCardChecks, devCardStarts;
import 'package:kryfo/devices/device_state.dart' show linkedDevicesForTest;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        linkedRoleForTest,
        useDatabasesForTest,
        useEngineForTest,
        AppStateDevchat;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart' show invitePreKeyId, kInviteKyberId;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'signal_kit.dart';

const _words = 'scare-raven-rare';
final _fc = '09' * 32;

// the engine as the card reaches it: the main identity's first-contact
// address at counter 0
class _Engine implements HaloEngine {
  @override
  String firstContactPk(int ident, int counter) =>
      counter == 0 ? _fc : 'error: no such counter';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Map<String, dynamic> _bundle(DevKey k) =>
    jsonDecode(utf8.decode(base64Decode(k.bundle))) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemDb store;
  late DevKey m1;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    store = MemDb();
    final pair = testKeyPair();
    await signalSession.bootstrap(
      database: store,
      xPubBytes: pair.xPub,
      xPrivBytes: pair.privateKey.serialize(),
    );
    // his key as pinned before 0.6: the same identity, no kyber prekey
    m1 = DevKey(
      keyId: 'm1',
      threeWords: _words,
      xPub: _hex(pair.xPub),
      bundle: base64Encode(
        utf8.encode(
          jsonEncode({'identityKey': base64Encode(pair.publicKey.serialize())}),
        ),
      ),
      fc: _fc,
    );
  });

  void everyday() {
    final db = DevTestDb(MemDb());
    useDatabasesForTest(db, Session(db));
  }

  setUp(() {
    useEngineForTest(_Engine());
    useDevKeysForTest([m1]);
    everyday();
    appState.myId = _words;
    appState.myOnion = '';
    appState.myXPub = m1.xPub;
  });

  tearDown(() {
    useDevKeysForTest(null);
    appState.myXPub = '';
    lockState.inVault = false;
    linkedRoleForTest = false;
    linkedDevicesForTest = null;
  });

  test('the copied card is his pinned key, with the kyber prekey', () async {
    final card = await appState.myDevCard();
    expect(card, isNotNull);
    final k = DevKey.fromLink(card!, keyId: 'm1')!;
    expect(k.xPub, m1.xPub);
    expect(k.threeWords, m1.threeWords);
    expect(k.fc, m1.fc);
    expect(devCardChecks(k), isTrue);
    expect(devCardStarts(k), isTrue);
    final b = _bundle(k);
    expect(b['signedPreKeyId'], 1);
    expect(b['preKeyId'], invitePreKeyId);
    expect(b['kyberPreKeyId'], kInviteKyberId);
  });

  test('copied again: the same card, and nothing made or written', () async {
    final rows = store.dump();
    final log = store.log.length;
    final first = await appState.myDevCard();
    expect(first, isNotNull);
    for (var i = 0; i < 3; i++) {
      expect(await appState.myDevCard(), first);
    }
    expect(store.log.length, log);
    expect(store.dump(), rows);
  });

  test('none for anyone else, the decoy, a vault or a linked device', () async {
    appState.myXPub = _hex(testKeyPair().xPub);
    expect(appState.devCardHere, isFalse);
    expect(await appState.myDevCard(), isNull);
    appState.myXPub = m1.xPub;

    final decoy = DevTestDb(MemDb(), HaloContainer.decoy);
    useDatabasesForTest(DevTestDb(MemDb()), Session(decoy));
    expect(appState.devCardHere, isFalse);
    expect(await appState.myDevCard(), isNull);
    everyday();

    lockState.inVault = true;
    expect(appState.devCardHere, isFalse);
    expect(await appState.myDevCard(), isNull);
    lockState.inVault = false;

    linkedDevicesForTest = true;
    linkedRoleForTest = true;
    expect(appState.devCardHere, isFalse);
    expect(await appState.myDevCard(), isNull);
    linkedRoleForTest = false;

    expect(appState.devCardHere, isTrue);
    expect(await appState.myDevCard(), isNotNull);
  });

  test('none when it would not be the pinned card', () async {
    // a first-contact address the pinned card does not name
    useDevKeysForTest([
      DevKey(
        keyId: 'm1',
        threeWords: _words,
        xPub: m1.xPub,
        bundle: m1.bundle,
        fc: 'ab' * 32,
      ),
    ]);
    appState.myXPub = m1.xPub;
    expect(await appState.myDevCard(), isNull);
    // other three words than the pinned ones
    useDevKeysForTest([m1]);
    appState.myId = 'quiet-amber-lake';
    expect(await appState.myDevCard(), isNull);
    // a retired key: not his phone any more
    useDevKeysForTest([
      DevKey(
        keyId: 'm1',
        threeWords: _words,
        xPub: m1.xPub,
        bundle: m1.bundle,
        fc: m1.fc,
        status: DevKeyStatus.retired,
      ),
    ]);
    appState.myXPub = m1.xPub;
    appState.myId = _words;
    expect(await appState.myDevCard(), isNull);
  });
}
