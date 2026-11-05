// every lane that sends or saves a file uses one cleaner: a picture or video
// is cleaned on a copy and read again, anything still found is refused,
// and a file that is no media goes as it is. a send or a note draws a
// picture the cleaner refuses, a raw one first, again as a clean jpeg, and
// sends one that cannot be drawn as it is, with nothing asked
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/clean_media.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/jpeg_strip.dart' show jpegHasExif;
import 'package:kryfo/image_strip.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/tools/cleaner.dart' show readFile;

import 'meta_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cleanmedia'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String put(String name, List<int> bytes) =>
      (File('${tmp.path}/$name')..writeAsBytesSync(bytes)).path;

  test('a photo sent as a file comes out clean', () async {
    final p = put('a.jpg', jpeg(tiff: cameraTiff(), xmp: xmpGps));
    final r = await cleanMediaFileHere(p, name: 'a.jpg');
    expect(r.how, MediaClean.clean);
    expect(r.video, false);
    expect(readFile(p).status, MetaStatus.nothing);
  });

  test('a video is told by its bytes, whatever its name', () async {
    final p = put(
      'clip.bin',
      File('test/fixtures/gopro_hero5_cut.mp4').readAsBytesSync(),
    );
    final r = await cleanMediaFileHere(p, name: 'clip.bin');
    expect(r.how, MediaClean.clean);
    expect(r.video, true);
    expect(readFile(p).status, MetaStatus.nothing);
  });

  test('a file that is no media is left exactly alone', () async {
    final bytes = t('%PDF-1.7 a page of text');
    final p = put('x.pdf', bytes);
    expect(
      (await cleanMediaFileHere(p, name: 'x.pdf')).how,
      MediaClean.notMedia,
    );
    expect(File(p).readAsBytesSync(), bytes);
  });

  test('media that cannot be read through is refused', () async {
    final whole = jpeg(tiff: cameraTiff());
    final cut = put('c.jpg', whole.sublist(0, whole.length - 3));
    expect(
      (await cleanMediaFileHere(cut, name: 'c.jpg')).how,
      MediaClean.refused,
    );
    final mini = put('m.heic', [
      ...box('ftyp', [...t('mif3'), ...be32(0), ...t('mif3'), ...t('heic')]),
      ...box('mini', List.filled(20, 1)),
    ]);
    expect(
      (await cleanMediaFileHere(mini, name: 'm.heic')).how,
      MediaClean.refused,
    );
    final clip = put('v.mp4', t('not a video at all, though it says so'));
    final v = await cleanMediaFileHere(clip, name: 'v.mp4');
    expect(v.how, MediaClean.refused);
    expect(v.video, true);
  });

  test('media that still reads as something after is refused', () async {
    // a picture item the reader does not know as a coding stays behind
    final p = put('u.heic', heif(coding: 'uri '));
    expect(
      (await cleanMediaFileHere(p, name: 'u.heic')).how,
      MediaClean.refused,
    );
  });

  test('the photo lanes refuse the same', () {
    expect(photoToSend(heif(coding: 'uri ')), null);
    final ok = photoToSend(jpeg(tiff: cameraTiff()));
    expect(ok, isNotNull);
    expect(ok!.length, lessThan(jpeg(tiff: cameraTiff()).length));
  });

  test('a clean that throws half way is a refusal, never an escape', () async {
    // gone before the clean reads it, as a file pulled away mid send
    final gone = '${tmp.path}/gone.jpg';
    final r = await cleanMediaFileHere(gone, name: 'gone.jpg');
    expect(r.how, MediaClean.refused);
    final v = await cleanMediaFile('${tmp.path}/gone.mp4', name: 'gone.mp4');
    expect(v.how, MediaClean.refused);
    expect(v.video, true);
    // a directory where a file should be
    final d = Directory('${tmp.path}/dir.jpg')..createSync();
    expect(
      (await cleanMediaFileHere(d.path, name: 'dir.jpg')).how,
      MediaClean.refused,
    );
  });

  group('a send', () {
    late Directory cache;
    setUp(() => cache = Directory('${tmp.path}/cache')..createSync());
    List<FileSystemEntity> left() {
      final d = Directory('${cache.path}/$kSaveCopies');
      return d.existsSync() ? d.listSync(recursive: true) : const [];
    }

    test('a copy that throws half way leaves nothing behind', () async {
      final src = put('a.jpg', jpeg(tiff: cameraTiff()));
      final dest = '${tmp.path}/media/f_1_a.jpg';
      Directory('${tmp.path}/media').createSync();
      final r = await copyClean(
        src,
        dest,
        name: 'a.jpg',
        cache: cache,
        copier: (a, b) async {
          final bytes = File(a).readAsBytesSync();
          File(b).writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
          throw const FileSystemException('no space left on device');
        },
      );
      expect(r.how, MediaClean.refused);
      expect(File(dest).existsSync(), false);
      expect(left().whereType<File>(), isEmpty);
    });

    test('only a clean copy reaches the media folder', () async {
      final bytes = jpeg(tiff: cameraTiff(), xmp: xmpGps);
      final src = put('b.jpg', bytes);
      final dest = '${tmp.path}/f_2_b.jpg';
      final r = await copyClean(src, dest, name: 'b.jpg', cache: cache);
      expect(r.how, MediaClean.clean);
      expect(readFile(dest).status, MetaStatus.nothing);
      expect(File(src).readAsBytesSync(), bytes);
      expect(left().whereType<File>(), isEmpty);
    });

    test('media that cannot be cleaned never reaches it', () async {
      final src = put('u.heic', heif(coding: 'uri '));
      final dest = '${tmp.path}/f_3_u.heic';
      final r = await copyClean(src, dest, name: 'u.heic', cache: cache);
      expect(r.how, MediaClean.refused);
      expect(File(dest).existsSync(), false);
      expect(left().whereType<File>(), isEmpty);
    });

    test('a file that is no media goes as it is', () async {
      final src = put('n.txt', t('notes'));
      final dest = '${tmp.path}/f_4_n.txt';
      final r = await copyClean(src, dest, name: 'n.txt', cache: cache);
      expect(r.how, MediaClean.notMedia);
      expect(File(dest).readAsStringSync(), 'notes');
    });
  });

  group('a save', () {
    test('hands out a clean copy and leaves the file as it was', () async {
      final bytes = jpeg(tiff: cameraTiff());
      final p = put('in_photo.jpg', bytes);
      final out = await cleanedForSave(p, 'photo.jpg', tmp);
      expect(out.path, isNot(p));
      expect(out.copy, isNotNull);
      expect(readFile(out.path!).status, MetaStatus.nothing);
      expect(File(p).readAsBytesSync(), bytes);
      expect(out.path!.startsWith('${tmp.path}/$kSaveCopies/'), true);
    });

    test('of a file that is no media hands out the file itself', () async {
      final p = put('in_notes.txt', t('hello'));
      final out = await cleanedForSave(p, 'notes.txt', tmp);
      expect(out.path, p);
      expect(out.copy, null);
    });

    test('of media that cannot be cleaned hands out nothing', () async {
      final p = put('in_u.heic', heif(coding: 'uri '));
      final out = await cleanedForSave(p, 'u.heic', tmp);
      expect(out.path, null);
      expect(Directory('${tmp.path}/$kSaveCopies').listSync(), isEmpty);
    });
  });

  group('a picture the cleaner cannot clean', () {
    // what the platform's draw answers: the bytes of a jpeg, or null
    Uint8List? drawn;
    var asked = 0;
    late Directory cache;
    setUp(() {
      cache = Directory('${tmp.path}/cache')..createSync();
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
    tearDown(() {
      onDesktop = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    });

    // a camera's raw file: a tiff head and its gps
    final rawBytes = [
      ...'II*'.codeUnits,
      0,
      ...List.filled(64, 7),
      ...'GPS 52.5 13.4'.codeUnits,
    ];
    final photo = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();

    test('a raw one that can be drawn goes as a clean jpeg', () async {
      drawn = photo;
      final src = put('IMG_1.dng', rawBytes);
      final r = await copyForSend(
        src,
        '${tmp.path}/f_1.dng',
        name: 'IMG_1.dng',
        raw: true,
        cache: cache,
      );
      expect(asked, 1);
      expect(r.path, '${tmp.path}/f_1.jpg');
      expect(r.name, 'IMG_1.jpg');
      final out = File(r.path!).readAsBytesSync();
      expect(pictureKind(out), PictureKind.jpeg);
      expect(jpegHasExif(out), isFalse);
      expect(readFile(r.path!).status, MetaStatus.nothing);
      expect(File('${tmp.path}/f_1.dng').existsSync(), isFalse);
      expect(File(src).readAsBytesSync(), rawBytes);
    });

    test('a raw one that cannot be drawn goes as it is, nothing asked of '
        'the person', () async {
      final src = put('IMG_2.dng', rawBytes);
      final r = await copyForSend(
        src,
        '${tmp.path}/f_2.dng',
        name: 'IMG_2.dng',
        raw: true,
        cache: cache,
      );
      expect(asked, 1);
      expect(r.path, '${tmp.path}/f_2.dng');
      expect(r.name, 'IMG_2.dng');
      expect(File(r.path!).readAsBytesSync(), rawBytes);
    });

    test('one the cleaner refuses is drawn again, or goes as it is', () async {
      final whole = jpeg(tiff: cameraTiff());
      final cut = whole.sublist(0, whole.length - 3);
      final src = put('c.jpg', cut);
      drawn = photo;
      final a = await copyForSend(
        src,
        '${tmp.path}/f_3.jpg',
        name: 'c.jpg',
        cache: cache,
      );
      expect(a.path, '${tmp.path}/f_3.jpg');
      expect(jpegHasExif(File(a.path!).readAsBytesSync()), isFalse);
      expect(readFile(a.path!).status, MetaStatus.nothing);
      drawn = null;
      final b = await copyForSend(
        src,
        '${tmp.path}/f_4.jpg',
        name: 'c.jpg',
        cache: cache,
      );
      expect(b.path, '${tmp.path}/f_4.jpg');
      expect(File(b.path!).readAsBytesSync(), cut);
    });

    test('a video the cleaner refuses still does not go, and is never '
        'drawn', () async {
      final src = put('v.mp4', t('not a video at all, though it says so'));
      final r = await copyForSend(
        src,
        '${tmp.path}/f_5.mp4',
        name: 'v.mp4',
        cache: cache,
      );
      expect(r.path, isNull);
      expect(r.video, isTrue);
      expect(asked, 0);
      expect(File('${tmp.path}/f_5.mp4').existsSync(), isFalse);
    });

    test('a picture it cleans is never drawn', () async {
      drawn = photo;
      final src = put('b.jpg', jpeg(tiff: cameraTiff(), xmp: xmpGps));
      final r = await copyForSend(
        src,
        '${tmp.path}/f_6.jpg',
        name: 'b.jpg',
        cache: cache,
      );
      expect(r.path, '${tmp.path}/f_6.jpg');
      expect(asked, 0);
    });

    test('a computer has nothing to draw with: it goes as it is', () async {
      onDesktop = true;
      drawn = photo;
      final src = put('IMG_7.dng', rawBytes);
      final r = await copyForSend(
        src,
        '${tmp.path}/f_7.dng',
        name: 'IMG_7.dng',
        raw: true,
        cache: cache,
      );
      expect(asked, 0);
      expect(File(r.path!).readAsBytesSync(), rawBytes);
    });
  });

  test('every send lane uses the one cleaner', () {
    for (final f in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('copyForSend(src, dest.path'), reason: f);
      expect(src, isNot(contains('stripMp4Metadata(')), reason: f);
    }
    final cam = File('lib/screens/camera_screen.dart').readAsStringSync();
    expect(cam, contains('photoToSendOffUi(small)'));
    final save = File('lib/file_save.dart').readAsStringSync();
    expect(save, contains('cleanedForSave('));
  });
}
