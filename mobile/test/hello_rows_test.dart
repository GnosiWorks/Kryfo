// SPDX-License-Identifier: GPL-3.0-or-later
// v4 invites and hellos in the app (identity v4 2.3, 3.1, 3.3): a reset
// takes the link people hold with it; a hello is routed and named as a
// first contact is, on both sides; one session and one open row per peer
// when a hello and a link add meet; a key's hellos go with its delete or
// block; a session and its pair's seed are kept together; a one-time
// invite goes once anything opened on it; the upkeep runs while the app
// does. real signal and real rows of the invite tables, the engine stood in
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart'
    show DevKey, currentDevKey, useDevKeysForTest;
import 'package:kryfo/first_contact.dart' show firstFails;
import 'package:kryfo/identities.dart';
import 'package:kryfo/invites.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        AppStateContacts,
        AppStateInvites,
        AppStateProfile,
        AppStateReceive,
        HaloEngine,
        handleHaloUriAdded,
        openAddedChatLater,
        openDevChatLater,
        unboundIdOf,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'signal_kit.dart';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _unhex(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

final _p = BigInt.parse(
  'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
  radix: 16,
);

// whether x is the x of a secp256k1 point, as the shim asks (2.4)
bool _lifts(List<int> x) {
  final v = BigInt.parse(_hex(x), radix: 16);
  if (v >= _p) return false;
  final a = (v.modPow(BigInt.from(3), _p) + BigInt.from(7)) % _p;
  final y = a.modPow((_p + BigInt.one) >> 2, _p);
  return y.modPow(BigInt.two, _p) == a;
}

// the engine's public half of a first-contact key, stood in
String _fcPkOf(Uint8List sk) {
  final x = sha256.convert(sk).bytes;
  return _lifts(x) ? _hex(x) : 'error: not a key';
}

const _b32 = 'abcdefghijklmnopqrstuvwxyz234567';

// an onion address for a key, in the shape onionKeyOf reads back
String _onionOf(List<int> key) {
  final b = [...key, 0, 0, 3];
  var acc = 0, bits = 0;
  final out = StringBuffer();
  for (final x in b) {
    acc = (acc << 8) | x;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_b32[(acc >> bits) & 31]);
    }
  }
  return '$out.onion';
}

String _sealOf(String x) => sha256.convert(utf8.encode('seal:$x')).toString();

// the words each face key stands for
final _idOf = <String, String>{};

final _myFace = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 11)));
// an onion service key: a real ed25519 point, as the shim asks
List<int> _onionKeyOf(int seed) => ed
    .public(ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, seed))))
    .bytes;
final _onionKey = _onionKeyOf(12);

class _Engine implements HaloEngine {
  _Engine(this.x);
  final String x;
  final unsubscribed = <String>[];
  final hellos = <String>[];
  @override
  String idFromEdPub(String hexPub) => _idOf[hexPub] ?? 'no-such-id';
  @override
  String myXPubkey() => x;
  @override
  String myEdPubkey() => _hex(ed.public(_myFace).bytes);
  @override
  void nostrSubscribeBg(int ident, String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(int ident, String peerXPubHex) {}
  @override
  String helloSealPk(int ident, String senderXHex) => _sealOf(senderXHex);
  @override
  String onionOfKey(String keyHex) => _onionOf(_unhex(keyHex));
  @override
  String faceSign(String msgHex) =>
      _hex(ed.sign(_myFace, _unhex(msgHex)));
  @override
  String fcKeyPk(String skHex) => _fcPkOf(_unhex(skHex));
  @override
  Future<String> subscribeFcKey(int ident, String inviteId, String sk) async =>
      'ok';
  @override
  Future<String> unsubscribeFcKey(int ident, String inviteId) async {
    unsubscribed.add(inviteId);
    return 'ok';
  }

  @override
  Future<String> pairSeed(int ident, String x, String seed) async => 'ok';
  @override
  Future<String> sendHello(int ident, String owner, String fc, String m) async {
    hellos.add(owner);
    return 'ok';
  }

  @override
  String firstContactPk(int ident, int counter) => 'fc$counter';
  @override
  Future<String> subscribeFirstContact(int ident, int counter) async => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

class _Io extends AppIo {
  const _Io();
  @override
  void listen(int ident, String xPub, {bool fresh = false}) {}
  @override
  void unlisten(int ident, String xPub) {}
  @override
  Future<String> relaySend(int ident, String xPub, String cipher) async => 'ok';
  @override
  Future<String> onionSend(String onion, String cipher) async => 'ok';
  @override
  Future<String> firstContactSend(
    int ident,
    String x,
    String fc,
    String c,
  ) async => 'ok';
  @override
  Future<String> letHeld(int ident, String xPub, String how) async => 'ok';
  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
    Object? on,
    String? msgUid,
    int? burnAt,
  }) async {}
  @override
  Future<void> unnotify(String payload) async {}
  @override
  Future<void> unnotifyGone(String payload, Set<String> tags) async {}
  @override
  String edPub() => 'ed-me';
  @override
  String xPub() => 'x-me';
}

// the everyday rows in maps, with the invite tables and a copy of each
// contact (its key claimed) in a file of rows, as the real container
// keeps them side by side
class _Rows extends ArrivalRows {
  _Rows(this.db) : super(HaloContainer.everyday);
  final MemDb db;
  @override
  Future<Database> open() async => db;

  @override
  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
    bool owe = false,
  }) async {
    await super.upsertContact(
      haloId,
      onion,
      xpub,
      accepted: accepted,
      owe: owe,
    );
    final p = people[haloId]!;
    await db.delete('contacts', where: 'halo_id = ?', whereArgs: [haloId]);
    await db.insert('contacts', {
      'halo_id': haloId,
      'onion': p['onion'] ?? '',
      'xpub': p['xpub'] ?? '',
      'first_seen': 0,
      'last_seen': 0,
      'accepted': p['accepted'],
      'blocked': p['blocked'] ?? 0,
      'ikey': identityKeyHex(p['xpub'] as String?),
    });
  }

  @override
  Future<void> oweHello(String ownerHex, String answersHex, String fc) =>
      db.insert('hellos', {
        'ident': kMainIdent,
        'way': 'want',
        'peer': ownerHex,
        'invite_id': answersHex,
        'fc': fc,
        'at': DateTime.now().millisecondsSinceEpoch,
      });

  // a hello waiting is a request, as kRequestRows has it
  @override
  Future<bool> askedBefore(String haloId) async {
    if (await super.askedBefore(haloId)) return true;
    final p = people[haloId];
    final k = identityKeyHex(p?['xpub'] as String?);
    if (p == null || p['accepted'] != 0 || k == null) return false;
    return (await db.query(
      'hellos',
      where: 'way = ? AND peer = ?',
      whereArgs: ['in', k],
    )).isNotEmpty;
  }
}

// someone else's phone: its store and rows, its face and the words it
// stands for
class _Phone {
  _Phone._(this.db, this.ss, this.face, this.words);
  final MemDb db;
  final SignalSession ss;
  final InviteFace face;
  final String words;

  static Future<_Phone> make(String words, int seed) async {
    final db = MemDb();
    final ss = await testStore(db: db);
    final keys = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, seed)));
    final pub = Uint8List.fromList(ed.public(keys).bytes);
    _idOf[_hex(pub)] = words;
    return _Phone._(
      db,
      ss,
      InviteFace(
        onionKey: Uint8List.fromList(_onionKeyOf(seed + 1)),
        face: pub,
        sign: (m) => Uint8List.fromList(ed.sign(keys, m)),
      ),
      words,
    );
  }

  List<int> get key => ss.identity.public;
  String get x => _hex(key.sublist(1));
  String get keyHex => _hex(key);

  // their hello to my invite [answers], as it comes off the relay
  Future<({String line, Uint8List hello, InviteRow once})> helloTo(
    String answers,
  ) async {
    final (hello, once) = await makeHello(
      db,
      ss,
      answers: _unhex(answers),
      owner: signalSession.identity.public,
      fcPkOf: _fcPkOf,
      face: face,
    );
    final wire = helloWireOf(
      hello,
      grindPow(helloPowSeed(hello), powBits),
    );
    return (line: '${_sealOf(x)}|$wire', hello: hello, once: once);
  }

  Future<InviteRow> mainInvite() => makeInvite(
    db,
    ss,
    kind: kInviteMain,
    fcPkOf: _fcPkOf,
    face: face,
  );
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb db;
  late _Rows live;
  late _Engine engine;
  late AppState app;
  late ArrivalStore store;

  Future<void> world({ArrivalStore? hidden}) async {
    store = hidden ?? ArrivalStore();
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    app = AppState(io: const _Io(), router: router)
      ..myId = 'my-own-words'
      ..myOnion = _onionOf(_onionKey);
    useDatabasesForTest(live, Session(live));
  }

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('hello_rows');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    db = MemDb();
    final me = testKeyPair();
    engine = _Engine(_hex(me.publicKey.serialize().sublist(1)));
    useEngineForTest(engine);
    await signalSession.bootstrap(
      database: db,
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  final opened = <String>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'fc_counter': '1'});
    firstFails.clear();
    for (final t in const [
      'invites',
      'hellos',
      'hello_seen',
      'fc_keys',
      'pairs',
      'contacts',
    ]) {
      await db.delete(t);
    }
    await db.delete(
      'signal_meta',
      where: 'k = ?',
      whereArgs: ['kin4_main_made'],
    );
    engine.unsubscribed.clear();
    engine.hellos.clear();
    live = _Rows(db);
    await world();
    opened.clear();
    final was = openAddedChatLater;
    openAddedChatLater = opened.add;
    addTearDown(() => openAddedChatLater = was);
  });

  Future<InviteRow> myMain() async {
    await app.keepMyInvites();
    return (await currentMainInvite(db, kMainIdent))!;
  }

  Future<List<Map<String, Object?>>> hellosOf(String way, String peer) =>
      db.query(
        'hellos',
        where: 'way = ? AND peer = ?',
        whereArgs: [way, peer],
      );

  test('a session made again and its pair\'s seed are kept together: a '
      'failed write leaves the old pair as it was', () async {
    final p = await _Phone.make('seed-together', 71);
    await app.startFromInvite(
      p.words,
      readInvite(p.ss.lib, (await p.mainInvite()).link),
    );
    final before = await pairOf(db, kMainIdent, p.keyHex);
    final session = await signalSession.sessionStore.load(p.words);
    expect(before.seed, isNotNull);
    db.failOn = 'insert:pairs';
    addTearDown(() => db.failOn = null);
    await expectLater(
      app.startFromInvite(
        p.words,
        readInvite(p.ss.lib, (await p.mainInvite()).link),
      ),
      throwsStateError,
    );
    db.failOn = null;
    final after = await pairOf(db, kMainIdent, p.keyHex);
    expect(after.conv, before.conv);
    expect(after.seed, before.seed);
    expect(await signalSession.sessionStore.load(p.words), session);
  });

}
