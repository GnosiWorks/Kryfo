// SPDX-License-Identifier: GPL-3.0-or-later
// a chat and a group on a wide desktop window: the thread and the composer
// keep a reading width, centred, the wallpaper and the head the whole width
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        AppStateRefresh,
        AppStateRoute,
        appState,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/wide/read_width.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_chat_fakes.dart';
import '../mem_db.dart';
import '../say_hi_fakes.dart';
import '../sticker_test_util.dart';

const _peer = 'calm-grey-heron';
const _wide = Size(1600, 900);

void _prefs() {
  SharedPreferences.setMockInitialValues({
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
  });
  FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
  appState.sendModeForTest = 'balanced';
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 200));
  }
  await t.pump(const Duration(seconds: 2));
}

void main() {
  setUp(() => onDesktop = true);
  tearDown(() => onDesktop = false);

  testWidgets('a wide chat keeps its thread and composer at reading width', (
    t,
  ) async {
    _prefs();
    useEngineForTest(SayHiRelay());
    lockState.openForTest();
    final docs = Directory.systemTemp.createTempSync('phone_layout');
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
        ('u-in', 'in', 'see you at the bridge', 1000),
        ('u-out', 'out', 'on my way now, a long line to fill the bubble', 2000),
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
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: 'abab',
        avatarSeed: _peer,
      ),
      size: _wide,
      ratio: 1,
      still: true,
    );
    await _settle(t);
    expect(t.takeException(), isNull);
    final side = (1600 - kReadWidth) / 2;
    // the bubbles sit inside the column, both sides
    final theirs = t.getRect(find.text('see you at the bridge'));
    final mine = t.getRect(
      find.text('on my way now, a long line to fill the bubble'),
    );
    expect(theirs.left, greaterThan(side));
    expect(mine.right, lessThan(1600 - side));
    // the composer's field too
    final field = t.getRect(find.byType(EditableText));
    expect(field.left, greaterThan(side));
    expect(field.right, lessThan(1600 - side));
    // the wallpaper and the head keep the whole width
    expect(t.getRect(find.byType(ListView)).width, 1600);
    await devClose(t);
  });
}
