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
    for (final (file, sig) in [
      ('lib/screens/chat_screen.dart', 'Future<void> _pickAndSendMultiple('),
      (
        'lib/screens/group_chat_screen.dart',
        'Future<void> _pickGroupMultiple(',
      ),
    ]) {
      final body = bodyOf(sourceOf(file), sig);
      final asks = callsOf(body, 'pickMultiImage(');
      expect(asks, ['pickMultiImage()'], reason: file);
      expect(body, contains('await readPickedPhotos(picked)'), reason: file);
    }
  });
}
