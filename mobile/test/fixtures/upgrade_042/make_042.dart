// SPDX-License-Identifier: GPL-3.0-or-later
// makes the 0.4.2 file the upgrade test opens. it runs inside a 0.4.2
// checkout (make_042.sh <checkout>), so the schema, onCreate and every row
// come from 0.4.2's own code: halo.db with a 1:1 chat and a group, each
// with rows that came in out of the order they were sent
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'sqlite_channel.dart';

const me = 'quiet-maple-harbor';
const alice = 'amber-otter-lake';
const bob = 'brisk-cedar-moon';
const gid = 'g0a1b2c3d4e5f60718293a4b5c6d7e8f9';
final everydayKey = '0e' * 32;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['UPGRADE_OUT'] ?? '';
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory docs;
  late SqliteChannel sql;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('make_042');
    // a fixed test key, which no secret scanner takes for a real one
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': everydayKey,
    });
    SharedPreferences.setMockInitialValues({});
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    sql = SqliteChannel.install()!;
  });

  tearDown(() => sql.uninstall());

  test('the database', () async {
    expect(out, isNotEmpty, reason: 'UPGRADE_OUT names where they go');
    final db = HaloDb();
    final raw = await db.open();
    final v = await raw.rawQuery('PRAGMA user_version');
    expect(v.first.values.first, 51);
    await db.saveIdentity(me, '07' * 32, '08' * 32);
    await db.upsertContact(alice, 'alice.onion', 'ab' * 32);
    await db.upsertContact(bob, 'bob.onion', 'cd' * 32);
    await db.createGroup(gid, 'Walks', [me, alice, bob], isAdmin: true);
    // each row as 0.4.2 writes it, its time set after: 0.4.2 stamps a row
    // with when it came
    Future<void> row(
      String peer,
      String dir,
      String text,
      String uid,
      int at, {
      String? group,
    }) async {
      await db.saveMessage(peer, dir, text, msgUid: uid, groupId: group);
      await raw.update(
        'messages',
        {'sent_at': at},
        where: 'msg_uid = ?',
        whereArgs: [uid],
      );
    }

    const t = 1767225600000;
    await row(alice, 'out', 'are you up', 'a1', t);
    await row(alice, 'in', 'yes', 'a2', t + 60000);
    await row(alice, 'in', 'what time', 'a3', t + 120000);
    // a late one, stored after the two above with an earlier time
    await row(alice, 'in', 'morning', 'a4', t + 30000);
    await row(alice, 'out', 'nine', 'a5', t + 180000);
    await row(me, 'out', 'walk at ten', 'g1', t + 200000, group: gid);
    await row(bob, 'in', 'in', 'g2', t + 260000, group: gid);
    await row(alice, 'in', 'me too', 'g3', t + 230000, group: gid);
    await raw.close();
    await File(p.join(docs.path, 'halo.db')).copy(p.join(out, 'halo.db'));
  });
}
