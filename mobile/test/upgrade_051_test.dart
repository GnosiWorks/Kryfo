// SPDX-License-Identifier: GPL-3.0-or-later
// a phone on 0.5.1 takes this version. its files were made by 0.5.1's own
// code (fixtures/upgrade_051, make_051.sh) at 80. they open here on the
// host's sqlite, from 80 and from each step after it: the schema ends as a
// new install's, every column and table the steps add is there, no row is
// lost, and a step run again changes nothing
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/main.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlite_channel.dart';

const _fixtures = 'test/fixtures/upgrade_051';
const _version = 85;

// the keys each file opens with, under the names the app keeps them by
final _keyFile =
    (jsonDecode(File('$_fixtures/keys.json').readAsStringSync()) as Map)
        .cast<String, String>();
final _keys = {
  'halo.db.passphrase': _keyFile['everyday']!,
  'halo.d.key': _keyFile['decoy']!,
};

// the three files a 0.5.1 phone keeps, each as this version opens it
final _files = <String, HaloDb Function()>{
  'halo.db': HaloDb.new,
  'halo_d.db': () => HaloDb(HaloContainer.decoy),
  'halo_v.db': () => HaloDb.withKey(HaloContainer.vault, _keyFile['vault']!),
};

// each step after 80, as onUpgrade runs it, and the statement that says
// it ran
final _steps = <int, (Future<void> Function(Database), String)>{
  81: (
    (db) async {
      await blockedKeysTable(db);
      await ackOwedColumn(db);
    },
    'CREATE TABLE IF NOT EXISTS blocked_keys',
  ),
  82: (groupEndColumns, 'ALTER TABLE groups ADD COLUMN ended_at'),
  83: (shotsColumns, 'ALTER TABLE contacts ADD COLUMN shots_on'),
  84: (albumColumns, 'ALTER TABLE messages ADD COLUMN album_id'),
  85: (wallpaperTable, 'CREATE TABLE IF NOT EXISTS wallpapers'),
};

// what the steps add, by table
const _added = {
  'blocked_keys': <String>[],
  'contacts': [
    'ack_owed',
    'shots_on',
    'shots_at',
    'shots_can',
    'shots_by',
    'shots_when',
  ],
  'groups': ['ended_at', 'ended_by'],
  'messages': ['album_id', 'album_n', 'album_i'],
  'wallpapers': ['chat', 'atmo', 'photo'],
};
const _indexes = [
  'idx_media_chunks_group',
  'idx_group_media_owed_group',
  'idx_messages_album',
];

// what the file holds, as sqlite describes it: each table's columns by
// name, its keys and indexes, and the triggers
Future<Map<String, Object?>> _schema(DatabaseExecutor db) async {
  final out = <String, Object?>{};
  final all = await db.rawQuery(
    "SELECT type, name, tbl_name, sql FROM sqlite_master "
    "WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  String flat(Object? s) => '${s ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final r in all) {
    final name = r['name'] as String;
    switch (r['type']) {
      case 'table':
        final cols = await db.rawQuery("PRAGMA table_info('$name')");
        out['table $name'] = {
          for (final c in cols)
            c['name']:
                '${c['type']} notnull=${c['notnull']} '
                'default=${c['dflt_value']} pk=${c['pk']}',
        };
        final idx = await db.rawQuery("PRAGMA index_list('$name')");
        final keys = <String>[];
        for (final i in idx) {
          final on = await db.rawQuery("PRAGMA index_info('${i['name']}')");
          final cols = [for (final c in on) c['name']].join(',');
          final named = '${i['origin']}' == 'c' ? '${i['name']} ' : '';
          keys.add(
            '$named(${i['origin']}) unique=${i['unique']} '
            'partial=${i['partial']} $cols',
          );
        }
        out['keys $name'] = keys..sort();
      case 'index':
        out['index $name'] = '${r['tbl_name']}: ${flat(r['sql'])}';
      case 'trigger':
        out['trigger $name'] = '${r['tbl_name']}: ${flat(r['sql'])}';
      case 'view':
        out['view $name'] = flat(r['sql']);
    }
  }
  return out;
}

// every row of every table, by the columns it had in 0.5.1
Future<Map<String, List<String>>> _rows(
  DatabaseExecutor db, {
  Map<String, Set<String>>? only,
}) async {
  final out = <String, List<String>>{};
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  for (final t in tables) {
    final name = t['name'] as String;
    if (only != null && !only.containsKey(name)) continue;
    final cols = only?[name];
    final rows = await db.rawQuery('SELECT * FROM "$name"');
    out[name] = [
      for (final r in rows)
        jsonEncode({
          for (final e in r.entries)
            if (cols == null || cols.contains(e.key))
              e.key: e.value is Uint8List
                  ? base64Encode(e.value as Uint8List)
                  : e.value,
        }),
    ]..sort();
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;
  // each file 0.5.1 left: its rows and their columns, and a new install's
  // schema for it, made by this onCreate
  final before = <String, Map<String, List<String>>>{};
  final beforeCols = <String, Map<String, Set<String>>>{};
  final fresh = <String, Map<String, Object?>>{};

  setUpAll(() async {
    sql = SqliteChannel.install();
    if (sql == null) return;
    for (final f in _files.keys) {
      final d = Directory.systemTemp.createTempSync('upgrade_051_fresh');
      m.setMockMethodCallHandler(paths, (_) async => d.path);
      FlutterSecureStorage.setMockInitialValues({});
      final db = _files[f]!();
      fresh[f] = await _schema(await db.open());
      await db.close();
      d.deleteSync(recursive: true);
      final old = await openDatabase(
        p.absolute('$_fixtures/$f'),
        readOnly: true,
        singleInstance: false,
      );
      expect(await old.getVersion(), 80, reason: f);
      before[f] = await _rows(old);
      beforeCols[f] = {
        for (final t in before[f]!.keys)
          t: {
            for (final c in await old.rawQuery("PRAGMA table_info('$t')"))
              c['name'] as String,
          },
      };
      await old.close();
    }
    sql!.uninstall();
  });

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('upgrade_051');
    for (final f in _files.keys) {
      File('$_fixtures/$f').copySync(p.join(docs.path, f));
    }
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({..._keys});
    SharedPreferences.setMockInitialValues({});
    useDevKeysForTest(null);
  });

  tearDown(() {
    sql?.uninstall();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  bool skip() {
    if (sql != null) return false;
    markTestSkipped('no sqlite on this host');
    return true;
  }

  // the copy of [f] here, taken by hand through the steps up to [to], as a
  // build that stopped there left it
  Future<void> stepTo(String f, int to) async {
    final raw = await openDatabase(p.join(docs.path, f), singleInstance: false);
    for (final e in _steps.entries) {
      if (e.key <= to) await e.value.$1(raw);
    }
    await raw.setVersion(to);
    await raw.close();
  }

  Future<void> holdsEverything(Database raw) async {
    for (final e in _added.entries) {
      final cols = [
        for (final c in await raw.rawQuery("PRAGMA table_info('${e.key}')"))
          c['name'],
      ];
      expect(cols, isNotEmpty, reason: e.key);
      expect(cols, containsAll(e.value), reason: e.key);
    }
    for (final i in _indexes) {
      expect(
        await raw.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
          [i],
        ),
        hasLength(1),
        reason: i,
      );
    }
  }

  test('the files hold what 0.5.1 wrote', () {
    if (skip()) return;
    // a check of the checks: an empty file or schema would pass them all
    expect(fresh['halo.db']!['table contacts'], contains('ack_owed'));
    expect(fresh['halo.db']!['table wallpapers'], isNotNull);
    expect(before['halo.db']!['messages'], hasLength(19));
    expect(before['halo.db']!['contacts'], hasLength(8));
    expect(before['halo.db']!['notif_rings'], hasLength(1));
    expect(before['halo_d.db']!['sessions'], hasLength(1));
    expect(before['halo_v.db']!['messages'], hasLength(2));
    for (final f in _files.keys) {
      expect(before[f]!.keys, isNot(contains('blocked_keys')), reason: f);
      expect(before[f]!.keys, isNot(contains('wallpapers')), reason: f);
    }
  });

  for (final f in _files.keys) {
    for (final from in [80, ..._steps.keys.where((k) => k < _version)]) {
      test('$f from $from opens at $_version with the schema of a new '
          'install and every row', () async {
        if (skip()) return;
        if (from > 80) await stepTo(f, from);
        final start = sql!.said.length;
        final db = _files[f]!();
        final raw = await db.open();
        expect(await raw.getVersion(), _version);
        final got = await _schema(raw);
        // key by key, so a miss names the table and the column
        for (final k in {...fresh[f]!.keys, ...got.keys}) {
          expect(got[k], fresh[f]![k], reason: k);
        }
        await holdsEverything(raw);
        // the steps after [from] ran, in order, and none before them
        final said = sql!.said.sublist(start);
        final at = [
          for (final e in _steps.entries)
            if (e.key > from) said.indexWhere((s) => s.startsWith(e.value.$2)),
        ];
        expect(at, everyElement(greaterThanOrEqualTo(0)));
        expect([...at]..sort(), at);
        for (final e in _steps.entries) {
          if (e.key <= from) {
            expect(
              said.where((s) => s.startsWith(e.value.$2)),
              isEmpty,
              reason: '${e.key}',
            );
          }
        }
        expect(said.where((s) => s.contains('ADD COLUMN written_at')), isEmpty);
        final after = await _rows(raw, only: beforeCols[f]);
        for (final t in before[f]!.keys) {
          expect(after[t], before[f]![t], reason: t);
        }
        await db.close();
      });
    }

    test(
      '$f: every step run again on a file that has it changes nothing',
      () async {
        if (skip()) return;
        final db = _files[f]!();
        final first = await db.open();
        final schema = await _schema(first);
        final rows = await _rows(first);
        await db.close();
        // a file whose steps went but whose number did not
        final raw = await openDatabase(
          p.join(docs.path, f),
          singleInstance: false,
        );
        await raw.setVersion(80);
        await raw.close();
        final again = _files[f]!();
        final up = await again.open();
        expect(await up.getVersion(), _version);
        expect(await _schema(up), schema);
        expect(await _rows(up), rows);
        await again.close();
      },
    );

    test('$f: a second open changes nothing', () async {
      if (skip()) return;
      final db = _files[f]!();
      final first = await db.open();
      final schema = await _schema(first);
      final rows = await _rows(first);
      await db.close();
      final from = sql!.said.length;
      final again = _files[f]!();
      final raw = await again.open();
      final said = sql!.said.sublist(from);
      expect(await raw.getVersion(), _version);
      expect(
        said.where(
          (s) => RegExp(
            r'^(ALTER|CREATE|UPDATE|INSERT|DELETE|DROP|REPLACE)',
          ).hasMatch(s),
        ),
        isEmpty,
      );
      expect(await _schema(raw), schema);
      expect(await _rows(raw), rows);
      await again.close();
    });
  }

  test('what 0.5.1 added reads back through this version', () async {
    if (skip()) return;
    final db = HaloDb();
    await db.open();
    expect((await db.getContact('brisk-cedar-moon'))!['name_check'], 1);
    expect((await db.getContact('brisk-cedar-moon'))!['ack_owed'], 1);
    expect((await db.getContact('dusty-heron-vale'))!['name_check'], 3);
    expect(await db.voiceDisguiseOf('amber-otter-lake'), isTrue);
    expect(
      await db.voiceDisguiseOf(
        'g0a1b2c3d4e5f60718293a4b5c6d7e8f9',
        group: true,
      ),
      isFalse,
    );
    await db.close();
  });
}
