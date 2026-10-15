// SPDX-License-Identifier: GPL-3.0-or-later
// an album in a group works as in a 1:1: its rows are one bubble in album
// order, under its sender's name, one sender's album never takes another's
// rows, and a timed album is read as one, every item at once
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart' show AlbumTag;
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/album_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g1';
const _id = '0f0e0d0c0b0a0908';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAADCAIAAAA7ljmRAAAAEElEQVR4nGP4Oo8bjhhwcgCFmhNpSPXr6AAAAABJRU5ErkJggg==',
);

class _GroupDb implements HaloDb {
  final rows = <Map<String, Object?>>[];
  final asked = <String>[];

  void add(
    String uid,
    String text, {
    int? burnSecs,
    String from = 'amber',
    Map<String, Object?> more = const {},
  }) {
    final id = rows.length + 1;
    rows.add({
      ...more,
      'rowid': id,
      'id': id,
      'peer_id': from,
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
    int? beforeAt,
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
  }) async => [
    for (final r in rows)
      if (r['pinned'] == 1) {...r},
  ];
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
  Future<void> purgeExpiredBurns({
    Future<Set<String>> Function()? blocked,
  }) async {}
  @override
  Future<void> deleteMessage(String msgUid) async {}

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('album_group');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  late _GroupDb db;

  Future<void> frames(WidgetTester t, int n) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  // one of [from]'s album, [i] of [n]
  void item(
    _GroupDb db,
    int i,
    int n, {
    String from = 'amber',
    String id = _id,
    int? burnSecs,
    String caption = '',
  }) {
    final f = File('${dir.path}/$from$id$i.png')..writeAsBytesSync(_png);
    db.add(
      '$from-$id-$i',
      caption,
      from: from,
      burnSecs: burnSecs,
      more: {'media_path': f.path, ...AlbumTag(id, n, i).toRow()},
    );
  }

  Future<void> open(WidgetTester t, void Function(_GroupDb db) rows) async {
    phone(t);
    lockState.openForTest();
    db = _GroupDb();
    db.add('hello', 'hello all');
    rows(db);
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

  List<String> order(AlbumGrid g) => [
    for (final x in g.tiles) x?.path?.split('/').last ?? '-',
  ];

  testWidgets('a group album is one bubble in album order', (t) async {
    await open(t, (db) {
      item(db, 1, 3);
      item(db, 2, 3);
      item(db, 0, 3, caption: 'from the hike');
    });
    expect(find.byType(AlbumGrid), findsOneWidget);
    expect(order(t.widget<AlbumGrid>(find.byType(AlbumGrid))), [
      'amber${_id}0.png',
      'amber${_id}1.png',
      'amber${_id}2.png',
    ]);
    expect(find.text('from the hike', findRichText: true), findsOneWidget);
    expect(find.text('hello all', findRichText: true), findsOneWidget);
    await close(t);
  });

  testWidgets('two senders with the same album id are two albums', (t) async {
    await open(t, (db) {
      item(db, 0, 2);
      item(db, 1, 2, from: 'birch');
      item(db, 1, 2);
      item(db, 0, 2, from: 'birch');
    });
    final grids = t.widgetList<AlbumGrid>(find.byType(AlbumGrid)).toList();
    expect(grids, hasLength(2));
    expect(order(grids[0]), ['amber${_id}0.png', 'amber${_id}1.png']);
    expect(order(grids[1]), ['birch${_id}0.png', 'birch${_id}1.png']);
    await close(t);
  });

  testWidgets('a timed album is read as one', (t) async {
    await open(t, (db) {
      for (var i = 0; i < 3; i++) {
        item(db, i, 3, burnSecs: 300);
      }
    });
    final uids = ['amber-$_id-0', 'amber-$_id-1', 'amber-$_id-2'];
    expect(db.asked.toSet(), containsAll(uids));
    final at = {for (final u in uids) db.burnAt(u)};
    expect(at, hasLength(1));
    expect(at.single, isNotNull);
    await close(t);
  });
}
