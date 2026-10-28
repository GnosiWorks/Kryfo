// SPDX-License-Identifier: GPL-3.0-or-later
// strip an mp4 (and mov, 3gp: same box format) of everything that is not
// the picture, the sound or subtitles. location, make, model, encoder and
// dates live in boxes beside the video: udta, meta, uuid (xmp), handler
// names, and the stamps in mvhd, tkhd, mdhd. a gps or motion sensor track
// (gopro, camera motion, timecode, any data track) is a track of its own
// with samples in mdat. nothing is moved, since the chunk offset tables
// point at absolute positions: what goes is renamed 'free' and zeroed in
// place (mp4_clean.dart), every mdat byte no kept track uses is zeroed, and
// a box or samsung trailer after the last one kept is cut off. the walk
// seeks and writes, so a long clip never sits in memory.
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'meta/byte_source.dart';
import 'meta/file_source.dart';
import 'meta/iso.dart';
import 'meta/meta_reader.dart';
import 'meta/mp4_tracks.dart';
import 'meta/sef.dart';
import 'mp4_clean.dart';

/// the containers this walk understands. mkv is a different format.
bool videoNameNeedsStrip(String name) {
  final n = name.toLowerCase();
  return n.endsWith('.mp4') ||
      n.endsWith('.m4v') ||
      n.endsWith('.mov') ||
      n.endsWith('.3gp') ||
      n.endsWith('.3g2');
}

/// strips [path] in place. true when it was read end to end and cleaned,
/// null when it is not an mp4 or a size or table cannot be trusted: a
/// caller drops a null rather than pass on what it could not read.
Future<bool?> stripMp4Metadata(String path) =>
    Isolate.run(() => stripMp4Sync(path));

/// how many things the reader still finds in [path], or null when it cannot
/// be read through, so an unreadable file never reads as clean. the check a
/// caller runs after the strip.
Future<int?> mp4MetadataCount(String path) =>
    Isolate.run(() => mp4MetadataCountSync(path));

bool? stripMp4Sync(String path) {
  final raf = File(path).openSync(mode: FileMode.append);
  try {
    final s = _RafSource(raf, raf.lengthSync());
    final p = _RafPatch(raf);
    final c = [0];
    // a samsung trailer ends the file in 'SEFT', after the last box
    final sef = readSef(s);
    final end = sef?.start ?? s.length;
    final top = isoBoxes(s, 0, end, c);
    if (top.isEmpty || !kMp4Top.contains(top.first.type)) return null;
    final lay = readMp4LayoutOf(s, top, c);
    cleanMoov(s, p, lay);

    final kept = lay.keptSamples.merged;
    var cut = end;
    for (final b in top.reversed) {
      if (kMp4Top.contains(b.type)) break;
      cut = b.start;
    }
    for (final (_, b) in kept) {
      if (b > cut) return null; // a kept sample in what is about to go
    }
    for (final b in top) {
      if (b.start >= cut) break;
      if (kFreeBoxes.contains(b.type)) {
        p.zero(b.body, b.end);
      } else if (!kMp4Top.contains(b.type)) {
        if (Ranges.overlaps(kept, b.start, b.end)) return null;
        p.neuter(b);
      } else if (b.type == 'mdat' && lay.moov != null) {
        for (final (x, y) in Ranges.gaps(kept, b.body, b.end)) {
          p.zero(x, y);
        }
      }
    }
    if (cut < s.length) {
      p.zero(cut, s.length);
      raf.truncateSync(cut);
    }
    raf.flushSync();
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
  final src = FileSource.open(path);
  try {
    final r = readMetaStrict(src);
    if (r.kind != MetaKind.mp4) return null;
    return switch (r.status) {
      MetaStatus.nothing => 0,
      MetaStatus.found => _count(r),
      _ => null,
    };
  } catch (_) {
    return null;
  } finally {
    src.close();
  }
}

int _count(MetaReport r) {
  var n = r.videoTags.length + r.extra.length + r.extraTracks;
  for (final b in [
    r.gps != null,
    r.make != null || r.model != null || r.software != null,
    r.created != null || r.taken != null,
    r.stamps,
    r.credentials,
    r.timecode,
    r.gpsPoints > 0,
    r.handlerNames,
    r.leftoverBytes > 0,
    r.liveId != null,
    r.networkCountry != null,
  ]) {
    if (b) n++;
  }
  return n == 0 ? 1 : n;
}

const _free = [0x66, 0x72, 0x65, 0x65]; // 'free'
final _zeros = Uint8List(64 * 1024);

class _RafPatch implements Mp4Patch {
  final RandomAccessFile raf;
  _RafPatch(this.raf);

  @override
  void neuter(IsoBox b) {
    raf.setPositionSync(b.start + 4);
    raf.writeFromSync(_free);
    zero(b.body, b.end);
  }

  @override
  void zero(int from, int to) {
    raf.setPositionSync(from);
    var left = to - from;
    while (left > 0) {
      final n = left < _zeros.length ? left : _zeros.length;
      raf.writeFromSync(_zeros, 0, n);
      left -= n;
    }
  }
}

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
