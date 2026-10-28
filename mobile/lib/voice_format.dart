// SPDX-License-Identifier: GPL-3.0-or-later
// the two shapes a voice note travels in: wav, as every version reads it,
// and opus in ogg, a tenth of the size, for phones that have said they
// play it. a note is a voice note by its name on the wire
import 'dart:io';
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
    return (lo - preskip) * 1000 ~/ 48000;
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
// beside the chat, in the container that holds it; a contact deleted takes
// its row along
Future<void> voiceOpusTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS voice_opus (
      halo_id TEXT PRIMARY KEY,
      can INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE TRIGGER IF NOT EXISTS voice_opus_follow AFTER DELETE ON '
    'contacts BEGIN DELETE FROM voice_opus WHERE halo_id = old.halo_id; END',
  );
}

Future<Database> _ready(Database db) async {
  await voiceOpusTable(db);
  return db;
}

Future<int> _canOf(Database db, String peer) async {
  final r = await db.query(
    'voice_opus',
    columns: const ['can'],
    where: 'halo_id = ?',
    whereArgs: [peer],
  );
  return r.isEmpty ? 0 : (r.first['can'] as num).toInt();
}

/// what an envelope from [peer] says of their phone. [carried]: it had the
/// word. [counts]: a message of theirs, which every phone that knows the
/// word stamps. true when it changed
Future<bool> takePeerOpus(
  Database db,
  String peer, {
  required bool carried,
  required bool counts,
  int? written,
}) async {
  await _ready(db);
  return db.transaction((t) async {
    final r = await t.query(
      'voice_opus',
      columns: const ['can'],
      where: 'halo_id = ?',
      whereArgs: [peer],
    );
    final was = r.isEmpty ? 0 : (r.first['can'] as num).toInt();
    final can = shotsCanAfter(
      was,
      carried: carried,
      counts: counts,
      written: written,
    );
    if (can == null) return false;
    await t.insert('voice_opus', {
      'halo_id': peer,
      'can': can,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  });
}

/// [peer]'s phone has said it plays opus, and has not gone back since
Future<bool> peerPlaysOpus(Database db, String peer) async =>
    await _canOf(await _ready(db), peer) > 0;

/// every one of [peers] plays opus. none known is no
Future<bool> allPlayOpus(Database db, Iterable<String> peers) async {
  if (peers.isEmpty) return false;
  await _ready(db);
  for (final p in peers) {
    if (await _canOf(db, p) <= 0) return false;
  }
  return true;
}
