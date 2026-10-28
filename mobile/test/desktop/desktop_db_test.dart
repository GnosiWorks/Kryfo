// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop database through sqflite_sqlcipher's own api, its channel
// answered by the desktop messenger on the sqlcipher linux/build-sqlcipher.sh
// builds
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_channels.dart';
import 'package:kryfo/desktop/desktop_db.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

final _lib = p.absolute('linux/out/libsqlcipher.so.0');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final there = File(_lib).existsSync();
  final skip = there ? false : 'no sqlcipher built (linux/build-sqlcipher.sh)';
  late Directory dir;

  setUpAll(() {
    if (!there) return;
    final db = DesktopDb(libraries: [_lib]);
    final m = DesktopMessenger(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      {sqlcipherChannel: (c) => db.call(c.method, c.arguments)},
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          sqlcipherChannel,
          (bytes) async => m.send(sqlcipherChannel, bytes),
        );
  });
  setUp(() => dir = Directory.systemTemp.createTempSync('desktop_db'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> make(String path, String key) async {
    final db = await openDatabase(
      path,
      password: key,
      version: 1,
      singleInstance: false,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE m (id INTEGER PRIMARY KEY, body TEXT UNIQUE)',
      ),
    );
    await db.insert('m', {'body': 'meet at the north gate'});
    await db.close();
  }

  test('the file on disk is not readable sqlite', () async {
    final path = p.join(dir.path, 'a.db');
    await make(path, 'k1');
    final raw = File(path).readAsBytesSync();
    expect(latin1.decode(raw.sublist(0, 15)), isNot('SQLite format 3'));
    expect(latin1.decode(raw).contains('north gate'), isFalse);
  }, skip: skip);

  test('the same key opens it again, quotes and all', () async {
    final path = p.join(dir.path, 'b.db');
    await make(path, "it's k2");
    final db = await openDatabase(path, password: "it's k2");
    expect((await db.query('m')).single['body'], 'meet at the north gate');
    await db.close();
  }, skip: skip);

  test('a raw key as the app gives it opens, and attaches', () async {
    final key = "x'${'ab' * 32}'";
    final a = p.join(dir.path, 'c.db'), b = p.join(dir.path, 'd.db');
    await make(a, key);
    await make(b, "x'${'cd' * 32}'");
    final db = await openDatabase(a, password: key);
    await db.execute('ATTACH DATABASE ? AS other KEY ?', [
      b,
      "x'${'cd' * 32}'",
    ]);
    expect(
      (await db.rawQuery('SELECT body FROM other.m')).single['body'],
      'meet at the north gate',
    );
    await db.close();
  }, skip: skip);

  test('a wrong key does not open it', () async {
    final path = p.join(dir.path, 'e.db');
    await make(path, 'k3');
    await expectLater(openDatabase(path, password: 'k4'), throwsA(anything));
  }, skip: skip);

  test('no key, no file', () async {
    final path = p.join(dir.path, 'f.db');
    await expectLater(openDatabase(path), throwsA(anything));
    await expectLater(openDatabase(path, password: ''), throwsA(anything));
    final f = File(path);
    // the open made the file; nothing was written into it
    expect(!f.existsSync() || f.lengthSync() == 0, isTrue);
  }, skip: skip);

  test('sqlite errors arrive as the phone gives them', () async {
    final path = p.join(dir.path, 'g.db');
    await make(path, 'k5');
    final db = await openDatabase(path, password: 'k5');
    try {
      await db.insert('m', {'body': 'meet at the north gate'});
      fail('a second row with the same body went in');
    } on DatabaseException catch (e) {
      expect(e.isUniqueConstraintError(), isTrue);
    } finally {
      await db.close();
    }
  }, skip: skip);

  test('a batch and a transaction go through', () async {
    final path = p.join(dir.path, 'h.db');
    await make(path, 'k6');
    final db = await openDatabase(path, password: 'k6');
    await db.transaction((t) async {
      final b = t.batch()
        ..insert('m', {'body': 'one'})
        ..insert('m', {'body': 'two'});
      await b.commit(noResult: true);
    });
    expect(
      Sqflite.firstIntValue(await db.rawQuery('SELECT count(*) FROM m')),
      3,
    );
    await db.close();
  }, skip: skip);

  test('an unknown call says not here', () async {
    final m = DesktopMessenger(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      {'x/y': (_) => notHere},
    );
    final r = await m.send(
      'x/y',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('z')),
    );
    expect(r, isNull);
  });
}
