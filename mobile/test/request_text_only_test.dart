// SPDX-License-Identifier: GPL-3.0-or-later
// a request to a stranger is words alone until they accept. my side offers
// no camera, photo, file or voice note and says why; their side keeps a
// stranger's photos and files unshown, and says when they come. an
// introduced request keeps its photos, and an accept brings them back
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
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/widgets/voice_mic.dart' show HoldToTalkMic;
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'amber-calm-river';
const _friend = 'quiet-oak-friend';
const _sender =
    'Photos and files unlock after they accept you, to keep you '
    'both safe.';
const _receiver =
    'Photos and files unlock after you accept them, to keep you safe.';

// a friend vouched for them
class _Introduced extends SayHiDb {
  _Introduced(super.mem);
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [
    {'voucher_id': _friend, 'nickname': 'Ana', 'avatar': null, 'verified': 0},
  ];
}

void main() {
  late MemDb mem;
  late Directory docs;

  setUp(() async {
    lockState.openForTest();
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    appState.setTorStatusForTest(TorStatus.reachable);
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('request_text_only');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    mockChannel('halo/platform', (_) async => null);
    useLibrary();
    mem = MemDb();
    await devChatTables(mem, now: 1);
  });

  tearDown(() {
    appState.setTorStatusForTest(TorStatus.off);
    StickerLibrary.use(null);
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    mockChannel('halo/platform', null);
    docs.deleteSync(recursive: true);
  });

  Future<void> person({
    required bool accepted,
    required bool paired,
    bool introduced = false,
  }) async {
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
    final db = introduced ? _Introduced(mem) : SayHiDb(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  }

  var n = 0;
  Future<void> said(String dir, String text, {String? photo}) =>
      mem.insert('messages', {
        'peer_id': _peer,
        'direction': dir,
        'plaintext': text,
        'sent_at': 1000 + n,
        'written_at': 1000 + n,
        'msg_uid': 'm${n++}',
        'media_path': ?photo,
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

  // what the composer offers besides words
  void offers(bool media) {
    final m = media ? findsOneWidget : findsNothing;
    expect(find.bySemanticsLabel('Attach a photo'), m);
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      expect(find.bySemanticsLabel('Open the camera'), m);
    }
    expect(find.byType(HoldToTalkMic), m);
  }

  testWidgets('to a stranger before they accept: words alone, and it says '
      'why', (t) async {
    await person(accepted: true, paired: false);
    await said('out', 'hello there');
    await open(t);
    offers(false);
    expect(find.text(_sender), findsOneWidget);
    // words still go
    expect(find.byType(TextField), findsWidgets);
    await devClose(t);
  });

  testWidgets('to someone a friend introduced: photos and files as before', (
    t,
  ) async {
    await person(accepted: true, paired: false, introduced: true);
    await said('out', 'hello there');
    await open(t);
    offers(true);
    expect(find.text(_sender), findsNothing);
    await devClose(t);
  });

  testWidgets('once they are in, the composer has it all again', (t) async {
    await person(accepted: true, paired: true);
    await said('out', 'hello there');
    await said('in', 'hi back');
    await open(t);
    offers(true);
    expect(find.text(_sender), findsNothing);
    await devClose(t);
  });

  testWidgets('a stranger\'s photo waits unshown, and the bar says when it '
      'comes', (t) async {
    final pic = File('${docs.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
    await person(accepted: false, paired: true);
    await said('in', 'their words');
    await said('in', 'their caption', photo: pic.path);
    await open(t);
    expect(find.text('their words'), findsOneWidget);
    expect(find.text('their caption'), findsNothing);
    expect(find.text(_receiver), findsOneWidget);
    // held back, not gone
    expect(pic.existsSync(), isTrue);
    await devClose(t);
  });

  testWidgets('an introduced request shows its photo', (t) async {
    final pic = File('${docs.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
    await person(accepted: false, paired: true, introduced: true);
    await said('in', 'their caption', photo: pic.path);
    await open(t);
    expect(find.text('their caption'), findsOneWidget);
    expect(find.text(_receiver), findsNothing);
    await devClose(t);
  });

  testWidgets('accepted, the photo shows', (t) async {
    final pic = File('${docs.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
    await person(accepted: true, paired: true);
    await said('in', 'their caption', photo: pic.path);
    await open(t);
    expect(find.text('their caption'), findsOneWidget);
    expect(find.text(_receiver), findsNothing);
    await devClose(t);
  });
}
