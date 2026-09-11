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

Uint8List stripJpegMetadata(Uint8List src) {
  if (src.length < 4 || src[0] != 0xFF || src[1] != 0xD8) return src;
  final out = BytesBuilder(copy: false);
  out.add([0xFF, 0xD8]);
  var i = 2;
  while (i + 4 <= src.length) {
    if (src[i] != 0xFF) break; // not a segment start: hand the rest over
    final marker = src[i + 1];
    // padding bytes between segments
    if (marker == 0xFF) {
      i += 1;
      continue;
    }
    // start of scan: everything from here to the end is image data
    if (marker == 0xDA) {
      out.add(src.sublist(i));
      return out.toBytes();
    }
    // standalone markers carry no length
    if (marker == 0xD8 ||
        (marker >= 0xD0 && marker <= 0xD7) ||
        marker == 0x01) {
      out.add([0xFF, marker]);
      i += 2;
      continue;
    }
    final len = (src[i + 2] << 8) | src[i + 3];
    final end = i + 2 + len;
    if (len < 2 || end > src.length) break;
    if (_keeps(marker)) out.add(src.sublist(i, end));
    i = end;
  }
  out.add(src.sublist(i));
  return out.toBytes();
}

// true when an app1 (exif or xmp) segment is present, for the test and for
// the capture screen to check its own work
bool jpegHasExif(Uint8List src) {
  if (src.length < 4 || src[0] != 0xFF || src[1] != 0xD8) return false;
  var i = 2;
  while (i + 4 <= src.length && src[i] == 0xFF) {
    final marker = src[i + 1];
    if (marker == 0xDA) return false;
    if (marker == 0xE1) return true;
    final len = (src[i + 2] << 8) | src[i + 3];
    if (len < 2) return false;
    i += 2 + len;
  }
  return false;
}
