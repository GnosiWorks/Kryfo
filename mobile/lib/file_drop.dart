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

import 'package:crypto/crypto.dart' show sha256;
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'typing.dart' show capsOfText, kCapDrops;

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

/// where a file is, its key, its hash, and this recipient's token: the
/// service gives the file only to a token it was given, and lets it go
/// once every token said it has it. [token] is null only on the sender's
/// own copy, before a recipient's is put in
class DropFrame {
  final String host;
  final String id;
  final String key;
  final int size;
  final int chunks;
  // the file's sha256 as the sender read it, checked once it is opened
  final String sum;
  final String? token;
  const DropFrame({
    required this.host,
    required this.id,
    required this.key,
    required this.size,
    required this.chunks,
    required this.sum,
    this.token,
  });

  Map<String, Object> toWire() => {
    'h': host,
    'i': id,
    'k': key,
    's': size,
    'c': chunks,
    'd': sum,
    't': ?token,
  };

  DropFrame withToken(String? t) => DropFrame(
    host: host,
    id: id,
    key: key,
    size: size,
    chunks: chunks,
    sum: sum,
    token: t,
  );

  /// null for anything that is not a whole, sane frame of a file this
  /// version would send. one without a token is no frame: every sender
  /// gives one, and a file nobody can say got for would wait its week
  static DropFrame? fromWire(Object? raw) => _parse(raw, token: true);

  static DropFrame? _parse(Object? raw, {required bool token}) {
    if (raw is! Map) return null;
    final h = raw['h'], i = raw['i'], k = raw['k'], s = raw['s'];
    final c = raw['c'], d = raw['d'], t = raw['t'];
    if (h is! String || !_hosts.contains(h)) return null;
    if (i is! String || !_hex32.hasMatch(i)) return null;
    if (k is! String || !_hex64.hasMatch(k)) return null;
    if (d is! String || !_hex64.hasMatch(d)) return null;
    if (s is! int || s <= 0 || s > kFreeFileBytes) return null;
    final need = (s + kDropChunk - 1) ~/ kDropChunk;
    if (c is! int || c != dropPadChunks(need)) return null;
    if (token && (t is! String || !_hex64.hasMatch(t))) return null;
    return DropFrame(
      host: h,
      id: i,
      key: k,
      size: s,
      chunks: c,
      sum: d,
      token: t is String && _hex64.hasMatch(t) ? t : null,
    );
  }

  /// what the engine fetches it with, into [path]. [blind]: the sealed
  /// bytes only, with no key to open them (hidden chats closed)
  String fetchJob(String path, {bool blind = false}) => jsonEncode({
    'host': host,
    'id': id,
    if (!blind) 'key': key,
    'size': size,
    'chunks': chunks,
    'path': path,
    'token': token ?? '',
    if (!blind) 'sum': sum,
    'blind': blind,
  });
}

/// a file up on the service: its frame without a token, and each
/// recipient's token
class DropSent {
  final DropFrame frame;
  final Map<String, String> tokens;
  // its parts went up in this send, not a file the service had whole
  // already: what the day's own count counts
  final bool sent;
  const DropSent(this.frame, this.tokens, {this.sent = true});

  /// the frame as [member] gets it
  DropFrame frameFor(String member) => frame.withToken(tokens[member]);
}

/// what the engine answered a send with. null for an error word
DropSent? dropSentOf(String r) {
  if (r.startsWith('error')) return null;
  try {
    final m = jsonDecode(r);
    if (m is! Map) return null;
    final f = DropFrame._parse({
      'h': kDropHost,
      'i': m['id'],
      'k': m['key'],
      's': m['size'],
      'c': m['chunks'],
      'd': m['sum'],
    }, token: false);
    final t = m['tokens'];
    if (f == null || t is! Map) return null;
    return DropSent(f, {
      for (final e in t.entries)
        if (e.key is String && e.value is String && _hex64.hasMatch(e.value))
          e.key as String: e.value as String,
    }, sent: m['sent'] != false);
  } catch (_) {
    return null;
  }
}

/// the job the engine sends a file with
String dropSendJob({
  required String path,
  required String uid,
  required List<String> members,
}) => jsonEncode({
  'path': path,
  'uid': uid,
  'members': members,
  'host': kDropHost,
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

/// a send that ended on the service being full or busy, which the chat
/// answers with a calm try later
bool dropTryLater(String r) =>
    const {'error: drop full', 'error: drop busy'}.contains(r);

/// a send past this phone's own day of big files
bool dropDayDone(String r) => r == 'error: drop limit';

// ---- this phone's own day of big files ----

// what one container sends through the service in a day, counted here and
// nowhere else: the service keeps no sender, so a sender's limit is the
// phone's own. it keeps a looping or a very busy app from using everyone's
// share
const kDropDayBytes = 1024 * 1024 * 1024;
const kDropDayFiles = 300;

/// the day's count as kept: `utc-day bytes files`
({String day, int bytes, int files}) dropDayOf(String? kept, DateTime now) {
  final today = now.toUtc().toIso8601String().substring(0, 10);
  final p = (kept ?? '').split(' ');
  if (p.length != 3 || p[0] != today) return (day: today, bytes: 0, files: 0);
  return (
    day: today,
    bytes: int.tryParse(p[1]) ?? 0,
    files: int.tryParse(p[2]) ?? 0,
  );
}

/// a file of [size] still fits the day
bool dropDayFits(({String day, int bytes, int files}) d, int size) =>
    d.bytes + size <= kDropDayBytes && d.files + 1 <= kDropDayFiles;

/// the day with a file of [size] in it, as kept
String dropDayAdd(({String day, int bytes, int files}) d, int size) =>
    '${d.day} ${d.bytes + size} ${d.files + 1}';

// ---- which phones fetch from the files service ----

// the name 'fb' in the phone's caps list (typing.dart), kept on the
// contacts row: a 1:1 frame's by the typing code, a group frame's by the
// group shots code (takeMemberCaps), on the member's row whether it is a
// contact or a member's card

Future<bool> _fetches(DatabaseExecutor db, String peer) async {
  final r = await db.query(
    'contacts',
    columns: const ['caps'],
    where: 'halo_id = ?',
    whereArgs: [peer],
    limit: 1,
  );
  return r.isNotEmpty &&
      capsOfText(r.first['caps'] as String?).contains(kCapDrops);
}

/// [peer]'s phone fetches from the files service, as its newest word says
Future<bool> peerTakesDrops(Database db, String peer) => _fetches(db, peer);

/// every member of [groupId] but [me] fetches from it. none known is no
Future<bool> groupTakesDrops(Database db, String groupId, String me) async {
  final r = await db.query(
    'group_members',
    columns: const ['halo_id'],
    where: 'group_id = ?',
    whereArgs: [groupId],
  );
  final others = [
    for (final m in r)
      if (m['halo_id'] != me) m['halo_id'] as String,
  ];
  if (others.isEmpty) return false;
  for (final m in others) {
    if (!await _fetches(db, m)) return false;
  }
  return true;
}

// ---- files coming in ----

// a frame whose file is still to come: the envelope as it came, kept in
// the container's own database until the file is in and filed under it.
// state: 0 to fetch, 1 fetched into path, 2 gone from the service, 3 filed
// with the got still to say
Future<void> dropFetchTable(DatabaseExecutor db) async {
  // the files a frame came for, by their id on the service, for a week:
  // one file is fetched once, however many frames name it
  await db.execute('''
    CREATE TABLE IF NOT EXISTS file_seen (
      file_id TEXT PRIMARY KEY,
      at INTEGER NOT NULL
    )
  ''');
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
// the message is filed before its file: it waits for a tap or for wi-fi,
// it is on its way, or the person paused it
const kFetchAsks = 4;
const kFetchComing = 5;
const kFetchPaused = 6;

/// its message is filed already, the file still to come
bool fetchFiledFirst(int state) => state >= kFetchAsks;

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

  DropFetch withPath(String to) => DropFetch(
    uid: uid,
    sender: sender,
    groupId: groupId,
    wire: wire,
    backPair: backPair,
    size: size,
    path: to,
    state: state,
    tries: tries,
    at: at,
  );
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

/// files on their way in a container holds at most. a frame is a few
/// hundred bytes and fetches run one at a time, so the bound is on the
/// work, and this is only a floor under a flood
const kFetchMost = 5000;

/// why a frame is not kept: null when it is
Future<String?> fetchRefused(
  Database db, {
  required String sender,
  required String fileId,
}) async {
  final seen = await db.query(
    'file_seen',
    where: 'file_id = ?',
    whereArgs: [fileId],
    limit: 1,
  );
  if (seen.isNotEmpty) return 'a file already here';
  final all = await db.query('file_fetches', columns: const ['msg_uid']);
  if (all.length >= kFetchMost) return 'too many coming';
  return null;
}

/// a file's id seen, so another frame naming it fetches nothing; a week on
/// it is forgotten
Future<void> noteSeen(Database db, String fileId, int now) async {
  await db.insert('file_seen', {
    'file_id': fileId,
    'at': now,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  await db.delete(
    'file_seen',
    where: 'at < ?',
    whereArgs: [now - kFetchKeptFor.inMilliseconds - 86400000],
  );
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
  int state = kFetchWaiting,
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
    'state': state,
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

/// the fetches whose messages are filed already
Future<List<DropFetch>> filedFetches(Database db) async {
  final r = await db.query(
    'file_fetches',
    where: 'state >= ?',
    whereArgs: [kFetchAsks],
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

/// `done total preparing` as the engine says it, or null
({int done, int total, bool preparing})? parseFileProgress(String s) {
  final p = s.split(' ');
  if (p.length < 2) return null;
  final d = int.tryParse(p[0]), t = int.tryParse(p[1]);
  if (d == null || t == null || t <= 0) return null;
  return (done: d, total: t, preparing: p.length > 2 && p[2] == '1');
}

// where a file fetched while hidden chats were closed waits, sealed: named
// by a hash of this phone's token, which the frame that opens later holds
// and the service never sees, so nothing ties the name to its record there
Future<String> heldPathIn(Directory media, String token) async {
  final dir = Directory('${media.path}/held');
  await dir.create(recursive: true);
  final name = sha256.convert(utf8.encode('kryfo-held:$token')).toString();
  return '${dir.path}/${name.substring(0, 32)}';
}

/// the held sealed bytes for [token]'s file, moved to where its fetch goes
/// on from them. false when there are none, or the fetch has its own
Future<bool> takeHeld(Directory media, String token, String fetchPath) async {
  if (await File('$fetchPath.part').exists()) return false;
  final held = File('${await heldPathIn(media, token)}.part');
  if (!await held.exists()) return false;
  try {
    await held.rename('$fetchPath.part');
    return true;
  } catch (_) {
    return false;
  }
}

/// held files past the service's week and a day: their frame never opened
Future<List<File>> staleHeldFiles(Directory media, DateTime now) async {
  final dir = Directory('${media.path}/held');
  if (!await dir.exists()) return const [];
  final out = <File>[];
  final cut = now.subtract(kFetchKeptFor + const Duration(days: 1));
  await for (final e in dir.list(followLinks: false)) {
    if (e is File && (await e.lastModified()).isBefore(cut)) out.add(e);
  }
  return out;
}

/// where a fetched file waits sealed for its message: beside the fetch
/// folder, which the engine reads and writes in the clear
String gotPathFor(String fetchPath) =>
    p.join(p.dirname(p.dirname(fetchPath)), 'got', p.basename(fetchPath));

/// true when [path] is the engine's own plain output in a fetch folder
bool inFetchFolder(String path) => p.basename(p.dirname(path)) == 'fetch';

/// the fetch and got folders' files no fetch names: a fetch dropped while
/// the app was gone. the sealed parts and the half opened copies too
Future<List<File>> strayFetchFiles(Directory media, Set<String> named) async {
  final out = <File>[];
  for (final name in const ['fetch', 'got']) {
    final dir = Directory('${media.path}/$name');
    if (!await dir.exists()) continue;
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File) continue;
      var base = e.path;
      for (final s in const ['.part', '.open']) {
        if (base.endsWith(s)) base = base.substring(0, base.length - s.length);
      }
      if (!named.contains(base)) out.add(e);
    }
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
