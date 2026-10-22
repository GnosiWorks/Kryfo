// every lane that sends or saves a file uses one cleaner: a picture or video
// is cleaned on a copy and read again, anything still found is refused,
// and a file that is no media goes as it is.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/clean_media.dart';
import 'package:kryfo/image_strip.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/tools/cleaner.dart' show readFile;

import 'meta_fixtures.dart';

void main() {
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

  test('every send lane uses the one cleaner', () {
    for (final f in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('cleanMediaFile(dest.path'), reason: f);
      expect(src, isNot(contains('stripMp4Metadata(')), reason: f);
    }
    final cam = File('lib/screens/camera_screen.dart').readAsStringSync();
    expect(cam, contains('photoToSendOffUi(small)'));
    final save = File('lib/file_save.dart').readAsStringSync();
    expect(save, contains('cleanedForSave('));
  });
}
