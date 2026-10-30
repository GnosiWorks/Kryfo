// SPDX-License-Identifier: GPL-3.0-or-later
// the linked-devices tables of a container (db 95): what the engine holds
// of contacts' device lists, my own lists, quiet devices and the pool, and
// what the later steps keep beside it. the engine says which rows to write
// (device_state.dart); this file only writes and reads them. with the
// switch off every table stays empty
import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

/// the columns the engine writes, by table, the key first
const kDevRowTables = <String, List<String>>{
  'dev_lists': ['ident', 'owner', 'version', 'wire', 'from_invite'],
  'dev_proven': ['ident', 'peer', 'key'],
  'dev_pq': ['ident', 'peer'],
  'dev_quiet': [
    'ident',
    'peer',
    'device',
    'key',
    'first_at',
    'rebuilt_at',
    'probe_at',
    'silent',
    'under',
  ],
  'dev_pool': [
    'ident',
    'device',
    'kyber_id',
    'key',
    'reg',
    'answers',
    'spk_id',
    'kdb1',
    'aged_at',
    'last',
  ],
};

const _devKeys = <String, List<String>>{
  'dev_lists': ['ident', 'owner'],
  'dev_proven': ['ident', 'peer', 'key'],
  'dev_pq': ['ident', 'peer'],
  'dev_quiet': ['ident', 'peer', 'device'],
  'dev_pool': ['ident', 'device', 'kyber_id'],
};

// columns that hold bytes: base64 between here and the engine
const _blobs = {'wire', 'kdb1'};

/// the tables, made at every open as well as by the upgrade to 95: a file
/// that took a later number without them still gets them. every statement
/// is safe twice
Future<void> deviceTables(
  DatabaseExecutor db,
  Future<void> Function(DatabaseExecutor db, String sql) addColumn,
) async {
  // a linked device's id on each of its identities (1 on the phone), and
  // the identity key itself there: its x_priv is its own device key
  await addColumn(
    db,
    'ALTER TABLE identities ADD COLUMN dev_id INTEGER NOT NULL DEFAULT 1',
  );
  await addColumn(db, 'ALTER TABLE identities ADD COLUMN ident_pub BLOB');
  // the signed lists held: mine ('me') and each contact's (their identity
  // key, hex), stored before the first send. sent_ok: every contact took it
  await db.execute('''
    CREATE TABLE IF NOT EXISTS dev_lists (
      ident INTEGER NOT NULL,
      owner TEXT NOT NULL,
      version INTEGER NOT NULL,
      wire BLOB NOT NULL,
      from_invite INTEGER NOT NULL DEFAULT 0,
      sent_ok INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (ident, owner)
    )
  ''');
  // listed keys a contact's message decrypted under
  await db.execute('''
    CREATE TABLE IF NOT EXISTS dev_proven (
      ident INTEGER NOT NULL,
      peer TEXT NOT NULL,
      key TEXT NOT NULL,
      PRIMARY KEY (ident, peer, key)
    )
  ''');
  // a contact with a post-quantum session: never classic again
  await db.execute('''
    CREATE TABLE IF NOT EXISTS dev_pq (
      ident INTEGER NOT NULL,
      peer TEXT NOT NULL,
      PRIMARY KEY (ident, peer)
    )
  ''');
  // devices that have not answered: the first copy, the first on the
  // session held now (rebuilt_at), the last probe
  await db.execute('''
    CREATE TABLE IF NOT EXISTS dev_quiet (
      ident INTEGER NOT NULL,
      peer TEXT NOT NULL,
      device INTEGER NOT NULL,
      key TEXT NOT NULL,
      first_at INTEGER NOT NULL DEFAULT 0,
      rebuilt_at INTEGER NOT NULL DEFAULT 0,
      probe_at INTEGER NOT NULL DEFAULT 0,
      silent INTEGER NOT NULL DEFAULT 0,
      under INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (ident, peer, device)
    )
  ''');
  // the phone's pool of its devices' bundles, one row per kyber id. kdb1
  // is null once handed out or aged out: the id stays, so it is never
  // taken again
  await db.execute('''
    CREATE TABLE IF NOT EXISTS dev_pool (
      ident INTEGER NOT NULL,
      device INTEGER NOT NULL,
      kyber_id INTEGER NOT NULL,
      key TEXT NOT NULL,
      reg INTEGER NOT NULL,
      answers INTEGER NOT NULL DEFAULT 0,
      spk_id INTEGER NOT NULL,
      kdb1 BLOB,
      aged_at INTEGER NOT NULL DEFAULT 0,
      last INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (ident, device, kyber_id)
    )
  ''');
  // openers from a device not on the list held yet, tried again after
  // each list, gone after 7 days
  await db.execute('''
    CREATE TABLE IF NOT EXISTS dev_held_openers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ident INTEGER NOT NULL,
      peer TEXT NOT NULL,
      device INTEGER NOT NULL,
      cipher BLOB NOT NULL,
      came_at INTEGER NOT NULL
    )
  ''');
  // lists still to go to a contact: removals at once, additions spread
  await db.execute('''
    CREATE TABLE IF NOT EXISTS dev_pushes (
      ident INTEGER NOT NULL,
      peer TEXT NOT NULL,
      version INTEGER NOT NULL,
      kind TEXT NOT NULL,
      due_at INTEGER NOT NULL,
      PRIMARY KEY (ident, peer, version, kind)
    )
  ''');
  // my own devices as only I see them, and their keys per identity.
  // heard_online_ms: the phone's time online since the device was last
  // heard from
  await db.execute('''
    CREATE TABLE IF NOT EXISTS own_devices (
      uid TEXT PRIMARY KEY,
      name TEXT NOT NULL DEFAULT '',
      kind TEXT NOT NULL DEFAULT 'computer',
      linked_at INTEGER NOT NULL,
      removed_at INTEGER,
      heard_online_ms INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS own_device_keys (
      uid TEXT NOT NULL,
      ident INTEGER NOT NULL,
      dev_id INTEGER NOT NULL,
      key TEXT NOT NULL,
      reg INTEGER NOT NULL,
      PRIMARY KEY (uid, ident)
    )
  ''');
  // each copy of a message still owed to one device, so one device's
  // failure goes again alone
  await db.execute('''
    CREATE TABLE IF NOT EXISTS dev_out (
      uid TEXT NOT NULL,
      ident INTEGER NOT NULL,
      peer TEXT NOT NULL,
      device INTEGER NOT NULL,
      at INTEGER NOT NULL,
      PRIMARY KEY (uid, ident, peer, device)
    )
  ''');
}

const _allTables = [
  'dev_lists',
  'dev_proven',
  'dev_pq',
  'dev_quiet',
  'dev_pool',
  'dev_held_openers',
  'dev_pushes',
  'own_devices',
  'own_device_keys',
  'dev_out',
];

/// at every open: [deviceTables] only when one is missing, so a file that
/// took a later number without them (a branch's 96 before this step
/// merged) gets them, and an open of a whole file writes nothing
Future<void> deviceTablesAtOpen(
  DatabaseExecutor db,
  Future<void> Function(DatabaseExecutor db, String sql) addColumn,
) async {
  final have = {
    for (final r in await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ))
      r['name'] as String,
  };
  final cols = {
    for (final c in await db.rawQuery("PRAGMA table_info('identities')"))
      c['name'] as String,
  };
  final whole =
      _allTables.every(have.contains) &&
      (!have.contains('identities') ||
          (cols.contains('dev_id') && cols.contains('ident_pub')));
  if (!whole) await deviceTables(db, addColumn);
}

/// the rows an engine answer names, written in order: a put writes over
/// the row with its key, a delete takes every row matching what it names.
/// a table or column the engine has no business with throws, and nothing
/// of the answer is written when [db] is a transaction
Future<void> applyDevRows(DatabaseExecutor db, List<dynamic> rows) async {
  for (final r in rows) {
    final op = r as Map<String, dynamic>;
    final table = op['t'] as String;
    final cols = kDevRowTables[table];
    final keys = _devKeys[table];
    if (cols == null || keys == null) {
      throw StateError('device rows: no table $table');
    }
    final put = op['put'] as Map<String, dynamic>?;
    final del = op['del'] as Map<String, dynamic>?;
    if ((put == null) == (del == null)) {
      throw StateError('device rows: one put or one delete');
    }
    final m = put ?? del!;
    final values = <String, Object?>{};
    for (final e in m.entries) {
      if (!cols.contains(e.key)) {
        throw StateError('device rows: no column ${e.key} in $table');
      }
      final v = e.value;
      values[e.key] = _blobs.contains(e.key) && v is String
          ? base64Decode(v)
          : v;
    }
    if (del != null) {
      final names = values.keys.toList();
      if (names.isEmpty) throw StateError('device rows: a delete of all');
      await db.delete(
        table,
        where: names.map((c) => '$c = ?').join(' AND '),
        whereArgs: [for (final c in names) values[c]],
      );
      continue;
    }
    for (final k in keys) {
      if (!values.containsKey(k)) {
        throw StateError('device rows: $table without $k');
      }
    }
    final rest = {
      for (final e in values.entries)
        if (!keys.contains(e.key)) e.key: e.value,
    };
    final where = keys.map((c) => '$c = ?').join(' AND ');
    final args = [for (final k in keys) values[k]];
    final n = rest.isEmpty
        ? (await db.query(table, where: where, whereArgs: args)).length
        : await db.update(table, rest, where: where, whereArgs: args);
    if (n == 0) await db.insert(table, values);
  }
}

/// one identity of mine for the engine: its key, and this device's key
/// for it (the same on the phone)
typedef DevMine = ({int ident, Uint8List identity, Uint8List key});

/// what the engine loads at the start: my identities, every contact with
/// an identity key, and the stored rows in the order they were written
Future<Map<String, Object?>> devLoadArgs(
  DatabaseExecutor db,
  List<DevMine> mine,
) async {
  String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  final out = <String, Object?>{
    'mine': [
      for (final m in mine)
        {'ident': m.ident, 'identity': hex(m.identity), 'key': hex(m.key)},
    ],
    'contacts': [
      for (final r in await db.query(
        'contacts',
        columns: ['ident', 'ikey'],
        where: 'ikey IS NOT NULL',
        orderBy: 'rowid',
      ))
        {'ident': r['ident'] ?? 0, 'identity': r['ikey']},
    ],
  };
  for (final t in kDevRowTables.entries) {
    out[t.key] = [
      for (final r in await db.query(t.key, columns: t.value, orderBy: 'rowid'))
        {
          for (final e in r.entries)
            e.key: e.value is List<int>
                ? base64Encode(e.value as List<int>)
                : e.value,
        },
    ];
  }
  return out;
}
