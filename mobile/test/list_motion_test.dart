// SPDX-License-Identifier: GPL-3.0-or-later
// the archived chats and a group's members: someone new grows in, someone
// who went folds away where they were and is let go, the archived count
// rolls to its new word. all of it rests, and with less movement nothing
// grows or folds.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/archived_screen.dart';
import 'package:kryfo/screens/group_info_screen.dart';
import 'package:kryfo/screens/home_screen.dart' show ContactPreview;
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/burn_fade.dart';
import 'package:kryfo/widgets/row_motion.dart';

Widget host(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: Directionality(textDirection: dir, child: c!),
  ),
  home: Scaffold(body: child),
);

Future<void> settles(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(t.binding.transientCallbackCount, 0);
}

void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

ContactPreview chat(String id) =>
    ContactPreview(haloId: id, avatarSeed: id, archived: true, preview: 'hi');

double heightOf(WidgetTester t, String text) => t
    .getSize(
      find.ancestor(of: find.text(text), matching: find.byType(FadeFold)).first,
    )
    .height;

void main() {
  group('archived chats', () {
    Widget list(
      List<String> ids, {
      bool still = false,
      ValueChanged<String>? onUnarchive,
    }) => host(
      ArchivedList(
        archived: [for (final id in ids) chat(id)],
        onUnarchive: onUnarchive ?? (_) {},
      ),
      still: still,
    );

    testWidgets('one taken back out folds away, and the count rolls', (
      t,
    ) async {
      quiet(t);
      final out = <String>[];
      await t.pumpWidget(list(['wren', 'moss', 'fern'], onUnarchive: out.add));
      await settles(t);
      final full = heightOf(t, 'moss');
      await t.tap(find.text('Unarchive').at(1));
      expect(out, ['moss']);
      await t.pumpWidget(list(['wren', 'fern']));
      await t.pump(const Duration(milliseconds: 140));
      // still drawn where it was, part folded
      expect(find.text('moss'), findsOneWidget);
      expect(heightOf(t, 'moss'), lessThan(full));
      expect(find.byType(AnimatedSwitcher), findsWidgets);
      await t.pump(const Duration(milliseconds: 400));
      await settles(t);
      expect(find.text('moss'), findsNothing);
    });

    testWidgets('one archived while here grows in', (t) async {
      await t.pumpWidget(list(['wren']));
      await settles(t);
      await t.pumpWidget(list(['wren', 'moss']));
      await t.pump(const Duration(milliseconds: 60));
      final grow = t.widget<GrowIn>(
        find.ancestor(of: find.text('moss'), matching: find.byType(GrowIn)),
      );
      expect(grow.active, isTrue);
      await settles(t);
    });

    testWidgets('the last one out leaves the quiet line behind', (t) async {
      await t.pumpWidget(list(['wren']));
      await settles(t);
      await t.pumpWidget(list([]));
      await t.pump(const Duration(milliseconds: 400));
      await settles(t);
      expect(find.text('wren'), findsNothing);
      expect(find.text('Nothing archived'), findsOneWidget);
    });

    testWidgets('reduced motion: the row goes with no fold', (t) async {
      await t.pumpWidget(list(['wren', 'moss'], still: true));
      await t.pump();
      final full = heightOf(t, 'moss');
      await t.pumpWidget(list(['wren'], still: true));
      await t.pump(const Duration(milliseconds: 60));
      if (find.text('moss').evaluate().isNotEmpty) {
        expect(heightOf(t, 'moss'), full);
      }
      await t.pump(const Duration(milliseconds: 400));
      await settles(t);
      expect(find.text('moss'), findsNothing);
    });

    testWidgets('the row numbers are never drawn in a line colour', (t) async {
      await t.pumpWidget(list(['wren']));
      await settles(t);
      final n = t.widget<Text>(find.text('01'));
      expect(n.style!.color, HaloColors.text3);
    });

    testWidgets('right to left: the list lays out from the right', (t) async {
      await t.pumpWidget(
        host(
          ArchivedList(archived: [chat('wren')], onUnarchive: (_) {}),
          dir: TextDirection.rtl,
        ),
      );
      await settles(t);
      final num = t.getTopLeft(find.text('01')).dx;
      final name = t.getTopLeft(find.text('wren')).dx;
      expect(num, greaterThan(name));
    });
  });

  group('group members', () {
    Widget card(List<String> ids, {bool still = false}) => host(
      SingleChildScrollView(
        child: MembersCard(
          members: ids,
          isMe: (id) => id == 'me',
          canRemove: false,
          onRemove: (_) {},
        ),
      ),
      still: still,
    );

    testWidgets('someone added grows in, someone gone folds away', (t) async {
      await t.pumpWidget(card(['me', 'wren']));
      await settles(t);
      final full = heightOf(t, 'wren');
      await t.pumpWidget(card(['me', 'wren', 'moss']));
      await t.pump(const Duration(milliseconds: 60));
      final grow = t.widget<GrowIn>(
        find.ancestor(of: find.text('moss'), matching: find.byType(GrowIn)),
      );
      expect(grow.active, isTrue);
      await settles(t);
      await t.pumpWidget(card(['me', 'moss']));
      await t.pump(const Duration(milliseconds: 140));
      expect(heightOf(t, 'wren'), lessThan(full));
      await t.pump(const Duration(milliseconds: 400));
      await settles(t);
      expect(find.text('wren'), findsNothing);
    });

    testWidgets('reduced motion: someone gone simply goes', (t) async {
      await t.pumpWidget(card(['me', 'wren'], still: true));
      await t.pump();
      final full = heightOf(t, 'wren');
      await t.pumpWidget(card(['me'], still: true));
      await t.pump(const Duration(milliseconds: 60));
      if (find.text('wren').evaluate().isNotEmpty) {
        expect(heightOf(t, 'wren'), full);
      }
      await t.pump(const Duration(milliseconds: 400));
      await settles(t);
      expect(find.text('wren'), findsNothing);
    });
  });
}
