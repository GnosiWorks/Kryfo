import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/nav_bar.dart';

Widget host({
  required HaloTab active,
  ValueChanged<HaloTab>? onPick,
  VoidCallback? onMeLongPress,
  double textScale = 1,
  bool still = false,
  double width = 360,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 640),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: still,
    ),
    child: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: width,
          child: HaloNavBar(
            active: active,
            onPick: onPick ?? (_) {},
            onMeLongPress: onMeLongPress,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('four tabs, tools second, equal widths', (t) async {
    await t.pumpWidget(host(active: HaloTab.chats));
    final xs = [
      for (final l in ['Chats', 'Tools', 'Support', 'Me'])
        t.getCenter(find.text(l)).dx,
    ];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i] - xs[i - 1], closeTo((360 - 12) / 4, 0.5));
    }
  });

  testWidgets('a tap picks, a long press on me opens dev and nowhere else', (
    t,
  ) async {
    final picked = <HaloTab>[];
    var dev = 0;
    await t.pumpWidget(
      host(
        active: HaloTab.chats,
        onPick: picked.add,
        onMeLongPress: () => dev++,
      ),
    );
    await t.tap(find.text('Tools'));
    await t.tap(find.text('Me'));
    expect(picked, [HaloTab.tools, HaloTab.me]);
    await t.longPress(find.text('Support'));
    expect(dev, 0);
    await t.longPress(find.text('Me'));
    expect(dev, 1);
  });

  testWidgets('talkback: one button a tab, the open one says selected', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(host(active: HaloTab.tools));
    expect(
      t.getSemantics(find.bySemanticsLabel('Tools')),
      matchesSemantics(
        label: 'Tools',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('Chats')),
      matchesSemantics(
        label: 'Chats',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Support'), findsOneWidget);
    h.dispose();
  });

  testWidgets('the biggest system font fits a narrow phone', (t) async {
    await t.pumpWidget(host(active: HaloTab.support, textScale: 2, width: 320));
    expect(t.takeException(), isNull);
    final box = find.ancestor(
      of: find.text('Support'),
      matching: find.byType(FittedBox),
    );
    expect(t.getSize(box).width, lessThanOrEqualTo((320 - 12) / 4));
  });

  testWidgets('the pill pops in, and lands inside 300 ms', (t) async {
    await t.pumpWidget(host(active: HaloTab.chats));
    await t.pumpWidget(host(active: HaloTab.tools));
    await t.pump(const Duration(milliseconds: 140));
    final mid = t.getSize(find.byType(HaloNavBar));
    await t.pump(const Duration(milliseconds: 160));
    expect(t.hasRunningAnimations, false);
    expect(t.getSize(find.byType(HaloNavBar)), mid);
  });

  testWidgets('reduced motion: nothing animates', (t) async {
    await t.pumpWidget(host(active: HaloTab.chats, still: true));
    await t.pumpWidget(host(active: HaloTab.me, still: true));
    await t.pump();
    expect(t.hasRunningAnimations, false);
  });
}
