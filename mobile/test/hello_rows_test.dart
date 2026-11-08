// SPDX-License-Identifier: GPL-3.0-or-later
// v4 invites and hellos in the app: a reset
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
import 'package:kryfo/heal.dart' show kRestoreCutPref;
import 'package:kryfo/identities.dart';
import 'package:kryfo/invites.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        AppStateContacts,
        AppStateInvites,
        AppStateOldPeers,
        AppStatePairCodes,
        AppStateProfile,
        AppStateReceive,
        AppStateRoute,
        HaloEngine,
        handleFetchForTest,
        handleHaloUriAdded,
        hasSessionWith,
        LinkKin,
        linkKinOf,
        linkPartsOf,
        kNoHelloWait,
        kOldPeerWait,
        oldPeerHelloDue,
        haloUriV3,
        openAddedChatLater,
        openDevChatLater,
        outsideLinkText,
        pairPeerOf,
        sendFirstContactNoted,
        unboundIdOf,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:kryfo/wire_pad.dart' show unpad;
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

// whether x is the x of a secp256k1 point, as the shim asks
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
  final subscribed = <String>[];
  final hellos = <String>[];
  // fc -> the engine's answer for a hello to it; ok otherwise
  final helloAnswers = <String, String>{};
  // the x keys whose pair's seed the engine was handed
  final seeded = <String>[];
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
  String faceSign(String msgHex) => _hex(ed.sign(_myFace, _unhex(msgHex)));
  @override
  String fcKeyPk(String skHex) => _fcPkOf(_unhex(skHex));
  @override
  Future<String> subscribeFcKey(int ident, String inviteId, String sk) async {
    subscribed.add(inviteId);
    return 'ok';
  }

  @override
  Future<String> unsubscribeFcKey(int ident, String inviteId) async {
    unsubscribed.add(inviteId);
    return 'ok';
  }

  @override
  Future<String> pairSeed(int ident, String x, String seed) async {
    seeded.add(x);
    return 'ok';
  }

  @override
  Future<String> sendHello(int ident, String owner, String fc, String m) async {
    final a = helloAnswers[fc];
    if (a != null) return a;
    hellos.add(owner);
    return 'ok';
  }

  @override
  Future<String> sendFirstContact(
    int ident,
    String peerXPubHex,
    String fcPk,
    String b64Cipher,
  ) async => firstContactAnswer;
  // what a first contact's send answers
  String firstContactAnswer = 'ok';

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
  void listenHidden(int ident, String xPub, {bool fresh = false}) =>
      listen(ident, xPub, fresh: fresh);
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
  _Rows(this.db, [HaloContainer c = HaloContainer.everyday]) : super(c);
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
    String answers, {
    int? nowMs,
  }) async {
    final (hello, once) = await makeHello(
      db,
      ss,
      answers: _unhex(answers),
      owner: signalSession.identity.public,
      fcPkOf: _fcPkOf,
      face: face,
      nowMs: nowMs,
    );
    final wire = helloWireOf(hello, grindPow(helloPowSeed(hello), powBits));
    return (line: '${_sealOf(x)}|$wire', hello: hello, once: once);
  }

  Future<InviteRow> mainInvite() =>
      makeInvite(db, ss, kind: kInviteMain, fcPkOf: _fcPkOf, face: face);

  // the one-time invite a pairing seals to the other side
  Future<InviteRow> pairInvite() =>
      makeInvite(db, ss, kind: kInviteOneTime, fcPkOf: _fcPkOf, face: face);

  // the opener of a session built from my invite [at], with the pair's seed
  // and a face signature, as a v4 first contact sends it
  Future<String> openerTo(InviteRow at, String uid) async {
    final inv = readInvite(ss.lib, at.link);
    await ss.processBundle('me', inv.block!.bundle);
    final frame = await wrapMessage(
      'hi',
      msgUid: uid,
      sender: SenderInfo(
        haloId: words,
        edPub: _hex(face.face),
        onion: 'o-$words',
        xPub: x,
      ),
    );
    final j =
        jsonDecode(frame.substring(kEnvelopePrefix.length))
            as Map<String, dynamic>;
    j['pg'] = 4;
    j['as'] = _hex(List<int>.generate(32, (i) => i + 7));
    j['fs'] = _hex(face.sign(faceText(key, _unhex(at.id))));
    final c = await ss.encryptTo('me', '$kEnvelopePrefix${jsonEncode(j)}');
    return '${_sealOf(x)}|$c';
  }
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
    engine.subscribed.clear();
    engine.hellos.clear();
    engine.helloAnswers.clear();
    engine.seeded.clear();
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
      db.query('hellos', where: 'way = ? AND peer = ?', whereArgs: [way, peer]);

  test('a reset drops the main invite people hold at once and makes a new '
      'one; once the v3 keys went it makes none of them again', () async {
    final first = await myMain();
    await app.resetInviteAddress();
    final now = (await currentMainInvite(db, kMainIdent))!;
    expect(now.id, isNot(first.id));
    expect(await inviteOf(db, kMainIdent, first.id), isNull);
    expect(
      await signalSession.signedPreKeyStore.contains(first.spkId!),
      isFalse,
    );
    expect(engine.unsubscribed, contains(first.id));
    // the roster invite keeps its own: a reset is of the link alone
    final roster = (await currentRosterInvite(db, kMainIdent))!;
    expect(
      (await fcKeysOf(db, kMainIdent)).keys,
      unorderedEquals([now.id, roster.id]),
    );
    expect(await app.myV4Invite(), inviteLink(now.link));
  });

  test('a hello from someone a shut vault hides is never filed on the '
      'everyday side', () async {
    final main = await myMain();
    final p = await _Phone.make('hidden-vault-one', 21);
    // the vault holds them, and the signal store their words' key
    final hidden = ArrivalStore();
    await hidden.putHidden(
      p.words,
      kHiddenPeer,
      peerCard(RouterCard(p.words, 'o-p', p.x)),
      1,
    );
    await hidden.putMeta('pub', 'pub-A');
    await world(hidden: hidden);
    await signalSession.identityStore.saw(p.words, p.key);
    final h = await p.helloTo(main.id);
    await app.receiveRelay([(peer: 'f0:${main.id}', cipher: h.line)]);
    await _settle();
    expect(live.people[p.words], isNull);
    expect(live.people[unboundIdOf(p.key)], isNull);
    expect(await hellosOf('in', p.keyHex), isEmpty);
  });

  test('a hello giving words bound here to another key, or let go by "this '
      'isn\'t them", is filed on an id of its own', () async {
    final main = await myMain();
    final p = await _Phone.make('bound-elsewhere-one', 31);
    final other = await _Phone.make('bound-elsewhere-two', 33);
    await signalSession.identityStore.saw(p.words, other.key);
    final h = await p.helloTo(main.id);
    await app.receiveRelay([(peer: 'f0:${main.id}', cipher: h.line)]);
    await _settle();
    expect(live.people[p.words], isNull);
    expect(live.people[unboundIdOf(p.key)]?['accepted'], 0);
    final q = await _Phone.make('let-go-words', 35);
    live.tombedNames.add(q.words);
    final h2 = await q.helloTo(main.id);
    await app.receiveRelay([(peer: 'f0:${main.id}', cipher: h2.line)]);
    await _settle();
    expect(live.people[q.words], isNull);
    expect(live.people[unboundIdOf(q.key)]?['accepted'], 0);
  });

  test('a qr goes through every check a link does: a shut vault\'s person '
      'reads as any link that does not take, and the developer\'s opens his '
      'chat', () async {
    final p = await _Phone.make('hidden-qr-one', 41);
    final inv = await p.mainInvite();
    final qr = inviteLink(inv.qr!);
    expect(
      await handleHaloUriAdded(qr, hidden: (id) => id == p.words, app: app),
      (l10n.appInvalidUri, false),
    );
    expect(await db.query('hellos'), isEmpty);
    expect(live.people[p.words], isNull);
    // the developer's own qr
    final dev = await _Phone.make('dev-pinned-words', 43);
    final devInv = await dev.mainInvite();
    useDevKeysForTest([
      DevKey(
        keyId: 'k-hello',
        threeWords: dev.words,
        xPub: dev.x,
        bundle: '',
        fc: '00' * 32,
      ),
    ]);
    addTearDown(() => useDevKeysForTest(null));
    final chats = <String>[];
    final was = openDevChatLater;
    openDevChatLater = chats.add;
    addTearDown(() => openDevChatLater = was);
    expect(await handleHaloUriAdded(inviteLink(devInv.qr!), app: app), (
      '',
      true,
    ));
    expect(chats, [currentDevKey!.chatId]);
    expect(await db.query('hellos'), isEmpty);
  });

  test('one open row per peer, and a link add with their hello waiting '
      'answers only the hello', () async {
    final p = await _Phone.make('two-ways-one', 51);
    final a = await p.mainInvite();
    final b = await p.mainInvite();
    for (final r in [a, b]) {
      await app.startFromInvite(p.words, readInvite(p.ss.lib, r.link));
    }
    expect(
      [for (final r in await hellosOf('open', p.keyHex)) r['invite_id']],
      [b.id],
    );
    await db.delete('hellos');
    // their hello came first, then I add their link
    final main = await myMain();
    final q = await _Phone.make('two-ways-two', 53);
    final h = await q.helloTo(main.id);
    await app.receiveRelay([(peer: 'f0:${main.id}', cipher: h.line)]);
    await _settle();
    expect(await hellosOf('in', q.keyHex), hasLength(1));
    final link = inviteLink((await q.mainInvite()).link);
    final (_, added) = await handleHaloUriAdded(link, app: app);
    expect(added, isTrue);
    await _settle();
    expect(
      [for (final r in await hellosOf('open', q.keyHex)) r['invite_id']],
      [h.once.id],
    );
    expect(await hellosOf('in', q.keyHex), isEmpty);
  });

  test('a v4 link tapped or opened from outside is read as the door reads '
      'it: its words, and who they are here', () async {
    final q = await _Phone.make('four-tapped-link', 131);
    final link = inviteLink((await q.mainInvite()).link);
    final qr = inviteLink((await q.mainInvite()).qr!);
    expect(linkPartsOf(link)?['id'], q.words);
    expect(linkPartsOf(qr)?['id'], q.words);
    expect(linkPartsOf('kryfo://share?v=4&i=AAAA'), isNull);
    final (_, added) = await handleHaloUriAdded(link, app: app);
    expect(added, isTrue);
    await _settle();
    final (kin, name) = await linkKinOf(link, app: app);
    expect(name, q.words);
    expect(kin, isNot(LinkKin.stranger));
  });

  test('in a decoy a qr and a v3 link with its first-contact address say '
      'what the everyday side says, and keep the person on the decoy alone: '
      'no hello, no key, no row of the everyday side', () async {
    Future<(String, String)> links(String words, int seed) async {
      final p = await _Phone.make('$words-qr', seed);
      final qr = inviteLink((await p.mainInvite()).qr!);
      final o = await _Phone.make('$words-vee', seed + 2);
      final v3 = haloUriV3(
        o.words,
        _onionOf(_onionKeyOf(seed + 3)),
        Uri.encodeQueryComponent(await o.ss.makeBundleB64()),
        _hex(List.filled(32, seed)),
      );
      return (qr, v3);
    }

    // the everyday side first
    final (qr1, v31) = await links('real-side', 71);
    expect(await handleHaloUriAdded(qr1, app: app), (l10n.helloSent, true));
    expect(await handleHaloUriAdded(v31, app: app), (l10n.helloSentOld, true));
    // the pass under way, which grinds each hello's proof of work
    await app.sendHellosOwed();
    await app.sendHellosOwed();
    expect(engine.hellos, hasLength(2));
    // the decoy, on others
    final (qr2, v32) = await links('decoy-side', 81);
    final decoyDb = MemDb();
    final decoy = _Rows(decoyDb, HaloContainer.decoy);
    final helloRows = db.rows('hellos').length;
    final everydayPeople = live.people.keys.toSet();
    useDatabasesForTest(live, Session(decoy));
    try {
      expect(await handleHaloUriAdded(qr2, app: app), (l10n.helloSent, true));
      expect(await handleHaloUriAdded(v32, app: app), (
        l10n.helloSentOld,
        true,
      ));
      // and again: saved already, as the everyday side says
      expect(await handleHaloUriAdded(qr2, app: app), (
        l10n.appAlreadySaved('decoy-side-qr'),
        true,
      ));
    } finally {
      useDatabasesForTest(live, Session(live));
    }
    await _settle();
    expect(decoy.people.keys, containsAll(['decoy-side-qr', 'decoy-side-vee']));
    expect(engine.hellos, hasLength(2));
    expect(db.rows('hellos'), hasLength(helloRows));
    expect(live.people.keys.toSet(), everydayPeople);
    expect(
      await signalSession.identityStore.getIdentity('decoy-side-qr'),
      isNull,
    );
    await _settle();
  });

  test('after a restore, a hello made before it from someone accepted on '
      'that key is dropped; a new person\'s is filed', () async {
    final main = await myMain();
    final now = DateTime.now().millisecondsSinceEpoch;
    const hour = 3600 * 1000;
    await (await SharedPreferences.getInstance()).setInt(kRestoreCutPref, now);
    final p = await _Phone.make('known-before-one', 61);
    await live.upsertContact(p.words, '', p.x);
    live.people[p.words]!['ikey'] = p.keyHex;
    final old = await p.helloTo(main.id, nowMs: now - 3 * hour);
    await app.receiveRelay([(peer: 'f0:${main.id}', cipher: old.line)]);
    await _settle();
    expect(await hellosOf('in', p.keyHex), isEmpty);
    final q = await _Phone.make('new-before-one', 63);
    final h = await q.helloTo(main.id, nowMs: now - 3 * hour);
    await app.receiveRelay([(peer: 'f0:${main.id}', cipher: h.line)]);
    await _settle();
    expect(await hellosOf('in', q.keyHex), hasLength(1));
  });

  test('a qr add with their hello waiting sends none of mine', () async {
    final main = await myMain();
    final q = await _Phone.make('qr-crossed-one', 55);
    final h = await q.helloTo(main.id);
    await app.receiveRelay([(peer: 'f0:${main.id}', cipher: h.line)]);
    await _settle();
    final qr = inviteLink((await q.mainInvite()).qr!);
    await handleHaloUriAdded(qr, app: app);
    await _settle();
    expect(await hellosOf('want', q.keyHex), isEmpty);
    expect(engine.hellos, isEmpty);
    expect(
      [for (final r in await hellosOf('open', q.keyHex)) r['invite_id']],
      [h.once.id],
    );
  });

  Future<(String, InviteRow)> owed(_Phone p) async {
    live.person(p.words, xpub: p.x);
    await live.upsertContact(p.words, '', p.x);
    final once = await makeInvite(
      db,
      signalSession,
      kind: kInviteOneTime,
      fcPkOf: _fcPkOf,
    );
    final at = DateTime.now().millisecondsSinceEpoch;
    for (final (way, inv) in [
      ('want', '0' * 32),
      ('out', once.id),
      ('in', '1' * 32),
    ]) {
      await db.insert('hellos', {
        'ident': kMainIdent,
        'way': way,
        'peer': p.keyHex,
        'invite_id': inv,
        'fc': 'ab' * 32,
        'at': at,
      });
    }
    return (p.words, once);
  }

  for (final how in ['delete', 'block']) {
    test('a $how lets their hellos go: none owed goes, mine out takes its '
        'one-time invite with it', () async {
      final p = await _Phone.make('gone-hellos-$how', 61);
      final (id, once) = await owed(p);
      if (how == 'delete') {
        await app.deleteConversation(id);
      } else {
        await app.block(id);
      }
      expect(
        await db.query('hellos', where: 'peer = ?', whereArgs: [p.keyHex]),
        isEmpty,
      );
      expect((await inviteOf(db, kMainIdent, once.id))?.usedAt, isNotNull);
      expect(
        await signalSession.signedPreKeyStore.contains(once.spkId!),
        isFalse,
      );
      expect(engine.unsubscribed, contains(once.id));
    });
  }

  test('a hello owed to a key with no row or a block is not sent', () async {
    final p = await _Phone.make('no-row-owed', 63);
    await live.oweHello(p.keyHex, '0' * 32, 'ab' * 32);
    await app.sendHellosOwed();
    expect(engine.hellos, isEmpty);
    expect(await hellosOf('want', p.keyHex), isEmpty);
    final q = await _Phone.make('blocked-owed', 65);
    await live.upsertContact(q.words, '', q.x);
    await db.update(
      'contacts',
      {'blocked': 1},
      where: 'halo_id = ?',
      whereArgs: [q.words],
    );
    await live.oweHello(q.keyHex, '0' * 32, 'ab' * 32);
    await app.sendHellosOwed();
    expect(engine.hellos, isEmpty);
  });

  test('a hello the engine turns down for its own address does not hold '
      'back the hellos after it', () async {
    final bad = await _Phone.make('bad-fc-owed', 67);
    await live.upsertContact(bad.words, '', bad.x);
    await live.oweHello(bad.keyHex, '0' * 32, 'zz' * 32);
    engine.helloAnswers['zz' * 32] = 'error: bad first-contact pubkey';
    final good = await _Phone.make('good-fc-owed', 69);
    await live.upsertContact(good.words, '', good.x);
    await live.oweHello(good.keyHex, '1' * 32, 'ab' * 32);
    await app.sendHellosOwed();
    expect(engine.hellos, contains(good.x));
    expect(await hellosOf('want', good.keyHex), isEmpty);
    // the turned down one is still owed, for a later pass
    expect(await hellosOf('want', bad.keyHex), hasLength(1));
  });

  test('no relay taking a hello stops the pass', () async {
    final a = await _Phone.make('no-relay-a', 71);
    await live.upsertContact(a.words, '', a.x);
    await live.oweHello(a.keyHex, '2' * 32, 'cd' * 32);
    engine.helloAnswers['cd' * 32] = 'error: no relays accepted';
    final b = await _Phone.make('no-relay-b', 73);
    await live.upsertContact(b.words, '', b.x);
    await live.oweHello(b.keyHex, '3' * 32, 'ef' * 32);
    await app.sendHellosOwed();
    expect(engine.hellos, isEmpty);
    expect(await hellosOf('want', b.keyHex), hasLength(1));
  });

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

  test('a one-time invite goes once an opener opened on it, though the '
      'opener is then refused', () async {
    final once = await makeInvite(
      db,
      signalSession,
      kind: kInviteOneTime,
      fcPkOf: _fcPkOf,
    );
    final p = await _Phone.make('opened-refused', 81);
    final inv = readInvite(p.ss.lib, once.link);
    await p.ss.processBundle('me', inv.block!.bundle);
    // no seed: refused after it opened
    final plain = await wrapMessage(
      'hi',
      msgUid: 'u-once',
      sender: SenderInfo(
        haloId: p.words,
        edPub: _hex(p.face.face),
        onion: 'o-p',
        xPub: p.x,
      ),
    );
    final c = await p.ss.encryptTo('me', plain);
    await app.receiveRelay([
      (peer: 'f0:${once.id}', cipher: '${_sealOf(p.x)}|$c'),
    ]);
    await _settle();
    expect(firstFails.codes, contains('seed'));
    expect((await inviteOf(db, kMainIdent, once.id))?.usedAt, isNotNull);
    expect(
      await signalSession.signedPreKeyStore.contains(once.spkId!),
      isFalse,
    );
    expect(
      await signalSession.kyberPreKeyStore.contains(once.kyberId!),
      isFalse,
    );
    expect(engine.unsubscribed, contains(once.id));
  });

  test('after the opener went to their one-time invite, the next seal waits '
      'for their answer and goes once it came; a main invite holds nothing '
      '(3c)', () async {
    final p = await _Phone.make('once-held', 85);
    final once = await makeInvite(
      p.db,
      p.ss,
      kind: kInviteOneTime,
      fcPkOf: _fcPkOf,
    );
    final inv = readInvite(p.ss.lib, once.link);
    await live.upsertContact(p.words, '', p.x);
    await app.startFromInvite(p.words, inv);
    final open = (await hellosOf('open', p.keyHex)).single;
    expect(open['once'], 1);
    expect(open['went_at'], isNull);
    // the opener goes, more than once while it has not reached a relay
    final first = await signalSession.encryptTo(p.words, 'first');
    expect(base64Decode(first)[0], kLsPreKey);
    expect(
      base64Decode(await signalSession.encryptTo(p.words, 'again'))[0],
      kLsPreKey,
    );
    final fc = _hex(inv.firstContact);
    expect(await sendFirstContactNoted(0, p.x, fc, first), 'ok');
    expect((await hellosOf('open', p.keyHex)).single['went_at'], isNotNull);
    await expectLater(
      signalSession.encryptTo(p.words, 'second'),
      throwsA(isA<WaitsForAnswer>()),
    );
    // a wrap's life on, that opener may have expired unread: one more goes,
    // and the rest of a burst waits for it
    final old = DateTime.now()
        .subtract(const Duration(days: 16))
        .millisecondsSinceEpoch;
    await db.update(
      'hellos',
      {'went_at': old},
      where: 'way = ? AND peer = ?',
      whereArgs: ['open', p.keyHex],
    );
    final late = await signalSession.encryptTo(p.words, 'late');
    expect(base64Decode(late)[0], kLsPreKey);
    await expectLater(
      signalSession.encryptTo(p.words, 'burst'),
      throwsA(isA<WaitsForAnswer>()),
    );
    // its send failed: its stamp goes, and the next one goes too rather
    // than waiting out another wrap's life
    engine.firstContactAnswer = 'error: no relay';
    expect(await sendFirstContactNoted(0, p.x, fc, late), isNot('ok'));
    expect((await hellosOf('open', p.keyHex)).single['went_at'], isNull);
    final retry = await signalSession.encryptTo(p.words, 'late again');
    expect(base64Decode(retry)[0], kLsPreKey);
    engine.firstContactAnswer = 'ok';
    expect(await sendFirstContactNoted(0, p.x, fc, retry), 'ok');
    final stamped = (await hellosOf('open', p.keyHex)).single['went_at'] as int;
    expect(stamped, greaterThan(old));
    await expectLater(
      signalSession.encryptTo(p.words, 'second'),
      throwsA(isA<WaitsForAnswer>()),
    );
    // the chat reads it as waiting on them, not on tor
    expect(signalSession.awaitsAnswer(p.words), isTrue);
    final before = DateTime.now().millisecondsSinceEpoch;
    // their answer: plain messages from here
    expect(
      unpad(
        utf8.decode(
          await p.ss.open(
            'me',
            kLsPreKey,
            Uint8List.fromList(base64Decode(first).sublist(1)),
          ),
        ),
      ),
      'first',
    );
    final back = base64Decode(await p.ss.encryptTo('me', 'back'));
    await signalSession.open(
      p.words,
      back[0],
      Uint8List.fromList(back.sublist(1)),
    );
    expect(signalSession.awaitsAnswer(p.words), isFalse);
    expect(signalSession.answeredAt(p.words), greaterThanOrEqualTo(before));
    expect(
      base64Decode(await signalSession.encryptTo(p.words, 'second'))[0],
      kLsWhisper,
    );
    // a main invite keeps listening: nothing is held for it
    final q = await _Phone.make('main-not-held', 87);
    final qi = readInvite(q.ss.lib, (await q.mainInvite()).link);
    await live.upsertContact(q.words, '', q.x);
    await app.startFromInvite(q.words, qi);
    expect((await hellosOf('open', q.keyHex)).single['once'], 0);
    final q1 = await signalSession.encryptTo(q.words, 'one');
    await sendFirstContactNoted(0, q.x, _hex(qi.firstContact), q1);
    expect(
      base64Decode(await signalSession.encryptTo(q.words, 'two'))[0],
      kLsPreKey,
    );
  });

  test('an opener at my main invite seeds the pair under their whole '
      'identity key, and the engine takes their x key', () async {
    final main = await myMain();
    final p = await _Phone.make('seeds-the-pair', 83);
    final inv = readInvite(p.ss.lib, main.link);
    await p.ss.processBundle('me', inv.block!.bundle);
    final frame = await wrapMessage(
      'hi',
      msgUid: 'u-seeded',
      sender: SenderInfo(
        haloId: p.words,
        edPub: _hex(p.face.face),
        onion: 'o-p',
        xPub: p.x,
      ),
    );
    final j =
        jsonDecode(frame.substring(kEnvelopePrefix.length))
            as Map<String, dynamic>;
    final seed = List<int>.generate(32, (i) => 200 - i);
    j['pg'] = 4;
    j['as'] = _hex(seed);
    j['fs'] = _hex(p.face.sign(faceText(p.key, _unhex(main.id))));
    final c = await p.ss.encryptTo('me', '$kEnvelopePrefix${jsonEncode(j)}');
    await app.receiveRelay([
      (peer: 'f0:${main.id}', cipher: '${_sealOf(p.x)}|$c'),
    ]);
    await _settle();
    final pair = await pairOf(db, kMainIdent, p.keyHex);
    expect(pair.conv, kConvSeeded);
    expect(pair.seed, seed);
    expect(engine.seeded, [p.x]);
  });

  test('the upkeep runs again once an hour while the app runs: an expired '
      'invite\'s keys go without a start', () async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    await app.keepMyInvites(nowMs: t0);
    final once = await makeInvite(
      db,
      signalSession,
      kind: kInviteOneTime,
      fcPkOf: _fcPkOf,
      nowMs: t0,
    );
    await app.keepMyInvitesDue(nowMs: t0 + 10 * 60 * 1000);
    expect(await inviteOf(db, kMainIdent, once.id), isNotNull);
    await app.keepMyInvitesDue(
      nowMs: t0 + (kOneTimeHours + kSkewHours + 2) * 3600 * 1000,
    );
    expect(await inviteOf(db, kMainIdent, once.id), isNull);
    expect(
      await signalSession.signedPreKeyStore.contains(once.spkId!),
      isFalse,
    );
    expect(engine.unsubscribed, contains(once.id));
  });

  test('a start before the onion is known listens on the invites people '
      'hold, and keeps them once it is there', () async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    final main = await myMain();
    // the next start: the upkeep runs before tor hands the onion back
    await world();
    app.myOnion = '';
    engine.subscribed.clear();
    final held = [for (final r in await invitesOf(db, kMainIdent)) r.id];
    await app.keepMyInvites(nowMs: t0);
    expect(engine.subscribed, unorderedEquals(held));
    expect(engine.subscribed, contains(main.id));
    expect((await currentMainInvite(db, kMainIdent))!.id, main.id);
    // nothing to keep before the hour while there is still no onion
    await app.keepMyInvitesDue(nowMs: t0 + 60 * 1000);
    expect(engine.subscribed, unorderedEquals(held));
    // the onion came: the next tick keeps them
    app.myOnion = _onionOf(_onionKey);
    final once = await makeInvite(
      db,
      signalSession,
      kind: kInviteOneTime,
      fcPkOf: _fcPkOf,
      nowMs: t0,
    );
    await app.keepMyInvitesDue(nowMs: t0 + 2 * 60 * 1000);
    expect(engine.subscribed, containsAll([main.id, once.id]));
    expect((await currentMainInvite(db, kMainIdent))!.id, main.id);
  });

  test('a start and a tick keeping the invites at once make one main '
      'invite, and a reset during an upkeep leaves only its own', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await Future.wait([
      app.keepMyInvitesDue(nowMs: now),
      app.keepMyInvites(nowMs: now),
    ]);
    expect(await invitesOf(db, kMainIdent, kind: kInviteMain), hasLength(1));
    await db.delete('invites');
    await db.delete('fc_keys');
    await Future.wait([app.keepMyInvites(), app.resetMyInvite()]);
    final mains = await invitesOf(db, kMainIdent, kind: kInviteMain);
    expect(mains, hasLength(1));
    final rosters = await invitesOf(db, kMainIdent, kind: kInviteRoster);
    expect(rosters, hasLength(1));
    expect(
      (await fcKeysOf(db, kMainIdent)).keys,
      unorderedEquals([mains.single.id, rosters.single.id]),
    );
  });

  test(
    'a pair code\'s sharer holds the invite it sealed, unheard, until '
    'the add; then only the joiner\'s opener opens there and files them',
    () async {
      await myMain();
      final mine = (await app.pairInvite())!;
      final row = mine.row as InviteRow;
      expect(row.oneTime, isTrue);
      final p = await _Phone.make('pair-code-joiner', 91);
      final peer = pairPeerOf((await p.pairInvite()).link)!;
      expect(peer.id, p.words);
      await app.pairHold(mine, peer);
      // the upkeep listens on every live invite but a held one
      engine.subscribed.clear();
      await app.keepMyInvites();
      expect(engine.subscribed, isNot(contains(row.id)));
      final (line, added) = await handleHaloUriAdded(
        peer.link,
        pairOut: row,
        app: app,
      );
      await _settle();
      expect((line, added), ('', true));
      expect(live.people[p.words]?['accepted'], 1);
      expect(opened, [p.words]);
      expect(engine.subscribed, contains(row.id));
      expect(
        [for (final r in await hellosOf('out', p.keyHex)) r['invite_id']],
        [row.id],
      );
      expect(await hellosOf('pair', p.keyHex), isEmpty);
      // the sharer starts nothing: the joiner does
      expect(engine.seeded, isEmpty);
      // anyone else at that invite is dropped before decrypt, unspent
      final q = await _Phone.make('pair-code-stranger', 93);
      await app.receiveRelay([
        (peer: 'f0:${row.id}', cipher: await q.openerTo(row, 'u-q')),
      ]);
      await _settle();
      expect(firstFails.codes, contains('owner'));
      expect((await inviteOf(db, kMainIdent, row.id))?.usedAt, isNull);
      // the joiner's opener opens, seeds the pair and spends the invite
      await app.receiveRelay([
        (peer: 'f0:${row.id}', cipher: await p.openerTo(row, 'u-p')),
      ]);
      await _settle();
      expect(engine.seeded, [p.x]);
      expect((await pairOf(db, kMainIdent, p.keyHex)).conv, kConvSeeded);
      expect((await inviteOf(db, kMainIdent, row.id))?.usedAt, isNotNull);
      expect(await hellosOf('out', p.keyHex), isEmpty);
    },
  );

  test('a pair code\'s joiner adds the sharer as from a v4 link: the session '
      'from its one-time invite, the opener to its address', () async {
    final p = await _Phone.make('pair-code-sharer', 95);
    final theirs = await p.pairInvite();
    final peer = pairPeerOf(theirs.link)!;
    final (line, added) = await handleHaloUriAdded(peer.link, app: app);
    await _settle();
    expect((line, added), ('', true));
    expect(live.people[p.words]?['accepted'], 1);
    expect(engine.seeded, [p.x]);
    final open = await hellosOf('open', p.keyHex);
    expect([for (final r in open) r['invite_id']], [theirs.id]);
    expect(open.single['once'], 1);
    // the joiner's own invite went to the sharer only to name them: it goes
    final mine = (await app.pairInvite())!;
    await app.pairDrop(mine);
    final row = mine.row as InviteRow;
    expect((await inviteOf(db, kMainIdent, row.id))?.usedAt, isNotNull);
    expect(await signalSession.signedPreKeyStore.contains(row.spkId!), isFalse);
  });

  test('a matched pairing nobody added goes after half an hour, and only '
      'one-time invites with a bundle and a face pair at all', () async {
    final main = await myMain();
    final mine = (await app.pairInvite())!;
    final row = mine.row as InviteRow;
    final p = await _Phone.make('pair-code-left', 97);
    await app.pairHold(mine, pairPeerOf((await p.pairInvite()).link)!);
    await app.keepMyInvites();
    expect((await inviteOf(db, kMainIdent, row.id))?.usedAt, isNull);
    await db.update(
      'hellos',
      {'at': DateTime.now().millisecondsSinceEpoch - 31 * 60 * 1000},
      where: 'way = ?',
      whereArgs: ['pair'],
    );
    await app.keepMyInvites();
    expect(await hellosOf('pair', p.keyHex), isEmpty);
    final gone = await inviteOf(db, kMainIdent, row.id);
    expect(gone == null || gone.usedAt != null, isTrue);
    expect(engine.subscribed, isNot(contains(row.id)));
    // a main invite, its qr form or bytes that are no invite pair with no one
    expect(pairPeerOf((await p.mainInvite()).link), isNull);
    expect(pairPeerOf((await p.mainInvite()).qr!), isNull);
    expect(pairPeerOf(Uint8List.fromList(List.filled(40, 7))), isNull);
    expect(pairPeerOf(main.link), isNull);
  });

  test('a pairing\'s invites are held from their making: no upkeep listens on '
      'them, and the joiner\'s opener arriving before the sharer\'s Add opens '
      'nothing and spends nothing, then opens once the Add came', () async {
    await myMain();
    final mine = (await app.pairInvite())!;
    final row = mine.row as InviteRow;
    final p = await _Phone.make('pair-code-early', 99);
    // the joiner's own invite on this phone is held the same way
    final joinerSide = (await app.pairInvite())!.row as InviteRow;
    engine.subscribed.clear();
    await app.keepMyInvites();
    expect(engine.subscribed, isNot(contains(row.id)));
    expect(engine.subscribed, isNot(contains(joinerSide.id)));
    final peer = pairPeerOf((await p.pairInvite()).link)!;
    await app.pairHold(mine, peer);
    expect(engine.unsubscribed, contains(row.id));
    // their Add came first: the opener is here before mine
    final early = await p.openerTo(row, 'u-early');
    // not acked: the engine fetches it again once the add listens
    expect(await app.receiveRelay([(peer: 'f0:${row.id}', cipher: early)]), {
      0,
    });
    await _settle();
    expect(firstFails.codes, contains('held'));
    expect(live.people[p.words], isNull);
    expect((await inviteOf(db, kMainIdent, row.id))?.usedAt, isNull);
    expect(engine.seeded, isEmpty);
    // the Add: the same opener, fetched again, opens and files them
    await handleHaloUriAdded(peer.link, pairOut: row, app: app);
    await _settle();
    await app.receiveRelay([(peer: 'f0:${row.id}', cipher: early)]);
    await _settle();
    expect(live.people[p.words]?['accepted'], 1);
    expect(engine.seeded, [p.x]);
    expect((await inviteOf(db, kMainIdent, row.id))?.usedAt, isNotNull);
  });

  test('a pairing held at a late match keeps its half hour from the match, '
      'not from the invite\'s making', () async {
    await myMain();
    final mine = (await app.pairInvite())!;
    final row = mine.row as InviteRow;
    // made 25 minutes ago, matched now
    await db.update(
      'hellos',
      {'at': DateTime.now().millisecondsSinceEpoch - 25 * 60 * 1000},
      where: 'way = ? AND invite_id = ?',
      whereArgs: ['pair', row.id],
    );
    final p = await _Phone.make('pair-code-late', 101);
    await app.pairHold(mine, pairPeerOf((await p.pairInvite()).link)!);
    // an upkeep ten minutes on, past the invite's half hour but not the
    // match's: the invite stays held
    await app.keepMyInvites(
      nowMs: DateTime.now().millisecondsSinceEpoch + 10 * 60 * 1000,
    );
    expect(await hellosOf('pair', p.keyHex), hasLength(1));
    expect((await inviteOf(db, kMainIdent, row.id))?.usedAt, isNull);
    // and goes once the match's half hour is over
    await app.keepMyInvites(
      nowMs: DateTime.now().millisecondsSinceEpoch + 31 * 60 * 1000,
    );
    expect(await hellosOf('pair', p.keyHex), isEmpty);
  });

  // contacts on an older Kryfo: no classic first
  // contact, so the chat says so and its hello goes again until they answer
  group('a v3 card\'s owner', () {
    // a card as a 0.5.x phone makes it: no kyber prekey
    String classicOf(String b64) {
      final j =
          jsonDecode(utf8.decode(base64Decode(b64))) as Map<String, dynamic>
            ..remove('kyberPreKeyPublic')
            ..remove('kyberPreKeyId')
            ..remove('kyberPreKeySignature');
      return base64Encode(utf8.encode(jsonEncode(j)));
    }

    Future<(String, _Phone)> v3Of(
      String words,
      int seed, {
      required bool classic,
    }) async {
      final p = await _Phone.make(words, seed);
      final b = await p.ss.makeBundleB64();
      final link = haloUriV3(
        p.words,
        _onionOf(_onionKeyOf(seed + 1)),
        Uri.encodeQueryComponent(classic ? classicOf(b) : b),
        _hex(List.filled(32, seed)),
      );
      return (link, p);
    }

    Future<void> hellosGo({int? nowMs}) async {
      await _settle();
      await app.sendHellosOwed(nowMs: nowMs);
      await app.sendHellosOwed(nowMs: nowMs);
    }

    const hour = 3600 * 1000;

    test('a link whose card has no post-quantum prekey: the chat says at '
        'once that they may need to update, and a hello goes', () async {
      final (link, p) = await v3Of('old-card-link', 111, classic: true);
      expect(await handleHaloUriAdded(link, app: app), (
        l10n.helloSentOld,
        true,
      ));
      final w = await app.helloWaitOf(p.words);
      expect(w.waits, isTrue);
      expect(w.update, isTrue);
      expect((await hellosOf('old', p.keyHex)).single['once'], 1);
      await hellosGo();
      expect(engine.hellos, contains(p.x));
    });

    test('a link handed over with the line end it was copied with: the '
        'fc stays, and the hello goes', () async {
      final (link, p) = await v3Of('copied-line-end', 129, classic: true);
      for (final end in ['\r', '\n', '\r\n', ' ']) {
        final uri = Uri.parse('$link$end');
        // as a uri the line end is part of the fc, and the card reads as
        // one without its first-contact address
        expect(uri.queryParameters['fc'], isNot(_hex(List.filled(32, 129))));
        expect(outsideLinkText(uri), link);
      }
      // the uri's own text is what the door was handed before: refused
      expect(
        await handleHaloUriAdded(Uri.parse('$link\r').toString(), app: app),
        (l10n.appLinkNeedsUpdate(p.words), false),
      );
      expect(
        await handleHaloUriAdded(
          outsideLinkText(Uri.parse('$link\r')),
          app: app,
        ),
        (l10n.helloSentOld, true),
      );
      expect((await app.helloWaitOf(p.words)).waits, isTrue);
    });

    test('a card with the prekey: what is written waits at once, the line '
        'comes only once the hello had a while without an answer', () async {
      final (link, p) = await v3Of('new-card-link', 113, classic: false);
      expect(await handleHaloUriAdded(link, app: app), (
        l10n.helloSentOld,
        true,
      ));
      final now = DateTime.now().millisecondsSinceEpoch;
      final w = await app.helloWaitOf(p.words, nowMs: now);
      expect(w.waits, isTrue);
      expect(w.update, isFalse);
      expect(w.updateAt, greaterThan(now));
      final later = await app.helloWaitOf(
        p.words,
        nowMs: now + kOldPeerWait.inMilliseconds + 1000,
      );
      expect(later.update, isTrue);
    });

    test('a chat deleted and added again from the same link sends a fresh '
        'hello, and says again that they may need to update', () async {
      final (link, p) = await v3Of('deleted-then-again', 125, classic: true);
      await handleHaloUriAdded(link, app: app);
      await hellosGo();
      List<String> sent() => [...engine.hellos.where((x) => x == p.x)];
      expect(sent(), hasLength(1));
      await app.deleteConversation(p.words);
      expect(await hellosOf('old', p.keyHex), isEmpty);
      expect(await hellosOf('out', p.keyHex), isEmpty);
      expect(live.people[p.words], containsPair('archived', 1));
      expect(await handleHaloUriAdded(link, app: app), (
        l10n.helloSentOld,
        true,
      ));
      expect((await hellosOf('old', p.keyHex)).single['once'], 1);
      expect((await app.helloWaitOf(p.words)).update, isTrue);
      await hellosGo();
      expect(sent(), hasLength(2));
    });

    test('a v4 qr is a 0.6 phone\'s: its hello waits, and no update line '
        'ever shows', () async {
      final p = await _Phone.make('four-qr-owner', 115);
      final qr = inviteLink((await p.mainInvite()).qr!);
      expect(await handleHaloUriAdded(qr, app: app), (l10n.helloSent, true));
      final far = DateTime.now().millisecondsSinceEpoch + 40 * 24 * hour;
      final w = await app.helloWaitOf(p.words, nowMs: far);
      expect(w.waits, isTrue);
      expect(w.update, isFalse);
      expect(w.updateAt, isNull);
      expect(await hellosOf('old', p.keyHex), isEmpty);
    });

    test('a handle still on a 0.5.x card says so on the add and adds no '
        'one; one on a card with the prekey is added', () async {
      app.setTorStatusForTest(TorStatus.bootstrapped);
      app.setRouteOKForTest(true);
      final reg = <String, (String, String)>{};
      handleFetchForTest = (url) async {
        final h = Uri.parse(url).queryParameters['name']!;
        final r = reg[h];
        if (r == null) return 'error: status 404';
        return jsonEncode({
          'names': {h: r.$1},
          'invite': r.$2,
        });
      };
      addTearDown(() => handleFetchForTest = null);
      final (old, p) = await v3Of('handle-old-card', 117, classic: true);
      reg['oldcard'] = (_hex(p.face.face), old);
      expect(await handleHaloUriAdded('@oldcard', app: app), (
        l10n.handleOlderKryfo,
        false,
      ));
      expect(live.people.containsKey(p.words), isFalse);
      await hellosGo();
      expect(engine.hellos, isNot(contains(p.x)));
      expect(
        await db.query('hellos', where: 'peer = ?', whereArgs: [p.keyHex]),
        isEmpty,
      );
      final (fresh, q) = await v3Of('handle-new-card', 119, classic: false);
      reg['newcard'] = (_hex(q.face.face), fresh);
      expect(await handleHaloUriAdded('@newcard', app: app), (
        l10n.helloSentOld,
        true,
      ));
      expect(live.people[q.words], containsPair('accepted', 1));
    });

    test('no answer: the hello goes again soon at first, then twice a day '
        'the first week, then daily; only the newest one-time invite out '
        'stays beside it', () async {
      final (link, p) = await v3Of('never-answers-back', 121, classic: true);
      await handleHaloUriAdded(link, app: app);
      // a pass of an earlier test may still be under way: theirs alone
      List<String> sent() => [...engine.hellos.where((x) => x == p.x)];
      await hellosGo();
      expect(sent(), hasLength(1));
      final t0 = DateTime.now().millisecondsSinceEpoch;
      const min = 60 * 1000;
      // an update asked for now comes soon: 10 min, 1 h, 3 h, 6 h
      for (final (at, n) in [
        (5 * min, 1),
        (11 * min, 2),
        (30 * min, 2),
        (61 * min, 3),
        (2 * hour, 3),
        (3 * hour + min, 4),
        (6 * hour + 2 * min, 5),
        // twice a day after, from the last one
        (12 * hour, 5),
        (18 * hour + 3 * min, 6),
        (30 * hour + 4 * min, 7),
      ]) {
        await hellosGo(nowMs: t0 + at);
        expect(sent(), hasLength(n), reason: 'at ${at ~/ min} min');
      }
      expect(await hellosOf('out', p.keyHex), hasLength(2));
      expect(engine.unsubscribed, hasLength(5));
      await hellosGo(nowMs: t0 + 8 * 24 * hour);
      expect(sent(), hasLength(8));
      await hellosGo(nowMs: t0 + 8 * 24 * hour + 13 * hour);
      expect(sent(), hasLength(8));
      await hellosGo(nowMs: t0 + 9 * 24 * hour + hour);
      expect(sent(), hasLength(9));
      expect(await hellosOf('out', p.keyHex), hasLength(2));
      // the line stays the whole time
      expect(
        (await app.helloWaitOf(p.words, nowMs: t0 + 9 * 24 * hour)).update,
        isTrue,
      );
      // thirteen hellos, each with its real proof of work: about 1.5 s a
      // grind on average but some take 10 s or more, past the default 30 s
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a phone asleep past the first steps sends one hello, not the '
        'ones it missed', () async {
      final (link, p) = await v3Of('asleep-past-steps', 127, classic: true);
      await handleHaloUriAdded(link, app: app);
      List<String> sent() => [...engine.hellos.where((x) => x == p.x)];
      await hellosGo();
      expect(sent(), hasLength(1));
      final t0 = DateTime.now().millisecondsSinceEpoch;
      await hellosGo(nowMs: t0 + 7 * hour);
      expect(sent(), hasLength(2));
      await hellosGo(nowMs: t0 + 7 * hour + 10 * 60 * 1000);
      expect(sent(), hasLength(2));
      await hellosGo(nowMs: t0 + 19 * hour + 60 * 1000);
      expect(sent(), hasLength(3));
    });

    test('the steps: front-loaded, then twice a day, then daily', () {
      const m = 60 * 1000;
      expect(oldPeerHelloDue(0, 0), 10 * m);
      expect(oldPeerHelloDue(0, 10 * m), hour);
      expect(oldPeerHelloDue(0, hour), 3 * hour);
      expect(oldPeerHelloDue(0, 3 * hour), 6 * hour);
      expect(oldPeerHelloDue(0, 6 * hour), 18 * hour);
      expect(oldPeerHelloDue(0, 7 * hour), 19 * hour);
      expect(oldPeerHelloDue(0, 8 * 24 * hour), 9 * 24 * hour);
    });

    test('once they update and answer the hello, their chat starts and '
        'nothing waits any more', () async {
      await myMain();
      final (link, p) = await v3Of('updates-them-later', 123, classic: true);
      await handleHaloUriAdded(link, app: app);
      await hellosGo();
      expect((await app.helloWaitOf(p.words)).update, isTrue);
      final out = (await hellosOf('out', p.keyHex)).single;
      final once = (await inviteOf(
        db,
        kMainIdent,
        out['invite_id'] as String,
      ))!;
      final opener = await p.openerTo(once, 'u-updated');
      await app.receiveRelay([(peer: 'f0:${once.id}', cipher: opener)]);
      await _settle();
      expect(await hasSessionWith(p.words), isTrue);
      expect(await hellosOf('old', p.keyHex), isEmpty);
      expect(await app.helloWaitOf(p.words), kNoHelloWait);
      // no hello goes to them again
      await hellosGo(nowMs: DateTime.now().millisecondsSinceEpoch + 30 * hour);
      expect(engine.hellos.where((x) => x == p.x), hasLength(1));
    });

    // what 0.5.3's own code made (fixtures/invites_053, make_invites_053.sh):
    // the qr and link it shows, the link when its counter did not read, and
    // the text its share sheet carries
    Map<String, dynamic> made053() =>
        jsonDecode(
              File(
                'test/fixtures/invites_053/from_053.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    String xOf(String card) => _hex(
      base64Decode(
        (jsonDecode(utf8.decode(base64Decode(card))) as Map)['identityKey']
            as String,
      ).sublist(1),
    );

    test(
      'a 0.5.3 qr scanned here: a hello to its first-contact address and '
      'the line that they may need to update, never an invalid link',
      () async {
        final m = made053();
        final id = m['id'] as String;
        final keyHex = '05${xOf(m['card'] as String)}';
        expect(await handleHaloUriAdded(m['qr'] as String, app: app), (
          l10n.helloSentOld,
          true,
        ));
        final w = await app.helloWaitOf(id);
        expect(w.waits, isTrue);
        expect(w.update, isTrue);
        expect(await hellosOf('old', keyHex), hasLength(1));
        await hellosGo();
        expect(engine.hellos, contains(xOf(m['card'] as String)));
        // and no session is built on the classic card
        expect(await hasSessionWith(id), isFalse);
      },
    );

    test('a 0.5.3 share text pasted here reads as its link; its link '
        'without a first-contact address says they need to update', () async {
      final m = made053();
      final id = m['id'] as String;
      expect(await handleHaloUriAdded(m['link_v2'] as String, app: app), (
        l10n.appLinkNeedsUpdate(id),
        false,
      ));
      expect(live.people.containsKey(id), isFalse);
      expect(engine.hellos, isEmpty);
      expect(await handleHaloUriAdded(m['share_text'] as String, app: app), (
        l10n.helloSentOld,
        true,
      ));
      expect((await app.helloWaitOf(id)).update, isTrue);
      expect(await hasSessionWith(id), isFalse);
    });
  });
}
