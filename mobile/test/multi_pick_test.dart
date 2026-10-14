// SPDX-License-Identifier: GPL-3.0-or-later
// photos picked several at a time come back whole, each from its own folder
// in the cache, and are shrunk here. the picker's own shrink writes
// cache/scaled_<name> once per name, so two photos of one name went as the
// last of them twice. two photos are two photos, whatever their names, and
// what the picker left is shredded even when a read fails
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kryfo/image_strip.dart' show pictureExt;
import 'package:kryfo/picked.dart';

import 'source_body.dart';

void main() {
  late Directory cache;
  setUp(() => cache = Directory.systemTemp.createTempSync('multi_pick'));
  tearDown(() => cache.deleteSync(recursive: true));

  // a pick laid out as image_picker_android leaves it: cache/<uuid>/<name>
  XFile pick(String uuid, String name, List<int> bytes) {
    final f = File('${cache.path}/$uuid/$name')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return XFile(f.path);
  }

  Future<Uint8List> shrink(Uint8List b) async =>
      Uint8List.fromList([0xAA, ...b]);

  test('two photos of one name go as two photos', () async {
    final a = pick('ffe32de1-5e01-47ec-a829-0f6c560e27b4', 'IMG_0001.jpg', [
      1,
      1,
    ]);
    final b = pick('2767e4fe-a67c-43f8-bd24-682f8ae06129', 'IMG_0001.jpg', [
      2,
      2,
    ]);
    final dropped = <String>[];
    final out = await readPickedPhotos(
      [a, b],
      shrink: shrink,
      drop: (x) async => dropped.addAll([for (final f in x) f.path]),
    );
    expect(out, [
      [0xAA, 1, 1],
      [0xAA, 2, 2],
    ]);
    expect(dropped, [a.path, b.path]);
  });

  test('a jpeg is shrunk, a png or a gif keeps its own format', () async {
    const jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1];
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 2];
    const gif = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 3];
    final out = await readPickedPhotos(
      [
        pick('ffe32de1-5e01-47ec-a829-0f6c560e27b4', 'a.jpg', jpeg),
        pick('2767e4fe-a67c-43f8-bd24-682f8ae06129', 'b.png', png),
        pick('3767e4fe-a67c-43f8-bd24-682f8ae06129', 'c.gif', gif),
      ],
      shrink: shrink,
      drop: (_) async {},
    );
    expect(out, [
      [0xAA, ...jpeg],
      png,
      gif,
    ]);
  });

  test('a picture kept in its own format is named for it', () {
    Uint8List b(List<int> x) => Uint8List.fromList(x);
    expect(pictureExt(b([0xFF, 0xD8, 0xFF, 0xE0])), 'jpg');
    expect(
      pictureExt(b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])),
      'png',
    );
    expect(pictureExt(b([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])), 'gif');
    expect(
      pictureExt(b([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])),
      'webp',
    );
    expect(
      pictureExt(
        b([
          0,
          0,
          0,
          24,
          ...'ftypheic'.codeUnits,
          0,
          0,
          0,
          0,
          ...'mif1'.codeUnits,
          0,
          0,
          0,
          0,
        ]),
      ),
      'heic',
    );
    for (final (file, sig) in [
      ('lib/screens/chat_screen.dart', 'Future<void> _sendOneImage('),
      ('lib/screens/group_chat_screen.dart', 'Future<void> _sendGroupImage('),
    ]) {
      final body = bodyOf(sourceOf(file), sig);
      expect(body, contains(r'.${pictureExt(bytes)}'), reason: file);
      expect(body, isNot(contains(".jpg'")), reason: file);
    }
  });

  test('one file handed back twice is read once', () async {
    final a = pick('ffe32de1-5e01-47ec-a829-0f6c560e27b4', 'IMG_0001.jpg', [1]);
    final out = await readPickedPhotos(
      [a, XFile(a.path)],
      shrink: shrink,
      drop: (_) async {},
    );
    expect(out, [
      [0xAA, 1],
    ]);
  });

  test('a read that fails still drops what the picker left', () async {
    final a = pick('ffe32de1-5e01-47ec-a829-0f6c560e27b4', 'a.jpg', [1]);
    final gone = XFile('${cache.path}/2767e4fe-a67c-43f8-bd24-682f8ae06129/b');
    var dropped = false;
    await expectLater(
      readPickedPhotos(
        [a, gone],
        shrink: shrink,
        drop: (_) async => dropped = true,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(dropped, isTrue);
  });

  test('both chats ask the picker for whole photos and shrink them here', () {
    final picked = sourceOf('lib/picked.dart');
    final pick = bodyOf(picked, 'Future<List<XFile>> pickGallery(');
    expect(callsOf(pick, 'pickMultiImage('), ['pickMultiImage()']);
    expect(callsOf(pick, 'pickMultipleMedia('), [
      'pickMultipleMedia()',
      'pickMultipleMedia()',
    ]);
    final send = bodyOf(picked, 'Future<void> sendGalleryPicks(');
    expect(send, contains('await readPickedPhotos('));
    for (final (file, sig) in [
      ('lib/screens/chat_screen.dart', 'Future<void> _pickAndSendMultiple('),
      (
        'lib/screens/group_chat_screen.dart',
        'Future<void> _pickGroupMultiple(',
      ),
    ]) {
      final body = bodyOf(sourceOf(file), sig);
      expect(body, contains('lockState.hold(pickGallery)'), reason: file);
      expect(body, contains('await sendGalleryPicks('), reason: file);
    }
  });
}
