// SPDX-License-Identifier: GPL-3.0-or-later
// the two shapes a voice note travels in: wav, as every version reads it,
// and opus in ogg, a tenth of the size, for phones that have said they
// play it. a note is a voice note by its name on the wire
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'chat_shots.dart' show shotsCanAfter;

const kVoiceWav = 'voice.wav';
const kVoiceOgg = 'voice.ogg';

/// a voice note's name, in either shape
bool isVoiceName(String? name) => name == kVoiceWav || name == kVoiceOgg;

/// the envelope's word for "this phone plays opus voice notes". every
/// envelope this version wraps carries it
const kOpusWire = 'op';

/// where a note placed as wav at [wav] is kept once it is opus
String oggPathOf(String wav) => wav.toLowerCase().endsWith('.wav')
    ? '${wav.substring(0, wav.length - 4)}.ogg'
    : '$wav.ogg';

/// the longest an ogg note is shown as: the mic's 30 minutes and a little
/// over, as the engine reads at most
const kOggLongestMs = 31 * 60 * 1000;

bool isOggPath(String path) => path.toLowerCase().endsWith('.ogg');

/// how long an ogg opus stream plays, from its first page and its last:
/// the last granule less the pre-skip, at 48 khz. null for anything else
int? oggOpusMs(Uint8List head, Uint8List tail) {
  // the first page holds OpusHead alone
  if (head.length < 47 || String.fromCharCodes(head.sublist(0, 4)) != 'OggS') {
    return null;
  }
  final h = ByteData.sublistView(head);
  final segs = head[26];
  final body = 27 + segs;
  if (head.length < body + 19 ||
      String.fromCharCodes(head.sublist(body, body + 8)) != 'OpusHead') {
    return null;
  }
  final preskip = h.getUint16(body + 10, Endian.little);
  final t = ByteData.sublistView(tail);
  // the last page that is whole in [tail]
  for (var at = tail.length - 27; at >= 0; at--) {
    if (tail[at] != 0x4F ||
        tail[at + 1] != 0x67 ||
        tail[at + 2] != 0x67 ||
        tail[at + 3] != 0x53 ||
        tail[at + 4] != 0) {
      continue;
    }
    final n = tail[at + 26];
    if (at + 27 + n > tail.length) continue;
    var size = 0;
    for (var i = 0; i < n; i++) {
      size += tail[at + 27 + i];
    }
    if (at + 27 + n + size != tail.length) continue;
    final lo = t.getUint32(at + 6, Endian.little);
    final hi = t.getUint32(at + 10, Endian.little);
    if (hi != 0) return null;
    if (lo < preskip) return null;
    // no note is longer than the mic records, whatever its last page says
    return math.min((lo - preskip) * 1000 ~/ 48000, kOggLongestMs);
  }
  return null;
}

/// [oggOpusMs] of a file, read from its first and last few kilobytes
Future<int?> oggFileMs(String path) async {
  RandomAccessFile? f;
  try {
    f = await File(path).open();
    final size = await f.length();
    final head = await f.read(4096);
    final from = size > 65536 ? size - 65536 : 0;
    await f.setPosition(from);
    final tail = await f.read(size - from);
    return oggOpusMs(head, tail);
  } catch (_) {
    return null;
  } finally {
    await f?.close();
  }
}

// ---- which phones play opus ----

// a peer's newest word on it, as the screenshot block keeps its own
// (shotsCanAfter): when their newest envelope was written, positive when
// it carried the word, negative when a message of theirs came without it.
// on their contact row for a 1:1 chat, on their member row for a group or
// a room, so it moves, ends and goes with the chat (opusColumns)
const kOpusCol = 'opus_can';

/// a phone's word in column [col] of the row [where] picks, moved on by
/// one envelope (shotsCanAfter). the opus word, and the files word
/// (file_drop.dart) beside it
Future<bool> takeCanWord(
  Database db,
  String table,
  String where,
  List<Object?> args, {
  String col = kOpusCol,
  required bool carried,
  required bool counts,
  int? written,
}) => db.transaction((t) async {
  final r = await t.query(
    table,
    columns: [col],
    where: where,
    whereArgs: args,
    limit: 1,
  );
  // only a row that is there already: nothing is made for anyone
  if (r.isEmpty) return false;
  final was = (r.first[col] as num?)?.toInt() ?? 0;
  final can = shotsCanAfter(
    was,
    carried: carried,
    counts: counts,
    written: written,
  );
  if (can == null) return false;
  await t.update(table, {col: can}, where: where, whereArgs: args);
  return true;
});

/// what a 1:1 envelope from [peer] says of their phone, kept only on the
/// row of a contact who was accepted. [carried]: it had the word.
/// [counts]: a message of theirs, which every phone that knows the word
/// stamps. true when it changed
Future<bool> takePeerOpus(
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
  carried: carried,
  counts: counts,
  written: written,
);

/// as [takePeerOpus], for a member of group or room [groupId], kept only
/// on a member row that is there
Future<bool> takeMemberOpus(
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
  carried: carried,
  counts: counts,
  written: written,
);

/// [peer]'s phone has said it plays opus, and has not gone back since
Future<bool> peerPlaysOpus(Database db, String peer) => canWordHeld(db, peer);

/// every member of [groupId] but [me] plays opus. none known is no
Future<bool> groupPlaysOpus(Database db, String groupId, String me) =>
    canWordAll(db, groupId, me);

/// [peer]'s phone has said the word in [col], and has not gone back since
Future<bool> canWordHeld(
  Database db,
  String peer, {
  String col = kOpusCol,
}) async {
  final r = await db.query(
    'contacts',
    columns: [col],
    where: 'halo_id = ?',
    whereArgs: [peer],
    limit: 1,
  );
  return r.isNotEmpty && ((r.first[col] as num?)?.toInt() ?? 0) > 0;
}

/// every member of [groupId] but [me] has said the word in [col]. none
/// known is no
Future<bool> canWordAll(
  Database db,
  String groupId,
  String me, {
  String col = kOpusCol,
}) async {
  final r = await db.query(
    'group_members',
    columns: ['halo_id', col],
    where: 'group_id = ?',
    whereArgs: [groupId],
  );
  final others = [
    for (final m in r)
      if (m['halo_id'] != me) m,
  ];
  return others.isNotEmpty &&
      others.every((m) => ((m[col] as num?)?.toInt() ?? 0) > 0);
}
