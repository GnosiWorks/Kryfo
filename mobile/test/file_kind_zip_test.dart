// SPDX-License-Identifier: GPL-3.0-or-later
// a zip is found by its end, whatever its first bytes; one whose end is
// there and cannot be read is taken for an app; an app anywhere inside an
// archive makes it one. a heic with a long brand list is still a picture,
// pictures the cleaner cannot read through are told apart, and a name is
// read as it is shown and saved: no hidden letters, one composed form
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/image_strip.dart';

import 'zip_maker.dart';

String _c(int r) => String.fromCharCode(r);

List<int> _u16(int v) => [v & 0xFF, v >> 8 & 0xFF];
List<int> _u32(int v) => [..._u16(v & 0xFFFF), ..._u16(v >> 16 & 0xFFFF)];

// an end record on its own, saying what the test wants it to
List<int> _end({int count = 1, int size = 46, int at = 0, int comment = 0}) => [
  ..._u32(0x06054b50),
  ..._u16(0),
  ..._u16(0),
  ..._u16(count),
  ..._u16(count),
  ..._u32(size),
  ..._u32(at),
  ..._u16(comment),
];

// a heic whose ftyp box runs past the first 256 bytes, its picture brand
// listed last
Uint8List _longHeic() {
  final brands = <int>[];
  for (var i = 0; i < 70; i++) {
    brands.addAll('iso${i % 10}'.codeUnits);
  }
  brands.addAll('heic'.codeUnits);
  final size = 16 + brands.length;
  return Uint8List.fromList([
    ..._u32be(size),
    ...'ftyp'.codeUnits,
    ...'isom'.codeUnits,
    0,
    0,
    0,
    0,
    ...brands,
    ...List.filled(64, 0),
  ]);
}

List<int> _u32be(int v) => [
  v >> 24 & 0xFF,
  v >> 16 & 0xFF,
  v >> 8 & 0xFF,
  v & 0xFF,
];

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kind2'));
  tearDown(() => tmp.deleteSync(recursive: true));

  var n = 0;
  File made(List<int> bytes) =>
      File('${tmp.path}/f${n++}')..writeAsBytesSync(bytes);

  Future<FileFacts> facts(List<int> bytes, String name) async =>
      (await readFileFactsFresh(made(bytes).path, name))!;

  group('a zip found by its end', () {
    test('an app behind a picture is an app', () async {
      final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(500, 1)];
      final f = await facts([...jpeg, ...apkBytes()], 'holiday.jpg');
      expect(f.installer, isTrue);
    });

    test('an end that is there and cannot be read is an app', () async {
      // the directory it names is not where it says
      final f = await facts([
        ...List.filled(100, 7),
        ..._end(size: 4000),
      ], 'notes.txt');
      expect(f.installer, isTrue);
      final pk = await facts([
        0x50,
        0x4B,
        0x03,
        0x04,
        ...List.filled(100, 7),
        ..._end(size: 20),
      ], 'a.zip');
      expect(pk.installer, isTrue);
    });

    test('a directory with more entries than any app is an app', () async {
      final z = zipOf({
        'a.txt': [1],
      });
      // the count in the end record says 100001
      final at = z.length - 22;
      final b = Uint8List.fromList(z)
        ..setAll(at + 8, _u16(100001 & 0xFFFF))
        ..setAll(at + 10, _u16(100001 & 0xFFFF));
      // 100001 does not fit in 16 bits, so the zip64 marker says it
      b.setAll(at + 8, _u16(0xFFFF));
      b.setAll(at + 10, _u16(0xFFFF));
      expect((await facts(b, 'a.zip')).installer, isTrue);
      expect(zipNamesIn(Uint8List(0), 100001), isNull);
    });

    test(
      'a signature whose comment does not reach the end is no zip',
      () async {
        final f = await facts([
          ...'just text '.codeUnits,
          ..._end(comment: 9),
        ], 'notes.txt');
        expect(f.installer, isFalse);
        expect(f.kind, FileKind.text);
      },
    );

    test(
      'a record with bytes after its comment is read as java reads it',
      () async {
        final z = zipOf({
          'a.txt': [1],
          'evil.apk': [2],
        });
        // the comment says none, and two bytes follow
        final short = [...z, ...'cc'.codeUnits];
        expect((await facts(short, 'notes.zip')).installer, isTrue);
        final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(40, 1)];
        expect((await facts([...jpeg, ...short], 'cat.jpg')).installer, isTrue);
        // a loose one that does not read says nothing
        final noise = await facts([
          ...'just text '.codeUnits,
          ..._end(size: 9000),
          ...'more'.codeUnits,
        ], 'notes.txt');
        expect(noise.installer, isFalse);
      },
    );

    test('a comment that runs exactly to the end is read', () async {
      final z = zipOf({
        'a.txt': [1],
      });
      final b = Uint8List.fromList([...z, ...'hi'.codeUnits])
        ..setAll(z.length - 2, _u16(2));
      expect(await zipDirOf(made(b).path), isA<ZipDir>());
      expect((await zipDirOf(made(b).path)).names, ['a.txt']);
    });
  });

  group('an app inside an archive', () {
    for (final inner in [
      'tools/old/Game.APK',
      'x.apks',
      'deep/a/b/c.xapk',
      'm.apkm',
      'bundle/app.aab',
    ]) {
      test('$inner makes it one', () async {
        final z = zipOf({
          'readme.txt': [1],
          inner: [2],
        });
        expect((await facts(z, 'stuff.zip')).installer, isTrue);
      });
    }

    test('an archive of other things is not', () async {
      final z = zipOf({
        'a/b.txt': [1],
        'apk-notes.md': [2],
      });
      expect((await facts(z, 'stuff.zip')).installer, isFalse);
    });
  });

  group('a heic with its brand past 256 bytes', () {
    test('is a picture, never a video', () async {
      final b = _longHeic();
      expect(b.length, greaterThan(300));
      final f = made(b);
      final raf = await f.open();
      final head = await pictureHead(raf);
      await raf.close();
      expect(head.length, greaterThan(256));
      expect(pictureKind(head), PictureKind.heif);
      expect(await bytesSayIsoVideo(f.path), isFalse);
      expect(await sendLaneCleans(f.path, 'a.heic'), isTrue);
      expect(
        (await readFileFactsFresh(f.path, 'x.bin'))!.kind,
        FileKind.picture,
      );
    });

    test('goes through the cleaner', () async {
      final f = made(_longHeic());
      var reads = 0;
      await stripPictureFile(
        f.path,
        readAll: (f) async {
          reads++;
          return f.readAsBytes();
        },
      );
      expect(reads, 1);
    });
  });

  group('pictures the cleaner cannot read through', () {
    final raws = <String, List<int>>{
      'tiff': [0x49, 0x49, 0x2A, 0, 8, 0, 0, 0],
      'dng': [0x4D, 0x4D, 0, 0x2A, 0, 0, 0, 8],
      'orf': 'IIRO'.codeUnits + [8, 0, 0, 0],
      'rw2': 'IIU'.codeUnits + [0, 8, 0, 0, 0],
      'raf': 'FUJIFILMCCD-RAW 0201'.codeUnits,
      'jxl': [0xFF, 0x0A, 1, 2],
      'jxl box': [
        0,
        0,
        0,
        0x0C,
        0x4A,
        0x58,
        0x4C,
        0x20,
        0x0D,
        0x0A,
        0x87,
        0x0A,
      ],
      'psd': '8BPS'.codeUnits + [0, 1],
      'cr3': [0, 0, 0, 24, ...'ftypcrx '.codeUnits, 0, 0, 0, 1],
      'svg': utf8.encode('<?xml version="1.0"?>\n<svg xmlns="x"></svg>'),
      'svg bare': utf8.encode('  <svg width="1"></svg>'),
    };
    raws.forEach((what, bytes) {
      test('$what is told, whatever its name', () async {
        for (final name in ['shot.jpg', 'clip.mp4', 'raw.$what']) {
          final f = await facts(bytes, name);
          expect(f.raw, isTrue, reason: name);
          expect(f.kind, FileKind.picture, reason: name);
          expect(f.iso, isFalse, reason: name);
        }
        final f = made(bytes);
        expect(await sendLaneCleans(f.path, 'x.$what'), isFalse);
        expect(await bytesSayIsoVideo(f.path), isFalse);
      });
    });

    test('a cr3 named as a video is not given to the video cleaner', () async {
      final f = made([0, 0, 0, 24, ...'ftypcrx '.codeUnits, 0, 0, 0, 1]);
      expect(await sendLaneCleans(f.path, 'clip.mp4'), isFalse);
    });

    test('an html page that names svg is not a picture', () async {
      final f = await facts(
        utf8.encode('<html><body><svg></svg></body></html>'),
        'page.html',
      );
      expect(f.raw, isFalse);
    });
  });

  group('a name read as it is shown and saved', () {
    test('a trailing dot, space or hidden letter does not hide an app', () {
      for (final name in [
        'x.apk.',
        'x.apk ',
        'x.apk${_c(0x200B)}',
        'x.ap${_c(0x200D)}k',
        'x.ap${_c(0x0336)}k',
        'x.ap${_c(0x0951)}k',
        'x.ap${_c(0x2028)}k',
        'x.apk${_c(0x2029)}',
        'x.ap${_c(0x20DD)}k',
        'x.APK${_c(0xFE0F)}',
      ]) {
        expect(nameSaysInstaller(name), isTrue, reason: name);
        expect(
          safeFileName(name),
          'x.${name.contains('APK') ? 'APK' : 'apk'}',
          reason: name,
        );
      }
    });

    test('what is shown is what is saved', () {
      expect(safeFileName('photo.jpg.exe'), 'photo_jpg.exe');
      final nfd = 'cafe${_c(0x0301)}.pdf';
      final nfc = 'caf${_c(0xE9)}.pdf';
      expect(safeFileName(nfd), nfc);
      expect(safeFileName(nfc), nfc);
      // a mark on or just before the extension goes
      expect(safeFileName('${_c(0xE1)}.pd${_c(0x0301)}f'), '${_c(0xE1)}.pdf');
      expect(safeFileName('x${_c(0x0301)}.pdf'), 'x.pdf');
      // hangul by rule: a leading consonant and a vowel make one syllable
      expect(
        safeFileName('${_c(0x1100)}${_c(0x1161)}.txt'),
        '${_c(0xAC00)}.txt',
      );
    });

    test('fillers that look like nothing go', () {
      for (final r in [
        0x3164,
        0x115F,
        0x1160,
        0xFFA0,
        0x034F,
        0xFE0F,
        0x2800,
      ]) {
        expect(
          safeFileName('a${_c(r)}b.pdf'),
          'ab.pdf',
          reason: r.toRadixString(16),
        );
      }
      expect(
        safeFileName('a${String.fromCharCodes([0xDB40, 0xDD00])}b.pdf'),
        'ab.pdf',
      );
    });

    test('joiners stay only between letters of scripts that join', () {
      final zwnj = _c(0x200C);
      final zwj = _c(0x200D);
      // persian
      expect(
        safeFileName('${_c(0x0645)}$zwnj${_c(0x06CC)}.pdf'),
        '${_c(0x0645)}$zwnj${_c(0x06CC)}.pdf',
      );
      // devanagari
      expect(
        safeFileName('${_c(0x0915)}${_c(0x094D)}$zwj${_c(0x0937)}.txt'),
        '${_c(0x0915)}${_c(0x094D)}$zwj${_c(0x0937)}.txt',
      );
      expect(safeFileName('ab${zwj}cd.pdf'), 'abcd.pdf');
      expect(safeFileName('a$zwnj.pdf'), 'a.pdf');
    });

    test('at most 200 bytes of utf-8, cut between whole letters', () {
      final long = safeFileName('${_c(0xE9) * 150}.pdf');
      expect(utf8.encode(long).length, lessThanOrEqualTo(200));
      expect(long, endsWith('.pdf'));
      final family = String.fromCharCodes([
        0xD83D,
        0xDC68,
        0x200D,
        0xD83D,
        0xDC69,
        0x200D,
        0xD83D,
        0xDC67,
      ]);
      final cut = safeFileName('${'a' * 190}$family.png');
      expect(utf8.encode(cut).length, lessThanOrEqualTo(200));
      // no half letter: every lone surrogate would fail to encode
      expect(() => utf8.encode(cut), returnsNormally);
      expect(cut.runes.where((r) => r >= 0xD800 && r <= 0xDFFF), isEmpty);
    });
  });
}
