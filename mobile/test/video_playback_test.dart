// SPDX-License-Identifier: GPL-3.0-or-later
// the one video player: one native player alive at a time, the one before
// sleeping and opening again where it was; the lock closes it and it comes
// back paused where it was; gone, it closes; the viewers all use it
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/video_playback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const video = MethodChannel('kryfo/video');
  late List<MethodCall> calls;
  var next = 1;

  setUp(() {
    calls = [];
    openPictures();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(video, (c) async {
          calls.add(c);
          return switch (c.method) {
            'open' => {'id': next++, 'w': 1280, 'h': 720, 'ms': 60000},
            'state' => {'ms': 1000, 'playing': true, 'done': false},
            _ => null,
          };
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(video, null);
    openPictures();
  });

  List<String> did(String m) => [
    for (final c in calls)
      if (c.method == m) '${(c.arguments as Map)['id'] ?? ''}',
  ];

  LockGuard open() => LockGuard(isLocked: () => false);

  test(
    'one player alive: the one before sleeps and comes back where it was',
    () async {
      final a = VideoPlayback('/a.mp4', guard: open());
      final b = VideoPlayback('/b.mp4', guard: open());
      await a.open();
      final aId = a.textureId!;
      await a.seek(const Duration(seconds: 12));
      expect(VideoPlayback.liveCount, 1);
      await b.open();
      expect(VideoPlayback.liveCount, 1, reason: 'never two native players');
      expect(did('close'), contains('$aId'));
      expect(a.textureId, isNull);
      expect(a.asleep, isTrue);
      expect(a.position, const Duration(seconds: 12));
      calls.clear();
      await a.play();
      expect(a.textureId, isNotNull);
      final seek = calls.firstWhere((c) => c.method == 'seek');
      expect((seek.arguments as Map)['ms'], 12000);
      expect(b.textureId, isNull);
      a.dispose();
      b.dispose();
      expect(VideoPlayback.liveCount, 0);
    },
  );

  test('the lock closes it; after it, it opens paused where it was', () async {
    final a = VideoPlayback('/a.mp4', guard: open());
    await a.open();
    await a.seek(const Duration(seconds: 5));
    shutPictures();
    await pumpEventQueue();
    expect(a.textureId, isNull);
    expect(VideoPlayback.liveCount, 0);
    calls.clear();
    openPictures();
    await pumpEventQueue();
    expect(a.textureId, isNotNull);
    expect(a.playing, isFalse);
    final seek = calls.firstWhere((c) => c.method == 'seek');
    expect((seek.arguments as Map)['ms'], 5000);
    a.dispose();
  });

  test(
    'an open still on its way when the lock goes up holds no player',
    () async {
      final a = VideoPlayback('/a.mp4', guard: open());
      final f = a.open();
      shutPictures();
      await f;
      expect(a.textureId, isNull);
      expect(VideoPlayback.liveCount, 0);
      expect(did('close'), isNotEmpty);
      a.dispose();
    },
  );

  test('nothing plays while locked', () async {
    final a = VideoPlayback('/a.mp4', guard: LockGuard(isLocked: () => true));
    await a.open();
    await a.play();
    expect(a.playing, isFalse);
    expect(did('play'), isEmpty);
    a.dispose();
  });

  test('gone, it closes', () async {
    final a = VideoPlayback('/a.mp4', guard: open());
    await a.open();
    final id = a.textureId!;
    a.dispose();
    expect(did('close'), contains('$id'));
  });

  test('every screen that plays a video uses the one player', () {
    for (final f in [
      'lib/widgets/video_viewer.dart',
      'lib/widgets/album_viewer.dart',
      'lib/widgets/clip_preview.dart',
    ]) {
      final s = File(f).readAsStringSync();
      expect(s, contains('VideoPlayback('), reason: f);
      expect(s, isNot(contains("MethodChannel('kryfo/video')")), reason: f);
    }
  });
}
