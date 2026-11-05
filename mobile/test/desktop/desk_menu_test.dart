// SPDX-License-Identifier: GPL-3.0-or-later
// a computer's right-click menu: at the mouse, nothing dimmed behind it,
// kept inside the window at every edge, opened by the menu key and
// shift+f10 at the focused item, arrows and enter and esc inside it, the
// reactions on top, the rows that take something away in rose, words a
// reader can hear, its contrast in both themes. the phone keeps its sheet
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/desk_menu.dart';
import 'package:kryfo/widgets/message_menu.dart';
import 'package:kryfo/widgets/press_scale.dart';

double _ratio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

Color _over(Color top, Color under) => Color.alphaBlend(top, under);

final _picked = <String>[];

List<List<DeskMenuItem>> _groups() => [
  [
    DeskMenuItem(
      icon: Icons.push_pin_outlined,
      label: 'Pin',
      onTap: () => _picked.add('pin'),
    ),
    DeskMenuItem(
      icon: Icons.copy_rounded,
      label: 'Copy',
      onTap: () => _picked.add('copy'),
    ),
  ],
  [
    DeskMenuItem(
      icon: Icons.delete_outline,
      label: 'Unsend',
      danger: true,
      onTap: () => _picked.add('unsend'),
    ),
  ],
];

Widget _app({
  bool still = false,
  bool full = false,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: Directionality(textDirection: dir, child: c!),
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) {
        void open() => showDeskMenu<void>(
          context,
          label: 'Message actions',
          groups: (_) => _groups(),
          reactions: DeskReactions(
            emojis: const ['❤️', '👍'],
            selected: null,
            onPick: (e) => _picked.add(e),
          ),
        );
        return SizedBox.expand(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(full ? 0 : 40),
              child: PressScale(
                key: const ValueKey('target'),
                onTap: () {},
                onLongPress: open,
                child: SizedBox(
                  width: full ? double.infinity : 200,
                  height: full ? double.infinity : 40,
                  child: const Text('a row'),
                ),
              ),
            ),
          ),
        );
      },
    ),
  ),
);

Future<void> _rightClick(WidgetTester t, Offset at) async {
  await t.tapAt(
    at,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await t.pumpAndSettle();
}

Rect _menuRect(WidgetTester t) =>
    t.getRect(find.byKey(const ValueKey('desk menu')));

void main() {
  setUp(() {
    onDesktop = true;
    lockState.openForTest();
    _picked.clear();
    DeskMenuAt.forget();
  });
  tearDown(() {
    onDesktop = false;
    HaloColors.setLight(false);
  });

  group('the spot', () {
    const area = Size(800, 600);
    const menu = Size(200, 300);
    test('down and to the end of the mouse when it fits', () {
      expect(
        deskMenuSpot(area: area, menu: menu, point: const Offset(100, 100)),
        const Offset(100, 100),
      );
    });
    test('the right edge: it opens to the mouse\'s left', () {
      expect(
        deskMenuSpot(area: area, menu: menu, point: const Offset(750, 100)).dx,
        550,
      );
    });
    test('the bottom edge: it opens over the mouse', () {
      expect(
        deskMenuSpot(area: area, menu: menu, point: const Offset(100, 580)).dy,
        280,
      );
    });
    test('the left and top edges: never past the gap', () {
      final o = deskMenuSpot(area: area, menu: menu, point: const Offset(2, 1));
      expect(o, const Offset(8, 8));
    });
    test('a window too short: the top of it, inside the gap', () {
      final o = deskMenuSpot(
        area: const Size(800, 200),
        menu: menu,
        point: const Offset(100, 150),
      );
      expect(o.dy, 8);
    });
    test('the corner: both flip', () {
      final o = deskMenuSpot(
        area: area,
        menu: menu,
        point: const Offset(790, 590),
      );
      expect(o, const Offset(590, 290));
    });
    test('right to left: it opens to the mouse\'s left, flips at the edge', () {
      const rtl = TextDirection.rtl;
      expect(
        deskMenuSpot(
          area: area,
          menu: menu,
          point: const Offset(400, 100),
          dir: rtl,
        ).dx,
        200,
      );
      expect(
        deskMenuSpot(
          area: area,
          menu: menu,
          point: const Offset(50, 100),
          dir: rtl,
        ).dx,
        50,
      );
    });
    test('a key: under the item, over it where there is no room', () {
      expect(
        deskMenuSpot(
          area: area,
          menu: menu,
          rect: const Rect.fromLTWH(40, 40, 200, 40),
        ),
        const Offset(40, 84),
      );
      expect(
        deskMenuSpot(
          area: area,
          menu: menu,
          rect: const Rect.fromLTWH(40, 500, 200, 40),
        ),
        const Offset(40, 196),
      );
    });
  });

  testWidgets('a right click opens it at the mouse, nothing dimmed', (t) async {
    await t.pumpWidget(_app());
    await _rightClick(t, const Offset(60, 50));
    expect(find.byType(DeskMenu), findsOneWidget);
    expect(_menuRect(t).topLeft, const Offset(60, 50));
    // no dim and no blur behind it, the long press's lifted bubble neither
    final barriers = t.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    for (final b in barriers) {
      expect(b.color == null || b.color!.a == 0, isTrue);
    }
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(MessageMenuCard), findsNothing);
  });

  testWidgets('near every edge the whole menu stays in the window', (t) async {
    await t.pumpWidget(_app(full: true));
    final size = t.view.physicalSize / t.view.devicePixelRatio;
    final win = Offset.zero & size;
    for (final at in [
      Offset(size.width - 3, 60),
      Offset(60, size.height - 3),
      Offset(size.width - 3, size.height - 3),
      const Offset(1, 1),
    ]) {
      await _rightClick(t, at);
      final r = _menuRect(t);
      expect(win.deflate(7.9).contains(r.topLeft), isTrue, reason: '$at $r');
      expect(
        win.deflate(7.9).contains(r.bottomRight),
        isTrue,
        reason: '$at $r',
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(DeskMenu), findsNothing);
    }
  });

  testWidgets('a click elsewhere or a right click elsewhere closes it', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await _rightClick(t, const Offset(60, 50));
    await t.tapAt(const Offset(700, 500));
    await t.pumpAndSettle();
    expect(find.byType(DeskMenu), findsNothing);
    await _rightClick(t, const Offset(60, 50));
    await _rightClick(t, const Offset(700, 500));
    expect(find.byType(DeskMenu), findsNothing);
    expect(_picked, isEmpty);
  });

  for (final key in ['menu', 'shift+f10']) {
    testWidgets('the $key key opens it at the focused item', (t) async {
      await t.pumpWidget(_app());
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      if (key == 'menu') {
        await t.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      } else {
        await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await t.sendKeyEvent(LogicalKeyboardKey.f10);
        await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      }
      await t.pumpAndSettle();
      expect(find.byType(DeskMenu), findsOneWidget);
      final item = t.getRect(find.byKey(const ValueKey('target')));
      final r = _menuRect(t);
      expect(r.left, item.left);
      expect(r.top, item.bottom + 4);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(DeskMenu), findsNothing);
      expect(_picked, isEmpty);
    });
  }

  testWidgets('arrows move through it and enter picks', (t) async {
    await t.pumpWidget(_app());
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await t.pumpAndSettle();
    // the first reaction has focus: right to the second, down to pin and
    // copy, up to pin again
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(_picked, ['pin']);
    expect(find.byType(DeskMenu), findsNothing);
  });

  testWidgets('a click on a reaction reacts and closes it', (t) async {
    await t.pumpWidget(_app());
    await _rightClick(t, const Offset(60, 50));
    expect(find.byKey(const ValueKey('desk menu reactions')), findsOneWidget);
    // the reactions come first, as on the phone's bar
    expect(
      t.getRect(find.text('👍')).top < t.getRect(find.text('Pin')).top,
      isTrue,
    );
    await t.tap(find.text('👍'));
    await t.pumpAndSettle();
    expect(_picked, ['👍']);
    expect(find.byType(DeskMenu), findsNothing);
  });

  testWidgets('the mouse lights the row under it', (t) async {
    await t.pumpWidget(_app());
    final g = await t.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await g.addPointer(location: const Offset(60, 50));
    await g.down(const Offset(60, 50));
    await g.up();
    await t.pumpAndSettle();
    await g.moveTo(t.getCenter(find.text('Copy')));
    await t.pumpAndSettle();
    final lit = t.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('Copy'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect((lit.decoration as BoxDecoration).color, deskMenuWash());
    await g.removePointer();
  });

  testWidgets('the rows that take something away are rose, set apart, last', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await _rightClick(t, const Offset(60, 50));
    final words = t.widget<Text>(find.text('Unsend'));
    expect(words.style!.color, HaloColors.roseText);
    expect(
      t.getRect(find.text('Unsend')).top > t.getRect(find.text('Copy')).top,
      isTrue,
    );
  });

  testWidgets('a reader hears its name and each row as a button', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_app());
    await _rightClick(t, const Offset(60, 50));
    expect(find.bySemanticsLabel('Message actions'), findsOneWidget);
    final pin = t.getSemantics(find.bySemanticsLabel('Pin'));
    expect(pin.flagsCollection.isButton, isTrue);
    expect(find.bySemanticsLabel('Unsend'), findsOneWidget);
    h.dispose();
  });

  testWidgets('a subtle grow in; none at all with reduced motion', (t) async {
    await t.pumpWidget(_app());
    await t.tapAt(
      const Offset(60, 50),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 30));
    final mid = t.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(DeskMenu),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(mid.opacity.value, inExclusiveRange(0, 1));
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();

    await t.pumpWidget(_app(still: true));
    await t.tapAt(
      const Offset(60, 50),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await t.pump();
    await t.pump();
    expect(find.byType(DeskMenu), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(DeskMenu),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
  });

  for (final light in [false, true]) {
    test('its words keep their contrast in ${light ? 'light' : 'dark'}', () {
      HaloColors.setLight(light);
      final ground = HaloColors.surface2;
      final lit = _over(deskMenuWash(), ground);
      final rose = _over(deskMenuWash(danger: true), ground);
      for (final (what, ink, on) in [
        ('words', HaloColors.text, ground),
        ('words lit', HaloColors.text, lit),
        ('second line', HaloColors.text2, ground),
        ('second line lit', HaloColors.text2, lit),
        ('rose', HaloColors.roseText, ground),
        ('rose lit', HaloColors.roseText, rose),
        ('amber words', HaloColors.amberText, ground),
        ('amber words lit', HaloColors.amberText, lit),
        ('violet words', HaloColors.violetText, lit),
      ]) {
        expect(_ratio(ink, on), greaterThanOrEqualTo(4.5), reason: what);
      }
      // the check is an icon: 3 to 1
      expect(_ratio(HaloColors.amberText, lit), greaterThanOrEqualTo(3));
    });
  }

  testWidgets('a row\'s menu on a computer is the small menu', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final a = await showMenuSheet<String>(
                  context,
                  groups: (ctx) => [
                    [
                      MenuSheetRow(
                        icon: Icons.archive_outlined,
                        label: 'Archive',
                        onTap: () => Navigator.pop(ctx, 'archive'),
                      ),
                    ],
                  ],
                );
                if (a != null) _picked.add(a);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(DeskMenu), findsOneWidget);
    expect(find.byType(MenuSheet), findsNothing);
    await t.tap(find.text('Archive'));
    await t.pumpAndSettle();
    expect(_picked, ['archive']);
    expect(find.byType(DeskMenu), findsNothing);

    // the phone: its sheet, as before
    onDesktop = false;
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(MenuSheet), findsOneWidget);
    expect(find.byType(DeskMenu), findsNothing);
  });
}
