// SPDX-License-Identifier: GPL-3.0-or-later
// a chat on a computer with a mouse and keyboard: it opens ready to type,
// esc lets go of a quote before it closes the chat, a mouse drag selects a
// bubble's words and never swipes a reply, and a right click still opens
// the bubble's menu
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/screens/chat_door.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/desk_menu.dart';
import 'package:kryfo/widgets/message_menu.dart' show MessageMenuCard;
import 'package:kryfo/wide/wide_home.dart';
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
  final docs = Directory.systemTemp.createTempSync('desk_chat');
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

// a row of the list, by its name
Finder _row(String id) =>
    find.descendant(of: find.byType(WideMark), matching: find.text(id)).first;

Finder _chat(String id) =>
    find.byWidgetPredicate((w) => w is ChatScreen && w.peerHaloId == id);

Future<void> _openRow(WidgetTester t, String id) async {
  await t.tap(_row(id));
  await _settle(t);
  expect(_chat(id), findsOneWidget);
}

Finder _composer(String id) => find.descendant(
  of: _chat(id),
  matching: find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == l10n.chatMessage,
  ),
);

bool _typing(WidgetTester t, String id) {
  final f = find.descendant(
    of: _composer(id),
    matching: find.byType(EditableText),
  );
  return t.widget<EditableText>(f.first).focusNode.hasFocus;
}

Finder _words(String id) =>
    find.descendant(of: _chat(id), matching: find.text('hello from $id'));

void main() {
  setUp(() => onDesktop = true);
  tearDown(() => onDesktop = false);

  testWidgets('a chat opens ready to type, and the next chat too', (t) async {
    await _open(t);
    await _openRow(t, _a);
    expect(_typing(t, _a), isTrue);
    await t.enterText(_composer(_a), 'hi');
    expect(find.text('hi'), findsOneWidget);
    await _openRow(t, _b);
    expect(_typing(t, _b), isTrue);
    await _close(t);
  });

  testWidgets('the phone opens a chat as it always did, no field focused', (
    t,
  ) async {
    onDesktop = false;
    await _open(t);
    await t.tap(find.text(_a).first);
    await _settle(t);
    expect(_chat(_a), findsOneWidget);
    expect(_typing(t, _a), isFalse);
    await _close(t);
  });

  testWidgets('esc lets go of the quote first, then closes the chat', (
    t,
  ) async {
    await _open(t);
    await _openRow(t, _a);
    // touch still swipes a reply on a computer
    await t.drag(_words(_a), const Offset(120, 0));
    await _settle(t);
    expect(find.text(l10n.chatReplyingTo), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(t);
    expect(find.text(l10n.chatReplyingTo), findsNothing);
    expect(_chat(_a), findsOneWidget, reason: 'the chat stays');
    expect(_typing(t, _a), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(t);
    expect(_chat(_a), findsNothing);
    await _close(t);
  });

  testWidgets('a mouse drag on a bubble selects its words, never a reply', (
    t,
  ) async {
    final copied = <String>[];
    await _open(t);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (c) async {
        if (c.method == 'Clipboard.setData') {
          copied.add((c.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await _openRow(t, _a);
    final box = t.getRect(_words(_a));
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: box.centerLeft + const Offset(1, 0));
    await t.pump();
    // a mouse over the words: they can be selected
    expect(
      find.ancestor(of: _words(_a), matching: find.byType(SelectionArea)),
      findsOneWidget,
    );
    await g.down(box.centerLeft + const Offset(1, 0));
    await t.pump(const Duration(milliseconds: 50));
    await g.moveTo(box.centerRight - const Offset(1, 0));
    await t.pump();
    await g.up();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.chatReplyingTo), findsNothing);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(copied, isNotEmpty);
    expect(copied.last, contains('hello from'));
    // the mouse gone, the selection stays while it is there
    await g.moveTo(Offset.zero);
    await t.pump();
    expect(
      find.ancestor(of: _words(_a), matching: find.byType(SelectionArea)),
      findsOneWidget,
    );
    await g.removePointer();
    await _close(t);
  });

  testWidgets('a right click on hovered words opens the menu once', (t) async {
    await _open(t);
    await _openRow(t, _a);
    final at = t.getCenter(_words(_a));
    final g = await t.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await g.addPointer(location: at);
    await t.pump();
    await g.down(at);
    await t.pump();
    await g.up();
    await _settle(t);
    expect(find.byType(DeskMenu), findsOneWidget);
    expect(find.byType(MessageMenuCard), findsNothing);
    await g.removePointer();
    await _close(t);
  });

  testWidgets('a click on a bubble\'s words still shows its date', (t) async {
    await _open(t);
    await _openRow(t, _a);
    final at = t.getCenter(_words(_a));
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    // the mouse comes onto the words with the press itself
    await g.addPointer(location: Offset.zero);
    await t.pump();
    await g.down(at);
    await t.pump(const Duration(milliseconds: 50));
    await g.up();
    await _settle(t);
    expect(find.byKey(const ValueKey('full-date')), findsOneWidget);
    // and with the mouse resting on them, once a click
    await t.pump();
    await g.down(at);
    await t.pump(const Duration(milliseconds: 50));
    await g.up();
    await _settle(t);
    expect(find.byKey(const ValueKey('full-date')), findsNothing);
    await g.down(at);
    await t.pump(const Duration(milliseconds: 50));
    await g.up();
    await _settle(t);
    expect(find.byKey(const ValueKey('full-date')), findsOneWidget);
    await g.removePointer();
    await _close(t);
  });

  testWidgets('a right click on a bubble\'s words opens its menu', (t) async {
    await _open(t);
    await _openRow(t, _a);
    await t.tapAt(
      t.getCenter(_words(_a)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await _settle(t);
    expect(find.byType(DeskMenu), findsOneWidget);
    expect(find.byType(MessageMenuCard), findsNothing);
    await _close(t);
  });

  testWidgets(
    'a bubble\'s menu sits at the mouse, reactions first, esc closes',
    (t) async {
      await _open(t);
      await _openRow(t, _a);
      final at = t.getCenter(_words(_a)) + const Offset(4, 2);
      await t.tapAt(
        at,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await _settle(t);
      final menu = t.getRect(find.byKey(const ValueKey('desk menu')));
      // at the mouse: under it, or over it this near the window's foot
      expect(menu.left, at.dx);
      expect(menu.top == at.dy || menu.bottom == at.dy, isTrue);
      expect(find.byKey(const ValueKey('desk menu reactions')), findsOneWidget);
      // the phone's order: reactions, reply, then pin, save, copy, forward
      final reply = t.getRect(find.text(l10n.chatReply)).top;
      final pin = t.getRect(find.text(l10n.chatPin)).top;
      final copy = t.getRect(find.text(l10n.commonCopy)).top;
      final forward = t.getRect(find.text(l10n.chatForward)).top;
      expect(reply < pin && pin < copy && copy < forward, isTrue);
      // theirs: no edit or unsend
      expect(find.text(l10n.chatUnsend), findsNothing);
      // nothing dimmed or lifted behind it
      expect(find.byType(BackdropFilter), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(t);
      expect(find.byType(DeskMenu), findsNothing);
      await _close(t);
    },
  );

  testWidgets('reply from the menu quotes the message', (t) async {
    await _open(t);
    await _openRow(t, _a);
    await t.tapAt(
      t.getCenter(_words(_a)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await _settle(t);
    await t.tap(find.text(l10n.chatReply));
    await _settle(t);
    expect(find.byType(DeskMenu), findsNothing);
    // the quote over the composer and the bubble: two of its words
    expect(_words(_a), findsNWidgets(2));
    await _close(t);
  });

  testWidgets('a chat row\'s right click is the small menu at the mouse', (
    t,
  ) async {
    await _open(t);
    final at = t.getCenter(_row(_b));
    await t.tapAt(
      at,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await _settle(t);
    expect(find.byType(DeskMenu), findsOneWidget);
    expect(t.getRect(find.byKey(const ValueKey('desk menu'))).topLeft, at);
    expect(find.text(l10n.homeMute), findsOneWidget);
    expect(find.text(l10n.homeArchive), findsOneWidget);
    expect(find.text(l10n.homeDeleteChat), findsOneWidget);
    // delete still asks first
    await t.tap(find.text(l10n.homeDeleteChat));
    await _settle(t);
    expect(find.text(l10n.homeDeleteThisChat), findsOneWidget);
    await _close(t);
  });

  testWidgets('the menu key opens a focused message\'s menu', (t) async {
    await _open(t);
    await _openRow(t, _a);
    // the bubble takes focus as tab would give it
    final ring = find.ancestor(
      of: _words(_a),
      matching: find.byType(DeskMenuFocus),
    );
    expect(ring, findsOneWidget);
    final node = Focus.of(
      t.element(find.descendant(of: ring, matching: find.byType(Stack)).first),
    );
    node.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await _settle(t);
    expect(find.byType(DeskMenu), findsOneWidget);
    final menu = t.getRect(find.byKey(const ValueKey('desk menu')));
    final bubble = t.getRect(ring);
    expect(
      (menu.top - bubble.bottom).abs() < 6 || menu.bottom <= bubble.top,
      isTrue,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(t);
    expect(find.byType(DeskMenu), findsNothing);
    await _close(t);
  });

  testWidgets('the phone keeps plain words in its bubbles', (t) async {
    onDesktop = false;
    await _open(t);
    await t.tap(find.text(_a).first);
    await _settle(t);
    expect(
      find.ancestor(of: _words(_a), matching: find.byType(SelectionArea)),
      findsNothing,
    );
    await _close(t);
  });
}
