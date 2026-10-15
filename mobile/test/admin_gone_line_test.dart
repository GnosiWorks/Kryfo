// SPDX-License-Identifier: GPL-3.0-or-later
// a group whose admin "this isn't them" took off this phone says so in one
// line: nothing that changes it reaches here any more, and the way out is
// beside it. a group with its admin shows no such line
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, kAdminGone, useDatabasesForTest;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g1';

// one group, paged as the phone's database pages it
class _GroupDb implements HaloDb {
  final rows = <Map<String, Object?>>[];
  // pages fetched above the newest one
  int olderPages = 0;

  // a message that carries the title of the page it first linked to
  void linked(String text, String title) {
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
          .subtract(Duration(minutes: 10 - id))
          .millisecondsSinceEpoch,
      'preview': jsonEncode({
        'url': 'https://a.example/one',
        'title': title,
        'by': 'sender',
      }),
    });
  }

  @override
  HaloContainer get container => HaloContainer.everyday;

  String? adminId = 'amber';

  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _group,
    'name': 'Friends',
    'is_admin': 0,
    'admin_id': adminId,
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
  });

  Future<void> open(WidgetTester t, _GroupDb db) async {
    phone(t);
    db.linked('hello https://a.example/one', 'A page');
    useDatabasesForTest(db, Session(db));
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  testWidgets('its admin taken off this phone: the line, and leave asks', (
    t,
  ) async {
    await open(t, _GroupDb()..adminId = kAdminGone);
    expect(find.text(l10n.groupAdminGoneLine), findsOneWidget);
    final leave = find.ancestor(
      of: find.text(l10n.groupInfoLeave),
      matching: find.byType(Container),
    );
    expect(t.getSize(leave.first).height, greaterThanOrEqualTo(44));
    await t.tap(find.text(l10n.groupInfoLeave));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(l10n.groupInfoLeaveGroup), findsOneWidget);
    await close(t);
  });

  testWidgets('a group with its admin shows no such line', (t) async {
    await open(t, _GroupDb());
    expect(find.text(l10n.groupAdminGoneLine), findsNothing);
    await close(t);
  });
}
