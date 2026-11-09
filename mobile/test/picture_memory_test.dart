// SPDX-License-Identifier: GPL-3.0-or-later
// decoded pictures in memory: the image cache held to 40 MB and 200, the
// cap kept across the lock, the cache emptied as the app leaves, and a
// video's first frame decoded no larger than the box it fills
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/widgets/sealed_picture.dart';

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
}
