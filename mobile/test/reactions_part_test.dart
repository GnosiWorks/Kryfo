// SPDX-License-Identifier: GPL-3.0-or-later
// a window or a long thread asks for the reactions of many rows at once:
// sqlite binds a bounded number of values in one statement, so they are
// read in parts and every one still comes back
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb, kReactionsPart;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'sqlite_ffi.dart';

class _Db extends HaloDb {
  _Db(this.mem);
  final SqliteMem mem;
  @override
  Future<Database> open() async => mem;
}

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  test('forty thousand uids: every reaction read, in parts', () async {
    final mem = SqliteMem.open()!;
    await mem.execute(
      'CREATE TABLE reactions (msg_uid TEXT, reactor TEXT, emoji TEXT)',
    );
    const n = 40000;
    await mem.execute('BEGIN');
    for (var i = 0; i < n; i += 7) {
      await mem.execute('INSERT INTO reactions VALUES (?, ?, ?)', [
        'u$i',
        '',
        '❤',
      ]);
    }
    await mem.execute('COMMIT');
    final got = await _Db(mem).loadReactionsFor([
      for (var i = 0; i < n; i++) 'u$i',
    ]);
    expect(got.length, (n + 6) ~/ 7);
    expect(got['u7']!.single.value, '❤');
    expect(kReactionsPart, lessThanOrEqualTo(999));
  }, skip: skip);
}
