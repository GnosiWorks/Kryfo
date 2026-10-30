// SPDX-License-Identifier: GPL-3.0-or-later
// kept translations through every upgrade: a file from 0.5.0 and 0.5.1
// that had translate_kept and its triggers keeps both once it opens at
// this version, so a migration that makes messages or contacts again must
// make them too. a message or contact delete then still takes its row
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/translate/settings.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlite_channel.dart';

const _triggers = [
  'translate_kept_gone',
  'translate_kept_edited',
  'translate_kept_follow',
  'translate_prefs_follow',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  SqliteChannel? sql;
  late Directory docs;

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('translate_upgrade');
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    SharedPreferences.setMockInitialValues({});
    useDevKeysForTest(null);
  });

  tearDown(() {
    sql?.uninstall();
    m.setMockMethodCallHandler(paths, null);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  for (final from in const ['upgrade_050', 'upgrade_051']) {
    for (final f in const ['halo.db', 'halo_v.db']) {
      test(
        '$from $f: the table and its triggers outlive the upgrade',
        () async {
          if (sql == null) {
            markTestSkipped('no sqlite on this host');
            return;
          }
          final dir = 'test/fixtures/$from';
          final keys =
              (jsonDecode(File('$dir/keys.json').readAsStringSync()) as Map)
                  .cast<String, String>();
          FlutterSecureStorage.setMockInitialValues({
            'halo.db.passphrase': keys['everyday']!,
          });
          final path = p.join(docs.path, f);
          File('$dir/$f').copySync(path);

          // the old file, as the translate code left it before the upgrade
          final old = await openDatabase(path, singleInstance: false);
          final msg = await old.rawQuery(
            'SELECT msg_uid, peer_id, plaintext FROM messages WHERE msg_uid '
            "IS NOT NULL AND plaintext != '' AND peer_id IN (SELECT halo_id "
            'FROM contacts) LIMIT 2',
          );
          expect(msg, isNotEmpty, reason: 'a message with a contact');
          final store = DbTranslateStore(() async => old);
          for (final r in msg) {
            await store.keep(
              r['peer_id'] as String,
              r['msg_uid'] as String,
              KeptTranslation(
                KeptTranslation.hashOf(r['plaintext'] as String),
                'zh>en>none',
                'kept',
              ),
              r['plaintext'] as String,
            );
          }
          expect(await old.query('translate_kept'), hasLength(msg.length));
          await old.close();

          final db = f == 'halo.db'
              ? HaloDb()
              : HaloDb.withKey(HaloContainer.vault, keys['vault']!);
          final raw = await db.open();
          final made = {
            for (final r in await raw.rawQuery(
              "SELECT name FROM sqlite_master WHERE type = 'trigger'",
            ))
              r['name'] as String,
          };
          expect(made, containsAll(_triggers));
          expect(await raw.query('translate_kept'), hasLength(msg.length));

          // and they still fire
          await raw.delete(
            'messages',
            where: 'msg_uid = ?',
            whereArgs: [msg.first['msg_uid']],
          );
          expect(await raw.query('translate_kept'), hasLength(msg.length - 1));
          if (msg.length > 1) {
            await raw.delete(
              'contacts',
              where: 'halo_id = ?',
              whereArgs: [msg.last['peer_id']],
            );
            expect(
              await raw.query(
                'translate_kept',
                where: 'chat = ?',
                whereArgs: [msg.last['peer_id']],
              ),
              isEmpty,
            );
          }
          await db.close();
        },
      );
    }
  }
}
