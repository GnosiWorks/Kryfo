// SPDX-License-Identifier: GPL-3.0-or-later
// the real chat screen: translate under their bubble and in its menu, none
// on ours. the translator is a stand-in
import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:kryfo/theme.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/translate/hub.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:kryfo/translate/translate_bubble.dart';
import 'package:kryfo/widgets/menu_backdrop.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';
import 'translate_fakes.dart';

const _peer = 'calm-grey-heron';
const _zh = '你好，我们明天见吧';
const _en = 'Hello, see you tomorrow';
const _ours = 'see you at the station then';
const _zhSoon = '三点在车站等我';
const _enSoon = 'Wait for me at the station at three';

Finder rich(String s) => find.textContaining(s, findRichText: true);

// a burn takes the row out of the database too
class _Db extends SayHiDb {
  _Db(super.mem, [super.container]);
  @override
  Future<void> deleteMessage(String msgUid, {String? from}) async =>
      mem.delete('messages', where: 'msg_uid = ?', whereArgs: [msgUid]);
}

void main() {
  late Directory docs;
  late Fakes f;
  late MemDb m;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    // the menu opens only over an unlocked app
    lockState.openForTest();
    docs = Directory.systemTemp.createTempSync('translate_chat');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    useLibrary();
    m = MemDb();
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
    await m.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': _zh,
      'msg_uid': 'u-zh',
      'sent_at': 1,
    });
    await m.insert('messages', {
      'peer_id': _peer,
      'direction': 'out',
      'plaintext': _ours,
      'msg_uid': 'u-ours',
      'sent_at': 2,
      'delivered': 1,
    });
    final db = _Db(m, HaloContainer.everyday);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    f = fakeHub(installed: true, words: {_zh: _en, _zhSoon: _enSoon});
    TranslationHub.instance = f.hub;
  });

  tearDown(() {
    TranslationHub.instance = null;
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester t, [int beats = 6]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openMenu(WidgetTester t, String text) async {
    await t.longPress(rich(text).first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(MenuBackdrop), findsOneWidget);
  }

  Future<void> open(WidgetTester t, {bool still = false}) async {
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: 'abab',
        avatarSeed: _peer,
      ),
      still: still,
    );
    await settle(t);
  }

  testWidgets('theirs in chinese offers translate; ours does not', (t) async {
    await open(t);
    expect(find.text(_zh), findsOneWidget);
    expect(find.text(_ours), findsOneWidget);
    expect(rich(l10n.translateAction), findsOneWidget);
    await t.tap(rich(l10n.translateAction));
    await settle(t);
    expect(find.text(_en), findsOneWidget);
    expect(find.text(_zh), findsNothing);
    expect(rich(l10n.translateFrom(l10n.translateLangZh)), findsOneWidget);
    await t.tap(rich(l10n.translateShowOriginal));
    await settle(t);
    expect(find.text(_zh), findsOneWidget);
    expect(find.text(_en), findsNothing);
    await devClose(t);
  });

  testWidgets('the long-press menu translates, and shows the original', (
    t,
  ) async {
    await open(t);
    await openMenu(t, _zh);
    expect(find.text(l10n.translateAction), findsOneWidget);
    await t.tap(find.text(l10n.translateAction));
    await settle(t, 10);
    expect(find.text(_en), findsOneWidget);

    await openMenu(t, _en);
    expect(find.text(l10n.translateShowOriginal), findsOneWidget);
    await t.tap(find.text(l10n.translateShowOriginal));
    await settle(t, 10);
    expect(find.text(_zh), findsOneWidget);

    // ours has no such entry
    await openMenu(t, _ours);
    expect(find.text(l10n.translateAction), findsNothing);
    await devClose(t);
  });

  testWidgets('the long-press menu: always this chat, never this language', (
    t,
  ) async {
    await open(t);
    await openMenu(t, _zh);
    expect(find.text(l10n.translateAlwaysChat), findsOneWidget);
    expect(find.text(l10n.translateBarNever(langName('zh'))), findsOneWidget);
    expect(
      t.widget<Icon>(find.byIcon(Icons.check_rounded)).color,
      Colors.transparent,
    );
    await t.tap(find.text(l10n.translateAlwaysChat));
    await settle(t, 10);
    expect(await f.store.chatAuto(_peer), isTrue);
    expect(find.text(_en), findsOneWidget);

    // on now: the row says so, and turns it off
    await openMenu(t, _en);
    expect(
      t.widget<Icon>(find.byIcon(Icons.check_rounded)).color,
      HaloColors.amberText,
    );
    await t.tap(find.text(l10n.translateAlwaysChat));
    await settle(t, 10);
    expect(await f.store.chatAuto(_peer), isFalse);
    expect(find.text(_zh), findsOneWidget);

    await openMenu(t, _zh);
    await t.tap(find.text(l10n.translateBarNever(langName('zh'))));
    await settle(t, 10);
    expect(f.store.settings.never, ['zh']);
    expect(rich(l10n.translateAction), findsNothing);
    expect(find.text(l10n.translateNeverDone(langName('zh'))), findsOneWidget);

    // ours has neither
    await openMenu(t, _ours);
    expect(find.text(l10n.translateAlwaysChat), findsNothing);
    await devClose(t);
  });

  testWidgets('a chat set to translate shows it translated', (t) async {
    await f.store.setChatAuto(_peer, true);
    await open(t);
    expect(find.text(_en), findsOneWidget);
    expect(rich(l10n.translateShowOriginal), findsOneWidget);
    await devClose(t);
  });

  testWidgets('reduced motion: no animation', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(t, still: true);
    await t.tap(rich(l10n.translateAction));
    await settle(t);
    expect(find.text(_en), findsOneWidget);
    expect(t.takeException(), isNull);
    await devClose(t);
  });

  testWidgets('a timed message takes its translation with it', (t) async {
    await m.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': _zhSoon,
      'msg_uid': 'u-soon',
      'sent_at': 3,
      'burn_secs': 5,
      'burn_at': DateTime.now().millisecondsSinceEpoch + 5000,
    });
    await open(t);
    expect(rich(_zhSoon), findsOneWidget);
    final soon = find.byWidgetPredicate(
      (w) => w is TranslatedBody && w.text == _zhSoon,
    );
    await t.tap(
      find.descendant(of: soon, matching: rich(l10n.translateAction)),
    );
    await settle(t, 10);
    expect(rich(_enSoon), findsOneWidget);
    final chat = t.widget<TranslatedBody>(soon).chat!;
    expect(chat.of('u-soon').text, _enSoon);

    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5200)),
    );
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(rich(_enSoon), findsNothing);
    expect(chat.of('u-soon').text, isNull);
    // the other message keeps its own
    expect(find.text(_zh), findsOneWidget);
    await devClose(t);
  });
}
