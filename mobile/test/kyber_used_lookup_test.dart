// SPDX-License-Identifier: GPL-3.0-or-later
// a last resort kyber key that never expires (the dev chat's) takes one
// base key per install that opens on it. every row stays, so a replayed
// opener is refused, and the check is one lookup on the primary key on a
// real sqlite, not a read of every row. its own file, as an isolate loads
// one sqlite for good
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show kyberTables;
import 'package:kryfo/signal_stores.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

const _plain = '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0';

Uint8List _key(int i) => Uint8List.fromList([
  5,
  i >> 8,
  i & 0xff,
  for (var b = 0; b < 30; b++) (i * 31 + b) & 0xff,
]);

// the store's queries on the real database, with the rows each brought
class _Spy implements DatabaseExecutor {
  _Spy(this.db);
  final Database db;
  var read = 0;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final r = await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    read += r.length;
    return r;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) => db.insert(table, values, conflictAlgorithm: conflictAlgorithm);

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      db.delete(table, where: where, whereArgs: whereArgs);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('db: ${i.memberName}');
}

void main() {
  final skip = File(_plain).existsSync() ? false : 'no system sqlite here';
  late Database db;

  setUp(() async {
    open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open(_plain));
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await kyberTables(db);
  });

  tearDown(() => db.close());

  for (final prefix in const ['', kDevSignalPrefix]) {
    test('a used base key is refused, every row kept, one lookup '
        '(${prefix.isEmpty ? 'main' : 'dev'})', () async {
      final spy = _Spy(db);
      final k = LsKyberPreKeyStore(spy, prefix: prefix);
      await k.store(7, Uint8List.fromList([1, 2, 3]), lastResort: true);
      for (var i = 0; i < 500; i++) {
        await k.markUsed(7, 1, _key(i));
        await k.markRead(7, _key(i));
      }
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM ${prefix}kyber_used',
      );
      expect(rows.single['n'], 500);
      // a copy of the bytes, as an opener read again brings them, found
      // without reading the other rows
      spy.read = 0;
      expect(await k.wasUsed(7, List<int>.of(_key(321))), isTrue);
      expect(await k.wasRead(7, List<int>.of(_key(0))), isTrue);
      expect(spy.read, 2);
      expect(await k.wasUsed(7, _key(500)), isFalse);
      expect(await k.wasRead(7, _key(500)), isFalse);
      // a prefix of a used key is another key
      expect(await k.wasUsed(7, _key(3).sublist(0, 32)), isFalse);
      // another kyber key or identity never matches
      expect(await k.wasUsed(8, _key(3)), isFalse);
      expect(
        await LsKyberPreKeyStore(
          db,
          prefix: prefix,
          ident: 1,
        ).wasUsed(7, _key(3)),
        isFalse,
      );
      for (final (t, c) in [
        ('kyber_used', 'base_key'),
        ('opener_reads', 'opener'),
      ]) {
        final plan = await db.rawQuery(
          'EXPLAIN QUERY PLAN SELECT kyber_id FROM $prefix$t '
          'WHERE ident = ? AND kyber_id = ? AND $c = ? LIMIT 1',
          [0, 7, _key(1)],
        );
        final how = plan.map((r) => r['detail']).join(' ');
        expect(how, contains('INDEX'));
        expect(how, contains('$c=?'));
      }
      // the key's own removal still takes its rows with it
      await k.remove(7);
      expect(await k.wasUsed(7, _key(321)), isFalse);
    }, skip: skip);
  }
}
