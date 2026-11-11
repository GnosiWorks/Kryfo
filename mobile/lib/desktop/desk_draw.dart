// SPDX-License-Identifier: GPL-3.0-or-later
// a computer's way to draw a picture again as a jpeg, as the phone's platform
// call does: pure dart (the image package, mit), so nothing native is added.
// a camera's raw file goes as the largest finished jpeg it carries (most
// cameras keep one full size beside the sensor data), turned as the file
// says; a tiff and anything else the image package reads is decoded whole.
// heic and avif need a native decoder and are not drawn here
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// a raw file's own jpeg must be at least this on its long edge to stand
/// in for the picture: a small thumbnail is no picture to send
const kRawPreviewLeast = 1200;

/// [b] drawn again as a jpeg, upright, [maxEdge] on the long edge at most,
/// with no metadata of any kind. null when it cannot be drawn here
Uint8List? deskDrawJpeg(Uint8List b, {int maxEdge = 4096, int quality = 90}) {
  img.Image? picture;
  try {
    picture = _decode(b);
  } catch (_) {
    picture = null;
  }
  if (picture == null || picture.width < 1 || picture.height < 1) return null;
  final long = math.max(picture.width, picture.height);
  if (long > maxEdge) {
    picture = img.copyResize(
      picture,
      width: picture.width >= picture.height ? maxEdge : null,
      height: picture.width >= picture.height ? null : maxEdge,
      interpolation: img.Interpolation.average,
    );
  }
  // the pixels only: no exif, no colour profile, no text
  picture
    ..exif = img.ExifData()
    ..iccProfile = null
    ..textData = null;
  if (picture.hasPalette ||
      picture.numChannels != 3 ||
      picture.bitsPerChannel != 8) {
    picture = picture.convert(
      format: img.Format.uint8,
      numChannels: 3,
      alpha: 255,
    );
    picture
      ..exif = img.ExifData()
      ..iccProfile = null
      ..textData = null;
  }
  return img.encodeJpg(picture, quality: quality);
}

img.Image? _decode(Uint8List b) {
  final tiffLike = _tiffOrder(b) != null;
  final raw = tiffLike || _isRaf(b) || _isCr3(b);
  if (raw) {
    final preview = largestJpeg(b, least: kRawPreviewLeast);
    if (preview != null) {
      final p = img.decodeJpg(preview);
      if (p != null) return _upright(p, rawOrientation(b));
    }
    // a plain tiff, or a raw with no jpeg big enough
    if (!tiffLike) return null;
    final t = img.decodeTiff(b);
    if (t == null) return null;
    return _upright(t, rawOrientation(b));
  }
  final p = img.decodeImage(b);
  if (p == null) return null;
  return _upright(p, null);
}

// turned as [orientation] says (1 to 8), else as the picture's own exif
img.Image _upright(img.Image p, int? orientation) {
  if (orientation != null && orientation >= 1 && orientation <= 8) {
    p.exif = img.ExifData();
    p.exif.imageIfd.orientation = orientation;
  }
  return img.bakeOrientation(p);
}

bool _isRaf(Uint8List b) => _ascii(b, 0, 'FUJIFILMCCD-RAW');

bool _isCr3(Uint8List b) =>
    b.length > 12 && _ascii(b, 4, 'ftyp') && _ascii(b, 8, 'crx ');

bool _ascii(Uint8List b, int at, String s) {
  if (at + s.length > b.length) return false;
  for (var i = 0; i < s.length; i++) {
    if (b[at + i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

// little or big endian for a tiff header, as cameras write them: II*, MM*,
// olympus' IIRO/IIRS and panasonic's IIU
Endian? _tiffOrder(Uint8List b) {
  if (b.length < 8) return null;
  if (b[0] == 0x49 && b[1] == 0x49) {
    final m = b[2] | b[3] << 8;
    if (m == 0x2A || m == 0x4F52 || m == 0x5352 || m == 0x55) {
      return Endian.little;
    }
  }
  if (b[0] == 0x4D && b[1] == 0x4D && b[2] == 0 && b[3] == 0x2A) {
    return Endian.big;
  }
  return null;
}

/// the orientation a raw file's first directory gives (canon's cr3 keeps
/// it in its CMT1 box), or null
int? rawOrientation(Uint8List b) {
  if (_tiffOrder(b) != null) return _ifd0Orientation(b, 0);
  if (_isCr3(b)) {
    final at = _find(b, 'CMT1', 0, math.min(b.length, 1 << 20));
    if (at >= 0 && at + 12 < b.length) return _ifd0Orientation(b, at + 4);
  }
  return null;
}

int? _ifd0Orientation(Uint8List b, int base) {
  try {
    final head = Uint8List.sublistView(b, base);
    final order = _tiffOrder(head);
    if (order == null) return null;
    final d = ByteData.sublistView(head);
    final ifd = d.getUint32(4, order);
    if (ifd + 2 > head.length) return null;
    final n = d.getUint16(ifd, order);
    for (var i = 0; i < n && i < 512; i++) {
      final e = ifd + 2 + i * 12;
      if (e + 12 > head.length) return null;
      if (d.getUint16(e, order) == 0x0112) {
        final v = d.getUint16(e + 8, order);
        return v >= 1 && v <= 8 ? v : null;
      }
    }
  } catch (_) {}
  return null;
}

int _find(Uint8List b, String s, int from, int to) {
  final first = s.codeUnitAt(0);
  for (var i = from; i + s.length <= to; i++) {
    if (b[i] == first && _ascii(b, i, s)) return i;
  }
  return -1;
}

/// the largest baseline or progressive jpeg inside [b], at least [least]
/// on its long edge, as its own bytes. the lossless jpeg some cameras keep
/// their sensor data in is no picture and is passed over
Uint8List? largestJpeg(Uint8List b, {int least = 0}) {
  ({int start, int end, int area})? best;
  var i = 0;
  while (i + 4 < b.length) {
    if (b[i] != 0xFF || b[i + 1] != 0xD8 || b[i + 2] != 0xFF) {
      i++;
      continue;
    }
    final j = _jpegAt(b, i);
    if (j == null) {
      i++;
      continue;
    }
    if (math.max(j.w, j.h) >= least &&
        (best == null || j.w * j.h > best.area)) {
      best = (start: i, end: j.end, area: j.w * j.h);
    }
    // what lies inside it, a thumbnail in its exif, is smaller
    i = j.end;
  }
  if (best == null) return null;
  return Uint8List.fromList(Uint8List.sublistView(b, best.start, best.end));
}

// the jpeg starting at [s]: where it ends and its size, or null when it is
// none that can be drawn
({int end, int w, int h})? _jpegAt(Uint8List b, int s) {
  final n = b.length;
  var p = s + 2;
  int? w, h;
  while (p + 2 <= n) {
    if (b[p] != 0xFF) return null;
    while (p < n && b[p] == 0xFF) {
      p++;
    }
    if (p >= n) return null;
    final m = b[p++];
    if (m == 0xD9) {
      if (w == null || h == null || w == 0 || h == 0) return null;
      return (end: p, w: w, h: h);
    }
    if (m == 0x01 || (m >= 0xD0 && m <= 0xD7)) continue;
    if (p + 2 > n) return null;
    final len = b[p] << 8 | b[p + 1];
    if (len < 2 || p + len > n) return null;
    // baseline, extended and progressive huffman only
    if (m == 0xC0 || m == 0xC1 || m == 0xC2) {
      if (len < 7) return null;
      h = b[p + 3] << 8 | b[p + 4];
      w = b[p + 5] << 8 | b[p + 6];
    } else if (m >= 0xC3 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) {
      return null;
    }
    p += len;
    if (m == 0xDA) {
      // the entropy coded data runs to the next marker that is not a
      // stuffed byte or a restart
      while (p + 1 < n) {
        if (b[p] == 0xFF) {
          final x = b[p + 1];
          if (x == 0 || (x >= 0xD0 && x <= 0xD7) || x == 0xFF) {
            p += x == 0xFF ? 1 : 2;
            continue;
          }
          break;
        }
        p++;
      }
    }
  }
  return null;
}
