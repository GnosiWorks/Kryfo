// SPDX-License-Identifier: GPL-3.0-or-later
// an upgrade adds a column and goes on only when there is nothing to add:
// the column is there already, or its table comes whole from an older
// step. any other failure stops the upgrade, so the version does not move
// past a column that was never added
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show addColumn;
import 'package:sqflite_sqlcipher/sqflite.dart' show DatabaseExecutor;

class _Db implements DatabaseExecutor {
  _Db(this.error);
  final String? error;
  final ran = <String>[];

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    ran.add(sql);
    if (error != null) throw Exception(error);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

const _alter = 'ALTER TABLE messages ADD COLUMN sticker TEXT';

void main() {
  test('a column added runs its statement', () async {
    final db = _Db(null);
    await addColumn(db, _alter);
    expect(db.ran, [_alter]);
  });

  test('a column already there is taken as added', () async {
    await addColumn(
      _Db('DatabaseException(duplicate column name: sticker (code 1))'),
      _alter,
    );
  });

  test('a table an older step makes is left to that step', () async {
    await addColumn(
      _Db('DatabaseException(no such table: messages (code 1))'),
      _alter,
    );
  });

  for (final e in [
    'DatabaseException(disk I/O error (code 10))',
    'DatabaseException(database or disk is full (code 13))',
    'DatabaseException(database is locked (code 5))',
  ]) {
    test('any other failure stops the upgrade: $e', () async {
      await expectLater(addColumn(_Db(e), _alter), throwsException);
    });
  }

  test('every ALTER in the app goes through it', () {
    for (final f in [
      'lib/main.dart',
      'lib/router.dart',
      'lib/devchat/dev_chat.dart',
      'lib/devchat/support.dart',
    ]) {
      final src = File(f).readAsStringSync();
      final all = RegExp(r"'ALTER TABLE").allMatches(src).length;
      final through = RegExp(
        r"addColumn\(\s*db,\s*'ALTER TABLE",
      ).allMatches(src).length;
      expect(through, all, reason: f);
    }
  });
}
