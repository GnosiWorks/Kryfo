// SPDX-License-Identifier: GPL-3.0-or-later
// the old switch for the whole app is gone. a phone that had it on asks
// once on home whether every chat should block: only once a chat's phone
// knows the block, never in a decoy and never with the hidden chats open.
// yes turns it on in the everyday chats that can and leaves the rest off;
// either answer ends the card for good. nothing changes without it. the
// window keeps what the app lock and the screens that hold it give it
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, shotsColumns, useDatabasesForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database, DatabaseExecutor;
import 'dart:io';

import 'arrival_fakes.dart';
import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

// what an upgrade asks of the database
class _Sql implements DatabaseExecutor {
  final said = <String>[];
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async =>
      said.add(sql);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _person(MemDb mem, String id, {int can = 0}) =>
    mem.insert('contacts', {
      'halo_id': id,
      'onion': 'o-$id',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'shots_can': can,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<bool> told;
  late MemDb mem;
  late _Rows db;

  setUp(() async {
    told = [];
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'block_screenshots': 'true'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), (
          call,
        ) async {
          if (call.method == 'setSecure') {
            told.add((call.arguments as Map)['on'] as bool);
          }
          return null;
        });
    mem = MemDb();
    db = _Rows(mem);
    await _person(mem, 'bob', can: 50);
    await _person(mem, 'carol');
    useDatabasesForTest(db, Session(db));
  });

  Future<AppState> make() async {
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    final app = AppState(io: ArrivalIo(), router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    await app.loadScreenSecure();
    return app;
  }

  Map<String, bool> on() => {
    for (final r in mem.rows('contacts'))
      r['halo_id'] as String: ChatShots.ofRow(r).on,
  };

  test('the old switch on: nothing changes by itself, and the whole '
      'window stays covered until the card is answered', () async {
    final app = await make();
    expect(app.shotsCardDue, isTrue);
    expect(on(), {'bob': false, 'carol': false});
    expect(told, [true]);
    await app.answerShotsCard(on: false);
    expect(told, [true, false]);
  });

  test(
    'yes: every chat whose phone can, and the card is gone for good',
    () async {
      final app = await make();
      expect(await app.answerShotsCard(on: true), 1);
      expect(on(), {'bob': true, 'carol': false});
      expect(ChatShots.ofRow(mem.rows('contacts').first).by, kShotsByMe);
      expect(app.shotsCardDue, isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'block_screenshots'),
        isNull,
      );
      expect((await make()).shotsCardDue, isFalse);
      expect(told.last, isFalse);
    },
  );

  test('no: nothing changes, and the card is gone for good', () async {
    final app = await make();
    expect(await app.answerShotsCard(on: false), 0);
    expect(on(), {'bob': false, 'carol': false});
    expect((await make()).shotsCardDue, isFalse);
  });

  test('it shows at once; with no chat that can yet, a yes waits and '
      'never says none', () async {
    await mem.update('contacts', {'shots_can': 0});
    final app = await make();
    expect(app.shotsCardDue, isTrue);
    expect(app.shotsCardCan, isFalse);
    expect(await app.answerShotsCard(on: true), 0);
    expect(app.shotsCardDue, isTrue);
    expect(told.last, isTrue);
    expect(
      await const FlutterSecureStorage().read(key: 'block_screenshots'),
      'true',
    );
    // a chat's phone says it knows the block: the yes is there
    await mem.update(
      'contacts',
      {'shots_can': 50},
      where: 'halo_id = ?',
      whereArgs: ['bob'],
    );
    final again = await make();
    expect(again.shotsCardCan, isTrue);
    expect(await again.answerShotsCard(on: true), 1);
  });

  test('never with the old switch off', () async {
    FlutterSecureStorage.setMockInitialValues({});
    expect((await make()).shotsCardDue, isFalse);
  });

  test('never in a decoy, never with the hidden chats open', () async {
    final app = await make();
    final decoy = _Rows(MemDb(), HaloContainer.decoy);
    useDatabasesForTest(db, Session(decoy));
    expect(app.shotsCardDue, isFalse);
    useDatabasesForTest(db, Session(db));
    lockState.inVault = true;
    addTearDown(() => lockState.inVault = false);
    expect(app.shotsCardDue, isFalse);
  });

  test('a yes never reaches a hidden chat', () async {
    final hidden = MemDb();
    await _person(hidden, 'dan', can: 50);
    final vault = _Rows(hidden, HaloContainer.vault);
    final app = await make();
    useDatabasesForTest(db, await Session.withVault(db, vault));
    await app.answerShotsCard(on: true);
    expect(ChatShots.ofRow(hidden.rows('contacts').single).on, isFalse);
    expect(on()['bob'], isTrue);
  });

  test('the upgrade adds the columns, after every older step', () async {
    final sql = _Sql();
    await shotsColumns(sql);
    expect(sql.said, [
      for (final c in ChatShots.columns)
        'ALTER TABLE contacts ADD COLUMN $c INTEGER NOT NULL DEFAULT 0',
    ]);
    final src = File('lib/main.dart').readAsStringSync();
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), greaterThanOrEqualTo(83));
    final at = src.indexOf('if (oldV < 83) {');
    expect(at, greaterThan(0));
    expect(src.substring(at, at + 120), contains('await shotsColumns(db);'));
    for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(src)) {
      if (int.parse(m.group(1)!) < 83) expect(m.start, lessThan(at));
    }
    // a new install has them from the start
    final fresh = MemDb();
    await fresh.insert('contacts', {
      'halo_id': 'x',
      'onion': '',
      'xpub': '',
      'first_seen': 1,
      'last_seen': 1,
    });
    final row = fresh.rows('contacts').single;
    for (final c in ChatShots.columns) {
      expect(row[c], 0, reason: c);
    }
  });
}
