// SPDX-License-Identifier: GPL-3.0-or-later
// the heal (KHB1, identity v4 3.8) as this phone makes and checks it, the
// tables it keeps, and who a restore pauses (Q20). the frames go through
// the shim's own parser; without the host library those tests skip
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/heal.dart';
import 'package:kryfo/invites.dart' show unixHours;
import 'package:kryfo/main.dart' show HaloDb;
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'mem_db.dart';
import 'signal_kit.dart';
import 'signal_ls/shim_lib.dart' show needsShim;
import 'sqlite_channel.dart';

const _day = 24 * 3600 * 1000;
const _hour = 3600 * 1000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the frame', () {
    test(
      'a heal from a phone reads back whole: its identity signs it, the '
      'block is device 1 on a one-time kyber, and the checks take it',
      () async {
        final ana = await testStore();
        final ben = await testStore();
        final now = DateTime.now().millisecondsSinceEpoch;
        final b = await makeHeal(ana, peer: ben.identity.public, nowMs: now);
        // 1,904 bytes from a phone (3.8)
        expect(b.length, 1904);
        final h = ana.lib.parseHeal(b);
        expect(h.restored, isFalse);
        expect(h.since, 0);
        expect(h.issued, unixHours(now));
        expect(h.identity, ana.identity.public);
        expect(h.peer, ben.identity.public);
        expect(h.signer, ana.identity.public);
        expect(h.block.deviceId, 1);
        expect(h.block.key, isNull);
        expect(
          checkHeal(
            h,
            held: ana.identity.public,
            mine: ben.identity.public,
            nowMs: now,
          ),
          isNull,
        );
        // its kyber is one made for this heal alone
        final heal = await ana.database.query(
          'kyber_prekeys',
          where: 'use = ?',
          whereArgs: ['heal'],
        );
        expect(heal, hasLength(1));
        expect(h.block.bundle.kyberPreKeyId, heal.single['id']);
        // two heals never share a nonce or a kyber
        final again = ana.lib.parseHeal(
          await makeHeal(ana, peer: ben.identity.public, nowMs: now),
        );
        expect(again.nonce, isNot(h.nonce));
        expect(
          again.block.bundle.kyberPreKeyId,
          isNot(h.block.bundle.kyberPreKeyId),
        );
      },
      skip: needsShim,
    );

    test('after a restore it says so, and since names a whole day', () async {
      final ana = await testStore();
      final ben = await testStore();
      final now = DateTime.now().millisecondsSinceEpoch;
      final day = healDayOf(now - 3 * _day);
      final h = ana.lib.parseHeal(
        await makeHeal(ana, peer: ben.identity.public, since: day, nowMs: now),
      );
      expect(h.restored, isTrue);
      expect(h.since, day);
      expect(healSinceMs(h), day * _hour);
      expect(day % 24, 0);
      await expectLater(
        makeHeal(ana, peer: ben.identity.public, since: day + 1),
        throwsArgumentError,
      );
    }, skip: needsShim);

    test('each check refuses on its own', () async {
      final ana = await testStore();
      final ben = await testStore();
      final eve = await testStore();
      final now = DateTime.now().millisecondsSinceEpoch;
      LsHeal at(int t) => ana.lib.parseHeal(
        // sync: the store work is awaited below
        _made[t]!,
      );
      for (final t in [
        now,
        now - 16 * _day,
        now + 25 * _hour,
        now - 14 * _day,
      ]) {
        _made[t] = await makeHeal(ana, peer: ben.identity.public, nowMs: t);
      }
      HealRefused? check(LsHeal h, {List<int>? held, List<int>? mine}) =>
          checkHeal(
            h,
            held: held ?? ana.identity.public,
            mine: mine ?? ben.identity.public,
            nowMs: now,
          );
      // not the key held for them
      expect(check(at(now), held: eve.identity.public), HealRefused.notTheirs);
      // made for someone else
      expect(check(at(now), mine: eve.identity.public), HealRefused.notMine);
      // older than a wrap lives, and too far ahead
      expect(check(at(now - 16 * _day)), HealRefused.stale);
      expect(check(at(now + 25 * _hour)), HealRefused.stale);
      expect(check(at(now - 14 * _day)), isNull);
      // a byte changed: the signature no longer holds, the parser refuses
      final bad = Uint8List.fromList(_made[now]!);
      bad[30] ^= 1;
      expect(() => ana.lib.parseHeal(bad), throwsA(isA<LsError>()));
      // signed by another key over the same body: refused too
      final body = _made[now]!.sublist(0, _made[now]!.length - 64);
      expect(
        () => ana.lib.parseHeal([...body, ...List.filled(64, 7)]),
        throwsA(isA<LsError>()),
      );
    }, skip: needsShim);

    test('a heal signed by a linked device (the shim\'s vector, 1,937 bytes) '
        'reads, and this phone refuses it until device lists are held', () {
      final line = File(
        'native/kryfo_signal/testdata/formats_v1.txt',
      ).readAsLinesSync().singleWhere((l) => l.startsWith('good heal_device '));
      final hex = line.split(' ').last;
      final b = Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
      expect(b.length, 1937);
      final h = KryfoSignal.shared.parseHeal(b);
      expect(h.block.deviceId, isNot(1));
      expect(h.signer, isNot(h.identity));
      expect(
        checkHeal(h, held: h.identity, mine: h.peer, nowMs: h.issued * _hour),
        HealRefused.device,
      );
    }, skip: needsShim);

    test('on the wire it is a json frame a 0.5.x reader drops', () {
      final w = healWire([1, 2, 3]);
      expect(w, startsWith('{"halo_ctl":"heal"'));
      expect(healOfWire(w), [1, 2, 3]);
      // the json heal is not one, nor anything else
      expect(healOfWire('{"halo_ctl":"bundle","bundle":"x"}'), isNull);
      expect(healOfWire('not json'), isNull);
      expect(healOfWire('{"halo_ctl":"heal","b":"${'A' * 4100}"}'), isNull);
    });
  });

  group('kept', () {
    test('a nonce is taken once in 16 days, per identity', () async {
      final db = MemDb();
      await healTables(db);
      await healTables(db);
      final t = DateTime.now().millisecondsSinceEpoch;
      final n = List.filled(16, 9);
      expect(await noteHealNonce(db, 0, n, nowMs: t), isTrue);
      expect(await noteHealNonce(db, 0, n, nowMs: t + _day), isFalse);
      expect(await noteHealNonce(db, 1, n, nowMs: t + _day), isTrue);
      // kept to its last millisecond, gone after
      final keep = kHealNonceKeep.inMilliseconds;
      expect(await noteHealNonce(db, 0, n, nowMs: t + keep - 1), isFalse);
      expect(await noteHealNonce(db, 2, n, nowMs: t), isTrue);
      expect(await noteHealNonce(db, 2, n, nowMs: t + keep), isTrue);
    });

    test('a nonce outlives the freshest heal it could belong to', () async {
      final ana = await testStore();
      final ben = await testStore();
      final t = DateTime.now().millisecondsSinceEpoch;
      // issued a day ahead of this clock, the most that is taken
      final b = await makeHeal(
        ana,
        peer: ben.identity.public,
        nowMs: t + kHealAhead.inMilliseconds,
      );
      final h = ana.lib.parseHeal(b);
      HealRefused? at(int now) => checkHeal(
        h,
        held: ana.identity.public,
        mine: ben.identity.public,
        nowMs: now,
      );
      final db = MemDb();
      expect(await noteHealNonce(db, 0, h.nonce, nowMs: t), isTrue);
      // the last hour it is fresh, the nonce is still known
      final lastFresh = (h.issued + kHealOldest.inHours) * _hour + _hour - 1;
      expect(at(lastFresh), isNull);
      expect(lastFresh - t, lessThan(kHealNonceKeep.inMilliseconds));
      expect(await noteHealNonce(db, 0, h.nonce, nowMs: lastFresh), isFalse);
      expect(at(lastFresh + 1), HealRefused.stale);
    }, skip: needsShim);

    test('one issued before the restore, or before the last heal taken from '
        'them, is older', () async {
      final ana = await testStore();
      final ben = await testStore();
      final t = DateTime.now().millisecondsSinceEpoch;
      final h = ana.lib.parseHeal(
        await makeHeal(ana, peer: ben.identity.public, nowMs: t - 2 * _hour),
      );
      HealRefused? at({int? restoredAt, int? lastIssued}) => checkHeal(
        h,
        held: ana.identity.public,
        mine: ben.identity.public,
        nowMs: t,
        restoredAt: restoredAt,
        lastIssued: lastIssued,
      );
      expect(at(), isNull);
      expect(at(restoredAt: t), HealRefused.older);
      // in hours, as issued: the restore's own hour takes it
      expect(at(restoredAt: h.issued * _hour + _hour - 1), isNull);
      expect(at(lastIssued: h.issued + 1), HealRefused.older);
      expect(at(lastIssued: h.issued), isNull);
    }, skip: needsShim);

    test('kept for the identity it came to', () async {
      final db = MemDb();
      final t = DateTime.now().millisecondsSinceEpoch;
      final n = List.filled(16, 3);
      expect(await noteHealNonce(db, 5, n, nowMs: t), isTrue);
      expect(await noteHealNonce(db, 6, n, nowMs: t), isTrue);
    });

    test(
      'a line holds them until the person looks; other lines do not',
      () async {
        final db = MemDb();
        await healTables(db);
        await addHealLine(
          db,
          'ana',
          at: 10,
          kind: kHealLineRestored,
          held: true,
        );
        await addHealLine(db, 'ben', at: 11, kind: kHealLineRepair);
        expect(await healHoldOf(db, 'ana'), kHealLineRestored);
        expect(await healHoldOf(db, 'ben'), isNull);
        expect(await healHeldPeers(db), {'ana'});
        expect(await healLinesOf(db, 'ana'), [
          (at: 10, kind: kHealLineRestored),
        ]);
        await dropHealHold(db, 'ana');
        expect(await healHoldOf(db, 'ana'), isNull);
        expect(await healHeldPeers(db), isEmpty);
        // the line stays where it happened
        expect(await healLinesOf(db, 'ana'), hasLength(1));
        // rows from before the table hold no one
        expect(await healHoldOf(MemDb(), 'ana'), isNull);
        expect(await healHeldPeers(MemDb()), isEmpty);
      },
    );

    test(
      "since is the day of their last message here, else the file's day",
      () async {
        final db = MemDb();
        const t = 1790000000000;
        await db.insert('messages', {
          'peer_id': 'ana',
          'plaintext': '',
          'direction': 'in',
          'sent_at': t - 5 * _day,
        });
        await db.insert('messages', {
          'peer_id': 'ana',
          'plaintext': '',
          'direction': 'in',
          'sent_at': t - 2 * _day,
        });
        // ours and a group's say nothing of what they sent us
        await db.insert('messages', {
          'peer_id': 'ana',
          'plaintext': '',
          'direction': 'out',
          'sent_at': t,
        });
        await db.insert('messages', {
          'peer_id': 'ana',
          'plaintext': '',
          'direction': 'in',
          'sent_at': t - _day,
          'group_id': 'g1',
        });
        expect(
          await healSinceFor(db, 'ana', fallbackMs: t),
          healDayOf(t - 2 * _day),
        );
        expect(await healSinceFor(db, 'ben', fallbackMs: t), healDayOf(t));
      },
    );
  });

  group('on a real database', () {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    late Directory docs;
    SqliteChannel? sql;
    final opened = <HaloDb>[];

    setUp(() {
      sql = SqliteChannel.install();
      docs = Directory.systemTemp.createTempSync('heal_test');
      // a 0.5.3 phone's own file: its upgrade runs on the first open
      File(
        'test/fixtures/upgrade_053/halo.db',
      ).copySync(p.join(docs.path, 'halo.db'));
      m.setMockMethodCallHandler(paths, (_) async => docs.path);
      final keys =
          (jsonDecode(
                    File(
                      'test/fixtures/upgrade_053/keys.json',
                    ).readAsStringSync(),
                  )
                  as Map)['everyday']
              as String;
      FlutterSecureStorage.setMockInitialValues({'halo.db.passphrase': keys});
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      for (final d in opened) {
        await d.close();
      }
      opened.clear();
      sql?.uninstall();
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    bool skip() {
      if (sql != null) return false;
      markTestSkipped('no sqlite on this host');
      return true;
    }

    Future<Database> open() async {
      final d = HaloDb();
      opened.add(d);
      return d.open();
    }

    Future<Set<String>> tables(Database db) async => {
      for (final r in await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        r['name'] as String,
    };

    test('a file that took a later version without them gets the tables '
        'at its next open', () async {
      if (skip()) return;
      var db = await open();
      expect(await tables(db), containsAll(['heal_lines', 'heal_nonces']));
      // as a file at this version would be that never made them: one that
      // phase 6 or linked step 7 numbered first is the same to the open
      await db.execute('DROP TABLE heal_lines');
      await db.execute('DROP TABLE heal_nonces');
      for (final d in opened) {
        await d.close();
      }
      opened.clear();
      db = await open();
      expect(await tables(db), containsAll(['heal_lines', 'heal_nonces']));
      await addHealLine(db, 'x', at: 1, kind: kHealLineRepair, held: true);
      expect(await healHeldPeers(db), {'x'});
    });

    test('older contacts are those without a capability list, never the '
        'blocked, the unaccepted or the dev chat', () async {
      if (skip()) return;
      final db = await open();
      final before = await olderContacts(db, isDev: (_) => false);
      // every contact of a 0.5.3 file: none sent a list
      expect(before, isNotEmpty);
      final first = before.first.id;
      await db.update(
        'contacts',
        {'caps': 'pp,ty'},
        where: 'halo_id = ?',
        whereArgs: [first],
      );
      Future<List<String>> ids({bool Function(String)? dev}) async => [
        for (final c in await olderContacts(db, isDev: dev ?? (_) => false))
          c.id,
      ];
      expect(await ids(), isNot(contains(first)));
      expect(await ids(), hasLength(before.length - 1));
      if (before.length > 1) {
        final second = before[1].id;
        await db.update(
          'contacts',
          {'blocked': 1},
          where: 'halo_id = ?',
          whereArgs: [second],
        );
        expect(await ids(), isNot(contains(second)));
      }
      expect(await ids(dev: (_) => true), isEmpty);
      expect(olderKryfo(null), isTrue);
      expect(olderKryfo(''), isTrue);
      expect(olderKryfo('pp'), isFalse);
    });
  });
}

final _made = <int, Uint8List>{};
