// SPDX-License-Identifier: GPL-3.0-or-later
// what cleaning an mp4 or mov means, box by box, for the video cleaner and
// for the animation inside a heif. keep-lists at every level: the boxes a
// player needs stay, everything else is renamed 'free' and zeroed in place,
// so no offset changes. tracks that are not picture, sound or subtitles go
// whole (gps, motion sensors, timecode, any data track), handler and
// compressor names are blanked, stamps zeroed, free space zeroed. the caller zeroes the mdat
// bytes no kept track uses.
import 'meta/byte_source.dart';
import 'meta/iso.dart';
import 'meta/mp4_tracks.dart';

/// the writes a clean makes, to a file or to bytes in memory
abstract class Mp4Patch {
  /// renames the box at [b] to 'free' and zeroes its payload
  void neuter(IsoBox b);

  void zero(int from, int to);
}

// full boxes with creation_time and modification_time after version+flags
const _stamped = {'mvhd', 'tkhd', 'mdhd'};

/// cleans the moov of [lay], and the fragments beside it
void cleanMoov(ByteSource s, Mp4Patch p, Mp4Layout lay) {
  final moov = lay.moov;
  if (moov == null) return;
  final c = [0];
  final gone = {
    for (final t in lay.tracks)
      if (!t.kept) t.id,
  };
  final byBox = {for (final t in lay.tracks) t.trak.start: t};
  for (final b in lay.moovKids) {
    switch (b.type) {
      case 'mvhd':
        _stamps(s, p, b);
      case 'trak':
        final t = byBox[b.start];
        if (t == null || !t.kept) {
          p.neuter(b);
        } else {
          _trak(s, p, t, gone, c);
          for (final (a, z) in compressorNames(s, t, c)) {
            p.zero(a, z);
          }
        }
      case 'mvex':
        for (final k in isoBoxes(s, b.body, b.end, c)) {
          if (k.type == 'trex' && _idIn(s, k, gone)) p.neuter(k);
        }
      case 'iods':
        break;
      default:
        _drop(p, b);
    }
  }
  for (final b in lay.top) {
    if (b.type == 'moof') _moof(s, p, b, gone, c);
    if (b.type == 'mfra') {
      for (final k in isoBoxes(s, b.body, b.end, c)) {
        if (k.type == 'tfra' && _idIn(s, k, gone)) p.neuter(k);
      }
    }
  }
}

// free space is zeroed and keeps its name; anything else not kept goes
void _drop(Mp4Patch p, IsoBox b) {
  if (kFreeBoxes.contains(b.type)) {
    p.zero(b.body, b.end);
  } else {
    p.neuter(b);
  }
}

// the track id sits right after version and flags
bool _idIn(ByteSource s, IsoBox b, Set<int> ids) =>
    b.bodySize >= 8 && ids.contains(be32(s.read(b.body + 4, 4), 0));

void _trak(ByteSource s, Mp4Patch p, Mp4Track t, Set<int> gone, List<int> c) {
  for (final b in isoBoxes(s, t.trak.body, t.trak.end, c)) {
    if (!kTrakKeep.contains(b.type)) {
      _drop(p, b);
    } else if (b.type == 'tkhd') {
      _stamps(s, p, b);
    } else if (b.type == 'tref') {
      // a reference held only to dropped tracks goes with them
      for (final r in isoBoxes(s, b.body, b.end, c)) {
        final ids = s.read(r.body, r.bodySize);
        var others = false;
        for (var i = 0; i + 4 <= ids.length; i += 4) {
          if (!gone.contains(be32(ids, i))) others = true;
        }
        if (!others) p.neuter(r);
      }
    } else if (b.type == 'mdia') {
      _within(s, p, b, kMdiaKeep, c);
    }
  }
}

// the media box and its media information box, by their keep-lists
void _within(
  ByteSource s,
  Mp4Patch p,
  IsoBox box,
  Set<String> keep,
  List<int> c,
) {
  for (final b in isoBoxes(s, box.body, box.end, c)) {
    if (!keep.contains(b.type)) {
      _drop(p, b);
    } else if (_stamped.contains(b.type)) {
      _stamps(s, p, b);
    } else if (b.type == 'hdlr') {
      blankHandlerName(p, b);
    } else if (b.type == 'minf') {
      _within(s, p, b, kMinfKeep, c);
    }
  }
}

/// a handler's name, and the vendor fields quicktime puts before it, zeroed.
/// an empty name is still a valid one
void blankHandlerName(Mp4Patch p, IsoBox h) {
  if (h.bodySize > 12) p.zero(h.body + 12, h.end);
}

void _moof(ByteSource s, Mp4Patch p, IsoBox moof, Set<int> gone, List<int> c) {
  for (final b in isoBoxes(s, moof.body, moof.end, c)) {
    if (!kMoofKeep.contains(b.type)) {
      _drop(p, b);
    } else if (b.type == 'traf') {
      final kids = isoBoxes(s, b.body, b.end, c);
      final tfhd = firstOf(kids, 'tfhd');
      if (tfhd != null && _idIn(s, tfhd, gone)) {
        p.neuter(b);
        continue;
      }
      for (final k in kids) {
        if (!kTrafKeep.contains(k.type)) _drop(p, k);
      }
    }
  }
}

// creation_time and modification_time sit right after the 4 bytes of
// version and flags: 4 bytes each in version 0, 8 each in version 1
void _stamps(ByteSource s, Mp4Patch p, IsoBox b) {
  if (b.bodySize < 4) throw const IsoError('short header box');
  final w = s.read(b.body, 1)[0] == 1 ? 8 : 4;
  if (b.bodySize < 4 + 2 * w) throw const IsoError('short header box');
  p.zero(b.body + 4, b.body + 4 + 2 * w);
}
