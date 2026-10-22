// SPDX-License-Identifier: GPL-3.0-or-later
// a heic or avif made to hold its picture and nothing beside it. the items
// the picture is drawn from (the primary, the tiles or layers it is built
// from, its alpha plane) are kept; exif, xmp, thumbnails, depth maps,
// mattes, gain maps and any other picture go. the meta box is written again
// with only the kept items and padded to its old size, so no byte moves and
// every offset in iloc still points where it did. the bytes of what went,
// and any mdat or idat byte no kept item uses, are zeroed. a clip or vendor
// box after the picture is cut, one before it renamed 'free' and zeroed.
import 'dart:convert';
import 'dart:typed_data';

import 'meta/byte_source.dart';
import 'meta/heif_items.dart';
import 'meta/iso.dart';
import 'meta/mp4_tracks.dart';

/// the cleaned bytes, [src] itself when there was nothing to do, or null
/// when the file cannot be read through or rebuilt
Uint8List? cleanHeif(Uint8List src) {
  try {
    return _clean(src);
  } on IsoError {
    return null;
  } on RangeError {
    return null;
  }
}

const _free = [0x66, 0x72, 0x65, 0x65];

// brands of an image sequence, whose moov is the animation and stays
const _sequences = {'msf1', 'hevc', 'hevx', 'hevm', 'hevs', 'avis'};

// top level boxes a heif is made of
const _top = {'ftyp', 'meta', 'mdat', 'free', 'skip', 'moov'};

// meta children written again; any other goes
const _metaKeep = {
  'hdlr',
  'pitm',
  'iinf',
  'iloc',
  'iref',
  'iprp',
  'idat',
  'grpl',
  'dinf',
};

Uint8List? _clean(Uint8List src) {
  final s = MemorySource(src);
  final c = [0];
  final top = isoBoxes(s, 0, src.length, c);
  if (top.isEmpty || top.first.type != 'ftyp') return null;
  if (firstOf(top, 'mini') != null) return null;
  final meta = firstOf(top, 'meta');
  if (meta == null) return null;
  final m = readHeifMeta(s, meta, c);
  final keep = heifPictureItems(s, m);
  if (keep.isEmpty) return null;

  // the kept items' bytes, in the file and in idat
  final used = Ranges();
  final usedIdat = Ranges();
  var dataEnd = meta.end;
  for (final id in keep) {
    final p = m.places[id];
    if (p == null) continue; // a derived item with no bytes of its own
    if (p.method == 2) return null; // read from another item: not guessed
    for (final e in p.extents) {
      if (p.method == 1) {
        if (m.idat == null) return null;
        usedIdat.add(e.at, e.len == 0 ? m.idat!.bodySize : e.at + e.len);
        continue;
      }
      final to = e.len == 0 ? src.length : e.at + e.len;
      if (e.at < 0 || to > src.length) return null;
      // bytes inside the meta box would move when it is written again
      if (e.at < meta.end && to > meta.start) return null;
      used.add(e.at, to);
      if (to > dataEnd) dataEnd = to;
    }
  }

  final sequence = _brands(src, top.first).any(_sequences.contains);
  final foreign = <IsoBox>[];
  var appended = false;
  for (final b in top) {
    final after = b.start >= dataEnd;
    if (after && b.type == 'ftyp') appended = true;
    final media = b.type == 'moov' || b.type == 'mdat';
    if (b == top.first) continue;
    if (!_top.contains(b.type) ||
        (after && (appended || (media && !sequence))) ||
        (b.type == 'moov' && !sequence)) {
      foreign.add(b);
    }
  }
  // an animation's frames are its tracks' samples. every track's stay here;
  // which tracks an animation keeps is the video cleaner's call
  if (sequence && top.any((b) => b.type == 'moov' && !foreign.contains(b))) {
    final lay = readMp4LayoutOf(s, top, c);
    for (final t in lay.tracks) {
      used.addAll(t.samples);
    }
  }
  // a kept picture byte inside a box about to go
  for (final (a, b) in used.merged) {
    if (foreign.any((f) => a < f.end && b > f.start)) return null;
  }

  final rebuilt = _metaBody(s, m, keep, usedIdat);
  if (rebuilt == null) return null;

  final out = Uint8List.fromList(src);
  out.setRange(meta.body, meta.end, rebuilt);
  _brandsKept(out, top.first, m, keep);
  if (sequence) {
    for (final b in top.where((b) => b.type == 'moov')) {
      if (!foreign.contains(b)) _neuterMovie(out, s, b, c);
    }
  }
  // every mdat byte no kept item uses
  final kept = used.merged;
  for (final b in top.where((b) => b.type == 'mdat')) {
    if (foreign.contains(b)) continue;
    for (final (x, y) in Ranges.gaps(kept, b.body, b.end)) {
      out.fillRange(x, y, 0);
    }
  }
  // free space can hold old bytes
  for (final b in top.where((b) => b.type == 'free' || b.type == 'skip')) {
    out.fillRange(b.body, b.end, 0);
  }
  // what went that lay outside mdat
  for (final id in m.items.keys) {
    if (keep.contains(id)) continue;
    final p = m.places[id];
    if (p == null || p.method != 0) continue;
    for (final e in p.extents) {
      if (e.len == 0) continue;
      final a = e.at.clamp(0, src.length);
      final b = (e.at + e.len).clamp(0, src.length);
      if (kept.any((k) => a < k.$2 && b > k.$1)) continue;
      if (a < meta.end && b > meta.start) continue; // written again above
      out.fillRange(a, b, 0);
    }
  }

  var cut = out.length;
  for (final b in top.reversed) {
    if (!foreign.contains(b)) break;
    cut = b.start;
  }
  for (final b in foreign) {
    if (b.start >= cut) continue;
    out.setRange(b.start + 4, b.start + 8, _free);
    out.fillRange(b.body, b.end, 0);
  }
  final done = cut == out.length ? out : Uint8List.sublistView(out, 0, cut);
  return _same(done, src) ? src : done;
}

// a brand that promises an item now gone is swapped for the major brand,
// in place: a reader that trusts the brand would look for it and fail
void _brandsKept(Uint8List out, IsoBox ftyp, HeifMeta m, Set<int> keep) {
  final tmap = keep.any((id) => m.items[id]?.type == 'tmap');
  if (tmap || ftyp.bodySize < 8) return;
  final major = out.sublist(ftyp.body, ftyp.body + 4);
  for (var i = ftyp.body + 8; i + 4 <= ftyp.end; i += 4) {
    if (latin1.decode(out.sublist(i, i + 4)) == 'tmap') {
      out.setRange(i, i + 4, major);
    }
  }
}

// the animation's own metadata: udta, meta and uuid boxes go as 'free' and
// zeroed, the creation and change stamps are zeroed. the tracks stay
const _movieNeuter = {'udta', 'meta', 'uuid'};
const _movieInto = {'moov', 'trak', 'mdia', 'minf', 'stbl', 'edts', 'dinf'};
const _movieStamped = {'mvhd', 'tkhd', 'mdhd'};

void _neuterMovie(Uint8List out, ByteSource s, IsoBox box, List<int> c) {
  for (final b in isoBoxes(s, box.body, box.end, c)) {
    if (_movieNeuter.contains(b.type)) {
      out.setRange(b.start + 4, b.start + 8, _free);
      out.fillRange(b.body, b.end, 0);
    } else if (_movieStamped.contains(b.type)) {
      if (b.bodySize < 4) throw const IsoError('short header box');
      final w = out[b.body] == 1 ? 8 : 4;
      if (b.bodySize < 4 + 2 * w) throw const IsoError('short header box');
      out.fillRange(b.body + 4, b.body + 4 + 2 * w, 0);
    } else if (_movieInto.contains(b.type)) {
      _neuterMovie(out, s, b, c);
    }
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Iterable<String> _brands(Uint8List b, IsoBox f) sync* {
  for (var i = f.body; i + 4 <= f.end; i += 4) {
    if (i == f.body + 4) continue; // minor version
    yield latin1.decode(b.sublist(i, i + 4));
  }
}

List<int> _box(String type, List<int> body) => [
  ..._be32(8 + body.length),
  ...latin1.encode(type),
  ...body,
];

List<int> _be32(int v) => [
  (v >> 24) & 255,
  (v >> 16) & 255,
  (v >> 8) & 255,
  v & 255,
];

List<int> _be16(int v) => [(v >> 8) & 255, v & 255];

// the meta payload again, with only the kept items, the size it was
List<int>? _metaBody(ByteSource s, HeifMeta m, Set<int> keep, Ranges idatUsed) {
  final old = m.meta;
  final body = <int>[...s.read(old.body, 4)]; // version and flags
  var hdlr = -1;
  // properties the kept items use, in their old order, numbered anew
  final usedProps = <int>{
    for (final id in keep)
      for (final a in m.assoc[id] ?? const <HeifAssoc>[]) a.index,
  };
  final order = usedProps.where((i) => i >= 1 && i <= m.props.length).toList()
    ..sort();
  final renumber = {for (var k = 0; k < order.length; k++) order[k]: k + 1};

  for (final k in m.kids) {
    if (!_metaKeep.contains(k.type)) continue;
    switch (k.type) {
      case 'hdlr':
        if (k.bodySize < 24) return null;
        hdlr = body.length;
        // type and reserved stay; the name is zeroed
        body.addAll(
          _box('hdlr', [
            ...s.read(k.body, 24),
            ...List.filled(k.bodySize - 24, 0),
          ]),
        );
      case 'pitm' || 'dinf':
        body.addAll(s.read(k.start, k.size));
      case 'iinf':
        final v = s.read(k.body, 1)[0];
        final items = [
          for (final id in m.items.keys)
            if (keep.contains(id)) m.items[id]!,
        ];
        body.addAll(
          _box('iinf', [
            v,
            0,
            0,
            0,
            ...(v == 0 ? _be16(items.length) : _be32(items.length)),
            for (final it in items) ..._infe(s, it),
          ]),
        );
      case 'iloc':
        final places = [
          for (final id in m.places.keys)
            if (keep.contains(id)) m.places[id]!,
        ];
        final p = isoPayload(s, k);
        body.addAll(
          _box('iloc', [
            ...m.ilocHead,
            ...(m.ilocVersion < 2
                ? _be16(places.length)
                : _be32(places.length)),
            for (final x in places) ...p.sublist(x.from, x.to),
          ]),
        );
      case 'iref':
        final w = m.irefVersion == 0 ? 2 : 4;
        List<int> id(int v) => w == 2 ? _be16(v) : _be32(v);
        final refs = <List<int>>[];
        for (final r in m.refs) {
          if (!keep.contains(r.from)) continue;
          final to = r.to.where(keep.contains).toList();
          if (to.isEmpty) continue;
          refs.add(
            _box(r.type, [
              ...id(r.from),
              ..._be16(to.length),
              for (final t in to) ...id(t),
            ]),
          );
        }
        if (refs.isNotEmpty) {
          body.addAll(
            _box('iref', [m.irefVersion, 0, 0, 0, for (final r in refs) ...r]),
          );
        }
      case 'iprp':
        final big = m.ipmaFlags & 1 != 0;
        final entries = <int>[];
        var n = 0;
        for (final id in keep.toList()..sort()) {
          final list = m.assoc[id];
          if (list == null || list.isEmpty) continue;
          n++;
          entries.addAll(m.ipmaVersion < 1 ? _be16(id) : _be32(id));
          entries.add(list.length);
          for (final a in list) {
            final i = renumber[a.index] ?? 0;
            if (big) {
              entries.addAll(_be16((a.essential ? 0x8000 : 0) | i));
            } else {
              entries.add((a.essential ? 0x80 : 0) | i);
            }
          }
        }
        body.addAll(
          _box('iprp', [
            ..._box('ipco', [
              for (final i in order)
                ...s.read(m.props[i - 1].start, m.props[i - 1].size),
            ]),
            ..._box('ipma', [
              m.ipmaVersion,
              0,
              0,
              m.ipmaFlags,
              ..._be32(n),
              ...entries,
            ]),
          ]),
        );
      case 'idat':
        final b = Uint8List.fromList(s.read(k.body, k.bodySize));
        for (final (x, y) in Ranges.gaps(idatUsed.merged, 0, b.length)) {
          b.fillRange(x, y, 0);
        }
        body.addAll(_box('idat', b));
      case 'grpl':
        final groups = <int>[];
        for (final g in m.groups) {
          if (g.entities.length < 2 || !g.entities.every(keep.contains)) {
            continue;
          }
          groups.addAll(s.read(g.box.start, g.box.size));
        }
        if (groups.isNotEmpty) body.addAll(_box('grpl', groups));
    }
  }
  final room = old.bodySize - body.length;
  if (room < 0) return null;
  if (room >= 8) {
    body.addAll(_box('free', List.filled(room - 8, 0)));
  } else if (room > 0) {
    // too small for a box of its own: the handler's name takes it
    if (hdlr < 0) return null;
    final size =
        (body[hdlr] << 24 |
            body[hdlr + 1] << 16 |
            body[hdlr + 2] << 8 |
            body[hdlr + 3]) +
        room;
    body.setRange(hdlr, hdlr + 4, _be32(size));
    final end = hdlr + size - room;
    body.insertAll(end, List.filled(room, 0));
  }
  return body;
}

// an item entry with its name left empty; a mime item keeps its type
List<int> _infe(ByteSource s, HeifItem it) {
  final p = s.read(it.infe.body, it.infe.bodySize);
  final v = p[0];
  if (v < 2) return s.read(it.infe.start, it.infe.size);
  final idLen = v == 2 ? 2 : 4;
  final head = p.sublist(0, 4 + idLen + 2 + 4); // version, id, protection, type
  return _box('infe', [
    ...head,
    0,
    if (it.type == 'mime') ...[...utf8.encode(it.contentType ?? ''), 0],
  ]);
}
