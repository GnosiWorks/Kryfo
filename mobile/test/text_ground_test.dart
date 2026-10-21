// SPDX-License-Identifier: GPL-3.0-or-later
// text with no material above it is drawn in flutter's error style, a
// yellow double underline. the video player, a page with no scaffold, and
// every raw route or overlay entry in the app stand on a material.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/widgets/motion.dart';
import 'package:kryfo/widgets/video_viewer.dart';

// the style each text is drawn with, its defaults merged in
List<TextStyle> drawn(WidgetTester t) => [
  for (final e in find.byType(Text).evaluate())
    DefaultTextStyle.of(e).style.merge((e.widget as Text).style),
];

void plain(WidgetTester t) {
  final styles = drawn(t);
  expect(styles, isNotEmpty);
  for (final s in styles) {
    expect(s.decoration ?? TextDecoration.none, TextDecoration.none);
    expect(s.decorationStyle, isNot(TextDecorationStyle.double));
  }
}

void quiet(WidgetTester t) {
  final was = videoGuard;
  videoGuard = LockGuard(isLocked: () => false);
  final m = t.binding.defaultBinaryMessenger;
  const secure = MethodChannel('halo/platform');
  const video = MethodChannel('kryfo/video');
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  m.setMockMethodCallHandler(secure, (_) async => null);
  m.setMockMethodCallHandler(video, (c) async {
    return switch (c.method) {
      'open' => {'id': 7, 'w': 640, 'h': 360, 'ms': 65000},
      'state' => {'ms': 1200, 'playing': false, 'done': false},
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

Future<void> tapToOpen(WidgetTester t, void Function(BuildContext) go) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => go(ctx),
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

void main() {
  testWidgets('the video player times are plain text', (t) async {
    quiet(t);
    await tapToOpen(t, (ctx) => openVideo(ctx, path: '/nowhere/clip.mp4'));
    expect(find.text('1:05'), findsOneWidget);
    plain(t);
  });

  testWidgets('a page with no scaffold gets plain text', (t) async {
    await tapToOpen(
      t,
      (ctx) => Navigator.of(ctx).push(haloRoute<void>(const Text('bare'))),
    );
    expect(find.text('bare'), findsOneWidget);
    plain(t);
  });

  // a new raw route or overlay entry has to stand on a material too
  test('every raw route and overlay entry has ground under its text', () {
    final raw = RegExp(r'PageRouteBuilder<[^>]*>\(|OverlayEntry\(');
    final ground = RegExp(r'TextGround\(|Material\(|DefaultTextStyle\(');
    // entries whose widget builds its own material further down, or draws
    // no text, by how many each file has
    const own = {
      'lib/stickers/sticker_flight.dart': 1, // a sticker, no text
      'lib/theme.dart': 1, // the toast's card is a material
      'lib/screens/search_screen.dart': 1, // a scaffold
      'lib/screens/group_chat_screen.dart': 1, // bubble and menu materials
      'lib/widgets/voice_parts.dart': 1, // the record bar is a material
    };
    final bare = <String>[];
    final counted = <String, int>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      for (final m in raw.allMatches(s)) {
        // the builder sits within a few lines of the constructor
        final end = (m.end + 900).clamp(0, s.length);
        if (ground.hasMatch(s.substring(m.end, end))) continue;
        final n = counted[f.path] = (counted[f.path] ?? 0) + 1;
        if (n <= (own[f.path] ?? 0)) continue;
        final line = '\n'.allMatches(s.substring(0, m.start)).length + 1;
        bare.add('${f.path}:$line');
      }
    }
    expect(bare, isEmpty);
  });
}
