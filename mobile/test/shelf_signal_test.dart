// SPDX-License-Identifier: GPL-3.0-or-later
// a full shelf turns a message down inside signal's open, before the
// session is stored: on a first message (its one-time prekey), on a later
// one while the sender still sends prekey messages, and on a plain one. the
// same cipher opens afterwards, and the prekey is there until it does. two
// real sessions, the stores in maps
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        processPeerBundle,
        signalDecrypt,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/stranger_gate.dart' show ShelfFull;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _me = 'my-own-words';
const _them = 'them-quiet-river';

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

typedef _Phone = ({SignalSession ss, String xPub});

Future<_Phone> _phone() async {
  final pair = Curve.generateKeyPair();
  final xPub = pair.publicKey.serialize().sublist(1);
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: xPub,
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (ss: ss, xPub: _hex(xPub));
}

class _Engine implements HaloEngine {
  _Engine(this.x);
  final String x;
  @override
  String myXPubkey() => x;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

// my card with a one-time prekey on it, not the kept invite one
Future<(String, int)> _cardWithOneTime() async {
  final ss = signalSession;
  var id = 1;
  while (!await ss.preKeyStore.containsPreKey(id)) {
    id++;
    if (id > 500) throw StateError('no one-time prekey');
  }
  final spk = await ss.signedPreKeyStore.loadSignedPreKey(1);
  final pk = await ss.preKeyStore.loadPreKey(id);
  final card = {
    'registrationId': ss.registrationId,
    'deviceId': 1,
    'preKeyId': pk.id,
    'preKeyPublic': base64Encode(pk.getKeyPair().publicKey.serialize()),
    'signedPreKeyId': spk.id,
    'signedPreKeyPublic': base64Encode(spk.getKeyPair().publicKey.serialize()),
    'signedPreKeySignature': base64Encode(spk.signature),
    'identityKey': base64Encode(ss.identityKeyPair.getPublicKey().serialize()),
  };
  return (base64Encode(utf8.encode(jsonEncode(card))), id);
}

// what the far phone opens of mine
Future<String> _theyOpen(_Phone p, String wireB64) async {
  final wire = base64Decode(wireB64);
  final body = Uint8List.fromList(wire.sublist(1));
  final c = SessionCipher(
    p.ss.sessionStore,
    p.ss.preKeyStore,
    p.ss.signedPreKeyStore,
    p.ss.identityStore,
    SignalProtocolAddress(_me, 1),
  );
  final plain = wire[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return utf8.decode(plain);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late _Phone them;
  late int oneTime;

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('shelf_signal');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final me = Curve.generateKeyPair();
    useEngineForTest(_Engine(_hex(me.publicKey.serialize().sublist(1))));
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    them = await _phone();
    final (card, id) = await _cardWithOneTime();
    oneTime = id;
    await processPeerBundle(_me, card, into: them.ss);
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  final addr = SignalProtocolAddress(_them, 1);

  // turned down once, then opened
  Future<void> downThenOpen(String plain, {required int type}) async {
    final wire = await them.ss.encryptTo(_me, plain);
    expect(base64Decode(wire)[0], type);
    var asked = 0;
    await expectLater(
      signalDecrypt(
        _them,
        wire,
        flagKeyChange: true,
        keep: (p) {
          asked++;
          expect(p, plain);
          return false;
        },
      ),
      throwsA(isA<ShelfFull>()),
    );
    expect(asked, 1);
    expect(
      await signalDecrypt(_them, wire, flagKeyChange: true, keep: (_) => true),
      plain,
    );
  }

  test('a first message keeps its prekey and its session unmade', () async {
    final wire = await them.ss.encryptTo(_me, 'first');
    final pkm = PreKeySignalMessage(base64Decode(wire).sublist(1));
    expect(pkm.getPreKeyId().value, oneTime);
    await expectLater(
      signalDecrypt(_them, wire, flagKeyChange: true, keep: (_) => false),
      throwsA(isA<ShelfFull>()),
    );
    expect(await signalSession.preKeyStore.containsPreKey(oneTime), isTrue);
    expect(await signalSession.sessionStore.containsSession(addr), isFalse);
    expect(await signalDecrypt(_them, wire, flagKeyChange: true), 'first');
    // opened at last, it spent the prekey
    expect(await signalSession.preKeyStore.containsPreKey(oneTime), isFalse);
  });

  test('a later prekey message on the session opens again', () async {
    final wire = await them.ss.encryptTo(_me, 'second');
    expect(base64Decode(wire)[0], CiphertextMessage.prekeyType);
    var asked = 0;
    await expectLater(
      signalDecrypt(
        _them,
        wire,
        flagKeyChange: true,
        keep: (_) {
          asked++;
          return false;
        },
      ),
      throwsA(isA<ShelfFull>()),
    );
    // turned down once, not tried again under the prekey
    expect(asked, 1);
    expect(await signalDecrypt(_them, wire, flagKeyChange: true), 'second');
  });

  test('a plain message opens again', () async {
    // my answer: their next is a plain message
    await _theyOpen(them, await signalSession.encryptTo(_them, 'hi'));
    await downThenOpen('third', type: CiphertextMessage.whisperType);
  });

  test('a start finds their key in signal when the row has none', () async {
    final live = ArrivalRows(HaloContainer.everyday)
      ..person(_them, onion: 'o', xpub: '');
    final io = ArrivalIo();
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    final app = AppState(io: io, router: router)..myId = _me;
    useDatabasesForTest(live, Session(live));
    await app.letHeldIn(live);
    expect(io.freed, [them.xPub]);
  });
}
