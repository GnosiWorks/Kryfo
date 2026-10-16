// SPDX-License-Identifier: GPL-3.0-or-later
// an opener that never came back delivered goes again, and once more when
// they add us back. real database methods over rows in maps; the wire and
// signal are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        kNotSent,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _amy = 'amy-who-waits';
const _min = 60000;

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // its or-clause is past what the map rows read: the same rule, in dart
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async {
    final blocked = {
      for (final c in mem.rows('contacts'))
        if (c['blocked'] == 1) c['halo_id'],
    };
    return [
      for (final r in mem.rows('messages'))
        if (r['direction'] == 'out' &&
            r['sent'] == 0 &&
            r['msg_uid'] != null &&
            r['group_id'] == null &&
            !skip.contains(r['peer_id']) &&
            !blocked.contains(r['peer_id']))
          r,
    ];
  }

  // a raw update, a join and an IFNULL the map rows do not read
  @override
  Future<void> bumpUnread(String peerId) async {}
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];

  // called as a try is noted, before the opener goes
  void Function(String uid)? onNote;
  @override
  Future<void> noteOpenerAgain(String uid, int tries, int at) {
    onNote?.call(uid);
    return super.noteOpenerAgain(uid, tries, at);
  }
}

class _Engine implements HaloEngine {
  @override
  void nostrSubscribeBg(String peerXPubHex, {bool fresh = false}) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;
  late ArrivalIo io;
  late AppState app;
  late int now;
  final pow = <String, int>{};

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('first_resend');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    useEngineForTest(_Engine());
    for (final u in ['o1', 'o2', 'o3']) {
      pow[u] = grindPow('text $u', powBits);
    }
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  Future<void> out(
    String uid, {
    int sent = 1,
    int delivered = 0,
    required int at,
    bool secure = false,
  }) => mem.insert('messages', {
    'peer_id': _amy,
    'direction': 'out',
    'plaintext': 'text $uid',
    'sent_at': at,
    'msg_uid': uid,
    'sent': sent,
    'delivered': delivered,
    'pow_nonce': pow[uid],
    'secure': secure ? 1 : 0,
  });

  Future<void> secure(String uid) => mem.update(
    'messages',
    {'secure': 1},
    where: 'msg_uid = ?',
    whereArgs: [uid],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    now = DateTime.now().millisecondsSinceEpoch;
    mem = MemDb();
    db = _Rows(mem, HaloContainer.everyday);
    io = ArrivalIo();
    await mem.insert('contacts', {
      'halo_id': _amy,
      'onion': 'o-$_amy',
      'xpub': 'x-$_amy',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 0,
    });
    // two openers to her: one with no receipt, one a block kept back, and
    // one that came back delivered
    await out('o1', at: now - 11 * _min);
    await out('o2', sent: kNotSent, at: now - 11 * _min);
    await out('o3', delivered: 1, at: now - 11 * _min);
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    useDatabasesForTest(db, Session(db));
    await app.rememberPeerFc(_amy, 'fc-$_amy');
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  // what each of our texts went as, by its uid
  List<UnwrappedMessage> wires(String uid) => [
    for (final (_, c) in io.sent)
      if (c.contains('"u":"$uid"'))
        unwrapMessage(c.substring('to $_amy '.length)),
  ];

  // the routes each of our texts went by, in order
  List<String> went(String uid) => [
    for (final (to, c) in io.sent)
      if (c.contains('"u":"$uid"')) to.split(' ').first,
  ];

  Future<void> lastWent(String uid, int at) => mem.update(
    'opener_again',
    {'last_at': at},
    where: 'msg_uid = ?',
    whereArgs: [uid],
  );

  Map<String, Object?>? again(String uid) {
    for (final r in mem.rows('opener_again')) {
      if (r['msg_uid'] == uid) return r;
    }
    return null;
  }

  group('an opener with no receipt', () {
    test('goes again by its first-contact address too, as each wait ends, '
        'four times at most', () async {
      await app.sendOpenersAgain();
      await settle();
      expect(went('o1'), containsAll(['fc', 'onion']));
      expect(went('o2'), isEmpty);
      expect(went('o3'), isEmpty);
      expect(again('o1')!['tries'], 1);
      // not yet due: nothing
      io.sent.clear();
      await app.sendOpenersAgain();
      await settle();
      expect(went('o1'), isEmpty);
      // an hour after it last went
      for (final (tries, wait) in [
        (1, 61),
        (2, 6 * 60 + 1),
        (3, 24 * 60 + 1),
      ]) {
        await lastWent('o1', now - wait * _min);
        await app.sendOpenersAgain();
        await settle();
        if (tries + 1 < 4) {
          expect(went('o1'), contains('fc'), reason: 'try ${tries + 1}');
        } else {
          // the last goes by her onion and the pair address, never her
          // first-contact address, which may be one she has reset since
          expect(
            went('o1'),
            unorderedEquals(['onion', 'relay']),
            reason: 'try ${tries + 1}',
          );
        }
        expect(again('o1')!['tries'], tries + 1);
        io.sent.clear();
      }
      // four times went: no more, however long it waits
      await lastWent('o1', now - 2 * 24 * 60 * _min);
      await app.sendOpenersAgain();
      await settle();
      expect(went('o1'), isEmpty);
      expect(again('o1')!['tries'], 4);
      // the row is left as it was: sent, waiting on its receipt
      final row = mem.rows('messages').firstWhere((r) => r['msg_uid'] == 'o1');
      expect((row['sent'], row['delivered']), (1, 0));
    });

    test('one going again is claimed before its try is noted: the chat '
        'cannot send it alongside, and the claim is let go after', () async {
      bool? chatGot;
      db.onNote = (uid) => chatGot ??= app.claimSend(uid);
      await app.sendOpenersAgain();
      await settle();
      expect(chatGot, isFalse);
      expect(went('o1'), containsAll(['fc', 'onion']));
      expect(app.sendInflight('o1'), isFalse);
      // one the chat holds is left to it, and costs no try
      db.onNote = null;
      await lastWent('o1', now - 61 * _min);
      io.sent.clear();
      expect(app.claimSend('o1'), isTrue);
      await app.sendOpenersAgain();
      await settle();
      expect(went('o1'), isEmpty);
      expect(again('o1')!['tries'], 1);
      expect(app.sendInflight('o1'), isTrue);
      app.releaseSend('o1');
    });

    test('one written two weeks ago or more never goes again', () async {
      await mem.update(
        'messages',
        {'sent_at': now - 14 * 24 * 60 * _min},
        where: 'msg_uid = ?',
        whereArgs: ['o1'],
      );
      await app.sendOpenersAgain();
      await settle();
      expect(went('o1'), isEmpty);
      expect(again('o1'), isNull);
    });

    test('a secure one goes again secure', () async {
      await secure('o1');
      await app.sendOpenersAgain();
      await settle();
      expect(wires('o1'), isNotEmpty);
      expect(wires('o1').every((w) => w.secure), isTrue);
    });

    test('it goes again as the very words it first went as', () async {
      final first = await wrapMessage(
        'text o1',
        msgUid: 'o1',
        powNonce: pow['o1'],
        powBitsUsed: powBits,
        supporterBadge: 'a badge since let go of',
        sender: asSender('me'),
        writtenAt: now - 11 * _min + 5,
      );
      await db.keepOpenerWire('o1', first);
      await app.sendOpenersAgain();
      await settle();
      final went = [
        for (final (_, c) in io.sent)
          if (c.contains('"u":"o1"')) c,
      ];
      expect(went, isNotEmpty);
      expect(went.toSet(), {'to $_amy $first'});
    });

    test('edited since it first went, it goes again as it reads now, after '
        'a restart too', () async {
      final first = await wrapMessage(
        'text o1',
        msgUid: 'o1',
        powNonce: pow['o1'],
        powBitsUsed: powBits,
        sender: asSender('me'),
      );
      await db.keepOpenerWire('o1', first);
      await db.editMessage('o1', 'text o1, put better');
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      final next = AppState(io: io, router: router)
        ..myId = 'me'
        ..sendModeForTest = 'fast';
      await next.sendOpenersAgain();
      await settle();
      final w = wires('o1');
      expect(w, isNotEmpty);
      for (final m in w) {
        expect(m.message, 'text o1, put better');
        // and its proof is over the words it carries, or their gate drops it
        expect(verifyPow(m.powText ?? m.message, m.powNonce!, powBits), isTrue);
      }
    });

    test('past their two, once its onion and relay copies both went, it '
        'waits held and goes no more', () async {
      await out('e1', delivered: 1, at: now - 30 * _min);
      await out('e2', delivered: 1, at: now - 20 * _min);
      await db.noteOpenerBoth('o1');
      await app.sendOpenersAgain();
      await settle();
      expect(went('o1'), isEmpty);
      // one of their first two still goes again
      await mem.delete('messages', where: 'msg_uid = ?', whereArgs: ['e1']);
      await app.sendOpenersAgain();
      await settle();
      expect(went('o1'), contains('fc'));
    });

    test('a receipt stops it', () async {
      await app.sendOpenersAgain();
      await settle();
      await db.markDelivered('o1', from: _amy);
      await lastWent('o1', now - 2 * 60 * _min);
      io.sent.clear();
      await app.sendOpenersAgain();
      await settle();
      expect(went('o1'), isEmpty);
    });

    test('a block, a new key or their add stops it', () async {
      for (final (col, v) in [
        ('blocked', 1),
        ('key_changed', 1),
        ('back_paired', 1),
      ]) {
        await mem.update(
          'contacts',
          {col: v},
          where: 'halo_id = ?',
          whereArgs: [_amy],
        );
        await app.sendOpenersAgain();
        await settle();
        expect(went('o1'), isEmpty, reason: col);
        await mem.update(
          'contacts',
          {col: 0},
          where: 'halo_id = ?',
          whereArgs: [_amy],
        );
      }
    });
  });

  test('a request that goes takes what of theirs was kept', () async {
    for (final (h, peer) in [('h1', _amy), ('h2', 'bo'), ('h3', _amy)]) {
      await db.keepFirst(h, 'c-$h', peer: peer, uid: 'u-$h', now: now);
    }
    await db.forgetRequest(_amy);
    expect([for (final r in await db.firstKept()) r.hash], ['h2']);
    await db.keepFirst('h4', 'c-h4', peer: 'bo', uid: 'u-h4', now: now);
    await db.forgetFirstOf('bo', uid: 'u-h4');
    expect([for (final r in await db.firstKept()) r.hash], ['h2']);
  });

  group('their add', () {
    // a message from her: the proof that she added us back
    Future<void> hears(String cipher, String uid) async {
      io.opens[cipher] = (
        _amy,
        await wrapMessage('hi', msgUid: uid, sender: asSender(_amy)),
      );
      await app.receiveRelay([(peer: 'x-$_amy', cipher: cipher)]);
      await settle();
    }

    test('puts what went with no receipt out again once, on the lane she '
        'reads now', () async {
      await hears('p1', 'a1');
      expect(await db.isBackPaired(_amy), isTrue);
      expect(went('o1'), ['relay']);
      expect(went('o2'), isEmpty);
      expect(went('o3'), isEmpty);
      final sent = {
        for (final r in mem.rows('messages')) r['msg_uid']: r['sent'],
      };
      expect(sent, containsPair('o1', 1));
      expect(sent, containsPair('o2', kNotSent));
      expect(
        [
          for (final r in mem.rows('messages'))
            if (r['peer_id'] == _amy && r['direction'] == 'in') r['msg_uid'],
        ],
        ['a1'],
      );
      // her next message changes nothing: it went once
      await hears('p2', 'a2');
      expect(went('o1'), ['relay']);
    });

    test(
      'lets go of her first-contact address, so no card hands it on',
      () async {
        expect(app.peerFcFor(_amy), 'fc-$_amy');
        await hears('p1', 'a1');
        await settle();
        expect(app.peerFcFor(_amy), isNull);
      },
    );

    test('reaches no further back than a copy is known as gone', () async {
      const day = 24 * 60 * _min;
      await out('old16', at: now - 16 * day);
      await out('old14', at: now - 14 * day);
      await hears('p1', 'a1');
      expect(went('old14'), ['relay']);
      expect(went('old16'), isEmpty);
    });

    test('a secure one goes again secure', () async {
      await secure('o1');
      await hears('p1', 'a1');
      expect(wires('o1').single.secure, isTrue);
    });

    test('a new key of hers puts nothing out again', () async {
      await mem.update(
        'contacts',
        {'key_changed': 1},
        where: 'halo_id = ?',
        whereArgs: [_amy],
      );
      await hears('p1', 'a1');
      expect(went('o1'), isEmpty);
    });
  });
}
