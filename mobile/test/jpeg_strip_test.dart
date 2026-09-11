import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/jpeg_strip.dart';

// a tiny synthetic jpeg: SOI, APP0, APP1 (exif with a fake gps tag), COM,
// DQT, SOS with some scan bytes, EOI
Uint8List _sample() {
  List<int> seg(int marker, List<int> body) => [
    0xFF,
    marker,
    (body.length + 2) >> 8,
    (body.length + 2) & 0xFF,
    ...body,
  ];
  return Uint8List.fromList([
    0xFF,
    0xD8,
    ...seg(0xE0, 'JFIF\x00'.codeUnits + [1, 1, 0, 0, 1, 0, 1, 0, 0]),
    ...seg(0xE1, 'Exif\x00\x00GPSLatitude=52.52'.codeUnits),
    ...seg(0xFE, 'shot on a phone'.codeUnits),
    ...seg(0xDB, List.filled(65, 3)),
    ...seg(0xDA, [1, 1, 0, 0, 63, 0]),
    0x12,
    0x34,
    0xFF,
    0x00,
    0x56,
    0xFF,
    0xD9,
  ]);
}

void main() {
  test('exif and comment go, picture data stays', () {
    final src = _sample();
    expect(jpegHasExif(src), isTrue);
    final out = stripJpegMetadata(src);
    expect(jpegHasExif(out), isFalse);
    final text = String.fromCharCodes(out);
    expect(text.contains('GPSLatitude'), isFalse);
    expect(text.contains('shot on a phone'), isFalse);
    expect(text.contains('JFIF'), isTrue);
    // scan data and the end marker survive byte for byte
    expect(out.sublist(out.length - 7), [
      0x12,
      0x34,
      0xFF,
      0x00,
      0x56,
      0xFF,
      0xD9,
    ]);
    expect(out.length < src.length, isTrue);
  });
  test('not a jpeg passes through untouched', () {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
    expect(stripJpegMetadata(png), png);
  });
}
