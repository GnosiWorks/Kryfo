// SPDX-License-Identifier: GPL-3.0-or-later
// a group's notification tapped while that group is open under another
// screen goes back to it. a second copy on top would hold its own draft and
// the lower one would write over it
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        claimChat,
        openChatForHalo,
        openRoomSoon,
        rootNavKey,
        useDatabasesForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show phone;

const _group = 'g1';
const _rows = 1;

// one group with a short thread, paged as the phone's database pages it
class _GroupDb implements HaloDb {
  final rows = <Map<String, Object?>>[];
  // pages fetched above the newest one
  int olderPages = 0;

  void add(String text) {
    final id = rows.length + 1;
    rows.add({
      'rowid': id,
      'id': id,
      'peer_id': 'amber',
      'group_id': _group,
      'direction': 'in',
      'plaintext': text,
      'msg_uid': 'uid$id',
      'sent': 1,
      'sent_at': DateTime.now()
          .subtract(Duration(minutes: _rows + 1 - id))
          .millisecondsSinceEpoch,
    });
  }

  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<bool> groupExists(String groupId) async => groupId == _group;

  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _group,
    'name': 'Friends',
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
  }) async {
    if (beforeRowid != null) olderPages++;
    final older = [
      for (final r in rows)
        if (beforeRowid == null || (r['rowid'] as int) < beforeRowid) r,
    ];
    return older.sublist(older.length > limit ? older.length - limit : 0);
  }

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    lockState.openForTest();
  });

  Future<void> frames(WidgetTester t, int n) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a tap for a group open under another screen goes back to '
      'it', (t) async {
    phone(t);
    final db = _GroupDb()..add('note 1');
    useDatabasesForTest(db, Session(db));
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GroupChatScreen(groupId: _group),
      ),
    );
    await frames(t, 20);
    rootNavKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('above'))),
      ),
    );
    await frames(t, 10);
    // the screen above is someone's chat, being read
    claimChat('someone-else-here');
    await openChatForHalo('group:$_group');
    await frames(t, 20);
    expect(find.text('above', skipOffstage: false), findsNothing);
    expect(find.byType(GroupChatScreen, skipOffstage: false), findsOne);
    // a link for a room already open goes back to it the same way
    rootNavKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('above'))),
      ),
    );
    await frames(t, 10);
    openRoomSoon(_group);
    await frames(t, 20);
    expect(find.text('above', skipOffstage: false), findsNothing);
    expect(find.byType(GroupChatScreen, skipOffstage: false), findsOne);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });
}
