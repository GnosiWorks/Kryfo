// SPDX-License-Identifier: GPL-3.0-or-later
// a qr code read from a picture: found in a screenshot and in a photo that
// is big, turned and grainy, nothing in a picture without one, nothing
// from bytes that are no picture, and no huge picture is drawn at all.
// the reads need zxing built for this computer (LD_LIBRARY_PATH to
// libflutter_zxing.so); without it those cases skip.
import 'dart:ffi';
import 'dart:io' show ZLibEncoder;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as img;
import 'package:kryfo/qr_picture.dart';

bool get _reader {
  try {
    DynamicLibrary.open('libflutter_zxing.so');
    return true;
  } catch (_) {
    return false;
  }
}

const _link = 'kryfo://add/k1?n=Mira&v=4&d=OBNXk2c2Fj0Lw1mZ8Vt3QpR7yHs9';

// the code as zxing draws it, grey on a white margin
img.Image _code(int side) {
  final e = zx.encodeBarcode(
    contents: _link,
    params: EncodeParams(width: side, height: side, margin: 16),
  );
  final grey = e.data!;
  final out = img.Image(width: side, height: side);
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final v = grey[y * side + x];
      out.setPixelRgb(x, y, v, v, v);
    }
  }
  return out;
}

// a dim, grainy desk 4000 x 3000 with the code small, turned and off centre
img.Image _photo() {
  final r = math.Random(7);
  final desk = img.Image(width: 4000, height: 3000);
  img.fill(desk, color: img.ColorRgb8(70, 58, 44));
  final code = img.copyRotate(_code(600), angle: 23);
  img.compositeImage(desk, code, dstX: 2500, dstY: 1700);
  for (final p in desk) {
    final n = r.nextInt(31) - 15;
    p
      ..r = (p.r + n).clamp(0, 255)
      ..g = (p.g + n).clamp(0, 255)
      ..b = (p.b + n).clamp(0, 255);
  }
  return desk;
}

void main() {
  final skip = _reader ? null : 'no zxing for this computer';

  test('a screenshot of a code reads', () async {
    final shot = img.Image(width: 1080, height: 2340);
    img.fill(shot, color: img.ColorRgb8(13, 11, 9));
    img.compositeImage(shot, _code(720), dstX: 180, dstY: 600);
    expect(await readQrPicture(img.encodePng(shot)), _link);
  }, skip: skip);

  test('a big photo, turned and grainy, reads', () async {
    final jpg = img.encodeJpg(_photo(), quality: 85);
    expect(await readQrPicture(jpg), _link);
  }, skip: skip);

  test('a picture with no code reads as none', () async {
    final r = math.Random(3);
    final pic = img.Image(width: 1200, height: 900);
    for (final p in pic) {
      p
        ..r = r.nextInt(256)
        ..g = r.nextInt(256)
        ..b = r.nextInt(256);
    }
    expect(await readQrPicture(img.encodePng(pic)), isNull);
  }, skip: skip);

  test('bytes that are no picture read as none', () async {
    expect(await readQrPicture(Uint8List(0)), isNull);
    expect(
      await readQrPicture(Uint8List.fromList(List.generate(4096, (i) => i))),
      isNull,
    );
  });

  test('a picture past the pixel cap is not drawn', () async {
    // a real png header claiming 20000 x 20000, the rest cut off
    final png = img.encodePng(img.Image(width: 8, height: 8));
    final head = Uint8List.fromList(png.sublist(0, 33));
    final v = ByteData.sublistView(head);
    v.setUint32(16, 20000);
    v.setUint32(20, 20000);
    expect(await readQrPicture(head), isNull);
  });

  test('only the formats a gallery holds are drawn', () {
    final pic = img.Image(width: 8, height: 8);
    for (final ok in [
      img.encodeJpg(pic),
      img.encodePng(pic),
      img.encodeGif(pic),
      img.encodeBmp(pic),
    ]) {
      expect(qrPictureDecoder(ok), isNotNull);
    }
    // an ico holds a png of any size behind a <= 256 px directory: never
    for (final no in [
      img.encodeIco(pic),
      img.encodeTiff(pic),
      img.encodeTga(pic),
      img.encodePvr(pic),
    ]) {
      expect(qrPictureDecoder(no), isNull);
    }
  });

  test('a png whose data inflates past its size is not drawn', () {
    final png = img.encodePng(img.Image(width: 100, height: 100));
    expect(pngDataFits(png), isTrue);
    // the same 100 x 100 header, its data 16 MB of deflated zeros
    final zeros = ZLibEncoder().convert(Uint8List(16 << 20));
    final head = png.sublist(0, 33);
    final len = ByteData(4)..setUint32(0, zeros.length);
    final kind = 'IDAT'.codeUnits;
    final bomb = Uint8List.fromList([
      ...head,
      ...len.buffer.asUint8List(),
      ...kind,
      ...zeros,
      // the crc is not what stops it
      0, 0, 0, 0,
      0, 0, 0, 0, ...'IEND'.codeUnits, 0xae, 0x42, 0x60, 0x82,
    ]);
    expect(zeros.length, lessThan(64 * 1024));
    expect(pngDataFits(bomb), isFalse);
  });

  test('an animated webp is left to the phone', () {
    // riff, a vp8x canvas of 100 x 100 with the animation flag, an anim
    // chunk: its frames would be drawn at their own size
    final body = <int>[
      ...'WEBP'.codeUnits,
      ...'VP8X'.codeUnits,
      10,
      0,
      0,
      0,
      0x02,
      0,
      0,
      0,
      99,
      0,
      0,
      99,
      0,
      0,
      ...'ANIM'.codeUnits,
      6,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ];
    final webp = Uint8List.fromList([
      ...'RIFF'.codeUnits,
      body.length,
      0,
      0,
      0,
      ...body,
    ]);
    expect(qrPictureDecoder(webp), isA<img.WebPDecoder>());
    expect(readQrPictureHere(webp), qrNotDrawn);
  });
}
