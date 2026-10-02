// SPDX-License-Identifier: GPL-3.0-or-later
// a group opens finished: nothing wrong on screen while it loads, the header
// right from the first frame, faces as everywhere else, timed messages that
// come on when a time is picked, a composer that moves like the 1:1 one and
// a message menu that leaves instead of vanishing. its info page, a contact
// page and the safety number open in their real state, and a member you
// know is one tap away
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show GroupPreview, HaloDb, appState, useDatabasesForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/screens/contact_screen.dart';
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/screens/group_info_screen.dart';
import 'package:kryfo/screens/home_screen.dart' show ContactPreview;
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/empty_chat.dart';
import 'package:kryfo/widgets/halo_switch.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g1';
const _anna = 'thumb-behave-boring';
const _bo = 'river-stone-quiet';

// a phone's database with one group and the people in it. [gate] holds
// every first read of the group until it completes
class _Db implements HaloDb {
  _Db({
    this.rows = const [],
    this.members = const ['me', _anna],
    this.blocked = const {},
  });

  final List<Map<String, Object?>> rows;
  final List<String> members;
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
    return {'group_id': _group, 'name': 'Friends', 'is_admin': 1};
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
  // the list read again once the group is marked read: the one it had
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  @override
  Future<void> markRoomSeen(String groupId) async {}
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
