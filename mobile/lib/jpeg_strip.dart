// SPDX-License-Identifier: GPL-3.0-or-later
// strip a jpeg of everything that is not the picture. exif (with its gps,
// device model and timestamp), xmp, comments and the maker notes all live
// in application segments between the start marker and the image data;
// dropping them leaves the pixels untouched. pure dart, no dependency, so
// the offline and f-droid builds stay as they are.
import 'dart:typed_data';

// segments kept: the picture itself and what decoding needs. app0 (jfif)
// and the colour profile carry no identifying data and keep colours right,
// so they stay. app1 (exif, xmp), app3 to app15 and com go. app2 is kept
// only when it is a colour profile: the same marker carries the
// multi-picture index phones use to hang a second image off the first.
bool _keeps(int marker, Uint8List src, int start, int end) {
  if (marker == 0xE0) return true; // jfif
  if (marker == 0xE2) return _isIcc(src, start, end);
  if (marker >= 0xE1 && marker <= 0xEF) return false; // exif, xmp, maker
  if (marker == 0xFE) return false; // comment
  return true;
}

const _icc = [73, 67, 67, 95, 80, 82, 79, 70, 73, 76, 69, 0]; // ICC_PROFILE\0
bool _isIcc(Uint8List src, int start, int end) {
  if (start + 4 + _icc.length > end) return false;
  for (var k = 0; k < _icc.length; k++) {
    if (src[start + 4 + k] != _icc[k]) return false;
  }
  return true;
}

// walks the segments before the scan. [keep] is asked about each one and
// gets the bytes it wants copied. returns false when a length field points
// past the file or under its own header, which is a file we cannot vouch
// for, so both callers treat that as failure rather than guessing
bool _walk(
  Uint8List src,
  BytesBuilder? out,
  bool Function(int marker, int start, int end) keep,
) {
  var i = 2;
  while (i + 4 <= src.length) {
    if (src[i] != 0xFF) return false; // not a segment start
    final marker = src[i + 1];
    // padding bytes between segments
    if (marker == 0xFF) {
      i += 1;
      continue;
    }
    // start of scan. the picture runs from here to its end marker and not
    // a byte further: "to the end of the file" took along whatever a phone
    // had hung after the picture, and a samsung camera hangs a trailer of
    // its own there, and some hang a whole second image.
    if (marker == 0xDA) return _scan(src, i, out, keep);
    // standalone markers carry no length
    if (marker == 0xD8 ||
        (marker >= 0xD0 && marker <= 0xD7) ||
        marker == 0x01) {
      out?.add([0xFF, marker]);
      i += 2;
      continue;
    }
    final len = (src[i + 2] << 8) | src[i + 3];
    final end = i + 2 + len;
    if (len < 2 || end > src.length) return false;
    if (keep(marker, i, end)) out?.add(src.sublist(i, end));
    i = end;
  }
  return false; // ran out before any scan data
}

// walks scan data to the end-of-image marker. inside a scan an 0xFF is
// data when a zero follows it, a restart marker when d0-d7 does, and fill
// when another 0xFF does. anything else is a real marker: the end, or in a
// progressive file a table or the next scan, which is asked about like any
// other segment. false when the file runs out before the end marker.
bool _scan(
  Uint8List src,
  int sos,
  BytesBuilder? out,
  bool Function(int marker, int start, int end) keep,
) {
  var i = sos;
  while (true) {
    // the scan header, a segment like any other
    if (i + 4 > src.length) return false;
    final hl = (src[i + 2] << 8) | src[i + 3];
    var j = i + 2 + hl;
    if (hl < 2 || j > src.length) return false;
    // entropy-coded data up to the next real marker
    while (true) {
      final f = src.indexOf(0xFF, j);
      if (f < 0 || f + 1 >= src.length) return false;
      final m = src[f + 1];
      if (m == 0x00 || (m >= 0xD0 && m <= 0xD7)) {
        j = f + 2;
      } else if (m == 0xFF) {
        j = f + 1;
      } else {
        j = f;
        break;
      }
    }
    out?.add(Uint8List.sublistView(src, i, j));
    // segments between scans, until the next scan or the end
    while (true) {
      if (j + 2 > src.length) return false;
      final m = src[j + 1];
      if (m == 0xD9) {
        out?.add(const [0xFF, 0xD9]);
        return true;
      }
      if (m == 0xDA) break;
      if (j + 4 > src.length) return false;
      final len = (src[j + 2] << 8) | src[j + 3];
      final end = j + 2 + len;
      if (len < 2 || end > src.length) return false;
      if (keep(m, j, end)) out?.add(Uint8List.sublistView(src, j, end));
      j = end;
      if (j + 1 >= src.length || src[j] != 0xFF) return false;
    }
    i = j;
  }
}

// the stripped file, or null when the file could not be walked to its scan
// data. a caller drops a null rather than passing on what it cannot read.
// something that is not a jpeg comes back as it was.
Uint8List? stripJpegMetadata(Uint8List src) {
  if (src.length < 4 || src[0] != 0xFF || src[1] != 0xD8) return src;
  final out = BytesBuilder(copy: false);
  out.add([0xFF, 0xD8]);
  // which way up is the one thing in the exif the picture needs: a phone
  // held upright saves a sideways image and a note to turn it. without the
  // note every portrait photo arrives on its side. it goes back in alone,
  // in an exif block built here that holds that one tag and nothing else.
  var turn = 1;
  final seen = _walk(src, null, (marker, a, b) {
    if (marker == 0xE1 && turn == 1) turn = _orientation(src, a, b);
    return false;
  });
  if (!seen) return null;
  if (turn >= 2 && turn <= 8) out.add(_orientationOnly(turn));
  final ok = _walk(src, out, (marker, a, b) => _keeps(marker, src, a, b));
  return ok ? out.toBytes() : null;
}

// the orientation tag (0x0112) out of an app1 exif segment, 1 when there is
// none or the block cannot be read. only ifd0 is looked at; that is where
// it lives.
int _orientation(Uint8List src, int start, int end) {
  var p = start + 4;
  const head = [0x45, 0x78, 0x69, 0x66, 0, 0]; // Exif\0\0
  if (p + 6 + 8 > end) return 1;
  for (var k = 0; k < 6; k++) {
    if (src[p + k] != head[k]) return 1;
  }
  p += 6; // the tiff header; offsets count from here
  final le = src[p] == 0x49 && src[p + 1] == 0x49;
  if (!le && !(src[p] == 0x4D && src[p + 1] == 0x4D)) return 1;
  int u16(int i) =>
      le ? src[i] | (src[i + 1] << 8) : (src[i] << 8) | src[i + 1];
  int u32(int i) => le
      ? src[i] | (src[i + 1] << 8) | (src[i + 2] << 16) | (src[i + 3] << 24)
      : (src[i] << 24) | (src[i + 1] << 16) | (src[i + 2] << 8) | src[i + 3];
  final ifd = p + u32(p + 4);
  if (ifd < p || ifd + 2 > end) return 1;
  final n = u16(ifd);
  for (var k = 0; k < n; k++) {
    final e = ifd + 2 + k * 12;
    if (e + 12 > end) return 1;
    if (u16(e) == 0x0112) {
      final v = u16(e + 8);
      return v >= 1 && v <= 8 ? v : 1;
    }
  }
  return 1;
}

// the block below and nothing else: what the check that follows a strip
// lets through
bool _isOrientationOnly(Uint8List src, int start, int end) {
  if (end - start != 36) return false;
  final want = _orientationOnly(src[start + 29]);
  for (var k = 0; k < 36; k++) {
    if (src[start + k] != want[k]) return false;
  }
  return true;
}

// app1, "Exif", a big-endian tiff with one ifd holding one entry
Uint8List _orientationOnly(int turn) => Uint8List.fromList([
  0xFF, 0xE1, 0x00, 0x22, // 34 bytes follow the marker, the length included
  0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
  0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,
  0x00, 0x01, // one entry
  0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, turn, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, // no next ifd
]);

// true when an app1 (exif or xmp) segment is present, or when the file
// cannot be walked, so an unreadable file never reads as clean
bool jpegHasExif(Uint8List src) {
  if (src.length < 4 || src[0] != 0xFF || src[1] != 0xD8) return false;
  var found = false;
  final ok = _walk(src, null, (marker, a, b) {
    if (marker == 0xE1 && !_isOrientationOnly(src, a, b)) found = true;
    return false;
  });
  return found || !ok;
}
