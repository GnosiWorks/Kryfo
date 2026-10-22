// SPDX-License-Identifier: GPL-3.0-or-later
// the items of a heif or avif: what each one is, where its bytes are, how
// they point at each other and which properties they carry. the reader names
// them; the cleaner keeps the picture's own items and rebuilds the meta box
// around them.
import 'dart:convert';
import 'dart:typed_data';

import 'byte_source.dart';
import 'iso.dart';

class HeifItem {
  final int id;
  final String type;
  final String name;
  final String? contentType;
  final IsoBox infe;
  const HeifItem(this.id, this.type, this.name, this.contentType, this.infe);

  bool get isXmp {
    if (type != 'mime') return false;
    final c = (contentType ?? '').toLowerCase();
    return c.contains('rdf+xml') || c.contains('xmp');
  }
}

class HeifExtent {
  final int at; // absolute for method 0, from the idat payload for method 1
  final int len;
  const HeifExtent(this.at, this.len);
}

class HeifPlace {
  final int id;
  final int method;
  final List<HeifExtent> extents;
  final int from; // the entry's bytes in the iloc payload
  final int to;
  const HeifPlace(this.id, this.method, this.extents, this.from, this.to);
}

class HeifRef {
  final String type;
  final int from;
  final List<int> to;
  const HeifRef(this.type, this.from, this.to);
}

class HeifGroup {
  final String type;
  final int id;
  final List<int> entities;
  final IsoBox box;
  const HeifGroup(this.type, this.id, this.entities, this.box);
}

class HeifAssoc {
  final int index; // 1-based into ipco
  final bool essential;
  const HeifAssoc(this.index, this.essential);
}

class HeifMeta {
  final IsoBox meta;
  final List<IsoBox> kids;
  int? primary;
  final Map<int, HeifItem> items = {};
  final Map<int, HeifPlace> places = {};
  int ilocVersion = 0;
  Uint8List ilocHead = Uint8List(0); // version, flags and the size nibbles
  int ilocIdxSize = 0;
  final List<HeifRef> refs = [];
  int irefVersion = 0;
  final List<IsoBox> props = [];
  final Map<int, List<HeifAssoc>> assoc = {};
  int ipmaVersion = 0;
  int ipmaFlags = 0;
  final List<HeifGroup> groups = [];
  IsoBox? idat;
  IsoBox? iprp;
  IsoBox? ipco;
  HeifMeta(this.meta, this.kids);

  Iterable<HeifRef> refsOf(String type) => refs.where((r) => r.type == type);

  /// the urn of the item's auxC property, if it has one
  String? auxType(ByteSource s, int id) {
    for (final a in assoc[id] ?? const <HeifAssoc>[]) {
      if (a.index < 1 || a.index > props.length) continue;
      final p = props[a.index - 1];
      if (p.type != 'auxC' || p.bodySize < 5) continue;
      final b = s.read(p.body + 4, (p.bodySize - 4).clamp(0, 256));
      final z = b.indexOf(0);
      return latin1.decode(b.sublist(0, z < 0 ? b.length : z));
    }
    return null;
  }

  /// file ranges of an item's bytes, or null for one built from other items
  List<(int, int)>? fileRanges(int id) {
    final p = places[id];
    if (p == null) return const [];
    if (p.method == 2) return null;
    final base = p.method == 1 ? idat?.body : 0;
    if (base == null) return null;
    return [for (final e in p.extents) (base + e.at, base + e.at + e.len)];
  }
}

/// the heif meta box at [meta], read whole. throws IsoError when a table
/// cannot be read through
HeifMeta readHeifMeta(ByteSource s, IsoBox meta, List<int> c) {
  if (meta.bodySize < 4) throw const IsoError('short meta box');
  final kids = isoBoxes(s, meta.body + 4, meta.end, c);
  final m = HeifMeta(meta, kids);
  for (final k in kids) {
    switch (k.type) {
      case 'pitm':
        final p = isoPayload(s, k);
        if (p.length < 6) throw const IsoError('short pitm');
        m.primary = p[0] == 0 ? be16(p, 4) : be32(p, 4);
      case 'iinf':
        _iinf(s, k, m, c);
      case 'iloc':
        _iloc(s, k, m);
      case 'iref':
        _iref(s, k, m, c);
      case 'iprp':
        _iprp(s, k, m, c);
      case 'idat':
        m.idat = k;
      case 'grpl':
        for (final g in isoBoxes(s, k.body, k.end, c)) {
          final p = isoPayload(s, g);
          if (p.length < 12) throw const IsoError('short group');
          final n = be32(p, 8);
          if (12 + n * 4 > p.length) throw const IsoError('short group');
          m.groups.add(
            HeifGroup(g.type, be32(p, 4), [
              for (var i = 0; i < n; i++) be32(p, 12 + i * 4),
            ], g),
          );
        }
    }
  }
  return m;
}

void _iinf(ByteSource s, IsoBox x, HeifMeta m, List<int> c) {
  if (x.bodySize < 6) throw const IsoError('short iinf');
  final v = s.read(x.body, 1)[0];
  final at = x.body + 4 + (v == 0 ? 2 : 4);
  for (final e in isoBoxes(s, at, x.end, c)) {
    if (e.type != 'infe') continue;
    final p = isoPayload(s, e);
    if (p.length < 4) throw const IsoError('short infe');
    final ev = p[0];
    if (ev < 2) {
      // no item type in these; an old style entry names a file or a mime type
      if (p.length < 8) throw const IsoError('short infe');
      final id = be16(p, 4);
      m.items[id] = HeifItem(id, '', '', null, e);
      continue;
    }
    final idLen = ev == 2 ? 2 : 4;
    var q = 4;
    if (q + idLen + 6 > p.length) throw const IsoError('short infe');
    final id = idLen == 2 ? be16(p, q) : be32(p, q);
    q += idLen + 2;
    final type = fourcc(p, q);
    q += 4;
    String cstr() {
      final z = p.indexOf(0, q);
      final end = z < 0 ? p.length : z;
      final s = utf8.decode(p.sublist(q, end), allowMalformed: true);
      q = end + 1;
      return s;
    }

    final name = q < p.length ? cstr() : '';
    final content = type == 'mime' && q < p.length ? cstr() : null;
    m.items[id] = HeifItem(id, type, name, content, e);
  }
}

void _iloc(ByteSource s, IsoBox x, HeifMeta m) {
  final p = isoPayload(s, x);
  if (p.length < 8) throw const IsoError('short iloc');
  final v = p[0];
  if (v > 2) throw const IsoError('unknown location table');
  m.ilocVersion = v;
  final offSize = p[4] >> 4, lenSize = p[4] & 15;
  final baseSize = p[5] >> 4;
  final idxSize = v == 0 ? 0 : p[5] & 15;
  m.ilocIdxSize = idxSize;
  m.ilocHead = Uint8List.fromList(p.sublist(0, 6));
  var q = 6;
  int count;
  if (v < 2) {
    count = be16(p, q);
    q += 2;
  } else {
    if (q + 4 > p.length) throw const IsoError('short iloc');
    count = be32(p, q);
    q += 4;
  }
  int read(int size) {
    if (size == 0) return 0;
    if (size != 4 && size != 8) throw const IsoError('odd field size');
    if (q + size > p.length) throw const IsoError('short iloc');
    final r = size == 8 ? be64(p, q) : be32(p, q);
    q += size;
    return r;
  }

  for (var n = 0; n < count; n++) {
    final from = q;
    final idLen = v < 2 ? 2 : 4;
    if (q + idLen > p.length) throw const IsoError('short iloc');
    final id = idLen == 2 ? be16(p, q) : be32(p, q);
    q += idLen;
    var method = 0;
    if (v > 0) {
      if (q + 2 > p.length) throw const IsoError('short iloc');
      method = be16(p, q) & 15;
      q += 2;
    }
    if (q + 2 > p.length) throw const IsoError('short iloc');
    q += 2; // data reference index
    final base = read(baseSize);
    if (q + 2 > p.length) throw const IsoError('short iloc');
    final extents = be16(p, q);
    q += 2;
    final list = <HeifExtent>[];
    for (var k = 0; k < extents; k++) {
      read(idxSize);
      final off = read(offSize);
      final len = read(lenSize);
      list.add(HeifExtent(base + off, len));
    }
    m.places[id] = HeifPlace(id, method, list, from, q);
  }
}

void _iref(ByteSource s, IsoBox x, HeifMeta m, List<int> c) {
  if (x.bodySize < 4) throw const IsoError('short iref');
  final v = s.read(x.body, 1)[0];
  m.irefVersion = v;
  final w = v == 0 ? 2 : 4;
  for (final r in isoBoxes(s, x.body + 4, x.end, c)) {
    final p = isoPayload(s, r);
    if (p.length < w + 2) throw const IsoError('short reference');
    final from = w == 2 ? be16(p, 0) : be32(p, 0);
    final n = be16(p, w);
    if (w + 2 + n * w > p.length) throw const IsoError('short reference');
    m.refs.add(
      HeifRef(r.type, from, [
        for (var i = 0; i < n; i++)
          w == 2 ? be16(p, w + 2 + i * w) : be32(p, w + 2 + i * w),
      ]),
    );
  }
}

void _iprp(ByteSource s, IsoBox x, HeifMeta m, List<int> c) {
  m.iprp = x;
  final kids = isoBoxes(s, x.body, x.end, c);
  final ipco = firstOf(kids, 'ipco');
  m.ipco = ipco;
  if (ipco != null) m.props.addAll(isoBoxes(s, ipco.body, ipco.end, c));
  for (final a in kids.where((b) => b.type == 'ipma')) {
    final p = isoPayload(s, a);
    if (p.length < 8) throw const IsoError('short ipma');
    final v = p[0];
    final flags = p[3];
    m.ipmaVersion = v;
    m.ipmaFlags = flags;
    final n = be32(p, 4);
    var q = 8;
    for (var k = 0; k < n; k++) {
      final idLen = v < 1 ? 2 : 4;
      if (q + idLen + 1 > p.length) throw const IsoError('short ipma');
      final id = idLen == 2 ? be16(p, q) : be32(p, q);
      q += idLen;
      final count = p[q++];
      final list = <HeifAssoc>[];
      for (var j = 0; j < count; j++) {
        if (flags & 1 != 0) {
          if (q + 2 > p.length) throw const IsoError('short ipma');
          final w = be16(p, q);
          q += 2;
          list.add(HeifAssoc(w & 0x7fff, w & 0x8000 != 0));
        } else {
          if (q + 1 > p.length) throw const IsoError('short ipma');
          final b = p[q++];
          list.add(HeifAssoc(b & 0x7f, b & 0x80 != 0));
        }
      }
      (m.assoc[id] ??= []).addAll(list);
    }
  }
}

// ---- what each item is ----

const kAlphaUrns = {
  'urn:mpeg:mpegB:cicp:systems:auxiliary:alpha',
  'urn:mpeg:hevc:2015:auxid:1',
};

const _derived = {'grid', 'iovl', 'iden'};

/// item types a picture is coded or built in
const kHeifCodings = {
  'hvc1',
  'hev1',
  'av01',
  'avc1',
  'jpeg',
  'grid',
  'iovl',
  'iden',
  'unci',
  'j2k1',
  'vvc1',
};

/// the items the picture is drawn from: the primary, the tiles or layers it
/// is built from, and its alpha plane. everything else is beside it
Set<int> heifPictureItems(ByteSource s, HeifMeta m) {
  final keep = <int>{};
  final primary = m.primary;
  if (primary == null || !m.items.containsKey(primary)) return keep;
  void add(int id) {
    if (!keep.add(id)) return;
    final it = m.items[id];
    if (it != null && _derived.contains(it.type)) {
      for (final r in m.refsOf('dimg').where((r) => r.from == id)) {
        r.to.forEach(add);
      }
    }
  }

  add(primary);
  // alpha planes of what is kept, and their own tiles
  var grew = true;
  while (grew) {
    grew = false;
    for (final r in m.refsOf('auxl')) {
      if (keep.contains(r.from)) continue;
      if (!r.to.any(keep.contains)) continue;
      if (!kAlphaUrns.contains(m.auxType(s, r.from))) continue;
      add(r.from);
      grew = true;
    }
  }
  return keep;
}

enum HeifRole {
  picture,
  another,
  exif,
  xmp,
  thumbnail,
  depth,
  matte,
  hdr,
  attached,
  other,
}

const _depthUrns = {
  'urn:mpeg:hevc:2015:auxid:2',
  'urn:mpeg:mpegB:cicp:systems:auxiliary:depth',
  'urn:com:apple:photo:2018:aux:depth',
  'urn:com:apple:photo:2019:aux:depth',
};

/// what an item beside the picture is
HeifRole heifRole(
  ByteSource s,
  HeifMeta m,
  int id,
  Set<int> picture, [
  int depth = 0,
]) {
  if (picture.contains(id)) return HeifRole.picture;
  final it = m.items[id];
  if (it == null) return HeifRole.other;
  if (it.type == 'Exif') return HeifRole.exif;
  if (it.isXmp) return HeifRole.xmp;
  if (it.type == 'tmap') return HeifRole.hdr;
  if (m.refsOf('thmb').any((r) => r.from == id)) return HeifRole.thumbnail;
  final aux = m.auxType(s, id);
  if (aux != null) {
    final a = aux.toLowerCase();
    if (a.contains('hdrgainmap')) return HeifRole.hdr;
    if (_depthUrns.contains(aux) || a.contains('depth')) return HeifRole.depth;
    if (a.contains('matte')) return HeifRole.matte;
    return HeifRole.other;
  }
  // the second input of a tone map item is its gain map
  for (final r in m.refsOf('dimg')) {
    if (m.items[r.from]?.type == 'tmap' && r.to.contains(id)) {
      return HeifRole.hdr;
    }
  }
  // an item a derived picture item is drawn from, not kept: a part of
  // something beside the picture, such as a gain map's tiles
  for (final r in m.refsOf('dimg')) {
    if (r.to.contains(id)) {
      final up = m.items[r.from];
      if (up != null && !picture.contains(up.id) && depth < 8) {
        return heifRole(s, m, up.id, picture, depth + 1);
      }
    }
  }
  if (it.type == 'mime' || it.type == 'uri ') return HeifRole.attached;
  // a whole second picture of a collection
  if (kHeifCodings.contains(it.type)) return HeifRole.another;
  return HeifRole.other;
}
