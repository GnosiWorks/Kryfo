// SPDX-License-Identifier: GPL-3.0-or-later
// decoded pictures in memory: the image cache held to 40 MB and 200, the
// cap kept across the lock, the cache emptied as the app leaves, and a
// video's first frame decoded no larger than the box it fills
import 'dart:async';
import 'dart:ui' as ui;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/widgets/album_grid.dart';
import 'package:kryfo/widgets/sealed_picture.dart';
import 'package:kryfo/widgets/video_bubble.dart';

import 'pin_flow_fakes.dart' show app;

// a plain png of w x h, as a frame the platform sends
Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF336699),
  );
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> _decode(ImageProvider p) {
  final done = Completer<ui.Image>();
  final stream = p.resolve(ImageConfiguration.empty);
  late final ImageStreamListener l;
  l = ImageStreamListener((info, _) {
    stream.removeListener(l);
    done.complete(info.image);
  }, onError: (e, _) => done.completeError(e));
  stream.addListener(l);
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ImageCache cache() => PaintingBinding.instance.imageCache;

  tearDown(() {
    resetPicturesForTest();
    cache()
      ..clear()
      ..maximumSizeBytes = 100 << 20
      ..maximumSize = 1000;
  });

  test('the cache is held to 40 MB and 200 pictures', () {
    capPictureCache();
    expect(cache().maximumSizeBytes, 40 << 20);
    expect(cache().maximumSize, 200);
  });

  test('capped under the lock, it stays empty and gets the cap as it '
      'lifts', () {
    shutPictures();
    capPictureCache();
    expect(cache().maximumSizeBytes, 0);
    openPictures();
    expect(cache().maximumSizeBytes, 40 << 20);
  });

  test('the lock lifting gives back the cap, never flutter\'s 100 MB', () {
    capPictureCache();
    shutPictures();
    openPictures();
    expect(cache().maximumSizeBytes, 40 << 20);
  });

  testWidgets('as the app leaves the cache empties at once', (t) async {
    final bytes = (await t.runAsync(() => _png(64, 64)))!;
    final img = (await t.runAsync(() => _decode(MemoryImage(bytes))))!;
    img.dispose();
    expect(cache().currentSize, 1);
    picturesLeaving();
    expect(cache().currentSize, 0);
    expect(picturesShut.value, isFalse);
    picturesBack();
  });

  testWidgets('a frame is decoded at the width asked, never past its own', (
    t,
  ) async {
    final bytes = (await t.runAsync(() => _png(640, 360)))!;
    final small = (await t.runAsync(() => _decode(frameImage(bytes, 160))))!;
    expect(small.width, 160);
    expect(small.height, 90);
    small.dispose();
    // a box wider than the frame: drawn at its own 640
    final wide = (await t.runAsync(() => _decode(frameImage(bytes, 1440))))!;
    expect(wide.width, 640);
    wide.dispose();
    expect(frameImage(bytes), isA<MemoryImage>());
  });

  group('a frame in its box', () {
    late Directory dir;
    late Uint8List frame;
    setUp(() => dir = Directory.systemTemp.createTempSync('frame_px'));
    tearDown(() => dir.deleteSync(recursive: true));

    // the platform's answer for a 640 x 360 clip
    Future<String> clip(WidgetTester t, String name) async {
      frame = (await t.runAsync(() => _png(640, 360)))!;
      final m = t.binding.defaultBinaryMessenger;
      const ch = MethodChannel('halo/platform');
      m.setMockMethodCallHandler(ch, (c) async {
        if (c.method != 'videoInfo') return null;
        return {'jpeg': frame, 'ms': 4000, 'w': 640, 'h': 360};
      });
      addTearDown(() => m.setMockMethodCallHandler(ch, null));
      return (File('${dir.path}/$name.mp4')..writeAsBytesSync([1, 2, 3])).path;
    }

    Future<ResizeImage> decoded(WidgetTester t) async {
      for (var i = 0; i < 40; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
        final img = t.widget<SealedPicture>(find.byType(SealedPicture)).image;
        if (img != null) return img as ResizeImage;
      }
      fail('no frame');
    }

    testWidgets('a grid tile: a wide frame fills the square tile\'s height', (
      t,
    ) async {
      final path = await clip(t, 'g');
      await t.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: AlbumGrid(
                tiles: [AlbumTile(path: path, video: true)],
                width: 300,
              ),
            ),
          ),
        ),
      );
      final img = await decoded(t);
      final box = t.getSize(find.byType(SealedPicture));
      final dpr = t.view.devicePixelRatio;
      final side = box.width > box.height ? box.width : box.height;
      // 16:9 into a square: the height is the side, so the width is 16/9 of it
      expect(img.width, (side * 640 / 360 * dpr).ceil());
      expect(img.width! / dpr, greaterThan(box.width));
    });

    testWidgets('a bubble held to its least height: the frame still covers '
        'it', (t) async {
      final path = await clip(t, 'b');
      await t.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: VideoBubble(
                path: path,
                fileName: 'b.mp4',
                width: 120,
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      final img = await decoded(t);
      final dpr = t.view.devicePixelRatio;
      // 120 wide at 16:9 is 67.5 high, held to 90: 160 across covers it
      expect(img.width, (90 * 640 / 360 * dpr).ceil());
    });
  });
}
