// SPDX-License-Identifier: GPL-3.0-or-later
// strip an mp4 (and mov, 3gp: same box format) of everything that is not
// the picture, the sound or subtitles. location, make, model, encoder and
// dates live in boxes beside the video: udta, meta, uuid (xmp), and the
// stamps in mvhd, tkhd, mdhd. a gps or motion sensor track (gopro, camera
// motion, timecode, any data track) is a track of its own with samples in
// mdat. nothing is deleted, since the chunk offset tables point at absolute
// positions: a box is renamed 'free' and zeroed in place, a stamp is zeroed
// where it sits, and every mdat byte no kept track uses is zeroed. the walk
// seeks and writes, so a long clip never sits in memory.
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'meta/byte_source.dart';
import 'meta/iso.dart';
import 'meta/mp4_tracks.dart';

// boxes that carry identifying data and nothing decoding needs
const _neuter = {'udta', 'meta', 'uuid'};
// full boxes with creation_time and modification_time after version+flags
const _stamped = {'mvhd', 'tkhd', 'mdhd'};
// containers worth looking inside. udta is not here: it is neutered whole
const _containers = {'moov', 'trak', 'mdia', 'minf', 'stbl', 'edts', 'dinf'};

/// the containers this walk understands. mkv is a different format.
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

/// strips [path] in place. true when every identifying box, data track and
/// unused mdat byte was neutered, null when it is not an mp4 or a size or
/// table cannot be trusted: a caller drops a null rather than pass on what
/// it could not read.
Future<bool?> stripMp4Metadata(String path) =>
    Isolate.run(() => stripMp4Sync(path));

/// how many identifying boxes, non-zero stamps, data tracks and used
/// stretches of unused mdat [path] still carries, or null when it cannot be
/// walked, so an unreadable file never reads as clean. the check a caller
/// runs after the strip.
Future<int?> mp4MetadataCount(String path) =>
    Isolate.run(() => mp4MetadataCountSync(path));

bool? stripMp4Sync(String path) {
  final raf = File(path).openSync(mode: FileMode.append);
  try {
    final src = _RafSource(raf, raf.lengthSync());
    final lay = readMp4Layout(src);
    _dropTracks(raf, src, lay);
    final n = _walk(raf, 0, src.length, strip: true);
    if (n == null) return null;
    for (final (a, b) in _unused(lay)) {
      _zero(raf, a, b);
    }
    return true;
  } on IsoError {
    return null;
  } on RangeError {
    return null;
  } finally {
    raf.closeSync();
  }
}

int? mp4MetadataCountSync(String path) {
  final raf = File(path).openSync();
  try {
    final src = _RafSource(raf, raf.lengthSync());
    final lay = readMp4Layout(src);
    final n = _walk(raf, 0, src.length, strip: false);
    if (n == null) return null;
    var found = n + lay.tracks.where((t) => !t.kept).length;
    for (final (a, b) in _unused(lay)) {
      if (nonZero(src, a, b - a)) found++;
    }
    return found;
  } on IsoError {
    return null;
  } on RangeError {
    return null;
  } finally {
    raf.closeSync();
  }
}

// the stretches of mdat no kept track's samples use. without a moov no
// player reads mdat as a video, so there is nothing to tell apart
List<(int, int)> _unused(Mp4Layout lay) {
  if (lay.moov == null) return const [];
  final kept = lay.keptSamples.merged;
  return [for (final m in lay.mdats) ...Ranges.gaps(kept, m.body, m.end)];
}

// a dropped track goes whole: its trak, its fragments and its defaults, and
// any reference a kept track holds only to dropped ones
void _dropTracks(RandomAccessFile raf, ByteSource s, Mp4Layout lay) {
  final gone = {
    for (final t in lay.tracks)
      if (!t.kept) t.id,
  };
  if (gone.isEmpty) return;
  final c = [0];
  for (final t in lay.tracks) {
    if (!t.kept) {
      _neuterBox(raf, t.trak);
    } else if (t.tref != null) {
      for (final r in isoBoxes(s, t.tref!.body, t.tref!.end, c)) {
        final ids = s.read(r.body, r.bodySize);
        var others = false;
        for (var i = 0; i + 4 <= ids.length; i += 4) {
          if (!gone.contains(be32(ids, i))) others = true;
        }
        if (!others) _neuterBox(raf, r);
      }
    }
  }
  // the track id sits right after version and flags in each of these
  void byId(IsoBox parent, String type) {
    for (final b in isoBoxes(s, parent.body, parent.end, c)) {
      if (b.type != type || b.bodySize < 8) continue;
      if (gone.contains(be32(s.read(b.body + 4, 4), 0))) _neuterBox(raf, b);
    }
  }

  final mvex = firstOf(lay.moovKids, 'mvex');
  if (mvex != null) byId(mvex, 'trex');
  for (final b in lay.top) {
    if (b.type == 'mfra') byId(b, 'tfra');
    if (b.type != 'moof') continue;
    for (final traf in isoBoxes(s, b.body, b.end, c)) {
      if (traf.type != 'traf') continue;
      final tfhd = firstOf(isoBoxes(s, traf.body, traf.end, c), 'tfhd');
      if (tfhd == null || tfhd.bodySize < 8) continue;
      if (gone.contains(be32(s.read(tfhd.body + 4, 4), 0))) {
        _neuterBox(raf, traf);
      }
    }
  }
}

void _neuterBox(RandomAccessFile raf, IsoBox b) {
  raf.setPositionSync(b.start + 4);
  raf.writeFromSync(_free);
  _zero(raf, b.body, b.end);
}

// walks the boxes between [start] and [end]. returns how many things it
// found (and, when stripping, neutered), or null on a size it cannot trust.
int? _walk(RandomAccessFile raf, int start, int end, {required bool strip}) {
  var pos = start;
  var found = 0;
  while (pos < end) {
    if (pos + 8 > end) return null; // trailing bytes too short to be a box
    raf.setPositionSync(pos);
    final head = raf.readSync(8);
    if (head.length < 8) return null;
    var size = _u32(head, 0);
    final type = String.fromCharCodes(head, 4, 8);
    var header = 8;
    if (size == 1) {
      // 64-bit size follows the type
      final big = raf.readSync(8);
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
        raf.setPositionSync(pos + 4);
        raf.writeFromSync(_free);
        _zero(raf, payload, pos + size);
      }
    } else if (_stamped.contains(type)) {
      final n = _stamps(raf, payload, pos + size, strip: strip);
      if (n == null) return null;
      found += n;
    } else if (_containers.contains(type)) {
      final n = _walk(raf, payload, pos + size, strip: strip);
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
int? _stamps(
  RandomAccessFile raf,
  int payload,
  int end, {
  required bool strip,
}) {
  if (payload + 4 > end) return null;
  raf.setPositionSync(payload);
  final v = raf.readSync(1)[0];
  final w = v == 1 ? 8 : 4;
  final at = payload + 4;
  if (at + 2 * w > end) return null;
  raf.setPositionSync(at);
  final cur = raf.readSync(2 * w);
  final dirty = cur.any((b) => b != 0) ? 1 : 0;
  if (strip && dirty == 1) {
    raf.setPositionSync(at);
    raf.writeFromSync(Uint8List(2 * w));
  }
  return dirty;
}

void _zero(RandomAccessFile raf, int from, int to) {
  raf.setPositionSync(from);
  var left = to - from;
  while (left > 0) {
    final n = left < _zeros.length ? left : _zeros.length;
    raf.writeFromSync(_zeros, 0, n);
    left -= n;
  }
}

int _u32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

int _u64(Uint8List b, int i) => (_u32(b, i) << 32) | _u32(b, i + 4);

class _RafSource implements ByteSource {
  final RandomAccessFile _raf;
  @override
  final int length;
  _RafSource(this._raf, this.length);

  @override
  Uint8List read(int offset, int count) {
    if (offset < 0 || count < 0 || offset + count > length) {
      throw RangeError('read $count at $offset of $length');
    }
    _raf.setPositionSync(offset);
    final b = _raf.readSync(count);
    if (b.length != count) throw RangeError('short read at $offset');
    return b;
  }
}
