// SPDX-License-Identifier: GPL-3.0-or-later
// the reaction pill and the timed flame are one widget each, drawn the same
// in a 1:1 chat and a group. the pill pops its emojis in, holds still when
// the phone asks for no movement, and the flame is the icon, not an emoji
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/burn_fade.dart' show BurnFlame;
import 'package:kryfo/widgets/chat_parts.dart';

import 'source_body.dart';

Widget _framed(Widget child, {bool still = false}) => MaterialApp(
  theme: buildHaloTheme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: Center(child: child)),
  ),
);

// the emojis' own way in, inside the pill. a press scale is a scale
// transition too, driven by its own tween
Finder _pops() => find.descendant(
  of: find.byType(ReactionPicker),
  matching: find.byWidgetPredicate(
    (w) => w is ScaleTransition && w.scale is CurvedAnimation,
  ),
);

void main() {
  final picks = <String>[];
  var replies = 0;
  Widget picker() => ReactionPicker(
    replyLabel: 'Reply',
    emojis: const ['❤️', '👍'],
    selected: '👍',
    onPick: picks.add,
    onReply: () => replies++,
  );

  setUp(() {
    picks.clear();
    replies = 0;
  });

  testWidgets('the emojis pop in one after another', (t) async {
    await t.pumpWidget(_framed(picker()));
    await t.pump(const Duration(milliseconds: 40));
    expect(_pops(), findsNWidgets(2));
    await t.pumpAndSettle();
    await t.tap(find.text('❤️'));
    await t.pumpAndSettle();
    expect(picks, ['❤️']);
    await t.tap(find.bySemanticsLabel('Reply'));
    await t.pumpAndSettle();
    expect(replies, 1);
  });

  testWidgets('with less movement nothing scales', (t) async {
    await t.pumpWidget(_framed(picker(), still: true));
    await t.pump();
    expect(_pops(), findsNothing);
    final press = t.widgetList<AnimatedScale>(
      find.descendant(
        of: find.byType(ReactionPicker),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(press, isNotEmpty);
    for (final p in press) {
      expect(p.duration, Duration.zero);
    }
    await t.pumpAndSettle();
  });

  testWidgets('every tile has its surface, the picked one amber', (t) async {
    await t.pumpWidget(_framed(picker()));
    await t.pumpAndSettle();
    BoxDecoration tileOf(String e) =>
        t
                .widget<Container>(
                  find
                      .ancestor(
                        of: find.text(e),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(tileOf('❤️').color, HaloColors.surface3);
    expect(tileOf('👍').color, HaloColors.amberSoft);
  });

  testWidgets('the timed flame is the icon, resting while it waits', (t) async {
    await t.pumpWidget(
      _framed(const BurnLine('30s', waits: true, color: Colors.amber)),
    );
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    expect(t.widget<BurnFlame>(find.byType(BurnFlame)).waiting, isTrue);
    expect(find.text('30s'), findsOneWidget);
  });

  test('both chats draw the shared pill and flame', () {
    for (final path in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      final src = sourceOf(path);
      expect(src, contains('ReactionPicker('), reason: path);
      expect(src, contains('BurnLine('), reason: path);
      expect(src, isNot(contains('class _EmojiTap')), reason: path);
      expect(src, isNot(contains("Text('🔥'")), reason: path);
    }
  });
}
