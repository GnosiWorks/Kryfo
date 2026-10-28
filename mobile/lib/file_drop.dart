// SPDX-License-Identifier: GPL-3.0-or-later
// files that go through our files service instead of the relay. the engine
// seals a file with a key of its own and sends it up (engine/filedrop.go);
// the message carries the key, the file's place and this recipient's token,
// and nothing else of it. the recipient fetches it, opens it, and tells the
// service it has it: once every recipient has, the file goes, a week at
// most. a phone of a version before this one gets slices, as it always has.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'voice_format.dart' show takeCanWord, canWordHeld, canWordAll;

/// the envelope's word for "this phone fetches files from the files
/// service". every envelope this version wraps carries it
const kDropsWire = 'fb';

/// the frame's field in an envelope
const kDropWire = 'bl';

/// the most a file may be when it goes through the files service. a paid
/// size would be chosen in [fileLimit], nothing else changes
const kFreeFileBytes = 50 * 1024 * 1024;

/// the most a version before the files service takes: its slices run out
/// at kMaxFileSlices
const kOldFileBytes = 15 * 1024 * 1024;

/// the most a file to these recipients may be. [drops]: every one of them
/// fetches from the files service
int fileLimit({required bool drops}) => drops ? kFreeFileBytes : kOldFileBytes;

/// the service a frame may name, by its key. never a url from the wire: a
/// sender cannot point a phone at a server of their choosing
const kDropHost = 'f1';
const _hosts = {kDropHost};

final _hex32 = RegExp(r'^[0-9a-f]{32}$');
final _hex64 = RegExp(r'^[0-9a-f]{64}$');

// the engine's sealing: 64 KiB chunks, the count rounded up (dropPadChunks)
const kDropChunk = 64 * 1024;
int dropPadChunks(int n) {
  if (n <= 16) return n;
  final e = n.bitLength - 4;
  final step = 1 << e;
  return (n + step - 1) ~/ step * step;
}

/// where a file is, its key, and this recipient's token for saying it
/// arrived. [token] is null on a frame from a sender that gave none
class DropFrame {
  final String host;
  final String id;
  final String key;
  final int size;
  final int chunks;
  final String? token;
  const DropFrame({
    required this.host,
    required this.id,
    required this.key,
    required this.size,
    required this.chunks,
    this.token,
  });

  Map<String, Object> toWire() => {
    'h': host,
    'i': id,
    'k': key,
    's': size,
    'c': chunks,
    't': ?token,
  };

  DropFrame withToken(String? t) => DropFrame(
    host: host,
    id: id,
    key: key,
    size: size,
    chunks: chunks,
    token: t,
  );

  /// null for anything that is not a whole, sane frame of a file this
  /// version would send
  static DropFrame? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final h = raw['h'], i = raw['i'], k = raw['k'], s = raw['s'];
    final c = raw['c'], t = raw['t'];
    if (h is! String || !_hosts.contains(h)) return null;
    if (i is! String || !_hex32.hasMatch(i)) return null;
    if (k is! String || !_hex64.hasMatch(k)) return null;
    if (s is! int || s <= 0 || s > kFreeFileBytes) return null;
    final need = (s + kDropChunk - 1) ~/ kDropChunk;
    if (c is! int || c != dropPadChunks(need)) return null;
    if (t != null && (t is! String || !_hex64.hasMatch(t))) return null;
    return DropFrame(
      host: h,
      id: i,
      key: k,
      size: s,
      chunks: c,
      token: t as String?,
    );
  }

  /// what the engine fetches it with, into [path]
  String fetchJob(String path) => jsonEncode({
    'host': host,
    'id': id,
    'key': key,
    'size': size,
    'chunks': chunks,
    'path': path,
  });
}

/// a file up on the service: its frame without a token, and each
/// recipient's token
class DropSent {
  final DropFrame frame;
  final Map<String, String> tokens;
  const DropSent(this.frame, this.tokens);

  /// the frame as [member] gets it
  DropFrame frameFor(String member) => frame.withToken(tokens[member]);
}

/// what the engine answered a send with. null for an error word
DropSent? dropSentOf(String r) {
  if (r.startsWith('error')) return null;
  try {
    final m = jsonDecode(r);
    if (m is! Map) return null;
    final f = DropFrame.fromWire({
      'h': kDropHost,
      'i': m['id'],
      'k': m['key'],
      's': m['size'],
      'c': m['chunks'],
    });
    final t = m['tokens'];
    if (f == null || t is! Map) return null;
    return DropSent(f, {
      for (final e in t.entries)
        if (e.key is String && e.value is String && _hex64.hasMatch(e.value))
          e.key as String: e.value as String,
    });
  } catch (_) {
    return null;
  }
}

/// the job the engine sends a file with
String dropSendJob({
  required String path,
  required String uid,
  required List<String> members,
  required String lane,
}) => jsonEncode({
  'path': path,
  'uid': uid,
  'members': members,
  'host': kDropHost,
  'lane': lane,
});

/// a file goes through the files service when it takes more than one
/// slice: one slice is a message like any other
bool dropFits(int bytes) => bytes > 12288 && bytes <= kFreeFileBytes;

/// the service refused for room or could not be reached: a file the relay
/// still takes goes as slices instead
bool dropFallsBack(String r) => const {
  'error: full',
  'error: busy',
  'error: limit',
  'error: net',
  'error: tor',
}.contains(r);

/// a send that ended on the service being full or at its limits, which
/// the chat answers with a calm try later
bool dropTryLater(String r) => const {
  'error: drop full',
  'error: drop busy',
  'error: drop limit',
}.contains(r);

// ---- which phones fetch from the files service ----

/// on a contact's row and a member's, as the opus word is kept
const kDropsCol = 'files_can';

Future<bool> takePeerDrops(
  Database db,
  String peer, {
  required bool carried,
  required bool counts,
  int? written,
}) => takeCanWord(
  db,
  'contacts',
  'halo_id = ? AND accepted = 1',
  [peer],
  col: kDropsCol,
  carried: carried,
  counts: counts,
  written: written,
);

Future<bool> takeMemberDrops(
  Database db,
  String groupId,
  String member, {
  required bool carried,
  required bool counts,
  int? written,
}) => takeCanWord(
  db,
  'group_members',
  'group_id = ? AND halo_id = ?',
  [groupId, member],
  col: kDropsCol,
  carried: carried,
  counts: counts,
  written: written,
);

Future<bool> peerTakesDrops(Database db, String peer) =>
    canWordHeld(db, peer, col: kDropsCol);

Future<bool> groupTakesDrops(Database db, String groupId, String me) =>
    canWordAll(db, groupId, me, col: kDropsCol);

// the upgrade to 88: the word beside the opus one, and the files coming in
Future<void> dropColumns(
  DatabaseExecutor db,
  Future<void> Function(DatabaseExecutor, String) addColumn,
) async {
  for (final table in const ['contacts', 'group_members']) {
    await addColumn(
      db,
      'ALTER TABLE $table ADD COLUMN $kDropsCol INTEGER NOT NULL DEFAULT 0',
    );
  }
  await dropFetchTable(db);
}

// ---- files coming in ----

// a frame whose file is still to come: the envelope as it came, kept in
// the container's own database until the file is in and filed under it.
// state: 0 to fetch, 1 fetched into path, 2 gone from the service, 3 filed
// with the got still to say
Future<void> dropFetchTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS file_fetches (
      msg_uid TEXT PRIMARY KEY,
      sender TEXT NOT NULL,
      group_id TEXT,
      wire TEXT NOT NULL,
      back_pair INTEGER NOT NULL DEFAULT 0,
      size INTEGER NOT NULL,
      path TEXT NOT NULL,
      state INTEGER NOT NULL DEFAULT 0,
      tries INTEGER NOT NULL DEFAULT 0,
      next_at INTEGER NOT NULL DEFAULT 0,
      at INTEGER NOT NULL
    )
  ''');
}

const kFetchWaiting = 0;
const kFetchHave = 1;
const kFetchGone = 2;
// filed, only the got still to say
const kFetchFiled = 3;

/// a file fetched for the service's week at most: past it, it is not there
const kFetchKeptFor = Duration(days: 7);

/// the wait before try [tries]: 30 s doubling to an hour
int fetchGap(int tries) {
  final g = 30000 << (tries < 7 ? tries : 7);
  return g < 3600000 ? g : 3600000;
}

class DropFetch {
  final String uid;
  final String sender;
  final String? groupId;
  final String wire;
  final bool backPair;
  final int size;
  final String path;
  final int state;
  final int tries;
  final int at;
  const DropFetch({
    required this.uid,
    required this.sender,
    required this.groupId,
    required this.wire,
    required this.backPair,
    required this.size,
    required this.path,
    required this.state,
    required this.tries,
    required this.at,
  });

  DropFetch.fromRow(Map<String, Object?> r)
    : uid = r['msg_uid'] as String,
      sender = r['sender'] as String,
      groupId = r['group_id'] as String?,
      wire = r['wire'] as String,
      backPair = r['back_pair'] == 1,
      size = (r['size'] as num).toInt(),
      path = r['path'] as String,
      state = (r['state'] as num).toInt(),
      tries = (r['tries'] as num).toInt(),
      at = (r['at'] as num).toInt();
}

/// the fetch for [uid], or null
Future<DropFetch?> fetchOf(Database db, String uid) async {
  final r = await db.query(
    'file_fetches',
    where: 'msg_uid = ?',
    whereArgs: [uid],
    limit: 1,
  );
  return r.isEmpty ? null : DropFetch.fromRow(r.first);
}

/// a frame kept to fetch. a second copy of the same message keeps the
/// first. true when it is new
Future<bool> noteFetch(
  Database db, {
  required String uid,
  required String sender,
  required String? groupId,
  required String wire,
  required bool backPair,
  required int size,
  required String path,
  required int now,
}) async {
  if (await fetchOf(db, uid) != null) return false;
  await db.insert('file_fetches', {
    'msg_uid': uid,
    'sender': sender,
    'group_id': groupId,
    'wire': wire,
    'back_pair': backPair ? 1 : 0,
    'size': size,
    'path': path,
    'at': now,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  return true;
}

/// files still to come from [sender], [except] the one in hand: a stranger
/// counts these toward their two
Future<int> fetchesFrom(Database db, String sender, {String? except}) async {
  final r = await db.query(
    'file_fetches',
    columns: const ['msg_uid'],
    where: 'sender = ?',
    whereArgs: [sender],
  );
  return r.where((x) => x['msg_uid'] != except).length;
}

/// what is due at [now], oldest first
Future<List<DropFetch>> dueFetches(Database db, int now) async {
  final r = await db.query(
    'file_fetches',
    where: 'next_at < ?',
    whereArgs: [now + 1],
    orderBy: 'at',
  );
  return [for (final x in r) DropFetch.fromRow(x)];
}

Future<void> fetchTried(Database db, String uid, int tries, int now) =>
    db.update(
      'file_fetches',
      {'tries': tries, 'next_at': now + fetchGap(tries)},
      where: 'msg_uid = ?',
      whereArgs: [uid],
    );

Future<void> fetchState(Database db, String uid, int state) => db.update(
  'file_fetches',
  {'state': state, 'next_at': 0},
  where: 'msg_uid = ?',
  whereArgs: [uid],
);

Future<void> dropFetchRow(Database db, String uid) =>
    db.delete('file_fetches', where: 'msg_uid = ?', whereArgs: [uid]);

/// every fetch from [sender], for a block or a take back
Future<List<DropFetch>> fetchesOf(Database db, String sender) async {
  final r = await db.query(
    'file_fetches',
    where: 'sender = ?',
    whereArgs: [sender],
  );
  return [for (final x in r) DropFetch.fromRow(x)];
}

/// where a fetch lands until it is filed: a folder of its own inside the
/// container's media, so the start sweep of files no row names never
/// takes one still coming in
Future<String> fetchPathIn(Directory media) async {
  final dir = Directory('${media.path}/fetch');
  await dir.create(recursive: true);
  final r = Random.secure();
  final leaf = [
    for (var i = 0; i < 16; i++)
      r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${dir.path}/$leaf';
}

/// the fetch folder's files no fetch names: a fetch dropped while the app
/// was gone. the sealed parts and the half opened copies too
Future<List<File>> strayFetchFiles(Directory media, Set<String> named) async {
  final dir = Directory('${media.path}/fetch');
  if (!await dir.exists()) return const [];
  final out = <File>[];
  await for (final e in dir.list(followLinks: false)) {
    if (e is! File) continue;
    var base = e.path;
    for (final s in const ['.part', '.open']) {
      if (base.endsWith(s)) base = base.substring(0, base.length - s.length);
    }
    if (!named.contains(base)) out.add(e);
  }
  return out;
}

/// a group's frame with [member]'s token where [marker] holds its place:
/// one frame is wrapped for every member, each gets its own token. no
/// token, and the frame goes without one
String withMemberToken(String wrapped, String marker, String? token) {
  final at = '"t":"$marker"';
  if (token != null && _hex64.hasMatch(token)) {
    return wrapped.replaceFirst(at, '"t":"$token"');
  }
  return wrapped.replaceFirst(',$at', '');
}
