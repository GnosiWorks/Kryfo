// SPDX-License-Identifier: GPL-3.0-or-later
// the tracks of an mp4 or mov and the bytes each one's samples take up in
// the file, from the sample tables (and the track fragments of a fragmented
// file). the reader names tracks by what they hold; the cleaner keeps the
// picture, sound and subtitle tracks and zeroes every other byte of mdat.
import 'dart:convert';
import 'dart:typed_data';

import 'byte_source.dart';
import 'iso.dart';

/// top level boxes a playable file is made of; anything else is cut
const kMp4Top = {
  'ftyp',
  'moov',
  'mdat',
  'free',
  'skip',
  'wide',
  'moof',
  'mfra',
  'sidx',
  'styp',
};

/// free space: old bytes can sit in it, so it is zeroed
const kFreeBoxes = {'free', 'skip', 'wide'};

const kMoovKeep = {'mvhd', 'trak', 'mvex', 'iods'};
const kTrakKeep = {'tkhd', 'edts', 'mdia', 'tref', 'tapt'};
const kMdiaKeep = {'mdhd', 'hdlr', 'minf', 'elng'};
const kMinfKeep = {
  'vmhd',
  'smhd',
  'nmhd',
  'gmhd',
  'hmhd',
  'sthd',
  'dinf',
  'stbl',
  'hdlr',
};
const kMoofKeep = {'mfhd', 'traf', 'pssh'};
const kTrafKeep = {
  'tfhd',
  'tfdt',
  'trun',
  'sbgp',
  'sgpd',
  'saiz',
  'saio',
  'senc',
  'subs',
};

enum TrackRole { picture, sound, subtitle, timecode, data }

class Mp4Track {
  final IsoBox trak;
  int id = 0;
  String handler = '';
  String format = '';
  String? aux;
  int sampleCount = 0;
  final Ranges samples = Ranges();

  /// where each chunk of the sample table starts
  final List<int> chunks = [];

  /// one size for every sample. quicktime sound counts such sizes in
  /// frames, not bytes, so these chunks are taken to run to the next one
  bool constantSize = false;
  final List<IsoBox> hdlrs = [];
  IsoBox? tkhd;
  IsoBox? mdhd;
  IsoBox? tref;
  IsoBox? stsd;
  Mp4Track(this.trak);

  TrackRole get role => trackRole(handler, aux);
  bool get kept => role != TrackRole.timecode && role != TrackRole.data;
}

const _alpha = {
  'urn:mpeg:mpegB:cicp:systems:auxiliary:alpha',
  'urn:mpeg:hevc:2015:auxid:1',
};

TrackRole trackRole(String handler, String? aux) => switch (handler) {
  'vide' || 'pict' => TrackRole.picture,
  // an auxiliary picture track: alpha is part of the picture, a depth
  // track is not
  'auxv' =>
    aux != null && _alpha.contains(aux) ? TrackRole.picture : TrackRole.data,
  'soun' => TrackRole.sound,
  'text' || 'sbtl' || 'subt' || 'clcp' => TrackRole.subtitle,
  'tmcd' => TrackRole.timecode,
  _ => TrackRole.data,
};

class Mp4Layout {
  final List<IsoBox> top;
  final IsoBox? moov;
  final List<IsoBox> moovKids;
  final List<Mp4Track> tracks;
  final bool fragmented;
  const Mp4Layout(
    this.top,
    this.moov,
    this.moovKids,
    this.tracks,
    this.fragmented,
  );

  Iterable<IsoBox> get mdats => top.where((b) => b.type == 'mdat');

  /// every byte a kept track's samples use
  Ranges get keptSamples {
    final r = Ranges();
    for (final t in tracks) {
      if (t.kept) r.addAll(t.samples);
    }
    return r;
  }
}

/// the layout of the whole file. throws IsoError on a size it cannot trust
Mp4Layout readMp4Layout(ByteSource s, {List<int>? count}) {
  final c = count ?? [0];
  final top = isoBoxes(s, 0, s.length, c);
  return readMp4LayoutOf(s, top, c);
}

Mp4Layout readMp4LayoutOf(ByteSource s, List<IsoBox> top, List<int> c) {
  final moov = firstOf(top, 'moov');
  if (moov == null) return Mp4Layout(top, null, const [], const [], false);
  final kids = isoBoxes(s, moov.body, moov.end, c);
  final tracks = <Mp4Track>[];
  for (final t in kids.where((b) => b.type == 'trak')) {
    tracks.add(_track(s, t, c));
  }
  final mvex = firstOf(kids, 'mvex');
  final fragmented =
      mvex != null || top.any((b) => b.type == 'moof' || b.type == 'mfra');
  if (fragmented) _fragments(s, top, mvex, tracks, c);
  _openEnded(top, tracks);
  for (final t in tracks) {
    for (final (a, b) in t.samples.merged) {
      if (a < 0 || b > s.length) throw const IsoError('sample past the file');
    }
  }
  return Mp4Layout(top, moov, kids, tracks, fragmented);
}

Mp4Track _track(ByteSource s, IsoBox trak, List<int> c) {
  final t = Mp4Track(trak);
  final kids = isoBoxes(s, trak.body, trak.end, c);
  t.tkhd = firstOf(kids, 'tkhd');
  t.tref = firstOf(kids, 'tref');
  if (t.tkhd != null) {
    final p = s.read(t.tkhd!.body, t.tkhd!.bodySize.clamp(0, 24));
    if (p.length >= 4) {
      final at = p[0] == 1 ? 20 : 12;
      if (p.length >= at + 4) t.id = be32(p, at);
    }
  }
  final mdia = firstOf(kids, 'mdia');
  if (mdia == null) return t;
  final mk = isoBoxes(s, mdia.body, mdia.end, c);
  t.mdhd = firstOf(mk, 'mdhd');
  final hdlr = firstOf(mk, 'hdlr');
  if (hdlr != null) {
    t.hdlrs.add(hdlr);
    if (hdlr.bodySize >= 12) t.handler = fourcc(s.read(hdlr.body + 8, 4), 0);
  }
  final minf = firstOf(mk, 'minf');
  if (minf == null) return t;
  final nk = isoBoxes(s, minf.body, minf.end, c);
  for (final h in nk.where((b) => b.type == 'hdlr')) {
    t.hdlrs.add(h);
  }
  final dinf = firstOf(nk, 'dinf');
  if (dinf != null) _selfContained(s, dinf, c);
  final stbl = firstOf(nk, 'stbl');
  if (stbl == null) return t;
  _samples(s, t, isoBoxes(s, stbl.body, stbl.end, c));
  return t;
}

// data kept in another file names that file; not something to pass on
void _selfContained(ByteSource s, IsoBox dinf, List<int> c) {
  final dref = firstOf(isoBoxes(s, dinf.body, dinf.end, c), 'dref');
  if (dref == null || dref.bodySize < 8) return;
  for (final e in isoBoxes(s, dref.body + 8, dref.end, c)) {
    if (e.bodySize < 4) throw const IsoError('short data reference');
    final flags = s.read(e.body, 4);
    if (flags[3] & 1 == 0) throw const IsoError('data in another file');
  }
}

void _samples(ByteSource s, Mp4Track t, List<IsoBox> stbl) {
  final stsd = firstOf(stbl, 'stsd');
  t.stsd = stsd;
  if (stsd != null && stsd.bodySize >= 16) {
    final head = s.read(stsd.body, 16);
    t.format = fourcc(head, 12);
    final entry = s.read(stsd.body + 8, (stsd.bodySize - 8).clamp(0, 4096));
    t.aux = _auxUrn(entry);
  }
  final stsz = firstOf(stbl, 'stsz');
  final stz2 = firstOf(stbl, 'stz2');
  final stsc = firstOf(stbl, 'stsc');
  final stco = firstOf(stbl, 'stco') ?? firstOf(stbl, 'co64');
  if (stco == null && stsc == null && stsz == null && stz2 == null) return;
  if (stco == null || stsc == null || (stsz == null && stz2 == null)) {
    throw const IsoError('sample table missing a part');
  }
  final sizes = _sizes(s, stsz ?? stz2!);
  t.sampleCount = sizes.count;
  t.constantSize = sizes.table == null && sizes.count > 0;

  final sc = isoPayload(s, stsc);
  if (sc.length < 8) throw const IsoError('short stsc');
  final runs = be32(sc, 4);
  if (8 + runs * 12 > sc.length) throw const IsoError('short stsc');

  final co = isoPayload(s, stco, max: 64 << 20);
  if (co.length < 8) throw const IsoError('short chunk table');
  final chunks = be32(co, 4);
  final wide = stco.type == 'co64';
  if (8 + chunks * (wide ? 8 : 4) > co.length) {
    throw const IsoError('short chunk table');
  }
  int chunkAt(int k) => wide ? be64(co, 8 + k * 8) : be32(co, 8 + k * 4);

  var sample = 0;
  for (var r = 0; r < runs; r++) {
    final first = be32(sc, 8 + r * 12);
    final per = be32(sc, 12 + r * 12);
    final last = r + 1 < runs ? be32(sc, 8 + (r + 1) * 12) - 1 : chunks;
    if (first < 1 || last > chunks || per > sizes.count) {
      throw const IsoError('sample to chunk table out of range');
    }
    for (var k = first; k <= last; k++) {
      if (sample >= sizes.count) break;
      final at = chunkAt(k - 1);
      t.chunks.add(at);
      var len = 0;
      for (var n = 0; n < per && sample < sizes.count; n++) {
        len += sizes.at(sample++);
      }
      t.samples.add(at, at + len);
    }
  }
}

// a constant size track's chunks end where the next chunk of any track
// starts, or where their box ends. never shorter than the table says
void _openEnded(List<IsoBox> top, List<Mp4Track> tracks) {
  if (!tracks.any((t) => t.constantSize && t.kept)) return;
  final starts = <int>{for (final t in tracks) ...t.chunks}.toList()..sort();
  for (final t in tracks.where((t) => t.constantSize && t.kept)) {
    for (final at in t.chunks) {
      var to = _boxEnd(top, at);
      var lo = 0, hi = starts.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (starts[mid] <= at) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      if (lo < starts.length && starts[lo] < to) to = starts[lo];
      t.samples.add(at, to);
    }
  }
}

int _boxEnd(List<IsoBox> top, int at) {
  for (final b in top) {
    if (at >= b.start && at < b.end) return b.end;
  }
  return at;
}

class _Sizes {
  final int count;
  final int fixed;
  final Uint8List? table;
  final int bits;
  const _Sizes(this.count, this.fixed, this.table, this.bits);
  int at(int i) {
    if (table == null) return fixed;
    switch (bits) {
      case 32:
        return be32(table!, i * 4);
      case 16:
        return be16(table!, i * 2);
      case 8:
        return table![i];
      default:
        final b = table![i >> 1];
        return i & 1 == 0 ? b >> 4 : b & 15;
    }
  }
}

_Sizes _sizes(ByteSource s, IsoBox b) {
  if (b.bodySize < 12) throw const IsoError('short sample sizes');
  final head = s.read(b.body, 12);
  final count = be32(head, 8);
  if (b.type == 'stsz') {
    final fixed = be32(head, 4);
    if (fixed != 0) return _Sizes(count, fixed, null, 32);
    if (12 + count * 4 > b.bodySize) throw const IsoError('short sample sizes');
    return _Sizes(count, 0, s.read(b.body + 12, count * 4), 32);
  }
  final bits = head[7];
  if (bits != 4 && bits != 8 && bits != 16) {
    throw const IsoError('odd sample size width');
  }
  final n = (count * bits + 7) >> 3;
  if (12 + n > b.bodySize) throw const IsoError('short sample sizes');
  return _Sizes(count, 0, s.read(b.body + 12, n), bits);
}

// the urn in an auxi box inside a sample entry, if there is one
String? _auxUrn(Uint8List entry) {
  for (var i = 4; i + 8 <= entry.length; i++) {
    if (entry[i] == 0x61 &&
        entry[i + 1] == 0x75 &&
        entry[i + 2] == 0x78 &&
        entry[i + 3] == 0x69) {
      final from = i + 8; // past the type and version and flags
      var to = from;
      while (to < entry.length && entry[to] != 0) {
        to++;
      }
      if (to <= from) return null;
      return latin1.decode(entry.sublist(from, to), allowInvalid: true);
    }
  }
  return null;
}

class _Trex {
  int size = 0;
}

void _fragments(
  ByteSource s,
  List<IsoBox> top,
  IsoBox? mvex,
  List<Mp4Track> tracks,
  List<int> c,
) {
  final trex = <int, _Trex>{};
  if (mvex != null) {
    for (final b in isoBoxes(s, mvex.body, mvex.end, c)) {
      if (b.type != 'trex' || b.bodySize < 24) continue;
      final p = s.read(b.body, 24);
      trex[be32(p, 4)] = _Trex()..size = be32(p, 16);
    }
  }
  final byId = {for (final t in tracks) t.id: t};
  for (final moof in top.where((b) => b.type == 'moof')) {
    var nextBase = moof.start;
    for (final traf in isoBoxes(s, moof.body, moof.end, c)) {
      if (traf.type != 'traf') continue;
      final kids = isoBoxes(s, traf.body, traf.end, c);
      final tfhd = firstOf(kids, 'tfhd');
      if (tfhd == null || tfhd.bodySize < 8) {
        throw const IsoError('track fragment without a header');
      }
      final h = isoPayload(s, tfhd);
      final flags = (h[1] << 16) | (h[2] << 8) | h[3];
      final id = be32(h, 4);
      final track = byId[id];
      if (track == null) throw const IsoError('fragment of no track');
      var q = 8;
      int? base;
      var defSize = trex[id]?.size ?? 0;
      if (flags & 0x01 != 0) {
        base = be64(h, q);
        q += 8;
      }
      if (flags & 0x02 != 0) q += 4;
      if (flags & 0x08 != 0) q += 4;
      if (flags & 0x10 != 0) {
        if (q + 4 > h.length) throw const IsoError('short fragment header');
        defSize = be32(h, q);
        q += 4;
      }
      base ??= flags & 0x20000 != 0 ? moof.start : nextBase;
      var at = base;
      for (final trun in kids.where((b) => b.type == 'trun')) {
        final p = isoPayload(s, trun, max: 64 << 20);
        if (p.length < 8) throw const IsoError('short run');
        final tf = (p[1] << 16) | (p[2] << 8) | p[3];
        final n = be32(p, 4);
        var r = 8;
        if (tf & 0x01 != 0) {
          at = base + be32(p, r).toSigned(32);
          r += 4;
        }
        if (tf & 0x04 != 0) r += 4;
        final per =
            (tf & 0x100 != 0 ? 4 : 0) +
            (tf & 0x200 != 0 ? 4 : 0) +
            (tf & 0x400 != 0 ? 4 : 0) +
            (tf & 0x800 != 0 ? 4 : 0);
        if (r + n * per > p.length) throw const IsoError('short run');
        var len = 0;
        for (var k = 0; k < n; k++) {
          var e = r + k * per;
          if (tf & 0x100 != 0) e += 4;
          len += tf & 0x200 != 0 ? be32(p, e) : defSize;
        }
        track.samples.add(at, at + len);
        track.sampleCount += n;
        at += len;
      }
      nextBase = at;
    }
  }
}

/// where the compressor name of each picture sample entry sits: 32 bytes
/// that often name the camera or the encoder
List<(int, int)> compressorNames(ByteSource s, Mp4Track t, List<int> c) {
  final d = t.stsd;
  if (d == null || t.role != TrackRole.picture || d.bodySize < 8) return [];
  return [
    for (final e in isoBoxes(s, d.body + 8, d.end, c))
      if (e.size >= 82 + 4) (e.start + 50, e.start + 82),
  ];
}

class TimedData {
  int gpsPoints = 0;
  bool motion = false;
}

const _timedCap = 8 << 20;

/// gps points and motion sensor readings in a gopro (gpmd) or google camera
/// motion (camm) track, counted, never kept. reads at most a few megabytes
TimedData timedData(ByteSource s, Mp4Track t) {
  final out = TimedData();
  if (t.format != 'gpmd' && t.format != 'camm') return out;
  var budget = _timedCap;
  for (final (a, b) in t.samples.merged) {
    if (budget <= 0) break;
    final n = (b - a) < budget ? b - a : budget;
    budget -= n;
    final p = s.read(a, n);
    if (t.format == 'gpmd') {
      _klv(p, 0, p.length, out, 0);
    } else {
      _camm(p, out);
    }
  }
  return out;
}

const _motionKeys = {'ACCL', 'GYRO', 'MAGN', 'CORI', 'GRAV', 'IORI'};

void _klv(Uint8List p, int from, int to, TimedData out, int depth) {
  var i = from;
  while (i + 8 <= to && depth < 8) {
    final key = latin1.decode(p.sublist(i, i + 4), allowInvalid: true);
    final type = p[i + 4];
    final size = p[i + 5];
    final repeat = be16(p, i + 6);
    final len = size * repeat;
    final end = i + 8 + ((len + 3) & ~3);
    if (end > to) return;
    if (key == 'GPS5' || key == 'GPS9' || key == 'GPRI') {
      out.gpsPoints += repeat;
    }
    if (_motionKeys.contains(key)) out.motion = true;
    if (type == 0) _klv(p, i + 8, i + 8 + len, out, depth + 1);
    i = end;
  }
}

// camm packet sizes after the four byte header, by packet type
const _cammSizes = [12, 8, 12, 12, 12, 24, 56, 12];

void _camm(Uint8List p, TimedData out) {
  var i = 0;
  while (i + 4 <= p.length) {
    final type = p[i + 2] | (p[i + 3] << 8);
    if (type >= _cammSizes.length) return;
    if (type == 5 || type == 6) out.gpsPoints++;
    if (type == 2 || type == 3 || type == 7) out.motion = true;
    i += 4 + _cammSizes[type];
  }
}
