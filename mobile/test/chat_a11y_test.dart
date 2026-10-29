// SPDX-License-Identifier: GPL-3.0-or-later
// a 1:1 chat to a screen reader and a keyboard: the long-press menu is one
// named layer with a close and nothing of the chat behind it, escape
// closes it, words on your own bubble are at full ink, and the in-chat
// search arrows are 48 boxes
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        AppStateRefresh,
        AppStateRoute,
        appState,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/menu_backdrop.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y_fakes.dart' show treeLabels;
import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'calm-grey-heron';
const _theirs = 'see you at the bridge';
const _mine = 'on my way now';

Future<void> _open(WidgetTester t, {bool light = false}) async {
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
  });
  FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
  appState.sendModeForTest = 'balanced';
  useEngineForTest(SayHiRelay());
  lockState.openForTest();
  final docs = Directory.systemTemp.createTempSync('chat_a11y');
  addTearDown(() => docs.deleteSync(recursive: true));
  mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
  addTearDown(() => mockChannel('plugins.flutter.io/path_provider', null));
  mockChannel('com.llfbandit.record/messages', (_) async => null);
  useLibrary();
  await t.runAsync(() async {
    final m = MemDb();
    await devChatTables(m, now: 1);
    await m.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
    });
    for (final (uid, dir, text, at) in [
      ('u-in', 'in', _theirs, 1000),
      ('u-out', 'out', _mine, 2000),
    ]) {
      await m.insert('messages', {
        'peer_id': _peer,
        'direction': dir,
        'plaintext': text,
        'msg_uid': uid,
        'sent_at': at,
      });
    }
    final db = SayHiDb(m, HaloContainer.everyday);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });
  HaloColors.setLight(light);
  await devOpen(
    t,
    const ChatScreen(
      peerHaloId: _peer,
      peerOnion: '',
      peerXPub: 'abab',
      avatarSeed: _peer,
    ),
  );
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(find.text(_theirs), findsOneWidget);
}

Future<void> _menu(WidgetTester t) async {
  await t.longPress(find.text(_theirs));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  expect(find.byType(MenuBackdrop), findsOneWidget);
}

void main() {
  tearDown(() => HaloColors.setLight(false));

  testWidgets('the message menu is one named layer over a hidden chat', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await _open(t);
    await _menu(t);
    final layer = find.bySemanticsLabel(l10n.a11yMessageActions);
    expect(layer, findsOneWidget);
    final n = t.getSemantics(layer);
    expect(n.flagsCollection.scopesRoute, isTrue);
    expect(n.flagsCollection.namesRoute, isTrue);
    // neither the copy of the bubble nor the chat under it is heard
    final heard = treeLabels(t).join('\n');
    expect(heard, isNot(contains(_mine)));
    expect(heard, isNot(contains(_theirs)));
    expect(heard, isNot(contains(l10n.chatSearchThisChat)));
    expect(heard, contains(l10n.a11yMessageActions));
    final close = find.bySemanticsLabel(l10n.commonClose);
    expect(close, findsOneWidget);
    expect(
      t.getSemantics(close).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    await t.tap(close);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(MenuBackdrop), findsNothing);
    await devClose(t);
    h.dispose();
  });

  testWidgets('escape closes the message menu', (t) async {
    await _open(t);
    await _menu(t);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(MenuBackdrop), findsNothing);
    await devClose(t);
  });

  for (final light in [true, false]) {
    testWidgets('words on your own bubble are at full ink in '
        '${light ? 'light' : 'dark'}', (t) async {
      await _open(t, light: light);
      final on = HaloColors.onAmber;
      final faded = inksOf(
        t,
      ).where((c) => c.r == on.r && c.g == on.g && c.b == on.b && c.a < 1);
      expect(faded, isEmpty);
      await devClose(t);
    });
  }

  testWidgets('the in-chat search arrows are 48 boxes', (t) async {
    final h = t.ensureSemantics();
    await _open(t);
    await t.tap(find.byTooltip(l10n.chatSearchThisChat));
    await t.pump(const Duration(milliseconds: 400));
    t.testTextInput.enterText('bridge');
    // one frame starts the row's fade in, the next ends it
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    for (final words in [l10n.chatPreviousMatch, l10n.chatNextMatch]) {
      final box = t.getSize(find.bySemanticsLabel(words));
      expect(box.width, greaterThanOrEqualTo(48), reason: words);
      expect(box.height, greaterThanOrEqualTo(48), reason: words);
    }
    await devClose(t);
    h.dispose();
  });
}

List<Color> inksOf(WidgetTester t) => [
  for (final w in t.widgetList<RichText>(find.byType(RichText)))
    ?w.text.style?.color,
];
