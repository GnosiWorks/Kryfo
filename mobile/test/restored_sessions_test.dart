// SPDX-License-Identifier: GPL-3.0-or-later
// a restore brings back signal sessions older than the far side's view of
// them. the phone the file was made on went on sealing after it, a
// delivery receipt at least, so the next seal on a restored session can
// repeat a message key the far side has spent: it drops that as a
// duplicate, and the text stays at one tick for good. a restored session
// is never sealed on again: the next seal starts one afresh from their
// card, the old one archived so what they sealed on it still opens. with
// no card kept the seal waits and asks them for one. the restored phone
// asks its people to start afresh too, as does a phone that cannot open
// what a contact sent, and whoever is asked puts out again what of theirs
// never came back delivered. real libsignal over rows kept in maps; this
// phone is the one restored
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloDb,
        kFrameReaction,
        kFrameReceipt,
        makePreKeyBundleB64,
        openSignalStore,
        processPeerBundle,
        signalDecrypt,
        signalEncrypt,
        useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart' show ArrivalSeal, ArrivalStore;
import 'mem_db.dart';

// the app's rows over maps. the requests' own queries are not this
// test's, nor the outbox's but where a test drains it
class _Rows extends HaloDb {
  _Rows(this.mem, [super.container = HaloContainer.everyday]);
  final MemDb mem;
  // the outbox read off the rows, for the tests that drain it
  var outbox = false;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async => [
    if (outbox)
      for (final r in mem.rows('messages'))
        if (r['direction'] == 'out' && r['sent'] == 0) r,
  ];
  // the counts and the home list's last lines are not this test's either
  @override
  Future<void> bumpUnread(String peerId) async {}
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => const {};
  @override
  Future<int> pendingRequestCount() async => 0;
  @override
  Future<List<Map<String, Object?>>> askedRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> vouchedPending() async => const [];
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
  @override
  Future<List<Map<String, Object?>>> parkedRequests() async => const [];
}

// signal as the app runs it, and a relay that keeps what it is handed
class _Io extends AppIo {
  final sent = <(String, String)>[];
  @override
  Future<String> relaySend(String xPub, String cipher) async {
    sent.add((xPub, cipher));
    return 'ok';
  }

  @override
  Future<String> onionSend(String onion, String cipher) async => 'error: off';
  @override
  Future<String> firstContactSend(
    String xPub,
    String fc,
    String cipher,
  ) async => 'error: off';
  @override
  void listen(String xPub) {}
  @override
  void unlisten(String xPub) {}
  @override
  String edPub() => 'ed-me';
  @override
  String xPub() => 'x-me';
  // the shade is not this test's
  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
    String? msgUid,
    int? burnAt,
  }) async {}
  @override
  Future<void> unnotifyMessage(String msgUid) async {}
  @override
  Future<void> unnotify(String payload) async {}

  // the bundle frames that went to [xPub], by whether they ask
  List<bool> asksTo(String xPub) => [
    for (final (to, c) in sent)
      if (to == xPub && c.startsWith('{'))
        (jsonDecode(c) as Map)['want'] == true,
  ];
}

typedef _Peer = ({SignalSession ss, String name, String xpub, String card});

var _n = 0;

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

Future<_Peer> _peer() async {
  final pair = Curve.generateKeyPair();
  final ss = SignalSession();
  final x = pair.publicKey.serialize().sublist(1);
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: x,
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (
    ss: ss,
    name: 'amber-river-${_n++}',
    // their x key, which their signal identity is made from
    xpub: _hex(x),
    card: await makePreKeyBundleB64(ss),
  );
}

// a text of theirs as their phone opens it: the app's open, a prekey on a
// session already held tried on that session first. a key spent already is
// a duplicate there, dropped, and anything else that does not open is null
Future<String?> _atPeer(_Peer p, String wireB64) async {
  final wire = base64Decode(wireB64);
  final body = Uint8List.fromList(wire.sublist(1));
  final addr = SignalProtocolAddress('me', 1);
  final c = SessionCipher(
    p.ss.sessionStore,
    p.ss.preKeyStore,
    p.ss.signedPreKeyStore,
    p.ss.identityStore,
    addr,
  );
  Future<Uint8List> open() async {
    if (wire[0] != CiphertextMessage.prekeyType) {
      return c.decryptFromSignal(SignalMessage.fromSerialized(body));
    }
    final pkm = PreKeySignalMessage(body);
    if (await p.ss.sessionStore.containsSession(addr)) {
      try {
        return await c.decryptFromSignal(pkm.getWhisperMessage());
      } catch (_) {
        return c.decrypt(pkm);
      }
    }
    return c.decrypt(pkm);
  }

  try {
    return utf8.decode(await p.ss.serial('me', open));
  } catch (_) {
    return null;
  }
}

// what a step leaves going on its own
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

Future<String> _toPeer(_Peer p, String text) => signalEncrypt(p.name, text);
Future<String> _fromPeer(_Peer p, String text) => p.ss.encryptTo('me', text);
Future<String?> _atMe(_Peer p, String wire) =>
    signalDecrypt(p.name, wire, flagKeyChange: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // this phone's signal store, and the rows its sessions are kept in
  final store = MemDb();
  late MemDb mem;
  late _Rows rows;
  late _Io io;
  late AppState app;
  late VaultRouter router;
  late ArrivalStore vaultList;

  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: store,
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    rows = _Rows(mem);
    useDatabasesForTest(rows, Session(rows));
    vaultList = ArrivalStore();
    router = VaultRouter(vaultList, ArrivalSeal());
    await router.load();
    io = _Io();
    app = AppState(io: io, router: router)
      ..myId = 'me'
      // a route is up: nothing waits on tor
      ..sendModeForTest = 'fast';
  });

  Future<void> contact(_Peer p, {bool card = true}) => mem.insert('contacts', {
    'halo_id': p.name,
    'onion': '',
    'xpub': p.xpub,
    'first_seen': 1,
    'last_seen': 1,
    'back_paired': 1,
    'accepted': 1,
    if (card) 'peer_bundle': p.card,
  });

  // paired from their card, a few texts each way, theirs last
  Future<void> talk(_Peer p) async {
    await processPeerBundle(p.name, p.card);
    for (var i = 0; i < 3; i++) {
      expect(await _atPeer(p, await _toPeer(p, 'me $i')), 'me $i');
      expect(await _atMe(p, await _fromPeer(p, 'them $i')), 'them $i');
    }
  }

  // the backup: this phone's session with them as the file holds it
  List<Map<String, Object?>> backUp(_Peer p) => [
    for (final r in store.rows('sessions'))
      if (r['address'] == p.name) r,
  ];

  // the file back in place, and the start after it, which marks what came
  // back (the store opening on a restore's pref, see the last test)
  Future<void> restore(_Peer p, List<Map<String, Object?>> file) async {
    await store.delete('sessions', where: 'address = ?', whereArgs: [p.name]);
    for (final r in file) {
      await store.insert('sessions', r);
    }
    await signalSession.markRestored();
  }

  // a text of theirs as their app wraps it, sealed and on the relay
  Future<void> came(_Peer p, String uid, String text, {int? burn}) async {
    final w = await wrapMessage(
      text,
      msgUid: uid,
      burnSeconds: burn,
      sender: SenderInfo(
        haloId: p.name,
        edPub: 'ed-${p.name}',
        onion: '',
        xPub: p.xpub,
      ),
    );
    final c = await _fromPeer(p, w);
    await app.receiveRelay([(peer: p.xpub, cipher: c)]);
    await _settle();
  }

  // what of ours has reached them, as their phone opens it. a cipher opens
  // once, so each is kept as it opened
  final opened = <String, String?>{};
  Future<List<String?>> atThem(_Peer p) async => [
    for (final (to, c) in [...io.sent])
      if (to == p.xpub && !c.startsWith('{'))
        opened.containsKey(c) ? opened[c] : (opened[c] = await _atPeer(p, c)),
  ];
  Future<List<String>> receiptsAt(_Peer p) async => [
    for (final w in await atThem(p))
      if (w != null) ?unwrapMessage(w).deliveredUid,
  ];

  Map<String, Object?>? row(String uid) {
    for (final r in mem.rows('messages')) {
      if (r['msg_uid'] == uid) return r;
    }
    return null;
  }

  // their card, asking nothing back, or asking us to start afresh. [n]
  // makes each one its own wrap, as a relay hands it over
  Future<void> card(
    _Peer p, {
    bool want = false,
    String? bundle,
    int n = 0,
  }) async {
    await app.receiveRelay([
      (
        peer: p.xpub,
        cipher: jsonEncode({
          'halo_ctl': 'bundle',
          'from': p.name,
          'bundle': bundle ?? p.card,
          'want': want,
          'n': n,
        }),
      ),
    ]);
    await _settle();
  }

  // a text of ours to them that went and never came back delivered
  Future<void> outTo(
    _Peer p,
    String uid, {
    int ago = 60000,
    String? peer,
    String direction = 'out',
    MemDb? into,
  }) => (into ?? mem).insert('messages', {
    'peer_id': peer ?? p.name,
    'direction': direction,
    'plaintext': uid,
    'sent_at': DateTime.now().millisecondsSinceEpoch - ago,
    'msg_uid': uid,
    'sent': 1,
    'delivered': 0,
  });

  Future<Uint8List> record(_Peer p) async =>
      (await store.query(
            'sessions',
            where: 'address = ?',
            whereArgs: [p.name],
          )).single['record']
          as Uint8List;

  test('the first text after a restore opens on the far side, and the '
      'chat goes on both ways', () async {
    final p = await _peer();
    await contact(p);
    await talk(p);
    final file = backUp(p);
    // their text after the backup, and this phone's receipt for it
    expect(await _atMe(p, await _fromPeer(p, 'After Backup 1')), isNotNull);
    expect(await _atPeer(p, await _toPeer(p, 'receipt')), 'receipt');
    await restore(p, file);

    // on the file's session this one repeats the receipt's key, and the far
    // side drops it as a duplicate
    final first = await _toPeer(p, 'b7 restored 10');
    expect(await _atPeer(p, first), 'b7 restored 10');
    expect(base64Decode(first).first, CiphertextMessage.prekeyType);
    expect(
      await _atMe(p, await _fromPeer(p, 'B7 to restored 10')),
      'B7 to restored 10',
    );
    expect(await _atPeer(p, await _toPeer(p, 'b7 second 10')), 'b7 second 10');
  });

  test('a restore two exchanges behind: both sides read each other '
      'again', () async {
    final p = await _peer();
    await contact(p);
    await talk(p);
    final file = backUp(p);
    for (var i = 0; i < 2; i++) {
      expect(await _atMe(p, await _fromPeer(p, 'gone $i')), 'gone $i');
      expect(await _atPeer(p, await _toPeer(p, 'lost $i')), 'lost $i');
    }
    await restore(p, file);

    expect(await _atPeer(p, await _toPeer(p, 'back')), 'back');
    for (var i = 0; i < 3; i++) {
      expect(await _atMe(p, await _fromPeer(p, 'them $i')), 'them $i');
      expect(await _atPeer(p, await _toPeer(p, 'me $i')), 'me $i');
    }
  });

  test('the session started afresh is the one the next texts ride, in '
      'any order they land', () async {
    final p = await _peer();
    await contact(p);
    await talk(p);
    final file = backUp(p);
    expect(await _atMe(p, await _fromPeer(p, 'after')), 'after');
    expect(await _atPeer(p, await _toPeer(p, 'receipt')), 'receipt');
    await restore(p, file);

    final one = await _toPeer(p, 'one');
    final two = await _toPeer(p, 'two');
    List<int> base(String w) => PreKeySignalMessage(
      Uint8List.fromList(base64Decode(w).sublist(1)),
    ).getBaseKey().serialize();
    expect(base(two), base(one));
    expect(await signalSession.sealsOnRestored(p.name), isFalse);
    expect(await _atPeer(p, two), 'two');
    expect(await _atPeer(p, one), 'one');
    expect(await _atMe(p, await _fromPeer(p, 'both')), 'both');
    final three = await _toPeer(p, 'three');
    expect(base64Decode(three).first, CiphertextMessage.whisperType);
    expect(await _atPeer(p, three), 'three');
  });

  test('with no card of theirs kept, nothing is sealed and they are asked '
      'for one; their answer lets the text go', () async {
    final p = await _peer();
    await contact(p, card: false);
    await talk(p);
    final file = backUp(p);
    expect(await _atMe(p, await _fromPeer(p, 'after')), 'after');
    expect(await _atPeer(p, await _toPeer(p, 'receipt')), 'receipt');
    await restore(p, file);

    final was = await record(p);
    await expectLater(_toPeer(p, 'waits'), throwsA(isA<StartingAfresh>()));
    await _settle();
    expect(await record(p), was, reason: 'nothing sealed on it');
    expect(io.asksTo(p.xpub), [true]);

    // their answer: their card, asking nothing back
    final answer = jsonEncode({
      'halo_ctl': 'bundle',
      'from': p.name,
      'bundle': p.card,
      'want': false,
    });
    await app.receiveRelay([(peer: p.xpub, cipher: answer)]);
    expect(await _atPeer(p, await _toPeer(p, 'waits')), 'waits');
  });

  test('asked to start afresh: what they sealed before still opens, and '
      'our texts they never got go again', () async {
    final p = await _peer();
    await contact(p);
    await talk(p);
    final inFlight = await _fromPeer(p, 'in flight');
    final now = DateTime.now().millisecondsSinceEpoch;
    Future<void> out(
      String uid, {
      int delivered = 0,
      int ago = 60000,
      String? group,
      String? media,
    }) => mem.insert('messages', {
      'peer_id': p.name,
      'direction': 'out',
      'plaintext': uid,
      'sent_at': now - ago,
      'msg_uid': uid,
      'sent': 1,
      'delivered': delivered,
      'group_id': ?group,
      'media_path': ?media,
    });
    await out('lost');
    await out('landed', delivered: 1);
    await out('long ago', ago: 8 * 24 * 3600 * 1000);
    await out('in a group', group: 'grp000000001');
    await out('a photo', media: '/m/a.jpg');

    final ask = jsonEncode({
      'halo_ctl': 'bundle',
      'from': p.name,
      'bundle': p.card,
      'want': true,
    });
    await app.receiveRelay([(peer: p.xpub, cipher: ask)]);
    await _settle();

    final sent = {
      for (final r in mem.rows('messages')) r['msg_uid']: r['sent'],
    };
    expect(sent, {
      'lost': 0,
      'landed': 1,
      'long ago': 1,
      'in a group': 1,
      'a photo': 1,
    });
    expect(io.asksTo(p.xpub), [false], reason: 'their answer: our card');
    expect(await _atMe(p, inFlight), 'in flight');
    expect(await _atPeer(p, await _toPeer(p, 'next')), 'next');
  });

  test('a text of theirs that does not open here asks them to start '
      'afresh, and sealed again on the session they start it opens', () async {
    final p = await _peer();
    await contact(p);
    await talk(p);
    await app.subscribeKnown();
    final file = backUp(p);
    for (var i = 0; i < 2; i++) {
      expect(await _atMe(p, await _fromPeer(p, 'gone $i')), 'gone $i');
      expect(await _atPeer(p, await _toPeer(p, 'lost $i')), 'lost $i');
    }
    await restore(p, file);

    // sealed on their side of the session, two steps past the file's
    final c = await _fromPeer(p, 'after the restore');
    await app.receiveRelay([(peer: p.xpub, cipher: c)]);
    await _settle();
    expect(io.asksTo(p.xpub), [true]);

    // they start a session from the card the ask carries, and put it again
    final card = (jsonDecode(io.sent.single.$2) as Map)['bundle'] as String;
    await processPeerBundle('me', card, into: p.ss);
    expect(
      await _atMe(p, await _fromPeer(p, 'after the restore')),
      'after the restore',
    );
    expect(await _atPeer(p, await _toPeer(p, 'and back')), 'and back');
  });

  test('a restored phone asks the people its sessions came back for to '
      'start afresh, once', () async {
    final p = await _peer();
    final q = await _peer();
    await contact(p);
    await contact(q);
    await talk(p);
    await talk(q);
    final file = backUp(p);
    expect(await _atMe(p, await _fromPeer(p, 'after')), 'after');
    await restore(p, file);
    // a session made after the restore is no one's to start over
    await processPeerBundle(q.name, q.card);
    expect(await signalSession.sealsOnRestored(q.name), isFalse);

    await app.askAfreshForTest();
    await app.askAfreshForTest();
    expect(io.asksTo(p.xpub), [true]);
    expect(io.asksTo(q.xpub), isEmpty);
  });

  test('the store marks what a restore brought back as it opens, only after '
      'a restore, and the mark holds across starts', () async {
    final db = MemDb();
    final pair = Curve.generateKeyPair();
    Future<SignalSession> start() async {
      final ss = SignalSession();
      await openSignalStore(
        ss,
        database: db,
        xPubBytes: pair.publicKey.serialize().sublist(1),
        xPrivBytes: pair.privateKey.serialize(),
      );
      return ss;
    }

    final p = await _peer();
    var ss = await start();
    await processPeerBundle(p.name, p.card, into: ss);
    ss = await start();
    expect(ss.hasRestored, isFalse);
    expect(await ss.sealsOnRestored(p.name), isFalse);

    // the restore's pref: this start marks, and the pref goes
    SharedPreferences.setMockInitialValues({kSessionsRestoredPref: true});
    ss = await start();
    expect(await ss.sealsOnRestored(p.name), isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(kSessionsRestoredPref),
      isNull,
    );
    // and the next start still knows them
    ss = await start();
    expect(await ss.sealsOnRestored(p.name), isTrue);
    await expectLater(
      ss.encryptTo(p.name, 'no card'),
      throwsA(isA<StartingAfresh>()),
    );
    final w = await ss.encryptTo(
      p.name,
      'card',
      afresh: () async => preKeyBundleOf(p.card),
    );
    expect(base64Decode(w).first, CiphertextMessage.prekeyType);
    expect(await ss.sealsOnRestored(p.name), isFalse);
  });

  test('a text of theirs that burned or was deleted here and comes again '
      'is acked and never shown again', () async {
    final p = await _peer();
    await contact(p);
    await talk(p);
    await app.subscribeKnown();
    await came(p, 'burns', 'gone in a minute', burn: 60);
    await came(p, 'deleted', 'delete me');
    expect(row('burns'), isNotNull);
    expect(row('deleted'), isNotNull);
    // read, its minute over and swept; the other deleted by hand
    await mem.update(
      'messages',
      {'burn_at': 1},
      where: 'msg_uid = ?',
      whereArgs: ['burns'],
    );
    await rows.purgeExpired();
    await rows.deleteMessage('deleted');
    expect(row('burns'), isNull);
    expect(row('deleted'), isNull);
    final acked = (await receiptsAt(p)).length;

    // their phone puts both out again, as an ask after a restore has it,
    // past the half minute a receipt is sent again in at most
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    await app.subscribeKnown();
    await came(p, 'burns', 'gone in a minute', burn: 60);
    await came(p, 'deleted', 'delete me');
    expect(row('burns'), isNull, reason: 'a burned one came back');
    expect(row('deleted'), isNull, reason: 'a deleted one came back');
    expect((await receiptsAt(p)).skip(acked), ['burns', 'deleted']);
    // someone else's with the same uid is theirs to send
    final q = await _peer();
    await contact(q);
    await talk(q);
    await came(q, 'burns', 'not the same one');
    expect(row('burns')?['peer_id'], q.name);
  });

  test('a receipt that cannot be sealed while the session waits on their '
      'card waits with it, and goes once the card is here', () async {
    final p = await _peer();
    await contact(p, card: false);
    await talk(p);
    await app.subscribeKnown();
    final file = backUp(p);
    expect(await _atPeer(p, await _toPeer(p, 'after')), 'after');
    await restore(p, file);

    await came(p, 'r1', 'did you get this');
    expect(row('r1')?['plaintext'], 'did you get this');
    expect(await receiptsAt(p), isEmpty);
    expect(app.waitsForCard(p.name), isTrue);
    expect(mem.rows('frames_out').single['kind'], kFrameReceipt);

    await card(p);
    expect(await receiptsAt(p), ['r1']);
    expect(mem.rows('frames_out'), isEmpty);
    expect(app.waitsForCard(p.name), isFalse);
  });

  test('a text waiting on their card is no failed try, and goes the moment '
      'their card is here', () async {
    final p = await _peer();
    await contact(p, card: false);
    await talk(p);
    final file = backUp(p);
    expect(await _atPeer(p, await _toPeer(p, 'after')), 'after');
    await restore(p, file);
    rows.outbox = true;
    await mem.insert('messages', {
      'peer_id': p.name,
      'direction': 'out',
      'plaintext': 'waits',
      'sent_at': DateTime.now().millisecondsSinceEpoch - 60000,
      'msg_uid': 'w1',
      'sent': 0,
    });

    await app.drainOutbox();
    await _settle();
    expect(row('w1')?['sent'], 0);
    expect(app.waitsForCard(p.name), isTrue);
    expect(app.outboxTriesForTest('w1'), 0);

    await card(p);
    expect(row('w1')?['sent'], 1);
    final at = await atThem(p);
    expect(unwrapMessage(at.whereType<String>().last).message, 'waits');
  });

  test('asked again within ten minutes, nothing goes again', () async {
    final p = await _peer();
    await contact(p);
    await talk(p);
    await outTo(p, 'lost');
    await card(p, want: true);
    expect(row('lost')?['sent'], 0);
    // the outbox sent it, and it is lost again
    await mem.update(
      'messages',
      {'sent': 1},
      where: 'msg_uid = ?',
      whereArgs: ['lost'],
    );
    await card(p, want: true, n: 1);
    expect(row('lost')?['sent'], 1);
  });

  test(
    'asked while their key is flagged as changed, nothing goes again',
    () async {
      final p = await _peer();
      await contact(p);
      await talk(p);
      await mem.update(
        'contacts',
        {'key_changed': 1},
        where: 'halo_id = ?',
        whereArgs: [p.name],
      );
      await outTo(p, 'lost');
      await card(p, want: true);
      expect(row('lost')?['sent'], 1);
    },
  );

  test('only our own text to them goes again, never a row of the same uid '
      'that came in or went to someone else', () async {
    final p = await _peer();
    await outTo(p, 'u1');
    await outTo(p, 'u1', peer: 'someone-else-here');
    await outTo(p, 'u1', direction: 'in');
    final n = await rows.resendUndelivered(p.name, since: 0);
    expect(n, 1);
    expect([for (final r in mem.rows('messages')) r['sent']], [0, 1, 1]);
  });

  test('a hidden chat asked while its vault is shut gets what never reached '
      'them as the vault opens', () async {
    final p = await _peer();
    await processPeerBundle(p.name, p.card);
    await vaultList.putMeta('pub', 'pub-A');
    await vaultList.putHidden(
      p.name,
      kHiddenPeer,
      peerCard(RouterCard(p.name, '', p.xpub, backPaired: true)),
      1,
    );
    await router.load();
    await card(p, want: true);

    // the vault opens: their chat and our text in it
    final vmem = MemDb();
    final vault = _Rows(vmem, HaloContainer.vault);
    await vmem.insert('contacts', {
      'halo_id': p.name,
      'onion': '',
      'xpub': p.xpub,
      'first_seen': 1,
      'last_seen': 1,
      'back_paired': 1,
      'accepted': 1,
    });
    await outTo(p, 'lost', into: vmem);
    useDatabasesForTest(rows, await Session.withVault(rows, vault));
    await app.drainSealed(vault, 'priv-A');
    expect(vmem.rows('messages').single['sent'], 0);
    expect(vaultList.inbox, isEmpty);
  });

  test('with no key pinned for them, a card is taken only with the key '
      'their x key makes', () async {
    final p = await _peer();
    final q = await _peer();
    await contact(p, card: false);
    // q's card under p's name, on p's relay lane
    await card(p, bundle: q.card);
    expect(mem.rows('contacts').single['peer_bundle'], isNull);
    // p's own, as 0.4.2 sends it
    await card(p);
    expect(mem.rows('contacts').single['peer_bundle'], p.card);
  });

  test('who was asked is kept with the sessions: a start after this one '
      'does not ask again', () async {
    final p = await _peer();
    await contact(p);
    await talk(p);
    await signalSession.markRestored();
    await app.askAfreshForTest();
    expect(io.asksTo(p.xpub), [true]);

    final again = AppState(io: io, router: router)..myId = 'me';
    await again.askAfreshForTest();
    expect(io.asksTo(p.xpub), [true]);
  });

  test('a pass asks a few people at a time', () async {
    final people = [for (var i = 0; i < 10; i++) await _peer()];
    for (final p in people) {
      await contact(p);
      await processPeerBundle(p.name, p.card);
    }
    await signalSession.markRestored();
    await app.askAfreshForTest();
    final asked = [
      for (final p in people)
        if (io.asksTo(p.xpub).isNotEmpty) p,
    ];
    expect(asked, hasLength(8));
  });

  test('someone who never answers is asked again later and later, and the '
      'marks go once every session has started afresh', () async {
    final db = MemDb();
    final pair = Curve.generateKeyPair();
    Future<SignalSession> start() async {
      final ss = SignalSession();
      await ss.bootstrap(
        database: db,
        xPubBytes: pair.publicKey.serialize().sublist(1),
        xPrivBytes: pair.privateKey.serialize(),
      );
      return ss;
    }

    final p = await _peer();
    var ss = await start();
    await processPeerBundle(p.name, p.card, into: ss);
    await ss.markRestored();
    const hour = 3600 * 1000;
    expect(await ss.askDue(p.name, 0), isTrue);
    await ss.noteAsked(p.name, 0);
    ss = await start();
    expect(await ss.askDue(p.name, hour - 1), isFalse);
    expect(await ss.askDue(p.name, hour), isTrue);
    await ss.noteAsked(p.name, hour);
    expect(await ss.askDue(p.name, 2 * hour), isFalse);
    expect(await ss.askDue(p.name, 3 * hour), isTrue);

    expect(await ss.dropRestoredWhenDone(), isFalse);
    expect(ss.hasRestored, isTrue);
    await ss.encryptTo(
      p.name,
      'afresh',
      afresh: () async => preKeyBundleOf(p.card),
    );
    expect(await ss.dropRestoredWhenDone(), isTrue);
    expect(ss.hasRestored, isFalse);
    expect(db.rows('signal_meta').map((r) => r['k']), ['regId']);
    ss = await start();
    expect(ss.hasRestored, isFalse);
  });

  test('a text waiting on their card asks once, and tries again as they '
      'are asked again, an hour on', () async {
    final p = await _peer();
    await contact(p, card: false);
    await talk(p);
    final file = backUp(p);
    expect(await _atPeer(p, await _toPeer(p, 'after')), 'after');
    await restore(p, file);
    rows.outbox = true;
    await mem.insert('messages', {
      'peer_id': p.name,
      'direction': 'out',
      'plaintext': 'waits',
      'sent_at': DateTime.now().millisecondsSinceEpoch - 60000,
      'msg_uid': 'w1',
      'sent': 0,
    });
    final t0 = DateTime.now().millisecondsSinceEpoch;
    await app.drainOutbox();
    await _settle();
    expect(io.asksTo(p.xpub), [true]);
    expect(app.outboxTriesForTest('w1'), 0);
    expect(
      app.outboxNextAtForTest('w1'),
      greaterThanOrEqualTo(t0 + 3600 * 1000),
    );

    // a start after this one tries at once, and asks nothing before it is due
    final again = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    await again.drainOutbox();
    await _settle();
    expect(again.waitsForCard(p.name), isTrue);
    expect(row('w1')?['sent'], 0);
    expect(io.asksTo(p.xpub), [true]);
  });

  test('a blocked contact who asks to start afresh is sent nothing, and '
      'their card is not kept', () async {
    final p = await _peer();
    await contact(p, card: false);
    await talk(p);
    await outTo(p, 'lost');
    await mem.update(
      'contacts',
      {'blocked': 1},
      where: 'halo_id = ?',
      whereArgs: [p.name],
    );
    final was = await record(p);
    await card(p, want: true);
    expect(io.asksTo(p.xpub), isEmpty);
    expect(row('lost')?['sent'], 1);
    expect(mem.rows('contacts').single['peer_bundle'], isNull);
    expect(await record(p), was);
  });

  test('someone a shut vault holds as blocked is sent nothing when they '
      'ask', () async {
    final p = await _peer();
    await processPeerBundle(p.name, p.card);
    final was = await record(p);
    await vaultList.putMeta('pub', 'pub-A');
    await vaultList.putHidden(
      p.name,
      kHiddenPeer,
      peerCard(RouterCard(p.name, '', p.xpub, backPaired: true, blocked: true)),
      1,
    );
    await router.load();
    await card(p, want: true);
    expect(io.asksTo(p.xpub), isEmpty);
    expect(vaultList.inbox, isEmpty);
    expect(await record(p), was, reason: 'no session from their card');
  });

  test('a resend owed to a hidden chat is not made once they are blocked '
      'there', () async {
    final p = await _peer();
    await processPeerBundle(p.name, p.card);
    await vaultList.putMeta('pub', 'pub-A');
    await vaultList.putHidden(
      p.name,
      kHiddenPeer,
      peerCard(RouterCard(p.name, '', p.xpub, backPaired: true)),
      1,
    );
    await router.load();
    await card(p, want: true);
    expect(vaultList.inbox, isNotEmpty);

    final vmem = MemDb();
    final vault = _Rows(vmem, HaloContainer.vault);
    await vmem.insert('contacts', {
      'halo_id': p.name,
      'onion': '',
      'xpub': p.xpub,
      'first_seen': 1,
      'last_seen': 1,
      'back_paired': 1,
      'accepted': 1,
      'blocked': 1,
    });
    await outTo(p, 'lost', into: vmem);
    useDatabasesForTest(rows, await Session.withVault(rows, vault));
    await app.drainSealed(vault, 'priv-A');
    expect(vmem.rows('messages').single['sent'], 1);
  });

  test('a receipt queued for someone goes with the block, and never goes '
      'out', () async {
    final p = await _peer();
    await contact(p, card: false);
    await talk(p);
    await app.subscribeKnown();
    final file = backUp(p);
    expect(await _atPeer(p, await _toPeer(p, 'after')), 'after');
    await restore(p, file);
    await came(p, 'r1', 'did you get this');
    expect(mem.rows('frames_out').single['kind'], kFrameReceipt);

    await app.block(p.name);
    expect(mem.rows('frames_out'), isEmpty);
    await card(p);
    await app.drainOutbox();
    await _settle();
    expect(await receiptsAt(p), isEmpty);
  });

  test('a word queued for someone blocked since never goes, and its row '
      'goes', () async {
    final p = await _peer();
    await contact(p);
    await talk(p);
    await rows.queueFrame('u1', kFrameReaction, p.name, 'x');
    await mem.update(
      'frames_out',
      {'at': DateTime.now().millisecondsSinceEpoch - 60000},
      where: 'msg_uid = ?',
      whereArgs: ['u1'],
    );
    await mem.update(
      'contacts',
      {'blocked': 1},
      where: 'halo_id = ?',
      whereArgs: [p.name],
    );
    await app.drainOutbox();
    await _settle();
    expect(io.sent.where((s) => s.$1 == p.xpub), isEmpty);
    expect(mem.rows('frames_out'), isEmpty);
  });

  test('receipts waiting on a card leave the window to the rest, and go '
      'after a week', () async {
    final w = await _peer();
    await contact(w, card: false);
    await talk(w);
    await app.subscribeKnown();
    final file = backUp(w);
    expect(await _atPeer(w, await _toPeer(w, 'after')), 'after');
    await restore(w, file);
    await came(w, 'r0', 'did you get this');
    expect(app.waitsForCard(w.name), isTrue);
    final now = DateTime.now().millisecondsSinceEpoch;
    const day = 24 * 3600 * 1000;
    for (var i = 0; i < 40; i++) {
      await mem.insert('frames_out', {
        'msg_uid': 'r${i + 1}',
        'kind': kFrameReceipt,
        'peer_id': w.name,
        'body': '',
        'at': now - 2 * day + i,
      });
    }
    await mem.insert('frames_out', {
      'msg_uid': 'old',
      'kind': kFrameReceipt,
      'peer_id': w.name,
      'body': '',
      'at': now - 8 * day,
    });

    // someone else, paired since, with a reaction queued behind them
    final p = await _peer();
    await contact(p);
    await talk(p);
    await mem.insert('frames_out', {
      'msg_uid': 'u1',
      'kind': kFrameReaction,
      'peer_id': p.name,
      'body': 'x',
      'at': now - 60000,
    });
    await app.drainOutbox();
    await _settle();
    expect(
      [for (final w in await atThem(p)) unwrapMessage(w!).reaction?.emoji],
      ['x'],
    );
    final left = {for (final r in mem.rows('frames_out')) r['msg_uid']};
    expect(left, hasLength(41));
    expect(left, isNot(contains('old')));
  });

  test('someone blocked or never taken in is not asked, and holds no '
      'restore\'s marks', () async {
    // the sessions of the tests before are not this one's
    await store.delete('sessions');
    final p = await _peer();
    final b = await _peer();
    final r = await _peer();
    for (final x in [p, b, r]) {
      await contact(x);
      await processPeerBundle(x.name, x.card);
    }
    await mem.update(
      'contacts',
      {'blocked': 1},
      where: 'halo_id = ?',
      whereArgs: [b.name],
    );
    await mem.update(
      'contacts',
      {'accepted': 0},
      where: 'halo_id = ?',
      whereArgs: [r.name],
    );
    await signalSession.markRestored();
    final t = DateTime.now().millisecondsSinceEpoch;
    await app.askAfreshForTest(now: t);
    expect(io.asksTo(p.xpub), [true]);
    expect(io.asksTo(b.xpub), isEmpty);
    expect(io.asksTo(r.xpub), isEmpty);
    expect(signalSession.hasRestored, isTrue);

    // p's next seal starts afresh from the card on its row
    expect(await _atPeer(p, await _toPeer(p, 'fresh')), 'fresh');
    await app.askAfreshForTest(now: t + 11 * 60 * 1000);
    expect(signalSession.hasRestored, isFalse);
  });

  test('the same uid from two people, both gone here, is known for '
      'each', () async {
    final p = await _peer();
    final q = await _peer();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final x in [p, q]) {
      await mem.insert('messages', {
        'peer_id': x.name,
        'direction': 'in',
        'plaintext': 'same',
        'sent_at': now,
        'msg_uid': 'twice',
        'sent': 1,
      });
    }
    await rows.deleteMessage('twice');
    expect(await rows.goneFrom(p.name, 'twice'), isTrue);
    expect(await rows.goneFrom(q.name, 'twice'), isTrue);
  });
}
