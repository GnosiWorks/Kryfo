// SPDX-License-Identifier: GPL-3.0-or-later
// a group opens finished: nothing wrong on screen while it loads, the header
// right from the first frame, faces as everywhere else, timed messages that
// come on when a time is picked, a composer that moves like the 1:1 one and
// a message menu that leaves instead of vanishing. its info page, a contact
// page and the safety number open in their real state, and a member you
// know is one tap away
import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        GroupPreview,
        HaloDb,
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/rooms.dart' show kRoomJoinWait;
import 'package:kryfo/screens/contact_screen.dart';
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/screens/group_info_screen.dart';
import 'package:kryfo/screens/home_screen.dart' show ContactPreview;
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/screens/search_screen.dart';
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/empty_chat.dart';
import 'package:kryfo/widgets/halo_switch.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:kryfo/widgets/media_bubbles.dart' show HoldToTalkMic;
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:kryfo/widgets/room_countdown.dart';
import 'package:kryfo/widgets/voice_parts.dart' show VoiceRecordBar;
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

  @override
  HaloContainer get container => HaloContainer.everyday;

  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async {
    await _wait();
    return {
      'group_id': _group,
      'name': 'Friends',
      'is_admin': joiningAt == null ? 1 : 0,
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
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async {
    await _wait();
    return members;
  }

  @override
  Future<Set<String>> blockedIds() async => blocked;
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int limit = 60,
  }) async => [...rows];
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

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// a knock again listens to the room's creator first, then knocks. the
// relays answer [answer]
class _RoomEngine implements HaloEngine {
  String answer = 'ok';
  final knocked = <String>[];
  @override
  void roomSubscribeBg(String priv, String peerPub) {}
  @override
  String myEdPubkey() => '';
  @override
  String myXPubkey() => '';
  @override
  Future<String> roomSendFirstContact(
    String priv,
    String peerPub,
    String fcPk,
    String msg,
  ) async {
    knocked.add(msg);
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Map<String, Object?> _in(int rowid, String from, String text) => {
  'rowid': rowid,
  'id': rowid,
  'peer_id': from,
  'group_id': _group,
  'direction': 'in',
  'plaintext': text,
  'msg_uid': 'uid-$rowid',
  'sent': 1,
  'sent_at': DateTime.now()
      .subtract(Duration(minutes: 10 - rowid))
      .millisecondsSinceEpoch,
};

ContactPreview _contact(
  String id, {
  String? nick,
  int? face,
  bool blocked = false,
}) => ContactPreview(
  haloId: id,
  nickname: nick,
  avatarSeed: id,
  avatar: face,
  blocked: blocked,
);

_Db _use(WidgetTester t, _Db db) {
  phone(t);
  useDatabasesForTest(db, Session(db));
  appState.sendModeForTest = 'private';
  appState.setRouteOKForTest(true);
  appState.setTorStatusForTest(TorStatus.reachable);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  return db;
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

// the size the timed messages line has right now, 0 when it is not there
double _stripFactor(WidgetTester t) {
  final text = find.byKey(const ValueKey('ghost-strip'));
  if (text.evaluate().isEmpty) return 0;
  final size = find.ancestor(of: text, matching: find.byType(SizeTransition));
  return t.widget<SizeTransition>(size.first).sizeFactor.value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.groups = [];
    appState.contacts = [];
    // the menus close with the lock: it is down here
    lockState.openForTest();
  });

  tearDown(() {
    appState.groups = [];
    appState.contacts = [];
    appState.setTorStatusForTest(TorStatus.off);
  });

  // first in the file: the recorder's lock is shared, and a screen closed
  // without letting it go holds it for every test after
  group('the group mic with nobody to hear it', () {
    late Directory tmp;
    // what the recorder was asked, and the file it wrote
    late List<String> asked;
    String? recording;

    void mock(String channel, Future<Object?> Function(MethodCall)? h) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(channel), h);

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('group_alone_mic');
      asked = [];
      recording = null;
      mock('plugins.flutter.io/path_provider', (_) async => tmp.path);
      mock('com.llfbandit.record/messages', (c) async {
        asked.add(c.method);
        switch (c.method) {
          case 'create':
            final id = (c.arguments as Map)['recorderId'];
            mock('com.llfbandit.record/events/$id', (_) async => null);
          case 'hasPermission':
            return true;
          case 'start':
            recording = (c.arguments as Map)['path'] as String;
            File(recording!).writeAsBytesSync(List.filled(64, 1));
          case 'stop':
            return recording;
        }
        return null;
      });
    });

    tearDown(() {
      mock('plugins.flutter.io/path_provider', null);
      mock('com.llfbandit.record/messages', null);
      tmp.deleteSync(recursive: true);
    });

    // real file work runs outside the test's clock
    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 20; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    Future<TestGesture> hold(WidgetTester t) async {
      final g = await t.startGesture(t.getCenter(find.byType(HoldToTalkMic)));
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await t.pump();
      return g;
    }

    testWidgets('in a room nobody joined, it never opens', (t) async {
      _use(t, _Db(room: true, members: [_roomPub]));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      final g = await hold(t);
      await settle(t);
      expect(find.text(l10n.groupChatNobodyToReadIt), findsWidgets);
      expect(asked, isNot(contains('start')));
      expect(find.byType(VoiceRecordBar), findsNothing);
      await g.up();
      await settle(t);
      expect(recording, isNull);
      await t.pump(const Duration(seconds: 4));
      await _close(t);
      // the recorder lets go of the plugin's one lock before the next test
      await settle(t);
    });

    testWidgets('the last one gone while it records: the voice is '
        'shredded, not left behind', (t) async {
      final db = _use(t, _Db(room: true, members: [_roomPub, _joiner]));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      // a recorder an earlier screen left is let go first
      await settle(t);
      final g = await hold(t);
      await settle(t);
      expect(find.byType(VoiceRecordBar), findsOneWidget);
      expect(File(recording!).existsSync(), isTrue);

      // the joiner leaves before the finger comes up
      db.members = [_roomPub];
      appState.chatChanged('group:$_group');
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.groupChatNobodyHereYet), findsOneWidget);
      await g.up();
      await settle(t);
      expect(find.text(l10n.groupChatNobodyToReadIt), findsWidgets);
      expect(File(recording!).existsSync(), isFalse);
      expect(find.byType(EmptyChat), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      await _close(t);
      // the recorder lets go of the plugin's one lock before the next test
      await settle(t);
    });
  });

  group('group chat', () {
    testWidgets('no empty state while it loads; an empty group gets one', (
      t,
    ) async {
      final db = _use(t, _Db())..gate = Completer<void>();
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(EmptyChat), findsNothing);
      expect(find.text(l10n.groupChatGroupCreatedSayHi), findsNothing);
      expect(find.text(l10n.groupChatNoMessagesYet), findsNothing);

      db.gate!.complete();
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      expect(find.byType(EmptyChat), findsOneWidget);
      expect(find.text(l10n.groupChatGroupCreatedSayHi), findsOneWidget);
      expect(find.text(l10n.groupChatEveryoneHereReads), findsOneWidget);
      await _close(t);
    });

    testWidgets('a room nobody joined says so, and holds what is typed', (
      t,
    ) async {
      final db = _use(t, _Db(room: true, members: [_roomPub]));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.groupChatNobodyHereYet), findsOneWidget);
      expect(find.text(l10n.groupChatShareTheRoomLink), findsOneWidget);
      expect(find.text(l10n.groupChatEveryoneHereReads), findsNothing);
      expect(find.text(l10n.chatSayHi), findsNothing);

      // nothing is sent, no bubble turns failed, the words stay put
      await t.enterText(find.byType(TextField), 'plan for tonight');
      await t.pump();
      await t.pump(const Duration(milliseconds: 250));
      await t.tap(find.bySemanticsLabel(l10n.commonSend));
      await t.pump();
      expect(find.text(l10n.groupChatNobodyToReadIt), findsOneWidget);
      expect(find.byType(EmptyChat), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'plan for tonight',
      );
      await t.pump(const Duration(seconds: 4));

      // someone joins: the room reads as one with people in it
      db.members = [_roomPub, _joiner];
      appState.chatChanged('group:$_group');
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.chatSayHi), findsOneWidget);
      expect(find.text(l10n.groupChatEveryoneHereReads), findsOneWidget);
      expect(find.text(l10n.groupChatNobodyHereYet), findsNothing);
      await t.enterText(find.byType(TextField), '');
      await _close(t);
    });

    testWidgets('a group everyone else left is not called new', (t) async {
      final was = appState.myId;
      appState.myId = 'me';
      addTearDown(() => appState.myId = was);
      _use(t, _Db(members: ['me']));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.groupChatNoMessagesYet), findsOneWidget);
      expect(find.text(l10n.groupChatNobodyToReadIt), findsOneWidget);
      expect(find.text(l10n.groupChatGroupCreatedSayHi), findsNothing);
      expect(find.text(l10n.groupChatEveryoneHereReads), findsNothing);
      await _close(t);
    });

    testWidgets('the header is the chat list\'s from the first frame', (
      t,
    ) async {
      final db = _use(t, _Db())..gate = Completer<void>();
      appState.groups = [
        GroupPreview(
          groupId: _group,
          name: 'Hiking crew',
          memberCount: 4,
          isAdmin: false,
          createdAt: DateTime(2026),
        ),
      ];
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump();
      expect(find.text('Hiking crew'), findsOneWidget);
      expect(find.text('H'), findsOneWidget);
      expect(find.text(l10n.groupChatMembers(4)), findsOneWidget);
      expect(find.text('·'), findsNothing);
      db.gate!.complete();
      await _close(t);
    });

    testWidgets('a member shows the face they picked', (t) async {
      _use(t, _Db(rows: [_in(1, _anna, 'hello')]));
      appState.contacts = [_contact(_anna, nick: 'Anna', face: 7)];
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      final faces = t
          .widgetList<KryfoAvatar>(find.byType(KryfoAvatar))
          .where((a) => a.seed == _anna);
      expect(faces, isNotEmpty);
      expect(faces.every((a) => a.choice == 7), isTrue);
      await _close(t);
    });

    testWidgets('a long name and a big font stay on the sender line', (
      t,
    ) async {
      _use(t, _Db(rows: [_in(1, _anna, 'hello')]));
      appState.contacts = [
        _contact(_anna, nick: 'Anna Maria Magdalena of the long valley road'),
      ];
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: app(const GroupChatScreen(groupId: _group)),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      await _close(t);
    });

    testWidgets('picking a burn time turns timed messages on', (t) async {
      _use(t, _Db());
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(_stripFactor(t), 0);

      await t.longPress(find.bySemanticsLabel(l10n.groupChatTimedMessages));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.groupChat5Minutes));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(_stripFactor(t), 1);
      await _close(t);
    });

    testWidgets('the timed line grows in, at once with less movement', (
      t,
    ) async {
      _use(t, _Db());
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.bySemanticsLabel(l10n.groupChatTimedMessages));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final f = _stripFactor(t);
      expect(f, greaterThan(0));
      expect(f, lessThan(1));
      await _close(t);

      // the flame was left on: start again from off
      FlutterSecureStorage.setMockInitialValues({});
      _use(t, _Db());
      await t.pumpWidget(
        app(const GroupChatScreen(groupId: _group), still: true),
      );
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.bySemanticsLabel(l10n.groupChatTimedMessages));
      await t.pump();
      await t.pump(const Duration(milliseconds: 20));
      expect(_stripFactor(t), 1);
      await _close(t);
    });

    testWidgets('mic and send pop, and simply swap with less movement', (
      t,
    ) async {
      double sendScale() {
        final send = find.bySemanticsLabel(l10n.commonSend);
        final s = find.ancestor(
          of: send,
          matching: find.byType(ScaleTransition),
        );
        return t.widget<ScaleTransition>(s.first).scale.value;
      }

      _use(t, _Db());
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      await t.enterText(find.byType(TextField), 'hi');
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(sendScale(), lessThan(1));
      await t.pump(const Duration(milliseconds: 300));
      expect(sendScale(), 1);
      await _close(t);

      _use(t, _Db());
      await t.pumpWidget(
        app(const GroupChatScreen(groupId: _group), still: true),
      );
      await t.pump(const Duration(seconds: 1));
      // the first half left a draft behind
      await t.enterText(find.byType(TextField), '');
      await t.pump(const Duration(seconds: 1));
      await t.enterText(find.byType(TextField), 'hi');
      await t.pump();
      await t.pump(const Duration(milliseconds: 20));
      expect(sendScale(), 1);
      await _close(t);
    });

    testWidgets('the menu: reactions above, actions under, and it leaves', (
      t,
    ) async {
      _use(t, _Db(rows: [_in(1, _anna, 'hello there')]));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      final bubble = t.getRect(find.text('hello there'));
      await t.longPress(find.text('hello there'));
      await t.pump(const Duration(milliseconds: 500));
      final bar = find.byKey(const ValueKey('group-menu-reactions'));
      final card = find.byKey(const ValueKey('group-menu-actions'));
      expect(t.getRect(bar).bottom, lessThanOrEqualTo(bubble.top));
      expect(t.getRect(card).top, greaterThanOrEqualTo(bubble.bottom));

      // a tap outside: it fades away, then it is gone
      await t.tapAt(const Offset(300, 650));
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      expect(bar, findsOneWidget);
      await t.pump(const Duration(milliseconds: 200));
      expect(bar, findsNothing);
      await _close(t);
    });

    testWidgets('a long message keeps its menu on the screen', (t) async {
      // tall with room only above it, taller than the screen, and scrolled
      // so its top is gone
      for (final (words, lift) in [(120, 0.0), (400, 0.0), (400, 300.0)]) {
        final long = List.filled(words, 'word').join(' ');
        _use(t, _Db(rows: [_in(1, _anna, long)]));
        await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
        await t.pump(const Duration(seconds: 1));
        final screen =
            Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
        if (lift > 0) {
          await t.drag(find.text(long), Offset(0, -lift));
          await t.pump(const Duration(seconds: 1));
        }
        final seen = t.getRect(find.text(long)).intersect(screen);
        await t.longPressAt(seen.center);
        await t.pump(const Duration(milliseconds: 500));
        final card = t.getRect(
          find.byKey(const ValueKey('group-menu-actions')),
        );
        final bar = t.getRect(
          find.byKey(const ValueKey('group-menu-reactions')),
        );
        expect(card.top, greaterThanOrEqualTo(0));
        expect(card.bottom, lessThanOrEqualTo(screen.bottom));
        expect(bar.top, greaterThanOrEqualTo(0));
        expect(bar.bottom, lessThanOrEqualTo(card.top));
        await _close(t);
      }
    });

    testWidgets('no menu once the lock is up as the keyboard goes', (t) async {
      _use(t, _Db(rows: [_in(1, _anna, 'hello there')]));
      lockState.openForTest(enabled: true);
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.byType(TextField));
      t.view.viewInsets = const FakeViewPadding(bottom: 600);
      addTearDown(t.view.resetViewInsets);
      await t.pump();
      await t.longPress(find.text('hello there'));
      // the keyboard is on its way down when the lock goes up
      lockState.lock();
      final buzzed = <Object?>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') buzzed.add(call);
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      t.view.resetViewInsets();
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(
          find.byKey(const ValueKey('group-menu-reactions')),
          findsNothing,
        );
      }
      expect(buzzed, isEmpty, reason: 'the menu never started');
      lockState.openForTest();
      await _close(t);
    });

    testWidgets('with less movement the menu goes at once', (t) async {
      _use(t, _Db(rows: [_in(1, _anna, 'hello there')]));
      await t.pumpWidget(
        app(const GroupChatScreen(groupId: _group), still: true),
      );
      await t.pump(const Duration(seconds: 1));
      await t.longPress(find.text('hello there'));
      await t.pump(const Duration(milliseconds: 500));
      final bar = find.byKey(const ValueKey('group-menu-reactions'));
      expect(bar, findsOneWidget);
      await t.tapAt(const Offset(300, 650));
      await t.pump();
      expect(bar, findsNothing);
      await _close(t);
    });
  });

  group('a room not let in yet', () {
    // a room joined [ago] back, as the chat list has it
    _Db joined(WidgetTester t, Duration ago) {
      final at = DateTime.now().subtract(ago).millisecondsSinceEpoch;
      final db = _use(t, _Db(room: true, members: [_roomPub, _joiner]))
        ..joiningAt = at;
      appState.groups = [
        GroupPreview(
          groupId: _group,
          name: 'Friends',
          memberCount: 2,
          isAdmin: false,
          createdAt: DateTime(2026),
          expiresAt: DateTime.now()
              .add(const Duration(hours: 24))
              .millisecondsSinceEpoch,
          joiningAt: at,
        ),
      ];
      return db;
    }

    // how far the composer has grown in, 1 when it is all there
    double composer(WidgetTester t) => t
        .widget<SizeTransition>(
          find
              .ancestor(
                of: find.byType(TextField),
                matching: find.byType(SizeTransition),
              )
              .first,
        )
        .sizeFactor
        .value;

    testWidgets('it waits: no composer, no count, nothing to send', (t) async {
      joined(t, Duration.zero);
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump();
      // from the first frame, as the chat list knew it
      expect(find.text(l10n.roomJoinWaitingToJoin), findsOneWidget);
      expect(find.byType(RoomCountdown), findsNothing);
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.roomJoinWaitingFor('Friends')), findsOneWidget);
      expect(find.text(l10n.roomJoinWaitingLine), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.bySemanticsLabel(l10n.commonSend), findsNothing);
      expect(find.byType(HoldToTalkMic), findsNothing);
      expect(find.byType(RoomCountdown), findsNothing);
      expect(find.text(l10n.chatSayHi), findsNothing);
      // and no info page with a member list nobody has confirmed
      await t.tap(find.text('Friends'));
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(GroupInfoScreen), findsNothing);
      await _close(t);
    });

    testWidgets('the wait runs out: not answering, try again or leave', (
      t,
    ) async {
      // a breath before the end of the wait
      joined(t, kRoomJoinWait - const Duration(milliseconds: 300));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n.roomJoinWaitingFor('Friends')), findsOneWidget);
      expect(find.text(l10n.roomJoinNoAnswer), findsNothing);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.roomJoinNoAnswer), findsOneWidget);
      expect(find.text(l10n.roomJoinMayHaveEnded), findsOneWidget);
      expect(find.text(l10n.commonTryAgain), findsOneWidget);
      expect(find.text(l10n.groupInfoLeave), findsOneWidget);
      expect(find.text(l10n.roomJoinNotAnswering), findsOneWidget);
      expect(find.text(l10n.roomJoinWaitingFor('Friends')), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await _close(t);
    });

    testWidgets('try again turns it back to waiting at once', (t) async {
      final engine = _RoomEngine();
      useEngineForTest(engine);
      final db = joined(t, const Duration(minutes: 5));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.roomJoinNoAnswer), findsOneWidget);
      final before = DateTime.now().millisecondsSinceEpoch;
      await t.tap(find.text(l10n.commonTryAgain));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.roomJoinWaitingFor('Friends')), findsOneWidget);
      expect(find.text(l10n.roomJoinNoAnswer), findsNothing);
      expect(db.knocks, hasLength(1));
      expect(db.knocks.single!, greaterThanOrEqualTo(before));
      expect(engine.knocked, hasLength(1));
      expect(find.byType(TextField), findsNothing);
      await _close(t);
    });

    testWidgets('a knock that does not go: not answering again at once', (
      t,
    ) async {
      final engine = _RoomEngine()..answer = 'error: no relay';
      useEngineForTest(engine);
      final db = joined(t, const Duration(minutes: 5));
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.commonTryAgain));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(engine.knocked, hasLength(1));
      expect(find.text(l10n.roomJoinNoAnswer), findsOneWidget);
      expect(find.text(l10n.commonTryAgain), findsOneWidget);
      expect(find.text(l10n.roomJoinWaitingFor('Friends')), findsNothing);
      expect(db.joiningAt, lessThan(db.knocks.single! - 1));
      await _close(t);
    });

    testWidgets('try again with the room shut under it is let go', (t) async {
      useEngineForTest(_RoomEngine());
      final db = joined(t, const Duration(minutes: 5))..shut = true;
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.commonTryAgain));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(db.knocks, isEmpty);
      await _close(t);
    });

    testWidgets('search names it as waiting, not by a member count', (t) async {
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.textInput, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.textInput, null),
      );
      Future<void> look() async {
        await t.pumpWidget(app(const SearchScreen()));
        await t.pump(const Duration(seconds: 1));
        await t.enterText(find.byType(TextField), 'frie');
        await t.pump(const Duration(milliseconds: 200));
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text(l10n.homeMembers(2)), findsNothing);
      }

      joined(t, Duration.zero);
      await look();
      expect(find.text(l10n.roomJoinWaitingToJoin), findsOneWidget);
      await _close(t);

      joined(t, const Duration(minutes: 5));
      await look();
      expect(find.text(l10n.roomJoinNotAnswering), findsOneWidget);
      await _close(t);
    });

    testWidgets('let in: the room comes alive in place, the composer grows '
        'in', (t) async {
      final db = joined(t, Duration.zero);
      await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(TextField), findsNothing);
      db.joiningAt = null;
      appState.chatChanged('group:$_group');
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      final mid = composer(t);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await t.pump(const Duration(seconds: 1));
      expect(composer(t), 1);
      expect(find.text(l10n.chatSayHi), findsOneWidget);
      expect(find.text(l10n.roomJoinWaitingFor('Friends')), findsNothing);
      expect(find.byType(RoomCountdown), findsOneWidget);
      await _close(t);

      // with less movement it is simply there
      final db2 = joined(t, Duration.zero);
      await t.pumpWidget(
        app(const GroupChatScreen(groupId: _group), still: true),
      );
      await t.pump(const Duration(seconds: 1));
      db2.joiningAt = null;
      appState.chatChanged('group:$_group');
      await t.pump();
      await t.pump(const Duration(milliseconds: 20));
      expect(composer(t), 1);
      await _close(t);
    });
  });

  group('group info', () {
    testWidgets('draws at once with the tile, and no spinner', (t) async {
      final db = _use(t, _Db())..gate = Completer<void>();
      appState.groups = [
        GroupPreview(
          groupId: _group,
          name: 'Hiking crew',
          memberCount: 4,
          isAdmin: true,
          createdAt: DateTime(2026),
        ),
      ];
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is Hero && w.tag == 'group-$_group'),
        findsOneWidget,
      );
      expect(find.text('Hiking crew'), findsOneWidget);
      expect(find.text(l10n.groupInfo1Member(4)), findsOneWidget);
      db.gate!.complete();
      await _close(t);
    });

    testWidgets('shared media is counted on the page, as on a contact\'s', (
      t,
    ) async {
      _use(
        t,
        _Db(
          rows: [
            {..._in(1, _anna, ''), 'media_path': '/nowhere/a.jpg'},
            _in(2, _anna, 'words'),
          ],
        ),
      );
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.contactSharedMedia('1')), findsOneWidget);
      expect(find.text(l10n.contactNothingSharedYet), findsNothing);
      await _close(t);
    });

    testWidgets('the members come in while the history is still read', (
      t,
    ) async {
      final db = _use(t, _Db())..history = Completer<void>();
      appState.contacts = [_contact(_anna, nick: 'Anna')];
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Anna'), findsOneWidget);
      db.history!.complete();
      await _close(t);
    });

    // it shows in the thread alone, where reading it starts its clock
    testWidgets('a timed photo nobody has read stays out of the shared '
        'media', (t) async {
      final soon = DateTime.now().millisecondsSinceEpoch + 60000;
      _use(
        t,
        _Db(
          rows: [
            {..._in(1, _anna, ''), 'media_path': '/nowhere/a.jpg'},
            {
              ..._in(2, _anna, ''),
              'media_path': '/nowhere/b.jpg',
              'burn_secs': 30,
            },
            {
              ..._in(3, _anna, ''),
              'media_path': '/nowhere/c.jpg',
              'burn_secs': 30,
              'burn_at': soon,
            },
          ],
        ),
      );
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.contactSharedMedia('2')), findsOneWidget);
      await _close(t);
    });

    testWidgets('a blocked member\'s photos stay out of sight', (t) async {
      _use(
        t,
        _Db(
          members: const ['me', _anna, _bo],
          blocked: const {_bo},
          rows: [
            {..._in(1, _anna, ''), 'media_path': '/nowhere/a.jpg'},
            {..._in(2, _bo, ''), 'media_path': '/nowhere/b.jpg'},
            {..._in(3, _bo, ''), 'media_path': '/nowhere/c.jpg'},
          ],
        ),
      );
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.contactSharedMedia('1')), findsOneWidget);
      await _close(t);
    });

    testWidgets('add waits for the members, so no one is offered twice', (
      t,
    ) async {
      final db = _use(t, _Db())..gate = Completer<void>();
      appState.groups = [
        GroupPreview(
          groupId: _group,
          name: 'Friends',
          memberCount: 2,
          isAdmin: true,
          createdAt: DateTime(2026),
        ),
      ];
      appState.contacts = [_contact(_anna, nick: 'Anna')];
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await t.pump();
      final add = find.text(l10n.commonAdd);
      await t.scrollUntilVisible(
        add,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(add);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Anna'), findsNothing);
      db.gate!.complete();
      await _close(t);
    });

    testWidgets('a member you know: your name for them, and a tap opens them', (
      t,
    ) async {
      _use(t, _Db());
      appState.contacts = [_contact(_anna, nick: 'Anna', face: 3)];
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text(_anna), findsOneWidget);
      await t.ensureVisible(find.text('Anna'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Anna'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(ContactScreen), findsOneWidget);
      await _close(t);
    });

    testWidgets('adding: names, no one blocked, and the count on the button', (
      t,
    ) async {
      _use(t, _Db(members: const ['me']));
      appState.contacts = [
        _contact(_anna, nick: 'Anna'),
        _contact(_bo, blocked: true),
      ];
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _group)));
      await t.pump(const Duration(seconds: 1));
      final add = find.text(l10n.commonAdd);
      await t.scrollUntilVisible(
        add,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(add);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text(_bo), findsNothing);
      await t.tap(find.text('Anna'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel(l10n.groupInfoAdd('1')), findsOneWidget);
      await _close(t);
    });
  });

  group('contact page', () {
    testWidgets('opens with the name you gave them, nothing wrong meanwhile', (
      t,
    ) async {
      final db = _use(t, _Db())..gate = Completer<void>();
      appState.contacts = [_contact(_anna, nick: 'Anna')];
      await t.pumpWidget(
        app(
          const ContactScreen(haloId: _anna, avatarSeed: _anna, peerXPub: ''),
        ),
      );
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Anna'), findsWidgets);
      expect(find.text(l10n.contactNothingSharedYet), findsNothing);
      db.gate!.complete();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.contactNothingSharedYet), findsOneWidget);
      await _close(t);
    });

    testWidgets('mute is a switch that moves on the tap', (t) async {
      final db = _use(t, _Db())..muting = Completer<void>();
      appState.contacts = [_contact(_anna, nick: 'Anna')];
      await t.pumpWidget(
        app(
          const ContactScreen(haloId: _anna, avatarSeed: _anna, peerXPub: ''),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      final row = find.text(l10n.contactMute);
      await t.ensureVisible(row);
      await t.pump(const Duration(milliseconds: 300));
      HaloSwitch muteSwitch() => t.widget<HaloSwitch>(
        find.descendant(
          of: find.ancestor(of: row, matching: find.byType(InkWell)).first,
          matching: find.byType(HaloSwitch),
        ),
      );
      expect(muteSwitch().value, isFalse);
      await t.tap(row);
      await t.pump();
      // the write has not landed yet
      expect(muteSwitch().value, isTrue);
      db.muting = null;
      await _close(t);
    });
  });

  testWidgets('the safety number opens in the state the contact page knew', (
    t,
  ) async {
    final db = _use(t, _Db())..verified = Completer<bool>();
    await t.pumpWidget(
      app(
        KeyVerificationScreen(
          peerHaloId: _anna,
          peerName: 'Anna',
          myXpub: 'ab' * 32,
          peerXpub: 'cd' * 32,
          initialVerified: true,
        ),
      ),
    );
    await t.pump();
    expect(find.text(l10n.keyVerificationVerified), findsOneWidget);
    db.verified!.complete(true);
    await _close(t);
  });
}
