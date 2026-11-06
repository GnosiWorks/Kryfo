// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's home, chat and group chat, pixel for pixel as they were before the wide
// desktop layout: nothing of it reaches the phone. the message field's word
// keeps one line
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
        HaloDb,
        appState,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'calm-grey-heron';
const _phone = Size(1080, 2340);

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

class _GroupDb implements HaloDb {
  final rows = <Map<String, Object?>>[
    for (final (id, out, text) in [
      (1, false, 'the trail is open again'),
      (2, true, 'good, saturday then, the long loop by the lake'),
    ])
      {
        'rowid': id,
        'id': id,
        'peer_id': out ? 'me' : 'amber',
        'group_id': 'g1',
        'direction': out ? 'out' : 'in',
        'plaintext': text,
        'msg_uid': 'uid$id',
        'sent': 1,
        'sent_at': id * 1000,
      },
  ];

  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': 'g1',
    'name': 'Hikers',
    'is_admin': 0,
  };
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async => ['amber'];
  @override
  Future<Set<String>> blockedIds() async => {};
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => beforeRowid == null ? [...rows] : [];
  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async =>
      [...rows];
  @override
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async => [
    for (final r in rows)
      if ((r['rowid'] as int) > afterRowid) r,
  ];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async => {};
  @override
  Future<Map<String, ({int have, int of, int gaveUp})>> groupFileReach(
    String groupId,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<bool> isAccepted(String haloId) async => true;
  @override
  Future<void> markRoomSeen(String groupId) async {}
  @override
  Future<void> clearGroupUnread(String groupId) async {}
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: true, delivered: true);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  setUp(() {
    onDesktop = false;
    homeClock = () => DateTime(2026, 10, 29, 12);
  });
  tearDown(() => homeClock = DateTime.now);

  testWidgets('the phone home is unchanged', (t) async {
    _prefs();
    lockState.openForTest();
    await t.runAsync(
      () => devWorld(chats: [('amber-new-river', 5, false), (_peer, 3, false)]),
    );
    await devOpen(
      t,
      devHome(
        groups: const [
          GroupSummary(groupId: 'g1', name: 'Hikers', memberCount: 3),
        ],
      ),
      size: _phone,
      ratio: 3,
      still: true,
    );
    await _settle(t);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/phone_home.png'),
    );
    await devClose(t);
  });

  testWidgets('the phone chat is unchanged', (t) async {
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
      size: _phone,
      ratio: 3,
      still: true,
    );
    await _settle(t);
    await expectLater(
      find.byType(ChatScreen),
      matchesGoldenFile('goldens/phone_chat.png'),
    );
    // the field's word keeps one line, however narrow large text makes it
    final field = t.widget<TextField>(find.byType(TextField).last);
    expect(field.decoration!.hintMaxLines, 1);
    await devClose(t);
  });

  testWidgets('the phone group chat is unchanged', (t) async {
    _prefs();
    lockState.openForTest();
    final docs = Directory.systemTemp.createTempSync('phone_layout');
    addTearDown(() => docs.deleteSync(recursive: true));
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    addTearDown(() => mockChannel('plugins.flutter.io/path_provider', null));
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    useLibrary();
    final db = _GroupDb();
    useDatabasesForTest(db, Session(db));
    await devOpen(
      t,
      const GroupChatScreen(groupId: 'g1'),
      size: _phone,
      ratio: 3,
      still: true,
    );
    await _settle(t);
    await expectLater(
      find.byType(GroupChatScreen),
      matchesGoldenFile('goldens/phone_group_chat.png'),
    );
    await devClose(t);
  });
}
