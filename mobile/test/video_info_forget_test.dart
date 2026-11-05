// SPDX-License-Identifier: GPL-3.0-or-later
// a clip's frame lives in memory only while the clip does: forgotten when it
// is shredded, an answer still on its way is not kept either. one the lock
// took on its way is asked again once the lock lifts
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/open_file.dart';
import 'package:kryfo/picture_lock.dart' show picturesShut;

const _platform = MethodChannel('halo/platform');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Completer<void>? gate;
  var asks = 0;
  setUp(() {
    gate = null;
    asks = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_platform, (c) async {
          if (c.method != 'videoInfo') return null;
          asks++;
          await gate?.future;
          return {
            'jpeg': Uint8List.fromList([1, 2, 3]),
            'ms': 2000,
            'w': 480,
            'h': 640,
          };
        });
  });
  tearDown(() {
    picturesShut.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_platform, null);
  });

  test('a forgotten clip has no frame', () async {
    const path = '/captures/clip_1.mp4';
    await videoInfoFor(path);
    expect(videoInfoNow(path), isNotNull);
    forgetVideoInfo(path);
    expect(videoInfoNow(path), isNull);
  });

  test('an answer that lands after the clip went is not kept', () async {
    const path = '/captures/clip_2.mp4';
    gate = Completer<void>();
    final asked = videoInfoFor(path);
    forgetVideoInfo(path);
    gate!.complete();
    await asked;
    expect(videoInfoNow(path), isNull);
    // asked again for a new file at that path, it is kept
    await videoInfoFor(path);
    expect(videoInfoNow(path), isNotNull);
  });

  test('a lock and an unlock while the frame is asked for: it is asked '
      'again and comes', () async {
    const path = '/captures/clip_3.mp4';
    gate = Completer<void>();
    final asked = videoInfoFor(path);
    picturesShut.value = true;
    forgetVideoFrames();
    picturesShut.value = false;
    gate!.complete();
    final got = await asked;
    expect(asks, 2);
    expect(got!.jpeg, isNotNull);
    expect(videoInfoNow(path)!.jpeg, isNotNull);
  });

  test('a frame that lands under the lock is not kept, and is asked for '
      'again after it', () async {
    const path = '/captures/clip_4.mp4';
    gate = Completer<void>();
    final asked = videoInfoFor(path);
    picturesShut.value = true;
    forgetVideoFrames();
    gate!.complete();
    final got = await asked;
    expect(got!.jpeg, isNull);
    expect(got.length, const Duration(seconds: 2));
    expect(asks, 1);
    picturesShut.value = false;
    expect((await videoInfoFor(path))!.jpeg, isNotNull);
    expect(asks, 2);
    // kept from here on
    await videoInfoFor(path);
    expect(asks, 2);
  });
}
