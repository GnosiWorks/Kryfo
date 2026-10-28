// SPDX-License-Identifier: GPL-3.0-or-later
// a new device takes the phone's history in: each record checked by the
// engine, then put in the database in one transaction with the stream's
// place, so a cut at any record resumes without losing or doubling a row.
// at the end every chat is counted again and compared with what the phone
// signed; a difference is shown, never passed over
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../search.dart' show searchBody;
import 'history_export.dart'
    show
        HistoryChatGap,
        HistoryChatRef,
        kHistoryContactCols,
        kHistoryGroupCols,
        kHistoryMessageCols;
import 'history_ffi.dart';

// files on their way in, beside the media folder's own
const _kPartDir = '.history';

// a file's state on the device
const _fileWaiting = 0;
const _fileWhole = 1;
const _fileLost = -1;

Future<void> historyTables(DatabaseExecutor t) async {
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_in (k INTEGER PRIMARY KEY CHECK '
    '(k = 1), stream TEXT NOT NULL, plan BLOB NOT NULL, state BLOB NOT NULL)',
  );
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_chats (n INTEGER PRIMARY KEY, '
    'grp INTEGER NOT NULL, chat_id TEXT NOT NULL)',
  );
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_rows (msg_id INTEGER PRIMARY KEY, '
    'n INTEGER NOT NULL, made INTEGER NOT NULL)',
  );
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_files (file INTEGER PRIMARY KEY, '
    'n INTEGER NOT NULL, name TEXT NOT NULL, size INTEGER NOT NULL, '
    'ok INTEGER NOT NULL DEFAULT 0)',
  );
}

const _kTables = [
  'history_in',
  'history_chats',
  'history_rows',
  'history_files',
];

/// the end of an import: what differs, and the tally for the phone
class HistoryResult {
  const HistoryResult(this.gaps, this.tally);
  final List<HistoryChatGap> gaps;
  final Uint8List tally;
  bool get whole => gaps.isEmpty;
}

/// the device's side of one stream
class HistoryImport {
  HistoryImport._(
    this._db,
    this._media,
    this._key,
    this._bind,
    this._identity,
    this._verify,
    this._r,
  );

  final Database _db;
  final String _media;
  final String _key;
  final String _bind;
  final String _identity;
  final Future<bool> Function(Uint8List body, Uint8List sig) _verify;
  HistoryReceiver _r;
  final _chats = <int, HistoryChatRef>{};
  final _files = <int, ({int chat, String name, int size, int ok})>{};
  final _cols = <String, Set<String>>{};
  bool _done = false;

  /// opens the stream [bindHex] names, taken up where it was left when this
  /// database holds its place. [verify] is ks_verify_ctx under the
  /// identity, "history-counts", over the head's body and signature
  static Future<HistoryImport> open({
    required Database db,
    required String mediaDir,
    required String keyHex,
    required String bindHex,
    required String identityHex,
    required Future<bool> Function(Uint8List body, Uint8List sig) verify,
  }) async {
    await historyTables(db);
    final held = await db.query('history_in', where: 'k = 1');
    HistoryReceiver? r;
    if (held.isNotEmpty && held.first['stream'] == bindHex) {
      r = HistoryReceiver.resume(
        keyHex: keyHex,
        bindHex: bindHex,
        identityHex: identityHex,
        plan: _blob(held.first['plan']),
        state: _blob(held.first['state']),
      );
      if (r == null) {
        throw const HistoryRefused('stored place', forGood: true);
      }
    } else if (held.isNotEmpty ||
        (await db.query('history_rows', limit: 1)).isNotEmpty) {
      // another stream's rows: a new stream starts from nothing
      await _discard(db, mediaDir);
      await historyTables(db);
    }
    r ??= HistoryReceiver.open(
      keyHex: keyHex,
      bindHex: bindHex,
      identityHex: identityHex,
    );
    final imp = HistoryImport._(
      db,
      mediaDir,
      keyHex,
      bindHex,
      identityHex,
      verify,
      r,
    );
    await imp._load();
    return imp;
  }

  static Uint8List _blob(Object? v) => v is Uint8List
      ? v
      : v is List<int>
      ? Uint8List.fromList(v)
      : Uint8List(0);

  // what the database already says of the chats and files, and the files a
  // cut left between their commit and their move
  Future<void> _load() async {
    for (final c in await _db.query('history_chats')) {
      _chats[c['n'] as int] = HistoryChatRef(
        c['grp'] == 1,
        c['chat_id'] as String,
      );
    }
    for (final f in await _db.query('history_files')) {
      final n = f['file'] as int;
      _files[n] = (
        chat: f['n'] as int,
        name: f['name'] as String,
        size: f['size'] as int,
        ok: f['ok'] as int,
      );
      if (f['ok'] == _fileWhole) await _settle(n);
    }
    _done = _r.done;
  }

  /// the index the phone sends next
  int get next => _r.next;

  bool get done => _done;

  String _part(int file) => p.join(_media, _kPartDir, '$file.part');
  String _final(String name) => p.join(_media, p.joinAll(name.split('/')));

  Future<Set<String>> _colsOf(DatabaseExecutor t, String table) async =>
      _cols[table] ??= {
        for (final r in await t.rawQuery('PRAGMA table_info($table)'))
          r['name'] as String,
      };

  /// one record from the phone. HistoryRefused when it is not the one due
  /// (send it again) or the stream cannot go on ([HistoryRefused.forGood])
  Future<HistoryEvent> take(Uint8List rec) async {
    final ev = _r.take(rec);
    try {
      if (ev.kind == 'head') {
        final h = ev.head!;
        final ok = await _verify(h.body!, h.sig!);
        _r.trust(ok);
      }
      if (ev.kind == 'data') await _write(ev);
      if (ev.kind == 'gone') await _drop(ev.file);
      await _db.transaction((t) async {
        await _apply(t, ev);
        // the plan holds the whole media list: written only when it grew
        if (ev.planChanged) {
          await t.insert('history_in', {
            'k': 1,
            'stream': _bind,
            'plan': _r.plan(),
            'state': _r.state(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await t.update('history_in', {'state': _r.state()}, where: 'k = 1');
        }
      });
    } catch (e) {
      // the engine moved on and the database did not: back to its place
      await _rewind();
      rethrow;
    }
    if (ev.kind == 'data' && ev.last && ev.ok) await _settle(ev.file);
    if (ev.kind == 'end') _done = true;
    return ev;
  }

  Future<void> _rewind() async {
    _r.close();
    _cols.clear();
    _chats.clear();
    _files.clear();
    final held = await _db.query('history_in', where: 'k = 1');
    final r = held.isEmpty
        ? null
        : HistoryReceiver.resume(
            keyHex: _key,
            bindHex: _bind,
            identityHex: _identity,
            plan: _blob(held.first['plan']),
            state: _blob(held.first['state']),
          );
    _r =
        r ??
        HistoryReceiver.open(
          keyHex: _key,
          bindHex: _bind,
          identityHex: _identity,
        );
    await _load();
  }

  // a chunk lands at its place in the file's part, whatever a cut left
  // after it
  Future<void> _write(HistoryEvent ev) async {
    final f = _files[ev.file];
    if (f == null || f.ok == _fileLost) return;
    final part = File(_part(ev.file));
    await part.parent.create(recursive: true);
    final raf = await part.open(mode: FileMode.append);
    try {
      await raf.truncate(ev.offset);
      await raf.setPosition(ev.offset);
      await raf.writeFrom(ev.bytes);
      if (ev.last) await raf.flush();
    } finally {
      await raf.close();
    }
  }

  Future<void> _drop(int file) async {
    try {
      await File(_part(file)).delete();
    } on PathNotFoundException {
      // nothing of it came yet
    }
  }

  // a whole file moves from its part to its name, once its row says whole
  Future<void> _settle(int file) async {
    final f = _files[file];
    if (f == null) return;
    final part = File(_part(file));
    if (!await part.exists()) return;
    final to = File(_final(f.name));
    await to.parent.create(recursive: true);
    await part.rename(to.path);
  }

  Future<void> _apply(Transaction t, HistoryEvent ev) async {
    switch (ev.kind) {
      case 'chat':
        await _chat(t, ev.chat, ev.meta!);
      case 'messages':
        await _messages(t, ev.chat, ev.rows);
      case 'media':
        var n = ev.first;
        for (final m in ev.media) {
          final f = (
            chat: (m['chat'] as num).toInt(),
            name: m['name'] as String,
            size: (m['size'] as num).toInt(),
            ok: _fileWaiting,
          );
          await t.insert('history_files', {
            'file': n,
            'n': f.chat,
            'name': f.name,
            'size': f.size,
            'ok': f.ok,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          _files[n++] = f;
        }
      case 'data' when ev.last:
        final ok = ev.ok && _files[ev.file]?.ok != _fileLost;
        await _fileOk(t, ev.file, ok ? _fileWhole : _fileLost);
      case 'gone':
        await _fileOk(t, ev.file, _fileLost);
    }
  }

  Future<void> _fileOk(Transaction t, int file, int ok) async {
    await t.update(
      'history_files',
      {'ok': ok},
      where: 'file = ?',
      whereArgs: [file],
    );
    final f = _files[file];
    if (f != null) {
      _files[file] = (chat: f.chat, name: f.name, size: f.size, ok: ok);
    }
  }

  Map<String, Object?> _pick(
    Map<String, dynamic> row,
    List<String> allowed,
    Set<String> have,
  ) => {
    for (final c in allowed)
      if (have.contains(c) && row.containsKey(c)) c: row[c],
  };

  Future<void> _chat(Transaction t, int n, Map<String, dynamic> meta) async {
    final group = meta['kind'] == 'group';
    final id = meta['id'] as String;
    final row = (meta['row'] as Map).cast<String, dynamic>();
    if (group) {
      final g = _pick(row, kHistoryGroupCols, await _colsOf(t, 'groups'))
        ..['group_id'] = id;
      await t.insert('groups', g, conflictAlgorithm: ConflictAlgorithm.ignore);
      // members and senders as keys only, never over a contact already here
      for (final c in (meta['people'] as List? ?? const [])) {
        final m = (c as Map).cast<String, dynamic>();
        final now = (m['first_seen'] as num?)?.toInt() ?? 0;
        await t.insert('contacts', {
          'halo_id': m['halo_id'],
          'onion': m['onion'] ?? '',
          'xpub': m['xpub'] ?? '',
          'first_seen': now,
          'last_seen': now,
          'accepted': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final m in (meta['members'] as List? ?? const [])) {
        final x = (m as Map).cast<String, dynamic>();
        await t.insert('group_members', {
          'group_id': id,
          'halo_id': x['halo_id'],
          'joined_at': x['joined_at'] ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } else {
      final c = _pick(row, kHistoryContactCols, await _colsOf(t, 'contacts'))
        ..['halo_id'] = id;
      c['onion'] ??= '';
      c['xpub'] ??= '';
      c['first_seen'] ??= 0;
      c['last_seen'] ??= 0;
      // a full row takes the place of a key-only one, never of a full one
      final was = await t.query(
        'contacts',
        columns: ['accepted'],
        where: 'halo_id = ?',
        whereArgs: [id],
      );
      if (was.isEmpty) {
        await t.insert('contacts', c);
      } else if (was.first['accepted'] == 0 && c['accepted'] == 1) {
        await t.update('contacts', c, where: 'halo_id = ?', whereArgs: [id]);
      }
    }
    await t.insert('history_chats', {
      'n': n,
      'grp': group ? 1 : 0,
      'chat_id': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _chats[n] = HistoryChatRef(group, id);
  }

  Future<void> _messages(
    Transaction t,
    int n,
    List<Map<String, dynamic>> rows,
  ) async {
    final chat = _chats[n];
    if (chat == null) throw const HistoryRefused('a chat never opened');
    final have = await _colsOf(t, 'messages');
    final fts = await _hasFts(t);
    for (final r in rows) {
      final m = _pick(r, kHistoryMessageCols, have);
      // a row lands in the chat it came in, whatever it says
      if (chat.group) {
        m['group_id'] = chat.id;
      } else {
        m['peer_id'] = chat.id;
        m['group_id'] = null;
      }
      for (final col in const ['media_path', 'file_path']) {
        final v = m[col];
        if (v is String && v.isNotEmpty) {
          m[col] = _safe(v) ? _final(v) : null;
        }
      }
      m['peer_id'] ??= '';
      m['direction'] ??= 'in';
      m['plaintext'] ??= '';
      m['sent_at'] ??= 0;
      // one that came here live before the copy is counted, not doubled
      int? id;
      var made = 0;
      final uid = m['msg_uid'];
      if (uid is String) {
        final there = await t.rawQuery(
          'SELECT id FROM messages WHERE msg_uid = ? AND id NOT IN '
          '(SELECT msg_id FROM history_rows) LIMIT 1',
          [uid],
        );
        if (there.isNotEmpty) id = there.first['id'] as int;
      }
      if (id == null) {
        made = 1;
        id = await t.insert('messages', m);
        if (fts) {
          final body = searchBody(m);
          if (body.trim().isNotEmpty) {
            await t.insert('msg_fts', {'rowid': id, 'body': body});
          }
        }
      }
      await t.insert('history_rows', {
        'msg_id': id,
        'n': n,
        'made': made,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (uid is! String) continue;
      for (final x in (r['x_reactions'] as List? ?? const [])) {
        final e = (x as Map).cast<String, dynamic>();
        await t.insert('reactions', {
          'msg_uid': uid,
          'reactor': e['reactor'],
          'emoji': e['emoji'],
          'reacted_at': e['reacted_at'] ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final x in (r['x_votes'] as List? ?? const [])) {
        final e = (x as Map).cast<String, dynamic>();
        await t.insert('poll_votes', {
          'poll_uid': uid,
          'voter': e['voter'],
          'group_id': e['group_id'],
          'choices': e['choices'] ?? '',
          'seq': e['seq'] ?? 0,
          'at': e['at'] ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  bool? _fts;
  Future<bool> _hasFts(DatabaseExecutor t) async => _fts ??= (await t.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE name = 'msg_fts'",
  )).isNotEmpty;

  // the phone's names, checked again here: only inside the media folder
  static bool _safe(String n) {
    if (n.isEmpty || n.startsWith('/') || n.contains(r'\')) return false;
    if (n.codeUnits.any((c) => c < 32)) return false;
    return n.split('/').every((s) => s.isNotEmpty && s != '.' && s != '..');
  }

  /// the counts in the database now, chat by chat in the stream's order:
  /// the rows this stream put there that are still there, and its files
  /// that are whole on disk
  Future<List<HistoryCount>> counts() async {
    final msgs = <int, int>{};
    for (final r in await _db.rawQuery(
      'SELECT hr.n AS n, COUNT(*) AS c FROM history_rows hr '
      'JOIN history_chats hc ON hc.n = hr.n '
      'JOIN messages m ON m.id = hr.msg_id '
      'WHERE (hc.grp = 1 AND m.group_id = hc.chat_id) OR (hc.grp = 0 '
      'AND m.peer_id = hc.chat_id AND m.group_id IS NULL) GROUP BY hr.n',
    )) {
      msgs[r['n'] as int] = r['c'] as int;
    }
    final files = <int, (int, int)>{};
    for (final f in await _db.query(
      'history_files',
      where: 'ok = ?',
      whereArgs: [_fileWhole],
    )) {
      final file = File(_final(f['name'] as String));
      final size = f['size'] as int;
      if (!await file.exists() || await file.length() != size) continue;
      final n = f['n'] as int;
      final was = files[n] ?? (0, 0);
      files[n] = (was.$1 + 1, was.$2 + size);
    }
    final count = (await _db.query('history_chats')).length;
    return [
      for (var n = 0; n < count; n++)
        HistoryCount(msgs[n] ?? 0, files[n]?.$1 ?? 0, files[n]?.$2 ?? 0),
    ];
  }

  /// once the stream is whole: every chat counted again and compared with
  /// what the phone signed, and the tally to send it back
  Future<HistoryResult> finish() async {
    if (!_done) throw const HistoryRefused('not whole yet');
    final got = await counts();
    final gaps = _r.check(got);
    return HistoryResult([
      for (final g in gaps)
        HistoryChatGap(
          _chats[g.chat] ?? HistoryChatRef(false, ''),
          g.want,
          g.got,
        ),
    ], _r.tally(got));
  }

  /// the bookkeeping goes once the person has seen the result; the rows
  /// and files stay
  Future<void> clear() async {
    _r.close();
    for (final t in _kTables) {
      await _db.execute('DROP TABLE IF EXISTS $t');
    }
    try {
      await Directory(p.join(_media, _kPartDir)).delete(recursive: true);
    } on PathNotFoundException {
      // no file was on its way
    }
  }

  /// a stream that cannot finish takes back what it put here
  Future<void> discard() async {
    _r.close();
    await _discard(_db, _media);
  }

  void close() => _r.close();

  static Future<void> _discard(Database db, String mediaDir) async {
    await historyTables(db);
    final files = await db.query('history_files');
    // only what the stream made: a row that was here before stays
    const made = '(SELECT msg_id FROM history_rows WHERE made = 1)';
    await db.transaction((t) async {
      final fts = (await t.rawQuery(
        "SELECT 1 FROM sqlite_master WHERE name = 'msg_fts'",
      )).isNotEmpty;
      if (fts) {
        await t.execute('DELETE FROM msg_fts WHERE rowid IN $made');
      }
      for (final table in const ['reactions', 'poll_votes']) {
        final col = table == 'reactions' ? 'msg_uid' : 'poll_uid';
        await t.execute(
          'DELETE FROM $table WHERE $col IN (SELECT msg_uid FROM messages '
          'WHERE id IN $made)',
        );
      }
      await t.execute('DELETE FROM messages WHERE id IN $made');
      for (final table in _kTables) {
        await t.execute('DROP TABLE IF EXISTS $table');
      }
    });
    for (final f in files) {
      final name = f['name'] as String;
      if (!_safe(name)) continue;
      try {
        await File(p.join(mediaDir, p.joinAll(name.split('/')))).delete();
      } on PathNotFoundException {
        // never came
      }
    }
    try {
      await Directory(p.join(mediaDir, _kPartDir)).delete(recursive: true);
    } on PathNotFoundException {
      // nothing on its way
    }
  }
}
