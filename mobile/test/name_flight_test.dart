// SPDX-License-Identifier: GPL-3.0-or-later
// a chat opened from the list shows the name given them, or the group's,
// in its header on every frame of the way in and back out, and so does the
// contact page opened from the chat
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/main.dart'
    show
        GroupPreview,
        HaloEngine,
        NotifChat,
        appState,
        notifTargetFor,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_door.dart';
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/contact_screen.dart';
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'wren-oak-lamp';
const _group = 'g1';

class _Db extends DevTestDb {
  _Db(super.mem);

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  bool _flag(String id, String col) => _contact(id)?[col] == 1;

  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _contact(haloId);
  @override
  Future<bool> isAccepted(String haloId) async => _flag(haloId, 'accepted');
  @override
  Future<bool> isBackPaired(String peerId) async =>
      _flag(peerId, 'back_paired');
  @override
  Future<bool> isBlocked(String haloId) async => _flag(haloId, 'blocked');
  @override
  Future<bool> isMuted(String haloId) async => _flag(haloId, 'muted');
  @override
  Future<bool> isVerified(String haloId) async => _flag(haloId, 'verified');
  @override
  Future<bool> keyChanged(String haloId) async => false;
  @override
  Future<String?> getAtmosphere(String peerId) async => null;
  @override
  Future<void> clearUnread(String peerId) async {}
  @override
  Future<void> dropHeld(String peerId) async {}
  @override
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async =>
      0;
  @override
  Future<int> countMessagesTo(String peerId) async => 0;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> purgeExpiredBurns({
    Future<Set<String>> Function()? blocked,
  }) async {}
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async => [];
  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => [];
  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => [];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  // the group, as its chat reads it
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _group,
    'name': 'Hikers',
    'is_admin': 1,
  };
  @override
  Future<bool> groupExists(String groupId) async => true;
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async => ['me', _peer];
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => [];
  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async =>
      [];
  @override
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async => [];
  @override
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async => {};
  @override
  Future<Map<String, ({int have, int of, int gaveUp})>> groupFileReach(
    String groupId,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  @override
  Future<void> clearGroupUnread(String groupId) async {}
  @override
  Future<List<Map<String, Object?>>> mediaFor(String peerId) async => [];
  @override
  Future<int?> firstMessageAt(String peerId) async => null;
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
}

// the relay: nothing is answered
class _Engine implements HaloEngine {
  @override
  String myEdPubkey() => 'ed-me';
  @override
  String myXPubkey() => 'x-me';
  @override
  void nostrSubscribeBg(String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

// what a page draws at a name's size, offstage and in flight too
List<String> _texts(WidgetTester t, Finder page, bool Function(TextStyle) at) =>
    [
      for (final w in t.widgetList<Text>(
        find.descendant(
          of: page,
          matching: find.byType(Text, skipOffstage: false),
          skipOffstage: false,
        ),
      ))
        if (w.style != null && at(w.style!)) w.data ?? '',
    ];

// the chat header's name line
bool _chatName(TextStyle s) =>
    s.fontSize == 14 && s.fontWeight == FontWeight.w500;
// the group header's
bool _groupName(TextStyle s) =>
    s.fontSize == 15 && s.fontWeight == FontWeight.w500;
// the contact page's big name
bool _pageName(TextStyle s) => s.fontSize == 26;

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
    useEngineForTest(_Engine());
    lockState.openForTest();
    docs = Directory.systemTemp.createTempSync('name_flight');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
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
      'nickname': 'Mira',
    });
    final db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    appState.groups = [
      GroupPreview(
        groupId: _group,
        name: 'Hikers',
        memberCount: 3,
        isAdmin: true,
        createdAt: DateTime(2026),
      ),
    ];
  });

  tearDown(() {
    appState.groups = [];
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  // the chat list as the app wires it
  Widget home() => Builder(
    builder: (context) => HomeScreen(
      haloId: 'neon-tiger-saturn',
      contacts: appState.contacts,
      groups: [
        for (final g in appState.groups)
          GroupSummary(
            groupId: g.groupId,
            name: g.name,
            memberCount: g.memberCount,
          ),
      ],
      onAddContact: () {},
      onNewGroup: () {},
      onNewRoom: () {},
      onOpenDev: () {},
      onOpenSettingsDirect: () {},
      onOpenChat: (id) => openChatAt(context, peer: id),
      onOpenGroup: (id) => openChatAt(context, groupId: id),
    ),
  );

  // one frame at a time, with the database's answers let in between, so a
  // read that lands mid-flight is seen
  Future<void> frames(WidgetTester t, void Function(int) check) async {
    for (var i = 0; i < 40; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await t.pump(const Duration(milliseconds: 16));
      check(i);
    }
  }

  // the three words never stand as a name anywhere, the flying face included
  void noWordsAsName(WidgetTester t, int i) => expect(
    _texts(t, find.byType(MaterialApp), (s) => (s.fontSize ?? 0) >= 14),
    isNot(contains(_peer)),
    reason: 'frame $i',
  );

  // read before any chat is open: the one on screen is never a target
  test('a notification tap opens with the name given them in hand', () async {
    final target = await notifTargetFor(_peer);
    expect(target, isA<NotifChat>());
    expect((target as NotifChat).row['nickname'], 'Mira');
  });

  for (final still in [false, true]) {
    final how = still ? ' (reduced motion)' : '';

    testWidgets('a chat opened from the list shows the name given them on '
        'every frame, there and back$how', (t) async {
      await devOpen(t, home(), still: still);
      await t.tap(find.text('Mira'));
      var opened = false;
      await frames(t, (i) {
        final chat = find.byType(ChatScreen, skipOffstage: false);
        if (chat.evaluate().isEmpty) {
          // the row is still being read: nothing pushed yet
          expect(opened, isFalse, reason: 'frame $i');
          return;
        }
        opened = true;
        expect(_texts(t, chat, _chatName), ['Mira'], reason: 'frame $i');
        noWordsAsName(t, i);
      });
      expect(opened, isTrue);
      await t.tap(find.byTooltip(l10n.commonBack));
      await frames(t, (i) {
        final chat = find.byType(ChatScreen, skipOffstage: false);
        if (chat.evaluate().isEmpty) return;
        expect(_texts(t, chat, _chatName), ['Mira'], reason: 'frame $i');
        noWordsAsName(t, i);
      });
      expect(find.byType(ChatScreen, skipOffstage: false), findsNothing);
      await devClose(t);
    });

    testWidgets('a group opened from the list shows its name on every '
        'frame, there and back$how', (t) async {
      await devOpen(t, home(), still: still);
      await t.tap(find.text('Hikers'));
      var opened = false;
      await frames(t, (i) {
        final chat = find.byType(GroupChatScreen, skipOffstage: false);
        if (chat.evaluate().isEmpty) {
          expect(opened, isFalse, reason: 'frame $i');
          return;
        }
        opened = true;
        expect(_texts(t, chat, _groupName), ['Hikers'], reason: 'frame $i');
      });
      expect(opened, isTrue);
      await t.tap(find.byTooltip(l10n.commonBack));
      await frames(t, (i) {
        final chat = find.byType(GroupChatScreen, skipOffstage: false);
        if (chat.evaluate().isEmpty) return;
        expect(_texts(t, chat, _groupName), ['Hikers'], reason: 'frame $i');
      });
      expect(find.byType(GroupChatScreen, skipOffstage: false), findsNothing);
      await devClose(t);
    });
  }

  testWidgets('the contact page opened from a chat the list does not hold '
      'shows the name given them from its first frame', (t) async {
    await devOpen(t, home());
    await t.tap(find.text('Mira'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    // a chat kept off the list, as a support chat is
    appState.contacts = [];
    await t.tap(find.bySemanticsLabel(l10n.chatViewContact));
    var opened = false;
    await frames(t, (i) {
      final page = find.byType(ContactScreen, skipOffstage: false);
      if (page.evaluate().isEmpty) return;
      opened = true;
      expect(_texts(t, page, _pageName), ['Mira'], reason: 'frame $i');
      noWordsAsName(t, i);
    });
    expect(opened, isTrue);
    await devClose(t);
  });
}
