// SPDX-License-Identifier: GPL-3.0-or-later
// the screenshot block on the chat's own screen. a chat that blocks holds
// the window's flag while it is open, and lets go as it closes. the switch
// in the chat's menu turns it on and off in place, and says it waits while
// their phone does not know the block, holding nothing. a mark beside the
// name says it is on, and a line in the thread says who changed it last.
// the chat's own screen over rows kept in maps, android's channel a fake
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/message_menu.dart' show MessageMenuCard;
import 'package:kryfo/widgets/shots_line.dart';
import 'package:kryfo/widgets/video_bubble.dart' show openReceivedFile;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'amber-calm-river';

// the block's rows, read and written as the app does
class _Db extends SayHiDb {
  _Db(super.mem);

  final frames = <String>[];

  Map<String, Object?> get _row =>
      mem.rows('contacts').firstWhere((r) => r['halo_id'] == _peer);

  // a read that has not come back yet
  Completer<void>? slow;

  @override
  Future<ChatShots> shotsOf(String peer) async {
    await slow?.future;
    return ChatShots.ofRow(_row);
  }

  @override
  Future<int?> turnShots(String peer, {required bool on}) async {
    final at = (_row['shots_at'] as int) + 1;
    await mem.update(
      'contacts',
      {
        'shots_on': on ? 1 : 0,
        'shots_at': at,
        'shots_by': kShotsByMe,
        'shots_when': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'halo_id = ?',
      whereArgs: [peer],
    );
    return at;
  }

  @override
  Future<void> queueFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
  ) async => frames.add('$kind $peerId');
}

void main() {
  late MemDb mem;
  late Directory docs;
  late List<bool> told;
  final calls = <String>[];

  setUp(() async {
    // the menu opens only over an unlocked app
    lockState.openForTest();
    told = [];
    calls.clear();
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('chat_shots_screen');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    mockChannel('halo/platform', (c) async {
      calls.add(c.method);
      if (c.method == 'setSecure') {
        told.add((c.arguments as Map)['on'] as bool);
      }
      return null;
    });
    useLibrary();
    mem = MemDb();
    await devChatTables(mem, now: 1);
  });

  tearDown(() {
    StickerLibrary.use(null);
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    mockChannel('halo/platform', null);
    docs.deleteSync(recursive: true);
  });

  Future<_Db> person({
    bool on = false,
    int can = 0,
    int blocked = 0,
    int by = kShotsByNone,
    int when = 0,
  }) async {
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'shots_on': on ? 1 : 0,
      'shots_at': on ? 5 : 0,
      'shots_can': can,
      'shots_by': by,
      'shots_when': when,
      'blocked': blocked,
    });
    final db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    return db;
  }

  Future<void> settle(WidgetTester t, [int beats = 6]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester t, {bool still = false}) async {
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: '',
        avatarSeed: _peer,
      ),
      still: still,
    );
    await settle(t);
  }

  Future<void> menu(WidgetTester t) async {
    await t.tap(find.byTooltip(l10n.chatContactOptions));
    await settle(t);
  }

  void closeSheet(WidgetTester t) =>
      t.state<NavigatorState>(find.byType(Navigator).first).pop();

  Finder mark() => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == l10n.chatShotsBlockedHere,
  );

  testWidgets('a chat that blocks holds the window while it is open, and '
      'lets go as it closes', (t) async {
    await person(on: true, can: 10);
    await open(t);
    expect(told.last, isTrue);
    expect(appState.secureForced, isTrue);
    expect(mark(), findsOneWidget);
    await devClose(t);
    expect(told.last, isFalse);
    expect(appState.secureForced, isFalse);
  });

  testWidgets('the window is covered before the chat draws, from what the '
      'list knows, while its own read is still out', (t) async {
    final db = await person(on: true, can: 10);
    db.slow = Completer<void>();
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: '',
        avatarSeed: _peer,
      ),
    );
    expect(told, isNotEmpty);
    expect(told.first, isTrue);
    db.slow!.complete();
    await settle(t);
    await devClose(t);
    expect(told.last, isFalse);
  });

  testWidgets('someone blocked holds nothing, and has no switch', (t) async {
    await person(on: true, can: 10, blocked: 1);
    await open(t);
    expect(told.where((on) => on), isEmpty);
    expect(mark(), findsNothing);
    await devClose(t);
  });

  testWidgets('their phone does not know the block: nothing held, nothing '
      'said, and the switch waits with its reason', (t) async {
    await person(on: true);
    await open(t);
    expect(told.where((on) => on), isEmpty);
    expect(mark(), findsNothing);
    await menu(t);
    expect(find.text(l10n.chatBlockScreenshots), findsOneWidget);
    expect(find.text(l10n.chatShotsWhenTheyUpdate), findsOneWidget);
    await t.tap(find.text(l10n.chatBlockScreenshots));
    await settle(t);
    expect(told.where((on) => on), isEmpty);
    expect(mem.rows('contacts').single['shots_on'], 1);
    await devClose(t);
  });

  testWidgets('the switch turns it on in place: the window is held, the '
      'frame queued, and the thread says so', (t) async {
    final db = await person(can: 10);
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'hello',
      'sent_at': 1000,
      'written_at': 1000,
      'msg_uid': 'm1',
    });
    await open(t);
    expect(appState.secureForced, isFalse);
    expect(find.byType(ShotsLine), findsNothing);
    await menu(t);
    expect(find.text(l10n.chatShotsWhenTheyUpdate), findsNothing);
    await t.tap(find.text(l10n.chatBlockScreenshots));
    await settle(t);
    expect(mem.rows('contacts').single['shots_on'], 1);
    expect(db.frames, ['shots $_peer']);
    expect(appState.secureForced, isTrue);
    expect(told.last, isTrue);
    // the sheet goes, and the thread has the line under the newest message
    closeSheet(t);
    await settle(t);
    expect(find.text(l10n.chatShotsYouTurnedOn), findsOneWidget);
    expect(mark(), findsOneWidget);
    // and off again
    await menu(t);
    await t.tap(find.text(l10n.chatBlockScreenshots));
    await settle(t);
    expect(mem.rows('contacts').single['shots_on'], 0);
    expect(appState.secureForced, isFalse);
    closeSheet(t);
    await settle(t);
    expect(find.text(l10n.chatShotsYouTurnedOff), findsOneWidget);
    expect(mark(), findsNothing);
    await devClose(t);
  });

  testWidgets('their change reads with their name, where it was made', (
    t,
  ) async {
    await person(on: true, can: 10, by: kShotsByThem, when: 2000);
    for (final (uid, at) in [('m1', 1000), ('m2', 3000)]) {
      await mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'in',
        'plaintext': 'text $uid',
        'sent_at': at,
        'written_at': at,
        'msg_uid': uid,
      });
    }
    await open(t, still: true);
    final line = find.text(l10n.chatShotsTheyTurnedOn(_peer));
    expect(line, findsOneWidget);
    // between the two messages
    final y = t.getCenter(line).dy;
    expect(y, greaterThan(t.getCenter(find.text('text m1')).dy));
    expect(y, lessThan(t.getCenter(find.text('text m2')).dy));
    await devClose(t);
  });

  // theirs in a chat that blocks is kept in it; mine never is; nothing is
  // kept once it is off, or while their phone does not know the block
  for (final (on, can, dir, kept, what) in [
    (true, 10, 'in', true, 'their message in a chat that blocks'),
    (true, 10, 'out', false, 'my own message in a chat that blocks'),
    (false, 10, 'in', false, 'their message once it is turned off'),
    (true, 0, 'in', false, 'their message while their phone does not know'),
  ]) {
    testWidgets(
      '$what: ${kept ? 'not copied, forwarded or saved, and '
                'opened in no other app' : 'copied, forwarded and saved as ever'}',
      (t) async {
        await person(on: on, can: can);
        await mem.insert('messages', {
          'peer_id': _peer,
          'direction': dir,
          'plaintext': 'the plan for friday',
          'sent_at': 1000,
          'written_at': 1000,
          'msg_uid': 'm1',
        });
        await open(t);
        await t.longPress(
          find.textContaining('the plan for friday', findRichText: true).first,
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        final card = find.byType(MessageMenuCard);
        Finder inCard(String s) =>
            find.descendant(of: card, matching: find.text(s));
        expect(inCard(l10n.commonCopy), kept ? findsNothing : findsOneWidget);
        expect(inCard(l10n.chatForward), kept ? findsNothing : findsOneWidget);
        expect(inCard(l10n.commonSave), kept ? findsNothing : findsOneWidget);
        expect(
          inCard(l10n.chatShotsMenuNote),
          kept ? findsOneWidget : findsNothing,
        );
        await devClose(t);
      },
    );
  }

  testWidgets('a file kept in its chat goes to no other app, with one line '
      'saying so', (t) async {
    late BuildContext ctx;
    await devOpen(
      t,
      Scaffold(
        body: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    unawaited(openReceivedFile(ctx, '/x/plan.pdf', 'plan.pdf', kept: true));
    await t.pump(const Duration(milliseconds: 300));
    expect(calls.where((m) => m == 'openFile' || m == 'shareFile'), isEmpty);
    expect(find.text(l10n.chatShotsKeptOpen), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    await devClose(t);
  });

  for (final (code, name) in [
    ('ar', 'نور الهدى من الحي القديم'),
    ('fa', 'مهتاب از کوچه‌ی قدیمی'),
    ('de', 'Jemand mit einem sehr langen Namen hier'),
  ]) {
    for (final light in [false, true]) {
      testWidgets('the line fits in $code, ${light ? 'light' : 'dark'}, '
          'at a large font size', (t) async {
        HaloColors.setLight(light);
        addTearDown(() => HaloColors.setLight(false));
        await devOpen(
          t,
          Scaffold(
            body: Column(
              children: [
                for (final on in [true, false])
                  ShotsLine(
                    on: on,
                    text: shotsLineText(on: on, mine: false, name: name),
                  ),
              ],
            ),
          ),
          locale: Locale(code),
          scale: 1.6,
          size: const Size(720, 1400),
        );
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
        expect(find.textContaining(name), findsNWidgets(2));
        await devClose(t);
      });
    }
  }
}
