// SPDX-License-Identifier: GPL-3.0-or-later
// the shared chat pieces move, come to rest, stay still when the phone asks
// for no movement, and mirror in a right-to-left language
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/chat_parts.dart';
import 'package:kryfo/widgets/count_badge.dart';
import 'package:kryfo/widgets/message_menu.dart';
import 'package:kryfo/widgets/motion.dart';
import 'package:kryfo/widgets/press_scale.dart';
import 'package:kryfo/widgets/swipe_to_reply.dart';

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

// nothing left ticking once it has settled: no ticker asking for frames
Future<void> settles(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(t.binding.transientCallbackCount, 0);
}

// drawn still: one frame on, nothing is ticking
Future<void> still(WidgetTester t) async {
  await t.pump();
  expect(t.binding.transientCallbackCount, 0);
}

Finder under<T>(Type of) =>
    find.descendant(of: find.byType(of), matching: find.byType(T));

Matrix4 entranceMatrix(WidgetTester t) =>
    t.widget<Transform>(under<Transform>(BubbleEntrance).first).transform;

double entranceOpacity(WidgetTester t) =>
    t.widget<Opacity>(under<Opacity>(BubbleEntrance).first).opacity;

const bubble = SizedBox(width: 120, height: 40);

void main() {
  group('house curve', () {
    test('starts at rest, lands on one, overshoots a little', () {
      expect(kHouseCurve.transform(0), 0);
      expect(kHouseCurve.transform(1), 1);
      var peak = 0.0;
      for (var i = 0; i <= 100; i++) {
        final v = kHouseCurve.transform(i / 100);
        if (v > peak) peak = v;
      }
      expect(peak, greaterThan(1.0));
      expect(peak, lessThan(1.05));
      // close enough to rest at the end that the snap cannot be seen
      expect((kHouseCurve.transform(0.99) - 1).abs(), lessThan(0.01));
    });
  });

  group('bubble entrance', () {
    testWidgets('ours rises from the end side and settles', (t) async {
      await t.pumpWidget(
        host(const BubbleEntrance(isOut: true, active: true, child: bubble)),
      );
      await t.pump(const Duration(milliseconds: 40));
      final m = entranceMatrix(t);
      expect(m.getTranslation().x, greaterThan(0));
      expect(m.getTranslation().y, greaterThan(0));
      expect(entranceOpacity(t), lessThan(1));
      await settles(t);
      expect(entranceMatrix(t).isIdentity(), isTrue);
      expect(entranceOpacity(t), 1);
    });

    testWidgets('theirs comes from the start side', (t) async {
      await t.pumpWidget(
        host(const BubbleEntrance(isOut: false, active: true, child: bubble)),
      );
      await t.pump(const Duration(milliseconds: 40));
      expect(entranceMatrix(t).getTranslation().x, lessThan(0));
      await settles(t);
    });

    testWidgets('mirrored right to left', (t) async {
      await t.pumpWidget(
        host(
          const BubbleEntrance(isOut: true, active: true, child: bubble),
          dir: TextDirection.rtl,
        ),
      );
      await t.pump(const Duration(milliseconds: 40));
      expect(entranceMatrix(t).getTranslation().x, lessThan(0));
      await settles(t);
      await t.pumpWidget(
        host(
          const BubbleEntrance(isOut: false, active: true, child: bubble),
          dir: TextDirection.rtl,
        ),
      );
      await t.pumpWidget(host(const SizedBox()));
      await t.pumpWidget(
        host(
          const BubbleEntrance(isOut: false, active: true, child: bubble),
          dir: TextDirection.rtl,
        ),
      );
      await t.pump(const Duration(milliseconds: 40));
      expect(entranceMatrix(t).getTranslation().x, greaterThan(0));
      await settles(t);
    });

    testWidgets('only fades when motion is reduced', (t) async {
      await t.pumpWidget(
        host(
          const BubbleEntrance(isOut: true, active: true, child: bubble),
          still: true,
        ),
      );
      await t.pump(const Duration(milliseconds: 40));
      expect(entranceMatrix(t).isIdentity(), isTrue);
      expect(entranceOpacity(t), lessThan(1));
      await settles(t);
      expect(entranceOpacity(t), 1);
    });

    testWidgets('an old row is drawn still, and keeps its state', (t) async {
      final key = GlobalKey();
      await t.pumpWidget(
        host(
          BubbleEntrance(
            isOut: true,
            active: false,
            child: SizedBox(key: key, width: 10, height: 10),
          ),
        ),
      );
      expect(entranceOpacity(t), 1);
      expect(entranceMatrix(t).isIdentity(), isTrue);
      await still(t);
      final before = key.currentContext;
      await t.pumpWidget(
        host(
          BubbleEntrance(
            isOut: true,
            active: true,
            child: SizedBox(key: key, width: 10, height: 10),
          ),
        ),
      );
      // a rebuild never starts it
      await still(t);
      expect(key.currentContext, same(before));
    });
  });

  group('count badge', () {
    testWidgets('pops in, rolls, pops away, then rests', (t) async {
      Widget at(int n, {bool still = false}) =>
          host(CountBadge(count: n), still: still);
      await t.pumpWidget(at(0));
      expect(find.text('0'), findsNothing);
      await t.pumpWidget(at(3));
      await t.pump(const Duration(milliseconds: 30));
      expect(under<ScaleTransition>(CountBadge), findsWidgets);
      await settles(t);
      expect(find.text('3'), findsOneWidget);
      await t.pumpWidget(at(4));
      await t.pump(const Duration(milliseconds: 60));
      // both numbers on screen mid roll, the new one sliding in
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      final slide = t.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text('4'),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      expect(slide.position.value.dy, greaterThan(0));
      await settles(t);
      expect(find.text('3'), findsNothing);
      await t.pumpWidget(at(120));
      await settles(t);
      expect(find.text('99+'), findsOneWidget);
      await t.pumpWidget(at(0));
      await settles(t);
      expect(find.text('99+'), findsNothing);
    });

    testWidgets('a fewer count rolls the other way', (t) async {
      await t.pumpWidget(host(const CountBadge(count: 5)));
      await t.pumpWidget(host(const CountBadge(count: 2)));
      await t.pump(const Duration(milliseconds: 60));
      final slide = t.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text('2'),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      expect(slide.position.value.dy, lessThan(0));
      await settles(t);
    });

    testWidgets('only fades when motion is reduced', (t) async {
      await t.pumpWidget(host(const CountBadge(count: 0), still: true));
      await t.pumpWidget(host(const CountBadge(count: 2), still: true));
      await t.pump(const Duration(milliseconds: 30));
      expect(under<ScaleTransition>(CountBadge), findsNothing);
      await t.pumpWidget(host(const CountBadge(count: 3), still: true));
      await t.pump(const Duration(milliseconds: 30));
      expect(under<SlideTransition>(CountBadge), findsNothing);
      await settles(t);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('first build draws it still', (t) async {
      await t.pumpWidget(host(const CountBadge(count: 7)));
      expect(find.text('7'), findsOneWidget);
      await still(t);
    });
  });

  group('jump down', () {
    testWidgets('springs in, taps, and hides', (t) async {
      var taps = 0;
      Widget at(bool shown, {bool still = false}) => host(
        JumpDownButton(
          shown: shown,
          count: 2,
          label: 'Newest',
          onTap: () => taps++,
        ),
        still: still,
      );
      await t.pumpWidget(at(false));
      await t.pumpWidget(at(true));
      await t.pump(const Duration(milliseconds: 60));
      final mid = t.widget<AnimatedScale>(find.byType(AnimatedScale).first);
      expect(mid.scale, 1);
      final grown = t.getSize(find.byType(PressScale)).width;
      final box = t.renderObject<RenderBox>(find.byType(PressScale));
      // part way through the spring it is drawn smaller than it will be
      expect(
        box.localToGlobal(Offset(grown, 0)).dx -
            box.localToGlobal(Offset.zero).dx,
        lessThan(grown),
      );
      await settles(t);
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await settles(t);
      expect(taps, 1);
      expect(find.text('2'), findsOneWidget);
      await t.pumpWidget(at(false));
      await settles(t);
      await t.tap(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
        warnIfMissed: false,
      );
      expect(taps, 1);
    });

    testWidgets('does not grow when motion is reduced', (t) async {
      await t.pumpWidget(
        host(
          JumpDownButton(shown: false, count: 0, label: 'Newest', onTap: () {}),
          still: true,
        ),
      );
      final s = t.widget<AnimatedScale>(find.byType(AnimatedScale).first);
      expect(s.scale, 1);
      await settles(t);
    });
  });

  group('reaction chip', () {
    testWidgets('springs once per reaction, then is still', (t) async {
      Widget chip(int n) => host(
        ReactionChip(emoji: '❤️', count: n, popKey: 'uid-a:❤️', mine: true),
      );
      await t.pumpWidget(chip(1));
      await t.pump(const Duration(milliseconds: 150));
      final s = t.widget<ScaleTransition>(under<ScaleTransition>(ReactionChip));
      expect(s.scale.value, greaterThan(1.0));
      await settles(t);
      // built again elsewhere: no second pop
      await t.pumpWidget(host(const SizedBox()));
      await t.pumpWidget(chip(1));
      await still(t);
      // a second person picks the same: the count rolls in
      await t.pumpWidget(chip(2));
      await t.pump(const Duration(milliseconds: 40));
      expect(find.text('2'), findsOneWidget);
      await settles(t);
    });

    testWidgets('only fades when motion is reduced', (t) async {
      await t.pumpWidget(
        host(
          const ReactionChip(emoji: '🔥', count: 1, popKey: 'uid-b:🔥'),
          still: true,
        ),
      );
      await t.pump(const Duration(milliseconds: 40));
      expect(under<ScaleTransition>(ReactionChip), findsNothing);
      await settles(t);
    });
  });

  group('sent tick', () {
    TextStyle label() => const TextStyle(fontSize: 9);
    Widget tick(bool delivered, {bool still = false}) => host(
      SentTick(
        delivered: delivered,
        deliveredLabel: 'Delivered',
        color: Colors.white,
        labelStyle: label(),
      ),
      still: still,
    );

    testWidgets('a receipt grows the word out of the tick', (t) async {
      await t.pumpWidget(tick(false));
      expect(find.text('Delivered'), findsNothing);
      final narrow = t.getSize(find.byType(SentTick)).width;
      await t.pumpWidget(tick(true));
      await t.pump(const Duration(milliseconds: 60));
      final mid = t.getSize(find.byType(SentTick)).width;
      await settles(t);
      final wide = t.getSize(find.byType(SentTick)).width;
      expect(mid, greaterThan(narrow));
      expect(mid, lessThan(wide));
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('already delivered is drawn still', (t) async {
      await t.pumpWidget(tick(true));
      expect(find.text('Delivered'), findsOneWidget);
      await still(t);
    });

    testWidgets('no growing or nodding when motion is reduced', (t) async {
      await t.pumpWidget(tick(false, still: true));
      await t.pumpWidget(tick(true, still: true));
      await t.pump(const Duration(milliseconds: 30));
      final scale = t.widget<Transform>(under<Transform>(SentTick).first);
      expect(scale.transform.isIdentity(), isTrue);
      expect(under<SlideTransition>(SentTick), findsNothing);
      await settles(t);
    });

    testWidgets('the word slides from the mirrored side in rtl', (t) async {
      Widget rtl(bool d) => host(
        SentTick(
          delivered: d,
          deliveredLabel: 'Delivered',
          color: Colors.white,
          labelStyle: label(),
        ),
        dir: TextDirection.rtl,
      );
      await t.pumpWidget(rtl(false));
      await t.pumpWidget(rtl(true));
      await t.pump(const Duration(milliseconds: 40));
      final slide = t.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text('Delivered'),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      expect(slide.position.value.dx, greaterThan(0));
      await settles(t);
    });
  });

  group('grow swap', () {
    testWidgets('folds one thing as the other grows, then rests', (t) async {
      Widget at(bool a) => host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GrowSwap(
              child: a
                  ? const SizedBox(key: ValueKey('a'), width: 40, height: 30)
                  : const SizedBox.shrink(key: ValueKey('b')),
            ),
          ],
        ),
      );
      await t.pumpWidget(at(true));
      await t.pumpWidget(at(false));
      await t.pump(const Duration(milliseconds: 90));
      final h = t.getSize(find.byType(GrowSwap)).height;
      expect(h, greaterThan(0));
      expect(h, lessThan(30));
      await settles(t);
      expect(t.getSize(find.byType(GrowSwap)).height, 0);
    });

    testWidgets('instant when motion is reduced', (t) async {
      Widget at(bool a) => host(
        GrowSwap(
          child: a
              ? const SizedBox(key: ValueKey('a'), width: 40, height: 30)
              : const SizedBox.shrink(key: ValueKey('b')),
        ),
        still: true,
      );
      await t.pumpWidget(at(false));
      await t.pumpWidget(at(true));
      await t.pump();
      expect(t.getSize(find.byType(GrowSwap)).height, 30);
      await settles(t);
    });
  });

  group('message menu', () {
    List<MenuAction> actions(List<String> hit) => [
      MenuAction(
        icon: Icons.delete_outline,
        label: 'Unsend',
        danger: true,
        onTap: () => hit.add('unsend'),
      ),
      MenuAction(icon: Icons.copy_rounded, label: 'Copy', onTap: () {}),
      const MenuAction(icon: Icons.forward, label: 'Forward', onTap: null),
      MenuAction(
        icon: Icons.push_pin_outlined,
        label: 'Pin',
        onTap: () => hit.add('pin'),
      ),
    ];

    testWidgets('rows follow each other in; the one that destroys is last', (
      t,
    ) async {
      final hit = <String>[];
      await t.pumpWidget(host(MessageMenuCard(actions: actions(hit))));
      await t.pump(const Duration(milliseconds: 16));
      double op(String l) => t
          .widget<Opacity>(
            find
                .ancestor(of: find.text(l), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
      expect(op('Copy'), greaterThan(op('Unsend')));
      await settles(t);
      expect(op('Unsend'), 1);
      expect(find.text('Forward'), findsNothing);
      final copy = t.getTopLeft(find.text('Copy')).dy;
      final pin = t.getTopLeft(find.text('Pin')).dy;
      final unsend = t.getTopLeft(find.text('Unsend')).dy;
      expect(copy, lessThan(pin));
      expect(pin, lessThan(unsend));
      await t.tap(find.text('Unsend'));
      await t.tap(find.text('Pin'));
      expect(hit, ['unsend', 'pin']);
      await settles(t);
    });

    testWidgets('all there at once when motion is reduced', (t) async {
      await t.pumpWidget(
        host(MessageMenuCard(actions: actions([])), still: true),
      );
      await t.pump();
      for (final o in t.widgetList<Opacity>(under<Opacity>(MessageMenuCard))) {
        expect(o.opacity, 1);
      }
      await still(t);
    });

    testWidgets('the sheet groups rows and greys what cannot be done', (
      t,
    ) async {
      var picked = '';
      await t.pumpWidget(
        host(
          SingleChildScrollView(
            child: MenuSheet(
              groups: [
                [
                  MenuSheetRow(
                    icon: Icons.person_outline,
                    label: 'View contact',
                    onTap: () => picked = 'contact',
                  ),
                  const MenuSheetRow(
                    icon: Icons.people_outline,
                    label: 'Introduce',
                    sub: 'Accept them first',
                    onTap: null,
                  ),
                ],
                const [],
                [
                  MenuSheetRow(
                    icon: Icons.block,
                    label: 'Block',
                    danger: true,
                    onTap: () => picked = 'block',
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      await settles(t);
      await t.tap(find.text('Introduce'));
      expect(picked, '');
      await t.tap(find.text('Block'));
      expect(picked, 'block');
      expect(find.text('Accept them first'), findsOneWidget);
    });
  });

  group('swipe to reply', () {
    double dx(WidgetTester t) => t
        .widget<Transform>(
          find
              .ancestor(of: find.text('hi'), matching: find.byType(Transform))
              .first,
        )
        .transform
        .getTranslation()
        .x;

    Widget swipe({bool still = false, TextDirection dir = TextDirection.ltr}) =>
        host(
          SwipeToReply(
            onReply: () {},
            child: const SizedBox(width: 300, height: 60, child: Text('hi')),
          ),
          still: still,
          dir: dir,
        );

    testWidgets('springs back a touch past its place, then rests', (t) async {
      await t.pumpWidget(swipe());
      final g = await t.startGesture(t.getCenter(find.text('hi')));
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(const Offset(60, 0));
      await t.pump();
      expect(dx(t), greaterThan(40));
      await g.up();
      var least = 0.0;
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
        final x = dx(t);
        if (x < least) least = x;
      }
      expect(least, lessThan(0));
      await settles(t);
      expect(dx(t), 0);
    });

    testWidgets('goes back at once when motion is reduced', (t) async {
      await t.pumpWidget(swipe(still: true));
      final g = await t.startGesture(t.getCenter(find.text('hi')));
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(const Offset(60, 0));
      await t.pump();
      await g.up();
      await t.pump();
      expect(dx(t), 0);
      await settles(t);
    });

    testWidgets('pulls the other way right to left', (t) async {
      await t.pumpWidget(swipe(dir: TextDirection.rtl));
      final g = await t.startGesture(t.getCenter(find.text('hi')));
      await g.moveBy(const Offset(-30, 0));
      await g.moveBy(const Offset(-40, 0));
      await t.pump();
      expect(dx(t), lessThan(0));
      await g.up();
      await settles(t);
    });
  });

  testWidgets('day chip and unread divider draw in both directions', (t) async {
    for (final dir in TextDirection.values) {
      await t.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [DayChip('Today'), UnreadDivider('New messages')],
          ),
          dir: dir,
        ),
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('New messages'), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });
}
