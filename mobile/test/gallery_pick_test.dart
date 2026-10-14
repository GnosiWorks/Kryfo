// SPDX-License-Identifier: GPL-3.0-or-later
// the gallery tile picks photos and videos together where android has its
// photo picker, and photos alone where it has not, since a mixed pick there
// is the file browser. a mixed pick goes in the order chosen: photos read
// whole and shrunk, each video the video tile's way, its copy shredded
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show ImagePickerPlatform;
import 'package:kryfo/picked.dart';

import 'source_body.dart';

// the plugin's own codec writes its option classes as lists behind a tag
class _Loose extends StandardMessageCodec {
  const _Loose();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) =>
      type > 128 ? readValue(buffer) : super.readValueOfType(type, buffer);
}

const _codec = _Loose();
const _api = 'dev.flutter.pigeon.image_picker_android.ImagePickerApi';

TestDefaultBinaryMessengerBinding get _b =>
    TestDefaultBinaryMessengerBinding.instance;

// the android picker as its host side answers it: [asked] gets the method
// and its general options, [allowMultiple, usePhotoPicker, limit]
void _picker(Map<String, List<Object?>> asked, List<String> paths) {
  for (final m in ['pickImages', 'pickVideos', 'pickMedia']) {
    _b.defaultBinaryMessenger.setMockMessageHandler('$_api.$m', (data) async {
      final args = _codec.decodeMessage(data)! as List<Object?>;
      asked[m] = args.last! as List<Object?>;
      return _codec.encodeMessage(<Object?>[paths]);
    });
  }
}

void _platform(Object? ready) => _b.defaultBinaryMessenger
    .setMockMethodCallHandler(const MethodChannel('halo/platform'), (c) async {
      if (c.method != 'photoPickerReady') return null;
      if (ready is Exception) throw ready;
      return ready;
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ImagePickerAndroid.registerWith);
  tearDown(() {
    for (final m in ['pickImages', 'pickVideos', 'pickMedia']) {
      _b.defaultBinaryMessenger.setMockMessageHandler('$_api.$m', null);
    }
    _b.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('halo/platform'),
      null,
    );
  });

  group('the pick', () {
    test('with the photo picker: photos and videos, several, in it', () async {
      final asked = <String, List<Object?>>{};
      _picker(asked, ['/c/a.jpg', '/c/b.mp4']);
      final got = await pickGallery(ready: () async => true);
      expect([for (final x in got) x.path], ['/c/a.jpg', '/c/b.mp4']);
      expect(asked.keys, ['pickMedia']);
      expect(asked['pickMedia']!.take(2), [true, true]);
      // only this pick used it
      final android = ImagePickerPlatform.instance as ImagePickerAndroid;
      expect(android.useAndroidPhotoPicker, isFalse);
      await ImagePicker().pickVideo(source: ImageSource.gallery);
      expect(asked['pickVideos']![1], isFalse);
    });

    test('without it: photos alone, as before', () async {
      final asked = <String, List<Object?>>{};
      _picker(asked, ['/c/a.jpg']);
      final got = await pickGallery(ready: () async => false);
      expect([for (final x in got) x.path], ['/c/a.jpg']);
      expect(asked.keys, ['pickImages']);
      expect(asked['pickImages']!.take(2), [true, false]);
    });

    test('the platform says which', () async {
      _platform(true);
      expect(await photoPickerReady(), isTrue);
      _platform(false);
      expect(await photoPickerReady(), isFalse);
      // an answer that never comes is no picker
      _platform(PlatformException(code: 'x'));
      expect(await photoPickerReady(), isFalse);
      _platform(null);
      expect(await photoPickerReady(), isFalse);
      final asked = <String, List<Object?>>{};
      _picker(asked, []);
      _platform(true);
      await pickGallery();
      _platform(false);
      await pickGallery();
      expect(asked.keys, ['pickMedia', 'pickImages']);
    });
  });

  group('the send', () {
    late Directory cache;
    setUp(() => cache = Directory.systemTemp.createTempSync('gallery_pick'));
    tearDown(() => cache.deleteSync(recursive: true));

    var n = 0;
    // a pick laid out as image_picker_android leaves it: cache/<uuid>/<name>
    XFile pick(String name, List<int> bytes) {
      final uuid =
          '${(n++).toRadixString(16).padLeft(8, '0')}'
          '-5e01-47ec-a829-0f6c560e27b4';
      final f = File('${cache.path}/$uuid/$name')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      return XFile(f.path);
    }

    Future<Uint8List> shrink(Uint8List b) async =>
        Uint8List.fromList([0xAA, ...b]);

    const jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1];
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 2];

    test('a mixed pick goes in the order chosen, each its own way', () async {
      final a = pick('IMG_1.jpg', jpeg);
      final v = pick('VID_1.mp4', [9]);
      final b = pick('shot.png', png);
      final w = pick('VID_2.mov', [8]);
      final seen = <String>[];
      final dropped = <List<String>>[];
      await sendGalleryPicks(
        [a, v, b, w],
        shrink: shrink,
        drop: (x) async => dropped.add([for (final f in x) f.name]),
        photo: (bytes, alone) async {
          seen.add('photo $bytes $alone');
          return true;
        },
        video: (x) async {
          seen.add('video ${x.name}');
          return true;
        },
      );
      expect(seen, [
        'photo ${[0xAA, ...jpeg]} false',
        'video VID_1.mp4',
        'photo $png false',
        'video VID_2.mov',
      ]);
      // the photos once read, each video once sent
      expect(dropped, [
        ['IMG_1.jpg', 'shot.png'],
        ['VID_1.mp4'],
        ['VID_2.mov'],
      ]);
    });

    test(
      'one photo alone gets its caption screen, one video does not',
      () async {
        final seen = <String>[];
        Future<void> send(XFile x) => sendGalleryPicks(
          [x, XFile(x.path)],
          shrink: shrink,
          drop: (_) async {},
          photo: (bytes, alone) async {
            seen.add('photo $alone');
            return true;
          },
          video: (x) async {
            seen.add('video');
            return true;
          },
        );
        await send(pick('a.jpg', jpeg));
        await send(pick('b.mp4', [9]));
        expect(seen, ['photo true', 'video']);
      },
    );

    test('a send that stops still drops every video copy', () async {
      final v = pick('a.mp4', [9]);
      final w = pick('b.mp4', [8]);
      final dropped = <String>[];
      await sendGalleryPicks(
        [v, w],
        drop: (x) async => dropped.addAll([for (final f in x) f.name]),
        photo: (_, _) async => true,
        video: (_) async => false,
      );
      expect(dropped.toSet(), {'a.mp4', 'b.mp4'});
      dropped.clear();
      await expectLater(
        sendGalleryPicks(
          [v, w],
          drop: (x) async => dropped.addAll([for (final f in x) f.name]),
          photo: (_, _) async => true,
          video: (_) async => throw StateError('gone'),
        ),
        throwsStateError,
      );
      expect(dropped.toSet(), {'a.mp4', 'b.mp4'});
    });

    test('a video is told by its name or its type', () {
      for (final n in ['a.mp4', 'a.MOV', 'a.3gp', 'a.webm', 'a.mkv']) {
        expect(isVideoPick(XFile('/c/$n')), isTrue, reason: n);
      }
      for (final n in ['a.jpg', 'a.heic', 'a.png', 'a.gif', 'a']) {
        expect(isVideoPick(XFile('/c/$n')), isFalse, reason: n);
      }
      expect(isVideoPick(XFile('/c/a', mimeType: 'video/mp4')), isTrue);
    });
  });

  test('both chats pick the gallery held and send videos the video way', () {
    for (final (file, sig, sendFile) in [
      (
        'lib/screens/chat_screen.dart',
        'Future<void> _pickAndSendMultiple(',
        '_sendFileFrom(x.path, madeVideoName(x.name))',
      ),
      (
        'lib/screens/group_chat_screen.dart',
        'Future<void> _pickGroupMultiple(',
        '_sendGroupFileFrom(x.path, madeVideoName(x.name))',
      ),
    ]) {
      final body = bodyOf(sourceOf(file), sig);
      expect(body, contains('await lockState.hold(pickGallery)'), reason: file);
      expect(body, contains('await sendGalleryPicks('), reason: file);
      expect(body, contains(sendFile), reason: file);
      expect(body, isNot(contains('ImagePicker()')), reason: file);
    }
  });
}
