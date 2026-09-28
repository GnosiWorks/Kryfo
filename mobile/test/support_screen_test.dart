// SPDX-License-Identifier: GPL-3.0-or-later
// the support inbox as the developer sees it. its pin sits on home on his
// phone alone, counts the chats waiting and breathes while someone waits.
// the inbox lists them waiting, answered and done, the done ones folded;
// a row has the face its three words make, the words left to right, the
// last line, the time and what is unread, and no chip saying how they
// wrote. a swipe puts a chat away or brings it back, the menu blocks or
// deletes it, and the inbox's own menu puts every waiting chat away. with
// nobody yet it says so. a notification's tap opens it or the chat it
// names, never in a decoy. the reset link is off on his phone. less
// movement and right to left are kept
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/screens/support_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/count_badge.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:kryfo/widgets/motion.dart' show BreathDot;
import 'package:kryfo/widgets/stagger_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _s = 'slow-amber-fox';
const _t = 'tall-quiet-pine';
const _r = 'plain-rust-door';

late DevKey _key;

// a phone's database, as the inbox and its actions reach it
class _Db extends DevTestDb {
  _Db(super.mem, [super.container]);

  Future<void> _set(String id, Map<String, Object?> v) =>
      mem.update('contacts', v, where: 'halo_id = ?', whereArgs: [id]);

  @override
  Future<Map<String, Object?>?> getContact(String haloId) async {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == haloId) return r;
    }
    return null;
  }

  @override
  Future<void> declineRequest(String haloId) async {
    await mem.delete('messages', where: 'peer_id = ?', whereArgs: [haloId]);
    await _set(haloId, {'accepted': 0, 'archived': 1, 'unread': 0});
  }

  @override
  Future<void> deleteConversation(String haloId) => declineRequest(haloId);
  @override
  Future<void> setBlocked(String haloId, bool blocked) =>
      _set(haloId, {'blocked': blocked ? 1 : 0});
  @override
  Future<void> dropHeld(String peerId) async {}
  @override
  Future<void> clearUnread(String peerId) => _set(peerId, {'unread': 0});
}

// what a chat's screen reads of its database, kept in maps
class _ChatDb extends _Db {
  _ChatDb(super.mem);

  bool _flag(String id, String col) =>
      mem.rows('contacts').any((r) => r['halo_id'] == id && r[col] == 1);

  List<Map<String, Object?>> _thread(String peer) => [
    for (final r in mem.rows('messages'))
      if (r['peer_id'] == peer && r['group_id'] == null)
        {...r, 'rowid': r['id']},
  ];

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
  Future<int> countMessagesFrom(String peerId) async =>
      _thread(peerId).where((r) => r['direction'] == 'in').length;
  @override
  Future<int> countMessagesTo(String peerId) async =>
      _thread(peerId).where((r) => r['direction'] == 'out').length;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> purgeExpiredBurns() async {}
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      _thread(peerId);
  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int limit = 60,
  }) async => _thread(peerId);
  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => [
    for (final r in _thread(peerId))
      if ((r['id'] as int) > afterRowid) r,
  ];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<bool> messageExists(String msgUid) async =>
      mem.rows('messages').any((r) => r['msg_uid'] == msgUid);
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: true, delivered: false);
}

late MemDb _mem;
late _Db _db;

// his phone, or with [dev] false anyone's: S waits with two unread, T was
// answered, R was put away
Future<void> _world({bool dev = true, bool chats = true}) async {
  _mem = MemDb();
  _db = _ChatDb(_mem);
  await devChatTables(_mem, now: 1);
  if (chats) {
    for (final (id, accepted, state, unread, at) in const [
      (_s, 0, 'open', 2, 300),
      (_t, 1, 'open', 0, 200),
      (_r, 0, 'done', 0, 100),
    ]) {
      await _mem.insert('contacts', {
        'halo_id': id,
        'onion': '',
        'xpub': 'x-$id',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': accepted,
        'unread': unread,
      });
      await _mem.insert('support_chats', {
        'halo_id': id,
        'first_at': at,
        'state': state,
      });
      await _mem.insert('messages', {
        'peer_id': id,
        'direction': 'in',
        'plaintext': 'help from $id',
        'sent_at': DateTime.now().millisecondsSinceEpoch - at * 1000,
      });
    }
    await _mem.insert('messages', {
      'peer_id': _t,
      'direction': 'out',
      'plaintext': 'try the update',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
  appState.myXPub = dev ? _key.xPub : '';
  useDatabasesForTest(_db, Session(_db));
  await appState.refreshContacts();
}

Widget _home() => ListenableBuilder(
  listenable: appState,
  builder: (_, _) => HomeScreen(
    haloId: 'marios-own-words',
    contacts: appState.contacts,
    devRow: appState.devRow,
    pendingCount: appState.pendingCount,
    support: appState.devMode ? appState.supportWaiting : null,
    onAddContact: () {},
    onNewGroup: () {},
    onNewRoom: () {},
    onOpenDev: () {},
    onOpenSettingsDirect: () {},
    onOpenChat: (_) {},
    onOpenGroup: (_) {},
  ),
);

// the pin's title: the nav bar has a tab of the same word
Finder get _pin => find.descendant(
  of: find.byType(SupportPin),
  matching: find.text(l10n.supportTitle),
);

Finder _rowOf(String id) =>
    find.ancestor(of: find.text(id), matching: find.byType(InkWell)).first;

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

String _state(String id) =>
    _mem.rows('support_chats').firstWhere((r) => r['halo_id'] == id)['state']
        as String;

// the engine as a block and an unblock reach it: listening, and no more
class _Engine implements HaloEngine {
  final calls = <String>[];
  @override
  void nostrSubscribeBg(String peerXPubHex) => calls.add('listen $peerXPubHex');
  @override
  void nostrUnsubscribeBg(String peerXPubHex) =>
      calls.add('unlisten $peerXPubHex');
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(_Engine());
    _key = devCard('m1');
    useDevKeysForTest([_key]);
    supportChatPageForTest = (id) =>
        Scaffold(body: Center(child: Text('support chat $id')));
  });

  tearDown(() {
    useDevKeysForTest(null);
    supportChatPageForTest = null;
    appState.myXPub = '';
    setL10nLocale(const Locale('en'));
  });

  group('the pin', () {
    testWidgets('his phone: the chats waiting, a breathing dot, and a tap '
        'into the inbox', (t) async {
      await _world();
      expect(appState.supportWaiting, 1);
      await devOpen(t, _home());
      expect(_pin, findsOneWidget);
      expect(find.text(l10n.supportWaiting(1)), findsOneWidget);
      expect(find.byKey(const ValueKey('support-breath')), findsOneWidget);
      final pin = find.byType(SupportPin);
      expect(
        t
            .widget<CountBadge>(
              find.descendant(of: pin, matching: find.byType(CountBadge)),
            )
            .count,
        1,
      );
      // none of them in the list or the requests
      for (final id in [_s, _t, _r]) {
        expect(find.text(id), findsNothing, reason: id);
      }
      expect(find.text(l10n.homeRequests), findsNothing);
      // and his own row to himself is not there
      expect(find.text(l10n.devRowTitle), findsNothing);
      await t.tap(_pin);
      await _settle(t);
      expect(find.byType(SupportScreen), findsOneWidget);
      await devClose(t);
    });

    testWidgets('nobody waiting: the pin stays, quiet', (t) async {
      await _world();
      await _mem.update(
        'support_chats',
        {'state': 'done'},
        where: 'halo_id = ?',
        whereArgs: [_s],
      );
      await appState.refreshContacts();
      await devOpen(t, _home());
      expect(find.text(l10n.supportWaiting(0)), findsOneWidget);
      expect(find.byType(BreathDot), findsNothing);
      await devClose(t);
    });

    testWidgets('anyone else\'s phone, and his decoy, have none', (t) async {
      await _world(dev: false);
      await devOpen(t, _home());
      expect(find.byType(SupportPin), findsNothing);
      // an answered chat there is simply a contact
      expect(find.text(_t), findsOneWidget);
      await devClose(t);

      await _world();
      final decoy = _Db(MemDb(), HaloContainer.decoy);
      await devChatTables(decoy.mem, now: 1);
      useDatabasesForTest(_db, Session(decoy));
      await appState.refreshContacts();
      expect(appState.devMode, isFalse);
      await devOpen(t, _home());
      expect(find.byType(SupportPin), findsNothing);
      // the decoy keeps its own row to him
      expect(find.text(l10n.devRowTitle), findsOneWidget);
      await devClose(t);
    });
  });

  group('the inbox', () {
    testWidgets('waiting, answered, and done folded away', (t) async {
      await _world();
      await devOpen(t, const SupportScreen());
      for (final w in [
        l10n.supportSectionWaiting,
        l10n.supportSectionAnswered,
        l10n.supportSectionDone,
      ]) {
        expect(find.text(w), findsOneWidget, reason: w);
      }
      double top(Finder f) => t.getTopLeft(f).dy;
      expect(
        top(find.text(_s)),
        lessThan(top(find.text(l10n.supportSectionAnswered))),
      );
      expect(
        top(find.text(_t)),
        lessThan(top(find.text(l10n.supportSectionDone))),
      );
      // done is folded
      expect(find.text(_r), findsNothing);
      await t.tap(find.text(l10n.supportSectionDone));
      await _settle(t);
      expect(find.text(_r), findsOneWidget);
      await t.tap(find.text(l10n.supportSectionDone));
      await _settle(t);
      expect(find.text(_r), findsNothing);
      await devClose(t);
    });

    testWidgets('a row: the face of the words, the words left to right, the '
        'last line, the time, what is unread, and no chip', (t) async {
      await _world();
      await devOpen(t, const SupportScreen());
      final row = _rowOf(_s);
      final face = t.widget<KryfoAvatar>(
        find.descendant(of: row, matching: find.byType(KryfoAvatar)),
      );
      expect(face.seed, _s);
      expect(face.choice, isNull);
      expect(t.widget<Text>(find.text(_s)).textDirection, TextDirection.ltr);
      expect(find.text('help from $_s'), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text(l10n.homeM('5'))),
        findsOneWidget,
      );
      expect(
        t
            .widget<CountBadge>(
              find.descendant(of: row, matching: find.byType(CountBadge)),
            )
            .count,
        2,
      );
      // his own reply reads as his
      expect(find.text(l10n.appYou('try the update')), findsOneWidget);
      // he is not told how anyone wrote
      expect(find.text(l10n.devAnonymous), findsNothing);
      await devClose(t);
    });

    testWidgets('a tap opens the chat', (t) async {
      await _world();
      await devOpen(t, const SupportScreen());
      await t.tap(find.text(_s));
      await _settle(t);
      expect(find.text('support chat $_s'), findsOneWidget);
      await devClose(t);
    });

    testWidgets('a swipe puts a chat away, and brings it back', (t) async {
      await _world();
      await devOpen(t, _home());
      await t.tap(_pin);
      await _settle(t);
      await t.drag(find.text(_s), const Offset(-700, 0));
      await _settle(t);
      expect(_state(_s), 'done');
      expect(appState.supportWaiting, 0);
      expect(find.text(_s), findsNothing);
      expect(find.text(l10n.supportSectionWaiting), findsNothing);
      await t.tap(find.text(l10n.supportSectionDone));
      await _settle(t);
      expect(find.text(_s), findsOneWidget);
      await t.drag(find.text(_s), const Offset(-700, 0));
      await _settle(t);
      expect(_state(_s), 'open');
      expect(appState.supportWaiting, 1);
      expect(find.text(l10n.supportSectionWaiting), findsOneWidget);
      // the pin followed
      Navigator.of(t.element(find.byType(SupportScreen))).pop();
      await _settle(t);
      expect(find.text(l10n.supportWaiting(1)), findsOneWidget);
      await devClose(t);
    });

    testWidgets('the menu: done, block, delete', (t) async {
      await _world();
      await devOpen(t, const SupportScreen());
      await t.longPress(find.text(_s));
      await _settle(t);
      final sheet = find.byType(BottomSheet);
      for (final w in [
        l10n.supportMarkDone,
        l10n.commonBlock,
        l10n.homeDeleteChat,
      ]) {
        expect(
          find.descendant(of: sheet, matching: find.text(w)),
          findsOneWidget,
          reason: w,
        );
      }
      await t.tap(find.text(l10n.homeDeleteChat));
      await _settle(t);
      expect(find.text(l10n.supportDeleteLine), findsOneWidget);
      await t.tap(find.text(l10n.commonDelete).last);
      await _settle(t);
      expect(find.text(_s), findsNothing);
      expect(
        _mem.rows('support_chats').map((r) => r['halo_id']),
        isNot(contains(_s)),
      );
      // blocked: gone from the inbox, still on file
      await t.longPress(find.text(_t));
      await _settle(t);
      await t.tap(find.text(l10n.commonBlock));
      await _settle(t);
      expect(find.text(l10n.requestsBlock(_t)), findsOneWidget);
      await t.tap(find.text(l10n.commonBlock).last);
      await _settle(t);
      expect(find.text(_t), findsNothing);
      expect(
        _mem.rows('contacts').firstWhere((r) => r['halo_id'] == _t)['blocked'],
        1,
      );
      await devClose(t);
    });

    testWidgets('mark all waiting as done', (t) async {
      await _world();
      await devOpen(t, const SupportScreen());
      await t.tap(find.byTooltip(l10n.supportMenu));
      await _settle(t);
      await t.tap(find.text(l10n.supportMarkAllDone));
      await _settle(t);
      expect(_state(_s), 'done');
      expect(_state(_t), 'open');
      expect(find.text(l10n.supportSectionWaiting), findsNothing);
      expect(find.text(l10n.supportWaiting(0)), findsOneWidget);
      // nothing left to put away: the row says why
      await t.tap(find.byTooltip(l10n.supportMenu));
      await _settle(t);
      expect(find.text(l10n.supportWaiting(0)), findsNWidgets(2));
      await devClose(t);
    });

    testWidgets('nobody has written yet', (t) async {
      await _world(chats: false);
      await devOpen(t, const SupportScreen());
      expect(find.text(l10n.supportEmpty), findsOneWidget);
      expect(find.text(l10n.supportEmptyLine), findsOneWidget);
      expect(find.byTooltip(l10n.supportMenu), findsNothing);
      await devClose(t);
    });

    testWidgets('with less movement it is simply there', (t) async {
      await _world();
      await devOpen(t, const SupportScreen(), still: true);
      for (final o in t.widgetList<AnimatedOpacity>(
        find.descendant(
          of: find.byType(StaggerIn),
          matching: find.byType(AnimatedOpacity),
        ),
      )) {
        expect(o.opacity, 1);
      }
      // done opens at once
      await t.tap(find.text(l10n.supportSectionDone));
      await t.pump();
      expect(find.text(_r), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(_r),
          matching: find.byWidgetPredicate(
            (w) => w is Align && (w.heightFactor ?? 1) < 1,
          ),
        ),
        findsNothing,
      );
      await devClose(t);
    });

    testWidgets('right to left: the face at the right, the words still '
        'left to right, nothing overflows', (t) async {
      await _world();
      await devOpen(
        t,
        const SupportScreen(),
        locale: const Locale('ar'),
        size: const Size(1080, 2220),
        ratio: 3,
      );
      final face = find.descendant(
        of: _rowOf(_s),
        matching: find.byType(KryfoAvatar),
      );
      expect(t.getCenter(face).dx, greaterThan(t.getCenter(find.text(_s)).dx));
      expect(t.widget<Text>(find.text(_s)).textDirection, TextDirection.ltr);
      expect(t.takeException(), isNull);
      await devClose(t);
    });
  });

  group('the biggest font on a small phone', () {
    testWidgets('the pin and the inbox keep inside their boxes', (t) async {
      await _world();
      for (final page in [_home(), const SupportScreen()]) {
        await devOpen(
          t,
          page,
          scale: 1.6,
          size: const Size(1080, 2220),
          ratio: 3,
        );
        expect(t.takeException(), isNull);
        await devClose(t);
      }
    });
  });

  group('a support chat', () {
    Widget chat({required bool support}) => ChatScreen(
      peerHaloId: _s,
      peerOnion: '',
      peerXPub: 'x-$_s',
      avatarSeed: _s,
      support: support,
    );

    testWidgets('opens with the composer, never accept and decline', (t) async {
      await _world();
      await devOpen(t, chat(support: true));
      expect(find.text('help from $_s'), findsOneWidget);
      expect(find.text(l10n.chatAccept), findsNothing);
      expect(find.text(l10n.chatDecline), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await devClose(t);
      // the same person as a request asks first
      await devOpen(t, chat(support: false));
      expect(find.text(l10n.chatAccept), findsOneWidget);
      expect(find.text(l10n.chatDecline), findsOneWidget);
      await devClose(t);
    });
  });

  group('a notification\'s tap', () {
    Future<NavigatorState> host(WidgetTester t) async {
      final nav = GlobalKey<NavigatorState>();
      await devOpen(
        t,
        Navigator(
          key: nav,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('home')),
          ),
        ),
      );
      return nav.currentState!;
    }

    testWidgets('opens the inbox, or the chat it names', (t) async {
      await _world();
      final nav = await host(t);
      final going = openSupportTap(nav, '');
      await _settle(t);
      expect(find.byType(SupportScreen), findsOneWidget);
      nav.pop();
      await _settle(t);
      await going;
      final chat = openSupportTap(nav, _s);
      await _settle(t);
      expect(find.text('support chat $_s'), findsOneWidget);
      nav.pop();
      await _settle(t);
      await chat;
      // a chat that is no support chat is not opened as one
      await openSupportTap(nav, 'some-other-one');
      await _settle(t);
      expect(find.text('home'), findsOneWidget);
      await devClose(t);
    });

    testWidgets('does nothing in a decoy', (t) async {
      await _world();
      useDatabasesForTest(_db, Session(_Db(MemDb(), HaloContainer.decoy)));
      final nav = await host(t);
      await openSupportTap(nav, '');
      await openSupportTap(nav, _s);
      await _settle(t);
      expect(find.byType(SupportScreen), findsNothing);
      expect(find.text('support chat $_s'), findsNothing);
      await devClose(t);
    });
  });

  group('the reset link', () {
    Future<Finder> reset(WidgetTester t) async {
      await devOpen(t, const SettingsScreen());
      final row = find.text(l10n.settingsResetMyInviteLink);
      await t.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(t.element(row), alignment: 0.5);
      await t.pump(const Duration(milliseconds: 500));
      return row;
    }

    testWidgets('is off on his phone, and says why', (t) async {
      await _world();
      final row = await reset(t);
      expect(find.text(l10n.supportResetPinned), findsOneWidget);
      expect(find.text(l10n.settingsOldLinksAndCodes), findsNothing);
      await t.tap(row);
      await _settle(t);
      expect(find.text(l10n.settingsResetInviteLink), findsNothing);
      await devClose(t);
    });

    testWidgets('asks as ever on anyone else\'s', (t) async {
      await _world(dev: false);
      final row = await reset(t);
      expect(find.text(l10n.supportResetPinned), findsNothing);
      expect(find.text(l10n.settingsOldLinksAndCodes), findsOneWidget);
      await t.tap(row);
      await _settle(t);
      expect(find.text(l10n.settingsResetInviteLink), findsOneWidget);
      await t.tapAt(const Offset(10, 10));
      await _settle(t);
      await devClose(t);
    });
  });
}
