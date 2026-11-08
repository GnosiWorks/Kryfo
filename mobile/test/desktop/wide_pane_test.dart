// SPDX-License-Identifier: GPL-3.0-or-later
// real chats in the desktop's pane: a notification opens its chat there
// and marks it, ctrl+f and esc act on the open chat first, the head has no
// back arrow beside the list, typed words survive a narrow window, the lock
// covers list and pane, and a new session starts with nothing marked
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_layer.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        AppStateRefresh,
        AppStateRoute,
        appState,
        openNotifChat,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/screens/chat_door.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/wide/wide_home.dart';
import 'package:kryfo/wide/wide_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mem_db.dart';
import '../say_hi_fakes.dart';
import '../sticker_test_util.dart';

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

// the lock's state, as the app's lock tells it
class _Lock extends ChangeNotifier {
  bool locked = false;
  void set(bool v) {
    locked = v;
    notifyListeners();
  }
}

Widget _app(Widget home, {_Lock? lock}) => MaterialApp(
  locale: const Locale('en'),
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) {
    final app = MediaQuery(
      data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
      child: child!,
    );
    if (lock == null) return app;
    return LockLayer(
      app: app,
      lock: lock,
      loaded: () => true,
      locked: () => lock.locked,
      pad: (_) => const Center(child: Text('pad')),
    );
  },
  home: home,
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 200));
  }
  await t.pump(const Duration(seconds: 1));
}

Future<void> _open(WidgetTester t, {_Lock? lock}) async {
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
  });
  FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
  appState.sendModeForTest = 'balanced';
  useEngineForTest(SayHiRelay());
  lockState.openForTest();
  final docs = Directory.systemTemp.createTempSync('wide_pane');
  addTearDown(() => docs.deleteSync(recursive: true));
  mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
  addTearDown(() => mockChannel('plugins.flutter.io/path_provider', null));
  mockChannel('com.llfbandit.record/messages', (_) async => null);
  useLibrary();
  await t.runAsync(() async {
    final m = MemDb();
    await devChatTables(m, now: 1);
    for (final (id, seen) in [(_a, 5), (_b, 3)]) {
      await m.insert('contacts', {
        'halo_id': id,
        'onion': '',
        'xpub': 'ab' * 32,
        'first_seen': 1,
        'last_seen': seen,
        'accepted': 1,
        'back_paired': 1,
      });
      await m.insert('messages', {
        'peer_id': id,
        'direction': 'in',
        'plaintext': 'hello from $id',
        'msg_uid': 'u-$id',
        'sent_at': seen * 1000,
      });
    }
    final db = SayHiDb(m, HaloContainer.everyday);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });
  t.view.physicalSize = const Size(1280, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final bin = t.binding.defaultBinaryMessenger;
  bin.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(
    () => bin.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  setL10nLocale(const Locale('en'));
  await t.pumpWidget(_app(_home(), lock: lock));
  await _settle(t);
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

Future<void> _resize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  await t.pump();
  await _settle(t);
}

// a row of the list, by its name
Finder _row(String id) =>
    find.descendant(of: find.byType(WideMark), matching: find.text(id)).first;

Finder _chat(String id) =>
    find.byWidgetPredicate((w) => w is ChatScreen && w.peerHaloId == id);

// a row read out as selected, by its name
bool _marked(WidgetTester t, String id) => find.semantics
    .byFlag(SemanticsFlag.isSelected)
    .evaluate()
    .any((n) => n.getSemanticsData().label.contains(id));

Future<void> _openRow(WidgetTester t, String id) async {
  await t.tap(_row(id));
  await _settle(t);
  expect(_chat(id), findsOneWidget);
}

double _contrast(Color x, Color y) {
  final a = x.computeLuminance(), b = y.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

// the mark's ground on row [id], and how far it shows
(BoxDecoration, double) _mark(WidgetTester t, String id) {
  final mark = find.ancestor(
    of: find.text(id).first,
    matching: find.byType(WideMark),
  );
  final ground = find.descendant(
    of: mark,
    matching: find.byKey(const ValueKey('wide-mark')),
  );
  final fade = t.widget<AnimatedOpacity>(
    find.ancestor(of: ground, matching: find.byType(AnimatedOpacity)).first,
  );
  final box = t.widget<Container>(ground).decoration! as BoxDecoration;
  return (box, fade.opacity);
}

void main() {
  setUp(() => onDesktop = true);
  tearDown(() => onDesktop = false);

  testWidgets('the open chat\'s row is tinted, with the accent at its start, '
      'and the tint follows the chat', (t) async {
    final h = t.ensureSemantics();
    await _open(t);
    expect(_mark(t, _a).$2, 0);
    await _openRow(t, _a);
    final (box, shown) = _mark(t, _a);
    expect(shown, 1);
    expect(box.color, HaloColors.surface3);
    expect(_mark(t, _b).$2, 0);
    expect(_marked(t, _a), isTrue);
    await _openRow(t, _b);
    expect(_mark(t, _b).$2, 1);
    expect(_mark(t, _a).$2, 0);
    expect(_marked(t, _a), isFalse);
    expect(_marked(t, _b), isTrue);
    // closed with esc: nothing marked
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(t);
    expect(_mark(t, _b).$2, 0);
    expect(_marked(t, _b), isFalse);
    h.dispose();
    await _close(t);
  });

  testWidgets('by keyboard: a row reached and opened with enter is marked', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await _open(t);
    Focus.of(t.element(find.text(_b).first)).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(t);
    expect(_chat(_b), findsOneWidget);
    expect(_marked(t, _b), isTrue);
    expect(_mark(t, _b).$2, 1);
    h.dispose();
    await _close(t);
  });

  test('the mark reads in both themes, whatever the accent', () {
    addTearDown(() {
      HaloColors.setLight(false);
      HaloColors.setAccent(HaloAccent.yellow);
    });
    for (final light in [false, true]) {
      HaloColors.setLight(light);
      for (final a in HaloAccent.values) {
        HaloColors.setAccent(a);
        final g = wideMarkGround();
        final why = '${light ? 'light' : 'dark'} ${a.name}';
        // the row's words on the raised ground
        for (final c in [HaloColors.text, HaloColors.text2, HaloColors.text3]) {
          expect(_contrast(c, g), greaterThanOrEqualTo(4.5), reason: why);
        }
        // the bar is what tells the row apart: 3:1 for a mark
        expect(
          _contrast(wideMarkBar(), g),
          greaterThanOrEqualTo(3),
          reason: why,
        );
        // and the ground is not the list's own
        expect(g, isNot(HaloColors.surface), reason: why);
      }
    }
  });

  testWidgets('a notification opens its chat in the pane, marked, unstacked', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await _open(t);
    await _openRow(t, _a);
    await t.runAsync(() => openNotifChat(_b, null));
    await _settle(t);
    expect(_chat(_b), findsOneWidget);
    expect(_chat(_a), findsNothing);
    expect(widePane!.depth.value, 1, reason: 'in place of the open one');
    expect(wideOnScreen.value, _b);
    expect(_marked(t, _b), isTrue);
    expect(_marked(t, _a), isFalse);
    // the same chat again is not opened twice
    await t.runAsync(() => openNotifChat(_b, null));
    await _settle(t);
    expect(widePane!.depth.value, 1);
    h.dispose();
    await _close(t);
  });

  testWidgets('a new session starts with no chat marked', (t) async {
    await _open(t);
    await _openRow(t, _a);
    expect(wideOnScreen.value, _a);
    // the session switch renews the navigator: a new home, a new pane
    await t.pumpWidget(_app(KeyedSubtree(key: UniqueKey(), child: _home())));
    await _settle(t);
    expect(wideOnScreen.value, isNull);
    expect(widePane!.depth.value, 0);
    final h = t.ensureSemantics();
    expect(_marked(t, _a), isFalse);
    h.dispose();
    await _close(t);
  });

  testWidgets('ctrl+f searches the open chat, esc closes that search first', (
    t,
  ) async {
    await _open(t);
    // nothing open: esc is left for others
    expect(await t.sendKeyEvent(LogicalKeyboardKey.escape), isFalse);
    await _openRow(t, _a);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(t);
    expect(find.byType(SearchHead), findsOneWidget);
    expect(widePane!.depth.value, 1, reason: 'no global search over it');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(t);
    expect(find.byType(SearchHead), findsNothing);
    expect(_chat(_a), findsOneWidget, reason: 'the chat stays');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(t);
    expect(_chat(_a), findsNothing);
    // with no chat open, ctrl+f is the global search
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(t);
    expect(widePane!.depth.value, 1);
    expect(find.byType(SearchHead), findsNothing);
    await _close(t);
  });

  testWidgets('no back arrow beside the list, one on a narrow window', (
    t,
  ) async {
    await _open(t);
    await _openRow(t, _a);
    Finder back() => find.descendant(
      of: _chat(_a),
      matching: find.byTooltip(l10n.commonBack),
    );
    expect(back(), findsNothing);
    await _resize(t, const Size(700, 800));
    expect(back(), findsOneWidget);
    await t.tap(back());
    await _settle(t);
    expect(_chat(_a), findsNothing);
    expect(find.text(_b), findsWidgets, reason: 'the list again');
    await _close(t);
  });

  testWidgets('a chat with words typed keeps them from wide to narrow', (
    t,
  ) async {
    await _open(t);
    await _openRow(t, _a);
    final field = find.descendant(
      of: _chat(_a),
      matching: find.byType(EditableText),
    );
    await t.enterText(field, 'half a thought');
    await t.pump();
    final state = t.state(_chat(_a));
    await _resize(t, const Size(700, 800));
    expect(find.byType(WideRail), findsNothing);
    expect(t.getRect(_chat(_a)).width, 700, reason: 'over the list');
    expect(identical(t.state(_chat(_a)), state), isTrue);
    expect(find.text('half a thought'), findsOneWidget);
    await _resize(t, const Size(1280, 800));
    expect(find.byType(WideRail), findsOneWidget);
    expect(identical(t.state(_chat(_a)), state), isTrue);
    expect(find.text('half a thought'), findsOneWidget);
    expect(wideOnScreen.value, _a);
    await _close(t);
  });

  testWidgets('the lock covers list and pane, and lifts back to both', (
    t,
  ) async {
    final lock = _Lock();
    final h = t.ensureSemantics();
    await _open(t, lock: lock);
    await _openRow(t, _a);
    final state = t.state(_chat(_a));
    await t.tap(
      find.descendant(of: _chat(_a), matching: find.byType(EditableText)),
    );
    await t.pump();
    lock.set(true);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('pad'), findsOneWidget);
    // neither side painted, read out, focused or hit
    expect(find.text('hello from $_a'), findsNothing);
    expect(find.text(_b), findsNothing);
    expect(find.bySemanticsLabel(RegExp(_b)), findsNothing);
    expect(find.bySemanticsLabel(RegExp('hello from')), findsNothing);
    final focus = FocusManager.instance.primaryFocus?.context;
    expect(
      focus == null ||
          find
              .descendant(
                of: find.byType(WideHome),
                matching: find.byElementPredicate((e) => e == focus),
              )
              .evaluate()
              .isEmpty,
      isTrue,
    );
    lock.set(false);
    await _settle(t);
    expect(find.text('pad'), findsNothing);
    expect(identical(t.state(_chat(_a)), state), isTrue);
    expect(find.text(_b), findsWidgets);
    h.dispose();
    await _close(t);
  });
}
