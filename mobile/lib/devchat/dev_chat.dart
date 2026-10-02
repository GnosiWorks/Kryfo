// SPDX-License-Identifier: GPL-3.0-or-later
// the chat with the developer as this phone keeps it: one row in every
// container that says whether the chat is fresh, how it started, or that it
// was deleted. a delete takes everything of it and stays a delete. nothing
// here reaches the network

import 'dart:math';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../dlog.dart';
import '../signal_stores.dart' show kDevSignalPrefix, kSignalTables;
import 'dev_key.dart';

enum DevState {
  // on show, nothing sent, no keys made
  fresh,
  // started with the person's three words
  everyday,
  // started with a name made for this chat alone
  anon,
  // deleted. only the settings row brings a fresh one back
  gone,
}

// a word this build does not know reads as gone: no row, nothing sent
DevState devStateOf(Object? s) {
  for (final v in DevState.values) {
    if (v.name == s) return v;
  }
  return DevState.gone;
}

// the table and its one row, in every container. a fresh install and every
// upgrade seed the row fresh. an existing row is never written here, so a
// delete survives every later migration, rerun and key list
Future<void> devChatTables(DatabaseExecutor db, {int? now}) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS devchat (
      k INTEGER PRIMARY KEY CHECK (k = 1),
      state TEXT NOT NULL,
      key_id TEXT NOT NULL,
      pinned INTEGER NOT NULL DEFAULT 1,
      muted INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0,
      anon_id TEXT,
      anon_ed_priv TEXT,
      anon_x_priv TEXT,
      created_at INTEGER NOT NULL,
      started_at INTEGER
    )
  ''');
  await db.insert('devchat', {
    'k': 1,
    'state': DevState.fresh.name,
    'key_id': currentDevKey?.keyId ?? '',
    'created_at': now ?? DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

// a table a migration made, or could not make: its wrapper lets the app
// open without it
Future<bool> _there(DatabaseExecutor db, String table) async =>
    (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    )).isNotEmpty;

// a copy of a container's database that leaves the phone, in a backup or a
// move: the name an anonymous chat was made with and its store stay here,
// so the copy never ties that name to the everyday one. the chat itself
// goes along and reads where it lands (DevChatRow.nameless). a table that
// is not there holds nothing; one that is there and will not clear fails
// the copy
Future<void> scrubDevAnon(DatabaseExecutor db) async {
  await clearDevStore(db);
  if (await _there(db, 'devchat')) {
    await db.update('devchat', {
      'anon_id': null,
      'anon_ed_priv': null,
      'anon_x_priv': null,
    });
  }
}

// the anonymous chat's own store, emptied: a start makes it anew, and a
// delete or a copy leaves nothing of it behind
Future<void> clearDevStore(DatabaseExecutor db) async {
  for (final name in kSignalTables) {
    final table = '$kDevSignalPrefix$name';
    if (await _there(db, table)) await db.delete(table);
  }
}

// the row as the table keeps it
class DevChatRow {
  const DevChatRow({
    required this.state,
    required this.keyId,
    this.pinned = true,
    this.muted = false,
    this.archived = false,
    this.anonId,
    this.anonEdPriv,
    this.anonXPriv,
    required this.createdAt,
    this.startedAt,
  });

  static DevChatRow of(Map<String, Object?> r) => DevChatRow(
    state: devStateOf(r['state']),
    keyId: r['key_id'] as String? ?? '',
    pinned: r['pinned'] == 1,
    muted: r['muted'] == 1,
    archived: r['archived'] == 1,
    anonId: r['anon_id'] as String?,
    anonEdPriv: r['anon_ed_priv'] as String?,
    anonXPriv: r['anon_x_priv'] as String?,
    createdAt: (r['created_at'] as num?)?.toInt() ?? 0,
    startedAt: (r['started_at'] as num?)?.toInt(),
  );

  final DevState state;
  // the key it started with. before that, a hint only: a fresh chat talks
  // to whichever key is current
  final String keyId;
  // until the first send. from then on the chat's contact row holds them
  final bool pinned;
  final bool muted;
  final bool archived;
  // the name made for an anonymous chat, and its keys
  final String? anonId;
  final String? anonEdPriv;
  final String? anonXPriv;
  final int createdAt;
  final int? startedAt;

  bool get started => state == DevState.everyday || state == DevState.anon;

  // an anonymous chat restored from a backup or a move: the name it was
  // made with stayed behind, so it reads but sends and hears nothing
  bool get nameless => state == DevState.anon && (anonXPriv ?? '').isEmpty;

  // the key the chat talks to
  DevKey? get key => switch (state) {
    DevState.fresh => currentDevKey,
    DevState.everyday || DevState.anon => devKeyById(keyId),
    DevState.gone => null,
  };

  // its peer id, also when its key has left the list
  String? get chatId => switch (state) {
    DevState.fresh => currentDevKey?.chatId,
    DevState.everyday || DevState.anon => DevKey.chatIdOf(keyId),
    DevState.gone => null,
  };
}

// the name an anonymous chat is written under: made for it, used nowhere
// else, and gone with it
class DevAnon {
  const DevAnon({required this.id, required this.edPriv, required this.xPriv});

  final String id;
  final String edPriv;
  final String xPriv;
}

// what home shows of the chat, beside the contacts and never among them
class DevRow {
  const DevRow({
    required this.keyId,
    required this.chatId,
    this.preview,
    this.when,
    this.unread = 0,
    this.pinned = true,
    this.muted = false,
    this.archived = false,
    this.started = false,
    this.anonymous = false,
    this.nameless = false,
    this.status = DevKeyStatus.current,
  });

  final String keyId;
  final String chatId;
  // the last message as the row says it. null before any: the welcome
  final String? preview;
  // the last message's time. none while fresh
  final DateTime? when;
  final int unread;
  final bool pinned;
  final bool muted;
  final bool archived;
  final bool started;
  final bool anonymous;
  // anonymous, restored without its made name: it reads, it never sends
  final bool nameless;
  // retired also when its key has left the list: it reads, it never sends
  final DevKeyStatus status;
}

// the developer's own phone: its everyday identity is a pinned key that
// still works. the caller leaves a decoy out
bool devModeOf(String everydayXPub) {
  final k = devKeyByXPub(everydayXPub);
  return k != null && k.status != DevKeyStatus.retired;
}

// the home row. none while gone, on the developer's own phone, or while
// fresh with no key to talk to
DevRow? devRowOf(
  DevChatRow? r, {
  Map<String, Object?>? contact,
  String? preview,
  DateTime? when,
  bool devMode = false,
}) {
  if (r == null || devMode) return null;
  switch (r.state) {
    case DevState.gone:
      return null;
    case DevState.fresh:
      final k = currentDevKey;
      if (k == null) return null;
      // no unread count: nothing arrived
      return DevRow(
        keyId: k.keyId,
        chatId: k.chatId,
        pinned: r.pinned,
        muted: r.muted,
        archived: r.archived,
      );
    case DevState.everyday || DevState.anon:
      bool flag(String col, bool fallback) =>
          contact == null ? fallback : contact[col] == 1;
      return DevRow(
        keyId: r.keyId,
        chatId: DevKey.chatIdOf(r.keyId),
        preview: preview,
        when: when,
        unread: (contact?['unread'] as num?)?.toInt() ?? 0,
        pinned: flag('pinned', r.pinned),
        muted: flag('muted', r.muted),
        archived: flag('archived', r.archived),
        started: true,
        anonymous: r.state == DevState.anon,
        nameless: r.nameless,
        status: r.key?.status ?? DevKeyStatus.retired,
      );
  }
}

const _kDev = 'dev:%';

// the chat's state machine over one container's database:
//   fresh -> everyday | anon    the first send
//   any -> gone                 a delete
//   gone -> fresh               the settings row, only when tapped
// nothing else moves it. to switch between three words and anonymous the
// chat is deleted and started again
class DevChat {
  DevChat(
    this._open, {
    required Future<void> Function(String path) shred,
    int Function()? now,
  }) : _shred = shred,
       _now = now ?? _clock;

  final Future<Database> Function() _open;
  // zeros, then unlink
  final Future<void> Function(String path) _shred;
  final int Function() _now;

  static int _clock() => DateTime.now().millisecondsSinceEpoch;

  static Future<DevChatRow?> _row(DatabaseExecutor t) async {
    final r = await t.query(
      'devchat',
      where: 'k = ?',
      whereArgs: [1],
      limit: 1,
    );
    return r.isEmpty ? null : DevChatRow.of(r.first);
  }

  Future<DevChatRow?> load() async => _row(await _open());

  Future<bool> setPinned(bool on) => _flag('pinned', on);
  Future<bool> setMuted(bool on) => _flag('muted', on);
  Future<bool> setArchived(bool on) => _flag('archived', on);

  // before the first send the flags are the row's; after it the chat's
  // contact row holds them, as for any chat. a deleted chat has none
  Future<bool> _flag(String col, bool on) async {
    final db = await _open();
    return db.transaction((t) async {
      final r = await _row(t);
      if (r == null) return false;
      final v = {col: on ? 1 : 0};
      switch (r.state) {
        case DevState.fresh:
          await t.update('devchat', v, where: 'k = ?', whereArgs: [1]);
          return true;
        case DevState.everyday || DevState.anon:
          final n = await t.update(
            'contacts',
            v,
            where: 'halo_id = ?',
            whereArgs: [DevKey.chatIdOf(r.keyId)],
          );
          return n > 0;
        case DevState.gone:
          return false;
      }
    });
  }

  // the first send: fresh becomes everyday, or anon with the name made for
  // it, and the chat gets its contact row with the flags it had. relay
  // only, so no onion; an anonymous chat keeps no bundle there, so the
  // everyday store can never build a session with the developer. refused
  // unless fresh and [key] is the current key, and when a row for the chat
  // names another key
  Future<bool> begin(DevKey key, {DevAnon? anon}) async {
    final cur = currentDevKey;
    if (cur == null ||
        cur.keyId != key.keyId ||
        cur.xPub != key.xPub ||
        cur.bundle != key.bundle ||
        cur.fc != key.fc) {
      return false;
    }
    if (anon != null &&
        (anon.id.isEmpty || anon.edPriv.isEmpty || anon.xPriv.isEmpty)) {
      return false;
    }
    final db = await _open();
    return db.transaction((t) async {
      final r = await _row(t);
      if (r == null || r.state != DevState.fresh) return false;
      final id = key.chatId;
      final have = await t.query(
        'contacts',
        columns: ['xpub'],
        where: 'halo_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (have.isNotEmpty && have.first['xpub'] != key.xPub) return false;
      final at = _now();
      final row = {
        'onion': '',
        'xpub': key.xPub,
        'last_seen': at,
        'accepted': 1,
        'verified': 1,
        'blocked': 0,
        'key_changed': 0,
        'unread': 0,
        'peer_bundle': anon == null ? key.bundle : null,
        'pinned': r.pinned ? 1 : 0,
        'muted': r.muted ? 1 : 0,
        'archived': r.archived ? 1 : 0,
      };
      if (have.isEmpty) {
        await t.insert('contacts', {'halo_id': id, 'first_seen': at, ...row});
      } else {
        await t.update('contacts', row, where: 'halo_id = ?', whereArgs: [id]);
      }
      final n = await t.update(
        'devchat',
        {
          'state': anon == null ? DevState.everyday.name : DevState.anon.name,
          'key_id': key.keyId,
          'started_at': at,
          'anon_id': anon?.id,
          'anon_ed_priv': anon?.edPriv,
          'anon_x_priv': anon?.xPriv,
        },
        where: 'k = ? AND state = ?',
        whereArgs: [1, DevState.fresh.name],
      );
      if (n != 1) throw StateError('dev chat: the row moved under a start');
      return true;
    });
  }

  // the settings row "Write to Marios": after a delete, a fresh chat as a
  // new install has it, on this tap only. otherwise the chat as it is. the
  // chat to open, or null with no key to talk to
  Future<String?> writeToMarios() async {
    final db = await _open();
    return db.transaction((t) async {
      final r = await _row(t);
      if (r != null && r.state != DevState.gone) return r.chatId;
      final k = currentDevKey;
      if (k == null) return null;
      await t.insert(
        'devchat',
        _fresh(k.keyId, _now()),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return k.chatId;
    });
  }

  static Map<String, Object?> _fresh(String keyId, int at) => {
    'k': 1,
    'state': DevState.fresh.name,
    'key_id': keyId,
    'pinned': 1,
    'muted': 0,
    'archived': 0,
    'anon_id': null,
    'anon_ed_priv': null,
    'anon_x_priv': null,
    'created_at': at,
    'started_at': null,
  };

  // deleted means gone: every dev: chat's messages and all that hangs off
  // them, its contact row, its signal session and identity, the name made
  // for it, and the files it named. the row stays, as gone, so no seed
  // brings it back. one transaction, with freed pages zeroed
  Future<void> delete() async {
    final db = await _open();
    final was = await db.rawQuery('PRAGMA secure_delete');
    final secure = was.isEmpty ? null : was.first.values.first;
    await db.rawQuery('PRAGMA secure_delete = 1');
    final List<String> files;
    try {
      files = await db.transaction(_wipe);
    } finally {
      await db.rawQuery('PRAGMA secure_delete = ${secure == 1 ? 1 : 0}');
    }
    for (final f in files) {
      await _shred(f);
    }
    // the zeroed pages into the file itself
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (e) {
      // the rows are gone already, and sqlite's next fold takes the pages
      dlog('dev chat: log not folded (${e.runtimeType})');
    }
  }

  Future<List<String>> _wipe(Transaction t) async {
    final r = await _row(t);
    final msgs = await t.query(
      'messages',
      columns: ['id', 'msg_uid', 'media_path', 'file_path', 'poll'],
      where: 'peer_id LIKE ?',
      whereArgs: [_kDev],
    );
    final people = await t.query(
      'contacts',
      columns: ['atmosphere'],
      where: 'halo_id LIKE ?',
      whereArgs: [_kDev],
    );
    final files = <String>[
      for (final m in msgs)
        for (final col in const ['media_path', 'file_path'])
          if (m[col] case final String f when f.isNotEmpty) f,
      for (final p in people)
        if (p['atmosphere'] case final String a when a.startsWith('image:'))
          a.substring(6),
    ];
    final uids = [
      for (final m in msgs)
        if (m['msg_uid'] case final String u) u,
    ];
    final polls = [
      for (final m in msgs)
        if (m['poll'] != null && m['msg_uid'] is String) m['msg_uid'] as String,
    ];
    final wants = [
      for (final w in await t.query(
        'media_wants',
        columns: ['media_id'],
        where: 'peer_id LIKE ?',
        whereArgs: [_kDev],
      ))
        w['media_id'] as String,
    ];
    await _inChunks(t, 'reactions', 'msg_uid', uids);
    await _inChunks(t, 'poll_votes', 'poll_uid', uids);
    await _inChunks(t, 'pins_out', 'msg_uid', uids);
    await _inChunks(t, 'edits_out', 'msg_uid', uids);
    await _inChunks(t, 'msg_fts', 'rowid', [for (final m in msgs) m['id']]);
    await _inChunks(t, 'media_chunks', 'media_id', wants);
    for (final (table, col) in const [
      ('media_wants', 'peer_id'),
      ('held_onion', 'peer_id'),
      ('pins_out', 'peer_id'),
      ('edits_out', 'peer_id'),
      ('frames_out', 'peer_id'),
      ('shield', 'halo_id'),
      ('vouches', 'halo_id'),
      ('vouches', 'voucher_id'),
      ('group_members', 'halo_id'),
      ('group_media_owed', 'member'),
      ('group_ctl_out', 'member'),
      ('messages', 'peer_id'),
      ('contacts', 'halo_id'),
      ('sessions', 'address'),
      ('peer_identities', 'address'),
    ]) {
      await t.delete(table, where: '$col LIKE ?', whereArgs: [_kDev]);
    }
    // the anonymous chat's own store, all of it
    await clearDevStore(t);
    // the delete marked its polls as just gone: nothing of them stays
    await _inChunks(t, 'polls_gone', 'uid', polls);
    await t.insert('devchat', {
      ..._fresh(r?.keyId ?? '', r?.createdAt ?? _now()),
      'state': DevState.gone.name,
      'pinned': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return files;
  }

  static Future<void> _inChunks(
    Transaction t,
    String table,
    String col,
    List<Object?> keys,
  ) async {
    for (var i = 0; i < keys.length; i += 400) {
      final part = keys.sublist(i, min(i + 400, keys.length));
      await t.delete(
        table,
        where: '$col IN (${List.filled(part.length, '?').join(', ')})',
        whereArgs: part,
      );
    }
  }
}
