// SPDX-License-Identifier: GPL-3.0-or-later
// the real chat screen: translate under their bubble and in its menu, none
// on ours. the translator is a stand-in
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/translate/hub.dart';
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

Finder rich(String s) => find.textContaining(s, findRichText: true);

void main() {
  late Directory docs;
  late Fakes f;

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
    final db = SayHiDb(m, HaloContainer.everyday);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    f = fakeHub(installed: true, words: {_zh: _en});
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
}
