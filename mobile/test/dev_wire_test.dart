// SPDX-License-Identifier: GPL-3.0-or-later
// the dev chat on the wire, with real libsignal over a phone's rows kept in
// maps. nothing reaches his keys before the first send, either way of
// writing: nothing listened for, sent or kept. the first send checks his
// card, builds his session in the store the chat uses and listens on the
// chat's own lane. an anonymous start makes a name that shares nothing
// with the everyday one. what comes on his lanes lands only in the chat
// running on that lane, opened in its own store, and the rest is dropped
// and marked seen. a delete lets go of all of it and stays a delete, a
// decoy never reaches the wire, and each new guard broken once is caught
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_frame.dart';
import 'package:kryfo/devchat/dev_gate.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devchat/dev_lane.dart';
import 'package:kryfo/devchat/dev_start.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloEngine,
        makePreKeyBundleB64,
        processPeerBundle,
        signalEncrypt,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'dev_chat_fakes.dart' show DevTestDb;
import 'mem_db.dart';

const _dev = 'dev:m1';
const _words = 'scare-raven-rare';
const _myWords = 'my-own-words';
// the everyday store's registration id: past the range a new one is drawn
// from, so the made name's can never be it by chance
const _everydayReg = 16383;

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

final _rnd = Random.secure();
String _rndHex(int n) => _hex([for (var i = 0; i < n; i++) _rnd.nextInt(256)]);
var _n = 0;

// a phone's signal store, bootstrapped the way the app does it
Future<({SignalSession ss, MemDb db, String xPub})> _phone() async {
  final pair = Curve.generateKeyPair();
  final xPub = pair.publicKey.serialize().sublist(1);
  final db = MemDb();
  final ss = SignalSession();
  await ss.bootstrap(
    database: db,
    xPubBytes: xPub,
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (ss: ss, db: db, xPub: _hex(xPub));
}

// a name as the engine makes one: an x25519 pair, and an ed key of seed
// then public half
Map<String, dynamic> _newName() {
  final x = Curve.generateKeyPair();
  final edPub = _rndHex(32);
  return {
    'id': 'made-name-${_n++}',
    'ed_priv': _rndHex(32) + edPub,
    'x_priv': _hex(x.privateKey.serialize()),
    'ed_pub': edPub,
    'x_pub': _hex(x.publicKey.serialize().sublist(1)),
    'onion_key': 'k',
    'onion': 'made.onion',
  };
}

// the developer: his phone and the key the app pins from its card
late ({SignalSession ss, MemDb db, String xPub}) _marios;
late DevKey _m1;
// someone with a key of their own
late ({SignalSession ss, MemDb db, String xPub}) _other;

// the person's everyday identity
late String _myX;
late String _myXPriv;
final _myEd = _rndHex(32);

// the person's phone: one database for every row, the everyday signal
// store's among them, as one file holds them on a phone
final _mem = MemDb();

// the rows the receive side reads and writes, straight off that database
class _Phone extends DevTestDb {
  _Phone(super.mem, [super.container]);

  final seen = <String>{};
  // the rooms the poll looked for
  final roomsAsked = <String>[];
  // saves that fail next
  var saveFails = 0;

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  bool _flag(String id, String col) => _contact(id)?[col] == 1;

  @override
  Future<Database> open() async => mem;
  @override
  Future<Map<String, Object?>?> roomByPub(String pub) async {
    roomsAsked.add(pub);
    return null;
  }

  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _contact(haloId);
  @override
  Future<bool> isAccepted(String haloId) async => _flag(haloId, 'accepted');
  @override
  Future<bool> isBlocked(String haloId) async => _flag(haloId, 'blocked');
  @override
  Future<bool> isMuted(String haloId) async => _flag(haloId, 'muted');
  @override
  Future<bool> isVouched(String haloId) async => false;
  @override
  Future<bool> isBackPaired(String peerId) async =>
      _flag(peerId, 'back_paired');
  @override
  Future<void> markBackPaired(String peerId) async => mem.update(
    'contacts',
    {'back_paired': 1},
    where: 'halo_id = ?',
    whereArgs: [peerId],
  );
  @override
  Future<String?> contactXPub(String haloId) async =>
      _contact(haloId)?['xpub'] as String?;
  @override
  Future<void> setContactXPub(String haloId, String xpub) async {}
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> parkedRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> vouchedPending() async => const [];
  @override
  Future<bool> alreadySeen(String hash) async => seen.contains(hash);
  @override
  Future<void> markSeen(String hash) async => seen.add(hash);
  @override
  Future<void> markSeenLong(String hash) async => seen.add(hash);
  @override
  Future<void> markDelivered(String msgUid, {required String from}) async {}
  // what the outbox took as sent
  final marked = <String>[];
  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async => [
    for (final r in mem.rows('messages'))
      if (r['direction'] == 'out' && r['sent'] == 0 && r['group_id'] == null) r,
  ];
  @override
  Future<void> markSent(String msgUid) async => marked.add(msgUid);
  @override
  Future<bool> messageExists(String msgUid) async =>
      mem.rows('messages').any((r) => r['msg_uid'] == msgUid);
  @override
  Future<void> unparkIfArchived(String haloId) async {}
  @override
  Future<void> bumpUnread(String peerId) async {}
  @override
  Future<void> clearUnread(String peerId) async {}
  @override
  Future<int> filesInFlightFrom(String from, {String? except}) async => 0;

  @override
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async =>
      mem
          .rows('messages')
          .where((r) => r['peer_id'] == peerId && r['direction'] == 'in')
          .length;

  @override
  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    int? burnSecs,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
    String? poll,
    String? sticker,
    int? sentAt,
  }) async {
    if (saveFails > 0) {
      saveFails--;
      throw StateError('the disk is full');
    }
    await mem.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
      'msg_uid': msgUid,
      'group_id': groupId,
      'sent': sent,
    });
  }
}

// signal as it is, the wire and the shade noted
class _Io extends AppIo {
  final listened = <String>[];
  final sent = <(String, String)>[];
  final rang = <(String, String?)>[];
  final tried = <String>[];

  @override
  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) {
    tried.add(peer);
    return super.decrypt(peer, cipher, flagKeyChange: flagKeyChange);
  }

  @override
  void listen(String xPub) => listened.add(xPub);
  @override
  String edPub() => _myEd;
  @override
  String xPub() => _myX;
  @override
  Future<String> relaySend(String xPub, String cipher) async {
    sent.add(('relay $xPub', cipher));
    return 'ok';
  }

  @override
  Future<String> onionSend(String onion, String cipher) async {
    sent.add(('onion $onion', cipher));
    return 'ok';
  }

  @override
  Future<String> firstContactSend(String xPub, String fc, String cipher) async {
    sent.add(('fc $xPub $fc', cipher));
    return 'ok';
  }

  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
    String? msgUid,
  }) async => rang.add((title, payload));

  @override
  Future<void> unnotify(String payload) async {}
}

// the engine: the names it makes and the room lanes it drops. anything
// else asked of it is noted and fails
class _Engine implements HaloEngine {
  final calls = <String>[];
  final dropped = <String>[];
  Map<String, dynamic>? Function() makes = _newName;

  @override
  Map<String, dynamic>? quietIdentity() {
    calls.add('quietIdentity');
    return makes();
  }

  @override
  void roomUnsubscribeBg(String pub) {
    calls.add('roomUnsubscribeBg');
    dropped.add(pub);
  }

  @override
  String myXPubkey() => _myX;
  @override
  String myEdPubkey() => _myEd;

  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName.toString());
    return super.noSuchMethod(i);
  }
}

class _NoStore implements RouterStore {
  @override
  Future<List<Map<String, Object?>>> hidden() async => const [];
  @override
  Future<String?> meta(String k) async => null;
  @override
  Future<int> inboxCount() async => 0;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the router was asked for ${i.memberName}');
}

class _NoSeal implements VaultSeal {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the seal was asked for ${i.memberName}');
}

late _Phone _live;
late _Io _io;
late _Engine _engine;
late AppState _app;

// a fresh install: the dev chat's row fresh, no one else, his card pinned
Future<void> _world() async {
  for (final t in [
    'contacts',
    'messages',
    'devchat',
    'sessions',
    'peer_identities',
    for (final n in kSignalTables) '$kDevSignalPrefix$n',
  ]) {
    await _mem.delete(t);
  }
  await devChatTables(_mem, now: 1);
  _live = _Phone(_mem);
  _io = _Io();
  _engine = _Engine();
  useEngineForTest(_engine);
  final router = VaultRouter(_NoStore(), _NoSeal());
  await router.load();
  _app = AppState(io: _io, router: router)..myId = _myWords;
  useDatabasesForTest(_live, Session(_live));
  devLane.forget();
}

DevChatRow _row([MemDb? db]) => DevChatRow.of((db ?? _mem).rows('devchat')[0]);

DevSelf _self([MemDb? db]) {
  final r = _row(db);
  return DevSelf.ofKeys(r.anonId, r.anonEdPriv, r.anonXPriv)!;
}

List<Map<String, Object?>> _kept(String table, [MemDb? db]) => [
  for (final r in (db ?? _mem).rows(table))
    if ((r['address'] ?? r['halo_id'] ?? r['peer_id']) == _dev) r,
];

// every row of the anonymous store
int _anonRows([MemDb? db]) => [
  for (final n in kSignalTables) ...(db ?? _mem).rows('$kDevSignalPrefix$n'),
].length;

bool get _hasDevContact => _kept('contacts').isNotEmpty;

// the tag his lane carries in the poll: the pair lane of his key with three
// words, the room tag of the made name when anonymous
String _roomTag(DevSelf s) => 'room:${s.xPub}:${_m1.xPub}';

// a frame of the person's, as the chat builds one
Future<String> _frame(String text) => wrapMessage(
  text,
  msgUid: 'p${_n++}',
  sender: SenderInfo(
    haloId: _myWords,
    edPub: _myEd,
    onion: 'me.onion',
    xPub: _myX,
  ),
);

// what he reads of a cipher, filed under [from]
Future<Map<String, dynamic>> _hisRead(String from, String cipher) async {
  final w = base64Decode(cipher);
  final body = Uint8List.fromList(w.sublist(1));
  final c = SessionCipher(
    _marios.ss.sessionStore,
    _marios.ss.preKeyStore,
    _marios.ss.signedPreKeyStore,
    _marios.ss.identityStore,
    SignalProtocolAddress(from, 1),
  );
  final plain = w[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  final s = utf8.decode(plain);
  expect(s, startsWith('halo/1:'));
  return jsonDecode(s.substring(7)) as Map<String, dynamic>;
}

// his answer to [who], as his phone seals it
Future<String> _hisAnswer(String who, String text, String uid) async =>
    _marios.ss.encryptTo(
      who,
      await wrapMessage(
        text,
        msgUid: uid,
        sender: SenderInfo(
          haloId: _words,
          edPub: 'ed-his',
          onion: '',
          xPub: _m1.xPub,
        ),
      ),
    );

// what came in for the chat
List<String> _inbox() => [
  for (final r in _mem.rows('messages'))
    if (r['peer_id'] == _dev && r['direction'] == 'in')
      r['plaintext'] as String,
];

// the mark a line leaves once it is off the relay
String _hash(String cipher) => sha256.convert(utf8.encode(cipher)).toString();

// what was sent without being waited for gets there
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

// the calls of the doors, as a stand-in for the engine behind the gate
class _Out {
  final calls = <String>[];

  Future<String> out() async {
    calls.add('out');
    return 'ok';
  }

  Future<String> room(String priv) async {
    calls.add('room $priv');
    return 'ok';
  }
}

// how the gate lets out a first message and a listen for his key
Future<List<String>> _wire(String cipher) async {
  final o = _Out();
  await devGate.sendFirstContact(
    _m1.xPub,
    _app.peerFcFor(_dev)!,
    cipher,
    out: o.out,
    room: o.room,
  );
  await devGate.listen(_m1.xPub, out: o.out, room: o.room);
  return o.calls;
}

// his card with its signature spoiled, or another identity's under his key
DevKey _card(String bundle) => DevKey(
  keyId: _m1.keyId,
  threeWords: _m1.threeWords,
  xPub: _m1.xPub,
  bundle: bundle,
  fc: _m1.fc,
);

// his card with one of its fields changed
String _edited(String bundle, String field, Object value) {
  final j = Map<String, Object?>.from(
    jsonDecode(utf8.decode(base64Decode(bundle))) as Map,
  );
  j[field] = value;
  return base64Encode(utf8.encode(jsonEncode(j)));
}

String _flipped(String bundle) {
  final j = Map<String, Object?>.from(
    jsonDecode(utf8.decode(base64Decode(bundle))) as Map,
  );
  final sig = base64Decode(j['signedPreKeySignature'] as String);
  sig[7] ^= 0x01;
  j['signedPreKeySignature'] = base64Encode(sig);
  return base64Encode(utf8.encode(jsonEncode(j)));
}

// a start that throws, and what it threw
Future<Object?> _failed(bool anon) async {
  try {
    await _app.devBegin(anon: anon);
  } catch (e) {
    return e;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _marios = await _phone();
    _other = await _phone();
    _m1 = DevKey(
      keyId: 'm1',
      threeWords: _words,
      xPub: _marios.xPub,
      bundle: await makePreKeyBundleB64(_marios.ss),
      fc: _rndHex(32),
    );
    await _mem.insert('signal_meta', {'k': 'regId', 'v': '$_everydayReg'});
    final me = Curve.generateKeyPair();
    _myX = _hex(me.publicKey.serialize().sublist(1));
    _myXPriv = _hex(me.privateKey.serialize());
    await signalSession.bootstrap(
      database: _mem,
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    useDevKeysForTest([_m1]);
    await _world();
  });

  tearDown(() => useDevKeysForTest(null));

  group('nothing before the first send', () {
    // the boot, a mode switch, the outbox, and lines on his lanes: none of
    // it reaches his keys while the chat is fresh
    Future<void> everythingButASend() async {
      await _app.subscribeKnown();
      await _app.resubscribe();
      await _app.subscribeDevLane();
      await _app.subscribePeer(_dev);
      await _app.drainOutbox();
      await _app.receiveRelay([
        (peer: _m1.xPub, cipher: 'c1'),
        (peer: 'room:${_rndHex(32)}:${_m1.xPub}', cipher: 'c2'),
      ]);
      await _settle();
    }

    test('fresh: nothing listened for, sent, kept or asked of the '
        'engine', () async {
      await everythingButASend();
      expect(_io.listened, isEmpty);
      expect(_io.sent, isEmpty);
      expect(_io.tried, isEmpty);
      expect(_io.rang, isEmpty);
      expect(_engine.calls, isEmpty);
      expect(_hasDevContact, isFalse);
      expect(_kept('sessions'), isEmpty);
      expect(_anonRows(), 0);
      expect(_row().state, DevState.fresh);
      // the lines on his lanes are off the relay all the same
      expect(_live.seen, hasLength(2));
      // his first-contact address is known and still shut
      expect(_app.peerFcFor(_dev), _m1.fc);
      expect(await _wire('c'), isEmpty);
    });

    for (final anon in [false, true]) {
      final how = anon ? 'anonymous' : 'three words';
      test('$how: the first send makes his session and listens once, and '
          'sends nothing itself', () async {
        await everythingButASend();
        expect(await _app.devBegin(anon: anon), DevStart.ok);
        expect(_io.listened, [_m1.xPub]);
        expect(_io.sent, isEmpty);
        expect(_engine.calls, anon ? ['quietIdentity'] : isEmpty);
        expect(_row().state, anon ? DevState.anon : DevState.everyday);
        // the gate now lets the chat's own first message out, the way
        // the chat was started, and its listen
        final c = await signalEncrypt(_dev, await _frame('a bug'));
        expect(
          await _wire(c),
          anon
              ? ['room ${_row().anonXPriv}', 'room ${_row().anonXPriv}']
              : ['out', 'out'],
        );
        // and it is his to read, as the chat was started
        final read = await _hisRead('who-${_n++}', c);
        expect(read['h'], anon ? _self().id : _myWords);
        expect(read['sp'], kDevSupport);
        // a second start changes nothing
        expect(await _app.devBegin(anon: !anon), DevStart.ok);
        expect(_io.listened, [_m1.xPub]);
        expect(_row().state, anon ? DevState.anon : DevState.everyday);
      });
    }

    test('two screens asking at once start it once', () async {
      final a = _app.devBegin(anon: true);
      final b = _app.devBegin(anon: false);
      expect(await a, DevStart.ok);
      expect(await b, DevStart.ok);
      expect(_engine.calls, ['quietIdentity']);
      expect(_row().state, DevState.anon);
      expect(_io.listened, [_m1.xPub]);
      expect(_kept('sessions'), isEmpty);
    });
  });

  group('an anonymous start', () {
    test('makes a name of its own that shares nothing with the everyday '
        'one, in a store of its own', () async {
      final everydayStore = {
        for (final t in kSignalTables) t: '${_mem.rows(t)}',
      };
      expect(await _app.devBegin(anon: true), DevStart.ok);
      final s = _self();
      expect(s.id, isNot(_myWords));
      expect(s.edPub, isNot(_myEd));
      expect(s.xPub, isNot(_myX));
      // its session and his key in the dev_ store, none in the everyday one
      expect(_kept('${kDevSignalPrefix}sessions'), hasLength(1));
      final held = _kept('${kDevSignalPrefix}peer_identities');
      expect(held, hasLength(1));
      expect(held.single['identity_key'], pinnedIdentity(_m1));
      expect({
        for (final t in kSignalTables) t: '${_mem.rows(t)}',
      }, everydayStore);
      final reg = _mem.rows('${kDevSignalPrefix}signal_meta').single['v'];
      expect(reg, isNot('$_everydayReg'));
      // an initiator only: no prekeys handed out or made
      expect(_mem.rows('${kDevSignalPrefix}prekeys'), isEmpty);
      expect(_mem.rows('${kDevSignalPrefix}signed_prekeys'), isEmpty);
      // his chat's row: his key, no bundle, no onion
      final c = _kept('contacts').single;
      expect(c['xpub'], _m1.xPub);
      expect(c['peer_bundle'], isNull);
      expect(c['onion'], '');
      // what he reads is sealed by the made name alone
      final cipher = await signalEncrypt(_dev, await _frame('hello'));
      final raw = base64Decode(cipher);
      final pkm = PreKeySignalMessage(Uint8List.fromList(raw.sublist(1)));
      expect(_hex(pkm.getIdentityKey().serialize().sublist(1)), s.xPub);
      expect(pkm.getRegistrationId(), isNot(_everydayReg));
      final read = await _hisRead('anon-${_n++}', cipher);
      expect(
        [read['h'], read['e'], read['x'], read['o']],
        [s.id, s.edPub, s.xPub, ''],
      );
      expect(jsonEncode(read), isNot(contains(_myWords)));
      expect(jsonEncode(read), isNot(contains(_myEd)));
      expect(jsonEncode(read), isNot(contains(_myX)));
    });

    test('after a delete, a new start is another name', () async {
      await _app.devBegin(anon: true);
      final first = _self();
      await _app.devDelete();
      expect(await _app.devBegin(anon: true), DevStart.none);
      await _live.devChat.writeToMarios();
      expect(await _app.devBegin(anon: true), DevStart.ok);
      final second = _self();
      expect(second.id, isNot(first.id));
      expect(second.edPub, isNot(first.edPub));
      expect(second.xPub, isNot(first.xPub));
      expect(_kept('${kDevSignalPrefix}sessions'), hasLength(1));
      final read = await _hisRead(
        'anon-${_n++}',
        await signalEncrypt(_dev, await _frame('again')),
      );
      expect(read['x'], second.xPub);
    });

    test('a name that is the everyday one, or does not read, is no name: '
        'nothing is kept', () async {
      final bad = <Map<String, dynamic>? Function()>[
        () => null,
        () => {..._newName(), 'id': _myWords},
        () => {..._newName(), 'ed_pub': _rndHex(32)},
        () => {..._newName(), 'x_pub': _rndHex(32)},
        () => {..._newName(), 'x_priv': 'not hex'},
        () {
          final n = _newName();
          return {...n, 'ed_priv': _rndHex(32) + _myEd, 'ed_pub': _myEd};
        },
        () => {..._newName(), 'x_priv': _myXPriv, 'x_pub': _myX},
      ];
      for (final make in bad) {
        _engine.makes = make;
        final e = await _failed(true);
        expect(e, isA<StateError>());
        expect(devKeyFailed(e!), isFalse);
        expect(_row().state, DevState.fresh);
        expect(_hasDevContact, isFalse);
        expect(_anonRows(), 0);
        expect(_io.listened, isEmpty);
      }
    });
  });

  group('the pinned key is checked', () {
    for (final (what, bundle) in [
      ('a flipped signature byte', () => _flipped(_m1.bundle)),
      ('another identity behind his key', () => '_other'),
      ('a card that does not read', () => 'not a card'),
    ]) {
      for (final anon in [false, true]) {
        test('$what, ${anon ? 'anonymous' : 'three words'}: refused with '
            'the line, nothing kept or listened for', () async {
          var b = bundle();
          if (b == '_other') b = await makePreKeyBundleB64(_other.ss);
          useDevKeysForTest([_card(b)]);
          final e = await _failed(anon);
          expect(e, isA<DevKeyCheckFailed>());
          expect(devKeyFailed(e!), isTrue);
          expect(_row().state, DevState.fresh);
          expect(_hasDevContact, isFalse);
          expect(_kept('sessions'), isEmpty);
          expect(_kept('peer_identities'), isEmpty);
          expect(_anonRows(), 0);
          expect(_io.listened, isEmpty);
          expect(_io.sent, isEmpty);
          // checked before any name is made
          expect(_engine.calls, isEmpty);
        });
      }
    }

    for (final anon in [false, true]) {
      final how = anon ? 'anonymous' : 'three words';
      test('$how: a card that checks out but will not build a session, or '
          'a start that breaks after it, keeps nothing', () async {
        // his signature holds, the prekey it signs for does not read
        useDevKeysForTest([
          _card(
            _edited(
              _m1.bundle,
              'preKeyPublic',
              base64Encode(List.filled(33, 0)),
            ),
          ),
        ]);
        expect(devCardChecks(currentDevKey!), isTrue);
        expect(await _failed(anon), isA<DevKeyCheckFailed>());
        void nothingKept() {
          expect(_row().state, DevState.fresh);
          expect(_hasDevContact, isFalse);
          expect(_kept('sessions'), isEmpty);
          expect(_kept('peer_identities'), isEmpty);
          expect(_anonRows(), 0);
          expect(_io.listened, isEmpty);
        }

        nothingKept();
        // the card is fine, the row will not move
        useDevKeysForTest([_m1]);
        _mem.failOn = 'update:devchat';
        try {
          final e = await _failed(anon);
          expect(e, isA<StateError>());
          expect(devKeyFailed(e!), isFalse);
        } finally {
          _mem.failOn = null;
        }
        nothingKept();
        // and the next try starts clean
        expect(await _app.devBegin(anon: anon), DevStart.ok);
      });
    }

    test('his own card passes the check it is held to', () async {
      expect(devCardChecks(_m1), isTrue);
      expect(devCardChecks(_card(_flipped(_m1.bundle))), isFalse);
      expect(
        devCardChecks(_card(await makePreKeyBundleB64(_other.ss))),
        isFalse,
      );
      expect(devCardChecks(_card('')), isFalse);
    });
  });

  group('what comes on his lanes', () {
    // the chat started, its first message read by him, and his answer
    Future<({String who, String? tag})> started(bool anon) async {
      await _app.devBegin(anon: anon);
      final who = '${anon ? 'anon' : 'me'}-${_n++}';
      await _hisRead(who, await signalEncrypt(_dev, await _frame('hello')));
      return (who: who, tag: anon ? _roomTag(_self()) : _m1.xPub);
    }

    test('anonymous: the room tag of the made name lands in the chat, '
        'opened in its own store', () async {
      final s = await started(true);
      final everyday = '${_mem.rows('sessions')}';
      final anonBefore = '${_mem.rows('${kDevSignalPrefix}sessions')}';
      final answer = await _hisAnswer(s.who, 'thanks, looking', 'r1');
      await _app.receiveRelay([(peer: s.tag!, cipher: answer)]);
      await _settle();
      expect(_inbox(), ['thanks, looking']);
      expect(_io.tried, [_dev]);
      // the made name's ratchet stepped, the everyday store did not move
      expect('${_mem.rows('${kDevSignalPrefix}sessions')}', isNot(anonBefore));
      expect('${_mem.rows('sessions')}', everyday);
      expect(_live.seen, contains(_hash(answer)));
      // it rings under his name
      expect(_io.rang, [('Marios', _dev)]);
      // its tick goes back sealed by the made name, and only through its
      // room lane
      expect(_io.sent.single.$1, 'relay ${_m1.xPub}');
      final tick = _io.sent.single.$2;
      final read = await _hisRead(s.who, tick);
      expect(read['dr'], 'r1');
      expect(read['h'], _self().id);
      final o = _Out();
      await devGate.nostrSend(_m1.xPub, tick, out: o.out, room: o.room);
      expect(o.calls, ['room ${_row().anonXPriv}']);
    });

    test('three words: his key\'s pair lane lands in the chat', () async {
      final s = await started(false);
      final answer = await _hisAnswer(s.who, 'on it', 'r2');
      await _app.receiveRelay([(peer: s.tag!, cipher: answer)]);
      await _settle();
      expect(_inbox(), ['on it']);
      expect(_io.rang, [('Marios', _dev)]);
      final tick = _io.sent.single;
      expect(tick.$1, 'relay ${_m1.xPub}');
      expect((await _hisRead(s.who, tick.$2))['h'], _myWords);
    });

    test('an answer that opened and did not go in lands when it comes '
        'again', () async {
      final s = await started(false);
      final answer = await _hisAnswer(s.who, 'on it', 'r3');
      final line = (peer: s.tag!, cipher: answer);
      _live.saveFails = 1;
      expect(await _app.receiveRelay([line]), {0});
      expect(_inbox(), isEmpty);
      expect(_live.seen, isNot(contains(_hash(answer))));
      // signal does not open it a second time
      expect(await _app.receiveRelay([line]), isEmpty);
      await _settle();
      expect(_inbox(), ['on it']);
      expect(_io.tried, [_dev]);
      expect(_live.seen, contains(_hash(answer)));
    });

    test('his answers caught up in any order land in the order he wrote '
        'them', () async {
      final s = await started(false);
      final words = ['are you free?', 'at 6', 'at the station'];
      final said = [
        for (final (i, w) in words.indexed) await _hisAnswer(s.who, w, 'o$i'),
      ];
      await _app.receiveRelay([
        for (final c in [said[2], said[0], said[1]]) (peer: s.tag!, cipher: c),
      ]);
      await _settle();
      expect(_inbox(), words);
    });

    for (final anon in [false, true]) {
      test('${anon ? 'anonymous' : 'three words'}: the other lane, '
          'another name\'s room, a clear frame: dropped and marked seen, '
          'never tried', () async {
        final s = await started(anon);
        final lines = [
          // his real answer, on the lane the chat does not run on
          (
            peer: anon ? _m1.xPub : 'room:${_rndHex(32)}:${_m1.xPub}',
            cipher: await _hisAnswer(s.who, 'x', 'o1'),
          ),
          (peer: 'room:${_rndHex(32)}:${_m1.xPub}', cipher: 'c${_n++}'),
          (peer: s.tag!, cipher: '{"halo_ctl":"bundle","from":"$_words"}'),
        ];
        await _app.receiveRelay(lines);
        await _settle();
        expect(_inbox(), isEmpty);
        expect(_io.tried, isEmpty);
        expect(_io.rang, isEmpty);
        expect(_io.sent, isEmpty);
        expect(_live.seen, hasLength(lines.length));
      });
    }

    test('a room tag that is not his goes to the rooms as before', () async {
      await started(true);
      final pub = _rndHex(32);
      await _app.receiveRelay([
        (peer: 'room:$pub:${_rndHex(32)}', cipher: 'c'),
      ]);
      expect(_live.roomsAsked, [pub]);
      expect(_io.tried, isEmpty);
      expect(devKeyOfTag('room:${_rndHex(32)}:${_rndHex(32)}'), isNull);
      expect(devKeyOfTag('roomfc:${_m1.xPub}'), isNull);
      expect(devKeyOfTag('firstcontact'), isNull);
    });
  });

  group('the outbox', () {
    for (final anon in [false, true]) {
      test('${anon ? 'anonymous' : 'three words'}: a message sent again '
          'before he answers goes to his first-contact address, sealed as '
          'the chat was started', () async {
        await _app.devBegin(anon: anon);
        await _mem.insert('messages', {
          'peer_id': _dev,
          'direction': 'out',
          'plaintext': 'still there?',
          'sent_at': DateTime.now().millisecondsSinceEpoch - 60000,
          'msg_uid': 'q1',
          'sent': 0,
          // ground over these words: one that does not fit is ground again
          'pow_nonce': grindPow('still there?', powBits),
        });
        _app.sendModeForTest = 'fast';
        await _app.drainOutbox();
        for (var i = 0; i < 100 && _live.marked.isEmpty; i++) {
          await _settle();
        }
        expect(_io.sent.single.$1, 'fc ${_m1.xPub} ${_m1.fc}');
        final c = _io.sent.single.$2;
        expect(_live.marked, ['q1']);
        final read = await _hisRead('who-${_n++}', c);
        expect(read['m'], 'still there?');
        expect(read['h'], anon ? _self().id : _myWords);
        // and the gate lets it out that way
        expect(await _wire(c), [
          anon ? 'room ${_row().anonXPriv}' : 'out',
          anon ? 'room ${_row().anonXPriv}' : 'out',
        ]);
      });
    }
  });

  group('the lane is listened to only once started', () {
    Future<List<String>> resubscribed() async {
      _io.listened.clear();
      await _app.resubscribe();
      await _app.subscribeDevLane();
      await _app.subscribePeer(_dev);
      return [..._io.listened];
    }

    test('fresh and gone: never', () async {
      expect(await resubscribed(), isEmpty);
      await _app.devDelete();
      expect(await resubscribed(), isEmpty);
      // a contact row planted under his chat's id changes nothing
      await _mem.insert('contacts', {
        'halo_id': _dev,
        'onion': '',
        'xpub': _m1.xPub,
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
      });
      expect(await resubscribed(), isEmpty);
    });

    for (final anon in [false, true]) {
      test('${anon ? 'anonymous' : 'three words'}: each time, on its own '
          'lane', () async {
        await _app.devBegin(anon: anon);
        expect(await resubscribed(), [_m1.xPub, _m1.xPub, _m1.xPub]);
        final o = _Out();
        await devGate.listen(_m1.xPub, out: o.out, room: o.room);
        expect(o.calls, [anon ? 'room ${_row().anonXPriv}' : 'out']);
      });
    }

    test('a chat restored without its made name, or on a retired key: '
        'never', () async {
      await _app.devBegin(anon: true);
      await scrubDevAnon(_mem);
      devLane.forget();
      expect(_row().nameless, isTrue);
      expect(await resubscribed(), isEmpty);
      final o = _Out();
      await devGate.listen(_m1.xPub, out: o.out, room: o.room);
      expect(o.calls, isEmpty);
      // and nothing it could still be sent lands
      await _app.receiveRelay([(peer: _m1.xPub, cipher: 'c')]);
      expect(_io.tried, isEmpty);

      await _world();
      await _app.devBegin(anon: false);
      useDevKeysForTest([
        DevKey(
          keyId: 'm1',
          threeWords: _words,
          xPub: _m1.xPub,
          bundle: _m1.bundle,
          fc: _m1.fc,
          status: DevKeyStatus.retired,
        ),
      ]);
      expect(await resubscribed(), isEmpty);
    });

    test('the boot and a mode switch ask for it', () {
      final src = File('lib/main.dart').readAsStringSync();
      final boot = src.substring(src.indexOf('await _subscribeRooms();'));
      expect(
        boot.indexOf('await subscribeDevLane();'),
        lessThan(boot.indexOf('await subscribeKnown();')),
      );
      final re = src.substring(
        src.indexOf('Future<void> resubscribe() async {'),
      );
      expect(
        re.substring(0, re.indexOf('\n  }\n')),
        contains('await subscribeDevLane();'),
      );
      expect(
        src.substring(src.indexOf('Future<void> setSendMode(')),
        contains('await resubscribe();'),
      );
    });
  });

  group('a delete', () {
    test('anonymous: the room lane dropped, the ciphers forgotten, and '
        'nothing after it lands, rings or is listened for', () async {
      await _app.devBegin(anon: true);
      final s = _self();
      final who = 'anon-${_n++}';
      final c = await signalEncrypt(_dev, await _frame('hello'));
      await _hisRead(who, c);
      expect(devTokens.has(c), isTrue);
      await _app.devDelete();
      expect(_engine.dropped, [s.xPub]);
      expect(devTokens.has(c), isFalse);
      expect(await _wire(c), isEmpty);
      expect(_row().state, DevState.gone);
      expect(_hasDevContact, isFalse);
      expect(_anonRows(), 0);
      // his answer after it
      final answer = await _hisAnswer(who, 'still there?', 'r3');
      await _app.receiveRelay([(peer: _roomTag(s), cipher: answer)]);
      await _settle();
      expect(_inbox(), isEmpty);
      expect(_io.tried, isEmpty);
      expect(_io.rang, isEmpty);
      expect(_live.seen, contains(_hash(answer)));
      _io.listened.clear();
      await _app.resubscribe();
      await _app.subscribePeer(_dev);
      expect(_io.listened, isEmpty);
      // nothing brings it back but the settings row, and that as new
      expect(await _app.devBegin(anon: true), DevStart.none);
      expect(await _live.devChat.writeToMarios(), _dev);
      expect(_row().state, DevState.fresh);
      await _app.resubscribe();
      expect(_io.listened, isEmpty);
    });

    test('three words: his session goes, and what comes on his key after '
        'is dropped', () async {
      await _app.devBegin(anon: false);
      final who = 'me-${_n++}';
      await _hisRead(who, await signalEncrypt(_dev, await _frame('hi')));
      expect(_kept('sessions'), hasLength(1));
      await _app.devDelete();
      // no room lane to drop: the pair lane goes with the next start
      expect(_engine.dropped, isEmpty);
      expect(_kept('sessions'), isEmpty);
      expect(_kept('peer_identities'), isEmpty);
      final answer = await _hisAnswer(who, 'hello?', 'r4');
      await _app.receiveRelay([(peer: _m1.xPub, cipher: answer)]);
      await _settle();
      expect(_inbox(), isEmpty);
      expect(_io.tried, isEmpty);
      expect(_io.rang, isEmpty);
      expect(_live.seen, contains(_hash(answer)));
    });
  });

  group('a decoy', () {
    late MemDb decoyMem;
    late _Phone decoy;

    Future<void> inDecoy() async {
      decoyMem = MemDb();
      await devChatTables(decoyMem, now: 1);
      decoy = _Phone(decoyMem, HaloContainer.decoy);
      useDatabasesForTest(_live, Session(decoy));
    }

    for (final anon in [false, true]) {
      test('${anon ? 'anonymous' : 'three words'}: its chat starts on this '
          'phone alone: no store, no lane, nothing on the wire', () async {
        await inDecoy();
        final everydayStore = '${_mem.rows('sessions')}';
        expect(await _app.devBegin(anon: anon), DevStart.ok);
        expect(_row(decoyMem).state, anon ? DevState.anon : DevState.everyday);
        expect(_engine.calls, anon ? ['quietIdentity'] : isEmpty);
        expect(_io.listened, isEmpty);
        expect(_io.sent, isEmpty);
        // no store in either container, the everyday chat as it was
        expect(_anonRows(decoyMem), 0);
        expect(_anonRows(), 0);
        expect('${_mem.rows('sessions')}', everydayStore);
        expect(_row().state, DevState.fresh);
        expect(_hasDevContact, isFalse);
        // the wire reads the everyday chat, which has not started
        expect(await _wire('c'), isEmpty);
        await _app.resubscribe();
        expect(_io.listened, isEmpty);
      });
    }

    test('a card that does not check out says the same line', () async {
      await inDecoy();
      useDevKeysForTest([_card(_flipped(_m1.bundle))]);
      expect(await _failed(true), isA<DevKeyCheckFailed>());
      expect(_row(decoyMem).state, DevState.fresh);
    });

    test('with the everyday chat running, its start adds nothing on the '
        'wire', () async {
      await _app.devBegin(anon: false);
      await inDecoy();
      _io.listened.clear();
      expect(await _app.devBegin(anon: true), DevStart.ok);
      expect(_io.listened, isEmpty);
      expect(_io.sent, isEmpty);
      expect(_row().state, DevState.everyday);
    });

    test('its delete leaves the everyday chat running', () async {
      await _app.devBegin(anon: true);
      final c = await signalEncrypt(_dev, await _frame('hello'));
      await inDecoy();
      await _app.devBegin(anon: true);
      await _app.devDelete();
      expect(_row(decoyMem).state, DevState.gone);
      expect(_row().state, DevState.anon);
      expect(_engine.dropped, isEmpty);
      expect(devTokens.has(c), isTrue);
      _io.listened.clear();
      await _app.resubscribe();
      expect(_io.listened, [_m1.xPub]);
    });
  });

  group('each new guard, broken once, is caught', () {
    test('the poll: a check on his key alone would take every line the '
        'running chat refuses', () async {
      final made = DevSelf.ofKeys(
        'made-one',
        _rndHex(64),
        _hex(Curve.generateKeyPair().privateKey.serialize()),
      )!;
      DevChatRow row(DevState s, {String? priv, String? id}) => DevChatRow(
        state: s,
        keyId: 'm1',
        createdAt: 1,
        anonId: id,
        anonEdPriv: priv == null ? null : _rndHex(64),
        anonXPriv: priv,
      );
      final anonPriv = _hex(Curve.generateKeyPair().privateKey.serialize());
      final anonRow = row(DevState.anon, priv: anonPriv, id: 'made-two');
      final anonSelf = DevSelf.ofKeys(
        anonRow.anonId,
        anonRow.anonEdPriv,
        anonRow.anonXPriv,
      )!;
      final refused = <(DevChatRow?, String)>[
        (null, _m1.xPub),
        (row(DevState.fresh), _m1.xPub),
        (row(DevState.gone), _m1.xPub),
        (row(DevState.everyday), _roomTag(anonSelf)),
        (anonRow, _m1.xPub),
        (anonRow, _roomTag(made)),
        (row(DevState.anon), _roomTag(anonSelf)),
      ];
      for (final (r, tag) in refused) {
        expect(devKeyOfTag(tag), isNotNull, reason: tag);
        expect(devLaneTakes(r, tag), isFalse, reason: '${r?.state} $tag');
      }
      expect(devLaneTakes(row(DevState.everyday), _m1.xPub), isTrue);
      expect(devLaneTakes(anonRow, _roomTag(anonSelf)), isTrue);
      // a retired key takes nothing either
      useDevKeysForTest([
        DevKey(
          keyId: 'm1',
          threeWords: _words,
          xPub: _m1.xPub,
          bundle: _m1.bundle,
          fc: _m1.fc,
          status: DevKeyStatus.retired,
        ),
      ]);
      expect(devLaneTakes(row(DevState.everyday), _m1.xPub), isFalse);
    });

    test('the card: the row alone takes a spoiled one, the check refuses '
        'it', () async {
      final spoiled = _card(_flipped(_m1.bundle));
      useDevKeysForTest([spoiled]);
      expect(devCardChecks(spoiled), isFalse);
      // a decoy has no store to catch it: the check is all there is
      expect(await _live.devChat.begin(spoiled), isTrue);
      // with three words the store would refuse it too
      await expectLater(
        processPeerBundle(_dev, spoiled.bundle, into: (await _phone()).ss),
        throwsA(isA<InvalidKeyException>()),
      );
    });

    test('the made name: the row alone takes any name, the start refuses '
        'the everyday one', () async {
      final mine = DevAnon(
        id: _myWords,
        edPriv: _rndHex(32) + _myEd,
        xPriv: _rndHex(32),
      );
      expect(await _live.devChat.begin(_m1, anon: mine), isTrue);
      await _world();
      _engine.makes = () => {..._newName(), 'id': _myWords};
      expect(await _failed(true), isA<StateError>());
      expect(_row().state, DevState.fresh);
    });

    test('the delete: the rows alone leave the ciphers passing and the '
        'room lane open', () async {
      await _app.devBegin(anon: true);
      final c = await signalEncrypt(_dev, await _frame('hello'));
      await _live.devChat.delete();
      expect(devTokens.has(c), isTrue);
      expect(_engine.dropped, isEmpty);
      await _world();
      await _app.devBegin(anon: true);
      final d = await signalEncrypt(_dev, await _frame('hello'));
      await _app.devDelete();
      expect(devTokens.has(d), isFalse);
      expect(_engine.dropped, hasLength(1));
    });

    test('the gate: a pass for any cipher would let a clear bundle ask out '
        'with three words, the token check refuses it', () async {
      final r = DevChatRow(state: DevState.everyday, keyId: 'm1', createdAt: 1);
      const ask = '{"halo_ctl":"bundle","from":"$_myWords"}';
      expect(DevGate.relayWay(r, _m1, ask, (_) => true), DevWay.pass);
      expect(DevGate.relayWay(r, _m1, ask, devTokens.has), DevWay.refused);
      expect(
        DevGate.firstContactWay(r, _m1, _m1, ask, devTokens.has),
        DevWay.refused,
      );
    });

    test('the lane\'s listen: a check on the contact row alone would '
        'listen before the first send', () async {
      await _mem.insert('contacts', {
        'halo_id': _dev,
        'onion': '',
        'xpub': _m1.xPub,
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
      });
      expect(await _live.contactXPub(_dev), _m1.xPub);
      await _app.subscribeDevLane();
      await _app.subscribePeer(_dev);
      expect(_io.listened, isEmpty);
    });
  });
}
