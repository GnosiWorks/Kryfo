// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop's wide window: a rail of tabs, the list and the chat pane
// side by side, the pane's calm empty page, the divider that drags and
// remembers, and the phone's single page again on a narrow window, with no
// flicker between the two around one width. right to left it mirrors, at
// twice the text it still fits, and a chat's thread keeps a reading width
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart' show appState, AppStateRoute;
import 'package:kryfo/screens/chat_door.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/wide/read_width.dart';
import 'package:kryfo/wide/wide_home.dart';
import 'package:kryfo/wide/wide_pane.dart';
import 'package:kryfo/widgets/nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_chat_fakes.dart';

const _a = 'amber-new-river';
const _b = 'calm-grey-heron';

Widget _home() => ListenableBuilder(
  listenable: appState,
  builder: (context, _) => HomeScreen(
    haloId: 'neon-tiger-saturn',
    contacts: appState.contacts,
    onAddContact: () {},
    onNewGroup: () {},
    onNewRoom: () {},
    onOpenDev: () {},
    onOpenSettingsDirect: () {},
    onOpenChat: (id) => openChatAt(context, peer: id),
    onOpenGroup: (_) {},
  ),
);

Future<void> _open(
  WidgetTester t, {
  Size size = const Size(1280, 800),
  Locale locale = const Locale('en'),
  double scale = 1,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
    ...prefs,
  });
  FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
  appState.sendModeForTest = 'balanced';
  lockState.openForTest();
  await t.runAsync(() => devWorld(chats: [(_a, 5, false), (_b, 3, false)]));
  await devOpen(
    t,
    _home(),
    size: size,
    ratio: 1,
    locale: locale,
    scale: scale,
    still: true,
  );
  await _settle(t);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _resize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

bool _wide() => find.byType(WideRail).evaluate().isNotEmpty;

Finder _onRail(String label) =>
    find.descendant(of: find.byType(WideRail), matching: find.text(label));

Rect _rect(WidgetTester t, Finder f) => t.getRect(f);

// the divider follows from the press, slop included
Future<void> _drag(WidgetTester t, Finder f, double dx) async {
  final g = await t.startGesture(t.getCenter(f));
  await g.moveBy(Offset(dx, 0));
  await t.pump();
  await g.up();
  await t.pump();
}

void main() {
  setUp(() {
    onDesktop = true;
    homeClock = () => DateTime(2026, 10, 29, 12);
    chatPageForTest = ({String? groupId, String? peer, String? uid}) =>
        Scaffold(body: Center(child: Text('chat $peer')));
  });
  tearDown(() {
    onDesktop = false;
    homeClock = DateTime.now;
    chatPageForTest = null;
  });

  testWidgets('a wide window shows rail, list and the empty pane', (t) async {
    await _open(t);
    expect(_wide(), isTrue);
    expect(find.byType(HaloNavBar), findsNothing);
    expect(find.text(l10n.wideSelectChat), findsOneWidget);
    expect(find.text(l10n.wideSelectChatLine), findsOneWidget);
    // every tab on the rail, the open one marked
    for (final tab in shownTabs) {
      expect(_onRail(navTabLabel(tab)), findsOneWidget);
    }
    final rail = _rect(t, find.byType(WideRail));
    expect(rail.left, 0);
    expect(rail.width, kRailWidth);
    // the list at its starting width, the pane the rest
    final pane = _rect(t, find.byType(WideEmpty));
    expect(pane.left, kRailWidth + kListStart + 1);
    expect(pane.right, 1280);
    await devClose(t);
  });

  testWidgets('a chat opens in the pane beside the list, escape closes it', (
    t,
  ) async {
    await _open(t);
    await t.tap(find.text(_a).first);
    await _settle(t);
    expect(find.text('chat $_a'), findsOneWidget);
    // the list stays, and so does the rail
    expect(find.text(_b), findsWidgets);
    expect(_wide(), isTrue);
    expect(wideOnScreen.value, _a);
    final chat = _rect(t, find.text('chat $_a'));
    expect(chat.left, greaterThan(kRailWidth + kListStart));
    // another chat takes its place, not a second page over it
    await t.tap(find.text(_b).first);
    await _settle(t);
    expect(find.text('chat $_b'), findsOneWidget);
    expect(find.text('chat $_a'), findsNothing);
    expect(widePane!.depth.value, 1);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(t);
    expect(find.text('chat $_b'), findsNothing);
    expect(find.text(l10n.wideSelectChat), findsOneWidget);
    expect(wideOnScreen.value, isNull);
    await devClose(t);
  });

  testWidgets('a narrow window is the phone page, the chat over the list', (
    t,
  ) async {
    await _open(t, size: const Size(700, 800));
    expect(_wide(), isFalse);
    expect(find.byType(HaloNavBar), findsOneWidget);
    expect(find.text(l10n.wideSelectChat), findsNothing);
    await t.tap(find.text(_a).first);
    await _settle(t);
    expect(_rect(t, find.byType(Scaffold).last).width, 700);
    // widened with the chat open, the chat stays open beside the list
    await _resize(t, const Size(1280, 800));
    await _settle(t);
    expect(_wide(), isTrue);
    expect(find.text('chat $_a'), findsOneWidget);
    expect(find.byType(HaloNavBar), findsNothing);
    await devClose(t);
  });

  testWidgets('crossing one width back and forth does not flicker', (t) async {
    await _open(t);
    expect(_wide(), isTrue);
    await _resize(t, const Size(kWideEnter - 20, 800));
    expect(_wide(), isTrue, reason: 'still above the way back');
    await _resize(t, const Size(kWideLeave - 1, 800));
    expect(_wide(), isFalse);
    await _resize(t, const Size(kWideEnter - 20, 800));
    expect(_wide(), isFalse, reason: 'not yet at the way in');
    await _resize(t, const Size(kWideEnter, 800));
    expect(_wide(), isTrue);
    expect(wideAt(kWideEnter - 1, was: false), isFalse);
    expect(wideAt(kWideLeave, was: true), isTrue);
    await devClose(t);
  });

  testWidgets('the divider drags, keeps its bounds and is remembered', (
    t,
  ) async {
    await _open(t);
    final divider = find.byType(ListDivider);
    // a tenth wider than the least, at first
    expect(kListStart, 396);
    expect(_rect(t, find.byType(WideEmpty)).left, kRailWidth + kListStart + 1);
    await _drag(t, divider, 20);
    await _settle(t);
    expect(_rect(t, find.byType(WideEmpty)).left, kRailWidth + 416 + 1);
    final p = await SharedPreferences.getInstance();
    expect(p.getDouble('wide_list_width'), 416);
    // never past its widest
    await _drag(t, divider, 300);
    await _settle(t);
    expect(_rect(t, find.byType(WideEmpty)).left, kRailWidth + kListMax + 1);
    // the keyboard moves it too
    await _drag(t, divider, -500);
    await _settle(t);
    expect(_rect(t, find.byType(WideEmpty)).left, kRailWidth + kListMin + 1);
    final h = t.ensureSemantics();
    final node = t.getSemantics(find.bySemanticsLabel(l10n.wideListWidth));
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await _settle(t);
    expect(
      _rect(t, find.byType(WideEmpty)).left,
      kRailWidth + kListMin + 16 + 1,
    );
    h.dispose();
    await devClose(t);
  });

  testWidgets('a divider drag rebuilds neither the list nor the pane', (
    t,
  ) async {
    await _open(t);
    await t.tap(find.text(_a).first);
    await _settle(t);
    Widget keyed(String label) => t.widget(
      find.byWidgetPredicate(
        (w) => w is KeyedSubtree && '${w.key}'.contains(label),
      ),
    );
    final list = keyed('wide list');
    final pane = keyed('wide pane');
    final nav = t.widget(find.byKey(widePane!.key));
    final rail = t.widget(find.byType(WideRail));
    final g = await t.startGesture(t.getCenter(find.byType(ListDivider)));
    for (var i = 0; i < 4; i++) {
      await g.moveBy(const Offset(4, 0));
      await t.pump();
    }
    expect(identical(keyed('wide list'), list), isTrue);
    expect(identical(keyed('wide pane'), pane), isTrue);
    expect(identical(t.widget(find.byKey(widePane!.key)), nav), isTrue);
    expect(identical(t.widget(find.byType(WideRail)), rail), isTrue);
    await g.up();
    await _settle(t);
    final page = find.ancestor(
      of: find.text('chat $_a'),
      matching: find.byType(Scaffold),
    );
    expect(_rect(t, page.first).left, kRailWidth + kListStart + 16 + 1);
    await devClose(t);
  });

  testWidgets('the screen reader hears only widths the divider reaches', (
    t,
  ) async {
    await _open(t, prefs: {'wide_list_width': kListMax});
    final h = t.ensureSemantics();
    var d = t
        .getSemantics(find.bySemanticsLabel(l10n.wideListWidth))
        .getSemanticsData();
    expect(d.value, '${kListMax.round()}');
    expect(d.increasedValue, '${kListMax.round()}');
    expect(d.decreasedValue, '${(kListMax - 16).round()}');
    await _drag(t, find.byType(ListDivider), -500);
    await _settle(t);
    d = t
        .getSemantics(find.bySemanticsLabel(l10n.wideListWidth))
        .getSemanticsData();
    expect(d.decreasedValue, '${kListMin.round()}');
    h.dispose();
    await devClose(t);
  });

  testWidgets('a width dragged before the wider start stays as it was', (
    t,
  ) async {
    await _open(t, prefs: {'wide_list_width': 360.0});
    expect(_rect(t, find.byType(WideEmpty)).left, kRailWidth + 360 + 1);
    await devClose(t);
  });

  testWidgets('a remembered width comes back, fitted to the window', (t) async {
    await _open(t, prefs: {'wide_list_width': 410.0});
    expect(_rect(t, find.byType(WideEmpty)).left, kRailWidth + 410 + 1);
    // a smaller window leaves the pane its room
    await _resize(t, const Size(860, 800));
    await _settle(t);
    expect(_wide(), isTrue);
    expect(
      _rect(t, find.byType(WideEmpty)).left,
      kRailWidth + (860 - kRailWidth - kPaneMin) + 1,
    );
    expect(listWidthIn(860, 410), 860 - kRailWidth - kPaneMin);
    expect(listWidthIn(2000, 100), kListMin);
    await devClose(t);
  });

  testWidgets('right to left the rail is on the right, the pane on the left', (
    t,
  ) async {
    for (final loc in const [Locale('ar'), Locale('fa')]) {
      await _open(t, locale: loc);
      final rail = _rect(t, find.byType(WideRail));
      expect(rail.right, 1280);
      final pane = _rect(t, find.byType(WideEmpty));
      expect(pane.left, 0);
      expect(pane.right, 1280 - kRailWidth - kListStart - 1);
      expect(find.text(l10n.wideSelectChat), findsOneWidget);
      // dragging towards the pane, to the left here, widens the list
      await _drag(t, find.byType(ListDivider), -16);
      await _settle(t);
      expect(
        _rect(t, find.byType(WideEmpty)).right,
        1280 - kRailWidth - (kListStart + 16) - 1,
      );
      await devClose(t);
      SharedPreferences.setMockInitialValues({});
    }
  });

  testWidgets('twice the text still fits, wide and narrow', (t) async {
    await _open(t, scale: 2);
    expect(_wide(), isTrue);
    expect(t.takeException(), isNull);
    await _resize(t, const Size(700, 800));
    await _settle(t);
    expect(t.takeException(), isNull);
    await devClose(t);
  });

  testWidgets('a thread keeps its reading width, the phone never asks', (
    t,
  ) async {
    double? side;
    double? width;
    Widget probe() => Directionality(
      textDirection: TextDirection.ltr,
      child: ReadWidth(
        builder: (c, s) {
          side = s;
          width = MediaQuery.sizeOf(c).width;
          return const SizedBox.expand();
        },
      ),
    );
    t.view.physicalSize = const Size(1400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1400, 800)),
        child: probe(),
      ),
    );
    expect(side, (1400 - kReadWidth) / 2);
    expect(width, kReadWidth);
    onDesktop = false;
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1400, 800)),
        child: probe(),
      ),
    );
    expect(side, 0);
    expect(width, 1400);
    expect(readLines(const [SizedBox()]).single, isA<SizedBox>());
  });

  testWidgets('the rail is reached by keyboard and picks a tab', (t) async {
    await _open(t);
    final me = _onRail(navTabLabel(HaloTab.me));
    expect(me, findsOneWidget);
    await t.tap(me);
    await _settle(t);
    final picked = t.widget<NavTab>(
      find.ancestor(of: me, matching: find.byType(NavTab)),
    );
    expect(picked.on, isTrue);
    // the pane is still there beside it
    expect(find.text(l10n.wideSelectChat), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WideRail),
        matching: find.byType(Tooltip),
      ),
      findsNWidgets(shownTabs.length),
    );
    // tab reaches the rail's tabs, enter picks one
    Focus.of(t.element(_onRail(navTabLabel(HaloTab.chats)))).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(t);
    expect(
      t
          .widget<NavTab>(
            find.ancestor(
              of: _onRail(navTabLabel(HaloTab.chats)),
              matching: find.byType(NavTab),
            ),
          )
          .on,
      isTrue,
    );
    await devClose(t);
  });

  testWidgets('up and down walk the list, enter opens the row', (t) async {
    await _open(t);
    final ya = t.getCenter(find.text(_a).first).dy;
    final yb = t.getCenter(find.text(_b).first).dy;
    final (top, under) = ya < yb ? (_a, _b) : (_b, _a);
    Focus.of(t.element(find.text(top).first)).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(
        of: find.byElementPredicate((e) => e == focused),
        matching: find.text(under),
      ),
      findsOneWidget,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(t);
    expect(find.text('chat $under'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await devClose(t);
  });
}
