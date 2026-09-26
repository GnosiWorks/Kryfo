import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/tools/cleaner.dart';

import 'meta_fixtures.dart';

void main() {
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
    test('handles separators and empty names', () {
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

  test('refuses a motion photo and leaves nothing', () async {
    final src = put(
      'm.heic',
      heif(tiff: cameraTiff(), after: box('mpvd', t('ftypmp42'))),
    );
    final r = await cleanFileHere(src, '${tmp.path}/out', 'm.heic');
    expect(r.failure, CleanFailure.motion);
    expect(r.path, null);
    final out = Directory('${tmp.path}/out');
    expect(!out.existsSync() || out.listSync().isEmpty, true);
  });

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
}
