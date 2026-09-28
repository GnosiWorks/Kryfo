// SPDX-License-Identifier: GPL-3.0-or-later
// a backup copies halo.db as bytes after folding the log into it. a fold
// that failed makes no copy: the backup would miss the latest messages and
// still say it was made. sqlite here is a stand-in on its channel
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const sqlite = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  late List<String> said;
  var foldFails = false;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('db_checkpoint');
    File(p.join(docs.path, 'halo.db')).writeAsStringSync('the database');
    said = [];
    foldFails = false;
    FlutterSecureStorage.setMockInitialValues({'halo.db.passphrase': 'pw'});
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    m.setMockMethodCallHandler(sqlite, (call) async {
      final args = call.arguments;
      final sql = args is Map ? '${args['sql'] ?? ''}' : '';
      said.add('${call.method} $sql'.trim());
      switch (call.method) {
        case 'openDatabase':
          return 1;
        case 'query':
          if (sql.contains('user_version')) {
            return {
              'columns': ['user_version'],
              'rows': [
                [56],
              ],
            };
          }
          return {
            'columns': ['n'],
            'rows': [
              [1],
            ],
          };
        case 'execute':
          if (foldFails && sql.contains('wal_checkpoint')) {
            throw PlatformException(code: 'sqlite_error', message: 'disk');
          }
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    m.setMockMethodCallHandler(sqlite, null);
    m.setMockMethodCallHandler(paths, null);
    docs.deleteSync(recursive: true);
  });

  test('a copy follows the fold', () async {
    final db = HaloDb();
    final to = p.join(docs.path, 'copy.db');
    await db.copyTo(to);
    expect(File(to).readAsStringSync(), 'the database');
    expect(said, contains('execute PRAGMA wal_checkpoint(TRUNCATE)'));
  });

  test('a fold that failed makes no copy', () async {
    final db = HaloDb();
    await db.open();
    foldFails = true;
    final to = p.join(docs.path, 'copy.db');
    await expectLater(db.copyTo(to), throwsA(isA<DatabaseException>()));
    expect(File(to).existsSync(), isFalse);
    await expectLater(db.checkpoint(), throwsA(isA<DatabaseException>()));
  });
}
