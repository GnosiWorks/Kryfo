// SPDX-License-Identifier: GPL-3.0-or-later
// strip a jpeg of everything that is not the picture. exif (with its gps,
// device model and timestamp), xmp, comments and the maker notes all live
// in application segments between the start marker and the image data;
// dropping them leaves the pixels untouched. pure dart, no dependency, so
// the offline and f-droid builds stay as they are.
import 'dart:typed_data';

// segments kept: the picture itself and what decoding needs. app0 (jfif)
// and app2 (the colour profile) carry no identifying data and keep colours
// right, so they stay. app1 (exif, xmp), app3 to app15 and com go.
bool _keeps(int marker) {
  if (marker == 0xE0 || marker == 0xE2) return true; // jfif, icc
  if (marker >= 0xE1 && marker <= 0xEF) return false; // exif, xmp, maker
  if (marker == 0xFE) return false; // comment
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
    // start of scan: everything from here to the end is image data
    if (marker == 0xDA) {
      out?.add(src.sublist(i));
      return true;
    }
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

// the stripped file, or null when the file could not be walked to its scan
// data. a caller drops a null rather than passing on what it cannot read.
// something that is not a jpeg comes back as it was.
Uint8List? stripJpegMetadata(Uint8List src) {
  if (src.length < 4 || src[0] != 0xFF || src[1] != 0xD8) return src;
  final out = BytesBuilder(copy: false);
  out.add([0xFF, 0xD8]);
  final ok = _walk(src, out, (marker, _, _) => _keeps(marker));
  return ok ? out.toBytes() : null;
}

// true when an app1 (exif or xmp) segment is present, or when the file
// cannot be walked, so an unreadable file never reads as clean
bool jpegHasExif(Uint8List src) {
  if (src.length < 4 || src[0] != 0xFF || src[1] != 0xD8) return false;
  var found = false;
  final ok = _walk(src, null, (marker, _, _) {
    if (marker == 0xE1) found = true;
    return false;
  });
  return found || !ok;
}
