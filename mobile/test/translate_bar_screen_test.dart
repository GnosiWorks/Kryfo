// SPDX-License-Identifier: GPL-3.0-or-later
// the translate bar in the real chat screen: there for their chinese in
// the everyday session, one tap for the whole thread, and never in the
// decoy, where the chat looks as it would on a phone with no bar at all
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
        sessionQuiet,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/translate/hub.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';
import 'translate_fakes.dart';

const _peer = 'calm-grey-heron';
const _zh1 = '你好，我们明天见吧';
const _en1 = 'Hello, see you tomorrow';
const _zh2 = '我们后天在车站见吧';
const _en2 = 'See you at the station the day after tomorrow';

Finder rich(String s) => find.textContaining(s, findRichText: true);

void main() {
  late Directory docs;
  late Fakes f;

  Future<void> use(HaloContainer container) async {
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
    var at = 1;
    for (final (uid, text) in [('u-1', _zh1), ('u-2', _zh2)]) {
      await m.insert('messages', {
        'peer_id': _peer,
        'direction': 'in',
        'plaintext': text,
        'msg_uid': uid,
        'sent_at': at++,
      });
    }
    final db = SayHiDb(m, container);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    lockState.openForTest();
    docs = Directory.systemTemp.createTempSync('translate_bar');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    useLibrary();
    f = fakeHub(installed: true, words: {_zh1: _en1, _zh2: _en2});
    TranslationHub.instance = f.hub;
  });

  tearDown(() {
    TranslationHub.instance = null;
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester t, [int beats = 8]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester t) async {
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: 'abab',
        avatarSeed: _peer,
      ),
    );
    await settle(t);
  }

  testWidgets('their chinese: the bar, and one tap for the whole chat', (
    t,
  ) async {
    await t.runAsync(() => use(HaloContainer.everyday));
    await open(t);
    final to = find.text(l10n.translateBarTo(langName('en')));
    expect(to, findsOneWidget);
    await t.tap(to);
    await settle(t);
    expect(find.text(_en1), findsOneWidget);
    expect(find.text(_en2), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tr-bar')),
        matching: find.text(l10n.translateShowOriginal),
      ),
      findsOneWidget,
    );
    await devClose(t);
  });

  testWidgets('the decoy never shows it', (t) async {
    await t.runAsync(() => use(HaloContainer.decoy));
    expect(sessionQuiet, isTrue);
    await open(t);
    expect(find.text(_zh1), findsOneWidget);
    expect(find.byKey(const ValueKey('tr-bar')), findsNothing);
    expect(find.text(l10n.translateBarTo(langName('en'))), findsNothing);
    await devClose(t);
  });
}
