// SPDX-License-Identifier: GPL-3.0-or-later
// a group's screenshot block on screen: the admin's switch and who it
// waits for, a member's row that only reads, a room's that never changes,
// none for an ended group. the group screen holds the window's flag from
// its first frame, keeps others' messages from the menu and says so, and
// shows the lock and the line where it changed. in persian and at twice
// the text it fits, and with reduced motion it shows at once. the
// database is a stand-in
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/typing.dart' show kCapGroupShots;
import 'package:kryfo/chat_shots.dart' show kShotsByThem;
import 'package:kryfo/capture_watch.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/drafts.dart' show Draft;
import 'package:kryfo/group_shots.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        wallKey,
        GroupPreview,
        HaloDb,
        appState,
        useDatabasesForTest,
        AppStateRoute,
        AppStateScreen;
import 'package:kryfo/message_envelope.dart' show GroupControl;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/rooms.dart' show kRoomJoinWait;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/screens/group_info_screen.dart';
import 'package:kryfo/screens/home_screen.dart' show ContactPreview;
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/halo_switch.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:kryfo/widgets/shots_line.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g1';
const _anna = 'thumb-behave-boring';
const _bo = 'river-stone-quiet';
// this phone's key in a room, and a joiner's
final _roomPub = 'ab' * 32;
final _joiner = 'cd' * 32;

// a phone's database with one group and the people in it. [gate] holds
// every first read of the group until it completes
class _Db implements HaloDb {
  _Db({
    this.rows = const [],
    this.members = const ['me', _anna],
    this.blocked = const {},
    this.room = false,
  });

  final List<Map<String, Object?>> rows;
  List<String> members;
  // a burner room this phone made, its link already handed out
  final bool room;
  // a room joined off a link, not let in yet: when the join went
  int? joiningAt;
  // the admin on record, and who ended the group
  String? adminId;
  String? endedBy;
  // this phone is a member, not the admin
  bool member = false;
  // when each knock again went
  final knocks = <int?>[];
  final Set<String> blocked;
  Completer<void>? gate;
  // holds the group's whole history, read for its photos
  Completer<void>? history;
  Completer<void>? muting;
  Completer<bool>? verified;

  Future<void> _wait() async {
    final g = gate;
    if (g != null) await g.future;
  }

  // a quiet one keeps a reaction from here on the phone
  HaloContainer box = HaloContainer.everyday;
  @override
  HaloContainer get container => box;

  // the drafts table, as the file keeps it across a process
  final kept = <String, Draft>{};
  @override
  bool get isOpen => true;
  @override
  Future<Draft?> draftOf(String chatId, {required bool group}) async =>
      kept[wallKey(chatId, group: group)];
  @override
  Future<void> putDraft(String chatId, Draft d, {required bool group}) async =>
      kept[wallKey(chatId, group: group)] = d;
  @override
  Future<void> dropDraftRow(String chatId, {required bool group}) async =>
      kept.remove(wallKey(chatId, group: group));

  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async {
    await _wait();
    return {
      'group_id': _group,
      'name': 'Friends',
      'is_admin': joiningAt == null && !member ? 1 : 0,
      'admin_id': adminId,
      if (endedBy != null) ...{'ended_at': 1, 'ended_by': endedBy},
      ...shots,
      if (room) ...{
        'joining_at': joiningAt,
        'room_pub': _roomPub,
        'room_priv': 'ef' * 32,
        'creator_pub': _joiner,
        'fc_pk': 'fc' * 32,
        'expires_at': DateTime.now()
            .add(const Duration(hours: 24))
            .millisecondsSinceEpoch,
        'room_seen': 1,
      },
    };
  }

  @override
  Future<bool> groupExists(String groupId) async => true;
  @override
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async => [];
  @override
  Future<int> nextRoomSeq(String groupId) async => knocks.length;
  // the keys a room listens to, noted before it does
  final listened = <String>{};
  @override
  Future<bool> noteRoomKeys(String groupId, Iterable<String> keys) async {
    listened.addAll(keys);
    return true;
  }

  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async {
    await _wait();
    return members;
  }

  @override
  Future<Set<String>> blockedIds() async => blocked;
  // a page as the database gives it: the newest [limit] before a row
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async {
    final older = [
      for (final r in rows)
        if (beforeRowid == null || (r['rowid'] as int) < beforeRowid) r,
    ];
    return older.sublist(older.length > limit ? older.length - limit : 0);
  }

  // one row by its uid, as a kept quote older than the page reads it,
  // after [quoteGate] when a test holds it
  int quoteReads = 0;
  Completer<void>? quoteGate;
  @override
  Future<Map<String, Object?>?> groupMessageIn(
    String groupId,
    String msgUid,
  ) async {
    quoteReads++;
    final gate = quoteGate;
    if (gate != null) await gate.future;
    for (final r in rows) {
      if (r['msg_uid'] == msgUid && r['group_id'] == groupId) return r;
    }
    return null;
  }

  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async {
    await _wait();
    final h = history;
    if (h != null) await h.future;
    return [...rows];
  }

  @override
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async => [
    for (final r in rows)
      if ((r['rowid'] as int) > afterRowid) r,
  ];
  // who reacted to what, '' for this phone
  final reactions = <String, List<MapEntry<String, String>>>{};
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {
    for (final u in msgUids)
      if (reactions[u] case final r?) u: List.of(r),
  };
  @override
  Future<void> addReaction(
    String msgUid,
    String reactor,
    String emoji, {
    int? at,
  }) async {
    final r = reactions.putIfAbsent(msgUid, () => []);
    r.removeWhere((e) => e.key == reactor);
    r.add(MapEntry(reactor, emoji));
  }

  @override
  Future<void> removeReaction(String msgUid, String reactor) async =>
      reactions[msgUid]?.removeWhere((e) => e.key == reactor);
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
  // the list read again once the group is marked read: the one it had
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  @override
  Future<void> markRoomSeen(String groupId) async {}
  @override
  Future<void> setRoomJoining(String groupId, int? at) async {
    joiningAt = at;
  }

  // a knock again: [shut] as a vault shut under it
  bool shut = false;
  @override
  Future<bool> restartRoomJoining(String groupId, int at) async {
    if (shut) throw StateError('shut');
    if (joiningAt == null) return false;
    knocks.add(at);
    joiningAt = at;
    return true;
  }

  @override
  Future<bool> failRoomJoining(String groupId, int at) async {
    if (joiningAt != at) return false;
    joiningAt = at - kRoomJoinWait.inMilliseconds;
    return true;
  }

  @override
  Future<void> clearGroupUnread(String groupId) async {}
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: false, delivered: false);

  // a person's page
  @override
  Future<Map<String, Object?>?> getContact(String haloId) async {
    await _wait();
    return {
      'halo_id': haloId,
      'nickname': haloId == _anna ? 'Anna' : null,
      'xpub': 'ab' * 32,
      'accepted': 1,
    };
  }

  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<List<Map<String, Object?>>> mediaFor(String peerId) async => [];
  @override
  Future<int?> firstMessageAt(String peerId) async => null;
  @override
  Future<void> setMuted(String haloId, bool muted) async {
    final m = muting;
    if (m != null) await m.future;
  }

  @override
  Future<bool> isVerified(String haloId) async {
    final v = verified;
    return v == null ? false : await v.future;
  }

  // the key held for them: the one the page was opened with
  @override
  Future<String?> heldKey(String haloId) async => 'cd' * 32;

  // the group's block as its row holds it, and what each person's app can
  // do
  final shots = <String, Object?>{};
  final caps = <String, Set<String>>{};
  final queued = <String>[];
  @override
  Future<Map<String, Set<String>>> capsOfPeople(Iterable<String> ids) async => {
    for (final id in ids)
      if (caps[id] != null) id: caps[id]!,
  };
  @override
  Future<GroupShots> groupShotsOf(String groupId) async =>
      GroupShots.ofRow(await getGroup(groupId), quiet: box.quiet);
  @override
  Future<GroupShotsWord?> turnGroupShots(
    String groupId, {
    required bool on,
    required bool all,
  }) async {
    final put = groupShotsTurned(
      await groupShotsOf(groupId),
      on: on,
      all: all,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    shots.addAll(put);
    return GroupShotsWord(on: on, all: on && all, at: put['shots_at'] as int);
  }

  @override
  Future<void> queueGroupCtl(
    String groupId,
    Iterable<String> members,
    GroupControl ctl, {
    required int now,
  }) async => queued.add(ctl.type);
  @override
  Future<void> queueGroupWrapped(
    String groupId,
    Iterable<String> members,
    String wrapped, {
    required int now,
  }) async => queued.add('words');
  @override
  Future<String?> notifTagOf(String chat) async => null;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Map<String, Object?> _in(int rowid, String from, String text) => {
  'rowid': rowid,
  'id': rowid,
  'peer_id': from,
  'group_id': _group,
  'direction': from == 'me' ? 'out' : 'in',
  'plaintext': text,
  'msg_uid': 'uid-$rowid',
  'sent': 1,
  'sent_at': DateTime.now()
      .subtract(Duration(minutes: 10 - rowid))
      .millisecondsSinceEpoch,
};

ContactPreview _contact(String id, {String? nick}) =>
    ContactPreview(haloId: id, nickname: nick, avatarSeed: id);

_Db _use(WidgetTester t, _Db db) {
  phone(t);
  // tall enough that the whole info page is laid out
  t.view.physicalSize = const Size(1080, 9000);
  useDatabasesForTest(db, Session(db));
  appState.myId = 'me';
  appState.sendModeForTest = 'private';
  appState.setRouteOKForTest(true);
  appState.setTorStatusForTest(TorStatus.reachable);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  return db;
}

// frames enough for what eases in after a read to land
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 6));
}

// the admin's group, with anna and bo in it
_Db _mine({Map<String, Object?> shots = const {}}) {
  final db = _Db(members: const ['me', _anna, _bo])..adminId = 'me';
  db.shots.addAll(shots);
  return db;
}

// anna's group, this phone a member
_Db _theirs({
  Map<String, Object?> shots = const {},
  List<Map<String, Object?>> rows = const [],
}) {
  final db = _Db(members: const ['me', _anna, _bo], rows: [...rows])
    ..adminId = _anna
    ..member = true;
  db.shots.addAll(shots);
  return db;
}

const _waiting = {'shots_on': 1, 'shots_at': 5};
const _forAll = {'shots_on': 1, 'shots_all': 1, 'shots_at': 5};

Finder _hint(String s) => find.text(s);

HaloSwitch _switch(WidgetTester t) => t.widget<HaloSwitch>(
  find.descendant(
    of: find.ancestor(
      of: find.text(l10n.chatBlockScreenshots),
      matching: find.byType(InkWell),
    ),
    matching: find.byType(HaloSwitch),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.groups = [];
    appState.contacts = [];
    lockState.openForTest();
  });

  tearDown(() {
    appState.groups = [];
    appState.contacts = [];
    appState.setTorStatusForTest(TorStatus.off);
  });

  group('the info page', () {
    testWidgets('the admin\'s switch: off, then waiting with who, then on '
        'for everyone', (t) async {
      final db = _use(t, _mine());
      db.caps[_anna] = {kCapGroupShots};
      appState.contacts = [_contact(_anna, nick: 'Anna'), _contact(_bo)];
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await _settle(t);
      expect(_hint(l10n.groupShotsBlocksAll), findsOneWidget);
      expect(_switch(t).value, isFalse);
      expect(_switch(t).onChanged, isNotNull);
      await t.tap(find.text(l10n.chatBlockScreenshots));
      await _settle(t);
      expect(db.shots['shots_on'], 1);
      expect(db.queued, contains('shots'));
      expect(_hint(l10n.groupShotsStartsWhenAll), findsOneWidget);
      expect(find.text(l10n.groupShotsWaitingFor(1)), findsOneWidget);
      expect(appState.secureForced, isTrue);
      // the sheet names who, and a tap hands them to the remove confirm
      await t.tap(find.text(l10n.groupShotsWaitingFor(1)));
      await _settle(t);
      expect(find.text(l10n.groupShotsWaitingTitle), findsOneWidget);
      expect(find.text(_bo), findsWidgets);
      expect(find.text(l10n.groupShotsNeedsUpdate), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget); // in the members, not here
      await t.tap(find.text(l10n.groupShotsNeedsUpdate));
      await _settle(t);
      expect(find.text(l10n.groupInfoRemove(_bo)), findsOneWidget);
      await t.tap(find.text(l10n.confirmSheetKeep).last);
      await _settle(t);
      // bo updates: on for everyone, and the waiting row is gone
      await _close(t);
      db.caps[_bo] = {kCapGroupShots};
      db.shots['shots_all'] = 1;
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await _settle(t);
      expect(_hint(l10n.groupShotsOnForAll), findsOneWidget);
      expect(find.text(l10n.groupShotsWaitingFor(1)), findsNothing);
      await _close(t);
    });

    testWidgets('someone the admin blocked is named so', (t) async {
      _use(t, _Db(members: const ['me', _anna], blocked: const {_anna}))
        ..adminId = 'me'
        ..shots.addAll(_waiting);
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await _settle(t);
      await t.tap(find.text(l10n.groupShotsWaitingFor(1)));
      await _settle(t);
      expect(find.text(l10n.groupShotsBlockedByYou), findsOneWidget);
      await _close(t);
    });

    for (final (state, hint) in [
      (const <String, Object?>{}, () => l10n.groupShotsOffAdminOnly),
      (_waiting, () => l10n.groupShotsWaitAdminOnly),
      (_forAll, () => l10n.groupShotsOnAdminOnly),
    ]) {
      testWidgets('a member\'s row only reads: ${state.length} set', (t) async {
        final db = _use(t, _theirs(shots: state));
        await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
        await _settle(t);
        expect(_hint(hint()), findsOneWidget);
        expect(_switch(t).onChanged, isNull);
        expect(_switch(t).value, state.isNotEmpty);
        await t.tap(find.text(l10n.chatBlockScreenshots));
        await _settle(t);
        expect(db.queued, isEmpty);
        expect(find.text(l10n.groupShotsWaitingFor(1)), findsNothing);
        await _close(t);
      });
    }

    testWidgets('a room keeps its own row, and an ended group has none', (
      t,
    ) async {
      _use(t, _Db(room: true, members: [_roomPub, _joiner]));
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await _settle(t);
      expect(find.text(l10n.roomShotsAlwaysOn), findsOneWidget);
      expect(find.text(l10n.groupShotsBlocksAll), findsNothing);
      expect(find.text(l10n.groupShotsOffAdminOnly), findsNothing);
      await _close(t);
      _use(t, _mine()..endedBy = 'me');
      appState.groups = [
        GroupPreview(
          groupId: _group,
          name: 'Friends',
          memberCount: 3,
          isAdmin: true,
          createdAt: DateTime(2026),
          endedBy: 'me',
        ),
      ];
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await _settle(t);
      expect(find.text(l10n.chatBlockScreenshots), findsNothing);
      await _close(t);
    });

    testWidgets('the admin leaving says it stays as it is', (t) async {
      _use(t, _mine(shots: _forAll));
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await _settle(t);
      await t.tap(find.text(l10n.groupInfoLeaveGroup2));
      await _settle(t);
      expect(find.text(l10n.groupShotsLeaveStays), findsOneWidget);
      await _close(t);
    });

    testWidgets('adding someone who cannot yet says so, and asks', (t) async {
      final db = _use(t, _Db(members: const ['me', _anna]))
        ..adminId = 'me'
        ..shots.addAll(_forAll);
      db.caps[_anna] = {kCapGroupShots};
      appState.contacts = [_contact(_anna, nick: 'Anna'), _contact(_bo)];
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await _settle(t);
      await t.tap(find.text(l10n.commonAdd));
      await _settle(t);
      expect(find.text(l10n.groupShotsCantYet), findsOneWidget);
      await t.tap(find.text(_bo));
      await t.pump();
      await t.tap(find.text(l10n.groupInfoAdd('1')));
      await _settle(t);
      expect(find.text(l10n.groupShotsAddPauses), findsOneWidget);
      await _close(t);
    });

    for (final (locale, scale) in [
      (const Locale('fa'), 2.0),
      (const Locale('ar'), 2.0),
      (const Locale('de'), 2.0),
    ]) {
      testWidgets('it fits in ${locale.languageCode} at ${scale}x', (t) async {
        _use(t, _mine(shots: _waiting));
        await t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: app(const GroupInfoScreen(groupId: _group), locale: locale),
          ),
        );
        await _settle(t);
        expect(t.takeException(), isNull);
        await t.tap(find.byIcon(Icons.hourglass_empty_rounded));
        await _settle(t);
        expect(t.takeException(), isNull);
        await _close(t);
      });
    }
  });

  group('the group screen', () {
    testWidgets('holds the flag from its first frame, the list knowing it', (
      t,
    ) async {
      final db = _use(t, _theirs(shots: _forAll))..gate = Completer<void>();
      appState.groups = [
        GroupPreview(
          groupId: _group,
          name: 'Friends',
          memberCount: 3,
          isAdmin: false,
          createdAt: DateTime(2026),
          shotsBlocking: true,
          shotsForAll: true,
        ),
      ];
      expect(appState.secureForced, isFalse);
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      expect(appState.secureForced, isTrue);
      db.gate!.complete();
      await _settle(t);
      expect(appState.secureForced, isTrue);
      await _close(t);
      // let go once it leaves
      expect(appState.secureForced, isFalse);
    });

    testWidgets('one that does not block holds nothing', (t) async {
      _use(t, _theirs());
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await _settle(t);
      expect(appState.secureForced, isFalse);
      await _close(t);
    });

    for (final out in [false, true]) {
      testWidgets('the menu keeps ${out ? 'its own' : 'others\''} messages '
          '${out ? 'free' : 'from copy, forward and save'}', (t) async {
        _use(
          t,
          _theirs(
            shots: _waiting,
            rows: [_in(1, out ? 'me' : _anna, 'hello there')],
          ),
        );
        await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
        await _settle(t);
        await t.longPress(find.text('hello there'));
        await t.pump(const Duration(milliseconds: 500));
        final card = find.byKey(const ValueKey('group-menu-actions'));
        Finder inCard(String s) =>
            find.descendant(of: card, matching: find.text(s));
        final kept = !out;
        expect(inCard(l10n.commonCopy), kept ? findsNothing : findsOneWidget);
        expect(
          inCard(l10n.groupChatForward),
          kept ? findsNothing : findsOneWidget,
        );
        expect(inCard(l10n.commonSave), kept ? findsNothing : findsOneWidget);
        expect(
          inCard(l10n.groupShotsMenuNote),
          kept ? findsOneWidget : findsNothing,
        );
        expect(inCard(l10n.roomShotsMenuNote), findsNothing);
        await _close(t);
      });
    }

    testWidgets('the lock by the count, labelled, only once on for '
        'everyone', (t) async {
      final handle = t.ensureSemantics();
      _use(t, _theirs(shots: _waiting));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await _settle(t);
      final lock = find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == l10n.groupShotsBlockedHere,
      );
      expect(lock, findsNothing);
      await _close(t);
      _use(t, _theirs(shots: _forAll));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await _settle(t);
      expect(lock, findsOneWidget);
      await _close(t);
      handle.dispose();
    });

    for (final still in [false, true]) {
      testWidgets(
        'the line where it changed${still ? ', at once with reduced '
                  'motion' : ''}',
        (t) async {
          final now = DateTime.now().millisecondsSinceEpoch;
          _use(
            t,
            _theirs(
              shots: {
                ..._forAll,
                'shots_line': kGroupLineStarted,
                'shots_by': kShotsByThem,
                'shots_when': now - 60000,
              },
              rows: [_in(1, _anna, 'before'), _in(9, _anna, 'after')],
            ),
          );
          await t.pumpWidget(
            app(const GroupChatScreen(groupId: _group), still: still),
          );
          await _settle(t);
          expect(find.text(l10n.groupShotsStarted), findsOneWidget);
          final line = find.byType(ShotsLine);
          expect(line, findsOneWidget);
          // between the two messages
          expect(
            t.getRect(line).top,
            greaterThan(t.getRect(find.text('before')).bottom),
          );
          expect(
            t.getRect(line).bottom,
            lessThan(t.getRect(find.text('after')).top),
          );
          if (still) {
            final o = t.widget<Opacity>(
              find.descendant(of: line, matching: find.byType(Opacity)).first,
            );
            expect(o.opacity, 1);
          }
          await _close(t);
        },
      );
    }

    testWidgets('a screenshot android tells of shows one quiet line here, '
        'and only on the screen in front', (t) async {
      _use(t, _theirs());
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await _settle(t);
      captureWatch.take('rec:0');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.captureRecording), findsNothing);
      captureWatch.take('shot');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.captureShotTaken), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      captureWatch.take('rec:1');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.captureRecording), findsOneWidget);
      await _close(t);
      // the screen gone: nobody hears it
      captureWatch.take('shot');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.captureShotTaken), findsNothing);
    });

    testWidgets('a group that blocks screenshots says nothing of one: its '
        'window gave a black picture', (t) async {
      _use(t, _theirs(shots: _waiting));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await _settle(t);
      expect(appState.windowSecure, isTrue);
      captureWatch.take('shot');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.captureShotTaken), findsNothing);
      await _close(t);
    });

    testWidgets('fits in fa at twice the text', (t) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      _use(
        t,
        _theirs(
          shots: {
            ..._waiting,
            'shots_line': kGroupLineOnWait,
            'shots_by': kShotsByThem,
            'shots_when': now - 60000,
          },
          rows: [_in(1, _anna, 'before'), _in(9, _anna, 'after')],
        ),
      );
      appState.contacts = [_contact(_anna, nick: 'آنا')];
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: app(
            const GroupChatScreen(groupId: _group),
            locale: const Locale('fa'),
          ),
        ),
      );
      await _settle(t);
      expect(t.takeException(), isNull);
      expect(find.byType(ShotsLine), findsOneWidget);
      await _close(t);
    });
  });

  test('the lines say who and what', () {
    expect(
      groupShotsLineText(kGroupLineOnWait, mine: true),
      l10n.groupShotsYouTurnedOnWait,
    );
    expect(
      groupShotsLineText(kGroupLineOnWait, mine: false, name: 'Anna'),
      l10n.groupShotsTheyTurnedOnWait('Anna'),
    );
    expect(
      groupShotsLineText(kGroupLineOn, mine: false, name: 'Anna'),
      l10n.chatShotsTheyTurnedOn('Anna'),
    );
    expect(
      groupShotsLineText(kGroupLineOff, mine: true),
      l10n.chatShotsYouTurnedOff,
    );
    expect(
      groupShotsLineText(kGroupLinePaused, mine: false),
      l10n.groupShotsPaused,
    );
    expect(groupShotsLineText(kGroupLineNone, mine: false), isNull);
    expect(keptOpenLine(KeptIn.group), l10n.groupShotsKeptOpen);
    expect(keptOpenLine(KeptIn.room), l10n.roomShotsKeptOpen);
    expect(keptOpenLine(KeptIn.chat), l10n.chatShotsKeptOpen);
  });
}
