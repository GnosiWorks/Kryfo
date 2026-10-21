// SPDX-License-Identifier: GPL-3.0-or-later
// a clip's frame lives in memory only while the clip does: forgotten when it
// is shredded, an answer still on its way is not kept either
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/open_file.dart';

const _platform = MethodChannel('halo/platform');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Completer<void>? gate;
  setUp(() {
    gate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_platform, (c) async {
          if (c.method != 'videoInfo') return null;
          await gate?.future;
          return {'ms': 2000, 'w': 480, 'h': 640};
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_platform, null),
  );

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
}
