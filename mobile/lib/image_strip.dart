// SPDX-License-Identifier: GPL-3.0-or-later
// a picture sent as a file, cleaned like one sent as a photo. the photo lane
// re-encodes; the file lane sends the file as it is, so this cleaning is
// lossless and never touches the picture data. the kind comes from the
// first bytes, not the name:
//   jpeg   the app segments go (jpeg_strip.dart)
//   png    only the chunks a picture is drawn from are kept, whole, so no
//          crc has to be redone
//   webp   EXIF and 'XMP ' go, their VP8X flags are cleared
//   gif    comments go, and every application block but the loop ones
//   heif   heic and avif: exif and xmp items are zeroed where they sit so
//          iloc offsets hold; unknown top level boxes are cut or emptied
// true: read end to end and clean. false: not a kind known here, left alone.
// null: it claims to be one and could not be read through, and a caller
// drops a null rather than send what it could not vouch for.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'jpeg_strip.dart';

enum PictureKind { jpeg, png, webp, heif, gif, other }

PictureKind pictureKind(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return PictureKind.jpeg;
  }
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A) {
    return PictureKind.png;
  }
  if (b.length >= 6 &&
      b[0] == 0x47 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x38 &&
      (b[4] == 0x37 || b[4] == 0x39) &&
      b[5] == 0x61) {
    return PictureKind.gif;
  }
  if (b.length >= 12 && _tag(b, 0) == 'RIFF' && _tag(b, 8) == 'WEBP') {
    return PictureKind.webp;
  }
  if (b.length >= 16 && _tag(b, 4) == 'ftyp') {
    final end = _u32(b, 0).clamp(16, b.length);
    for (var i = 8; i + 4 <= end; i += 4) {
      if (i == 12) continue; // minor version, not a brand
      if (_heifBrands.contains(_tag(b, i))) return PictureKind.heif;
    }
  }
  return PictureKind.other;
}

const _heifBrands = {
  'heic',
  'heix',
  'hevc',
  'hevx',
  'heim',
  'heis',
  'mif1',
  'msf1',
  'avif',
  'avis',
};

/// cleans the file at [path] in place. see the contract at the top.
Future<bool?> stripPictureFile(String path) async {
  final f = File(path);
  final src = await f.readAsBytes();
  final out = stripPictureBytes(src);
  if (out == null) return null;
  if (identical(out, src)) return pictureKind(src) != PictureKind.other;
  await f.writeAsBytes(out, flush: true);
  return true;
}

/// the same, off the ui thread: walking megabytes of scan data drops
/// frames. top level, so the isolate gets the path and nothing of the caller.
Future<bool?> stripPictureFileOffUi(String path) =>
    Isolate.run(() => stripPictureFile(path));

/// the cleaned bytes; [src] itself when there was nothing to do or the file
/// is no picture known here; null when it could not be read through.
Uint8List? stripPictureBytes(Uint8List src) {
  switch (pictureKind(src)) {
    case PictureKind.jpeg:
      return stripJpegMetadata(src);
    case PictureKind.png:
      return _png(src);
    case PictureKind.webp:
      return _webp(src);
    case PictureKind.heif:
      return _heif(src);
    case PictureKind.gif:
      return _gif(src);
    case PictureKind.other:
      return src;
  }
}

String _tag(Uint8List b, int i) => latin1.decode(b.sublist(i, i + 4));
int _u16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];
int _u32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
int _u32le(Uint8List b, int i) =>
    b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);

// ---------------------------------------------------------------- png

// what a png needs to be drawn in the right colours, and the three that make
// an animated one move. everything else goes: a keep list is not surprised
// by a chunk like caBX (content credentials, which can name the account).
const _pngKeep = {
  'IHDR', 'PLTE', 'IDAT', 'IEND', 'tRNS', // the picture
  'gAMA', 'cHRM', 'sRGB', 'iCCP', 'sBIT', 'cICP', 'mDCv', 'cLLi', // colour
  'bKGD', 'pHYs', 'sPLT', 'hIST', // how to show it
  'acTL', 'fcTL', 'fdAT', // apng
};

Uint8List? _png(Uint8List src) {
  final out = BytesBuilder(copy: false);
  out.add(src.sublist(0, 8));
  var i = 8;
  var dropped = false;
  while (true) {
    if (i + 12 > src.length) return null; // no IEND before the file ran out
    final len = _u32(src, i);
    final end = i + 12 + len;
    if (len > 0x7fffffff || end > src.length) return null;
    final type = _tag(src, i + 4);
    if (_pngKeep.contains(type)) {
      out.add(src.sublist(i, end));
    } else {
      dropped = true;
    }
    i = end;
    // anything after IEND is not the picture. it goes too
    if (type == 'IEND') {
      if (i != src.length) dropped = true;
      break;
    }
  }
  return dropped ? out.toBytes() : src;
}

// --------------------------------------------------------------- webp

Uint8List? _webp(Uint8List src) {
  final chunks = <Uint8List>[];
  var i = 12;
  var dropped = false;
  final riffEnd = 8 + _u32le(src, 4);
  if (riffEnd > src.length) return null;
  while (i < riffEnd) {
    if (i + 8 > riffEnd) return null;
    final type = _tag(src, i);
    final len = _u32le(src, i + 4);
    final end = i + 8 + len + (len & 1); // chunks are padded to even
    if (end > riffEnd + 1 || i + 8 + len > src.length) return null;
    final stop = end > src.length ? src.length : end;
    if (type == 'EXIF' || type == 'XMP ') {
      dropped = true;
    } else {
      final c = Uint8List.fromList(src.sublist(i, stop));
      // VP8X says up front which extras follow. bit 3 exif, bit 2 xmp
      if (type == 'VP8X' && len >= 1 && (c[8] & 0x0C) != 0) {
        c[8] &= ~0x0C & 0xFF;
        dropped = true;
      }
      chunks.add(c);
    }
    i = end;
  }
  // bytes after the riff are not the picture
  if (riffEnd + (riffEnd & 1) < src.length) dropped = true;
  if (!dropped) return src;
  final body = BytesBuilder(copy: false);
  for (final c in chunks) {
    body.add(c);
    if (c.length & 1 == 1) body.add([0]);
  }
  final b = body.toBytes();
  final size = 4 + b.length;
  final out = BytesBuilder(copy: false)
    ..add(latin1.encode('RIFF'))
    ..add([
      size & 255,
      (size >> 8) & 255,
      (size >> 16) & 255,
      (size >> 24) & 255,
    ])
    ..add(latin1.encode('WEBP'))
    ..add(b);
  return out.toBytes();
}

// ---------------------------------------------------------------- gif

// the application blocks that make it loop; the rest (xmp, mostly) go
const _gifApps = {'NETSCAPE2.0', 'ANIMEXTS1.0'};

Uint8List? _gif(Uint8List src) {
  if (src.length < 13) return null;
  var i = 13;
  final flags = src[10];
  if (flags & 0x80 != 0) i += 3 * (1 << ((flags & 7) + 1)); // global palette
  if (i > src.length) return null;
  final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(src, 0, i));
  var dropped = false;

  // the end of a run of length-prefixed sub-blocks starting at [p]
  int? subBlocks(int p) {
    while (true) {
      if (p >= src.length) return null;
      final n = src[p];
      p += 1 + n;
      if (n == 0) return p;
      if (p > src.length) return null;
    }
  }

  while (true) {
    if (i >= src.length) return null; // no trailer
    final b = src[i];
    if (b == 0x3B) {
      out.add(const [0x3B]);
      if (i + 1 != src.length) dropped = true; // bytes after the end
      break;
    }
    if (b == 0x2C) {
      // an image: descriptor, local palette, code size, data
      if (i + 10 > src.length) return null;
      var p = i + 10;
      final f = src[i + 9];
      if (f & 0x80 != 0) p += 3 * (1 << ((f & 7) + 1));
      if (p + 1 > src.length) return null;
      final end = subBlocks(p + 1);
      if (end == null) return null;
      out.add(Uint8List.sublistView(src, i, end));
      i = end;
      continue;
    }
    if (b == 0x21) {
      if (i + 2 > src.length) return null;
      final label = src[i + 1];
      final end = subBlocks(i + 2);
      if (end == null) return null;
      var keep = label == 0xF9 || label == 0x01; // frame timing, plain text
      if (label == 0xFF && i + 14 <= src.length && src[i + 2] == 11) {
        keep = _gifApps.contains(latin1.decode(src.sublist(i + 3, i + 14)));
      }
      if (keep) {
        out.add(Uint8List.sublistView(src, i, end));
      } else {
        dropped = true;
      }
      i = end;
      continue;
    }
    return null; // not a block a gif has
  }
  return dropped ? out.toBytes() : src;
}

// --------------------------------------------------------------- heif

class _Box {
  final String type;
  final int start; // of the header
  final int body; // of the payload
  final int end;
  const _Box(this.type, this.start, this.body, this.end);
}

List<_Box>? _boxes(Uint8List b, int from, int to) {
  final out = <_Box>[];
  var i = from;
  while (i < to) {
    if (i + 8 > to) return null;
    var size = _u32(b, i);
    final type = _tag(b, i + 4);
    var head = 8;
    if (size == 1) {
      if (i + 16 > to) return null;
      if (_u32(b, i + 8) != 0) return null; // past anything we would hold
      size = _u32(b, i + 12);
      head = 16;
    } else if (size == 0) {
      size = to - i; // runs to the end
    }
    if (size < head || i + size > to) return null;
    out.add(_Box(type, i, i + head, i + size));
    i += size;
  }
  return out;
}

Uint8List? _heif(Uint8List src) {
  final top = _boxes(src, 0, src.length);
  if (top == null) return null;
  final metas = top.where((x) => x.type == 'meta').toList();
  if (metas.isEmpty) return null; // a heif with no meta has no picture either
  final meta = metas.first;
  if (meta.body + 4 > meta.end) return null;
  final inner = _boxes(src, meta.body + 4, meta.end); // past version+flags
  if (inner == null) return null;

  // which items are about the picture and not of it
  final strip = <int>{};
  final iinf = inner.where((x) => x.type == 'iinf').toList();
  if (iinf.isEmpty) return null;
  {
    final x = iinf.first;
    if (x.body + 6 > x.end) return null;
    final v = src[x.body];
    final entriesAt = x.body + 4 + (v == 0 ? 2 : 4);
    if (entriesAt > x.end) return null;
    final infes = _boxes(src, entriesAt, x.end);
    if (infes == null) return null;
    for (final e in infes) {
      if (e.type != 'infe') continue;
      if (e.body + 4 > e.end) return null;
      final ev = src[e.body];
      if (ev < 2) continue; // v0/v1 carry no item type; nothing to match on
      var p = e.body + 4;
      final idLen = ev == 2 ? 2 : 4;
      if (p + idLen + 2 + 4 > e.end) return null;
      final id = idLen == 2 ? _u16(src, p) : _u32(src, p);
      p += idLen + 2;
      final type = _tag(src, p);
      p += 4;
      if (type == 'Exif') {
        strip.add(id);
      } else if (type == 'mime') {
        // name, then content type, both null-terminated
        final rest = latin1.decode(src.sublist(p, e.end), allowInvalid: true);
        final lower = rest.toLowerCase();
        if (lower.contains('xmp') || lower.contains('rdf+xml')) strip.add(id);
      }
    }
  }
  // top level boxes the format does not name: samsung's sefd is one, the
  // same vendor block it hangs behind a jpeg
  final foreign = top.where((x) => !_heifKnown.contains(x.type)).toList();
  if (strip.isEmpty && foreign.isEmpty) return src;

  final iloc = inner.where((x) => x.type == 'iloc').toList();
  if (iloc.isEmpty) {
    if (strip.isNotEmpty) return null;
    return _dropForeign(Uint8List.fromList(src), top, foreign);
  }
  final idat = inner.where((x) => x.type == 'idat').toList();
  final out = Uint8List.fromList(src);
  final x = iloc.first;
  var p = x.body;
  if (p + 8 > x.end) return null;
  final v = src[p];
  if (v > 2) return null;
  p += 4;
  final offSize = src[p] >> 4;
  final lenSize = src[p] & 15;
  final baseSize = src[p + 1] >> 4;
  final idxSize = v == 0 ? 0 : src[p + 1] & 15;
  p += 2;
  int count;
  if (v < 2) {
    count = _u16(src, p);
    p += 2;
  } else {
    if (p + 4 > x.end) return null;
    count = _u32(src, p);
    p += 4;
  }
  int? read(int size) {
    if (size == 0) return 0;
    if (size != 4 && size != 8) return null;
    if (p + size > x.end) return null;
    if (size == 8) {
      if (_u32(src, p) != 0) return null;
      p += 4;
    }
    final r = _u32(src, p);
    p += 4;
    return r;
  }

  final located = <int>{};
  for (var n = 0; n < count; n++) {
    final idLen = v < 2 ? 2 : 4;
    if (p + idLen > x.end) return null;
    final id = idLen == 2 ? _u16(src, p) : _u32(src, p);
    p += idLen;
    var method = 0;
    if (v > 0) {
      if (p + 2 > x.end) return null;
      method = _u16(src, p) & 15;
      p += 2;
    }
    if (p + 2 > x.end) return null;
    p += 2; // data reference index
    final base = read(baseSize);
    if (base == null) return null;
    if (p + 2 > x.end) return null;
    final extents = _u16(src, p);
    p += 2;
    for (var k = 0; k < extents; k++) {
      if (idxSize > 0 && read(idxSize) == null) return null;
      final off = read(offSize);
      final len = read(lenSize);
      if (off == null || len == null) return null;
      if (!strip.contains(id)) {
        // a picture item kept inside a box about to be emptied would be
        // emptied with it
        if (method == 0 && foreign.isNotEmpty) {
          final from = base + off;
          final to = len == 0 ? src.length : from + len;
          if (foreign.any((f) => from < f.end && to > f.start)) return null;
        }
        continue;
      }
      int at;
      if (method == 0) {
        at = base + off;
      } else if (method == 1) {
        if (idat.isEmpty) return null;
        at = idat.first.body + base + off;
      } else {
        return null; // built from other items; not something to guess at
      }
      // a zero length means "to the end of the file", which for metadata
      // beside a picture is not a thing to take on trust
      if (len == 0 || at < 0 || at + len > out.length) return null;
      out.fillRange(at, at + len, 0);
      located.add(id);
    }
  }
  // named in iinf and never located: cannot say it is clean
  if (located.length != strip.length) return null;
  return _dropForeign(out, top, foreign);
}

const _heifKnown = {'ftyp', 'meta', 'mdat', 'free', 'skip', 'moov', 'mpvd'};

// at the tail they are cut off, which moves nothing. anywhere else they are
// renamed to 'free' and zeroed in place, as mp4_strip does, so every offset
// in iloc still points where it did
Uint8List _dropForeign(Uint8List out, List<_Box> top, List<_Box> foreign) {
  if (foreign.isEmpty) return out;
  var cut = out.length;
  for (final b in top.reversed) {
    if (!foreign.contains(b)) break;
    cut = b.start;
  }
  for (final b in foreign) {
    if (b.start >= cut) continue;
    out.setRange(b.start + 4, b.start + 8, const [0x66, 0x72, 0x65, 0x65]);
    out.fillRange(b.body, b.end, 0);
  }
  return cut == out.length ? out : Uint8List.sublistView(out, 0, cut);
}
