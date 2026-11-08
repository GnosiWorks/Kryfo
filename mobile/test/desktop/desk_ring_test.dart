// SPDX-License-Identifier: GPL-3.0-or-later
// the focus ring on a computer comes only where the keyboard led: a photo,
// an album's tile, a file or a bubble right clicked keeps no ring once its
// menu went, picked, closed by esc or by a click elsewhere, and a mouse
// press anywhere takes a ring the keyboard did not lead to off. tab still
// brings it
import 'dart:convert';
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
import 'package:kryfo/widgets/key_ring.dart';
import 'package:kryfo/wide/wide_home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mem_db.dart';
import '../say_hi_fakes.dart';
import '../sticker_test_util.dart';

const _a = 'amber-new-river';
const _b = 'calm-grey-heron';

// a 1x1 png
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

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
      final png = File('${docs.path}/p-$id.png')
        ..writeAsBytesSync(base64Decode(_png));
      for (var k = 0; k < 3; k++) {
        await m.insert('messages', {
          'peer_id': id,
          'direction': 'in',
          'plaintext': '',
          'msg_uid': 'p-$id-$k',
          'media_path': png.path,
          'sent_at': seen * 1000 + 10 + k,
          'album_id': 'ab12' * 4,
          'album_n': 3,
          'album_i': k,
        });
      }
      await m.insert('messages', {
        'peer_id': id,
        'direction': 'in',
        'plaintext': '',
        'msg_uid': 'one-$id',
        'media_path': png.path,
        'sent_at': seen * 1000 + 20,
      });
      final doc = File('${docs.path}/notes-$id.pdf')
        ..writeAsBytesSync([37, 80, 68, 70]);
      await m.insert('messages', {
        'peer_id': id,
        'direction': 'in',
        'plaintext': '',
        'msg_uid': 'f-$id',
        'file_path': doc.path,
        'file_name': 'notes.pdf',
        'sent_at': seen * 1000 + 30,
      });
      await m.insert('messages', {
        'peer_id': id,
        'direction': 'in',
        'plaintext': 'hello from $id',
        'msg_uid': 'u-$id',
        // the newest, under the photos and the file
        'sent_at': seen * 1000 + 40,
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

Finder _words(String id) =>
    find.descendant(of: _chat(id), matching: find.text('hello from $id'));

// a bare spot in the chat, the same place in the pane whatever the list's width
const _blank = Offset(kRailWidth + kListStart + 428, 120);

void main() {
  setUp(() {
    onDesktop = true;
    KeyLead.on.value = false;
  });
  tearDown(() => onDesktop = false);

  final ring = find.byKey(const ValueKey('key ring'));

  // what can be right clicked in the chat, and where it takes focus
  Finder photo() =>
      find.descendant(of: _chat(_a), matching: find.byType(Image));
  final things = <String, Finder Function()>{
    'an album tile': () => photo().first,
    'a photo': () => photo().last,
    'a file': () =>
        find.descendant(of: _chat(_a), matching: find.text('notes')).first,
    'a bubble': () => _words(_a),
  };

  // the nearest node the item can hold focus on, as tab or a closing
  // route gives it
  FocusNode nodeOf(WidgetTester t, Finder f) {
    final rings = find.ancestor(of: f, matching: find.byType(KeyRing));
    return Focus.of(
      t.element(
        find.descendant(of: rings.first, matching: find.byType(Stack)).first,
      ),
    );
  }

  Future<TestGesture> rightClick(WidgetTester t, Offset at) async {
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
    return g;
  }

  for (final MapEntry(key: what, value: of) in things.entries) {
    for (final how in ['picked', 'esc', 'a click elsewhere']) {
      testWidgets('$what right clicked keeps no ring once the menu went '
          '($how)', (t) async {
        await _open(t);
        await _openRow(t, _a);
        // tab led there: the ring shows
        final node = nodeOf(t, of());
        node.requestFocus();
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        node.requestFocus();
        await t.pump();
        expect(ring, findsWidgets);
        final g = await rightClick(t, t.getCenter(of()));
        switch (how) {
          case 'picked':
            await t.tap(find.text(l10n.chatReply).last);
          case 'esc':
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
          default:
            await g.moveTo(_blank);
            await g.down(_blank);
            await g.up();
        }
        await _settle(t);
        expect(find.byType(DeskMenu), findsNothing);
        // the focus may come back to it, as a closing route gives it back
        nodeOf(t, of()).requestFocus();
        await t.pump();
        expect(ring, findsNothing);
        await g.removePointer();
        await _close(t);
      });
    }
  }

  testWidgets('a mouse press takes off a ring the keyboard put on a photo', (
    t,
  ) async {
    await _open(t);
    await _openRow(t, _a);
    // typing makes flutter's look the keyboard's, and a mouse keeps it
    await t.sendKeyEvent(LogicalKeyboardKey.keyA);
    final node = nodeOf(t, photo().last);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    node.requestFocus();
    await t.pump();
    expect(ring, findsWidgets);
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: _blank);
    await g.down(_blank);
    await g.up();
    await _settle(t);
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
    expect(ring, findsNothing);
    // focus that comes with no key, after typing, shows none either
    node.requestFocus();
    await t.pump();
    expect(ring, findsNothing);
    // the keyboard leading again brings it back
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    node.requestFocus();
    await t.pump();
    expect(ring, findsWidgets);
    await g.removePointer();
    await _close(t);
  });
}
