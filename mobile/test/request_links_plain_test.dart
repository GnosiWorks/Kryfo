// SPDX-License-Identifier: GPL-3.0-or-later
// links in a request are plain words on both sides: no card under them,
// nothing that opens on a tap, and no preview offered while typing. once
// both sides are in, the same message shows its link card again.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRefresh,
        AppStateRoute;
import 'package:kryfo/open_outside.dart' show openOutsideForTest;
import 'package:kryfo/rooms.dart' show RoomLink;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/widgets/kryfo_link_text.dart' show RoomInviteCard;
import 'package:kryfo/widgets/link_stub.dart' show LinkStub;
import 'package:kryfo/widgets/place_stub.dart' show PlaceStub;
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:kryfo/widgets/preview_strip.dart' show PreviewStrip;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'amber-calm-river';
const _web = 'look https://example.org/plan';
const _geo = 'here geo:48.858093,2.294694';
const _invite =
    'add me kryfo://share?id=tourist-admit-sun&onion=abcdefghijklmnop.onion'
    '&v=3&bundle=QUJDRA';

void main() {
  late MemDb mem;
  late Directory docs;
  late List<Uri> opened;

  setUp(() async {
    lockState.openForTest();
    opened = [];
    openOutsideForTest = (u) async {
      opened.add(u);
      return true;
    };
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    appState.setTorStatusForTest(TorStatus.reachable);
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('request_links_plain');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    mockChannel('halo/platform', (_) async => null);
    useLibrary();
    mem = MemDb();
    await devChatTables(mem, now: 1);
  });

  tearDown(() {
    openOutsideForTest = null;
    appState.setTorStatusForTest(TorStatus.off);
    StickerLibrary.use(null);
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    mockChannel('halo/platform', null);
    docs.deleteSync(recursive: true);
  });

  Future<void> person({required bool accepted, required bool paired}) async {
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': accepted ? 1 : 0,
      'back_paired': paired ? 1 : 0,
      'blocked': 0,
    });
    final db = SayHiDb(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  }

  var n = 0;
  Future<void> said(String dir, String text) => mem.insert('messages', {
    'peer_id': _peer,
    'direction': dir,
    'plaintext': text,
    'sent_at': 1000 + n,
    'written_at': 1000 + n,
    'msg_uid': 'm${n++}',
  });

  Future<void> settle(WidgetTester t, [int beats = 6]) async {
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
        peerXPub: '',
        avatarSeed: _peer,
      ),
    );
    await settle(t);
  }

  Future<void> tapWords(WidgetTester t, String text) async {
    await t.tap(find.text(text), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a stranger\'s links in a request are plain words', (t) async {
    final room = RoomLink(
      roomId: 'room-one',
      name: 'Book club',
      expiresAt: DateTime.now()
          .add(const Duration(hours: 2))
          .millisecondsSinceEpoch,
      creatorPub: 'a' * 64,
      fcPk: 'b' * 64,
    ).encode();
    await person(accepted: false, paired: true);
    await said('in', _web);
    await said('in', _geo);
    await said('in', room);
    await said('in', _invite);
    await open(t);
    expect(find.byType(LinkStub), findsNothing);
    expect(find.byType(PlaceStub), findsNothing);
    expect(find.byType(RoomInviteCard), findsNothing);
    expect(find.text(_web), findsOneWidget);
    expect(find.text(room), findsOneWidget);
    expect(find.text(_invite), findsOneWidget);
    await tapWords(t, _web);
    await tapWords(t, _geo);
    await tapWords(t, room);
    await tapWords(t, _invite);
    expect(opened, isEmpty);
    expect(find.byType(BottomSheet), findsNothing);
    await devClose(t);
  });

  testWidgets('my links to someone who has not accepted are plain words, '
      'and no preview is offered', (t) async {
    await person(accepted: true, paired: false);
    await said('out', _web);
    await open(t);
    expect(find.byType(LinkStub), findsNothing);
    expect(find.text(_web), findsOneWidget);
    await tapWords(t, _web);
    expect(opened, isEmpty);
    await t.enterText(find.byType(TextField).last, 'see https://example.org');
    await t.pump();
    expect(t.widget<PreviewStrip>(find.byType(PreviewStrip)).url, isNull);
    await devClose(t);
  });

  testWidgets('once both sides are in, the link card is back', (t) async {
    await person(accepted: true, paired: true);
    await said('in', _web);
    await open(t);
    expect(find.byType(LinkStub), findsOneWidget);
    await t.tap(find.byType(LinkStub));
    await t.pump(const Duration(milliseconds: 300));
    expect(opened, [Uri.parse('https://example.org/plan')]);
    await t.enterText(find.byType(TextField).last, 'see https://example.org');
    await t.pump();
    expect(
      t.widget<PreviewStrip>(find.byType(PreviewStrip)).url,
      'https://example.org',
    );
    await devClose(t);
  });
}
