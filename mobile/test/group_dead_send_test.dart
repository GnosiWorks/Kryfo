// SPDX-License-Identifier: GPL-3.0-or-later
// a group message reloaded as 'sending' has no send left to settle it. once
// the route can carry traffic it is marked failed and goes again on its own,
// also when the route comes up while the group is open, and also when it
// comes up while another message of the group is on its way. a file still
// going out is never marked failed, however long it takes
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, appState, useDatabasesForTest;
import 'package:kryfo/media_send.dart' show mediaInflight;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/polls.dart' show PollSpec, PollVote;
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g1';
const _stale = 'uid-stale';
const _file = 'uid-file';

// a phone's database with one group, as the group screen reads it. a send
// that asks for its poll row first is held there until [hold] completes
class _GroupDb implements HaloDb {
  _GroupDb(this.rows);

  final List<Map<String, Object?>> rows;
  final asked = <String>[];
  Completer<void>? hold;

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
  Future<List<String>> getGroupMembers(String groupId) async => ['a', 'b'];
  @override
  Future<Set<String>> blockedIds() async => {};
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int limit = 60,
  }) async => [...rows];
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
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> markRoomSeen(String groupId) async {}
  @override
  Future<void> clearGroupUnread(String groupId) async {}

  // a send starts here: noted, held when asked to, then refused, so it
  // fails without anything leaving
  @override
  Future<({PollSpec spec, String? groupId, bool mine})?> pollRow(
    String uid,
  ) async {
    asked.add(uid);
    final h = hold;
    if (h != null && uid != _stale && uid != _file) await h.future;
    throw StateError('no sending in this test');
  }

  // nothing in this test ever goes out
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: false, delivered: false);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Map<String, Object?> _out(int rowid, String uid, {String? file}) => {
  'rowid': rowid,
  'id': rowid,
  'peer_id': 'me',
  'group_id': _group,
  'direction': 'out',
  'plaintext': 'hello $rowid',
  'msg_uid': uid,
  'sent': 0,
  'sent_at': DateTime.now()
      .subtract(const Duration(minutes: 2))
      .millisecondsSinceEpoch,
  'file_name': ?file,
};

Future<_GroupDb> _open(WidgetTester t) async {
  phone(t);
  // the file row has no path on disk, so a retry of it would start at its
  // poll row as a text one does, and be seen
  final db = _GroupDb([_out(1, _stale), _out(2, _file, file: 'notes.pdf')]);
  useDatabasesForTest(db, Session(db));
  mediaInflight.add(_file);
  addTearDown(() => mediaInflight.remove(_file));
  appState.sendModeForTest = 'private';
  appState.setRouteOKForTest(true);
  appState.setTorStatusForTest(TorStatus.starting);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
  await t.pump(const Duration(seconds: 1));
  return db;
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    appState.sendModeForTest = 'private';
    appState.setTorStatusForTest(TorStatus.off);
  });

  testWidgets('the route coming up settles a dead send, not a file going out', (
    t,
  ) async {
    final db = await _open(t);
    // still warming up: queued, not dead, so nothing goes again
    await t.pump(const Duration(seconds: 31));
    expect(db.asked, isEmpty);

    appState.setTorStatusForTest(TorStatus.publishing);
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 31));
    expect(db.asked, contains(_stale));
    expect(db.asked, isNot(contains(_file)));
    await _close(t);
  });

  testWidgets('a send on its way when the route comes up only delays it', (
    t,
  ) async {
    final db = await _open(t);
    db.hold = Completer<void>();
    await t.enterText(find.byType(TextField), 'one more');
    await t.pump();
    await t.tap(find.bySemanticsLabel(l10n.commonSend));
    await t.pump(const Duration(milliseconds: 300));
    expect(db.asked, hasLength(1));

    appState.setTorStatusForTest(TorStatus.publishing);
    await t.pump(const Duration(seconds: 1));
    db.hold!.complete();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 31));
    expect(db.asked, contains(_stale));
    expect(db.asked, isNot(contains(_file)));
    await _close(t);
  });
}
