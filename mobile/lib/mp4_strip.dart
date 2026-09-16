// SPDX-License-Identifier: GPL-3.0-or-later
// strip an mp4 of everything that is not the picture. mov and 3gp are the
// same box format and are covered by the same walk; mkv is not and is left
// alone. the location, the make and model, the encoder and the creation
// date all live in boxes beside the video, never inside it:
//
//   udta   user data. ©xyz (location), loci (3gp location), ©mak ©mod
//          ©swr ©day and whatever else the camera felt like adding
//   meta   the itunes-style key list some phones write instead
//   uuid   xmp, when present
//   mvhd, tkhd, mdhd   creation and modification stamps at fixed offsets
//
// nothing is ever deleted. deleting shifts every byte after it, and the
// chunk offset tables point at absolute positions in the file, so one
// removed box makes the video unplayable. instead a box is renamed to
// 'free', the spec's no-op, and its payload zeroed in place; a stamp is
// zeroed where it sits. sizes do not change, offsets do not move. the walk
// seeks and writes through the file, so a long clip never goes through
// memory. pure dart, no dependency, so the offline and f-droid builds stay
// as they are.
import 'dart:io';
import 'dart:typed_data';

// boxes that carry identifying data and nothing decoding needs
const _neuter = {'udta', 'meta', 'uuid'};
// full boxes with creation_time and modification_time after version+flags
const _stamped = {'mvhd', 'tkhd', 'mdhd'};
// containers worth looking inside. udta is not here: it is neutered whole
const _containers = {'moov', 'trak', 'mdia', 'minf', 'stbl', 'edts', 'dinf'};

/// the containers this walk understands. mkv is a different format and is
/// left alone rather than pretended at.
bool videoNameNeedsStrip(String name) {
  final n = name.toLowerCase();
  return n.endsWith('.mp4') ||
      n.endsWith('.m4v') ||
      n.endsWith('.mov') ||
      n.endsWith('.3gp') ||
      n.endsWith('.3g2');
}

const _free = [0x66, 0x72, 0x65, 0x65]; // 'free'
final _zeros = Uint8List(64 * 1024);

/// strips [path] in place. true when the file was walked end to end and
/// every identifying box neutered. null when a size field points past the
/// file or under its own header, which is a file we cannot vouch for: a
/// caller drops a null rather than passing on what it could not read. a
/// file that is not an mp4 at all comes back null for the same reason.
Future<bool?> stripMp4Metadata(String path) async {
  final raf = await File(path).open(mode: FileMode.append);
  try {
    final n = await _walk(raf, 0, await raf.length(), strip: true);
    return n == null ? null : true;
  } finally {
    await raf.close();
  }
}

/// how many identifying boxes or non-zero stamps [path] still carries, or
/// null when it cannot be walked, so an unreadable file never reads as
/// clean. the check a caller runs after the strip.
Future<int?> mp4MetadataCount(String path) async {
  final raf = await File(path).open();
  try {
    return await _walk(raf, 0, await raf.length(), strip: false);
  } finally {
    await raf.close();
  }
}

// walks the boxes between [start] and [end]. returns how many things it
// found (and, when stripping, neutered), or null on a size it cannot trust.
Future<int?> _walk(
  RandomAccessFile raf,
  int start,
  int end, {
  required bool strip,
}) async {
  var pos = start;
  var found = 0;
  while (pos < end) {
    if (pos + 8 > end) return null; // trailing bytes too short to be a box
    await raf.setPosition(pos);
    final head = await raf.read(8);
    if (head.length < 8) return null;
    var size = _u32(head, 0);
    final type = String.fromCharCodes(head, 4, 8);
    var header = 8;
    if (size == 1) {
      // 64-bit size follows the type
      final big = await raf.read(8);
      if (big.length < 8) return null;
      size = _u64(big, 0);
      header = 16;
    } else if (size == 0) {
      // runs to the end of the file. only meaningful at the top level
      if (start != 0) return null;
      size = end - pos;
    }
    if (size < header || pos + size > end) return null;
    final payload = pos + header;

    if (_neuter.contains(type)) {
      found++;
      if (strip) {
        await raf.setPosition(pos + 4);
        await raf.writeFrom(_free);
        await _zero(raf, payload, pos + size);
      }
    } else if (_stamped.contains(type)) {
      final n = await _stamps(raf, payload, pos + size, strip: strip);
      if (n == null) return null;
      found += n;
    } else if (_containers.contains(type)) {
      final n = await _walk(raf, payload, pos + size, strip: strip);
      if (n == null) return null;
      found += n;
    }
    pos += size;
  }
  return found;
}

// creation_time and modification_time sit right after the 4 bytes of
// version and flags: 4 bytes each in version 0, 8 each in version 1.
// returns how many were non-zero, or null when the box is too short.
Future<int?> _stamps(
  RandomAccessFile raf,
  int payload,
  int end, {
  required bool strip,
}) async {
  if (payload + 4 > end) return null;
  await raf.setPosition(payload);
  final v = (await raf.read(1))[0];
  final w = v == 1 ? 8 : 4;
  final at = payload + 4;
  if (at + 2 * w > end) return null;
  await raf.setPosition(at);
  final cur = await raf.read(2 * w);
  final dirty = cur.any((b) => b != 0) ? 1 : 0;
  if (strip && dirty == 1) {
    await raf.setPosition(at);
    await raf.writeFrom(Uint8List(2 * w));
  }
  return dirty;
}

Future<void> _zero(RandomAccessFile raf, int from, int to) async {
  await raf.setPosition(from);
  var left = to - from;
  while (left > 0) {
    final n = left < _zeros.length ? left : _zeros.length;
    await raf.writeFrom(_zeros, 0, n);
    left -= n;
  }
}

int _u32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

int _u64(Uint8List b, int i) => (_u32(b, i) << 32) | _u32(b, i + 4);
