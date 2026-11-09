// SPDX-License-Identifier: GPL-3.0-or-later
// a new device takes the phone's history in: each record checked by the
// engine, then put in the database in one transaction with the stream's
// place, so a cut at any record resumes without losing or doubling a row.
// at the end every chat is counted again and compared with what the phone
// signed; a difference is shown, never passed over
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../desktop/sealed_format.dart'
    show
        ChunkCrypto,
        EngineChunkCrypto,
        chunkPlain,
        isSealedHead,
        openChunk,
        plainLength,
        sealedHead;
import '../main.dart' show goneKey, goneKept;
import '../search.dart' show searchBody;
import '../l10n/l10n.dart';
import 'history_files.dart';
import 'history_export.dart'
    show
        HistoryChatGap,
        HistoryChatLeft,
        HistoryChatRef,
        historyLeftOf,
        kHistoryContactCols,
        kHistoryMaterial,
        kHistoryGroupCols,
        kHistoryMessageCols,
        kHistorySupport,
        kHistoryViaDev;
import 'history_ffi.dart';

// files on their way in, beside the media folder's own
const _kPartDir = '.history';

// a file's state on the device
const _fileWaiting = 0;
const _fileWhole = 1;
const _fileLost = -1;
// no row of the copy points at it: the device kept its own file for the
// message, or deleted the message. never written, counted as come
const _fileHere = 2;

// one record that never opens, again and again: a spool gone bad, or a
// link that keeps cutting it short. past this many tries at one index the
// copy pauses, and nothing taken so far goes
const kHistoryTries = 16;

/// the line a chat that stayed on the phone shows on the new device. a
/// screenshot block is the one reason there is
String historyStaysText(String why) => l10n.historyChatStaysShots;

// the stream key is kept here, inside the device's own encrypted database,
// so a restart of the device can take the copy up again. the phone never
// keeps it. clear and discard drop it
Future<void> historyTables(DatabaseExecutor t) async {
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_in (k INTEGER PRIMARY KEY CHECK '
    '(k = 1), stream TEXT NOT NULL, stream_key TEXT NOT NULL, '
    'bind TEXT NOT NULL, id TEXT NOT NULL, identity TEXT NOT NULL, '
    'plan BLOB NOT NULL, state BLOB NOT NULL)',
  );
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_chats (n INTEGER PRIMARY KEY, '
    'grp INTEGER NOT NULL, chat_id TEXT NOT NULL, stays TEXT)',
  );
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_rows (msg_id INTEGER PRIMARY KEY, '
    'n INTEGER NOT NULL, made INTEGER NOT NULL)',
  );
  // rows of the copy this device had deleted already: left out, counted
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_gone (n INTEGER PRIMARY KEY, '
    'c INTEGER NOT NULL)',
  );
  // a file the phone keeps sealed comes as it lies there, with its own
  // key: opened once whole, the key gone with it
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_keys (name TEXT PRIMARY KEY, '
    'key BLOB NOT NULL)',
  );
  // the lists the phone held, taken at the end
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_lists (identity TEXT PRIMARY KEY, '
    'wire TEXT NOT NULL)',
  );
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_files (file INTEGER PRIMARY KEY, '
    'n INTEGER NOT NULL, name TEXT NOT NULL, size INTEGER NOT NULL, '
    'ok INTEGER NOT NULL DEFAULT 0)',
  );
  // every row the copy made beside the messages (a contact, a group, a
  // member, a gone row, a proof), and a key-only contact it filled with
  // the row it had before: a discard takes them back
  await t.execute(
    'CREATE TABLE IF NOT EXISTS history_made (t TEXT NOT NULL, '
    "a TEXT NOT NULL, b TEXT NOT NULL DEFAULT '', was TEXT, "
    'PRIMARY KEY (t, a, b))',
  );
}

const _kTables = [
  'history_in',
  'history_chats',
  'history_rows',
  'history_gone',
  'history_keys',
  'history_lists',
  'history_files',
  'history_made',
];

// what history_made names
const _madeContact = 'contact';
const _madeFilled = 'filled';
const _madeGroup = 'group';
const _madeMember = 'member';
const _madeGone = 'gone';
const _madeProven = 'proven';
const _madePq = 'pq';
const _madeSupport = 'support';

// the inbox states a copy may set: a chat the phone moved to Chats stays out
const _supportStates = {'open', 'done', 'out'};

Future<void> _made(
  DatabaseExecutor t,
  String kind,
  String a, [
  String b = '',
  String? was,
]) => t.insert('history_made', {
  't': kind,
  'a': a,
  'b': b,
  'was': was,
}, conflictAlgorithm: ConflictAlgorithm.ignore);

Future<bool> _exists(
  DatabaseExecutor t,
  String table,
  String where,
  List<Object?> args,
) async => (await t.query(
  table,
  columns: ['1'],
  where: where,
  whereArgs: args,
  limit: 1,
)).isNotEmpty;

// a row's values as json, bytes as base64, and back
String _rowJson(Map<String, Object?> r) => jsonEncode({
  for (final e in r.entries)
    e.key: e.value is List<int>
        ? {'b': base64Encode(e.value! as List<int>)}
        : e.value,
});

Map<String, Object?> _rowOf(String j) => {
  for (final e in (jsonDecode(j) as Map).entries)
    e.key as String: e.value is Map
        ? base64Decode((e.value as Map)['b'] as String)
        : e.value,
};

/// a chat that came as its row alone, and why
class HistoryStay {
  const HistoryStay(this.chat, this.why);
  final HistoryChatRef chat;
  final String why;
  String get line => historyStaysText(why);
}

/// the end of an import: what differs, what the phone could not send, the
/// chats that stayed there, and the tally for the phone
class HistoryResult {
  const HistoryResult(
    this.gaps,
    this.left,
    this.leftChats,
    this.stays,
    this.tally,
  );
  final List<HistoryChatGap> gaps;
  final List<HistoryChatLeft> left;
  final int leftChats;
  final List<HistoryStay> stays;
  final Uint8List tally;

  /// nothing lost on the way and nothing left out
  bool get whole => gaps.isEmpty && left.isEmpty && leftChats == 0;
}

/// the device's side of one stream
class HistoryImport {
  HistoryImport._(
    this._db,
    this._media,
    this._key,
    this._bind,
    this._id,
    this._identity,
    this._r,
    this._crypto,
    this._coming,
  );

  final Database _db;
  final String _media;
  final String _key;
  final String _bind;
  final String _id;
  final String _identity;
  HistoryReceiver _r;
  final ChunkCrypto _crypto;
  // the bubbles' list of files on their way, when the app shows one
  final HistoryFilesComing? _coming;
  // a rewind that failed: nothing more until the import is opened again
  bool _stopped = false;
  int _triesAt = -1;
  int _tries = 0;
  bool _paused = false;

  /// the copy paused after kHistoryTries refusals at one index
  bool get paused => _paused;

  /// takes records again after a pause, the same index first
  void resume() {
    _paused = false;
    _tries = 0;
  }

  final _chats = <int, HistoryChatRef>{};
  final _files = <int, ({int chat, String name, int size, int ok})>{};
  final _cols = <String, Set<String>>{};
  bool _done = false;

  /// opens the stream of the link [bindHex] from the sender [idHex] (the
  /// phone's first answer gives it), taken up where it was left when this
  /// database holds its place. a stream from another link or another sender
  /// starts again from nothing: its text may be other text
  static Future<HistoryImport> open({
    required Database db,
    required String mediaDir,
    required String keyHex,
    required String bindHex,
    required String idHex,
    required String identityHex,
    ChunkCrypto crypto = const EngineChunkCrypto(),
    HistoryFilesComing? coming,
  }) async {
    await historyTables(db);
    final stream = '$bindHex/$idHex';
    final held = await db.query('history_in', where: 'k = 1');
    HistoryReceiver? r;
    if (held.isNotEmpty && held.first['stream'] == stream) {
      r = HistoryReceiver.resume(
        keyHex: keyHex,
        bindHex: bindHex,
        idHex: idHex,
        identityHex: identityHex,
        plan: _blob(held.first['plan']),
        state: _blob(held.first['state']),
      );
      if (r == null) {
        throw const HistoryRefused('stored place', forGood: true);
      }
    } else if (held.isNotEmpty ||
        (await db.query('history_rows', limit: 1)).isNotEmpty) {
      await _discard(db, mediaDir);
      await historyTables(db);
    }
    r ??= HistoryReceiver.open(
      keyHex: keyHex,
      bindHex: bindHex,
      idHex: idHex,
      identityHex: identityHex,
    );
    final imp = HistoryImport._(
      db,
      mediaDir,
      keyHex,
      bindHex,
      idHex,
      identityHex,
      r,
      crypto,
      coming,
    );
    await imp._load();
    return imp;
  }

  /// the copy this database holds the place of, after a restart of the
  /// device; null when it holds none
  static Future<HistoryImport?> reopen({
    required Database db,
    required String mediaDir,
    ChunkCrypto crypto = const EngineChunkCrypto(),
  }) async {
    await historyTables(db);
    final held = await db.query('history_in', where: 'k = 1');
    if (held.isEmpty) return null;
    final h = held.first;
    return open(
      db: db,
      mediaDir: mediaDir,
      keyHex: h['stream_key'] as String,
      bindHex: h['bind'] as String,
      idHex: h['id'] as String,
      identityHex: h['identity'] as String,
      crypto: crypto,
    );
  }

  /// the files a copy this database holds still brings, by their paths
  /// here: those its list waits on, or before its list came, those its rows
  /// name that are not here yet
  static Future<List<String>> comingOf(Database db, String mediaDir) async {
    await historyTables(db);
    String at(String name) => p.join(mediaDir, p.joinAll(name.split('/')));
    final files = await db.query('history_files');
    if (files.isNotEmpty) {
      return [
        for (final f in files)
          if (f['ok'] == _fileWaiting ||
              (f['ok'] == _fileWhole &&
                  await File(
                    p.join(mediaDir, _kPartDir, '${f['file']}.part'),
                  ).exists()))
            at(f['name'] as String),
      ];
    }
    final out = <String>[];
    for (final r in await db.rawQuery(
      'SELECT media_path, file_path FROM messages '
      'WHERE id IN (SELECT msg_id FROM history_rows)',
    )) {
      for (final v in [r['media_path'], r['file_path']]) {
        if (v is String && p.isWithin(mediaDir, v) && !await File(v).exists()) {
          out.add(v);
        }
      }
    }
    return out;
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
      if (f['ok'] == _fileWhole) {
        await _settle(n);
        _landed(n);
      }
    }
    _done = _r.done;
  }

  /// the index the phone sends next
  int get next => _r.next;

  /// the stream's head, once record 0 is in
  HistoryHead? get head => _r.head();

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
    if (_stopped) throw const HistoryRefused('open it again');
    if (_paused) throw const HistoryRefused('paused', paused: true);
    final at = _r.next;
    final HistoryEvent ev;
    try {
      ev = _r.take(rec);
    } on HistoryRefused catch (e) {
      if (e.forGood) rethrow;
      _tries = _triesAt == at ? _tries + 1 : 1;
      _triesAt = at;
      if (_tries >= kHistoryTries) {
        _paused = true;
        throw const HistoryRefused('paused', paused: true);
      }
      rethrow;
    }
    _tries = 0;
    try {
      if (ev.kind == 'data') await _write(ev);
      if (ev.kind == 'gone') await _drop(ev.file);
      await _db.transaction((t) async {
        await _apply(t, ev);
        // the plan holds the whole media list: written only when it grew
        if (ev.planChanged) {
          await t.insert('history_in', {
            'k': 1,
            'stream': '$_bind/$_id',
            'stream_key': _key,
            'bind': _bind,
            'id': _id,
            'identity': _identity,
            'plan': _r.plan(),
            'state': _r.state(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await t.update('history_in', {'state': _r.state()}, where: 'k = 1');
        }
      });
    } catch (e) {
      // the engine moved on and the database did not: back to its place.
      // when even that fails the import stops until it is opened again, and
      // what is stored stays
      try {
        await _rewind();
      } catch (_) {
        _stopped = true;
      }
      rethrow;
    }
    if (ev.kind == 'data' && ev.last) {
      if (ev.ok) await _settle(ev.file);
      _landed(ev.file);
    }
    if (ev.kind == 'gone') _landed(ev.file);
    if (ev.kind == 'media') _listed();
    final rowFiles = List.of(_rowFiles);
    _rowFiles.clear();
    final coming = _coming;
    if (coming != null && rowFiles.isNotEmpty) {
      coming.add([
        for (final f in rowFiles)
          if (!await File(f).exists()) f,
      ]);
    }
    if (ev.kind == 'end') {
      _done = true;
      _coming?.clear();
    }
    await _dropGoneFiles();
    return ev;
  }

  // files the rows of the last record name, for the bubbles
  final _rowFiles = <String>[];

  // the list came: the bubbles wait on what it brings, nothing else
  void _listed() => _coming?.only([
    for (final f in _files.values)
      if (f.ok == _fileWaiting) _final(f.name),
  ]);

  // a file landed or will not come: its bubble stops waiting
  void _landed(int file) {
    final f = _files[file];
    if (f != null) _coming?.done(_final(f.name));
  }

  Future<void> _dropGoneFiles() async {
    while (_goneFiles.isNotEmpty) {
      try {
        await File(_goneFiles.removeLast()).delete();
      } on FileSystemException {
        // gone already
      }
    }
  }

  Future<void> _rewind() async {
    _goneFiles.clear();
    _rowFiles.clear();
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
            idHex: _id,
            identityHex: _identity,
            plan: _blob(held.first['plan']),
            state: _blob(held.first['state']),
          );
    _r =
        r ??
        HistoryReceiver.open(
          keyHex: _key,
          bindHex: _bind,
          idHex: _id,
          identityHex: _identity,
        );
    await _load();
  }

  // a chunk lands at its place in the file's part, whatever a cut left
  // after it
  Future<void> _write(HistoryEvent ev) async {
    final f = _files[ev.file];
    if (f == null || f.ok == _fileLost || f.ok == _fileHere) return;
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

  // a whole file moves from its part to its name, once its row says whole.
  // one the phone keeps sealed is opened with its own key on the way, and
  // one that does not open counts as lost
  Future<void> _settle(int file) async {
    final f = _files[file];
    if (f == null) return;
    final part = File(_part(file));
    if (!await part.exists()) return;
    final to = File(_final(f.name));
    await to.parent.create(recursive: true);
    final keys = await _db.query(
      'history_keys',
      columns: ['key'],
      where: 'name = ?',
      whereArgs: [f.name],
    );
    final key = keys.isEmpty ? null : _blob(keys.first['key']);
    if (key == null || key.length != 32) {
      // sealed on the phone after its key was read: bytes no one here opens
      if (await _sealedPart(part)) {
        await _db.transaction((t) => _fileOk(t, file, _fileLost));
        await part.delete();
        return;
      }
      await part.rename(to.path);
      return;
    }
    final open = File('${_part(file)}.open');
    // a disk that fails or a seal that is locked here is no lost file: the
    // part and its key stay, and the next take or start tries again
    final ok = await _unseal(part, open, key);
    if (ok) {
      await open.rename(to.path);
    } else {
      try {
        await open.delete();
      } on FileSystemException {
        // never made
      }
      await _db.transaction((t) => _fileOk(t, file, _fileLost));
    }
    await part.delete();
    await _db.delete('history_keys', where: 'name = ?', whereArgs: [f.name]);
  }

  // the phone's sealed bytes in [from] to their plaintext in [to], chunk by
  // chunk. false when any chunk does not open under [fk]
  Future<bool> _unseal(File from, File to, Uint8List fk) async {
    RandomAccessFile? src, dst;
    try {
      src = await from.open();
      dst = await to.open(mode: FileMode.write);
      final size = await src.length();
      if (size < sealedHead || !isSealedHead(await src.read(sealedHead))) {
        return false;
      }
      final len = plainLength(size);
      if (len == null) return false;
      final last = len == 0 ? 0 : (len - 1) ~/ chunkPlain;
      for (var i = 0; i <= last; i++) {
        final n = i < last ? chunkPlain : len - i * chunkPlain;
        final stored = await src.read(n + 32);
        final plain = openChunk(_crypto, fk, i, i == last, stored);
        if (plain == null || plain.length != n) return false;
        await dst.writeFrom(plain);
      }
      await dst.flush();
      return true;
    } finally {
      fk.fillRange(0, fk.length, 0);
      try {
        await src?.close();
      } finally {
        await dst?.close();
      }
    }
  }

  // a part that starts as a sealed file does
  static Future<bool> _sealedPart(File part) async {
    final r = await part.open();
    try {
      if (await r.length() < sealedHead) return false;
      return isSealedHead(await r.read(sealedHead));
    } finally {
      await r.close();
    }
  }

  Future<void> _apply(Transaction t, HistoryEvent ev) async {
    switch (ev.kind) {
      case 'chat':
        await _chat(t, ev.chat, ev.meta!);
      case 'messages':
        await _messages(t, ev.chat, ev.rows);
      case 'media':
        // every row of the copy is in by now: the list follows the text
        final wanted = <String>{
          for (final r in await t.rawQuery(
            'SELECT media_path, file_path FROM messages '
            'WHERE id IN (SELECT msg_id FROM history_rows)',
          ))
            for (final v in [r['media_path'], r['file_path']])
              if (v is String) v,
        };
        var n = ev.first;
        for (final m in ev.media) {
          final name = m['name'] as String;
          final size = (m['size'] as num).toInt();
          final f = (
            chat: (m['chat'] as num).toInt(),
            name: name,
            size: size,
            ok: wanted.contains(_final(name)) && !await _held(t, name, size)
                ? _fileWaiting
                : _fileHere,
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
        final was = _files[ev.file]?.ok;
        if (was == _fileHere) return;
        final ok = ev.ok && was != _fileLost;
        await _fileOk(t, ev.file, ok ? _fileWhole : _fileLost);
      case 'gone':
        if (_files[ev.file]?.ok == _fileHere) return;
        await _fileOk(t, ev.file, _fileLost);
    }
  }

  // a file already here at its listed size, as an earlier copy left it: the
  // list comes before any chunk of this stream, so this stream never wrote
  // it, and it is neither written again nor taken back by a discard. a file
  // the phone keeps sealed counts by its plaintext: its sealed bytes left by
  // an older copy are no file to keep
  Future<bool> _held(DatabaseExecutor t, String name, int size) async {
    try {
      final have = await File(_final(name)).length();
      if (await _exists(t, 'history_keys', 'name = ?', [name])) {
        return have == plainLength(size);
      }
      return have == size;
    } on FileSystemException {
      return false;
    }
  }

  // a file at its listed size: the bytes as the phone holds them, or the
  // plaintext of a sealed one
  static bool _sizeOk(int have, int listed) =>
      have == listed || have == plainLength(listed);

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
    if (meta['kind'] == kHistoryMaterial) return _material(t, n, meta);
    final group = meta['kind'] == 'group';
    final id = meta['id'] as String;
    final row = (meta['row'] as Map).cast<String, dynamic>();
    if (group) {
      final g = _pick(row, kHistoryGroupCols, await _colsOf(t, 'groups'))
        ..['group_id'] = id;
      // a group that stays on the phone comes with its name alone
      g['name'] ??= '';
      g['created_at'] ??= 0;
      if (!await _exists(t, 'groups', 'group_id = ?', [id])) {
        await t.insert('groups', g);
        await _made(t, _madeGroup, id);
      }
      // members and senders as keys only, never over a contact already here
      for (final c in (meta['people'] as List? ?? const [])) {
        final m = (c as Map).cast<String, dynamic>();
        final now = (m['first_seen'] as num?)?.toInt() ?? 0;
        final who = m['halo_id'];
        if (who is! String) continue;
        if (await _exists(t, 'contacts', 'halo_id = ?', [who])) continue;
        await _made(t, _madeContact, who);
        await t.insert('contacts', {
          'halo_id': m['halo_id'],
          'onion': m['onion'] ?? '',
          'xpub': m['xpub'] ?? '',
          'first_seen': now,
          'last_seen': (m['last_seen'] as num?)?.toInt() ?? now,
          'back_paired': m['back_paired'] ?? 0,
          'blocked': m['blocked'] ?? 0,
          'accepted': 0,
        });
      }
      for (final m in (meta['members'] as List? ?? const [])) {
        final x = (m as Map).cast<String, dynamic>();
        final who = x['halo_id'];
        if (who is! String) continue;
        if (await _exists(t, 'group_members', 'group_id = ? AND halo_id = ?', [
          id,
          who,
        ])) {
          continue;
        }
        await t.insert('group_members', {
          'group_id': id,
          'halo_id': who,
          'joined_at': x['joined_at'] ?? 0,
        });
        await _made(t, _madeMember, id, who);
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
        await _made(t, _madeContact, id);
      } else if (was.first['accepted'] == 0 && c['accepted'] == 1) {
        // the key-only row as it was, for a discard
        final old = await t.query(
          'contacts',
          columns: c.keys.toList(),
          where: 'halo_id = ?',
          whereArgs: [id],
        );
        await _made(t, _madeFilled, id, '', _rowJson(old.first));
        await t.update('contacts', c, where: 'halo_id = ?', whereArgs: [id]);
      }
    }
    if (!group) await _support(t, id, meta[kHistorySupport]);
    final stays = meta['stays'];
    await t.insert('history_chats', {
      'n': n,
      'grp': group ? 1 : 0,
      'chat_id': id,
      'stays': stays is String ? stays : null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _chats[n] = HistoryChatRef(group, id);
  }

  // a chat of the developer's inbox, as the phone files it. one this device
  // filed already keeps its own state
  Future<void> _support(Transaction t, String id, Object? sp) async {
    if (sp is! Map) return;
    final s = sp['s'], f = sp['f'];
    if (s is! String || !_supportStates.contains(s)) return;
    if ((await _colsOf(t, 'support_chats')).isEmpty) return;
    if (await _exists(t, 'support_chats', 'halo_id = ?', [id])) return;
    await t.insert('support_chats', {
      'halo_id': id,
      'first_at': f is int ? f : 0,
      'state': s,
    });
    await _made(t, _madeSupport, id);
  }

  // what is no chat. the phone deleted these lately: noted gone here too,
  // and a copy this device got live goes, as it went there. the lists the
  // phone holds wait for the end, when the contacts are all here
  Future<void> _material(
    Transaction t,
    int n,
    Map<String, dynamic> meta,
  ) async {
    for (final g in (meta['gone'] as List? ?? const [])) {
      await _goneRow(t, g);
    }
    // what the phone's engine learnt of a contact: the keys their messages
    // came under, and a post-quantum session seen (never classic again)
    final dev = await _hasDev(t);
    for (final x in (meta['proven'] as List? ?? const [])) {
      if (!dev || x is! List || x.length != 2) continue;
      final peer = x[0], key = x[1];
      if (peer is! String || key is! String) continue;
      if (await _exists(t, 'dev_proven', 'ident = 0 AND peer = ? AND key = ?', [
        peer,
        key,
      ])) {
        continue;
      }
      await t.insert('dev_proven', {'ident': 0, 'peer': peer, 'key': key});
      await _made(t, _madeProven, peer, key);
    }
    for (final peer in (meta['pq'] as List? ?? const [])) {
      if (!dev || peer is! String) continue;
      if (await _exists(t, 'dev_pq', 'ident = 0 AND peer = ?', [peer])) {
        continue;
      }
      await t.insert('dev_pq', {'ident': 0, 'peer': peer});
      await _made(t, _madePq, peer);
    }
    for (final l in (meta['lists'] as List? ?? const [])) {
      if (l is! List || l.length != 2) continue;
      if (l[0] is! String || l[1] is! String) continue;
      await t.insert('history_lists', {
        'identity': l[0],
        'wire': l[1],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await t.insert('history_chats', {
      'n': n,
      'grp': 2,
      'chat_id': '',
      'stays': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _chats[n] = const HistoryChatRef(false, '');
  }

  // files of messages the phone deleted, gone from disk once their rows went
  final _goneFiles = <String>[];

  bool? _dev;
  Future<bool> _hasDev(DatabaseExecutor t) async => _dev ??= (await t.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE name = 'dev_proven'",
  )).isNotEmpty;

  // one gone row of the phone's [uid, key, at]: noted gone here, and every
  // incoming row of it in its chat goes, the copy's own too. a copy row
  // that goes counts as come, as one deleted here before does, and a file
  // of the copy it had counts as come too
  Future<void> _goneRow(Transaction t, Object? g) async {
    if (g is! List || g.length != 3) return;
    final uid = g[0], key = g[1], at = g[2];
    if (uid is! String || key is! String || at is! int) return;
    if (!await _exists(t, 'gone_in', 'msg_uid = ? AND peer_id = ?', [
      uid,
      key,
    ])) {
      await _made(t, _madeGone, uid, key);
    }
    await t.rawInsert(
      'INSERT INTO gone_in (msg_uid, peer_id, at) VALUES (?, ?, ?) '
      'ON CONFLICT (msg_uid, peer_id) DO UPDATE SET at = excluded.at '
      'WHERE excluded.at > gone_in.at',
      [uid, key, at],
    );
    final grp = key.startsWith('group:')
        ? key.substring(6, key.lastIndexOf(':'))
        : null;
    final sender = grp == null ? key : key.substring(key.lastIndexOf(':') + 1);
    final fts = await _hasFts(t);
    for (final r in await t.query(
      'messages',
      columns: ['id', 'media_path', 'file_path'],
      where: grp == null
          ? "msg_uid = ? AND peer_id = ? AND group_id IS NULL AND direction = 'in'"
          : "msg_uid = ? AND peer_id = ? AND group_id = ? AND direction = 'in'",
      whereArgs: grp == null ? [uid, sender] : [uid, sender, grp],
    )) {
      final id = r['id'] as int;
      final hr = await t.query(
        'history_rows',
        columns: ['n'],
        where: 'msg_id = ?',
        whereArgs: [id],
      );
      if (hr.isNotEmpty) {
        await t.delete('history_rows', where: 'msg_id = ?', whereArgs: [id]);
        await t.rawInsert(
          'INSERT INTO history_gone (n, c) VALUES (?, 1) '
          'ON CONFLICT (n) DO UPDATE SET c = c + 1',
          [hr.first['n']],
        );
      }
      if (fts) {
        await t.delete('msg_fts', where: 'rowid = ?', whereArgs: [id]);
      }
      await t.delete('messages', where: 'id = ?', whereArgs: [id]);
      for (final c in const ['media_path', 'file_path']) {
        final v = r[c];
        if (v is! String || v.isEmpty || !p.isWithin(_media, v)) continue;
        _goneFiles.add(v);
        for (final f in _files.entries) {
          if (_final(f.value.name) == v && f.value.ok != _fileHere) {
            await _fileOk(t, f.key, _fileHere);
          }
        }
      }
    }
    await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
  }

  /// what the phone deleted since it made the copy, once every record is
  /// in: taken as the copy's own gone rows are, for the copy's chats alone
  Future<void> goneSince(List<Object?> rows) async {
    if (_stopped) throw const HistoryRefused('open it again');
    final peers = {
      for (final c in _chats.values)
        if (!c.group && c.id.isNotEmpty) c.id,
    };
    final groups = {
      for (final c in _chats.values)
        if (c.group) c.id,
    };
    await _db.transaction((t) async {
      for (final g in rows) {
        if (g is! List || g.length != 3 || g[1] is! String) continue;
        final key = g[1] as String;
        final grp = key.startsWith('group:') && key.lastIndexOf(':') > 6
            ? key.substring(6, key.lastIndexOf(':'))
            : null;
        if (grp == null ? !peers.contains(key) : !groups.contains(grp)) {
          continue;
        }
        await _goneRow(t, g);
      }
    });
    await _dropGoneFiles();
  }

  /// the lists of contacts the phone held, for the engine to take as a
  /// first list (identity hex, wire base64)
  Future<List<({String identity, String wire})>> lists() async => [
    for (final r in await _db.query('history_lists', orderBy: 'identity'))
      (identity: r['identity'] as String, wire: r['wire'] as String),
  ];

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
          if (_safe(v)) _rowFiles.add(_final(v));
        }
      }
      if (r[kHistoryViaDev] == 1 && have.contains('via_dev')) m['via_dev'] = 1;
      // the keys of the files the phone keeps sealed, for when they land
      if (r['x_keys'] case final Map keys) {
        for (final e in keys.entries) {
          final name = e.key, k = e.value;
          if (name is! String || !_safe(name) || k is! String) continue;
          final Uint8List key;
          try {
            key = base64Decode(k);
          } on FormatException {
            continue;
          }
          if (key.length != 32) continue;
          await t.insert('history_keys', {
            'name': name,
            'key': key,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      m['peer_id'] ??= '';
      m['direction'] ??= 'in';
      m['plaintext'] ??= '';
      m['sent_at'] ??= 0;
      // a row that came here live under the copy's uid. the same chat,
      // sender and direction is the same message, edited or not: one row,
      // in the copy's state, counted. any other row under the uid is
      // someone else's claim: it keeps its own words and reactions under a
      // uid of its own, so no two rows share one
      int? id;
      var made = 0;
      final uid = m['msg_uid'];
      // deleted here already, live: it stays deleted, and counts as come
      if (uid is String &&
          m['direction'] == 'in' &&
          goneKept(m['group_id'] as String?) &&
          (await t.query(
            'gone_in',
            columns: ['msg_uid'],
            where: 'msg_uid = ? AND peer_id = ?',
            whereArgs: [
              uid,
              goneKey(m['peer_id'] as String, group: m['group_id'] as String?),
            ],
            limit: 1,
          )).isNotEmpty) {
        await t.rawInsert(
          'INSERT INTO history_gone (n, c) VALUES (?, 1) '
          'ON CONFLICT (n) DO UPDATE SET c = c + 1',
          [n],
        );
        continue;
      }
      if (uid is String) {
        for (final live in await t.rawQuery(
          'SELECT id, peer_id, group_id, direction, plaintext, edited, '
          'preview, media_path, file_path, file_name FROM messages '
          'WHERE msg_uid = ? AND id NOT IN (SELECT msg_id FROM history_rows)',
          [uid],
        )) {
          final same =
              id == null &&
              live['peer_id'] == m['peer_id'] &&
              live['group_id'] == m['group_id'] &&
              live['direction'] == m['direction'];
          if (same) {
            id = live['id'] as int;
            final keep = Map<String, Object?>.of(m);
            // a newer edit than the phone's, taken here live, keeps its words
            final mine = await _editAt(t, uid, m['peer_id'] as String);
            final theirs = (r['x_edit_w'] as num?)?.toInt();
            if (mine != null && (theirs == null || mine > theirs)) {
              for (final c in const ['plaintext', 'edited', 'preview']) {
                keep[c] = live[c];
              }
            } else if (theirs != null) {
              await _tookEdit(t, uid, m['peer_id'] as String, theirs);
            }
            // a file the device already holds stays its own
            if (await _hasFile(live)) {
              for (final c in const ['media_path', 'file_path', 'file_name']) {
                keep[c] = live[c];
              }
            }
            m
              ..clear()
              ..addAll(keep);
            await t.update('messages', m, where: 'id = ?', whereArgs: [id]);
            if (fts) {
              await t.delete('msg_fts', where: 'rowid = ?', whereArgs: [id]);
              final body = searchBody(m);
              if (body.trim().isNotEmpty) {
                await t.insert('msg_fts', {'rowid': id, 'body': body});
              }
            }
            continue;
          }
          final own = '$uid.${_freshUid()}';
          await t.update(
            'messages',
            {'msg_uid': own},
            where: 'id = ?',
            whereArgs: [live['id']],
          );
          // what came for it goes with it; the copy brings its own
          await t.update(
            'reactions',
            {'msg_uid': own},
            where: 'msg_uid = ?',
            whereArgs: [uid],
          );
          await t.update(
            'poll_votes',
            {'poll_uid': own},
            where: 'poll_uid = ?',
            whereArgs: [uid],
          );
        }
      }
      if (id == null) {
        made = 1;
        id = await t.insert('messages', m);
        // a late live copy of an older edit stays out, as it would here
        if ((r['x_edit_w'] as num?)?.toInt() case final w? when uid is String) {
          await _tookEdit(t, uid, m['peer_id'] as String, w);
        }
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
        // the later of two reactions by one person stays
        await t.rawInsert(
          'INSERT INTO reactions (msg_uid, reactor, emoji, reacted_at) '
          'VALUES (?, ?, ?, ?) ON CONFLICT (msg_uid, reactor) DO UPDATE SET '
          'emoji = excluded.emoji, reacted_at = excluded.reacted_at '
          'WHERE excluded.reacted_at > reactions.reacted_at',
          [uid, e['reactor'], e['emoji'], e['reacted_at'] ?? 0],
        );
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

  // the sender's time on the last edit of uid this device took live
  static Future<int?> _editAt(
    DatabaseExecutor t,
    String uid,
    String sender,
  ) async {
    final r = await t.query(
      'frame_order',
      columns: ['w'],
      where: "msg_uid = ? AND sender = ? AND kind = 'edit'",
      whereArgs: [uid, sender],
      limit: 1,
    );
    return r.isEmpty ? null : (r.first['w'] as num).toInt();
  }

  // the phone's time on the sender's last edit, kept unless a later is here
  static Future<void> _tookEdit(
    DatabaseExecutor t,
    String uid,
    String sender,
    int w,
  ) => t.rawInsert(
    "INSERT INTO frame_order (msg_uid, sender, kind, w) VALUES (?, ?, 'edit', ?) "
    'ON CONFLICT (msg_uid, sender, kind) DO UPDATE SET w = excluded.w '
    'WHERE excluded.w > frame_order.w',
    [uid, sender, w],
  );

  static Future<bool> _hasFile(Map<String, Object?> row) async {
    for (final c in const ['media_path', 'file_path']) {
      final v = row[c];
      if (v is String && v.isNotEmpty && await File(v).exists()) return true;
    }
    return false;
  }

  static String _freshUid() {
    final r = Random.secure();
    return [
      for (var i = 0; i < 8; i++)
        r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
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
    for (final r in await _db.query('history_gone')) {
      final n = r['n'] as int;
      msgs[n] = (msgs[n] ?? 0) + (r['c'] as int);
    }
    final files = <int, (int, int)>{};
    for (final f in await _db.query(
      'history_files',
      where: 'ok IN (?, ?)',
      whereArgs: [_fileWhole, _fileHere],
    )) {
      final file = File(_final(f['name'] as String));
      final size = f['size'] as int;
      if (f['ok'] == _fileWhole &&
          (!await file.exists() || !_sizeOk(await file.length(), size))) {
        continue;
      }
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
    final head = _r.head()!;
    final chats = [
      for (var n = 0; n < head.chats.length; n++)
        _chats[n] ?? const HistoryChatRef(false, ''),
    ];
    return HistoryResult(
      [for (final g in gaps) HistoryChatGap(chats[g.chat], g.want, g.got)],
      historyLeftOf(head, chats),
      head.leftChats,
      [
        for (final c in await _db.query(
          'history_chats',
          where: 'stays IS NOT NULL',
          orderBy: 'n',
        ))
          HistoryStay(chats[c['n'] as int], c['stays'] as String),
      ],
      _r.tally(got),
    );
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

  /// the contacts the copy made or filled, for their lists and listens to
  /// go before a discard takes their rows
  static Future<List<String>> madeContacts(Database db) async {
    await historyTables(db);
    return [
      for (final r in await db.query(
        'history_made',
        columns: ['a'],
        where: 't IN (?, ?)',
        whereArgs: [_madeContact, _madeFilled],
        orderBy: 'a',
      ))
        r['a'] as String,
    ];
  }

  /// what a copy left with no place held takes back too
  static Future<void> discardHeld(Database db, String mediaDir) =>
      _discard(db, mediaDir);

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
      // the rest it made, a contact's lists and proofs with it
      final dev = (await t.rawQuery(
        "SELECT 1 FROM sqlite_master WHERE name = 'dev_lists'",
      )).isNotEmpty;
      for (final r in await t.query('history_made')) {
        final a = r['a'] as String, b = r['b'] as String;
        switch (r['t']) {
          case _madeContact:
            final c = await t.query(
              'contacts',
              columns: ['ikey'],
              where: 'halo_id = ?',
              whereArgs: [a],
            );
            final ikey = c.isEmpty ? null : c.first['ikey'];
            if (dev && ikey is String) {
              for (final table in const ['dev_lists', 'dev_proven']) {
                await t.delete(
                  table,
                  where: table == 'dev_lists'
                      ? 'ident = 0 AND owner = ?'
                      : 'ident = 0 AND peer = ?',
                  whereArgs: [ikey],
                );
              }
              await t.delete(
                'dev_pq',
                where: 'ident = 0 AND peer = ?',
                whereArgs: [ikey],
              );
            }
            await t.delete('contacts', where: 'halo_id = ?', whereArgs: [a]);
          case _madeFilled:
            final was = r['was'];
            if (was is String) {
              await t.update(
                'contacts',
                _rowOf(was),
                where: 'halo_id = ?',
                whereArgs: [a],
              );
            }
          case _madeGroup:
            await t.delete('groups', where: 'group_id = ?', whereArgs: [a]);
          case _madeSupport:
            await t.delete(
              'support_chats',
              where: 'halo_id = ?',
              whereArgs: [a],
            );
          case _madeMember:
            await t.delete(
              'group_members',
              where: 'group_id = ? AND halo_id = ?',
              whereArgs: [a, b],
            );
          case _madeGone:
            await t.delete(
              'gone_in',
              where: 'msg_uid = ? AND peer_id = ?',
              whereArgs: [a, b],
            );
          case _madeProven when dev:
            await t.delete(
              'dev_proven',
              where: 'ident = 0 AND peer = ? AND key = ?',
              whereArgs: [a, b],
            );
          case _madePq when dev:
            await t.delete(
              'dev_pq',
              where: 'ident = 0 AND peer = ?',
              whereArgs: [a],
            );
        }
      }
      for (final table in _kTables) {
        await t.execute('DROP TABLE IF EXISTS $table');
      }
    });
    for (final f in files) {
      final name = f['name'] as String;
      // never written by this stream
      if (!_safe(name) || f['ok'] == _fileHere) continue;
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
