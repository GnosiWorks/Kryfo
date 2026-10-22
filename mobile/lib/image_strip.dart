// SPDX-License-Identifier: GPL-3.0-or-later
// a picture sent as a file, cleaned like one sent as a photo. the photo lane
// re-encodes; the file lane sends the file as it is, so this cleaning is
// lossless and never touches the picture data. the kind comes from the
// first bytes, not the name:
//   jpeg   the app segments go (jpeg_strip.dart)
//   png    only the chunks a picture is drawn from are kept, whole, so no
//          crc has to be redone; an orientation goes back in alone
//   webp   only the chunks a picture is drawn from are kept; an orientation
//          goes back in alone and the VP8X flags say what is left
//   gif    comments go, and every application block but the loop ones
//   heif   heic and avif: only the items the picture is drawn from stay,
//          nothing moves (heif_clean.dart)
// true: read end to end and clean. false: not a kind known here, left alone.
// null: it claims to be one and could not be read through, and a caller
// drops a null rather than send what it could not vouch for.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'heif_clean.dart';
import 'jpeg_strip.dart';
import 'meta/tiff.dart';

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
  'mif2',
  'mif3',
  'msf1',
  'avif',
  'avis',
};

/// the first bytes of [raf], enough to tell a picture: 256, or the whole
/// ftyp box of an iso file up to 4 kb, since a heic can list its brand
/// past the first 256
Future<Uint8List> pictureHead(RandomAccessFile raf) async {
  await raf.setPosition(0);
  final h = await raf.read(256);
  if (h.length < 256 || _tag(h, 4) != 'ftyp') return h;
  final box = _u32(h, 0);
  if (box <= h.length) return h;
  await raf.setPosition(0);
  return raf.read(box < 4096 ? box : 4096);
}

/// the extension a picture's bytes call for; jpg for one not known here
String pictureExt(Uint8List b) => switch (pictureKind(b)) {
  PictureKind.png => 'png',
  PictureKind.gif => 'gif',
  PictureKind.webp => 'webp',
  PictureKind.heif => 'heic',
  _ => 'jpg',
};

/// cleans the file at [path] in place. see the contract at the top. the
/// first bytes are read before anything else, so a file that is not a
/// picture is never read whole. [readAll] stands in for the read in tests
Future<bool?> stripPictureFile(
  String path, {
  @visibleForTesting Future<Uint8List> Function(File f)? readAll,
}) async {
  final f = File(path);
  final raf = await f.open();
  final Uint8List head;
  try {
    head = await pictureHead(raf);
  } finally {
    await raf.close();
  }
  if (pictureKind(head) == PictureKind.other) return false;
  final src = await (readAll ?? (File f) => f.readAsBytes())(f);
  final out = stripPictureBytes(src);
  if (out == null) return null;
  if (identical(out, src)) return pictureKind(src) != PictureKind.other;
  await _writeOver(f, out, src.length);
  return true;
}

/// the same, off the ui thread: walking megabytes of scan data drops
/// frames. top level, so the isolate gets the path and nothing of the caller.
Future<bool?> stripPictureFileOffUi(String path) =>
    Isolate.run(() => stripPictureFile(path));

/// a photo as it may leave: cleaned, and a jpeg that still reads as tagged
/// is refused. every photo lane passes here, the gallery's above all: its
/// picker re-encodes and copies the tags across, and gives the original
/// back untouched when it cannot read the size. null: drop it.
Uint8List? photoToSend(Uint8List src) {
  final out = stripPictureBytes(src);
  if (out == null || jpegHasExif(out)) return null;
  return out;
}

/// the same, off the ui thread
Future<Uint8List?> photoToSendOffUi(Uint8List src) =>
    Isolate.run(() => photoToSend(src));

/// a saved photo made fit to go again, in place: a row left unsent by a
/// version that did not clean gallery photos still holds the tags on disk.
/// false when it was clean already, true when it was rewritten, null when it
/// cannot be cleaned and may not go.
Future<bool?> cleanSavedPhoto(String path) => Isolate.run(() async {
  final f = File(path);
  final Uint8List src;
  try {
    src = await f.readAsBytes();
  } catch (_) {
    return null;
  }
  final out = photoToSend(src);
  if (out == null) return null;
  if (_same(out, src)) return false;
  await _writeOver(f, out, src.length);
  return true;
});

// the clean bytes go over the old ones and the cut tail is zeroed before the
// file is shortened. best effort: f2fs and wear levelling can keep old blocks
Future<void> _writeOver(File f, Uint8List out, int was) async {
  // append keeps the blocks; a write mode would truncate first
  final raf = await f.open(mode: FileMode.append);
  try {
    await raf.setPosition(0);
    await raf.writeFrom(out);
    final zeros = Uint8List(64 * 1024);
    var left = was - out.length;
    while (left > 0) {
      final n = left < zeros.length ? left : zeros.length;
      await raf.writeFrom(zeros, 0, n);
      left -= n;
    }
    await raf.flush();
    if (was > out.length) await raf.truncate(out.length);
    await raf.flush();
  } finally {
    await raf.close();
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

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
      return cleanHeif(src);
    case PictureKind.gif:
      return _gif(src);
    case PictureKind.other:
      return src;
  }
}

String _tag(Uint8List b, int i) => latin1.decode(b.sublist(i, i + 4));
int _u32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
int _u32le(Uint8List b, int i) =>
    b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);

// ---- png ----

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
  final turn = _pngTurn(src);
  if (turn == null) return null;
  var i = 8;
  var dropped = false;
  var turned = turn == 1;
  while (true) {
    if (i + 12 > src.length) return null; // no IEND before the file ran out
    final len = _u32(src, i);
    final end = i + 12 + len;
    if (len > 0x7fffffff || end > src.length) return null;
    final type = _tag(src, i + 4);
    // the orientation goes before the picture data, where readers look
    if (!turned && (type == 'IDAT' || type == 'fdAT' || type == 'IEND')) {
      out.add(_pngChunk('eXIf', orientationTiff(turn)));
      turned = true;
    }
    if (_pngKeep.contains(type) ||
        (type == 'eXIf' && !turned && _isTurnOnly(src, i + 8, len, turn))) {
      out.add(src.sublist(i, end));
      if (type == 'eXIf') turned = true;
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

// the turn an eXIf chunk asks for, 1 when there is none. null when the
// chunks cannot be walked
int? _pngTurn(Uint8List src) {
  var i = 8;
  while (i + 12 <= src.length) {
    final len = _u32(src, i);
    final end = i + 12 + len;
    if (len > 0x7fffffff || end > src.length) return null;
    final type = _tag(src, i + 4);
    if (type == 'eXIf') {
      return readTiff(
            Uint8List.sublistView(src, i + 8, i + 8 + len),
          )?.orientation ??
          1;
    }
    if (type == 'IEND') return 1;
    i = end;
  }
  return null;
}

// true when [len] bytes at [at] are the orientation block this file wrote
bool _isTurnOnly(Uint8List src, int at, int len, int turn) {
  if (turn < 2 || turn > 8) return false;
  final want = orientationTiff(turn);
  if (len != want.length || at + len > src.length) return false;
  for (var k = 0; k < len; k++) {
    if (src[at + k] != want[k]) return false;
  }
  return true;
}

List<int> _pngChunk(String type, List<int> data) {
  final typed = [...latin1.encode(type), ...data];
  final crc = _crc32(typed);
  return [..._be32(data.length), ...typed, ..._be32(crc)];
}

List<int> _be32(int v) => [
  (v >> 24) & 255,
  (v >> 16) & 255,
  (v >> 8) & 255,
  v & 255,
];

final Uint32List _crcTable = () {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

// ---- webp ----

// the webp chunks a picture is drawn from, still or animated
const _webpKeep = {'VP8 ', 'VP8L', 'VP8X', 'ALPH', 'ANIM', 'ANMF', 'ICCP'};

Uint8List? _webp(Uint8List src) {
  final chunks = <Uint8List>[];
  var i = 12;
  var dropped = false;
  var turn = 1;
  var exifKept = false;
  if (src.length < 12) return null;
  final riffEnd = 8 + _u32le(src, 4);
  if (riffEnd > src.length) return null;
  while (i < riffEnd) {
    if (i + 8 > riffEnd) return null;
    final type = _tag(src, i);
    final len = _u32le(src, i + 4);
    final end = i + 8 + len + (len & 1); // chunks are padded to even
    if (end > riffEnd + 1 || i + 8 + len > src.length) return null;
    final stop = end > src.length ? src.length : end;
    if (type == 'EXIF' && turn == 1) {
      var tiff = Uint8List.sublistView(src, i + 8, i + 8 + len);
      // some writers put jpeg's "Exif\0\0" in front
      if (len > 6 && tiff[0] == 0x45 && tiff[1] == 0x78 && tiff[4] == 0) {
        tiff = Uint8List.sublistView(tiff, 6);
      }
      turn = readTiff(tiff)?.orientation ?? 1;
    }
    if (type == 'EXIF' && _isTurnOnly(src, i + 8, len, turn)) {
      // written here before: it stays where it is
      exifKept = true;
      chunks.add(Uint8List.fromList(src.sublist(i, stop)));
    } else if (!_webpKeep.contains(type)) {
      dropped = true;
    } else {
      chunks.add(Uint8List.fromList(src.sublist(i, stop)));
    }
    i = end;
  }
  // bytes after the riff are not the picture
  if (riffEnd + (riffEnd & 1) < src.length) dropped = true;
  // VP8X says up front which extras follow: bit 3 exif, bit 2 xmp. only
  // the exif one may stay, for an orientation written back alone
  final keepTurn = turn >= 2 && turn <= 8;
  for (final c in chunks) {
    if (_tag(c, 0) != 'VP8X' || c.length < 9) continue;
    final want = (c[8] & ~0x0C & 0xFF) | (keepTurn ? 0x08 : 0);
    if (want != c[8]) {
      c[8] = want;
      dropped = true;
    }
  }
  if (!dropped) return src;
  final body = BytesBuilder(copy: false);
  for (final c in chunks) {
    body.add(c);
    if (c.length & 1 == 1) body.add([0]);
  }
  if (keepTurn && !exifKept && chunks.any((c) => _tag(c, 0) == 'VP8X')) {
    final t = orientationTiff(turn);
    body.add([
      ...latin1.encode('EXIF'),
      t.length & 255,
      (t.length >> 8) & 255,
      0,
      0,
      ...t,
      if (t.length.isOdd) 0,
    ]);
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

// ---- gif ----

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
