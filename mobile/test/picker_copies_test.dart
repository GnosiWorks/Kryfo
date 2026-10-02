// SPDX-License-Identifier: GPL-3.0-or-later
// the gallery picker copies each pick whole, exif and gps included, to
// cache/<uuid>/<its own name>, and hands back only a shrunk scaled_<name>
// beside it. both go once the bytes are read, and whatever a dead app left
// goes at the next start. the cache here is laid out the way
// image_picker_android leaves it, with a gallery photo in it
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/picked.dart';

import 'source_body.dart';

final _photo = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();
const _name = 'IMG_20261001_101502.jpg';
const _pick = 'ffe32de1-5e01-47ec-a829-0f6c560e27b4';
const _other = '2767e4fe-a67c-43f8-bd24-682f8ae06129';

void main() {
  late Directory cache;
  late File original;
  late File scaled;
  late File otherPick;
  late List<File> keep;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('picker_copies');
    original = File('${cache.path}/$_pick/$_name')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_photo);
    scaled = File('${cache.path}/scaled_$_name')..writeAsBytesSync(_photo);
    // a video another chat is still sending from
    otherPick = File('${cache.path}/$_other/VID_20261001_101503.mp4')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_photo);
    keep = [
      File('${cache.path}/vn_1.wav')..writeAsStringSync('a voice note'),
      File('${cache.path}/share_plus/a.pdf')
        ..createSync(recursive: true)
        ..writeAsStringSync('shared'),
      File('${cache.path}/not-a-picker-folder/$_name')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_photo),
    ];
  });
  tearDown(() => cache.deleteSync(recursive: true));

  void kept() {
    for (final f in keep) {
      expect(f.existsSync(), isTrue, reason: f.path);
    }
  }

  test('a shrunk pick takes its full size original with it', () async {
    expect(original.readAsBytesSync(), _photo);
    await shredPickerCopies(cache, [scaled.path]);
    expect(scaled.existsSync(), isFalse);
    expect(original.existsSync(), isFalse);
    expect(Directory('${cache.path}/$_pick').existsSync(), isFalse);
    // another pick's folder is its own flow's to clear
    expect(otherPick.existsSync(), isTrue);
    kept();
  });

  test('a pick handed back from its own folder takes the folder', () async {
    await shredPickerCopies(cache, [otherPick.path]);
    expect(Directory('${cache.path}/$_other').existsSync(), isFalse);
    expect(original.existsSync(), isTrue);
    kept();
  });

  test('a path outside the cache is never touched', () async {
    final outside = Directory.systemTemp.createTempSync('gallery');
    addTearDown(() => outside.deleteSync(recursive: true));
    final real = File('${outside.path}/$_name')..writeAsBytesSync(_photo);
    await shredPickerCopies(cache, [real.path]);
    expect(real.readAsBytesSync(), _photo);
    expect(original.existsSync(), isTrue);
  });

  test('the start sweep takes every picker folder and shrunk copy', () async {
    await sweepPickerLeftovers(cache);
    expect(scaled.existsSync(), isFalse);
    expect(Directory('${cache.path}/$_pick').existsSync(), isFalse);
    expect(Directory('${cache.path}/$_other').existsSync(), isFalse);
    kept();
  });

  test('every gallery pick and the boot sweep go through it', () {
    final main = sourceOf('lib/main.dart');
    expect(
      bodyOf(main, 'Future<void> sweepCaptures('),
      contains('await sweepPickerLeftovers(tmp)'),
    );
    final chat = sourceOf('lib/screens/chat_screen.dart');
    final group = sourceOf('lib/screens/group_chat_screen.dart');
    for (final (src, fn) in [
      (chat, 'Future<void> _pickAndSendVideo('),
      (chat, 'Future<void> _pickAndSendMultiple('),
      (chat, 'Future<void> _pickWallpaperImage('),
      (group, 'Future<void> _pickGroupVideo('),
      (group, 'Future<void> _pickGroupMultiple('),
    ]) {
      final body = bodyOf(src, fn);
      expect(body, contains('} finally {'), reason: fn);
      expect(body, contains('await shredPickedImages('), reason: fn);
      expect(body, isNot(contains('shredFile(')), reason: fn);
    }
  });
}
