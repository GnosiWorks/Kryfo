// SPDX-License-Identifier: GPL-3.0-or-later
// an upright clip comes out of the player wide, with a quarter turn still to
// make. the player's box takes the clip's shape as shown, and the texture
// fills it at the decoded shape, turned upright.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/widgets/video_frame.dart';
import 'package:kryfo/widgets/video_viewer.dart';

void quiet(WidgetTester t, Map<String, dynamic> opened) {
  final was = videoGuard;
  videoGuard = LockGuard(isLocked: () => false);
  final m = t.binding.defaultBinaryMessenger;
  const secure = MethodChannel('halo/platform');
  const video = MethodChannel('kryfo/video');
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  m.setMockMethodCallHandler(secure, (_) async => null);
  m.setMockMethodCallHandler(video, (c) async {
    return switch (c.method) {
      'open' => opened,
      'state' => {'ms': 0, 'playing': true, 'done': false},
      _ => null,
    };
  });
  addTearDown(() {
    videoGuard = was;
    m.setMockMethodCallHandler(SystemChannels.platform, null);
    m.setMockMethodCallHandler(secure, null);
    m.setMockMethodCallHandler(video, null);
  });
}

Future<void> open(WidgetTester t) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openVideo(ctx, path: '/nowhere/upright.mp4'),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byType(GestureDetector).first);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> close(WidgetTester t) async {
  Navigator.of(t.element(find.byType(VideoFrame))).pop();
  await t.pumpAndSettle();
}

void main() {
  group('shape from the player', () {
    test('the shown size sets the aspect, turns wrap to 0..3', () {
      final s = VideoShape.from({'w': 1080, 'h': 1920, 'turns': 1}, 16 / 9);
      expect(s.aspect, closeTo(1080 / 1920, 1e-9));
      expect(s.turns, 1);
      expect(VideoShape.from({'w': 4, 'h': 3, 'turns': 7}, 1).turns, 3);
      expect(VideoShape.from({'w': 4, 'h': 3, 'turns': -1}, 1).turns, 3);
    });

    test('an older player answer keeps the frame aspect and no turn', () {
      final s = VideoShape.from({'id': 1, 'ms': 10}, 0.75);
      expect(s.aspect, 0.75);
      expect(s.turns, 0);
    });
  });

  testWidgets('a turned frame fills its box upright', (t) async {
    const k = ValueKey('tex');
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 360,
            height: 800,
            child: Center(
              child: VideoFrame(
                aspect: 9 / 16,
                turns: 1,
                under: ColoredBox(color: Colors.black),
                texture: SizedBox.expand(key: k),
              ),
            ),
          ),
        ),
      ),
    );
    final box = t.getSize(find.byType(AspectRatio));
    expect(box.width / box.height, closeTo(9 / 16, 1e-6));
    // the texture is laid out wide, as decoded, then turned into the box
    final tex = t.getSize(find.byKey(k));
    expect(tex, Size(box.height, box.width));
    final r = t.getRect(find.byType(RotatedBox));
    expect(r.size, box);
  });

  testWidgets('the player takes the shown shape and the turn it is told', (
    t,
  ) async {
    quiet(t, {'id': 7, 'w': 1080, 'h': 1920, 'turns': 1, 'ms': 4000});
    await open(t);
    final frame = t.widget<VideoFrame>(find.byType(VideoFrame));
    expect(frame.aspect, closeTo(1080 / 1920, 1e-9));
    expect(frame.turns, 1);
    final box = t.getSize(find.byType(AspectRatio));
    expect(box.width / box.height, closeTo(1080 / 1920, 1e-3));
    final tex = t.getSize(find.byType(Texture));
    expect(tex.width, closeTo(box.height, 0.01));
    expect(tex.height, closeTo(box.width, 0.01));
    expect(t.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
    await close(t);
  });

  testWidgets('a phone that turns frames itself gets no extra turn', (t) async {
    quiet(t, {'id': 7, 'w': 1080, 'h': 1920, 'turns': 0, 'ms': 4000});
    await open(t);
    final tex = t.getSize(find.byType(Texture));
    final box = t.getSize(find.byType(AspectRatio));
    expect(tex, box);
    expect(t.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 0);
    await close(t);
  });
}
