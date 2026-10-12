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
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        appState,
        askInboxMove,
        HaloEngine,
        LinkKin,
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
        signalDecrypt,
        unboundIdOf,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/shield_sheet.dart' show ShieldFlag;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
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
  void nostrSubscribeBg(String peerXPubHex) {}
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
  void listen(String xPub) {}
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
      ShieldFlag.fromRow(live.shields[own])?.headline,
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
      'shut', () async {
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
    expect(
      ShieldFlag.fromRow(live.shields[own])?.headline,
      l10n.scamShieldGivesUsedName(_hidden),
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
      askTakeName = (id, {required chat}) async {
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
}
