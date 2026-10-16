// SPDX-License-Identifier: GPL-3.0-or-later
// a message's words go with it: from the search index of the phone's own
// databases, and from every copy that leaves the phone. a copy made without
// the hidden chats keeps nothing that says the vault held anything. the
// databases are real sqlite files, read back as bytes
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show scrubCopy, tidyCopy;
import 'package:kryfo/main.dart'
    show eraseFreedPages, indexSearchRow, searchForgetsOnce, searchTables;
import 'package:kryfo/router.dart' show routerTables;
import 'package:path/path.dart' as p;

import 'sqlite_ffi.dart';

// sorted apart and with nothing in common at their start, so the index
// keeps each whole
const _kept = 'quokkablossom';
const _gone = 'zephyrmarmalade';

// a signal table as the app makes it, without the prefix
String _signal(String table) {
  final src = File('lib/app/database.dart').readAsStringSync();
  final m = RegExp(
    "'(CREATE TABLE IF NOT EXISTS \\\$\\{prefix\\}$table \\(.*\\))',",
  ).firstMatch(src)!;
  return m.group(1)!.replaceFirst(r'${prefix}', '');
}

void main() {
  group(
    'on the host\'s sqlite',
    skip: SqliteMem.open() == null ? 'no sqlite on this host' : null,
    () {
      late Directory tmp;
      late SqliteMem db;

      setUp(() {
        tmp = Directory.systemTemp.createTempSync('search_forgets');
        db = SqliteMem.open(path: p.join(tmp.path, 'halo.db'))!;
      });
      tearDown(() async {
        await db.close();
        tmp.deleteSync(recursive: true);
      });

      // the phone's database: freed pages zeroed, as the app opens it
      Future<void> made({required bool fresh}) async {
        await eraseFreedPages(db);
        await db.execute(appTable('messages'));
        await routerTables(db);
        await searchTables(db, fresh: fresh);
      }

      Future<void> say(int id, String words) async {
        final row = {
          'id': id,
          'peer_id': 'p',
          'direction': 'in',
          'plaintext': words,
          'sent_at': 1,
        };
        await db.insert('messages', row);
        await indexSearchRow(db, id, row);
      }

      Future<List<Object?>> found(String word) async => [
        for (final r in await db.rawQuery(
          'SELECT rowid FROM msg_fts WHERE msg_fts MATCH ?',
          [word],
        ))
          r['rowid'],
      ];

      test('a new index forgets a message\'s words as it goes', () async {
        await made(fresh: true);
        await say(1, _kept);
        await say(2, _gone);
        await db.delete('messages', where: 'id = ?', whereArgs: [2]);
        expect(holds(db.bytes(), _gone), isFalse);
        expect(holds(db.bytes(), _kept), isTrue);
        expect(await found(_kept), [1]);
      });

      test(
        'an index made before forgets what went, once, and from then on',
        () async {
          await made(fresh: false);
          await say(1, _kept);
          await say(2, _gone);
          await db.delete('messages', where: 'id = ?', whereArgs: [2]);
          // a mark laid over the words, the words themselves still there
          expect(holds(db.bytes(), _gone), isTrue);
          await searchForgetsOnce(db);
          expect(holds(db.bytes(), _gone), isFalse);
          expect(await found(_kept), [1]);
          await say(3, 'xylophonequince');
          await db.delete('messages', where: 'id = ?', whereArgs: [3]);
          expect(holds(db.bytes(), 'xylophonequince'), isFalse);
          // and only once
          await say(4, 'velvetcormorant');
          await db.delete('messages', where: 'id = ?', whereArgs: [4]);
          await searchForgetsOnce(db);
          expect(holds(db.bytes(), 'velvetcormorant'), isFalse);
        },
      );

      test('a copy that leaves keeps no word of a message gone, and no free '
          'page', () async {
        await made(fresh: false);
        await say(1, _kept);
        await say(2, _gone);
        await db.delete('messages', where: 'id = ?', whereArgs: [2]);
        expect(holds(db.bytes(), _gone), isTrue);
        await tidyCopy(db);
        expect(holds(db.bytes(), _gone), isFalse);
        expect(await found(_kept), [1]);
        expect(
          (await db.rawQuery('PRAGMA freelist_count')).first.values.first,
          0,
        );
      });

      test(
        'a copy without the hidden chats says nothing of the vault\'s inbox',
        () async {
          await made(fresh: false);
          await db.execute(_signal('sessions'));
          await db.execute(_signal('peer_identities'));
          await say(1, _kept);
          // what arrived for the hidden chats while they were shut
          for (var i = 0; i < 3; i++) {
            await db.insert('vault_inbox', {
              'uid': 'u$i',
              'sealed': [1, 2, 3],
              'at': 1,
            });
          }
          await db.delete('vault_inbox');
          Future<Set<Object?>> counted() async => {
            for (final r in await db.rawQuery(
              'SELECT name FROM sqlite_sequence',
            ))
              r['name'],
          };
          expect(await counted(), {'messages', 'vault_inbox'});
          await scrubCopy(db);
          expect(await counted(), {'messages'});
          expect(
            (await db.rawQuery('PRAGMA freelist_count')).first.values.first,
            0,
          );
        },
      );
    },
  );

  test('the sqlite the app bundles can forget: sqlcipher-android 4.6 or '
      'later, sqlite 3.42 or later', () {
    final config =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map;
    final plugin = (config['packages'] as List).cast<Map>().firstWhere(
      (e) => e['name'] == 'sqflite_sqlcipher',
    );
    final root = Uri.parse(plugin['rootUri'] as String);
    final gradle = File(
      p.join(root.toFilePath(), 'android', 'build.gradle'),
    ).readAsStringSync();
    final v = RegExp(
      r'net\.zetetic:sqlcipher-android:(\d+)\.(\d+)',
    ).firstMatch(gradle)!;
    final major = int.parse(v.group(1)!), minor = int.parse(v.group(2)!);
    // 4.10.0 bundles sqlite 3.50.4
    expect(major > 4 || (major == 4 && minor >= 6), isTrue, reason: v[0]);
  });
}
