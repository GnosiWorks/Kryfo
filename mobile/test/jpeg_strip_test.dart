import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/jpeg_strip.dart';

import 'photo_crafted.dart';

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
  test('strips exif and comment, keeps picture data', () {
    final src = _sample();
    expect(jpegHasExif(src), isTrue);
    final out = stripJpegMetadata(src)!;
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
  test('padding before a segment does not hide exif', () {
    final src = _sample();
    // a legal fill byte between the app0 segment and the exif one
    final app0End = 2 + 2 + 16;
    final padded = Uint8List.fromList([
      ...src.sublist(0, app0End),
      0xFF,
      ...src.sublist(app0End),
    ]);
    expect(jpegHasExif(padded), isTrue);
    final out = stripJpegMetadata(padded)!;
    expect(jpegHasExif(out), isFalse);
    expect(String.fromCharCodes(out).contains('GPSLatitude'), isFalse);
  });
  test('refuses a broken segment length', () {
    final src = _sample();
    final broken = Uint8List.fromList(src);
    // the exif segment's length now points past the end of the file
    final exifAt = 2 + 2 + 16;
    broken[exifAt + 2] = 0xFF;
    broken[exifAt + 3] = 0xFF;
    expect(stripJpegMetadata(broken), isNull);
    expect(jpegHasExif(broken), isTrue);
  });

  test('exif behind ff 00, where a decoder reads on, is refused', () {
    final gps = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();
    var at = 2;
    while (gps[at + 1] != 0xE1) {
      at += 2 + (gps[at + 2] << 8 | gps[at + 3]);
    }
    expect(stripJpegMetadata(hiddenSegment(gps, at)), isNull);
    // the same between two scans, and fill there is no marker
    final src = _sample();
    final eoi = src.length - 2;
    final two = Uint8List.fromList([
      ...src.sublist(0, eoi),
      0xFF, 0xFE, 0, 4, 1, 2, 0xFF, 0xDA, 0, 8, 1, 1, 0, 0, 63, 0, 9, //
      0xFF, 0xD9,
    ]);
    expect(stripJpegMetadata(two), isNotNull);
    final exif = [0xFF, 0xE1, 0, 8, ...'Exif'.codeUnits, 0, 0];
    for (final (what, gap) in [
      ('ff 00', [0xFF, 0x00, 0, 2 + exif.length, ...exif]),
      ('a restart', [0xFF, 0xD0, ...exif]),
    ]) {
      final hid = Uint8List.fromList([
        ...src.sublist(0, eoi),
        0xFF, 0xFE, 0, 4, 1, 2, ...gap, 0xFF, 0xDA, 0, 8, 1, 1, 0, 0, 63, 0, //
        9, 0xFF, 0xD9,
      ]);
      expect(stripJpegMetadata(hid), isNull, reason: what);
    }
    final filled = Uint8List.fromList([
      ...src.sublist(0, eoi),
      0xFF, 0xFE, 0, 4, 1, 2, 0xFF, ...exif, 0xFF, 0xDA, 0, 8, 1, 1, 0, 0, //
      63, 0, 9, 0xFF, 0xD9,
    ]);
    expect(
      String.fromCharCodes(stripJpegMetadata(filled)!),
      isNot(contains('Exif')),
    );
  });

  group('where the picture ends', () {
    List<int> seg(int m, List<int> body) => [
      0xFF,
      m,
      ((body.length + 2) >> 8) & 255,
      (body.length + 2) & 255,
      ...body,
    ];
    final icc = [...'ICC_PROFILE'.codeUnits, 0, 1, 1, 9, 9];
    final mpf = [...'MPF'.codeUnits, 0, 7, 7, 7];
    Uint8List pic({List<int> tail = const [], bool eoi = true}) =>
        Uint8List.fromList([
          0xFF, 0xD8,
          ...seg(0xE2, icc),
          ...seg(0xE2, mpf),
          ...seg(0xDB, [1, 2, 3]),
          ...seg(0xDA, [0, 1]),
          5, 6, 0xFF, 0x00, 7, 0xFF, 0xD3, 8, // data, a stuffed ff, a restart
          ...seg(0xC4, [4, 4]), // a table between scans, as progressive has
          ...seg(0xFE, 'between scans'.codeUnits), // and a comment
          ...seg(0xDA, [0, 2]),
          9, 9, 9,
          if (eoi) ...[0xFF, 0xD9],
          ...tail,
        ]);
    String text(Uint8List b) => String.fromCharCodes(b);

    test('drops a trailer after the end marker', () {
      final out = stripJpegMetadata(
        pic(tail: 'SEFHsamsung trailer SEFT'.codeUnits),
      )!;
      expect(text(out).contains('samsung'), false);
      expect(out.sublist(out.length - 2), [0xFF, 0xD9]);
    });
    test('keeps both scans and the table between', () {
      final out = stripJpegMetadata(pic())!;
      expect(out.where((b) => b == 9).length >= 3, true);
      expect(text(out).contains('between scans'), false);
      // 5 6 ff00 7 ffd3 8 is there byte for byte
      final s = text(out);
      expect(
        s.contains(String.fromCharCodes([5, 6, 0xFF, 0, 7, 0xFF, 0xD3, 8])),
        true,
      );
    });
    test('keeps app2 only as a colour profile', () {
      final s = text(stripJpegMetadata(pic())!);
      expect(s.contains('ICC_PROFILE'), true);
      expect(s.contains('MPF'), false);
    });
    test('no end marker is null', () {
      expect(stripJpegMetadata(pic(eoi: false)), null);
    });
  });

  group('which way up', () {
    List<int> seg(int m, List<int> body) => [
      0xFF,
      m,
      ((body.length + 2) >> 8) & 255,
      (body.length + 2) & 255,
      ...body,
    ];
    // little-endian exif: orientation 6 and a camera model beside it
    final exif = [
      ...'Exif'.codeUnits,
      0,
      0,
      0x49,
      0x49,
      0x2A,
      0x00,
      0x08,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x10,
      0x01,
      0x02,
      0x00,
      0x08,
      0x00,
      0x00,
      0x00,
      0x26,
      0x00,
      0x00,
      0x00,
      0x12,
      0x01,
      0x03,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x06,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      ...'SM-A536B'.codeUnits,
    ];
    Uint8List pic(List<int> app1) => Uint8List.fromList([
      0xFF,
      0xD8,
      ...seg(0xE1, app1),
      ...seg(0xDA, [0, 1]),
      1,
      2,
      3,
      0xFF,
      0xD9,
    ]);
    test('keeps only the orientation', () {
      final out = stripJpegMetadata(pic(exif))!;
      final s = String.fromCharCodes(out);
      expect(s.contains('SM-A536B'), false);
      // our block: app1, 34 long, one entry, tag 0x0112, value 6
      expect(out.sublist(2, 6), [0xFF, 0xE1, 0x00, 0x22]);
      expect(out[31], 6);
      // and the check that follows a strip accepts it as clean
      expect(jpegHasExif(out), false);
      // stripping it again changes nothing
      expect(stripJpegMetadata(out), out);
    });
    test('upright gets no orientation block', () {
      final up = List<int>.from(exif)..[36] = 1;
      final out = stripJpegMetadata(pic(up))!;
      expect(out.sublist(2, 4), [0xFF, 0xDA]);
    });
    test('drops an unreadable exif', () {
      final out = stripJpegMetadata(
        pic([...'Exif'.codeUnits, 0, 0, 9, 9, 9, 9, 9, 9, 9, 9]),
      )!;
      expect(out.sublist(2, 4), [0xFF, 0xDA]);
    });
  });

  group('app0 and app14', () {
    List<int> seg(int m, List<int> body) => [
      0xFF,
      m,
      (body.length + 2) >> 8,
      (body.length + 2) & 0xFF,
      ...body,
    ];
    Uint8List pic(List<int> head) => Uint8List.fromList([
      0xFF,
      0xD8,
      ...head,
      ...seg(0xDB, List.filled(65, 3)),
      ...seg(0xDA, [1, 1, 0, 0, 63, 0]),
      0x12,
      0xFF,
      0xD9,
    ]);
    // jfif 1.02, dots per inch, 72 by 72, then a 2 by 1 thumbnail
    final jfif = seg(0xE0, [
      ...'JFIF\x00'.codeUnits,
      1, 2, 1, 0, 72, 0, 72, 2, 1, //
      ...List.filled(6, 0xAB),
    ]);

    test('jfif loses its thumbnail and keeps its density', () {
      final out = stripJpegMetadata(pic(jfif))!;
      expect(out.sublist(2, 20), [
        0xFF, 0xE0, 0x00, 0x10, ...'JFIF\x00'.codeUnits, //
        1, 2, 1, 0, 72, 0, 72, 0, 0,
      ]);
      expect(out.contains(0xAB), isFalse);
    });

    test('a jfxx thumbnail segment goes', () {
      final jfxx = seg(0xE0, [
        ...'JFXX\x00'.codeUnits,
        0x10,
        0xFF,
        0xD8,
        0xAB,
        0xFF,
        0xD9,
      ]);
      final out = stripJpegMetadata(pic([...jfif, ...jfxx]))!;
      expect(String.fromCharCodes(out).contains('JFXX'), isFalse);
      expect(out.contains(0xAB), isFalse);
    });

    test('adobe app14 stays with its colour transform', () {
      final adobe = seg(0xEE, [...'Adobe'.codeUnits, 0, 100, 0x80, 0, 0, 0, 2]);
      final out = stripJpegMetadata(pic(adobe))!;
      final at = out.indexOf(0xEE) - 1;
      expect(out.sublist(at, at + 16), [
        0xFF, 0xEE, 0x00, 0x0E, ...'Adobe'.codeUnits, //
        0, 100, 0, 0, 0, 0, 2,
      ]);
    });

    test('the orientation follows the jfif header', () {
      final exif = seg(0xE1, [
        ...'Exif\x00\x00'.codeUnits,
        0x4D, 0x4D, 0, 0x2A, 0, 0, 0, 8, 0, 1, //
        0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, 6, 0, 0,
        0, 0, 0, 0,
      ]);
      final out = stripJpegMetadata(pic([...jfif, ...exif]))!;
      expect(out.sublist(2, 4), [0xFF, 0xE0]);
      expect(out.sublist(20, 22), [0xFF, 0xE1]);
    });
  });
}
