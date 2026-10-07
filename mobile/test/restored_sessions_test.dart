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
        makePreKeyBundleB64,
        openSignalStore,
        preKeyBundleOf,
        processPeerBundle,
        signalDecrypt,
        signalEncrypt,
        useDatabasesForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart' show ArrivalSeal, ArrivalStore;
import 'mem_db.dart';

// the app's rows over maps. the outbox's and the requests' own queries
// are not this test's
class _Rows extends HaloDb {
  _Rows(this.mem) : super(HaloContainer.everyday);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async => const [];
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

  // the bundle frames that went to [xPub], by whether they ask
  List<bool> asksTo(String xPub) => [
    for (final (to, c) in sent)
      if (to == xPub && c.startsWith('{'))
        (jsonDecode(c) as Map)['want'] == true,
  ];
}

typedef _Peer = ({SignalSession ss, String name, String xpub, String card});

var _n = 0;

Future<_Peer> _peer() async {
  final pair = Curve.generateKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  final name = 'amber-river-${_n++}';
  return (
    ss: ss,
    name: name,
    xpub: 'x-$name',
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
  late _Io io;
  late AppState app;

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
    final rows = _Rows(mem);
    useDatabasesForTest(rows, Session(rows));
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    io = _Io();
    app = AppState(io: io, router: router)..myId = 'me';
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
}
