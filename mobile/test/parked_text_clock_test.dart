// SPDX-License-Identifier: GPL-3.0-or-later
// a text of ours kept until it can go, as for someone on an older Kryfo,
// says so in its bubble: its time and a clock with a label for a screen
// reader, as a photo kept back says it in its corner. the chat's own screen
// over rows kept in maps
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateRefresh;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'amber-kept-river';

void main() {
  late MemDb mem;
  late Directory docs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('parked_text');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    useLibrary();
    mem = MemDb();
    await devChatTables(mem, now: 1);
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
    });
    // a decoy sends nothing: what is written there is kept, as for someone
    // on an older Kryfo
    final db = SayHiDb(mem, HaloContainer.decoy);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    StickerLibrary.use(null);
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

  testWidgets('a text kept until it can go shows its time and a waiting '
      'clock, with its label', (t) async {
    final handle = t.ensureSemantics();
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: '',
        avatarSeed: _peer,
      ),
    );
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'kept for later');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t, 12);
    expect(find.textContaining('kept for later'), findsWidgets);
    // the bubble's own clock: nothing else on this chat draws one
    final clock = find.byIcon(Icons.schedule_rounded);
    expect(clock, findsOneWidget);
    expect(t.widget<Icon>(clock).semanticLabel, l10n.chatWaitsToSend);
    // and nothing says it failed
    expect(find.text(l10n.chatFailedTapToRetryShown), findsNothing);
    await devClose(t);
    handle.dispose();
  });
}
