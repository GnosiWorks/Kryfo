// SPDX-License-Identifier: GPL-3.0-or-later
// a clip plays in place before it goes: on its own once open, a tap to
// pause and play, a timeline that seeks, its shape and turn as the player
// says, and quiet under reduced motion and the lock
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/clip_preview.dart';
import 'package:kryfo/widgets/video_viewer.dart' show ViewerScrubber;

const _video = MethodChannel('kryfo/video');

late List<MethodCall> calls;
late bool playing;
late bool done;
// a play that waits here until let through
Completer<void>? playGate;
Map<String, Object> answer = {};

void player(WidgetTester t, {Map<String, Object>? open}) {
  calls = [];
  playing = false;
  done = false;
  answer = open ?? {'id': 5, 'w': 360, 'h': 640, 'ms': 4000};
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(_video, (c) async {
    calls.add(c);
    switch (c.method) {
      case 'open':
        return answer;
      case 'play':
        await playGate?.future;
        playing = true;
        return null;
      case 'pause':
        playing = false;
        return null;
      case 'state':
        return {'ms': done ? 4000 : 1000, 'playing': playing, 'done': done};
    }
    return null;
  });
  addTearDown(() => m.setMockMethodCallHandler(_video, null));
}

List<String> asked() => [for (final c in calls) c.method];

Widget host({bool still = false, bool autoplay = true}) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: Scaffold(
    body: ClipPreview(path: '/nowhere/clip.mp4', autoplay: autoplay),
  ),
);

// a tap on the picture away from the play mark in its middle
Future<void> tapPicture(WidgetTester t) => t.tapAt(
  t.getTopLeft(find.bySemanticsLabel(l10n.videoBubbleVideo)) +
      const Offset(24, 24),
);

Future<void> beats(WidgetTester t, [int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late LockGuard was;
  var locked = false;
  setUp(() {
    locked = false;
    was = clipGuard;
    clipGuard = LockGuard(isLocked: () => locked);
  });
  tearDown(() => clipGuard = was);

  testWidgets('it plays once open, and a tap pauses and plays it', (t) async {
    player(t);
    await t.pumpWidget(host());
    await beats(t);
    expect(asked(), containsAllInOrder(['open', 'play']));
    expect(find.byType(Texture), findsOneWidget);
    // the timeline reads where it is and how long it is
    expect(find.text('0:01'), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);

    await tapPicture(t);
    await beats(t);
    expect(playing, isFalse);
    expect(asked().last, 'pause');
    // the big mark is up while it waits, and plays it
    await t.tap(find.bySemanticsLabel(l10n.videoViewerPlay).first);
    await beats(t);
    expect(playing, isTrue);
    await t.pumpWidget(const SizedBox());
    expect(asked().last, 'close');
  });

  testWidgets('reduced motion: it waits for a tap', (t) async {
    player(t);
    await t.pumpWidget(host(still: true));
    await beats(t);
    expect(asked(), ['open']);
    expect(find.bySemanticsLabel(l10n.videoViewerPlay), findsWidgets);
    await tapPicture(t);
    await beats(t);
    expect(playing, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the timeline seeks where it is touched', (t) async {
    player(t);
    await t.pumpWidget(host(autoplay: false));
    await beats(t);
    final bar = t.getRect(find.byType(ViewerScrubber));
    await t.tapAt(Offset(bar.left + bar.width * 0.75, bar.center.dy));
    await beats(t);
    final seek = calls.lastWhere((c) => c.method == 'seek');
    expect((seek.arguments as Map)['ms'], closeTo(3000, 40));
    // the frame under the thumb shows
    expect(find.byType(Texture), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('at the end it offers to play again, from the start', (t) async {
    player(t);
    await t.pumpWidget(host());
    await beats(t);
    done = true;
    playing = false;
    await beats(t);
    final again = find.bySemanticsLabel(l10n.videoViewerPlayAgain);
    expect(again, findsOneWidget);
    calls.clear();
    await t.tap(again);
    await beats(t);
    expect(asked().take(2), ['seek', 'play']);
    expect((calls.first.arguments as Map)['ms'], 0);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('an upright clip keeps its shape and its turn', (t) async {
    player(t, open: {'id': 5, 'w': 360, 'h': 640, 'turns': 1, 'ms': 4000});
    await t.pumpWidget(host());
    await beats(t, 6);
    final box = t.getSize(find.byType(ClipRRect).first);
    expect(box.width / box.height, closeTo(360 / 640, 0.01));
    final turn = t.widget<RotatedBox>(
      find.ancestor(
        of: find.byType(Texture),
        matching: find.byType(RotatedBox),
      ),
    );
    expect(turn.quarterTurns, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the lock pauses it, and nothing starts under it', (t) async {
    player(t);
    await t.pumpWidget(host());
    await beats(t);
    expect(playing, isTrue);
    locked = true;
    clipGuard.locking();
    await beats(t);
    expect(playing, isFalse);
    calls.clear();
    await tapPicture(t);
    await beats(t);
    expect(asked(), isNot(contains('play')));
    await t.pumpWidget(const SizedBox());
  });

  void away(WidgetTester t) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(() {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }

  testWidgets('going behind the app pauses it', (t) async {
    player(t);
    await t.pumpWidget(host());
    await beats(t);
    expect(playing, isTrue);
    away(t);
    await beats(t);
    expect(playing, isFalse);
    expect(asked().last, 'pause');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a play still being asked when the app goes behind is paused '
      'once it answers', (t) async {
    player(t);
    playGate = Completer<void>();
    addTearDown(() => playGate = null);
    await t.pumpWidget(host());
    await beats(t);
    expect(asked(), contains('play'));
    expect(playing, isFalse);
    away(t);
    playGate!.complete();
    await beats(t);
    expect(playing, isFalse);
    expect(asked().last, 'pause');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a clip the phone cannot play says so', (t) async {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_video, (c) async => null);
    addTearDown(() => m.setMockMethodCallHandler(_video, null));
    await t.pumpWidget(host());
    await beats(t);
    expect(find.text(l10n.videoViewerCannotPlay), findsOneWidget);
    expect(find.byType(ViewerScrubber), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
