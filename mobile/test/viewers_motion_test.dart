// SPDX-License-Identifier: GPL-3.0-or-later
// the photo viewer flies out of its photo and back, closes on a pull and
// springs back from a short one; the video player asks nothing of the
// player while it is paused. all of it comes to rest, and with less
// movement nothing flies.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/widgets/photo_viewer.dart';
import 'package:kryfo/widgets/video_viewer.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAADCAIAAAA7ljmRAAAAEElEQVR4nGP4Oo8bjhhwcgCFmhNpSPXr6AAAAABJRU5ErkJggg==',
);

Widget host(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: Directionality(textDirection: dir, child: c!),
  ),
  home: Scaffold(body: Center(child: child)),
);

// the platform answers nothing: haptics, the screenshot flag
void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  const secure = MethodChannel('halo/platform');
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  m.setMockMethodCallHandler(secure, (_) async => null);
  addTearDown(() {
    m.setMockMethodCallHandler(SystemChannels.platform, null);
    m.setMockMethodCallHandler(secure, null);
  });
}

Future<void> settles(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(t.binding.transientCallbackCount, 0);
}

class _Thumb extends StatelessWidget {
  final ImageProvider image;
  const _Thumb(this.image);
  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('thumb'),
    onTap: () => openPhotoImage(context, image, tag: 'p', radius: 12),
    child: Hero(
      tag: 'p',
      child: SizedBox(
        width: 120,
        height: 90,
        child: Image(image: image, fit: BoxFit.cover),
      ),
    ),
  );
}

double _drag(WidgetTester t) {
  final tr = t.widget<Transform>(
    find
        .descendant(
          of: find.byType(PhotoViewer),
          matching: find.byType(Transform),
        )
        .first,
  );
  return tr.transform.getTranslation().y;
}

void main() {
  group('the photo viewer', () {
    late MemoryImage image;
    setUp(() => image = MemoryImage(_png));

    Future<void> open(WidgetTester t, {bool still = false}) async {
      quiet(t);
      await t.pumpWidget(host(_Thumb(image), still: still));
      final ctx = t.element(find.byType(_Thumb));
      await t.runAsync(() => precacheImage(image, ctx));
      await t.tap(find.byKey(const ValueKey('thumb')));
      await t.pump();
      await t.pump();
    }

    testWidgets('flies out of its photo and lands', (t) async {
      await open(t);
      await t.pump(const Duration(milliseconds: 100));
      // mid flight: the corners are between the photo's and none
      final clip = t.widget<ClipRRect>(find.byType(ClipRRect).last);
      final r = (clip.borderRadius as BorderRadius).topLeft.x;
      expect(r, greaterThan(0));
      expect(r, lessThan(12));
      await settles(t);
      expect(find.byType(PhotoViewer), findsOneWidget);
    });

    testWidgets('a tap flies it home and nothing is left moving', (t) async {
      await open(t);
      await settles(t);
      await t.tapAt(const Offset(20, 20));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(PhotoViewer), findsOneWidget);
      await settles(t);
      expect(find.byType(PhotoViewer), findsNothing);
    });

    testWidgets('a short pull springs back and rests', (t) async {
      await open(t);
      await settles(t);
      final g = await t.startGesture(const Offset(200, 300));
      await g.moveBy(const Offset(0, 30));
      await g.moveBy(const Offset(0, 30));
      await t.pump();
      expect(_drag(t), greaterThan(20));
      await g.up();
      await t.pump(const Duration(milliseconds: 60));
      expect(_drag(t), greaterThan(0));
      await settles(t);
      expect(_drag(t), 0);
      expect(find.byType(PhotoViewer), findsOneWidget);
    });

    testWidgets('a long pull closes it', (t) async {
      await open(t);
      await settles(t);
      await t.drag(find.byType(PhotoViewer), const Offset(0, 200));
      await settles(t);
      expect(find.byType(PhotoViewer), findsNothing);
    });

    testWidgets('reduced motion: there at once, and a pull snaps back', (
      t,
    ) async {
      await open(t, still: true);
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
      expect(find.byType(PhotoViewer), findsOneWidget);
      final g = await t.startGesture(const Offset(200, 300));
      await g.moveBy(const Offset(0, 30));
      await g.moveBy(const Offset(0, 30));
      await g.up();
      await t.pump();
      expect(_drag(t), 0);
      expect(t.binding.transientCallbackCount, 0);
      await t.tapAt(const Offset(20, 20));
      await t.pump();
      await t.pump();
      expect(find.byType(PhotoViewer), findsNothing);
    });

    testWidgets('right to left: it opens and closes the same way', (t) async {
      quiet(t);
      await t.pumpWidget(host(_Thumb(image), dir: TextDirection.rtl));
      final ctx = t.element(find.byType(_Thumb));
      await t.runAsync(() => precacheImage(image, ctx));
      await t.tap(find.byKey(const ValueKey('thumb')));
      await settles(t);
      expect(find.byType(PhotoViewer), findsOneWidget);
      await t.tapAt(const Offset(20, 20));
      await settles(t);
      expect(find.byType(PhotoViewer), findsNothing);
    });

    testWidgets('a photo slow to decode opens after a moment anyway', (
      t,
    ) async {
      quiet(t);
      await t.pumpWidget(host(_Thumb(image)));
      await t.tap(find.byKey(const ValueKey('thumb')));
      await t.pump(const Duration(milliseconds: 320));
      await settles(t);
      expect(find.byType(PhotoViewer), findsOneWidget);
    });
  });

  group('opening twice', () {
    testWidgets('a second tap while it decodes opens nothing more', (t) async {
      quiet(t);
      final image = MemoryImage(_png);
      await t.pumpWidget(host(_Thumb(image)));
      await t.tap(find.byKey(const ValueKey('thumb')));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(find.byKey(const ValueKey('thumb')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 320));
      await t.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsOneWidget);
    });
  });

  group('the photo tile', () {
    testWidgets('fades up once, and a cached one is simply there', (t) async {
      await t.pumpWidget(
        host(const PhotoTileFade(shown: false, child: SizedBox(width: 20))),
      );
      await t.pumpWidget(
        host(const PhotoTileFade(shown: true, child: SizedBox(width: 20))),
      );
      await t.pump(const Duration(milliseconds: 80));
      final o = t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(o.opacity, 1);
      await settles(t);
    });
  });

  group('the video player', () {
    late List<String> calls;
    late bool playing;

    void player(WidgetTester t) {
      calls = [];
      playing = false;
      final was = videoGuard;
      videoGuard = LockGuard(isLocked: () => false);
      addTearDown(() => videoGuard = was);
      const video = MethodChannel('kryfo/video');
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(video, (c) async {
        calls.add(c.method);
        switch (c.method) {
          case 'open':
            return {'id': 7, 'w': 640, 'h': 360, 'ms': 8000};
          case 'play':
            playing = true;
            return null;
          case 'pause':
            playing = false;
            return null;
          case 'state':
            return {'ms': 1200, 'playing': playing, 'done': false};
        }
        return null;
      });
      addTearDown(() => m.setMockMethodCallHandler(video, null));
    }

    int asked() => calls.where((c) => c == 'state').length;

    testWidgets('asks where it is while it plays, and not once paused', (
      t,
    ) async {
      quiet(t);
      player(t);
      await t.pumpWidget(
        host(
          Builder(
            builder: (ctx) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openVideo(ctx, path: '/nowhere/clip.mp4'),
              child: const SizedBox(width: 100, height: 60),
            ),
          ),
        ),
      );
      await t.tap(find.byType(GestureDetector).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 600));
      expect(playing, isTrue);
      expect(asked(), greaterThan(0));
      await t.tap(find.bySemanticsLabel(l10n.videoViewerPause));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      final before = asked();
      await t.pump(const Duration(seconds: 3));
      expect(asked(), before);
      await t.tap(find.bySemanticsLabel(l10n.commonClose).first);
      await t.pumpAndSettle();
    });
  });
}
