// SPDX-License-Identifier: GPL-3.0-or-later
// while a decoy is open nothing of the everyday account leaves: its texts,
// edits, pins, reactions and receipts wait, and so does a file part way
// out. a decoy left open by the run before holds it too, until a pin opens
// the everyday side. what arrives still lands, unseen, and its receipt
// waits with the rest. once the everyday side is back each goes once. the
// database methods are the real ones over rows kept in maps; the wire and
// signal are stand-ins
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart' show LockStore, PinResult;
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        kFrameReaction,
        kFrameReceipt,
        sessionQuiet,
        useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _bob = 'bob-who-writes';
// someone a shut vault keeps
const _vic = 'vic-kept-hidden';

// the lock's storage: the mark of a decoy open and the pin table, with a
// read of the mark that fails or does not answer
class _Lock implements LockStore {
  _Lock({bool table = true, bool? quiet}) {
    if (table) kept['halo.lock.table'] = 't';
    if (quiet != null) kept['halo.lock.state'] = jsonEncode({'q': quiet});
  }
  final kept = <String, String>{};
  var fails = 0;
  Completer<void>? hang;
  @override
  Future<String?> read(String key) async {
    if (key == 'halo.lock.state') {
      await hang?.future;
      if (fails > 0) {
        fails--;
        throw StateError('no read');
      }
    }
    return kept[key];
  }

  @override
  Future<void> write(String key, String value) async => kept[key] = value;
  @override
  Future<void> delete(String key) async => kept.remove(key);
}

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => [
    for (final r in mem.rows('messages'))
      if (r['direction'] == 'out' &&
          r['sent'] == 0 &&
          r['msg_uid'] != null &&
          r['group_id'] == null &&
          !skip.contains(r['peer_id']))
        r,
  ];
}

Future<void> _person(MemDb mem, String id) => mem.insert('contacts', {
  'halo_id': id,
  'onion': 'o-$id',
  'xpub': 'x-$id',
  'first_seen': 1,
  'last_seen': 1,
  'accepted': 1,
  'back_paired': 1,
  'blocked': 0,
});

Future<void> _out(MemDb mem, String uid, String peer) =>
    mem.insert('messages', {
      'peer_id': peer,
      'direction': 'out',
      'plaintext': 'text $uid',
      'sent_at': 1,
      'msg_uid': uid,
      'sent': 0,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;
  late _Rows decoy;
  late ArrivalIo io;
  late AppState app;
  late ArrivalStore list;
  late VaultRouter router;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('decoy_hold');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    db = _Rows(mem);
    decoy = _Rows(MemDb(), HaloContainer.decoy);
    io = ArrivalIo();
    await _person(mem, _bob);
    list = ArrivalStore();
    router = VaultRouter(list, ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    useDatabasesForTest(db, Session(db));
  });

  tearDown(() => docs.deleteSync(recursive: true));

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  // old enough to go again, newer than a week
  Future<void> age() async {
    for (final t in ['edits_out', 'pins_out', 'frames_out']) {
      for (final r in mem.rows(t)) {
        await mem.update(
          t,
          {'at': DateTime.now().millisecondsSinceEpoch - 60000},
          where: 'msg_uid = ?',
          whereArgs: [r['msg_uid']],
        );
      }
    }
  }

  List<UnwrappedMessage> wire() => [
    for (final (_, c) in io.sent)
      unwrapMessage(c.substring(c.indexOf(' ', 3) + 1)),
  ];

  // a text, an edit, a pin and a reaction, all waiting on the everyday side
  Future<void> queued() async {
    await _out(mem, 't1', _bob);
    await db.queueEdit('e1', _bob, 'changed');
    await db.queuePin('p1', _bob, true);
    await db.queueFrame('r1', kFrameReaction, _bob, 'x');
    await age();
  }

  // what went, once each: texts by uid, the rest by what they name
  List<String> went() => [
    for (final m in wire())
      if (m.edit != null)
        'edit ${m.edit!.targetUid}'
      else if (m.pin != null)
        'pin ${m.pin!.targetUid}'
      else if (m.reaction != null)
        'reaction ${m.reaction!.targetUid}'
      else if (m.deliveredUid != null)
        'receipt ${m.deliveredUid}'
      else
        'text ${m.msgUid}',
  ]..sort();

  int tries(String table) => (mem.rows(table).single['tries'] as int?) ?? 0;

  test('a decoy open: nothing of the everyday side goes, and no try is '
      'used', () async {
    await queued();
    useDatabasesForTest(db, Session(decoy));
    expect(sessionQuiet, isTrue);
    expect(app.everydayHeld, isTrue);
    await app.drainOutbox();
    await app.askForMissingSlices();
    await app.sendOpenersAgain();
    await settle();
    expect(io.sent, isEmpty);
    expect(mem.rows('messages').single['sent'], 0);
    expect(tries('edits_out'), 0);
    expect(tries('pins_out'), 0);
    expect(tries('frames_out'), 0);
    // nothing reaches anyone one to one either
    final r = await app.introduce(_bob, 'someone-else');
    expect((r.toFirst, r.toSecond), (false, false));
    expect(io.sent, isEmpty);
  });

  test('left for the everyday side, each goes once', () async {
    await queued();
    useDatabasesForTest(db, Session(decoy));
    await app.drainOutbox();
    await app.receiptForTest(_bob, 'm1');
    await settle();
    expect(io.sent, isEmpty);

    useDatabasesForTest(db, Session(db));
    expect(app.everydayHeld, isFalse);
    await app.drainOutbox();
    await settle();
    await app.drainOutbox();
    await settle();
    expect(went(), [
      'edit e1',
      'pin p1',
      'reaction r1',
      'receipt m1',
      'text t1',
    ]);
    expect(mem.rows('messages').single['sent'], 1);
    for (final t in ['edits_out', 'pins_out', 'frames_out']) {
      expect(mem.rows(t), isEmpty, reason: t);
    }
  });

  test('a receipt waits on the everyday side, not in the decoy', () async {
    useDatabasesForTest(db, Session(decoy));
    await app.receiptForTest(_bob, 'm1');
    await settle();
    expect(io.sent, isEmpty);
    final row = mem.rows('frames_out').single;
    expect(
      (row['msg_uid'], row['kind'], row['peer_id']),
      ('m1', kFrameReceipt, _bob),
    );
    expect(decoy.mem.rows('frames_out'), isEmpty);
  });

  test('what arrives for the everyday side lands, and its receipt '
      'waits', () async {
    useDatabasesForTest(db, Session(decoy));
    final hi = await wrapMessage(
      'hello there',
      msgUid: 'in1',
      sender: asSender(_bob),
    );
    io.opens['c1'] = (_bob, hi);
    await app.receiveRelay([(peer: 'x-$_bob', cipher: 'c1')]);
    await settle();
    final got = [
      for (final r in mem.rows('messages'))
        if (r['direction'] == 'in') r['plaintext'],
    ];
    expect(got, ['hello there']);
    expect(decoy.mem.rows('messages'), isEmpty);
    expect(io.sent, isEmpty);
    expect(io.ticksFor('in1'), isEmpty);
    expect(mem.rows('frames_out').single['msg_uid'], 'in1');

    useDatabasesForTest(db, Session(db));
    await app.drainOutbox();
    await settle();
    expect(io.ticksFor('in1'), hasLength(1));
  });

  test('a decoy the run before left open holds it until a pin opens the '
      'everyday side, and then it goes', () async {
    await queued();
    app.quietMarkedForTest = true;
    expect(sessionQuiet, isFalse);
    expect(app.everydayHeld, isTrue);
    await app.drainOutbox();
    await app.receiptForTest(_bob, 'm1');
    await settle();
    expect(io.sent, isEmpty);

    app.revealGap = Duration.zero;
    await app.sessionFor(PinResult.normal);
    await settle();
    expect(app.everydayHeld, isFalse);
    expect(went(), [
      'edit e1',
      'pin p1',
      'reaction r1',
      'receipt m1',
      'text t1',
    ]);
  });

  group('the mark a run starts with', () {
    // a text waiting, so a hold and its end are seen on the wire
    Future<void> waiting() => _out(mem, 't1', _bob);

    Future<void> released() async {
      await settle();
      expect(app.everydayHeld, isFalse);
      expect(went(), ['text t1']);
    }

    test('a decoy left open, with the lock on, holds until a pin', () async {
      await waiting();
      await app.readDecoyMark(store: _Lock(quiet: true));
      expect(app.everydayHeld, isTrue);
      await app.drainOutbox();
      await settle();
      expect(io.sent, isEmpty);
      app.revealGap = Duration.zero;
      await app.sessionFor(PinResult.normal);
      await released();
    });

    test('none left open holds nothing', () async {
      await app.readDecoyMark(store: _Lock(quiet: false));
      expect(app.everydayHeld, isFalse);
    });

    test('a read that fails with the lock off holds nothing', () async {
      final lock = _Lock(table: false)..fails = 1000;
      await app.readDecoyMark(store: lock, retry: Duration.zero);
      expect(app.everydayHeld, isFalse);
    });

    test('a read that hangs with the lock off holds nothing', () async {
      final lock = _Lock(table: false)..hang = Completer();
      await app.readDecoyMark(
        store: lock,
        wait: const Duration(milliseconds: 20),
      );
      expect(app.everydayHeld, isFalse);
    });

    test('a read that fails with the lock on holds, is tried again, and its '
        'answer lets go', () async {
      await waiting();
      final lock = _Lock(quiet: false)..fails = 3;
      await app.readDecoyMark(
        store: lock,
        wait: const Duration(milliseconds: 20),
        retry: const Duration(milliseconds: 30),
      );
      expect(app.everydayHeld, isTrue);
      await app.drainOutbox();
      await settle();
      expect(io.sent, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await released();
    });

    test('a read that hangs with the lock on holds, and the late answer '
        'lets go', () async {
      await waiting();
      final lock = _Lock(quiet: false)..hang = Completer();
      await app.readDecoyMark(
        store: lock,
        wait: const Duration(milliseconds: 20),
      );
      expect(app.everydayHeld, isTrue);
      lock.hang!.complete();
      await released();
    });

    test('a late answer that a decoy is open keeps the hold', () async {
      await waiting();
      final lock = _Lock(quiet: true)..hang = Completer();
      await app.readDecoyMark(
        store: lock,
        wait: const Duration(milliseconds: 20),
      );
      lock.hang!.complete();
      await settle();
      expect(app.everydayHeld, isTrue);
      expect(io.sent, isEmpty);
    });
  });

  test('killed while held: the next run holds what waits until a pin, '
      'then each goes once', () async {
    await _out(mem, 't1', _bob);
    app.quietMarkedForTest = true;
    await app.receiptForTest(_bob, 'm1');
    await settle();
    expect(io.sent, isEmpty);
    // the process goes; a new one starts over the same database
    final next = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast'
      ..revealGap = Duration.zero;
    await next.readDecoyMark(store: _Lock(quiet: true));
    await next.drainOutbox();
    await settle();
    expect(io.sent, isEmpty);
    await next.sessionFor(PinResult.normal);
    await settle();
    await next.drainOutbox();
    await settle();
    expect(went(), ['receipt m1', 'text t1']);
  });

  group('owed in memory', () {
    Future<void> hidden() async {
      await list.putHidden(
        _vic,
        'peer',
        jsonEncode({'h': _vic, 'o': '', 'x': 'x-$_vic', 'bp': 1, 'vk': ''}),
        1,
      );
      await router.load();
    }

    test('a receipt to a shut vault\'s person goes once the decoy is left, '
        'and waits while the link is down', () async {
      await hidden();
      useDatabasesForTest(db, Session(decoy));
      await app.receiptForTest(_vic, 'h1');
      await settle();
      expect(io.sent, isEmpty);
      expect(app.receiptsOwedForTest, 1);

      useDatabasesForTest(db, Session(db));
      app.noteOnline(false);
      await app.drainOutbox();
      await app.replayForTest();
      await settle();
      expect(io.sent, isEmpty);
      expect(app.receiptsOwedForTest, 1);

      // a send that does not get through keeps it
      app.noteOnline(true);
      io.down = true;
      await app.replayForTest();
      await settle();
      expect(app.receiptsOwedForTest, 1);

      io.down = false;
      await app.drainOutbox();
      await settle();
      expect(io.ticksFor('h1'), hasLength(1));
      expect(app.receiptsOwedForTest, 0);
      await app.replayForTest();
      await settle();
      expect(io.ticksFor('h1'), hasLength(1));
    });

    test('a card owed goes once the decoy is left, kept until it went, and '
        'waits while the link is down', () async {
      app.myBundleForTest = () async => 'card';
      useDatabasesForTest(db, Session(decoy));
      expect(await app.bundleCtlForTest(_bob, want: true), isFalse);
      expect(app.ctlOwedForTest, isTrue);
      expect(io.sent, isEmpty);

      useDatabasesForTest(db, Session(db));
      app.noteOnline(false);
      await app.replayForTest();
      await settle();
      expect(io.sent, isEmpty);
      expect(app.ctlOwedForTest, isTrue);

      app.noteOnline(true);
      io.down = true;
      await app.replayForTest();
      await settle();
      expect(app.ctlOwedForTest, isTrue);

      io.down = false;
      // a minute past the try that did not go
      await Future<void>.delayed(const Duration(milliseconds: 10));
      app.bundleGapForTest = Duration.zero;
      await app.replayForTest();
      await settle();
      final asks = [
        for (final (_, c) in io.sent)
          if (c.contains('"halo_ctl":"bundle"')) c,
      ];
      expect(asks, hasLength(1));
      expect(asks.single, contains('"want":true'));
      expect(app.ctlOwedForTest, isFalse);
    });
  });

  test('a group pin a hold refuses waits in the lane and goes once', () async {
    await mem.insert('groups', {
      'group_id': 'g1',
      'name': 'G',
      'created_at': 1,
      'is_admin': 1,
    });
    await mem.insert('group_members', {
      'group_id': 'g1',
      'halo_id': _bob,
      'joined_at': 1,
    });
    await mem.insert('group_members', {
      'group_id': 'g1',
      'halo_id': 'me',
      'joined_at': 0,
    });
    app.quietMarkedForTest = true;
    await app.pinInGroup('g1', 'gm1', true);
    await settle();
    expect(io.sent, isEmpty);
    expect(mem.rows('group_ctl_out'), hasLength(1));

    app.revealGap = Duration.zero;
    await app.sessionFor(PinResult.normal);
    await settle();
    final pins = [
      for (final m in wire())
        if (m.pin != null) m.pin!.targetUid,
    ];
    expect(pins, ['gm1']);
    expect(mem.rows('group_ctl_out'), isEmpty);
  });
}
