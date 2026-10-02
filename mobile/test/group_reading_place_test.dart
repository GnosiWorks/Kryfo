// SPDX-License-Identifier: GPL-3.0-or-later
// a new message in a group leaves someone reading back where they are, and
// the jump button counts only what came in, never the pages scrolled in.
// near the newest, where no jump button shows, the new message is followed
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show HaloDb, appState, useDatabasesForTest;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/chat_parts.dart' show JumpDownButton;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g1';
const _rows = 200;

// one group with a long thread, paged as the phone's database pages it
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
  Future<Map<String, ({int have, int of})>> groupFileReach(
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

  late _GroupDb db;

  // frames, not one long pump: the screen's work waits on frames
  Future<void> frames(WidgetTester t, int n) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester t) async {
    phone(t);
    db = _GroupDb();
    for (var i = 1; i <= _rows; i++) {
      db.add('note $i');
    }
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

  ScrollPosition thread(WidgetTester t) => t
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((s) => s.axisDirection == AxisDirection.down)
      .position;

  JumpDownButton jump(WidgetTester t) =>
      t.widget<JumpDownButton>(find.byType(JumpDownButton));

  bool seen(String text) =>
      find.text(text, findRichText: true).hitTestable().evaluate().isNotEmpty;

  Future<void> arrive(WidgetTester t, String text) async {
    db.add(text);
    appState.chatChanged('group:$_group');
    await frames(t, 6);
  }

  testWidgets('a new message while reading back leaves the place, and the '
      'jump button counts it, not the pages scrolled in', (t) async {
    await open(t);
    // up to the top of the first page, which brings in the next one
    thread(t).jumpTo(0);
    await frames(t, 10);
    expect(db.olderPages, greaterThan(0));
    expect(jump(t).shown, isTrue);
    expect(jump(t).count, 0);
    final at = thread(t).pixels;

    await arrive(t, 'new 1');
    await arrive(t, 'new 2');
    expect(thread(t).pixels, at);
    expect(seen('new 2'), isFalse);
    expect(jump(t).shown, isTrue);
    expect(jump(t).count, 2);

    await t.tap(find.byType(JumpDownButton));
    await frames(t, 10);
    expect(seen('new 2'), isTrue);
    expect(jump(t).count, 0);
    await close(t);
  });

  testWidgets('a new message near the newest is followed', (t) async {
    await open(t);
    final end = thread(t).maxScrollExtent;
    thread(t).jumpTo(end - 150);
    await frames(t, 5);
    expect(jump(t).shown, isFalse);

    await arrive(t, 'new 1');
    expect(thread(t).pixels, thread(t).maxScrollExtent);
    expect(seen('new 1'), isTrue);
    expect(jump(t).count, 0);
    await close(t);
  });
}
