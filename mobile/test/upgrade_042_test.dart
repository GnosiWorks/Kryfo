// SPDX-License-Identifier: GPL-3.0-or-later
// a phone on 0.4.2 takes this version. its file was made by 0.4.2's own
// code (fixtures/upgrade_042, make_042.sh). it opens here on the host's
// sqlite, step by step up to this version: the schema ends as a new
// install's, every message keeps the place 0.4.2 showed it in, one that
// comes after goes where it was written, and a second open changes nothing
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlite_channel.dart';

const _fixtures = 'test/fixtures/upgrade_042';
const _alice = 'amber-otter-lake';
const _gid = 'g0a1b2c3d4e5f60718293a4b5c6d7e8f9';
const _t = 1767225600000;

// what the file holds, as sqlite describes it: each table's columns by
// name, its indexes, and the triggers
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
      case 'index':
        out['index $name'] = '${r['tbl_name']}: ${flat(r['sql'])}';
      case 'trigger':
        out['trigger $name'] = '${r['tbl_name']}: ${flat(r['sql'])}';
    }
  }
  return out;
}

List<String?> _uids(List<Map<String, Object?>> rows) => [
  for (final r in rows) r['msg_uid'] as String?,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('upgrade_042');
    File('$_fixtures/halo.db').copySync(p.join(docs.path, 'halo.db'));
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': '0e' * 32,
    });
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    sql?.uninstall();
    m.setMockMethodCallHandler(paths, null);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  bool skip() {
    if (sql != null) return false;
    markTestSkipped('no sqlite on this host');
    return true;
  }

  test('the file holds what 0.4.2 wrote', () async {
    if (skip()) return;
    final old = await openDatabase(
      p.absolute('$_fixtures/halo.db'),
      readOnly: true,
      singleInstance: false,
    );
    expect(await old.getVersion(), 51);
    final cols = await old.rawQuery("PRAGMA table_info('messages')");
    expect([for (final c in cols) c['name']], isNot(contains('written_at')));
    expect(await old.query('messages'), hasLength(8));
    await old.close();
  });

  test('it opens at 85 with the schema of a new install', () async {
    if (skip()) return;
    final fresh = Directory.systemTemp.createTempSync('upgrade_042_fresh');
    m.setMockMethodCallHandler(paths, (_) async => fresh.path);
    final made = HaloDb();
    final want = await _schema(await made.open());
    await made.close();
    fresh.deleteSync(recursive: true);
    m.setMockMethodCallHandler(paths, (_) async => docs.path);

    // what the upgrade says, past the new install's own statements
    final from = sql!.said.length;
    final db = HaloDb();
    final raw = await db.open();
    expect(await raw.getVersion(), 85);
    final got = await _schema(raw);
    for (final k in {...want.keys, ...got.keys}) {
      expect(got[k], want[k], reason: k);
    }
    expect(
      sql!.said.where(
        (s) => s.startsWith('ALTER TABLE messages ADD COLUMN written_at'),
      ),
      hasLength(1),
    );
    // the step to 80 runs last
    int at(String step) =>
        sql!.said.indexWhere((s) => s.startsWith(step), from);
    final ack = at('ALTER TABLE contacts ADD COLUMN ack_owed');
    expect(ack, greaterThan(at('ALTER TABLE messages ADD COLUMN written_at')));
    expect(ack, greaterThan(at('CREATE TABLE IF NOT EXISTS notif_rings')));
    // and the steps from 81 after it, in order
    final keys = at('CREATE TABLE IF NOT EXISTS blocked_keys');
    expect(keys, greaterThan(ack));
    final ended = at('ALTER TABLE groups ADD COLUMN ended_at');
    expect(ended, greaterThan(keys));
    final shots = at('ALTER TABLE contacts ADD COLUMN shots_on');
    expect(shots, greaterThan(ended));
    final album = at('ALTER TABLE messages ADD COLUMN album_id');
    expect(album, greaterThan(shots));
    expect(at('CREATE TABLE IF NOT EXISTS wallpapers'), greaterThan(album));
    await db.close();
  });

  test('every message keeps the place 0.4.2 showed it in', () async {
    if (skip()) return;
    final db = HaloDb();
    final raw = await db.open();
    for (final r in await raw.query('messages')) {
      expect(r['written_at'], r['sent_at'], reason: '${r['msg_uid']}');
    }
    // 0.4.2 sorted a chat by sent_at: a4 came after a3 and sat above a2
    expect(_uids(await db.messagesFor(_alice)), ['a1', 'a4', 'a2', 'a3', 'a5']);
    expect(_uids(await db.messagesPage(_alice, limit: 3)), ['a2', 'a3', 'a5']);
    expect(_uids(await db.loadGroupMessages(_gid)), ['g1', 'g3', 'g2']);
    // one that comes now, written between two of them, goes there
    await db.saveMessage(
      _alice,
      'in',
      'late',
      msgUid: 'a6',
      writtenAt: _t + 90000,
    );
    expect(_uids(await db.messagesFor(_alice)), [
      'a1',
      'a4',
      'a2',
      'a6',
      'a3',
      'a5',
    ]);
    await db.close();
  });

  test('a second open changes nothing', () async {
    if (skip()) return;
    final db = HaloDb();
    final first = await db.open();
    final schema = await _schema(first);
    final rows = await first.query('messages', orderBy: 'id');
    await db.close();
    final from = sql!.said.length;
    final again = HaloDb();
    final raw = await again.open();
    expect(await raw.getVersion(), 85);
    expect(
      sql!.said
          .sublist(from)
          .where((s) => RegExp(r'^(ALTER|CREATE|UPDATE|INSERT)').hasMatch(s)),
      isEmpty,
    );
    expect(await _schema(raw), schema);
    expect(await raw.query('messages', orderBy: 'id'), rows);
    await again.close();
  });
}
