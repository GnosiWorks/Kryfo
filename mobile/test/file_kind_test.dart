// SPDX-License-Identifier: GPL-3.0-or-later
// what a file is comes from its bytes before its name: a renamed app
// installer is still one, a pdf called .jpg opens as a pdf, and a name is
// made safe before it is saved or handed to another app
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_kind.dart';

import 'zip_maker.dart';

Uint8List _b(String s) => Uint8List.fromList(latin1.encode(s));

final _pdf = _b('%PDF-1.7\n%\xE2\xE3\xCF\xD3\n');
final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 74, 70]);
Uint8List _ftyp(String brand) =>
    Uint8List.fromList([0, 0, 0, 24, ..._b('ftyp$brand'), 0, 0, 0, 0]);

void main() {
  group('an app installer', () {
    test('is one by its manifest, whatever it is called', () {
      for (final n in ['photo.jpg', 'notes.pdf', 'clip.mp4', 'file', null]) {
        final f = factsOf(
          n,
          apkBytes(),
          zipNames: ['AndroidManifest.xml', 'classes.dex'],
        );
        expect(f.installer, isTrue, reason: '$n');
        expect(f.ext, 'apk', reason: '$n');
        expect(f.mime, isNull);
      }
    });

    test('is one by its name, whatever is inside', () {
      for (final n in ['x.apk', 'X.APK', 'photo.jpg.apk', 'a.xapk', 'a.apks']) {
        expect(factsOf(n, _pdf).installer, isTrue, reason: n);
      }
      expect(nameSaysInstaller('photo.jpg.apk'), isTrue);
      expect(nameSaysInstaller('photo.apk.jpg'), isFalse);
    });

    test('bundles of apps count', () {
      expect(zipHoldsInstaller(['base.apk', 'split_config.en.apk']), isTrue);
      expect(zipHoldsInstaller(['toc.pb', 'splits/base-master.apk']), isTrue);
      expect(
        zipHoldsInstaller(['manifest.json', 'com.x.apk', 'icon.png']),
        isTrue,
      );
      expect(zipHoldsInstaller(['info.json', 'base.apk']), isTrue);
      expect(zipHoldsInstaller(['readme.txt', 'b/c.png']), isFalse);
      expect(zipHoldsInstaller(['word/document.xml']), isFalse);
    });
  });

  group('the bytes before the name', () {
    test('a pdf called .jpg opens as a pdf', () {
      final f = factsOf('scan.jpg', _pdf);
      expect(f.kind, FileKind.pdf);
      expect(f.ext, 'pdf');
      expect(f.mime, 'application/pdf');
    });

    test(
      'a name that agrees keeps its own extension and the phone\'s type',
      () {
        final f = factsOf('photo.JPEG', _jpeg);
        expect(f.kind, FileKind.picture);
        expect(f.ext, 'jpeg');
        expect(f.mime, isNull);
      },
    );

    test('a zip is a docx or an epub when the name says so', () {
      final z = zipOf({
        'word/document.xml': [1],
      });
      expect(factsOf('cv.docx', z).kind, FileKind.document);
      expect(factsOf('cv.docx', z).mime, isNull);
      expect(factsOf('a.epub', z).kind, FileKind.document);
      final lie = factsOf('cat.jpg', z);
      expect(lie.kind, FileKind.archive);
      expect(lie.mime, 'application/zip');
    });

    test('mp4 and m4a share a box: the name says which', () {
      final song = factsOf('song.m4a', _ftyp('isom'));
      expect(song.kind, FileKind.audio);
      expect(song.mime, isNull);
      final clip = factsOf('clip.bin', _ftyp('isom'));
      expect(clip.kind, FileKind.video);
      expect(clip.iso, isTrue);
      expect(clip.mime, 'video/mp4');
      expect(factsOf(null, _ftyp('M4A ')).kind, FileKind.audio);
      expect(factsOf(null, _ftyp('qt  ')).mime, 'video/quicktime');
      // a heic is a picture, which the picture cleaner takes
      expect(factsOf(null, _ftyp('heic')).kind, FileKind.picture);
    });

    test('a file of no known kind goes by its name', () {
      final f = factsOf('notes.txt', _b('hello there'));
      expect(f.kind, FileKind.text);
      expect(f.ext, 'txt');
      final none = factsOf('README', _b('hello'));
      expect(none.kind, FileKind.other);
      expect(none.ext, '');
    });
  });

  group('read from disk', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('file_kind'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('an app renamed as a photo is read as an app', () async {
      final f = File('${tmp.path}/in_1_photo.jpg')
        ..writeAsBytesSync(apkBytes());
      final facts = await readFileFacts(f.path, 'photo.jpg');
      expect(facts.installer, isTrue);
      expect(knownInstaller(f.path, 'photo.jpg'), isTrue);
    });

    test('an app whose manifest is not the first entry', () async {
      final f = File('${tmp.path}/in_2_x.zip')
        ..writeAsBytesSync(apkBytes(first: 'META-INF/MANIFEST.MF'));
      expect((await readFileFacts(f.path, 'x.zip')).installer, isTrue);
    });

    test('a plain zip is not an app', () async {
      final f = File('${tmp.path}/in_3_a.zip')
        ..writeAsBytesSync(
          zipOf({
            'a.txt': [1],
            'b/c.png': [2],
          }),
        );
      final facts = await readFileFacts(f.path, 'a.zip');
      expect(facts.installer, isFalse);
      expect(facts.kind, FileKind.archive);
    });

    test('a zip cut short still names its first entry', () async {
      final whole = apkBytes();
      final f = File('${tmp.path}/in_4_x.bin')
        ..writeAsBytesSync(whole.sublist(0, 80));
      expect((await readFileFacts(f.path, 'x.bin')).installer, isTrue);
    });

    test('a file that is gone goes by its name', () async {
      final facts = await readFileFacts('${tmp.path}/nothing', 'a.pdf');
      expect(facts.kind, FileKind.pdf);
    });

    test('a renamed mp4 is walked by the cleaner, a pdf is not', () async {
      final mp4 = File('${tmp.path}/clip.bin')..writeAsBytesSync(_ftyp('isom'));
      final pdf = File('${tmp.path}/a.pdf')..writeAsBytesSync(_pdf);
      final jpg = File('${tmp.path}/a.dat')..writeAsBytesSync(_jpeg);
      final song = File('${tmp.path}/s.m4a')..writeAsBytesSync(_ftyp('M4A '));
      expect(await bytesSayIsoVideo(mp4.path), isTrue);
      expect(await bytesSayIsoVideo(song.path), isFalse);
      expect(await bytesSayIsoVideo(pdf.path), isFalse);
      expect(await sendLaneCleans(mp4.path, 'clip.bin'), isTrue);
      expect(await sendLaneCleans(jpg.path, 'a.dat'), isTrue);
      expect(await sendLaneCleans(pdf.path, 'a.pdf'), isFalse);
      expect(await sendLaneCleans(song.path, 's.m4a'), isFalse);
    });
  });

  group('a name fit to save', () {
    test('no folder in it and no way up', () {
      expect(safeFileName('../../etc/passwd'), isNot(contains('/')));
      expect(safeFileName('../../etc/passwd'), isNot(startsWith('.')));
      expect(safeFileName(r'..\..\win.ini'), isNot(contains(r'\')));
      expect(safeFileName('a/b:c*d?e"f<g>h|i.txt'), 'a_b_c_d_e_f_g_h_i.txt');
    });

    test('a direction override cannot turn the extension round', () {
      // shows as "invoicekpa.pdf" with the override left in
      final name = 'invoice${String.fromCharCode(0x202E)}fdp.apk';
      expect(safeFileName(name), 'invoicefdp.apk');
      expect(shownFileName(name), 'invoicefdp.apk');
      expect(shownFileName('a${String.fromCharCode(0x2067)}b.pdf'), 'ab.pdf');
    });

    test('hidden characters go, the persian joiner stays', () {
      final zwsp = String.fromCharCode(0x200B);
      final zwnj = String.fromCharCode(0x200C);
      expect(safeFileName('a${zwsp}b.pdf'), 'ab.pdf');
      expect(safeFileName('نامه$zwnjها.pdf'), 'نامه$zwnjها.pdf');
      expect(safeFileName('a\u0000b\nc.txt'), 'abc.txt');
    });

    test('only the last extension is one', () {
      expect(safeFileName('photo.jpg.apk'), 'photo_jpg.apk');
      expect(safeFileName('report.PDF.exe'), 'report_PDF.exe');
      expect(safeFileName('my.notes.v2.pdf'), 'my.notes.v2.pdf');
    });

    test('an installer always ends as one', () {
      const app = FileFacts(FileKind.installer, 'apk');
      expect(safeFileName('photo.jpg', facts: app), 'photo_jpg.apk');
      expect(safeFileName('holiday', facts: app), 'holiday.apk');
      expect(safeFileName('x.xapk', facts: app), 'x.xapk');
    });

    test('no hidden-file dot, never empty, never too long', () {
      expect(safeFileName('.profile'), 'profile');
      expect(safeFileName('...'), 'file');
      expect(safeFileName('   '), 'file');
      expect(safeFileName(null), 'file');
      final long = safeFileName('${'x' * 300}.pdf');
      expect(long.length, 120);
      expect(long, endsWith('.pdf'));
    });
  });
}
