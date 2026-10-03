// SPDX-License-Identifier: GPL-3.0-or-later
// in a group, someone's timed message starts counting when it is shown here,
// as in a 1:1: never under the lock, and from its whole window, which the
// countdown reads as it starts
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/burn_fade.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g1';
const _timed = 'timed01';

class _GroupDb implements HaloDb {
  final rows = <Map<String, Object?>>[];
  final asked = <String>[];

  void add(String uid, String text, {int? burnSecs}) {
    final id = rows.length + 1;
    rows.add({
      'rowid': id,
      'id': id,
      'peer_id': 'amber',
      'group_id': _group,
      'direction': 'in',
      'plaintext': text,
      'msg_uid': uid,
      'sent': 1,
      'burn_secs': burnSecs,
      'burn_at': null,
      'sent_at': DateTime.now().millisecondsSinceEpoch - 60000 + id,
    });
  }

  int? burnAt(String uid) =>
      rows.firstWhere((r) => r['msg_uid'] == uid)['burn_at'] as int?;

  // as the real one: an unlit timed row that came in starts now
  @override
  Future<Map<String, int>> lightReadBurns(List<String> msgUids) async {
    asked.addAll(msgUids);
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <String, int>{};
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      if (!msgUids.contains(uid) || r['direction'] != 'in') continue;
      final secs = r['burn_secs'] as int?;
      r['burn_at'] ??= secs == null ? null : now + secs * 1000;
      final at = r['burn_at'] as int?;
      if (at != null) out[uid] = at;
    }
    return out;
  }

  @override
  HaloContainer get container => HaloContainer.everyday;
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
    int limit = 60,
  }) async => [
    for (final r in rows)
      if (beforeRowid == null || (r['rowid'] as int) < beforeRowid) {...r},
  ];
  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async =>
      [
        for (final r in rows) {...r},
      ];
  @override
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async => [
    for (final r in rows)
      if ((r['rowid'] as int) > afterRowid) {...r},
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
  Future<void> purgeExpiredBurns() async {}
  @override
  Future<void> deleteMessage(String msgUid) async {}

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

  late _GroupDb db;

  Future<void> frames(WidgetTester t, int n) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester t) async {
    phone(t);
    db = _GroupDb();
    for (var i = 1; i <= 3; i++) {
      db.add('uid$i', 'note $i');
    }
    db.add(_timed, 'gone soon', burnSecs: 300);
    useDatabasesForTest(db, Session(db));
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
    await frames(t, 20);
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  bool waits(WidgetTester t) =>
      t.widget<BurnFlame>(find.byType(BurnFlame)).waiting;

  testWidgets('shown, it starts counting from its whole window', (t) async {
    lockState.openForTest();
    final before = DateTime.now().millisecondsSinceEpoch;
    await open(t);
    final at = db.burnAt(_timed);
    expect(at, isNotNull);
    expect(at, greaterThanOrEqualTo(before + 300000));
    expect(waits(t), isFalse);
    // five minutes reads 5m as it starts, not 4m a moment in
    expect(find.text(' 5m'), findsOneWidget);
    await close(t);
  });

  testWidgets('under the lock it waits, then starts as the lock lifts', (
    t,
  ) async {
    lockState.openForTest(enabled: true);
    lockState.lock();
    await open(t);
    expect(db.burnAt(_timed), isNull);
    expect(db.asked, isEmpty);
    expect(find.text(' 5m'), findsOneWidget);
    expect(waits(t), isTrue);

    lockState.openForTest(enabled: true);
    // and its listeners hear of it
    lockState.inDecoy = false;
    await frames(t, 10);
    expect(db.burnAt(_timed), isNotNull);
    expect(waits(t), isFalse);
    expect(find.text(' 5m'), findsOneWidget);
    await close(t);
  });
}
