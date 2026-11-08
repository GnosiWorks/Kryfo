import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/jpeg_strip.dart' show jpegHasExif;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/screens/clean_screen.dart' show failureTitle;
import 'package:kryfo/tools/cleaner.dart';

import 'meta_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cleaner'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String put(String name, List<int> bytes) {
    final f = File('${tmp.path}/$name')..writeAsBytesSync(bytes);
    return f.path;
  }

  group('names', () {
    test('a plain name keeps its stem', () {
      expect(cleanName('beach.JPG', MetaKind.jpeg), 'beach clean.jpg');
    });
    test('replaces a name that carries a date', () {
      expect(
        cleanName('IMG_20260918_112233.jpg', MetaKind.jpeg),
        'photo clean.jpg',
      );
      expect(cleanName('VID_20260918.mp4', MetaKind.mp4), 'video clean.mp4');
    });
    test('extension follows the real file kind', () {
      expect(cleanName('holiday.png', MetaKind.jpeg), 'holiday clean.jpg');
      expect(cleanName('clip.mov', MetaKind.mp4), 'clip clean.mov');
      expect(cleanName('clip.mov', MetaKind.jpeg), 'clip clean.jpg');
    });
    test('separators and empty names give a safe name', () {
      expect(
        cleanName('../../etc/passwd', MetaKind.png),
        '_.._etc_passwd clean.png',
      );
      expect(cleanName(null, MetaKind.png), 'photo clean.png');
      expect(cleanName('.jpg', MetaKind.jpeg).endsWith(' clean.jpg'), true);
    });
  });

  test('a camera jpeg comes out clean', () async {
    final src = put('a.jpg', jpeg(tiff: cameraTiff()));
    final r = await cleanFileHere(src, '${tmp.path}/out', 'a.jpg');
    expect(r.failure, null);
    expect(r.before.gps, isNotNull);
    expect(readFile(r.path!).status, MetaStatus.nothing);
    expect(r.name, 'a clean.jpg');
    expect(r.mime, 'image/jpeg');
    expect(File(src).existsSync(), true);
  });

  test('cleans heif and mp4 too', () async {
    final h = put('h.heic', heif(tiff: cameraTiff(), xmp: xmpGps));
    final rh = await cleanFileHere(h, '${tmp.path}/out', 'h.heic');
    expect(rh.failure, null);
    final m = put('m.mp4', mp4(place: true, maker: true, created: 3800000000));
    final rm = await cleanFileHere(m, '${tmp.path}/out', 'm.mp4');
    expect(rm.failure, null);
    expect(readFile(rm.path!).status, MetaStatus.nothing);
  });

  test('a motion photo heic keeps its still and loses the clip', () async {
    final src = put(
      'm.heic',
      heif(tiff: cameraTiff(), after: box('mpvd', t('ftypmp42'))),
    );
    final r = await cleanFileHere(src, '${tmp.path}/out', 'm.heic');
    expect(r.before.embeddedVideo, true);
    expect(r.failure, null);
    expect(readFile(r.path!).status, MetaStatus.nothing);
    expect(
      latin1.decode(File(r.path!).readAsBytesSync()).contains('mpvd'),
      false,
    );
  });

  test('a motion photo jpeg keeps its still and loses the clip', () async {
    // the clip and a samsung trailer hang after the end marker
    final clip = [...box('ftyp', t('mp42')), ...box('mdat', t('sound'))];
    final x =
        '<x:xmpmeta><rdf:Description GCamera:MotionPhoto="1"/></x:xmpmeta>';
    final whole = jpeg(
      tiff: cameraTiff(),
      xmp: x,
      mpf: true,
      trailer: [
        ...clip,
        ...sefTrailer([('MCC_Data', t('262'))]),
      ],
    );
    final src = put('mp.jpg', whole);
    final r = await cleanFileHere(src, '${tmp.path}/out', 'mp.jpg');
    expect(r.before.embeddedVideo, true);
    expect(r.before.networkCountry, '262');
    expect(r.failure, null);
    final out = File(r.path!).readAsBytesSync();
    expect(readFile(r.path!).status, MetaStatus.nothing);
    // the scan data is the same bytes, and nothing follows the end marker
    const scan = [0xFF, 0xDA, 0x00, 0x04, 0, 1, 5, 6, 0xFF, 0x00, 7];
    int find(List<int> b) {
      for (var k = 0; k + scan.length <= b.length; k++) {
        var ok = true;
        for (var n = 0; n < scan.length && ok; n++) {
          ok = b[k + n] == scan[n];
        }
        if (ok) return k;
      }
      return -1;
    }

    final at = find(out);
    final was = find(whole);
    expect(at, greaterThan(0));
    expect(out.sublist(at), whole.sublist(was, was + out.length - at));
    expect(out.sublist(out.length - 2), [0xFF, 0xD9]);
  });

  test(
    'a jpeg with an hdr layer keeps its picture and names the layer',
    () async {
      final x = '<x:xmpmeta><rdf:Description hdrgm:Version="1.0"/></x:xmpmeta>';
      final src = put('h.jpg', jpeg(xmp: x, mpf: true, trailer: jpeg()));
      final r = await cleanFileHere(src, '${tmp.path}/out', 'h.jpg');
      expect(r.before.hdrLayer, true);
      expect(r.failure, null);
      expect(readFile(r.path!).status, MetaStatus.nothing);
      expect(
        removedLines(r.before).map((l) => l.label),
        contains(l10n.cleanerHdrLayer),
      );
    },
  );

  test('removes a vendor box too', () async {
    final src = put(
      's.heic',
      heif(tiff: cameraTiff(), after: box('sefd', t('samsung'))),
    );
    final r = await cleanFileHere(src, '${tmp.path}/out', 's.heic');
    expect(r.failure, null);
    expect(readFile(r.path!).status, MetaStatus.nothing);
  });

  test('fails closed on leftovers the reader sees', () async {
    final src = put('u.heic', heif(coding: 'uri '));
    final r = await cleanFileHere(src, '${tmp.path}/out', 'u.heic');
    expect(r.failure, CleanFailure.notClean);
    expect(Directory('${tmp.path}/out').listSync().isEmpty, true);
  });

  test('refuses a non-picture and a cut file', () async {
    final pdf = put('x.pdf', t('%PDF-1.7 hello hello hello hello'));
    expect(
      (await cleanFileHere(pdf, '${tmp.path}/out', 'x.pdf')).failure,
      CleanFailure.unknownKind,
    );
    final whole = jpeg(tiff: cameraTiff());
    final cut = put('c.jpg', whole.sublist(0, whole.length - 3));
    expect(
      (await cleanFileHere(cut, '${tmp.path}/out', 'c.jpg')).failure,
      CleanFailure.unreadable,
    );
  });

  test('the rows name what was found', () {
    final r = readFile(put('a.jpg', jpeg(tiff: cameraTiff())));
    final labels = removedLines(r).map((l) => l.label).toList();
    expect(labels.first, 'Location');
    expect(labels.contains('Phone model'), true);
  });

  // heic, avif and a picture the cleaner refuses are drawn again as a clean
  // jpeg the way the lanes draw them; where nothing can draw it, the line
  // says plainly it can't be cleaned
  group('drawn again', () {
    Uint8List? drawn;
    var asked = 0;
    final photo = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();
    setUp(() {
      drawn = null;
      asked = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('halo/platform'), (
            call,
          ) async {
            if (call.method != 'shrinkJpeg') return null;
            asked++;
            return drawn;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('halo/platform'), null),
    );

    Future<CleanResult> clean(String path, String name) =>
        cleanFile(path, '${tmp.path}/out', originalName: name);

    void isCleanJpeg(CleanResult r) {
      expect(r.failure, isNull);
      expect(r.mime, 'image/jpeg');
      expect(r.name!.endsWith(' clean.jpg'), isTrue);
      final out = File(r.path!).readAsBytesSync();
      expect(jpegHasExif(out), isFalse);
      expect(readFile(r.path!).status, MetaStatus.nothing);
      expect(r.bytes, out.length);
    }

    test('a heic comes out a clean jpeg, the heic copy gone', () async {
      drawn = photo;
      final h = put('h.heic', heif(tiff: cameraTiff(), xmp: xmpGps));
      final r = await clean(h, 'h.heic');
      expect(asked, 1);
      isCleanJpeg(r);
      expect(r.before.gps, isNotNull);
      final left = Directory(
        '${tmp.path}/out',
      ).listSync(recursive: true).whereType<File>().toList();
      expect(left.map((f) => f.path), [r.path]);
    });

    test('a heic nothing can draw is still cleaned as a heic', () async {
      final h = put('h.heic', heif(tiff: cameraTiff(), xmp: xmpGps));
      final r = await clean(h, 'h.heic');
      expect(asked, 1);
      expect(r.failure, isNull);
      expect(r.name, 'h clean.heic');
    });

    test('a picture it cannot clean comes out a clean jpeg', () async {
      drawn = photo;
      final raw = put('IMG_1.dng', [
        ...'II*'.codeUnits,
        0,
        ...List.filled(64, 7),
      ]);
      isCleanJpeg(await clean(raw, 'IMG_1.dng'));
      final whole = jpeg(tiff: cameraTiff());
      final cut = put('c.jpg', whole.sublist(0, whole.length - 3));
      isCleanJpeg(await clean(cut, 'c.jpg'));
      final u = put('u.heic', heif(coding: 'uri '));
      isCleanJpeg(await clean(u, 'u.heic'));
    });

    test('one nothing can draw says plainly it can\'t be cleaned, no copy '
        'made', () async {
      final u = put('u.heic', heif(coding: 'uri '));
      final r = await clean(u, 'u.heic');
      expect(asked, 1);
      expect(r.failure, CleanFailure.notClean);
      expect(r.path, isNull);
      expect(failureTitle(r.failure!), l10n.cleanKryfoCouldNotMake);
      final out = Directory('${tmp.path}/out');
      expect(
        !out.existsSync() ||
            out.listSync(recursive: true).whereType<File>().isEmpty,
        isTrue,
      );
    });

    test('a clean jpeg and a video are never drawn', () async {
      drawn = photo;
      final a = put('a.jpg', jpeg(tiff: cameraTiff()));
      expect((await clean(a, 'a.jpg')).name, 'a clean.jpg');
      final v = put('v.mp4', t('not a video at all, though it says so'));
      await clean(v, 'v.mp4');
      expect(asked, 0);
    });
  });
}
