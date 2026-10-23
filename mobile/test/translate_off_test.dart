// SPDX-License-Identifier: GPL-3.0-or-later
// translation stays off until its library ships: no screen shows it and no
// hub is built
import 'dart:io';

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
import 'package:kryfo/translate/hub.dart';
import 'package:kryfo/translate/hub_live.dart';
import 'package:kryfo/widgets/menu_backdrop.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'calm-grey-heron';
const _zh = '你好，我们明天见吧';

void main() {
  test('the switch is off and nothing builds a hub', () {
    expect(kOfflineTranslation, isFalse);
    TranslationHub.instance = null;
    expect(translationHubIfOn(), isNull);
    expect(TranslationHub.instance, isNull);
  });

  test('screens reach translation only through the switch', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('hub_live.dart')) continue;
      final src = f.readAsStringSync();
      if (RegExp(r'\btranslationHub\(\)').hasMatch(src)) bad.add(f.path);
    }
    expect(bad, isEmpty);
  });

  testWidgets('a chinese message in a chat shows no translate', (t) async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    lockState.openForTest();
    final docs = Directory.systemTemp.createTempSync('translate_off');
    addTearDown(() => docs.deleteSync(recursive: true));
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    addTearDown(() => mockChannel('plugins.flutter.io/path_provider', null));
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    addTearDown(() => mockChannel('com.llfbandit.record/messages', null));
    useLibrary();
    TranslationHub.instance = null;
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
      await m.insert('messages', {
        'peer_id': _peer,
        'direction': 'in',
        'plaintext': _zh,
        'msg_uid': 'u-zh',
        'sent_at': 1,
      });
      final db = SayHiDb(m, HaloContainer.everyday);
      useDatabasesForTest(db, Session(db));
      await appState.refreshContacts();
    });

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
    expect(find.text(_zh), findsOneWidget);
    final line = find.textContaining(l10n.translateAction, findRichText: true);
    expect(line, findsNothing);

    await t.longPress(find.text(_zh));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(MenuBackdrop), findsOneWidget);
    expect(find.text(l10n.translateAction), findsNothing);
    expect(TranslationHub.instance, isNull);
    await devClose(t);
  });
}
