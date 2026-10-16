// SPDX-License-Identifier: GPL-3.0-or-later
// a name stays with the key first seen for it. a first contact or a card
// that gives the name of someone here with another key leaves their
// session, row and chat as they were; such a first contact is filed on an
// id of its own, with a line saying the name it gave. a first message opens
// under a name only with the key that name is bound to, and a name with a
// key but no session yet takes a first message only with its proof of work.
// words a request, an introduction or a group gave, never checked, do not
// turn a link away: the person chooses which one keeps them, a verified one
// is never replaced, and a deleted chat holds no name at all.
// real libsignal over rows kept in maps; the engine derives an id from an
// ed key the way the app asks it to
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devchat/support.dart';
import 'package:kryfo/first_contact.dart' show firstFails;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        appState,
        askInboxMove,
        HaloEngine,
        LinkKin,
        kAdminGone,
        askTakeName,
        kNameAsk,
        nameCheckOf,
        buildHaloUri,
        haloUriV3,
        handleHaloUriAdded,
        hasSessionWith,
        openAddedChatLater,
        linkKinOf,
        makePreKeyBundleB64,
        processPeerBundle,
        session,
        signalDecrypt,
        unboundIdOf,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/scam_shield.dart' show ShieldFlag;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _me = 'my-own-words';
const _amber = 'amber-still-river';
const _member = 'quiet-member-one';
const _hidden = 'hidden-member-two';
const _g2 = 'g2hidden0001';
const _said = 'new phone, same me';

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
final _rnd = Random.secure();
String _rndHex(int n) => _hex([for (var i = 0; i < n; i++) _rnd.nextInt(256)]);

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

List<int> _keyOf(_Phone p) => p.ss.identityKeyPair.getPublicKey().serialize();

// the three words an ed key stands for, as the engine derives them
final _idOf = <String, String>{};

class _Engine implements HaloEngine {
  _Engine(this.x, this.ed);
  final String x;
  final String ed;
  @override
  String idFromEdPub(String hexPub) => _idOf[hexPub] ?? 'no-such-id';
  @override
  String myXPubkey() => x;
  @override
  String myEdPubkey() => ed;
  @override
  void nostrSubscribeBg(String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(String peerXPubHex) => dropped.add(peerXPubHex);
  @override
  dynamic noSuchMethod(Invocation i) {
    engineAsked.add(i.memberName);
    throw UnimplementedError('engine: ${i.memberName}');
  }
}

// what the engine was asked for that it does not do here, sends among them
final engineAsked = <Symbol>[];
// the addresses the app stopped listening on
final dropped = <String>[];
const _sends = {#sendTo, #nostrSend, #sendFirstContact};

// the addresses let go of
final unheard = <String>[];

// signal as it is; the network and android stand in
class _Io extends AppIo {
  const _Io();
  @override
  void listen(String xPub, {bool fresh = false}) {}
  @override
  void unlisten(String xPub) => unheard.add(xPub);
  @override
  Future<String> relaySend(String xPub, String cipher) async => 'ok';
  @override
  Future<String> onionSend(String onion, String cipher) async => 'ok';
  @override
  Future<String> firstContactSend(String x, String fc, String c) async => 'ok';
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
  String edPub() => 'ed-me';
  @override
  String xPub() => 'x-me';
}

// what someone holding [ss] reads of a cipher I sealed for them
Future<String?> _reads(SignalSession ss, String cipher) async {
  try {
    final w = base64Decode(cipher);
    final body = Uint8List.fromList(w.sublist(1));
    final c = SessionCipher(
      ss.sessionStore,
      ss.preKeyStore,
      ss.signedPreKeyStore,
      ss.identityStore,
      SignalProtocolAddress(_me, 1),
    );
    final plain = w[0] == CiphertextMessage.prekeyType
        ? await c.decrypt(PreKeySignalMessage(body))
        : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
    return utf8.decode(plain);
  } catch (_) {
    return null;
  }
}

// a first message to me from [p], giving the name [says] and the ed key [ed]
Future<String> _opener(
  _Phone p,
  String says,
  String ed,
  String text, {
  int? pow,
}) async {
  await processPeerBundle(_me, await makePreKeyBundleB64(), into: p.ss);
  final plain = await wrapMessage(
    text,
    msgUid: 'u${_rnd.nextInt(1 << 30)}',
    powNonce: pow,
    powBitsUsed: pow == null ? null : powBits,
    sender: SenderInfo(
      haloId: says,
      edPub: ed,
      onion: 'o-${p.xPub.substring(0, 8)}',
      xPub: p.xPub,
    ),
  );
  return p.ss.encryptTo(_me, plain);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

// his phone's rows, with the inbox beside them
class _InboxRows extends ArrivalRows {
  _InboxRows() : super(HaloContainer.everyday);
  final inbox = MemDb();
  @override
  SupportChats get support => SupportChats(() async => inbox);
}

// rows where filing a contact can be held at [gate], noting how many are
// filing at once, and where a block check can fail once
class _GatedRows extends ArrivalRows {
  _GatedRows() : super(HaloContainer.everyday);
  Completer<void>? gate;
  var inside = 0;
  var most = 0;
  var blockFails = 0;

  @override
  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
    bool owe = false,
  }) async {
    final g = gate;
    gate = null;
    most = max(most, ++inside);
    try {
      await g?.future;
      await super.upsertContact(haloId, onion, xpub, accepted: accepted);
    } finally {
      inside--;
    }
  }

  @override
  Future<bool> isBlocked(String haloId) async {
    if (blockFails > 0) {
      blockFails--;
      throw StateError('the disk is full');
    }
    return super.isBlocked(haloId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late ArrivalRows live;
  late ArrivalStore store;
  late AppState app;
  late _Phone amber;
  late String amberEd;
  late int pow;

  Future<void> world({
    List<RouterCard> hiddenMembers = const [],
    ArrivalRows? rows,
  }) async {
    live = rows ?? ArrivalRows(HaloContainer.everyday);
    live.person(_amber, onion: 'o-amber', xpub: amber.xPub);
    store = ArrivalStore();
    if (hiddenMembers.isNotEmpty) {
      await store.putHidden(_g2, kHiddenGroup, groupCard(hiddenMembers), 1);
      await store.putMeta('pub', 'pub-A');
    }
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    app = AppState(io: const _Io(), router: router)..myId = _me;
    useDatabasesForTest(live, Session(live));
  }

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('name_binding');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    final me = Curve.generateKeyPair();
    useEngineForTest(
      _Engine(_hex(me.publicKey.serialize().sublist(1)), _rndHex(32)),
    );
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    amber = await _phone();
    amberEd = _rndHex(32);
    _idOf[amberEd] = _amber;
    // a chat with amber, started from her card
    await processPeerBundle(_amber, await makePreKeyBundleB64(amber.ss));
    // a first message owes its proof of work, once for every test here
    pow = grindPow(_said, powBits);
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  // the chats an add opened
  final opened = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await world();
    opened.clear();
    final was = openAddedChatLater;
    openAddedChatLater = opened.add;
    addTearDown(() => openAddedChatLater = was);
  });

  // a stranger's next text, as their phone seals it
  Future<String> strayNext(
    _Phone p,
    String says,
    String ed,
    String uid,
  ) async => p.ss.encryptTo(
    _me,
    await wrapMessage(
      _said,
      msgUid: uid,
      powNonce: pow,
      powBitsUsed: powBits,
      sender: SenderInfo(haloId: says, edPub: ed, onion: 'o-s', xPub: p.xPub),
    ),
  );

  test('copies of a stranger\'s opener off a relay\'s backlog take no '
      'place on their shelf and change nothing of the request', () async {
    final stray = await _phone();
    final ed = _rndHex(32);
    const id = 'stray-words-here';
    _idOf[ed] = id;
    final c = await _opener(stray, id, ed, _said, pow: pow);
    await app.receiveRelay([(peer: 'firstcontact', cipher: c)]);
    await _settle();
    await app.receiveRelay([
      (peer: stray.xPub, cipher: await strayNext(stray, id, ed, 'u2')),
    ]);
    await _settle();
    final held = live.heldRows[id]?.length ?? 0;
    final row = {...?live.people[id]};
    for (var i = 0; i < 2; i++) {
      live.seen.clear();
      await app.receiveRelay([(peer: 'firstcontact', cipher: c)]);
      await _settle();
    }
    expect(live.heldRows[id]?.length ?? 0, held);
    expect(live.people[id], row);
  });

  test('a stranger\'s opener that opened and was not filed lands when it '
      'comes again', () async {
    final stray = await _phone();
    final ed = _rndHex(32);
    const id = 'stray-words-six';
    _idOf[ed] = id;
    final c = await _opener(stray, id, ed, _said, pow: pow);
    final line = (peer: 'firstcontact', cipher: c);
    live.beforeSave = () {
      live.beforeSave = null;
      throw StateError('the disk is full');
    };
    expect(await app.receiveRelay([line]), {0});
    expect(live.msgs.where((m) => m['peer_id'] == id), isEmpty);
    expect(live.seen, isEmpty);
    // signal does not open it a second time
    expect(await app.receiveRelay([line]), isEmpty);
    await _settle();
    expect(
      [
        for (final m in live.msgs)
          if (m['peer_id'] == id) m['plaintext'],
      ],
      [_said],
    );
    expect(live.seen, hasLength(1));
  });

  test('a copy of an opener being filed is not filed beside it, and comes '
      'again', () async {
    final rows = _GatedRows();
    await world(rows: rows);
    final stray = await _phone();
    final ed = _rndHex(32);
    const id = 'stray-words-seven';
    _idOf[ed] = id;
    final c = await _opener(stray, id, ed, _said, pow: pow);
    final line = (peer: 'firstcontact', cipher: c);
    final gate = rows.gate = Completer<void>();
    // the first one fails once it is let go
    rows.beforeSave = () {
      rows.beforeSave = null;
      throw StateError('the disk is full');
    };
    final first = app.receiveRelay([line]);
    await _settle();
    expect(rows.inside, 1);
    // its copy off the onion lane and the relay's at the same time
    await app.receiveOnion([c]);
    expect(await app.receiveRelay([line]), {0});
    gate.complete();
    expect(await first, {0});
    expect(rows.most, 1);
    expect(await app.receiveRelay([line]), isEmpty);
    await _settle();
    expect(
      [
        for (final m in rows.msgs)
          if (m['peer_id'] == id) m['plaintext'],
      ],
      [_said],
    );
  });

  test('an opener without its proof that failed on its first try leaves '
      'no row and no address behind', () async {
    final rows = _GatedRows();
    await world(rows: rows);
    final stray = await _phone();
    final ed = _rndHex(32);
    const id = 'stray-words-eight';
    _idOf[ed] = id;
    final line = (
      peer: 'firstcontact',
      cipher: await _opener(stray, id, ed, _said),
    );
    unheard.clear();
    rows.blockFails = 1;
    expect(await app.receiveRelay([line]), {0});
    expect(rows.people[id], isNotNull);
    expect(await app.receiveRelay([line]), isEmpty);
    expect(rows.people[id], isNull);
    expect(unheard, [stray.xPub]);
  });

  test('a copy of a turned-away stranger\'s opener leaves them turned '
      'away, and tells them nothing', () async {
    final stray = await _phone();
    final ed = _rndHex(32);
    const id = 'stray-words-two';
    _idOf[ed] = id;
    final c = await _opener(stray, id, ed, _said, pow: pow);
    await app.receiveRelay([(peer: 'firstcontact', cipher: c)]);
    await _settle();
    final uid =
        live.msgs.firstWhere((m) => m['peer_id'] == id)['msg_uid'] as String;
    // declined: the text gone and kept as gone, the row parked
    live.msgs.removeWhere((m) => m['peer_id'] == id);
    live.gone.add((id, uid));
    live.people[id]!['archived'] = 1;
    live.people[id]!['accepted'] = 0;
    final row = {...live.people[id]!};
    live.seen.clear();
    engineAsked.clear();
    await app.receiveRelay([(peer: 'firstcontact', cipher: c)]);
    await _settle();
    expect(live.people[id], row);
    expect(live.msgs.where((m) => m['peer_id'] == id), isEmpty);
    expect(engineAsked.where(_sends.contains), isEmpty);
  });

  test('a first contact under a contact\'s name with another key leaves '
      'the contact as it was', () async {
    final other = await _phone();
    await app.receiveOnion([
      await _opener(other, _amber, amberEd, _said, pow: pow),
    ]);
    await _settle();
    final next = await signalSession.encryptTo(_amber, 'for amber only');
    expect(await _reads(other.ss, next), isNull);
    expect(await _reads(amber.ss, next), 'for amber only');
    expect(live.people[_amber], containsPair('xpub', amber.xPub));
    expect(live.people[_amber], containsPair('onion', 'o-amber'));
    expect(live.people[_amber], containsPair('accepted', 1));
    expect(live.msgs.where((m) => m['peer_id'] == _amber), isEmpty);
  });

  test('such a first contact is a request on an id of its own, with a line '
      'saying the name it gave', () async {
    final other = await _phone();
    await app.receiveOnion([
      await _opener(other, _amber, amberEd, _said, pow: pow),
    ]);
    await _settle();
    final own = unboundIdOf(_keyOf(other));
    expect(own, isNot(contains('-')));
    expect(live.people[own], containsPair('accepted', 0));
    expect(live.people[own], containsPair('xpub', other.xPub));
    expect(
      [
        for (final m in live.msgs)
          if (m['peer_id'] == own) m['plaintext'],
      ],
      [_said],
    );
    expect(
      ShieldFlag.fromRow(live.shields[own])?.lead.noticed,
      l10n.scamShieldGivesUsedName(_amber),
    );
    // and the next message from them opens there too
    final again = await other.ss.encryptTo(
      _me,
      await wrapMessage(
        'still me',
        msgUid: 'again1',
        sender: SenderInfo(
          haloId: _amber,
          edPub: amberEd,
          onion: 'o',
          xPub: other.xPub,
        ),
      ),
    );
    await app.receiveOnion([again]);
    await _settle();
    expect(live.msg('again1')?['peer_id'], own);
  });

  test('a first contact from the contact themself still lands in their '
      'chat', () async {
    final c = await _opener(amber, _amber, amberEd, 'from amber');
    await app.receiveOnion([c]);
    await _settle();
    expect(
      live.msgs.where((m) => m['peer_id'] == _amber).single,
      containsPair('plaintext', 'from amber'),
    );
  });

  test(
    'an opener that comes again off a relay is a copy: the session '
    'as it runs stays, nothing shows twice, and what follows opens',
    () async {
      final c = await _opener(amber, _amber, amberEd, 'opened once');
      await app.receiveRelay([(peer: amber.xPub, cipher: c)]);
      await _settle();
      // a turn each way: the session moves on past the opener
      expect(
        await _reads(amber.ss, await signalSession.encryptTo(_amber, 'back')),
        'back',
      );
      final turned = await amber.ss.encryptTo(
        _me,
        await wrapMessage(
          'a turn',
          msgUid: 'u-turn',
          sender: SenderInfo(
            haloId: _amber,
            edPub: amberEd,
            onion: 'o-amber',
            xPub: amber.xPub,
          ),
        ),
      );
      await app.receiveRelay([(peer: amber.xPub, cipher: turned)]);
      await _settle();
      final mine = live.msgs.where((m) => m['peer_id'] == _amber).length;
      final addr = SignalProtocolAddress(_amber, 1);
      final before = (await signalSession.sessionStore.loadSession(
        addr,
      )).serialize();
      // a fresh install walks the relay's backlog, its seen marks gone,
      // and the opener comes again
      live.seen.clear();
      await app.receiveRelay([(peer: amber.xPub, cipher: c)]);
      await _settle();
      expect(
        (await signalSession.sessionStore.loadSession(addr)).serialize(),
        before,
      );
      expect(live.msgs.where((m) => m['peer_id'] == _amber).length, mine);
      // what she writes next still opens
      final next = await amber.ss.encryptTo(
        _me,
        await wrapMessage(
          'after the copy',
          msgUid: 'u-after',
          sender: SenderInfo(
            haloId: _amber,
            edPub: amberEd,
            onion: 'o-amber',
            xPub: amber.xPub,
          ),
        ),
      );
      await app.receiveRelay([(peer: amber.xPub, cipher: next)]);
      await _settle();
      expect(
        live.msgs
            .where((m) => m['peer_id'] == _amber)
            .map((m) => m['plaintext']),
        contains('after the copy'),
      );
    },
  );

  test('a second opener held up on a relay while the chat moved on is '
      'still read, and the session runs on both ways', () async {
    final first = await _opener(amber, _amber, amberEd, 'one');
    // sent before she heard back: the same start, the next number
    final second = await amber.ss.encryptTo(
      _me,
      await wrapMessage(
        'two, late',
        msgUid: 'u-late',
        sender: SenderInfo(
          haloId: _amber,
          edPub: amberEd,
          onion: 'o-amber',
          xPub: amber.xPub,
        ),
      ),
    );
    await app.receiveRelay([(peer: amber.xPub, cipher: first)]);
    await _settle();
    // turns each way, more than the chains a session keeps
    for (var i = 0; i < 6; i++) {
      expect(
        await _reads(amber.ss, await signalSession.encryptTo(_amber, 'r$i')),
        'r$i',
      );
      final back = await amber.ss.encryptTo(
        _me,
        await wrapMessage(
          'b$i',
          msgUid: 'u-b$i',
          sender: SenderInfo(
            haloId: _amber,
            edPub: amberEd,
            onion: 'o-amber',
            xPub: amber.xPub,
          ),
        ),
      );
      await app.receiveRelay([(peer: amber.xPub, cipher: back)]);
      await _settle();
    }
    await app.receiveRelay([(peer: amber.xPub, cipher: second)]);
    await _settle();
    expect(
      live.msgs.where((m) => m['peer_id'] == _amber).map((m) => m['plaintext']),
      contains('two, late'),
    );
    // and the session runs on both ways
    expect(
      await _reads(amber.ss, await signalSession.encryptTo(_amber, 'on')),
      'on',
    );
    final after = await amber.ss.encryptTo(
      _me,
      await wrapMessage(
        'still here',
        msgUid: 'u-still',
        sender: SenderInfo(
          haloId: _amber,
          edPub: amberEd,
          onion: 'o-amber',
          xPub: amber.xPub,
        ),
      ),
    );
    await app.receiveRelay([(peer: amber.xPub, cipher: after)]);
    await _settle();
    expect(
      live.msgs.where((m) => m['peer_id'] == _amber).map((m) => m['plaintext']),
      contains('still here'),
    );
  });

  test('a first message opens under a name only with the key bound to '
      'it', () async {
    final member = await _phone();
    final memberEd = _rndHex(32);
    _idOf[memberEd] = _member;
    // a member of a group whose card came with the group: a key, no session
    live.person(_member, onion: 'o-m', xpub: member.xPub, accepted: 0);
    final stranger = await _phone();
    final strangerEd = _rndHex(32);
    _idOf[strangerEd] = 'another-new-name';
    final c = await _opener(stranger, 'another-new-name', strangerEd, 'hi');
    expect(await signalDecrypt(_member, c), isNull);
    await app.receiveOnion([c]);
    await _settle();
    expect(live.msgs.where((m) => m['peer_id'] == _member), isEmpty);
    expect(await hasSessionWith(_member), isFalse);
    // the member's own first message pays like any other: without its
    // proof of work it is not kept, with it it lands under their name
    await app.receiveOnion([
      await _opener(member, _member, memberEd, 'no proof'),
    ]);
    await _settle();
    expect(live.msgs.where((m) => m['peer_id'] == _member), isEmpty);
    await app.receiveOnion([
      await _opener(member, _member, memberEd, _said, pow: pow),
    ]);
    await _settle();
    expect(
      live.msgs.where((m) => m['peer_id'] == _member).single,
      containsPair('plaintext', _said),
    );
    expect(live.people[_member], containsPair('xpub', member.xPub));
  });

  test('a first contact that gives its x key and runs on another is not '
      'kept', () async {
    final other = await _phone();
    final otherEd = _rndHex(32);
    _idOf[otherEd] = 'plain-new-name';
    await processPeerBundle(_me, await makePreKeyBundleB64(), into: other.ss);
    final plain = await wrapMessage(
      _said,
      msgUid: 'xk1',
      powNonce: pow,
      powBitsUsed: powBits,
      sender: SenderInfo(
        haloId: 'plain-new-name',
        edPub: otherEd,
        onion: 'o',
        xPub: amber.xPub,
      ),
    );
    await app.receiveOnion([await other.ss.encryptTo(_me, plain)]);
    await _settle();
    expect(live.msg('xk1'), isNull);
    expect(live.people.containsKey('plain-new-name'), isFalse);
  });

  test('a card that gives a contact\'s name with another key changes '
      'nothing', () async {
    final other = await _phone();
    final link = haloUriV3(
      _amber,
      'o-other',
      Uri.encodeQueryComponent(await makePreKeyBundleB64(other.ss)),
      'ab' * 32,
    );
    expect(await handleHaloUriAdded(link), (
      l10n.appLinkWordsTaken(_amber),
      false,
    ));
    // the older card, by its x key alone
    expect(
      (await handleHaloUriAdded(buildHaloUri(_amber, 'o-other', other.xPub))),
      (l10n.appLinkWordsTaken(_amber), false),
    );
    expect(live.people[_amber], containsPair('onion', 'o-amber'));
    expect(live.people[_amber], containsPair('xpub', amber.xPub));
    final next = await signalSession.encryptTo(_amber, 'still for amber');
    expect(await _reads(other.ss, next), isNull);
    expect(await _reads(amber.ss, next), 'still for amber');
  });

  test('a card whose key does not read is refused and changes '
      'nothing', () async {
    for (final x in ['', 'zz', 'ab' * 31]) {
      expect(await handleHaloUriAdded(buildHaloUri(_amber, 'o-other', x)), (
        l10n.appInvalidUri,
        false,
      ));
      expect(await handleHaloUriAdded(buildHaloUri('new-name-here', 'o', x)), (
        l10n.appInvalidUri,
        false,
      ));
    }
    expect(live.people[_amber], containsPair('onion', 'o-amber'));
    expect(live.people[_amber], containsPair('xpub', amber.xPub));
    expect(live.people.containsKey('new-name-here'), isFalse);
    expect(live.rowWrites, isEmpty);
    // the same card with her own key still reads
    expect(
      await handleHaloUriAdded(buildHaloUri(_amber, 'o-amber', amber.xPub)),
      (l10n.appAlreadySaved(_amber), true),
    );
  });

  group('adding by link', () {
    setUp(() => appState.myId = _me);
    tearDown(() => appState.myId = '');

    test('my own card adds no one', () async {
      final mine = haloUriV3(
        _me,
        'o-me',
        Uri.encodeQueryComponent(await makePreKeyBundleB64()),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(mine), (l10n.appYourOwnInvite, false));
      expect(opened, isEmpty);
      expect(live.people.containsKey(_me), isFalse);
      expect(live.rowWrites, isEmpty);
    });

    test('someone blocked stays blocked and is told so', () async {
      const blocked = 'blocked-before-asked';
      final them = await _phone();
      live.person(blocked, accepted: 0);
      live.people[blocked]!['blocked'] = 1;
      final card = haloUriV3(
        blocked,
        'o-them',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(card), (
        l10n.appTheyAreBlocked(blocked),
        false,
      ));
      expect(opened, isEmpty);
      expect(live.people[blocked], containsPair('accepted', 0));
      expect(live.people[blocked], containsPair('blocked', 1));
      expect(live.rowWrites, isEmpty);
    });

    test('on his phone, someone added whose chat is in the inbox is asked '
        'about, once; anyone else, or on another phone, never', () async {
      const inInbox = 'wrote-from-row';
      const other = 'plain-new-friend';
      final rows = _InboxRows();
      live = rows;
      useDatabasesForTest(rows, Session(rows));
      await rows.support.file(inInbox);
      final asked = <String>[];
      final was = askInboxMove;
      askInboxMove = asked.add;
      final x = 'ab' * 32;
      useDevKeysForTest([
        DevKey(keyId: 'm1', threeWords: 'a-b-c', xPub: x, bundle: '', fc: ''),
      ]);
      addTearDown(() {
        askInboxMove = was;
        useDevKeysForTest(null);
        appState.myXPub = '';
      });
      final phones = {inInbox: await _phone(), other: await _phone()};
      // the same person's card each time: their key stays theirs
      Future<String> card(String id) async => haloUriV3(
        id,
        'o-$id',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(phones[id]!.ss)),
        'ab' * 32,
      );
      appState.myXPub = x;
      expect(appState.devMode, isTrue);
      expect((await handleHaloUriAdded(await card(inInbox))).$2, isTrue);
      expect(asked, [inInbox]);
      // the question is the answer: their chat does not open over it
      expect(opened, isEmpty);
      // kept apart, and their card again: asked once, not on every add
      expect((await handleHaloUriAdded(await card(inInbox))).$2, isTrue);
      expect(asked, [inInbox]);
      expect((await handleHaloUriAdded(await card(other))).$2, isTrue);
      expect(asked, [inInbox]);
      // moved: nothing more to ask
      await rows.support.moveOut(inInbox);
      expect((await handleHaloUriAdded(await card(inInbox))).$2, isTrue);
      expect(asked, [inInbox]);
      // another phone files nothing and asks nothing
      await rows.support.file(inInbox);
      appState.myXPub = '';
      expect((await handleHaloUriAdded(await card(inInbox))).$2, isTrue);
      expect(asked, [inInbox]);
    });

    test('someone added is in the chat list at once, and their chat '
        'opens', () async {
      const fresh = 'fresh-from-search';
      final them = await _phone();
      final card = haloUriV3(
        fresh,
        'o-fresh',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(appState.contacts.where((c) => c.haloId == fresh), isEmpty);
      expect(await handleHaloUriAdded(card), ('', true));
      expect(appState.contacts.where((c) => c.haloId == fresh), hasLength(1));
      expect(opened, [fresh]);
      // nothing went to them: the chat's card says how they hear of it
      expect(engineAsked.where(_sends.contains), isEmpty);
    });

    test('an old card adds as a new one does: home shows them and their '
        'chat opens', () async {
      const fresh = 'fresh-old-card';
      final them = await _phone();
      final card = buildHaloUri(fresh, 'o-fresh', them.xPub);
      expect(appState.contacts.where((c) => c.haloId == fresh), isEmpty);
      expect(await handleHaloUriAdded(card), ('', true));
      expect(appState.contacts.where((c) => c.haloId == fresh), hasLength(1));
      expect(opened, [fresh]);
      // again: the line says so, and the chat opens again
      expect(await handleHaloUriAdded(card), (
        l10n.appAlreadySaved(fresh),
        true,
      ));
      expect(opened, [fresh, fresh]);
    });

    test('in the decoy someone added stays on this phone, and their chat '
        'opens as it would anywhere', () async {
      const fresh = 'fresh-decoy-face';
      final them = await _phone();
      final decoy = ArrivalRows(HaloContainer.decoy);
      useDatabasesForTest(live, Session(decoy));
      addTearDown(() => useDatabasesForTest(live, Session(live)));
      engineAsked.clear();
      final card = haloUriV3(
        fresh,
        'o-fresh',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(card), ('', true));
      expect(opened, [fresh]);
      expect(decoy.people[fresh], containsPair('accepted', 1));
      expect(live.people.containsKey(fresh), isFalse);
      expect(engineAsked.where(_sends.contains), isEmpty);
      // again: the line says so, and the chat opens again
      expect(await handleHaloUriAdded(card), (
        l10n.appAlreadySaved(fresh),
        true,
      ));
      expect(opened, [fresh, fresh]);
    });

    test('someone who asked is taken in by their card as the accept button '
        'would', () async {
      const asker = 'asked-me-first';
      final them = await _phone();
      final ed = _rndHex(32);
      _idOf[ed] = asker;
      live.person(asker, onion: 'o-asker', xpub: them.xPub, accepted: 0);
      await live.saveMessage(asker, 'in', 'hello', msgUid: 'asked1');
      // one past what a stranger gets, held until they are let in
      await processPeerBundle(_me, await makePreKeyBundleB64(), into: them.ss);
      await live.holdCipher(
        asker,
        await them.ss.encryptTo(
          _me,
          await wrapMessage(
            'held for you',
            msgUid: 'held1',
            sender: SenderInfo(
              haloId: asker,
              edPub: ed,
              onion: 'o-asker',
              xPub: them.xPub,
            ),
          ),
        ),
      );
      engineAsked.clear();
      final card = haloUriV3(
        asker,
        'o-asker',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(card), ('', true));
      await _settle();
      expect(live.people[asker], containsPair('accepted', 1));
      // what was held is taken to be opened
      expect(live.calls, contains('heldOf:$asker'));
      // and the word that they are in went out
      expect(engineAsked.where(_sends.contains), isNotEmpty);
    });

    test(
      'an old card from someone who asked takes them in the same way',
      () async {
        const asker = 'asked-old-card';
        final them = await _phone();
        final ed = _rndHex(32);
        _idOf[ed] = asker;
        live.person(asker, onion: 'o-old', xpub: them.xPub, accepted: 0);
        await live.saveMessage(asker, 'in', 'hello', msgUid: 'oldasked1');
        // an old card carries no bundle: the session is the one their
        // first message made
        await processPeerBundle(asker, await makePreKeyBundleB64(them.ss));
        await processPeerBundle(
          _me,
          await makePreKeyBundleB64(),
          into: them.ss,
        );
        await live.holdCipher(
          asker,
          await them.ss.encryptTo(
            _me,
            await wrapMessage(
              'held for you',
              msgUid: 'oldheld1',
              sender: SenderInfo(
                haloId: asker,
                edPub: ed,
                onion: 'o-old',
                xPub: them.xPub,
              ),
            ),
          ),
        );
        engineAsked.clear();
        expect(
          await handleHaloUriAdded(buildHaloUri(asker, 'o-old', them.xPub)),
          ('', true),
        );
        await _settle();
        expect(live.people[asker], containsPair('accepted', 1));
        expect(live.calls, contains('heldOf:$asker'));
        expect(engineAsked.where(_sends.contains), isNotEmpty);
      },
    );

    test('a group member known by key alone is added, not already saved, '
        'and is sent nothing', () async {
      const member = 'met-in-group';
      final them = await _phone();
      live.person(member, onion: 'o-met', xpub: them.xPub, accepted: 0);
      await live.saveMessage(member, 'in', 'in the group', groupId: 'g1');
      engineAsked.clear();
      final card = haloUriV3(
        member,
        'o-met',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(card), ('', true));
      await _settle();
      expect(live.people[member], containsPair('accepted', 1));
      expect(live.calls, isNot(contains('heldOf:$member')));
      expect(engineAsked.where(_sends.contains), isEmpty);
    });

    test('one declined before is added again, not already saved', () async {
      const parked = 'declined-once-before';
      final them = await _phone();
      live.person(parked, onion: 'o-p', xpub: them.xPub, accepted: 0);
      live.people[parked]!['archived'] = 1;
      final card = haloUriV3(
        parked,
        'o-p',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(them.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(card), ('', true));
      await _settle();
      expect(live.people[parked], containsPair('accepted', 1));
      expect(live.people[parked], containsPair('archived', 0));
      expect(live.calls, contains('heldOf:$parked'));
    });
  });

  group('an invite from outside, held up against the people here', () {
    Future<String> card(String id, _Phone p) async => haloUriV3(
      id,
      'o-$id',
      Uri.encodeQueryComponent(await makePreKeyBundleB64(p.ss)),
      'ab' * 32,
    );

    test('a contact on their own key is one already here, by the name they '
        'have here', () async {
      live.people[_amber]!['nickname'] = 'Amber';
      expect(await linkKinOf(await card(_amber, amber)), (
        LinkKin.kept,
        'Amber',
      ));
      // the older card, by its x key
      expect(await linkKinOf(buildHaloUri(_amber, 'o', amber.xPub)), (
        LinkKin.kept,
        'Amber',
      ));
    });

    test('their words on another key are not them', () async {
      final other = await _phone();
      expect(await linkKinOf(await card(_amber, other)), (
        LinkKin.otherKey,
        _amber,
      ));
      expect(await linkKinOf(buildHaloUri(_amber, 'o', other.xPub)), (
        LinkKin.otherKey,
        _amber,
      ));
      // nor is a card whose key does not read
      expect(await linkKinOf(buildHaloUri(_amber, 'o', 'zz')), (
        LinkKin.otherKey,
        _amber,
      ));
    });

    test('words someone here is called by are someone else\'s', () async {
      live.people[_amber]!['nickname'] = 'fresh-new-words';
      final them = await _phone();
      expect(await linkKinOf(await card('fresh-new-words', them)), (
        LinkKin.lookalike,
        'fresh-new-words',
      ));
    });

    test('someone a shut vault holds is asked about as a stranger, and '
        'their words on another key read as any link that does not '
        'take', () async {
      const shut = 'shut-away-friend';
      final held = await _phone();
      await world(hiddenMembers: [RouterCard(shut, 'o-s', held.xPub)]);
      // their session is in the signal store the vault shares
      await processPeerBundle(shut, await makePreKeyBundleB64(held.ss));
      expect(app.hiddenWhileShut(shut), isTrue);
      expect(app.hiddenWhileShut(_amber), isFalse);
      final link = await card(shut, await _phone());
      expect(await linkKinOf(link, hidden: app.hiddenWhileShut), (
        LinkKin.stranger,
        shut,
      ));
      expect(await handleHaloUriAdded(link, hidden: app.hiddenWhileShut), (
        l10n.appInvalidUri,
        false,
      ));
      expect(live.people.containsKey(shut), isFalse);
      // their own card too: no everyday row, and their session stays
      final before = await signalSession.sessionStore.loadSession(
        SignalProtocolAddress(shut, 1),
      );
      final own = await card(shut, held);
      expect(await linkKinOf(own, hidden: app.hiddenWhileShut), (
        LinkKin.stranger,
        shut,
      ));
      expect(await handleHaloUriAdded(own, hidden: app.hiddenWhileShut), (
        l10n.appInvalidUri,
        false,
      ));
      // nor does any chat open for them
      expect(opened, isEmpty);
      expect(live.people.containsKey(shut), isFalse);
      expect(
        (await signalSession.sessionStore.loadSession(
          SignalProtocolAddress(shut, 1),
        )).serialize(),
        before.serialize(),
      );
      // a decoy holding them asks about them as about any of its own
      final decoy = ArrivalRows(HaloContainer.decoy);
      decoy.person(shut, onion: 'o-s', xpub: held.xPub);
      decoy.person('decoy-only-friend', onion: 'o-d', xpub: held.xPub);
      useDatabasesForTest(live, Session(decoy));
      for (final id in [shut, 'decoy-only-friend']) {
        expect(
          await linkKinOf(
            buildHaloUri(id, 'o', held.xPub),
            hidden: app.hiddenWhileShut,
          ),
          (LinkKin.kept, id),
          reason: id,
        );
      }
      useDatabasesForTest(live, Session(live));
      // someone here on another key is still said to be
      expect(
        await handleHaloUriAdded(
          await card(_amber, await _phone()),
          hidden: app.hiddenWhileShut,
        ),
        (l10n.appLinkWordsTaken(_amber), false),
      );
    });

    test('anyone else, one who asked and one blocked among them, is asked '
        'about as a stranger', () async {
      final them = await _phone();
      expect(await linkKinOf(await card('fresh-new-words', them)), (
        LinkKin.stranger,
        'fresh-new-words',
      ));
      live.person('asked-quietly-once', xpub: them.xPub, accepted: 0);
      expect(
        await linkKinOf(buildHaloUri('asked-quietly-once', 'o', them.xPub)),
        (LinkKin.stranger, 'asked-quietly-once'),
      );
      live.people[_amber]!['blocked'] = 1;
      expect(await linkKinOf(await card(_amber, amber)), (
        LinkKin.stranger,
        _amber,
      ));
    });
  });

  test('a card with the key already here reads as saved', () async {
    final link = haloUriV3(
      _amber,
      'o-amber',
      Uri.encodeQueryComponent(await makePreKeyBundleB64(amber.ss)),
      '',
    );
    expect(await handleHaloUriAdded(link), (
      l10n.appAlreadySaved(_amber),
      true,
    ));
    // their chat opens all the same
    expect(opened, [_amber]);
  });

  test('a hidden group\'s member keeps their name while the vault is '
      'shut, and no line says so', () async {
    final member = await _phone();
    final memberEd = _rndHex(32);
    _idOf[memberEd] = _hidden;
    await world(hiddenMembers: [RouterCard(_hidden, 'o-m', member.xPub)]);
    final other = await _phone();
    await app.receiveOnion([
      await _opener(other, _hidden, memberEd, _said, pow: pow),
    ]);
    await _settle();
    expect(store.inbox, isEmpty);
    expect(await hasSessionWith(_hidden), isFalse);
    final own = unboundIdOf(_keyOf(other));
    expect(live.msgs.where((m) => m['peer_id'] == own), hasLength(1));
    // and nothing on the everyday side says something hidden goes by it
    expect(
      ShieldFlag.fromRow(live.shields[own])?.lead.noticed,
      isNot(l10n.scamShieldGivesUsedName(_hidden)),
    );
    // the member's own first message is sealed for the vault
    await app.receiveOnion([
      await _opener(member, _hidden, memberEd, 'from the member'),
    ]);
    await _settle();
    expect(store.inbox, hasLength(1));
  });

  test('a first contact moved off a hidden member\'s name that was not '
      'filed lands on its own id when it comes again', () async {
    final member = await _phone();
    final memberEd = _rndHex(32);
    _idOf[memberEd] = _hidden;
    await world(hiddenMembers: [RouterCard(_hidden, 'o-m', member.xPub)]);
    // nothing of the name held here from a test before
    final addr = SignalProtocolAddress(_hidden, 1);
    await signalSession.sessionStore.deleteSession(addr);
    await signalSession.identityStore.removePeerIdentity(addr);
    final other = await _phone();
    final line = (
      peer: 'firstcontact',
      cipher: await _opener(other, _hidden, memberEd, _said, pow: pow),
    );
    live.beforeSave = () {
      live.beforeSave = null;
      throw StateError('the disk is full');
    };
    expect(await app.receiveRelay([line]), {0});
    expect(await app.receiveRelay([line]), isEmpty);
    await _settle();
    final own = unboundIdOf(_keyOf(other));
    expect(live.msgs.where((m) => m['peer_id'] == own), hasLength(1));
    expect(store.inbox, isEmpty);
  });

  group('a first contact without its proof of work', () {
    const newcomer = 'fresh-face-here';

    Future<_Phone> opener() async {
      final other = await _phone();
      final ed = _rndHex(32);
      _idOf[ed] = newcomer;
      await app.receiveOnion([await _opener(other, newcomer, ed, 'no proof')]);
      await _settle();
      return other;
    }

    test('leaves no session and no request behind', () async {
      unheard.clear();
      final other = await opener();
      expect(unheard, [other.xPub]);
      expect(await hasSessionWith(newcomer), isFalse);
      expect(live.people[newcomer], isNull);
      expect(live.msgs.where((m) => m['peer_id'] == newcomer), isEmpty);
    });

    test('and what comes after it on the same session is not kept', () async {
      final other = await opener();
      for (final text in ['second', 'third']) {
        final plain = await wrapMessage(
          text,
          msgUid: 'u${_rnd.nextInt(1 << 30)}',
          sender: SenderInfo(
            haloId: newcomer,
            edPub: 'ed',
            onion: 'o-new',
            xPub: other.xPub,
          ),
        );
        await app.receiveOnion([await other.ss.encryptTo(_me, plain)]);
        await _settle();
      }
      expect(live.msgs.where((m) => m['peer_id'] == newcomer), isEmpty);
      expect(await hasSessionWith(newcomer), isFalse);
    });

    test('leaves a request row it did not make', () async {
      // a row with no key yet, as an introduction leaves one
      live.person(newcomer, accepted: 0, onion: 'o-was');
      await opener();
      expect(live.people[newcomer], containsPair('accepted', 0));
      expect(await hasSessionWith(newcomer), isFalse);
    });
  });

  group('words nobody checked', () {
    // each test its own words: the signal store outlives a test
    const ends = [
      'ash',
      'bay',
      'cove',
      'dune',
      'elm',
      'fern',
      'glen',
      'hill',
      'isle',
      'jade',
      'kelp',
      'lake',
      'moor',
      'nook',
      'oak',
      'pond',
      'quay',
      'reed',
    ];
    var round = -1;
    late String words;
    late _Phone mallory;
    late _Phone alice;
    late String aliceEd;
    final asked = <(String, bool)>[];
    var answer = true;

    setUp(() async {
      words = 'calm-river-${ends[++round]}';
      mallory = await _phone();
      alice = await _phone();
      aliceEd = _rndHex(32);
      _idOf[aliceEd] = words;
      asked.clear();
      dropped.clear();
      answer = true;
      final was = askTakeName;
      askTakeName =
          (id, {required chat, deleted = false, tombed = false}) async {
            asked.add((id, chat));
            return answer;
          };
      addTearDown(() => askTakeName = was);
    });

    // a stranger's request under alice's words
    Future<void> squat() async {
      final ed = _rndHex(32);
      _idOf[ed] = words;
      await app.receiveOnion([
        await _opener(mallory, words, ed, _said, pow: pow),
      ]);
      await _settle();
      expect(live.people[words], containsPair('accepted', 0));
      expect(nameCheckOf(live.people[words]), 3);
    }

    Future<String> link(_Phone p) async => haloUriV3(
      words,
      'o-real',
      Uri.encodeQueryComponent(await makePreKeyBundleB64(p.ss)),
      'ab' * 32,
    );

    Future<void> sessionIsWith(_Phone who, _Phone not) async {
      final next = await signalSession.encryptTo(words, 'for the one kept');
      expect(await _reads(not.ss, next), isNull);
      expect(await _reads(who.ss, next), 'for the one kept');
    }

    test('a request\'s words go to the link the person chooses', () async {
      await squat();
      expect(await linkKinOf(await link(alice)), (LinkKin.claimed, words));
      expect(await handleHaloUriAdded(await link(alice)), ('', true));
      expect(asked, [(words, false)]);
      expect(live.people[words], containsPair('accepted', 1));
      // the chat asks for the safety number, and the words are not the
      // request's any more
      expect(nameCheckOf(live.people[words]), kNameAsk);
      expect(live.msgs.where((m) => m['peer_id'] == words), isEmpty);
      expect(dropped, contains(mallory.xPub));
      await sessionIsWith(alice, mallory);
    });

    test('kept, the request stays as it was', () async {
      await squat();
      answer = false;
      expect(await handleHaloUriAdded(await link(alice)), ('', false));
      expect(asked, [(words, false)]);
      expect(live.people[words], containsPair('accepted', 0));
      expect(live.msgs.where((m) => m['peer_id'] == words), hasLength(1));
      await sessionIsWith(mallory, alice);
    });

    test('a request taken in is asked about with its chat', () async {
      await squat();
      live.people[words]!['accepted'] = 1;
      expect(await handleHaloUriAdded(await link(alice)), ('', true));
      expect(asked, [(words, true)]);
      expect(live.msgs.where((m) => m['peer_id'] == words), isEmpty);
      await sessionIsWith(alice, mallory);
    });

    test('a verified name is never replaced, and nothing is asked', () async {
      await squat();
      live.people[words]!['verified'] = 1;
      expect(await linkKinOf(await link(alice)), (LinkKin.verified, words));
      expect(await handleHaloUriAdded(await link(alice)), (
        l10n.appLinkWordsVerified(words),
        false,
      ));
      expect(asked, isEmpty);
      await sessionIsWith(mallory, alice);
    });

    test('words added by a scan stay, and nothing is asked', () async {
      expect(await handleHaloUriAdded(await link(mallory), scanned: true), (
        '',
        true,
      ));
      expect(nameCheckOf(live.people[words]), 0);
      expect(await linkKinOf(await link(alice)), (LinkKin.otherKey, words));
      expect(await handleHaloUriAdded(await link(alice)), (
        l10n.appLinkWordsTaken(words),
        false,
      ));
      expect(asked, isEmpty);
    });

    test('a deleted chat keeps no name: a link takes it unasked', () async {
      await squat();
      await app.deleteConversation(words);
      expect(await linkKinOf(await link(alice)), (LinkKin.stranger, words));
      expect(await handleHaloUriAdded(await link(alice)), ('', true));
      expect(asked, isEmpty);
      expect(live.people[words], containsPair('accepted', 1));
      await sessionIsWith(alice, mallory);
    });

    test('a deleted chat keeps no name: the real one writing lands under '
        'their words', () async {
      await squat();
      await app.deleteConversation(words);
      await app.receiveOnion([
        await _opener(alice, words, aliceEd, _said, pow: pow),
      ]);
      await _settle();
      expect(live.people.containsKey(unboundIdOf(_keyOf(alice))), isFalse);
      expect(
        [
          for (final m in live.msgs)
            if (m['peer_id'] == words) m['plaintext'],
        ],
        [_said],
      );
      // a request again, its words not checked
      expect(live.people[words], containsPair('accepted', 0));
      expect(nameCheckOf(live.people[words]), 3);
      await sessionIsWith(alice, mallory);
    });

    test('someone a group holds keeps their words: no link takes their '
        'seat', () async {
      // a card from a group's member list
      live.group('g-seat', [words]);
      await live.upsertContactStub(words, 'o-m', mallory.xPub);
      expect(nameCheckOf(live.people[words]), 3);
      expect(await linkKinOf(await link(alice)), (LinkKin.otherKey, words));
      expect(await handleHaloUriAdded(await link(alice)), (
        l10n.appLinkWordsTaken(words),
        false,
      ));
      expect(asked, isEmpty);
      expect(live.people[words], containsPair('xpub', mallory.xPub));
      expect(live.members['g-seat'], [words]);
    });

    test('a deleted chat whose person sits in a group keeps its words, '
        'for a link and for a first contact', () async {
      await squat();
      await app.deleteConversation(words);
      live.group('g-seat2', [words]);
      expect(await handleHaloUriAdded(await link(alice)), (
        l10n.appLinkWordsTaken(words),
        false,
      ));
      await app.receiveOnion([
        await _opener(alice, words, aliceEd, _said, pow: pow),
      ]);
      await _settle();
      expect(live.people.containsKey(unboundIdOf(_keyOf(alice))), isTrue);
      expect(live.people[words], containsPair('xpub', mallory.xPub));
      expect(dropped, isEmpty);
    });

    test('a card no session can be built on lets nothing go', () async {
      await squat();
      final j =
          jsonDecode(
                utf8.decode(base64Decode(await makePreKeyBundleB64(alice.ss))),
              )
              as Map<String, dynamic>;
      j['signedPreKeySignature'] = base64Encode(List.filled(64, 1));
      final bad = haloUriV3(
        words,
        'o-real',
        Uri.encodeQueryComponent(base64Encode(utf8.encode(jsonEncode(j)))),
        'ab' * 32,
      );
      final (line, added) = await handleHaloUriAdded(bad);
      expect(added, isFalse);
      expect(line, isNot(''));
      expect(asked, isEmpty);
      expect(live.people[words], containsPair('accepted', 0));
      expect(live.people[words], containsPair('xpub', mallory.xPub));
      expect(live.msgs.where((m) => m['peer_id'] == words), hasLength(1));
      await sessionIsWith(mallory, alice);
    });

    test('what changed while the question was up is read again before '
        'anything goes', () async {
      await squat();
      askTakeName =
          (id, {required chat, deleted = false, tombed = false}) async {
            asked.add((id, chat));
            // verified meanwhile, from their chat
            live.people[words]!['verified'] = 1;
            return true;
          };
      expect(await handleHaloUriAdded(await link(alice)), (
        l10n.appLinkWordsVerified(words),
        false,
      ));
      expect(asked, hasLength(1));
      expect(live.people[words], containsPair('xpub', mallory.xPub));
      await sessionIsWith(mallory, alice);
    });

    test(
      'a deleted chat\'s words go only to an opener the gate takes',
      () async {
        await squat();
        await app.deleteConversation(words);
        // no proof of work: dropped at the gate, so nothing is let go for it
        await app.receiveOnion([await _opener(alice, words, aliceEd, _said)]);
        await _settle();
        expect(live.people[words], containsPair('xpub', mallory.xPub));
        expect(dropped, isEmpty);
        expect(live.msgs.where((m) => m['peer_id'] == words), isEmpty);
      },
    );

    test('in the decoy nothing is let go, and the everyday side is not '
        'touched', () async {
      await squat();
      final decoy = ArrivalRows(HaloContainer.decoy);
      decoy.person(words, xpub: mallory.xPub, accepted: 0);
      decoy.people[words]!['name_check'] = 3;
      useDatabasesForTest(live, Session(decoy));
      addTearDown(() => useDatabasesForTest(live, Session(live)));
      expect(await linkKinOf(await link(alice)), (LinkKin.otherKey, words));
      expect(await handleHaloUriAdded(await link(alice)), (
        l10n.appLinkWordsTaken(words),
        false,
      ));
      expect(asked, isEmpty);
      expect(decoy.people[words], containsPair('xpub', mallory.xPub));
      expect(live.people[words], containsPair('accepted', 0));
      expect(dropped, isEmpty);
      await sessionIsWith(mallory, alice);
    });

    test('a scan settles a request\'s words, any other add asks for the '
        'safety number', () async {
      await squat();
      expect(await handleHaloUriAdded(await link(mallory)), ('', true));
      // still the words the request gave, and the chat asks
      expect(nameCheckOf(live.people[words]), 3);
      expect(await handleHaloUriAdded(await link(mallory), scanned: true), (
        l10n.appAlreadySaved(words),
        true,
      ));
      expect(nameCheckOf(live.people[words]), 0);
      // someone new by a link: the chat asks, nothing more
      const fresh = 'brand-new-words';
      final link2 = haloUriV3(
        fresh,
        'o',
        Uri.encodeQueryComponent(await makePreKeyBundleB64(alice.ss)),
        'ab' * 32,
      );
      expect(await handleHaloUriAdded(link2), ('', true));
      expect(nameCheckOf(live.people[fresh]), kNameAsk);
    });
  });

  // the safety number they read out was another: the contact goes, all of
  // it, and the key it ran on is blocked. the words go back to no one, so
  // the real person comes in under them as anyone does
  group('this isn\'t them', () {
    var round = 0;
    late String words;
    late _Phone mallory;
    late _Phone alice;
    late String aliceEd;
    final asked = <(String, bool, bool, bool)>[];

    setUp(() async {
      words =
          'not-them-${String.fromCharCode(97 + round ~/ 26)}'
          '${String.fromCharCode(97 + round++ % 26)}';
      mallory = await _phone();
      alice = await _phone();
      aliceEd = _rndHex(32);
      _idOf[aliceEd] = words;
      unheard.clear();
      asked.clear();
      final was = askTakeName;
      askTakeName =
          (id, {required chat, deleted = false, tombed = false}) async {
            asked.add((id, chat, deleted, tombed));
            return true;
          };
      addTearDown(() => askTakeName = was);
    });

    Future<String> link(_Phone p, {String? id}) async => haloUriV3(
      id ?? words,
      'o-${p.xPub.substring(0, 8)}',
      Uri.encodeQueryComponent(await makePreKeyBundleB64(p.ss)),
      'ab' * 32,
    );

    // the fake's link, under the real one's words, added as any link is
    Future<void> faked({bool scanned = false}) async {
      expect(await handleHaloUriAdded(await link(mallory), scanned: scanned), (
        '',
        true,
      ));
      expect(live.people[words], containsPair('accepted', 1));
      expect(await signalSession.peerXPubHex(words), mallory.xPub);
    }

    Future<void> sessionIsWith(_Phone who, _Phone not) async {
      final next = await signalSession.encryptTo(words, 'for the one kept');
      expect(await _reads(not.ss, next), isNull);
      expect(await _reads(who.ss, next), 'for the one kept');
    }

    // a first message under the words, with the real one's ed key, which
    // anyone can copy
    Future<void> writes(_Phone p, {GroupControl? gc, String? group}) async {
      await processPeerBundle(_me, await makePreKeyBundleB64(), into: p.ss);
      final plain = await wrapMessage(
        _said,
        msgUid: 'u${_rnd.nextInt(1 << 30)}',
        powNonce: pow,
        powBitsUsed: powBits,
        groupId: group,
        groupControl: gc,
        sender: SenderInfo(
          haloId: words,
          edPub: aliceEd,
          onion: 'o-${p.xPub.substring(0, 8)}',
          xPub: p.xPub,
        ),
      );
      await app.receiveOnion([await p.ss.encryptTo(_me, plain)]);
      await _settle();
    }

    // a group control from amber, a contact here
    Future<void> amberSays(GroupControl gc, {required String group}) async {
      await processPeerBundle(_me, await makePreKeyBundleB64(), into: amber.ss);
      final plain = await wrapMessage(
        '',
        msgUid: 'g${_rnd.nextInt(1 << 30)}',
        groupId: group,
        groupControl: gc,
        sender: SenderInfo(
          haloId: _amber,
          edPub: amberEd,
          onion: 'o-amber',
          xPub: amber.xPub,
        ),
      );
      await app.receiveOnion([await amber.ss.encryptTo(_me, plain)]);
      await _settle();
    }

    List<Object?> textsOf(String id) => [
      for (final m in live.msgs)
        if (m['peer_id'] == id) m['plaintext'],
    ];

    // filed on an id of its own, with the line saying the name it gave
    void filedOnItsOwn(_Phone p) {
      final own = unboundIdOf(_keyOf(p));
      expect(live.people[own], containsPair('accepted', 0));
      expect(textsOf(own), [_said]);
      expect(
        ShieldFlag.fromRow(live.shields[own])?.lead.noticed,
        l10n.scamShieldGivesUsedName(words),
      );
    }

    test('a fake added by a link and deleted: the real link takes the '
        'words after one question', () async {
      await faked();
      await app.deleteConversation(words);
      expect(await linkKinOf(await link(alice)), (LinkKin.claimed, words));
      expect(await handleHaloUriAdded(await link(alice)), ('', true));
      expect(asked, [(words, false, true, false)]);
      expect(live.people[words], containsPair('accepted', 1));
      expect(nameCheckOf(live.people[words]), kNameAsk);
      await sessionIsWith(alice, mallory);
    });

    test('a fake added by a link and deleted: kept, nothing changes', () async {
      await faked();
      await app.deleteConversation(words);
      askTakeName =
          (id, {required chat, deleted = false, tombed = false}) async => false;
      expect(await handleHaloUriAdded(await link(alice)), ('', false));
      expect(await signalSession.peerXPubHex(words), mallory.xPub);
    });

    test('R1 a friend added by a link and deleted keeps the words against '
        'someone writing first with them', () async {
      expect(await handleHaloUriAdded(await link(alice)), ('', true));
      await app.deleteConversation(words);
      await writes(mallory);
      expect(await signalSession.peerXPubHex(words), alice.xPub);
      expect(textsOf(words), isEmpty);
      filedOnItsOwn(mallory);
    });

    test('R1b the same for a friend added by a scan', () async {
      expect(await handleHaloUriAdded(await link(alice), scanned: true), (
        '',
        true,
      ));
      await app.deleteConversation(words);
      await writes(mallory);
      expect(await signalSession.peerXPubHex(words), alice.xPub);
      filedOnItsOwn(mallory);
    });

    test('it takes everything of theirs and blocks the key', () async {
      await faked();
      expect(await app.notThem(words, mallory.xPub), isTrue);
      expect(live.people.containsKey(words), isFalse);
      expect(await hasSessionWith(words), isFalse);
      expect(await signalSession.peerXPubHex(words), isNull);
      expect(live.blockedKeyAt.keys, [mallory.xPub]);
      expect(live.tombedNames, {words});
      expect(unheard, contains(mallory.xPub));
    });

    test('REV-D after it the real link adds them under their words after a '
        'question of its own, and the chat asks for the number', () async {
      await faked(scanned: true);
      await app.notThem(words, mallory.xPub);
      expect(await linkKinOf(await link(alice)), (LinkKin.claimed, words));
      expect(await handleHaloUriAdded(await link(alice), scanned: true), (
        '',
        true,
      ));
      expect(asked, [(words, false, false, true)]);
      expect(live.people[words], containsPair('accepted', 1));
      expect(nameCheckOf(live.people[words]), kNameAsk);
      expect(live.tombedNames, isEmpty);
      await sessionIsWith(alice, mallory);
    });

    test(
      'R2 after it, someone writing first under the words is filed on '
      'an id of their own, the real one too, until the person adds them',
      () async {
        await faked();
        await app.notThem(words, mallory.xPub);
        final m2 = await _phone();
        await writes(m2);
        expect(live.people.containsKey(words), isFalse);
        expect(await signalSession.peerXPubHex(words), isNull);
        filedOnItsOwn(m2);
        await writes(alice);
        filedOnItsOwn(alice);
        expect(live.people.containsKey(words), isFalse);
      },
    );

    test('after it an introduction or a group list under the words seats '
        'them on an id of their own', () async {
      await faked();
      await app.notThem(words, mallory.xPub);
      final m2 = await _phone();
      final own = unboundIdOf(_keyOf(m2));
      live.group('g-after', [_me, _amber], admin: _amber);
      await amberSays(
        GroupControl(
          type: 'add',
          members: [words],
          participants: [
            {'h': words, 'o': 'o-m2', 'x': m2.xPub},
          ],
        ),
        group: 'g-after',
      );
      expect(live.members['g-after'], contains(own));
      expect(live.members['g-after'], isNot(contains(words)));
      expect(live.people.containsKey(words), isFalse);
      expect(live.people[own], containsPair('xpub', m2.xPub));
    });

    test('R3 a group the fake ran has no admin after: nothing anyone sends '
        'changes it', () async {
      await faked();
      const gid = 'grev00000001';
      live.group(gid, [words, _me, _amber], admin: words);
      expect(await app.notThem(words, mallory.xPub), isTrue);
      expect(live.groupRows[gid]?['admin_id'], kAdminGone);
      expect(live.members[gid], isNot(contains(words)));
      final m2 = await _phone();
      await writes(
        m2,
        group: gid,
        gc: const GroupControl(type: 'rename', name: 'taken over'),
      );
      expect(live.groupRows[gid]?['name'], isNot('taken over'));
      // and the words added back by the person still run nothing
      expect(await handleHaloUriAdded(await link(alice)), ('', true));
      await writes(
        alice,
        group: gid,
        gc: const GroupControl(type: 'rename', name: 'taken over'),
      );
      expect(live.groupRows[gid]?['name'], isNot('taken over'));
      expect(live.groupRows[gid]?['admin_id'], kAdminGone);
    });

    test('the key stays out on every way in, under any words', () async {
      await faked();
      await app.notThem(words, mallory.xPub);
      // a link or a code under their words or others, an old card
      for (final l in [
        await link(mallory),
        await link(mallory, id: 'other-mask-words'),
        buildHaloUri('old-card-words', 'o', mallory.xPub),
      ]) {
        expect(await handleHaloUriAdded(l), (l10n.appKeyBlocked, false));
      }
      // a first message under their words or new ones
      for (final says in [words, 'fresh-mask-words']) {
        final ed = _rndHex(32);
        _idOf[ed] = says;
        await app.receiveOnion([
          await _opener(mallory, says, ed, _said, pow: pow),
        ]);
        await _settle();
        expect(live.people.containsKey(says), isFalse);
        expect(textsOf(says), isEmpty);
      }
      final own = unboundIdOf(_keyOf(mallory));
      expect(live.people.containsKey(own), isFalse);
      expect(await hasSessionWith(words), isFalse);
      expect(await hasSessionWith(own), isFalse);
      expect(live.people.containsKey('other-mask-words'), isFalse);
      expect(live.people.containsKey('old-card-words'), isFalse);
    });

    test('a key that moved meanwhile lets nothing go', () async {
      await faked();
      expect(await app.notThem(words, 'cd' * 32), isFalse);
      expect(live.people[words], containsPair('accepted', 1));
      expect(await signalSession.peerXPubHex(words), mallory.xPub);
      expect(live.blockedKeyAt, isEmpty);
      expect(live.tombedNames, isEmpty);
    });

    test('in the decoy only the decoy\'s row goes, its key blocked there, '
        'and the everyday side is not touched', () async {
      await faked();
      final decoy = ArrivalRows(HaloContainer.decoy);
      decoy.person(words, xpub: mallory.xPub);
      useDatabasesForTest(live, Session(decoy));
      addTearDown(() => useDatabasesForTest(live, Session(live)));
      expect(await app.notThem(words, mallory.xPub), isTrue);
      expect(decoy.people.containsKey(words), isFalse);
      expect(decoy.blockedKeyAt.keys, [mallory.xPub]);
      expect(decoy.tombedNames, {words});
      expect(live.people[words], containsPair('accepted', 1));
      expect(live.blockedKeyAt, isEmpty);
      expect(live.tombedNames, isEmpty);
      expect(await signalSession.peerXPubHex(words), mallory.xPub);
      expect(unheard, isEmpty);
      expect(
        await handleHaloUriAdded(
          buildHaloUri('other-mask-two', 'o', mallory.xPub),
        ),
        (l10n.appKeyBlocked, false),
      );
    });

    // a vault holding the fake, open, with a group of its own naming them
    Future<(ArrivalRows, VaultRouter)> hiddenFake() async {
      final vault = _OpenCount();
      vault.person(words, onion: 'o-h', xpub: mallory.xPub);
      vault.group('g-hidden', [_me, words], admin: words);
      await processPeerBundle(words, await makePreKeyBundleB64(mallory.ss));
      final store = ArrivalStore();
      await store.putHidden(
        words,
        kHiddenPeer,
        peerCard(RouterCard(words, 'o-h', mallory.xPub, backPaired: true)),
        1,
      );
      await store.putMeta('pub', 'pub-A');
      final router = VaultRouter(store, ArrivalSeal());
      await router.load();
      app = AppState(io: const _Io(), router: router)..myId = _me;
      useDatabasesForTest(live, await Session.withVault(live, vault));
      addTearDown(() => useDatabasesForTest(live, Session(live)));
      return (vault, router);
    }

    test('a hidden chat goes from the open vault alone, its key blocked '
        'there, and its seat on the everyday side goes', () async {
      // an everyday group knows them by key alone
      live.group('g-day', [_me, _amber, words], admin: _amber);
      await live.upsertContactStub(words, 'o-h', mallory.xPub);
      final (vault, router) = await hiddenFake();
      expect(session.isHidden(words), isTrue);
      expect(await app.notThem(words, mallory.xPub), isTrue);
      expect(vault.people.containsKey(words), isFalse);
      expect(vault.blockedKeyAt.keys, [mallory.xPub]);
      expect(vault.groupRows['g-hidden']?['admin_id'], kAdminGone);
      expect(live.blockedKeyAt, isEmpty);
      expect(live.people.containsKey(words), isFalse);
      expect(live.members['g-day'], isNot(contains(words)));
      expect(router.keeps(words), isFalse);
      expect(router.keyBlocked(mallory.xPub), isTrue);
      expect(router.tombed(words), isTrue);
      expect(session.isHidden(words), isFalse);
      expect(await hasSessionWith(words), isFalse);
      // the real one's link adds them as anyone new, and takes the words
      expect(await handleHaloUriAdded(await link(alice), app: app), ('', true));
      expect(live.people[words], containsPair('accepted', 1));
      expect(vault.tombedNames, isEmpty);
      await sessionIsWith(alice, mallory);
    });

    test('with the vault shut its block and its words still hold, and the '
        'everyday side says nothing of it', () async {
      final (_, router) = await hiddenFake();
      await app.notThem(words, mallory.xPub);
      // the vault shuts
      useDatabasesForTest(live, Session(live));
      expect(
        await handleHaloUriAdded(
          await link(mallory, id: 'other-mask-three'),
          app: app,
        ),
        (l10n.appInvalidUri, false),
      );
      final ed = _rndHex(32);
      _idOf[ed] = 'fresh-mask-two';
      await app.receiveOnion([
        await _opener(mallory, 'fresh-mask-two', ed, _said, pow: pow),
      ]);
      await _settle();
      expect(live.people.containsKey('fresh-mask-two'), isFalse);
      expect(live.people.containsKey(unboundIdOf(_keyOf(mallory))), isFalse);
      // the real one writing first is filed on their own id, and nothing
      // names the vault's words to the everyday side
      await writes(alice);
      final own = unboundIdOf(_keyOf(alice));
      expect(live.people[own], containsPair('accepted', 0));
      expect(textsOf(own), [_said]);
      expect(
        ShieldFlag.fromRow(live.shields[own])?.lead.noticed,
        isNot(l10n.scamShieldGivesUsedName(words)),
      );
      expect(router.keyBlocked(mallory.xPub), isTrue);
    });

    test('with the vault open, the real one writing first is filed on '
        'their own id, and nothing after it shuts names the vault\'s '
        'words', () async {
      await hiddenFake();
      await writes(alice);
      final own = unboundIdOf(_keyOf(alice));
      expect(live.people[own], containsPair('accepted', 0));
      expect(textsOf(own), [_said]);
      // the vault shuts
      useDatabasesForTest(live, Session(live));
      expect(
        ShieldFlag.fromRow(live.shields[own])?.lead.noticed,
        isNot(l10n.scamShieldGivesUsedName(words)),
      );
      expect('${live.shields[own]}', isNot(contains(words)));
    });

    test('an everyday contact\'s seat in the vault\'s groups goes now with '
        'the vault open, and as it next opens when shut', () async {
      for (final open in [true, false]) {
        await faked();
        final vault = ArrivalRows(HaloContainer.vault);
        vault.group('g-v', [_me, words], admin: _me);
        vault.person(words, xpub: mallory.xPub, accepted: 0);
        final store = ArrivalStore();
        await store.putMeta('pub', 'pub-A');
        final router = VaultRouter(store, ArrivalSeal());
        await router.load();
        app = AppState(io: const _Io(), router: router)..myId = _me;
        useDatabasesForTest(
          live,
          open ? await Session.withVault(live, vault) : Session(live),
        );
        addTearDown(() => useDatabasesForTest(live, Session(live)));
        expect(await app.notThem(words, mallory.xPub), isTrue);
        if (open) {
          expect(vault.members['g-v'], [_me]);
          expect(await router.seatsGone(), isEmpty);
        } else {
          expect(vault.members['g-v'], [_me, words]);
          expect(await router.seatsGone(), [(words, mallory.xPub)]);
          await app.seatsGoneIntoForTest(vault);
          expect(vault.members['g-v'], [_me]);
          expect(await router.seatsGone(), isEmpty);
        }
        expect(vault.people.containsKey(words), isFalse);
        // the next round, under new words
        words = '${words}z';
        mallory = await _phone();
        _idOf[aliceEd] = words;
      }
    });

    test('the router keeps the vault\'s marks across a start, and they go '
        'once its rows were handed over', () async {
      final store = ArrivalStore();
      await store.putMeta('pub', 'pub-A');
      final r = VaultRouter(store, ArrivalSeal());
      await r.load();
      await r.markKey('AB' * 32, on: true);
      await r.markTomb(words, on: true);
      await r.queueSeatGone(words, 'ab' * 32);
      final again = VaultRouter(store, ArrivalSeal());
      await again.load();
      expect(again.keyBlocked('ab' * 32), isTrue);
      expect(again.tombed(words), isTrue);
      expect(again.keeps(words), isFalse);
      expect(await again.seatsGone(), [(words, 'ab' * 32)]);
      await again.markTomb(words, on: false);
      expect(again.tombed(words), isFalse);
      await again.retire();
      expect(again.keyBlocked('ab' * 32), isFalse);
      expect(await again.seatsGone(), isEmpty);
    });

    test('REV-D kept at the question: nothing is added, the words stay let '
        'go', () async {
      await faked();
      await app.notThem(words, mallory.xPub);
      askTakeName =
          (id, {required chat, deleted = false, tombed = false}) async => false;
      expect(await handleHaloUriAdded(await link(alice)), ('', false));
      expect(live.people.containsKey(words), isFalse);
      expect(live.tombedNames, {words});
    });

    test('REV-E a link that fails to add leaves the words let go', () async {
      await faked();
      await app.notThem(words, mallory.xPub);
      final bogus = base64Encode(
        utf8.encode(
          jsonEncode({
            'identityKey': base64Encode([5, for (var i = 0; i < 32; i++) 7]),
          }),
        ),
      );
      final l = haloUriV3(
        words,
        'o-bogus',
        Uri.encodeQueryComponent(bogus),
        'ab' * 32,
      );
      final (_, added) = await handleHaloUriAdded(l);
      expect(added, isFalse);
      expect(live.tombedNames, {words});
      expect(live.people.containsKey(words), isFalse);
      final m2 = await _phone();
      await writes(m2);
      expect(live.people.containsKey(words), isFalse);
      filedOnItsOwn(m2);
    });

    test('REV-A with the decoy on screen, someone writing first under words '
        'the everyday side let go is filed on an id of their own', () async {
      await faked();
      expect(await app.notThem(words, mallory.xPub), isTrue);
      final decoy = ArrivalRows(HaloContainer.decoy);
      useDatabasesForTest(live, Session(decoy));
      addTearDown(() => useDatabasesForTest(live, Session(live)));
      final m2 = await _phone();
      await writes(m2);
      expect(live.people.containsKey(words), isFalse);
      expect(await signalSession.peerXPubHex(words), isNull);
      filedOnItsOwn(m2);
      expect(live.tombedNames, {words});
    });

    test('REV-A2 with the decoy on screen, a group list under the words '
        'seats them on an id of their own', () async {
      await faked();
      await app.notThem(words, mallory.xPub);
      live.group('g-after', [_me, _amber], admin: _amber);
      final decoy = ArrivalRows(HaloContainer.decoy);
      useDatabasesForTest(live, Session(decoy));
      addTearDown(() => useDatabasesForTest(live, Session(live)));
      final m2 = await _phone();
      await amberSays(
        GroupControl(
          type: 'add',
          members: [words],
          participants: [
            {'h': words, 'o': 'o-m2', 'x': m2.xPub},
          ],
        ),
        group: 'g-after',
      );
      expect(live.members['g-after'], contains(unboundIdOf(_keyOf(m2))));
      expect(live.members['g-after'], isNot(contains(words)));
      expect(live.people.containsKey(words), isFalse);
    });

    test('REV-B a vault removed hands its blocks and let-go words to the '
        'everyday side', () async {
      final (vault, router) = await hiddenFake();
      await app.notThem(words, mallory.xPub);
      await live.takeBlocks(await vault.blockedKeys(), await vault.tombs());
      await router.retire();
      useDatabasesForTest(live, Session(live));
      expect(live.blockedKeyAt.keys, [mallory.xPub]);
      expect(live.tombedNames, {words});
      final m2 = await _phone();
      await writes(m2);
      filedOnItsOwn(m2);
      final ed = _rndHex(32);
      _idOf[ed] = 'fresh-mask-four';
      await app.receiveOnion([
        await _opener(mallory, 'fresh-mask-four', ed, _said, pow: pow),
      ]);
      await _settle();
      expect(live.people.containsKey('fresh-mask-four'), isFalse);
    });

    test('REV-C a remove on the everyday side leaves a seat in the vault '
        'held under the same words on another key', () async {
      await faked();
      final vault = ArrivalRows(HaloContainer.vault);
      vault.group('g-v', [_me, words], admin: _me);
      vault.person(words, xpub: alice.xPub, accepted: 0);
      final store = ArrivalStore();
      await store.putMeta('pub', 'pub-A');
      final router = VaultRouter(store, ArrivalSeal());
      await router.load();
      app = AppState(io: const _Io(), router: router)..myId = _me;
      useDatabasesForTest(live, await Session.withVault(live, vault));
      addTearDown(() => useDatabasesForTest(live, Session(live)));
      expect(await app.notThem(words, mallory.xPub), isTrue);
      expect(vault.members['g-v'], [_me, words]);
      expect(vault.people[words], containsPair('xpub', alice.xPub));
    });

    test(
      'the vault\'s marks are read again from its rows as it opens',
      () async {
        final (vault, router) = await hiddenFake();
        await app.notThem(words, mallory.xPub);
        // marks gone astray: a stray one, and the vault's own missing
        await router.markKey('cd' * 32, on: true);
        await router.markTomb(words, on: false);
        await app.remarkForTest(vault);
        expect(router.keyBlocked(mallory.xPub), isTrue);
        expect(router.keyBlocked('cd' * 32), isFalse);
        expect(router.tombed(words), isTrue);
      },
    );

    test('a tidy that failed waits before it is tried again', () async {
      final bad = _BadDb();
      await app.tidyForTest(bad, now: 0);
      expect(bad.opens, 1);
      await app.tidyForTest(bad, now: 60000);
      expect(bad.opens, 1);
      await app.tidyForTest(bad, now: 11 * 60000);
      expect(bad.opens, 2);
      // twice as long the next time
      await app.tidyForTest(bad, now: 22 * 60000);
      expect(bad.opens, 2);
      await app.tidyForTest(bad, now: 32 * 60000);
      expect(bad.opens, 3);
    });

    test('R3-1 with the vault shut, a link under words it let go is added '
        'as anyone\'s, and its mark comes off', () async {
      final (vault, router) = await hiddenFake();
      expect(await app.notThem(words, mallory.xPub), isTrue);
      useDatabasesForTest(live, Session(live));
      expect(await linkKinOf(await link(alice), app: app), (
        LinkKin.stranger,
        words,
      ));
      expect(await handleHaloUriAdded(await link(alice), app: app), ('', true));
      expect(asked, isEmpty);
      expect(live.people[words], containsPair('accepted', 1));
      expect(router.tombed(words), isFalse);
      expect(await router.tombsGone(), [words]);
      // R3-2 the vault opens again: its own tomb goes before its marks are
      // read, so the mark does not come back
      expect(vault.tombedNames, {words});
      await app.remarkForTest(vault);
      expect(vault.tombedNames, isEmpty);
      expect(router.tombed(words), isFalse);
      expect(await router.tombsGone(), isEmpty);
      // and the real one, their chat deleted, still writes under the words
      await app.deleteConversation(words);
      await writes(alice);
      expect(live.people[words], containsPair('xpub', alice.xPub));
      expect(live.people.containsKey(unboundIdOf(_keyOf(alice))), isFalse);
    });

    test('R3-3 an everyday unblock with the vault shut leaves the vault\'s '
        'block, and nothing names it', () async {
      final (_, router) = await hiddenFake();
      await app.notThem(words, mallory.xPub);
      await live.takeBlocks([(x: mallory.xPub, at: 1)], const []);
      useDatabasesForTest(live, Session(live));
      expect([for (final k in await app.blockedKeys()) k.x], [mallory.xPub]);
      await app.unblockKey(mallory.xPub);
      expect(await app.blockedKeys(), isEmpty);
      expect(router.keyBlocked(mallory.xPub), isTrue);
    });

    test('after a replace the old vault\'s block holds unseen: nothing listed, '
        'no everyday row, a first message dropped, a link turned away as '
        'any that does not take', () async {
      final (_, router) = await hiddenFake();
      await app.notThem(words, mallory.xPub);
      useDatabasesForTest(live, Session(live));
      await router.forget();
      expect(await app.blockedKeys(), isEmpty);
      expect(live.blockedKeyAt, isEmpty);
      expect(live.tombedNames, isEmpty);
      final ed = _rndHex(32);
      _idOf[ed] = 'fresh-mask-five';
      await app.receiveOnion([
        await _opener(mallory, 'fresh-mask-five', ed, _said, pow: pow),
      ]);
      await _settle();
      expect(live.people.containsKey('fresh-mask-five'), isFalse);
      expect(live.people.containsKey(unboundIdOf(_keyOf(mallory))), isFalse);
      expect(
        await handleHaloUriAdded(
          await link(mallory, id: 'other-mask-five'),
          app: app,
        ),
        (l10n.appInvalidUri, false),
      );
      // a link under the words is added as anyone's, no sheet of its own
      expect(await linkKinOf(await link(alice), app: app), (
        LinkKin.stranger,
        words,
      ));
    });

    test('R3-5 a lock with a slow vault: the next vault open does not wait '
        'on a tidy', () async {
      final slow = _SlowDb();
      final store = ArrivalStore();
      await store.putMeta('pub', 'pub-A');
      final router = VaultRouter(store, ArrivalSeal());
      await router.load();
      app = AppState(io: const _Io(), router: router)..myId = _me;
      useDatabasesForTest(live, await Session.withVault(live, slow));
      addTearDown(() => useDatabasesForTest(live, Session(live)));
      app.lockingUp();
      final sw = Stopwatch()..start();
      try {
        await app.settleVault(ArrivalRows(HaloContainer.vault));
      } catch (_) {
        // the stand-in vault has no mover: only how long it waited counts
      }
      expect(sw.elapsedMilliseconds, lessThan(1500));
      expect(slow.opened, isFalse);
    });

    test('R4-1 a replaced vault\'s let-go words are never asked about in the '
        'new vault', () async {
      final (_, router) = await hiddenFake();
      await app.notThem(words, mallory.xPub);
      useDatabasesForTest(live, Session(live));
      await router.forget();
      await router.start('pub-B');
      final v2 = ArrivalRows(HaloContainer.vault);
      useDatabasesForTest(live, await Session.withVault(live, v2));
      await app.remarkForTest(v2);
      expect(await linkKinOf(await link(alice), app: app), (
        LinkKin.stranger,
        words,
      ));
      expect(await handleHaloUriAdded(await link(alice), app: app), ('', true));
      expect(asked, isEmpty);
    });

    test('R4-2 with no vault left, someone writing first under a gone '
        'vault\'s words gets no line naming someone here', () async {
      final (_, router) = await hiddenFake();
      await app.notThem(words, mallory.xPub);
      useDatabasesForTest(live, Session(live));
      await router.forget();
      await router.retire();
      await writes(alice);
      final own = unboundIdOf(_keyOf(alice));
      final at = live.people.containsKey(words) ? words : own;
      expect(
        ShieldFlag.fromRow(live.shields[at])?.lead.noticed,
        isNot(l10n.scamShieldGivesUsedName(words)),
      );
    });

    test('R4-3 both sides let the words go, vault shut: the add lifts the '
        'vault\'s too', () async {
      final (vault, router) = await hiddenFake();
      await app.notThem(words, mallory.xPub);
      useDatabasesForTest(live, Session(live));
      await live.takeBlocks(const [], [(name: words, at: 1)]);
      expect(await handleHaloUriAdded(await link(alice), app: app), ('', true));
      expect(await router.tombsGone(), [words]);
      useDatabasesForTest(live, await Session.withVault(live, vault));
      await app.remarkForTest(vault);
      expect(router.tombed(words), isFalse);
      expect(vault.tombedNames, isEmpty);
    });

    test('R4-4 a key blocked on the everyday side says so, whatever a shut '
        'vault also blocked', () async {
      await hiddenFake();
      await app.notThem(words, mallory.xPub);
      useDatabasesForTest(live, Session(live));
      await live.takeBlocks([(x: mallory.xPub, at: 1)], const []);
      expect(
        await handleHaloUriAdded(
          await link(mallory, id: 'other-mask-six'),
          app: app,
        ),
        (l10n.appKeyBlocked, false),
      );
    });

    test('a key a gone vault blocked and the new vault blocks too is the '
        'new vault\'s mark, and its unblock lets it go', () async {
      final (_, router) = await hiddenFake();
      await app.notThem(words, mallory.xPub);
      useDatabasesForTest(live, Session(live));
      await router.forget();
      await router.start('pub-B');
      expect(router.keyBlockedUnseen(mallory.xPub, vaultOpen: true), isTrue);
      final v2 = ArrivalRows(HaloContainer.vault);
      v2.blockedKeyAt[mallory.xPub] = 2;
      await app.remarkForTest(v2);
      expect(router.keyBlockedUnseen(mallory.xPub, vaultOpen: true), isFalse);
      expect(router.keyBlocked(mallory.xPub), isTrue);
      await router.markKey(mallory.xPub, on: false);
      expect(router.keyBlocked(mallory.xPub), isFalse);
    });

    test('a removal in the open vault tidies its file right after, off the '
        'queue', () async {
      final (vault, _) = await hiddenFake();
      final before = (vault as _OpenCount).opens;
      expect(await app.notThem(words, mallory.xPub), isTrue);
      await _settle();
      expect(vault.opens, greaterThan(before));
    });

    test('a first message on a key only the vault blocked leaves no word of '
        'a block in the debug list', () async {
      await hiddenFake();
      await app.notThem(words, mallory.xPub);
      useDatabasesForTest(live, Session(live));
      firstFails.clear();
      final ed = _rndHex(32);
      _idOf[ed] = 'fresh-mask-seven';
      await app.receiveOnion([
        await _opener(mallory, 'fresh-mask-seven', ed, _said, pow: pow),
      ]);
      await _settle();
      expect(live.people.containsKey('fresh-mask-seven'), isFalse);
      expect(firstFails.codes, isNot(contains('blocked')));
      expect(firstFails.codes, isNotEmpty);
    });

    test('the developer is never let go this way', () async {
      expect(await app.notThem('dev:marios', 'ab' * 32), isFalse);
    });
  });
}

// a database that never opens: its tidy fails each time it is tried
class _BadDb extends ArrivalRows {
  _BadDb() : super(HaloContainer.decoyVault);
  var opens = 0;
  @override
  Future<Database> open() async {
    opens++;
    throw StateError('shut');
  }
}

// a vault whose file is slow to open: a tidy at its close would hold up
// everything queued behind it
class _SlowDb extends ArrivalRows {
  _SlowDb() : super(HaloContainer.vault);
  var opened = false;
  @override
  Future<Database> open() async {
    opened = true;
    await Future<void>.delayed(const Duration(seconds: 3));
    throw StateError('slow');
  }

  @override
  Future<void> close() async {}
}

// a vault whose file counts how often it is opened
class _OpenCount extends ArrivalRows {
  _OpenCount() : super(HaloContainer.vault);
  var opens = 0;
  @override
  Future<Database> open() async {
    opens++;
    throw StateError('not here');
  }
}
