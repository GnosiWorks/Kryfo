// SPDX-License-Identifier: GPL-3.0-or-later
// group member pairs through the hello: a roster invite of
// my own, kept and made again; mine to the admin as I join, and the
// members' ones kept from the admin's roster; a hello from the smaller key
// to the other's roster invite, taken there without a request or the work,
// and its opener answered once; the admin passing them on. members on
// 0.5.x, hidden groups, the decoy, blocks and a member who never answers
// keep groups going as before. real signal and real invite rows, the
// engine stood in
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/first_contact.dart' show firstFails;
import 'package:kryfo/group_shots.dart' show GroupShotsWord;
import 'package:kryfo/identities.dart';
import 'package:kryfo/invites.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        AppStateDoor,
        AppStateGroupHellos,
        AppStateGroupLanes,
        AppStateInvites,
        AppStateOldPeers,
        AppStateOutbox,
        AppStateProfile,
        AppStateReceive,
        HaloDb,
        HaloEngine,
        keyBelow,
        kOldPeerWait,
        processPeerBundle,
        rosterPassWait,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart'
    show kSealSizes, padSeal, unpad, utf8Length;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'old_wire/envelope_051.dart' as v051;
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

bool _lifts(List<int> x) {
  final v = BigInt.parse(_hex(x), radix: 16);
  if (v >= _p) return false;
  final a = (v.modPow(BigInt.from(3), _p) + BigInt.from(7)) % _p;
  final y = a.modPow((_p + BigInt.one) >> 2, _p);
  return y.modPow(BigInt.two, _p) == a;
}

String _fcPkOf(Uint8List sk) {
  final x = sha256.convert(sk).bytes;
  return _lifts(x) ? _hex(x) : 'error: not a key';
}

const _b32 = 'abcdefghijklmnopqrstuvwxyz234567';

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

final _idOf = <String, String>{};

const _me = 'my-own-words';
final _myFace = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 11)));
List<int> _onionKeyOf(int seed) => ed
    .public(ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, seed))))
    .bytes;
final _onionKey = _onionKeyOf(12);

class _Engine implements HaloEngine {
  _Engine(this.x);
  final String x;
  final unsubscribed = <String>[];
  final listened = <String>[];
  // the hellos sent: whose, and the wire line
  final hellos = <(String, String)>[];
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
    listened.add(inviteId);
    return 'ok';
  }

  @override
  Future<String> unsubscribeFcKey(int ident, String inviteId) async {
    unsubscribed.add(inviteId);
    return 'ok';
  }

  @override
  Future<String> pairSeed(int ident, String x, String seed) async => 'ok';
  @override
  Future<String> sendHello(int ident, String owner, String fc, String m) async {
    hellos.add((owner, m));
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
  _Io();
  // where each frame went: 'fc <x>', 'onion <onion>' or 'relay <x>'
  final sent = <(String, String)>[];
  @override
  void listen(int ident, String xPub, {bool fresh = false}) {}

  @override
  void listenHidden(int ident, String xPub, {bool fresh = false}) =>
      listen(ident, xPub, fresh: fresh);
  @override
  void unlisten(int ident, String xPub) {}
  @override
  Future<String> relaySend(int ident, String xPub, String cipher) async {
    sent.add(('relay $xPub', cipher));
    return 'ok';
  }

  @override
  Future<String> onionSend(
    String onion,
    String cipher, {
    bool rest = false,
  }) async {
    sent.add(('onion $onion', cipher));
    return 'ok';
  }

  @override
  Future<String> firstContactSend(
    int ident,
    String x,
    String fc,
    String c,
  ) async {
    sent.add(('fc $x', c));
    return 'ok';
  }

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
    bool silent = false,
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

// the rows in maps, each contact copied (its key claimed) into a file of
// rows beside the invite tables, as the real container keeps them
class _Rows extends ArrivalRows {
  _Rows(this.db, [HaloContainer c = HaloContainer.everyday]) : super(c);
  final MemDb db;
  @override
  Future<Database> open() async => db;

  Future<void> _mirror(String haloId) async {
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
    await _mirror(haloId);
  }

  @override
  Future<void> upsertContactStub(
    String haloId,
    String onion,
    String xpub,
  ) async {
    await super.upsertContactStub(haloId, onion, xpub);
    if (people.containsKey(haloId)) await _mirror(haloId);
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
}

class _Phone {
  _Phone._(this.db, this.ss, this.face, this.words, this.edKey, this.onion);
  final MemDb db;
  final SignalSession ss;
  final InviteFace face;
  final String words;
  final ed.PrivateKey edKey;
  final String onion;

  static Future<_Phone> make(String words, int seed) async {
    final db = MemDb();
    final ss = await testStore(db: db);
    final keys = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, seed)));
    final pub = Uint8List.fromList(ed.public(keys).bytes);
    _idOf[_hex(pub)] = words;
    final onionKey = Uint8List.fromList(_onionKeyOf(seed + 1));
    return _Phone._(
      db,
      ss,
      InviteFace(
        onionKey: onionKey,
        face: pub,
        sign: (m) => Uint8List.fromList(ed.sign(keys, m)),
      ),
      words,
      keys,
      _onionOf(onionKey),
    );
  }

  List<int> get key => ss.identity.public;
  String get x => _hex(key.sublist(1));
  String get keyHex => _hex(key);

  Future<InviteRow> roster({int? nowMs}) =>
      makeInvite(db, ss, kind: kInviteRoster, fcPkOf: _fcPkOf, nowMs: nowMs);

  Map<String, String> part({InviteRow? ri}) => {
    'h': words,
    'o': onion,
    'x': x,
    if (ri != null) 'ri': base64Encode(ri.link),
  };

  SenderInfo get sender =>
      SenderInfo(haloId: words, edPub: _hex(face.face), onion: onion, xPub: x);

  // their hello to my invite [answers], with no work done for it
  Future<({String line, InviteRow once})> helloTo(
    String answers, {
    bool work = false,
  }) async {
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
      work ? grindPow(helloPowSeed(hello), powBits) : 0,
    );
    return (line: '${_sealOf(x)}|$wire', once: once);
  }
}

// the real group rows' code on the same file of rows: a removal as a
// phone runs it
class _Halo extends HaloDb {
  _Halo(this.db);
  final MemDb db;
  @override
  Future<Database> open() async => db;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 40));

const _g = 'grp000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb db;
  late _Rows live;
  late _Engine engine;
  late _Io io;
  late AppState app;
  var seed = 100;

  Future<void> world({ArrivalStore? hidden}) async {
    final store = hidden ?? ArrivalStore();
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    io = _Io();
    app = AppState(io: io, router: router)
      ..myId = _me
      ..myOnion = _onionOf(_onionKey);
    useDatabasesForTest(live, Session(live));
  }

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('group_hello');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    db = MemDb();
    final me = testKeyPair();
    engine = _Engine(_hex(me.publicKey.serialize().sublist(1)));
    useEngineForTest(engine);
    _idOf[_hex(ed.public(_myFace).bytes)] = _me;
    await signalSession.bootstrap(
      database: db,
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

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
      'roster_invites',
    ]) {
      await db.delete(t);
    }
    engine.unsubscribed.clear();
    engine.listened.clear();
    engine.hellos.clear();
    live = _Rows(db);
    await world();
    rosterPassWait = const Duration(seconds: 20);
  });

  // a phone whose key is above mine (it waits for my hello) or below it
  // (it says hello to me)
  Future<_Phone> phone(String words, {required bool above}) async {
    while (true) {
      final p = await _Phone.make(words, seed++);
      if (keyBelow(signalSession.identity.public, p.key) == above) return p;
    }
  }

  Future<InviteRow> myRoster({int? nowMs}) async {
    await app.keepMyInvites(nowMs: nowMs);
    return (await currentRosterInvite(db, kMainIdent))!;
  }

  Future<UnwrappedMessage> env(_Phone from, GroupControl gc) async =>
      unwrapMessage(
        await wrapMessage(
          '',
          groupId: _g,
          groupControl: gc,
          sender: from.sender,
        ),
      );

  Future<List<Map<String, Object?>>> hellosOf(String way, String peer) =>
      db.query('hellos', where: 'way = ? AND peer = ?', whereArgs: [way, peer]);

  // a group made by [admin] with [others], as its create comes to me
  Future<void> joinFrom(
    _Phone admin,
    List<(_Phone, InviteRow?)> others, {
    GroupShotsWord? shots,
  }) async {
    live.person(admin.words, xpub: admin.x, onion: admin.onion);
    await live.upsertContact(admin.words, admin.onion, admin.x);
    await app.groupControlForTest(
      admin.words,
      await env(
        admin,
        GroupControl(
          type: 'create',
          name: 'g',
          members: [_me, admin.words, for (final (p, _) in others) p.words],
          participants: [
            admin.part(),
            for (final (p, ri) in others) p.part(ri: ri),
          ],
          shots: shots,
        ),
      ),
      live,
    );
    await _settle();
  }

  test('my roster invite: no bundle, not one-time, its own id and address, '
      'made again at six months and gone a day past its year', () async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    final r = await myRoster(nowMs: t0);
    final main = (await currentMainInvite(db, kMainIdent))!;
    final inv = readInvite(signalSession.lib, r.link);
    expect(r.link, hasLength(160));
    expect(inv.oneTime, isFalse);
    expect(inv.block, isNull);
    expect(inv.face, isNull);
    expect(inv.onion, isNull);
    expect(r.spkId, isNull);
    expect(r.kyberId, isNull);
    expect(r.id, isNot(main.id));
    expect(
      _hex(inv.firstContact),
      isNot(_hex(readInvite(signalSession.lib, main.link).firstContact)),
    );
    expect(inv.identity, signalSession.identity.public);
    expect(engine.listened, contains(r.id));
    const h = 3600 * 1000;
    await app.keepMyInvites(nowMs: t0 + (kMainReissueHours + 1) * h);
    final again = (await currentRosterInvite(db, kMainIdent))!;
    expect(again.id, isNot(r.id));
    final old = (await inviteOf(db, kMainIdent, r.id))!;
    expect(old.retiredAt, isNotNull);
    expect(old.openAt(unixHours(t0) + kMainReissueHours + 1), isTrue);
    await app.keepMyInvites(nowMs: t0 + (kMainHours + kSkewHours + 2) * h);
    expect(await inviteOf(db, kMainIdent, r.id), isNull);
    expect(engine.unsubscribed, contains(r.id));
  });

  test('a member taking a create keeps the members\' roster invites, tells '
      'the admin its own in their own session, and says hello only to a '
      'key above its own, without the work', () async {
    final mine = await myRoster();
    final admin = await _Phone.make('admin-of-it', seed++);
    final up = await phone('above-me-one', above: true);
    final down = await phone('below-me-one', above: false);
    final upRi = await up.roster();
    final downRi = await down.roster();
    await joinFrom(admin, [(up, upRi), (down, downRi)]);
    final held = await rosterInvitesIn(db, _g);
    expect(held.keys, unorderedEquals([up.words, down.words]));
    // mine to the admin, and to no one else
    final told = [
      for (final r in live.ctlOut)
        if (GroupControl.fromWire(jsonDecode(r['ctl'] as String))!.type == 'ri')
          r,
    ];
    expect([for (final r in told) r['member']], [admin.words]);
    final gc = GroupControl.fromWire(jsonDecode(told.single['ctl'] as String))!;
    expect(base64Decode(gc.invite!), mine.link);
    // the hello goes up, at once and without the work, none down
    await app.sendHellosOwed();
    await _settle();
    expect([for (final (x, _) in engine.hellos) x], [up.x]);
    final hw = helloOfWire(engine.hellos.single.$2)!;
    expect(hw.nonce, 0);
    final hl = signalSession.lib.parseHello(hw.hello);
    expect(_hex(hl.answers), upRi.id);
    expect(hl.owner, up.key);
    final out = await hellosOf('out', up.keyHex);
    expect(out.single['invite_id'], _hex(hl.invite.id));
    expect(
      await db.query('hellos', where: 'peer = ?', whereArgs: [down.keyHex]),
      isEmpty,
    );
  });

  test('a create of fifty members with their roster invites fits the '
      'largest seal', () async {
    final ri = base64Encode(
      (await (await _Phone.make('size-of-it', seed++)).roster()).link,
    );
    final parts = [
      for (var i = 0; i < 50; i++)
        {
          'h': 'member-number-long-$i',
          'o': _onionOf(_onionKeyOf(i)),
          'x': 'ab' * 32,
          'ri': ri,
        },
    ];
    final w = await wrapMessage(
      '',
      groupId: _g,
      groupControl: GroupControl(
        type: 'create',
        name: 'Family',
        members: [for (final p in parts) p['h']!],
        participants: parts,
        stamp: DateTime.now().millisecondsSinceEpoch,
        shots: GroupShotsWord(on: true, all: false, at: 1),
      ),
      sender: SenderInfo(
        haloId: _me,
        edPub: engine.myEdPubkey(),
        onion: _onionOf(_onionKey),
        xPub: engine.x,
      ),
      writtenAt: DateTime.now().millisecondsSinceEpoch,
    );
    expect(utf8Length(padSeal(w)), kSealSizes.last);
  });

  test('a 0.5.x phone reads a roster with roster invites as before, and '
      'takes the new controls for ones its version does not know', () async {
    final p = await _Phone.make('older-reader-one', seed++);
    final ri = await p.roster();
    String gcOf(GroupControl gc) => jsonEncode(gc.toWire());
    final create = await wrapMessage(
      '',
      groupId: _g,
      groupControl: GroupControl(
        type: 'create',
        name: 'g',
        members: [_me, p.words],
        participants: [p.part(ri: ri)],
      ),
      sender: p.sender,
    );
    final old = v051.unwrapMessage(create).groupControl!;
    expect(old.type, 'create');
    expect(old.participants!.single['h'], p.words);
    expect(old.participants!.single['o'], p.onion);
    expect(old.participants!.single['x'], p.x);
    for (final t in ['ri', 'roster', 'pair']) {
      final w = await wrapMessage(
        '',
        groupId: _g,
        groupControl: GroupControl(
          type: t,
          invite: t == 'ri' ? base64Encode(ri.link) : null,
          participants: t == 'roster' ? [p.part(ri: ri)] : null,
        ),
        sender: p.sender,
      );
      final o = v051.unwrapMessage(w);
      // a type its switch has no case for: nothing happens there
      expect(o.groupControl?.type, t, reason: gcOf(GroupControl(type: t)));
      expect(o.message, '');
    }
  });

  test('a roster invite that is not the member\'s own is not kept', () async {
    await myRoster();
    final admin = await _Phone.make('admin-of-two', seed++);
    final up = await phone('above-me-two', above: true);
    final other = await _Phone.make('someone-else-two', seed++);
    // the other one's invite under their words, and an expired one
    final wrong = await other.roster();
    await joinFrom(admin, [(up, wrong)]);
    expect(await rosterInvitesIn(db, _g), isEmpty);
    expect(await hellosOf('want', up.keyHex), isEmpty);
  });

  test('members on 0.5.x keep the old way: no roster invite, no hello, and '
      'an introduced one is still asked for their card', () async {
    await myRoster();
    var asked = 0;
    app.myBundleForTest = () async {
      asked++;
      return base64Encode(utf8.encode('{}'));
    };
    final admin = await _Phone.make('admin-of-old', seed++);
    final old = await phone('older-phone-one', above: true);
    final up = await phone('newer-phone-one', above: true);
    await joinFrom(admin, [(old, null), (up, await up.roster())]);
    expect((await rosterInvitesIn(db, _g)).keys, [up.words]);
    expect(await hellosOf('want', old.keyHex), isEmpty);
    live.vouches[old.words] = {admin.words};
    live.vouches[up.words] = {admin.words};
    final frame = await wrapMessage(
      'hi',
      groupId: _g,
      sender: SenderInfo(
        haloId: _me,
        edPub: engine.myEdPubkey(),
        onion: app.myOnion,
        xPub: engine.x,
      ),
    );
    expect(await app.sendEnvelopeForTest(up.words, frame), isFalse);
    await _settle();
    expect(asked, 0);
    expect(await app.sendEnvelopeForTest(old.words, frame), isFalse);
    await _settle();
    expect(asked, 1);
  });

  test('a member\'s hello at my roster invite is answered without a request '
      'or the work, on a seeded pair, and its first frame goes to their '
      'one-time address alone', () async {
    final mine = await myRoster();
    final admin = await _Phone.make('admin-of-three', seed++);
    final down = await phone('below-me-three', above: false);
    await joinFrom(admin, [(down, await down.roster())]);
    final h = await down.helloTo(mine.id);
    await app.receiveRelay([(peer: 'f0:${mine.id}', cipher: h.line)]);
    await _settle();
    expect(live.people[down.words]?['accepted'], 0);
    expect(await hellosOf('in', down.keyHex), isEmpty);
    expect(await signalSession.sessionStore.load(down.words), isNotNull);
    final pair = await pairOf(db, kMainIdent, down.keyHex);
    expect(pair.conv, kConvSeeded);
    expect(
      app.peerFcFor(down.words),
      _hex(readInvite(signalSession.lib, h.once.link).firstContact),
    );
    await app.ctlPassForTest;
    await _settle();
    final to = [for (final (w, _) in io.sent) w];
    expect(to, contains('fc ${down.x}'));
    expect(to.where((w) => w.startsWith('onion')), isEmpty);
    // and it opens on their side, on the seed and their invite
    final c = io.sent.firstWhere((s) => s.$1 == 'fc ${down.x}').$2;
    final w = base64Decode(c);
    final plain = await down.ss.open(_me, w[0], Uint8List.sublistView(w, 1));
    final got = unwrapMessage(unpad(utf8.decode(plain)));
    expect(got.groupControl?.type, 'pair');
    expect(got.protoGen, 4);
    expect(got.addrSeed, _hex(pair.seed!));
  });

  test(
    'a hello at my roster invite from someone in no group of mine, or '
    'one blocked, is dropped; at my main invite the work is still asked',
    () async {
      final mine = await myRoster();
      final stranger = await _Phone.make('not-in-groups', seed++);
      final h = await stranger.helloTo(mine.id);
      await app.receiveRelay([(peer: 'f0:${mine.id}', cipher: h.line)]);
      await _settle();
      expect(firstFails.codes, contains('roster'));
      expect(live.people[stranger.words], isNull);
      expect(await signalSession.sessionStore.load(stranger.words), isNull);
      final admin = await _Phone.make('admin-of-four', seed++);
      final blocked = await phone('blocked-member-four', above: false);
      await joinFrom(admin, [(blocked, await blocked.roster())]);
      live.people[blocked.words]!['blocked'] = 1;
      await live.upsertContactStub(blocked.words, '', blocked.x);
      await db.update(
        'contacts',
        {'blocked': 1},
        where: 'halo_id = ?',
        whereArgs: [blocked.words],
      );
      final hb = await blocked.helloTo(mine.id);
      await app.receiveRelay([(peer: 'f0:${mine.id}', cipher: hb.line)]);
      await _settle();
      expect(await signalSession.sessionStore.load(blocked.words), isNull);
      final main = (await currentMainInvite(db, kMainIdent))!;
      firstFails.clear();
      final lazy = await _Phone.make('no-work-done', seed++);
      final hl = await lazy.helloTo(main.id);
      await app.receiveRelay([(peer: 'f0:${main.id}', cipher: hl.line)]);
      await _settle();
      expect(firstFails.codes, contains('pow'));
      expect(live.people[lazy.words], isNull);
    },
  );

  test(
    'my hello\'s answer: the member\'s opener at my one-time invite opens '
    'on the seed it carries, is answered once, and they stay a member',
    () async {
      await myRoster();
      final admin = await _Phone.make('admin-of-five', seed++);
      final up = await phone('above-me-five', above: true);
      await joinFrom(admin, [(up, await up.roster())]);
      await app.sendHellosOwed();
      await _settle();
      final hw = helloOfWire(engine.hellos.single.$2)!;
      final hl = up.ss.lib.parseHello(hw.hello);
      final once = _hex(hl.invite.id);
      await up.ss.processBundle(_me, hl.invite.block!.bundle);
      final as = List<int>.generate(32, (i) => i + 7);
      final frame = await wrapMessage(
        '',
        groupId: _g,
        groupControl: const GroupControl(type: 'pair'),
        sender: up.sender,
      );
      final j =
          jsonDecode(frame.substring(kEnvelopePrefix.length))
              as Map<String, dynamic>;
      j['pg'] = 4;
      j['as'] = _hex(as);
      j['fs'] = _hex(ed.sign(up.edKey, faceText(up.key, hl.invite.id)));
      final c = await up.ss.encryptTo(_me, '$kEnvelopePrefix${jsonEncode(j)}');
      await app.receiveRelay([
        (peer: 'f0:$once', cipher: '${_sealOf(up.x)}|$c'),
      ]);
      await _settle();
      expect(await signalSession.sessionStore.load(up.words), isNotNull);
      final pair = await pairOf(db, kMainIdent, up.keyHex);
      expect(pair.conv, kConvSeeded);
      expect(pair.seed, as);
      await app.ctlPassForTest;
      await _settle();
      // answered once, on the pair's own address: they are back-paired
      List<String> toUp() => [
        for (final (w, _) in io.sent)
          if (w.endsWith(up.x)) w,
      ];
      expect(toUp(), ['relay ${up.x}']);
      expect(live.people[up.words]?['accepted'], 0);
      expect(await hellosOf('out', up.keyHex), isEmpty);
      // a pair frame that is no opener is not answered again
      await app.groupControlForTest(
        up.words,
        await env(up, const GroupControl(type: 'pair')),
        live,
      );
      await app.ctlPassForTest;
      await _settle();
      expect(toUp(), hasLength(1));
    },
  );

  test(
    'the admin keeps a member\'s roster invite only when it is theirs, '
    'and passes them on, mine with them, to the members who sent one',
    () async {
      final mine = await myRoster();
      final m1 = await _Phone.make('first-member-six', seed++);
      final m2 = await _Phone.make('second-member-six', seed++);
      final old = await _Phone.make('older-member-six', seed++);
      for (final p in [m1, m2, old]) {
        live.person(p.words, xpub: p.x, onion: p.onion);
        await live.upsertContact(p.words, p.onion, p.x);
      }
      live.group(_g, [_me, m1.words, m2.words, old.words], admin: _me);
      rosterPassWait = Duration.zero;
      final r1 = await m1.roster();
      final r2 = await m2.roster();
      // m1 handing on m2's: not theirs
      await app.groupControlForTest(
        m1.words,
        await env(m1, GroupControl(type: 'ri', invite: base64Encode(r2.link))),
        live,
      );
      expect(await rosterInvitesIn(db, _g), isEmpty);
      for (final (p, r) in [(m1, r1), (m2, r2)]) {
        await app.groupControlForTest(
          p.words,
          await env(p, GroupControl(type: 'ri', invite: base64Encode(r.link))),
          live,
        );
      }
      await _settle();
      expect(live.ctlTo(m1.words), ['roster']);
      expect(live.ctlTo(m2.words), ['roster']);
      expect(live.ctlTo(old.words), isEmpty);
      final row = live.ctlOut.firstWhere((r) => r['member'] == m1.words);
      final gc = GroupControl.fromWire(jsonDecode(row['ctl'] as String))!;
      final ri = {for (final p in gc.participants!) p['h']: p['ri']};
      expect(ri[_me], base64Encode(mine.link));
      expect(ri[m1.words], base64Encode(r1.link));
      expect(ri[m2.words], base64Encode(r2.link));
      expect(ri.containsKey(old.words), isFalse);
      expect(await rosterInvitesToPass(db), isEmpty);
      // the same one again passes nothing on
      live.ctlOut.clear();
      await app.groupControlForTest(
        m1.words,
        await env(m1, GroupControl(type: 'ri', invite: base64Encode(r1.link))),
        live,
      );
      await _settle();
      expect(live.ctlOut, isEmpty);
      // a new member's create carries the roster invites held
      final row2 = await rosterInvitesIn(db, _g);
      expect(row2.keys, unorderedEquals([m1.words, m2.words]));
    },
  );

  test('a member\'s roster invite is taken by its admin only, and a roster '
      'from anyone else changes nothing', () async {
    await myRoster();
    final admin = await _Phone.make('admin-of-seven', seed++);
    final m = await _Phone.make('member-of-seven', seed++);
    final up = await phone('above-me-seven', above: true);
    await joinFrom(admin, [(m, null), (up, null)]);
    await app.groupControlForTest(
      m.words,
      await env(
        m,
        GroupControl(type: 'ri', invite: base64Encode((await m.roster()).link)),
      ),
      live,
    );
    await app.groupControlForTest(
      m.words,
      await env(
        m,
        GroupControl(
          type: 'roster',
          participants: [up.part(ri: await up.roster())],
        ),
      ),
      live,
    );
    expect(await rosterInvitesIn(db, _g), isEmpty);
    await app.groupControlForTest(
      admin.words,
      await env(
        admin,
        GroupControl(
          type: 'roster',
          participants: [up.part(ri: await up.roster())],
        ),
      ),
      live,
    );
    expect((await rosterInvitesIn(db, _g)).keys, [up.words]);
  });

  for (final (c, n) in [
    (HaloContainer.vault, 'vault'),
    (HaloContainer.decoy, 'decoy'),
  ]) {
    test('a group in the $n keeps the old way: no roster invite told '
        'or kept, no hello', () async {
      await myRoster();
      final vdb = MemDb();
      final other = _Rows(vdb, c);
      final admin = await _Phone.make('admin-hidden-$n', seed++);
      final up = await phone('above-hidden-$n', above: true);
      other.person(admin.words, xpub: admin.x);
      await app.groupControlForTest(
        admin.words,
        await env(
          admin,
          GroupControl(
            type: 'create',
            name: 'h',
            members: [_me, admin.words, up.words],
            participants: [
              admin.part(),
              up.part(ri: await up.roster()),
            ],
          ),
        ),
        other,
      );
      await _settle();
      expect(other.members[_g], isNotNull);
      expect(other.ctlTo(admin.words), isNot(contains('ri')));
      expect(await rosterInvitesIn(vdb, _g), isEmpty);
      expect(await db.query('hellos'), isEmpty);
    });
  }

  test('while a decoy holds the everyday side, a join sends no hello and '
      'its roster invite waits in the lane', () async {
    await myRoster();
    app.quietMarkedForTest = true;
    addTearDown(() => app.quietMarkedForTest = false);
    final admin = await _Phone.make('admin-decoy-nine', seed++);
    final up = await phone('above-decoy-nine', above: true);
    await joinFrom(admin, [(up, await up.roster())]);
    await app.sendHellosOwed();
    await _settle();
    expect(engine.hellos, isEmpty);
    expect(io.sent, isEmpty);
    expect(live.ctlTo(admin.words), contains('ri'));
  });

  test('a blocked member is owed no hello', () async {
    await myRoster();
    final admin = await _Phone.make('admin-blocks-ten', seed++);
    final up = await phone('above-blocked-ten', above: true);
    live.person(up.words, xpub: up.x, onion: up.onion, accepted: 0);
    live.people[up.words]!['blocked'] = 1;
    await joinFrom(admin, [(up, await up.roster())]);
    expect(await hellosOf('want', up.keyHex), isEmpty);
  });

  test('a member who never answers: no second hello while one waits, a '
      'fresh one once its invite went, and a send to them fails at once '
      'without a bundle swap', () async {
    await myRoster();
    var asked = 0;
    app.myBundleForTest = () async {
      asked++;
      return '';
    };
    final admin = await _Phone.make('admin-of-eleven', seed++);
    final up = await phone('above-silent-eleven', above: true);
    await joinFrom(admin, [(up, await up.roster())]);
    await app.sendHellosOwed();
    await _settle();
    expect(engine.hellos, hasLength(1));
    await app.rosterHellosForTest();
    await app.sendHellosOwed();
    await _settle();
    expect(engine.hellos, hasLength(1));
    final frame = await wrapMessage(
      'hi',
      groupId: _g,
      sender: SenderInfo(
        haloId: _me,
        edPub: engine.myEdPubkey(),
        onion: app.myOnion,
        xPub: engine.x,
      ),
    );
    expect(await app.sendEnvelopeForTest(up.words, frame), isFalse);
    expect(asked, 0);
    // its one-time invite past its life and a day: owed again
    const h = 3600 * 1000;
    await app.keepMyInvites(
      nowMs:
          DateTime.now().millisecondsSinceEpoch +
          (kOneTimeHours + kSkewHours + 2) * h,
    );
    await _settle();
    final first = helloOfWire(engine.hellos.first.$2)!.hello;
    final firstOnce = _hex(signalSession.lib.parseHello(first).invite.id);
    final out = await hellosOf('out', up.keyHex);
    expect(out.single['invite_id'], isNot(firstOnce));
    expect(engine.hellos, hasLength(2));
  });

  test('a group with screenshot blocking on: the join still tells the admin '
      'what this app can, and its roster invite', () async {
    await myRoster();
    final admin = await _Phone.make('admin-shots-twelve', seed++);
    final up = await phone('above-shots-twelve', above: true);
    await joinFrom(
      admin,
      [(up, await up.roster())],
      shots: GroupShotsWord(
        on: true,
        all: false,
        at: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    expect(live.ctlTo(admin.words), containsAll(['caps', 'ri']));
    await _settle();
    expect([for (final (x, _) in engine.hellos) x], [up.x]);
  });

  test(
    'no roster invite goes to an admin I know on another identity',
    () async {
      await myRoster();
      final admin = await _Phone.make('admin-other-ident', seed++);
      live.person(admin.words, xpub: admin.x);
      await live.upsertContact(admin.words, admin.onion, admin.x);
      await db.update(
        'contacts',
        {'ident': 3},
        where: 'halo_id = ?',
        whereArgs: [admin.words],
      );
      await app.loadIdentsForTest();
      expect(app.identOf(admin.words), 3);
      await app.groupControlForTest(
        admin.words,
        await env(
          admin,
          GroupControl(
            type: 'create',
            name: 'g',
            members: [_me, admin.words],
            participants: [admin.part()],
          ),
        ),
        live,
      );
      await _settle();
      expect(live.ctlTo(admin.words), isNot(contains('ri')));
    },
  );
  test('the admin keeps a member\'s roster invite again only when it is '
      'newer and a day on, and passes every one to a new member or one '
      'whose own was made again, the others only what is new', () async {
    final mine = await myRoster();
    final m1 = await _Phone.make('first-member-delta', seed++);
    final m2 = await _Phone.make('second-member-delta', seed++);
    for (final p in [m1, m2]) {
      live.person(p.words, xpub: p.x, onion: p.onion);
      await live.upsertContact(p.words, p.onion, p.x);
    }
    live.group(_g, [_me, m1.words, m2.words], admin: _me);
    rosterPassWait = Duration.zero;
    final now = DateTime.now().millisecondsSinceEpoch;
    const h = 3600 * 1000;
    Future<void> ri(_Phone p, InviteRow r) async {
      await app.groupControlForTest(
        p.words,
        await env(p, GroupControl(type: 'ri', invite: base64Encode(r.link))),
        live,
      );
      await _settle();
    }

    Map<String?, String?> rosterTo(String member) {
      final row = live.ctlOut.lastWhere((r) => r['member'] == member);
      final gc = GroupControl.fromWire(jsonDecode(row['ctl'] as String))!;
      expect(gc.type, 'roster');
      return {for (final p in gc.participants!) p['h']: p['ri']};
    }

    final r1 = await m1.roster(nowMs: now - 5 * h);
    await ri(m1, r1);
    expect(rosterTo(m1.words).keys, unorderedEquals([_me, m1.words]));
    // another of the same hour: not kept, nothing passed
    live.ctlOut.clear();
    final same = await m1.roster(nowMs: now - 5 * h);
    expect(same.issued, r1.issued);
    await ri(m1, same);
    expect((await rosterInviteOf(db, _g, m1.words))!.id, r1.id);
    expect(live.ctlOut, isEmpty);
    // a newer one within the day: not kept either
    final newer = await m1.roster(nowMs: now);
    await ri(m1, newer);
    expect((await rosterInviteOf(db, _g, m1.words))!.id, r1.id);
    expect(live.ctlOut, isEmpty);
    // a new member: every one to them, theirs alone to the one before
    final r2 = await m2.roster();
    await ri(m2, r2);
    expect(rosterTo(m2.words), {
      _me: base64Encode(mine.link),
      m1.words: base64Encode(r1.link),
      m2.words: base64Encode(r2.link),
    });
    expect(rosterTo(m1.words), {m2.words: base64Encode(r2.link)});
    // a day on, the newer one is kept and goes to the others alone
    await db.update(
      'roster_invites',
      {'kept': now - kRosterKeepEvery.inMilliseconds - 1},
      where: 'member = ?',
      whereArgs: [m1.words],
    );
    live.ctlOut.clear();
    await ri(m1, newer);
    expect((await rosterInviteOf(db, _g, m1.words))!.id, newer.id);
    expect(rosterTo(m2.words), {m1.words: base64Encode(newer.link)});
    // m1 made theirs again, and may have lost the set: every one to them
    expect(rosterTo(m1.words), {
      _me: base64Encode(mine.link),
      m1.words: base64Encode(newer.link),
      m2.words: base64Encode(r2.link),
    });
    expect(await rosterInvitesToPass(db), isEmpty);
  });

  test('a second roster hello from a member who has a session with me is '
      'dropped: no session made again, no second first frame', () async {
    final mine = await myRoster();
    final admin = await _Phone.make('admin-of-twice', seed++);
    final down = await phone('below-me-twice', above: false);
    await joinFrom(admin, [(down, await down.roster())]);
    final h1 = await down.helloTo(mine.id);
    await app.receiveRelay([(peer: 'f0:${mine.id}', cipher: h1.line)]);
    await _settle();
    await app.ctlPassForTest;
    await _settle();
    expect(await signalSession.sessionStore.load(down.words), isNotNull);
    int toDown() => io.sent.where((s) => s.$1 == 'fc ${down.x}').length;
    expect(toDown(), 1);
    final pair = await pairOf(db, kMainIdent, down.keyHex);
    final h2 = await down.helloTo(mine.id);
    await app.receiveRelay([(peer: 'f0:${mine.id}', cipher: h2.line)]);
    await _settle();
    await app.ctlPassForTest;
    await _settle();
    expect(firstFails.codes, contains('again'));
    expect(toDown(), 1);
    expect((await pairOf(db, kMainIdent, down.keyHex)).seed, pair.seed);
    expect(
      app.peerFcFor(down.words),
      _hex(readInvite(signalSession.lib, h1.once.link).firstContact),
    );
  });

  test('a removed member: their hello at my roster invite is dropped before '
      'it is noted, and my hello out to them takes no opener', () async {
    final mine = await myRoster();
    final admin = await _Phone.make('admin-removes-it', seed++);
    final down = await phone('below-removed-one', above: false);
    final up = await phone('above-removed-one', above: true);
    await joinFrom(admin, [
      (down, await down.roster()),
      (up, await up.roster()),
    ]);
    await app.sendHellosOwed();
    await _settle();
    final once =
        (await hellosOf('out', up.keyHex)).single['invite_id'] as String;
    for (final p in [down, up]) {
      await live.removeGroupMember(_g, p.words);
      await _Halo(db).removeGroupMember(_g, p.words);
    }
    expect(await rosterInvitesIn(db, _g), isEmpty);
    expect(await hellosOf('out', up.keyHex), isEmpty);
    expect((await inviteOf(db, kMainIdent, once))!.usedAt, isNotNull);
    expect(engine.unsubscribed, contains(once));
    await db.delete('hello_seen');
    final hl = await down.helloTo(mine.id);
    await app.receiveRelay([(peer: 'f0:${mine.id}', cipher: hl.line)]);
    await _settle();
    expect(firstFails.codes, contains('roster'));
    expect(await db.query('hello_seen'), isEmpty);
    expect(await signalSession.sessionStore.load(down.words), isNull);
  });

  test('a member I know on another identity keeps the old way: their roster '
      'invite not kept, no hello to them, theirs not answered', () async {
    final mine = await myRoster();
    final admin = await _Phone.make('admin-two-idents', seed++);
    final up = await phone('above-other-ident', above: true);
    final down = await phone('below-other-ident', above: false);
    final ups = await up.roster();
    final downs = await down.roster();
    Future<void> elsewhere() async {
      for (final p in [up, down]) {
        await db.update(
          'contacts',
          {'ident': 3},
          where: 'halo_id = ?',
          whereArgs: [p.words],
        );
      }
      await app.loadIdentsForTest();
    }

    for (final p in [up, down]) {
      live.person(p.words, xpub: p.x, onion: p.onion, accepted: 0);
      await live.upsertContactStub(p.words, p.onion, p.x);
    }
    await elsewhere();
    expect(app.identOf(up.words), 3);
    await joinFrom(admin, [(up, ups), (down, downs)]);
    await elsewhere();
    await app.groupControlForTest(
      admin.words,
      await env(
        admin,
        GroupControl(
          type: 'roster',
          participants: [
            up.part(ri: ups),
            down.part(ri: downs),
          ],
        ),
      ),
      live,
    );
    await _settle();
    expect(await rosterInvitesIn(db, _g), isEmpty);
    expect(await hellosOf('want', up.keyHex), isEmpty);
    expect(engine.hellos, isEmpty);
    final hl = await down.helloTo(mine.id);
    await app.receiveRelay([(peer: 'f0:${mine.id}', cipher: hl.line)]);
    await _settle();
    expect(await signalSession.sessionStore.load(down.words), isNull);
  });

  test('a member takes a newer roster invite from the admin within the '
      'day: the day limit is the admin\'s alone', () async {
    await myRoster();
    final admin = await _Phone.make('admin-of-rone', seed++);
    final up = await phone('above-me-rone', above: true);
    const h = 3600 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    final first = await up.roster(nowMs: now - 5 * h);
    await joinFrom(admin, [(up, first)]);
    expect((await rosterInviteOf(db, _g, up.words))!.id, first.id);
    final newer = await up.roster(nowMs: now);
    await app.groupControlForTest(
      admin.words,
      await env(
        admin,
        GroupControl(
          type: 'roster',
          participants: [up.part(ri: newer)],
        ),
      ),
      live,
    );
    await _settle();
    expect((await rosterInviteOf(db, _g, up.words))!.id, newer.id);
  });

  test('a roster invite kept, or a roster hello taken, ahead of now (a '
      'clock set back since) holds nothing back', () async {
    final mine = await myRoster();
    final admin = await _Phone.make('admin-of-rtwo', seed++);
    final down = await phone('below-me-rtwo', above: false);
    const h = 3600 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ahead = now + 30 * 24 * h;
    await joinFrom(admin, [(down, await down.roster())]);
    final m = await _Phone.make('member-of-rtwo', seed++);
    final r1 = await m.roster(nowMs: now - 5 * h);
    final r2 = await m.roster(nowMs: now);
    Future<bool> keep(InviteRow r) => keepRosterInvite(
      db,
      'grp-r-two',
      m.words,
      r.link,
      id: r.id,
      issued: r.issued,
      passOn: true,
    );
    expect(await keep(r1), isTrue);
    await db.update(
      'roster_invites',
      {'kept': ahead},
      where: 'member = ?',
      whereArgs: [m.words],
    );
    expect(await keep(r2), isTrue);
    expect((await rosterInviteOf(db, 'grp-r-two', m.words))!.id, r2.id);
    // a hello of theirs taken ahead of now: theirs is taken today
    await db.insert('hellos', {
      'ident': kMainIdent,
      'way': 'taken',
      'peer': down.keyHex,
      'invite_id': '0' * 32,
      'at': ahead,
    });
    final hl = await down.helloTo(mine.id);
    await app.receiveRelay([(peer: 'f0:${mine.id}', cipher: hl.line)]);
    await _settle();
    expect(firstFails.codes, isNot(contains('again')));
    expect(await signalSession.sessionStore.load(down.words), isNotNull);
    final taken = await hellosOf('taken', down.keyHex);
    expect(taken.single['at'] as int, lessThan(ahead));
  });

  test('a member whose newest roster invite went past its life waits for '
      'no hello: the old way runs', () async {
    await myRoster();
    final admin = await _Phone.make('admin-of-rthree', seed++);
    final down = await phone('below-me-rthree', above: false);
    await joinFrom(admin, [(down, await down.roster())]);
    expect(await app.rosterPairWaitsForTest(down.words), isTrue);
    const h = 3600 * 1000;
    final old = await down.roster(
      nowMs: DateTime.now().millisecondsSinceEpoch - 400 * 24 * h,
    );
    await db.update(
      'roster_invites',
      {'id': old.id, 'issued': old.issued, 'invite': old.link},
      where: 'member = ?',
      whereArgs: [down.words],
    );
    expect(await app.rosterPairWaitsForTest(down.words), isFalse);
  });

  test('a member removed after their roster invite went past its life: my '
      'hello out to them is spent all the same', () async {
    await myRoster();
    final admin = await _Phone.make('admin-of-rfive', seed++);
    final up = await phone('above-me-rfive', above: true);
    await joinFrom(admin, [(up, await up.roster())]);
    await app.sendHellosOwed();
    await _settle();
    final once =
        (await hellosOf('out', up.keyHex)).single['invite_id'] as String;
    const h = 3600 * 1000;
    final old = await up.roster(
      nowMs: DateTime.now().millisecondsSinceEpoch - 400 * 24 * h,
    );
    expect(
      () => readInvite(signalSession.lib, old.link),
      throwsA(isA<InviteRefused>()),
    );
    await db.update(
      'roster_invites',
      {'id': old.id, 'issued': old.issued, 'invite': old.link},
      where: 'member = ?',
      whereArgs: [up.words],
    );
    await db.update(
      'hellos',
      {'fc': _hex(signalSession.lib.parseInvite(old.link).firstContact)},
      where: 'way = ? AND peer = ?',
      whereArgs: ['out', up.keyHex],
    );
    await live.removeGroupMember(_g, up.words);
    await _Halo(db).removeGroupMember(_g, up.words);
    expect(await hellosOf('out', up.keyHex), isEmpty);
    expect((await inviteOf(db, kMainIdent, once))!.usedAt, isNotNull);
    expect(engine.unsubscribed, contains(once));
  });

  test('a pass waiting is not put off by more roster invites coming', () async {
    await myRoster();
    final ms = [
      for (final c in 'abcdef'.split(''))
        await _Phone.make('member-waits-$c', seed++),
    ];
    for (final p in ms) {
      live.person(p.words, xpub: p.x, onion: p.onion);
      await live.upsertContact(p.words, p.onion, p.x);
    }
    live.group(_g, [_me, for (final p in ms) p.words], admin: _me);
    rosterPassWait = const Duration(milliseconds: 400);
    final started = DateTime.now();
    for (final p in ms) {
      final r = await p.roster();
      await app.groupControlForTest(
        p.words,
        await env(p, GroupControl(type: 'ri', invite: base64Encode(r.link))),
        live,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    expect(DateTime.now().difference(started), greaterThan(rosterPassWait));
    // the first went within the wait of its own, more coming or not
    expect(live.ctlTo(ms.first.words), contains('roster'));
    await Future<void>.delayed(rosterPassWait * 2);
    await _settle();
    for (final p in ms) {
      expect(live.ctlTo(p.words), contains('roster'));
    }
    expect(await rosterInvitesToPass(db), isEmpty);
  });

  test('a member on 0.5.x in a new group is named once they have been in it '
      'a while, until a pair with them forms; one with a roster invite or a '
      'session is never named', () async {
    await myRoster();
    final admin = await _Phone.make('admin-of-new', seed++);
    final old = await phone('older-in-new', above: true);
    final up = await phone('newer-in-new', above: true);
    final known = await phone('known-in-new', above: true);
    await joinFrom(admin, [
      (old, null),
      (up, await up.roster()),
      (known, null),
    ]);
    live.joinedAt[_g] = DateTime.now().millisecondsSinceEpoch;
    // the admin and someone chatting here already hold sessions with me
    for (final p in [admin, known]) {
      await processPeerBundle(p.words, await p.ss.makeBundleB64());
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final later = now + kOldPeerWait.inMilliseconds + 1000;
    expect(await app.groupWaitsForUpdate(_g, nowMs: now), isEmpty);
    expect(await app.groupWaitsForUpdate(_g, nowMs: later), [old.words]);
    // they updated: a pair formed, nothing is said any more
    await processPeerBundle(old.words, await old.ss.makeBundleB64());
    expect(await app.groupWaitsForUpdate(_g, nowMs: later), isEmpty);
  });
}
