// SPDX-License-Identifier: GPL-3.0-or-later
// a chat row's swipe: the glyph behind grows with the drag and lights with
// a click once the swipe counts, the row slides back and the action runs.
// mirrored in a right-to-left language, still with less movement, and at
// rest afterwards.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/swipe_actions.dart';

Widget host(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: Directionality(textDirection: dir, child: c!),
  ),
  home: Scaffold(
    body: Align(alignment: Alignment.topCenter, child: child),
  ),
);

Future<void> settles(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(t.binding.transientCallbackCount, 0);
}

void main() {
  late List<String> done;
  late int clicks;

  setUp(() {
    done = [];
    clicks = 0;
  });

  void listen(WidgetTester t) {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'HapticFeedback.vibrate') clicks++;
      return null;
    });
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  Widget row() => SizedBox(
    width: 400,
    child: SwipeActions(
      rowKey: const ValueKey('row'),
      start: SwipeAction(
        icon: Icons.notifications_off_outlined,
        label: 'Mute',
        color: Colors.grey.shade300,
        ink: Colors.black,
        onDone: () async => done.add('mute'),
      ),
      end: SwipeAction(
        icon: Icons.archive_outlined,
        label: 'Archive',
        color: Colors.amber,
        ink: Colors.black,
        onDone: () async => done.add('archive'),
      ),
      child: const ColoredBox(
        color: Colors.black,
        child: SizedBox(height: 64, width: 400, child: Text('Wren')),
      ),
    ),
  );

  double glyphScale(WidgetTester t, IconData icon) => t
      .widget<Transform>(
        find
            .ancestor(of: find.byIcon(icon), matching: find.byType(Transform))
            .first,
      )
      .transform
      .storage[0];

  Color round(WidgetTester t, IconData icon) {
    final box = t.widget<AnimatedContainer>(
      find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  testWidgets('the glyph grows with the drag and lights once it counts', (
    t,
  ) async {
    listen(t);
    await t.pumpWidget(host(row()));
    final home = t.getTopLeft(find.text('Wren')).dx;
    final g = await t.startGesture(t.getCenter(find.text('Wren')));
    await g.moveBy(const Offset(-30, 0));
    await g.moveBy(const Offset(-30, 0));
    await t.pump();
    final early = glyphScale(t, Icons.archive_outlined);
    expect(early, lessThan(1));
    expect(round(t, Icons.archive_outlined), isNot(Colors.amber));
    await g.moveBy(const Offset(-80, 0));
    await g.moveBy(const Offset(-60, 0));
    await t.pump();
    expect(glyphScale(t, Icons.archive_outlined), greaterThan(early));
    expect(clicks, 1);
    await t.pump(const Duration(milliseconds: 200));
    expect(round(t, Icons.archive_outlined), Colors.amber);
    await g.up();
    await settles(t);
    expect(done, ['archive']);
    // it slid back: the row is where it was
    expect(t.getTopLeft(find.text('Wren')).dx, home);
  });

  testWidgets('a short swipe does nothing and slides back', (t) async {
    listen(t);
    await t.pumpWidget(host(row()));
    await t.drag(find.text('Wren'), const Offset(60, 0));
    await settles(t);
    expect(done, isEmpty);
    expect(clicks, 0);
  });

  testWidgets('right to left: a swipe to the left is the start action', (
    t,
  ) async {
    listen(t);
    await t.pumpWidget(host(row(), dir: TextDirection.rtl));
    await t.drag(find.text('Wren'), const Offset(-260, 0));
    await settles(t);
    expect(done, ['mute']);
  });

  testWidgets('reduced motion: the glyph is simply there', (t) async {
    listen(t);
    await t.pumpWidget(host(row(), still: true));
    final g = await t.startGesture(t.getCenter(find.text('Wren')));
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(20, 0));
    await t.pump();
    expect(glyphScale(t, Icons.notifications_off_outlined), 1);
    await g.up();
    await settles(t);
  });
}
