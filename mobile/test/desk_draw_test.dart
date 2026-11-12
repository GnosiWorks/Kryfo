// SPDX-License-Identifier: GPL-3.0-or-later
// a computer draws pictures again in dart: a phone photo with its gps, a
// tiff, and cameras' raw files come out as clean upright jpegs. raw files
// are real cameras' (KRYFO_CORPUS/cleaner-corpus/public/raw, cc0 from
// raw.pixls.us); heic and avif need a native decoder and stay as they are
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kryfo/clean_media.dart';
import 'package:kryfo/desktop/desk_draw.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/image_strip.dart';
import 'package:kryfo/jpeg_strip.dart' show jpegHasExif;
import 'package:kryfo/meta/byte_source.dart' show MemorySource;
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/picture_convert.dart' show deskDrawKilled, deskDrawLimit;
import 'package:kryfo/tools/cleaner.dart' show readFile;
import 'package:path/path.dart' as p;

final _root = Platform.environment['KRYFO_CORPUS'];
final _noCorpus = _root == null ? 'needs KRYFO_CORPUS' : null;
String _corpus(String rel) => p.join(_root ?? '', 'cleaner-corpus', rel);

// what reads in [b]: nothing beside the picture
MetaStatus _reads(Uint8List b) => readMetaStrict(MemorySource(b)).status;

void _clean(Uint8List out) {
  expect(pictureKind(out), PictureKind.jpeg);
  expect(jpegHasExif(out), isFalse);
  expect(_reads(out), MetaStatus.nothing);
}

// a tiny baseline jpeg of [w] x [h]
Uint8List _smallJpeg(int w, int h) =>
    img.encodeJpg(img.Image(width: w, height: h), quality: 50);

// a tiff of one 16 x 16 grey strip, deflated: [z] is its strip
Uint8List _deflateTiff(List<int> z) {
  final ifd = <List<int>>[
    [256, 3, 1, 16],
    [257, 3, 1, 16],
    [258, 3, 1, 8],
    [259, 3, 1, 8],
    [262, 3, 1, 1],
    [273, 4, 1, 8 + 2 + 10 * 12 + 4],
    [277, 3, 1, 1],
    [278, 3, 1, 16],
    [279, 4, 1, z.length],
    [284, 3, 1, 1],
  ];
  final d = ByteData(8 + 2 + ifd.length * 12 + 4);
  d.setUint8(0, 0x49);
  d.setUint8(1, 0x49);
  d.setUint16(2, 42, Endian.little);
  d.setUint32(4, 8, Endian.little);
  d.setUint16(8, ifd.length, Endian.little);
  for (var i = 0; i < ifd.length; i++) {
    final e = ifd[i], at = 10 + i * 12;
    d.setUint16(at, e[0], Endian.little);
    d.setUint16(at + 2, e[1], Endian.little);
    d.setUint32(at + 4, e[2], Endian.little);
    if (e[1] == 3) {
      d.setUint16(at + 8, e[3], Endian.little);
    } else {
      d.setUint32(at + 8, e[3], Endian.little);
    }
  }
  return Uint8List.fromList([...d.buffer.asUint8List(), ...z]);
}

// a png of [w] x [h] grey whose image data is [z]
Uint8List _png(int w, int h, List<int> z) {
  List<int> chunk(String t, List<int> body) {
    final d = ByteData(4)..setUint32(0, body.length);
    return [...d.buffer.asUint8List(), ...t.codeUnits, ...body, 0, 0, 0, 0];
  }

  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8)
    ..setUint8(9, 0);
  return Uint8List.fromList([
    0x89, ...'PNG'.codeUnits, 13, 10, 26, 10, //
    ...chunk('IHDR', ihdr.buffer.asUint8List()),
    ...chunk('IDAT', z),
    ...chunk('IEND', const []),
  ]);
}

// a drawing that never ends, for the kill
Uint8List? _forever(Uint8List b) {
  var x = 0;
  while (true) {
    x = (x + b.length) & 0xFFFF;
  }
}

Uint8List? _quick(Uint8List b) => Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]);

void main() {
  group('a stranger\'s file', () {
    test('a header that says too many pixels is never decoded', () {
      // sof0 saying 20000 x 20000, and hardly anything behind it
      final huge = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xC0, 0, 11, 8, 0x4E, 0x20, 0x4E, 0x20, 1, 1, 0x11, 0,
        0xFF, 0xDA, 0, 8, 1, 1, 0, 0, 0x3F, 0, 1, 2, 3, 0xFF, 0xD9, //
      ]);
      final sw = Stopwatch()..start();
      expect(deskDrawJpeg(huge), isNull);
      expect(largestJpeg(huge), isNull);
      expect(pngFits(_png(20000, 20000, const [])), isFalse);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      // a raw whose biggest jpeg lies about its size gives the honest one
      final small = img.encodeJpg(img.Image(width: 1300, height: 1000));
      final raw = Uint8List.fromList([
        ...'II*'.codeUnits, 0, 8, 0, 0, 0, 0, 0, ...huge, ...small, //
      ]);
      expect(largestJpeg(raw, least: 1200), small);
    });

    test('a deflate bomb in a png or a tiff is stopped before decoding', () {
      final bomb = ZLibEncoder().convert(Uint8List(64 << 20));
      expect(bomb.length, lessThan(1 << 20));
      final sw = Stopwatch()..start();
      expect(pngFits(_png(64, 64, bomb)), isFalse);
      expect(deskDrawJpeg(_png(64, 64, bomb)), isNull);
      expect(tiffFits(_deflateTiff(bomb)), isFalse);
      expect(deskDrawJpeg(_deflateTiff(bomb)), isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      // the same, honest, goes through
      final rows = Uint8List(16 * 16);
      expect(tiffFits(_deflateTiff(ZLibEncoder().convert(rows))), isTrue);
      expect(
        deskDrawJpeg(_deflateTiff(ZLibEncoder().convert(rows))),
        isNotNull,
      );
      final png = img.encodePng(img.Image(width: 64, height: 64));
      expect(pngFits(png), isTrue);
      expect(deskDrawJpeg(png), isNotNull);
    });

    test('starts and markers over and over end in time', () {
      final unit = [0xFF, 0xD8, 0xFF, 0xDA, 0, 2, 0xFF, 0, 0xFF, 0xD0];
      final b = Uint8List.fromList([
        ...'II*'.codeUnits, 0, 8, 0, 0, 0, //
        for (var i = 0; i < 400000; i++) ...unit,
      ]);
      final sw = Stopwatch()..start();
      expect(largestJpeg(b), isNull);
      expect(deskDrawJpeg(b), isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    });

    test('a drawing that does not end is killed', () async {
      final was = deskDrawLimit;
      deskDrawLimit = const Duration(seconds: 1);
      addTearDown(() => deskDrawLimit = was);
      final sw = Stopwatch()..start();
      expect(await deskDrawKilled(Uint8List(8), draw: _forever), isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      expect(await deskDrawKilled(Uint8List(8), draw: _quick), [
        0xFF,
        0xD8,
        0xFF,
        1,
      ]);
    });
  });

  group('jpegs inside a file', () {
    test('the largest drawable one, past a lossless one', () {
      final small = _smallJpeg(40, 30);
      final big = _smallJpeg(200, 100);
      // a lossless jpeg header (sof3), as a canon keeps its sensor data
      final lossless = [
        0xFF, 0xD8, 0xFF, 0xC3, 0, 11, 8, 0x0F, 0xA0, 0x17, 0x70, 1, 1, 0x11,
        0, 0xFF, 0xD9, //
      ];
      final b = Uint8List.fromList([
        ...'II*'.codeUnits, 0, 8, 0, 0, 0, //
        ...lossless, 1, 2, 3, ...small, 9, 9, ...big, 7, ...lossless,
      ]);
      expect(largestJpeg(b), big);
      expect(largestJpeg(b, least: 150), big);
      expect(largestJpeg(b, least: 300), isNull);
    });

    test('a cut one is none', () {
      final big = _smallJpeg(200, 100);
      expect(largestJpeg(big.sublist(0, big.length - 40)), isNull);
    });

    test('the orientation a tiff head gives', () {
      // ifd0 at 8 with one entry: 0x0112 = 6
      final le = Uint8List.fromList([
        ...'II*'.codeUnits, 0, 8, 0, 0, 0, //
        1, 0, 0x12, 0x01, 3, 0, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0,
      ]);
      expect(rawOrientation(le), 6);
      final be = Uint8List.fromList([
        0x4D, 0x4D, 0, 0x2A, 0, 0, 0, 8, //
        0, 1, 0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, 8, 0, 0, 0, 0, 0, 0,
      ]);
      expect(rawOrientation(be), 8);
      expect(rawOrientation(Uint8List.fromList(_smallJpeg(4, 4))), isNull);
    });
  });

  group('drawn again', () {
    test('a raw with only a thumbnail is not drawn from it', () {
      final b = Uint8List.fromList([
        ...'II*'.codeUnits, 0, 8, 0, 0, 0, 0, 0, //
        ...'GPS 52.5 13.4'.codeUnits,
        ..._smallJpeg(160, 120),
      ]);
      expect(deskDrawJpeg(b), isNull);
    });

    test('a raw\'s own jpeg, turned as the raw says, with nothing of it', () {
      final preview = img.Image(width: 1600, height: 1200);
      img.fill(preview, color: img.ColorRgb8(200, 30, 30));
      final jpg = img.encodeJpg(preview, quality: 60);
      final b = Uint8List.fromList([
        ...'II*'.codeUnits, 0, 8, 0, 0, 0, //
        2, 0, //
        0x12, 0x01, 3, 0, 1, 0, 0, 0, 6, 0, 0, 0, //
        0x25, 0x88, 4, 0, 1, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, //
        ...'GPS 52.5 13.4 Wren'.codeUnits,
        ...jpg,
      ]);
      final out = deskDrawJpeg(b)!;
      _clean(out);
      final d = img.decodeJpg(out)!;
      // 6: turned a quarter, so it stands
      expect((d.width, d.height), (1200, 1600));
      expect(String.fromCharCodes(out), isNot(contains('Wren')));
    });

    test('a preview that stands already is not turned again', () {
      final jpg = img.encodeJpg(img.Image(width: 1200, height: 1600));
      final b = Uint8List.fromList([
        ...'II*'.codeUnits, 0, 8, 0, 0, 0, //
        1, 0, 0x12, 0x01, 3, 0, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0,
        ...jpg,
      ]);
      final d = img.decodeJpg(deskDrawJpeg(b)!)!;
      expect((d.width, d.height), (1200, 1600));
    });

    test('a tiff is decoded whole and turned', () {
      final t = img.Image(width: 300, height: 100);
      img.fill(t, color: img.ColorRgb8(10, 120, 200));
      t.exif.imageIfd.orientation = 8;
      t.exif.imageIfd['Artist'] = img.IfdValueAscii('Wren');
      final out = deskDrawJpeg(img.encodeTiff(t))!;
      _clean(out);
      final d = img.decodeJpg(out)!;
      expect((d.width, d.height), (100, 300));
      expect(String.fromCharCodes(out), isNot(contains('Wren')));
    });

    test('a long edge past the most is drawn down to it', () {
      final big = img.Image(width: 5000, height: 2500);
      final out = deskDrawJpeg(img.encodeJpg(big, quality: 30))!;
      final d = img.decodeJpg(out)!;
      expect((d.width, d.height), (4096, 2048));
    });

    test('what is no picture is not drawn', () {
      expect(deskDrawJpeg(Uint8List.fromList('%PDF-1.7'.codeUnits)), isNull);
      expect(deskDrawJpeg(Uint8List(0)), isNull);
    });

    test('a phone photo with its gps comes out clean and upright', () {
      for (final name in [
        '20261022_135215.jpg',
        'Screenshot_20261022-135445_Camera.jpg',
      ]) {
        final src = File(_corpus('samsung/$name')).readAsBytesSync();
        expect(_reads(src), isNot(MetaStatus.nothing), reason: name);
        final out = deskDrawJpeg(src)!;
        _clean(out);
        final a = img.decodeJpg(src)!;
        final up = img.bakeOrientation(a);
        final d = img.decodeJpg(out)!;
        final long = math.max(up.width, up.height);
        final scale = long > 4096 ? 4096 / long : 1.0;
        expect(d.width, closeTo(up.width * scale, 1), reason: name);
        expect(d.height, closeTo(up.height * scale, 1), reason: name);
      }
    }, skip: _noCorpus);

    test('heic and avif need a decoder this does not have', () {
      for (final name in ['libheif/example.heic', 'libheif/example.avif']) {
        final src = File(_corpus('public/$name')).readAsBytesSync();
        expect(deskDrawJpeg(src), isNull, reason: name);
      }
    }, skip: _noCorpus);
  });

  group('real cameras\' raw files', () {
    final dir = Directory(_corpus('public/raw'));
    final files = dir.existsSync()
        ? (dir
              .listSync()
              .whereType<File>()
              .where((f) => f.lengthSync() > 0)
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];

    test(
      'each comes out a clean upright jpeg of its own picture',
      () {
        expect(files, isNotEmpty);
        for (final f in files) {
          final name = p.basename(f.path);
          final src = f.readAsBytesSync();
          final out = deskDrawJpeg(src);
          expect(out, isNotNull, reason: name);
          _clean(out!);
          final d = img.decodeJpg(out)!;
          expect(
            math.max(d.width, d.height),
            greaterThanOrEqualTo(1200),
            reason: name,
          );
          expect(
            math.max(d.width, d.height),
            lessThanOrEqualTo(4096),
            reason: name,
          );
          final o = rawOrientation(src);
          if (o == 6 || o == 8) {
            expect(d.height, greaterThan(d.width), reason: name);
          }
          // ignore: avoid_print
          print(
            '$name ${src.length >> 20} MB -> ${d.width}x${d.height} '
            'turn $o, ${out.length >> 10} KB',
          );
        }
      },
      skip: _noCorpus ?? (files.isEmpty ? 'no raw files' : null),
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });

  group('a send from a computer', () {
    late Directory tmp;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('desk_draw');
      onDesktop = true;
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('halo/platform'), (
            call,
          ) async {
            fail('a computer asks no platform to draw (${call.method})');
          });
    });
    tearDown(() {
      onDesktop = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
      tmp.deleteSync(recursive: true);
    });

    test('a raw file goes as a clean jpeg of its own picture', () async {
      final preview = img.Image(width: 2000, height: 1500);
      final b = Uint8List.fromList([
        ...'II*'.codeUnits, 0, 8, 0, 0, 0, 0, 0, //
        ...'GPS 52.5 13.4'.codeUnits,
        ...img.encodeJpg(preview, quality: 40),
      ]);
      final src = '${tmp.path}/IMG_1.dng';
      File(src).writeAsBytesSync(b);
      final cache = Directory('${tmp.path}/cache')..createSync();
      final r = await copyForSend(
        src,
        '${tmp.path}/f_1.dng',
        name: 'IMG_1.dng',
        raw: true,
        cache: cache,
      );
      expect(r.name, 'IMG_1.jpg');
      expect(r.path, '${tmp.path}/f_1.jpg');
      final out = File(r.path!).readAsBytesSync();
      _clean(out);
      expect(readFile(r.path!).status, MetaStatus.nothing);
      expect(img.decodeJpg(out)!.width, 2000);
    });
  });
}
