// SPDX-License-Identifier: GPL-3.0-or-later
// the support inbox as the developer sees it: its pin on home, the inbox
// and its rows, swipes, menus and notification taps
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, session, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/screens/support_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
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
// one of his own contacts
const _c = 'close-old-friend';

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
  @override
  Future<void> setNickname(String haloId, String? name) =>
      _set(haloId, {'nickname': name});

  // an accept that fails, as a full disk would
  var acceptFails = false;
  var acceptTries = 0;
  @override
  Future<void> acceptRequest(String haloId) async {
    acceptTries++;
    if (acceptFails) throw StateError('the disk is full');
    await super.acceptRequest(haloId);
  }
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
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async =>
      _thread(peerId).where((r) => r['direction'] == 'in').length;
  @override
  Future<int> countMessagesTo(String peerId) async =>
      _thread(peerId).where((r) => r['direction'] == 'out').length;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> purgeExpiredBurns({
    Future<Set<String>> Function()? blocked,
  }) async {}
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      _thread(peerId);
  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
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
  @override
  Future<bool> hasViaDev(String haloId) async =>
      _thread(haloId).any((r) => r['via_dev'] == 1);
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
  void nostrSubscribeBg(String peerXPubHex, {bool fresh = false}) =>
      calls.add('listen $peerXPubHex');
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
    testWidgets(
      'his phone: the chats waiting, a pulsing dot, and a tap into the inbox',
      (t) async {
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
      },
    );

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
      // an answered chat there is just a contact
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

    testWidgets('a name he gives shows on its row at once, no open needed', (
      t,
    ) async {
      await _world();
      await devOpen(t, const SupportScreen());
      expect(find.text(_s), findsOneWidget);
      // the contact page's rename, while the inbox is on screen
      await session.setNickname(_s, 'Anna from the forum');
      await appState.refreshContacts();
      await _settle(t);
      expect(find.text('Anna from the forum'), findsOneWidget);
      expect(find.text(_s), findsNothing);
      // the same face, the same place, and the chat it opens
      final row = find
          .ancestor(
            of: find.text('Anna from the forum'),
            matching: find.byType(InkWell),
          )
          .first;
      expect(
        t
            .widget<KryfoAvatar>(
              find.descendant(of: row, matching: find.byType(KryfoAvatar)),
            )
            .seed,
        _s,
      );
      // a name taken off gives the words back
      await session.setNickname(_s, null);
      await appState.refreshContacts();
      await _settle(t);
      expect(find.text(_s), findsOneWidget);
      expect(find.text('Anna from the forum'), findsNothing);
      await session.setNickname(_s, 'Anna');
      await appState.refreshContacts();
      await _settle(t);
      await t.tap(find.text('Anna'));
      await _settle(t);
      expect(find.text('support chat $_s'), findsOneWidget);
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

    testWidgets('reduced motion: no animation', (t) async {
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

    testWidgets('a first reply whose taking-on fails settles as failed, and '
        'nothing escapes', (t) async {
      await _world();
      _db.acceptFails = true;
      await devOpen(t, chat(support: true));
      await t.enterText(find.byType(TextField), 'on it');
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.byIcon(Icons.arrow_upward));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(_db.acceptTries, 1);
      expect(t.takeException(), isNull);
      expect(
        _mem
            .rows('messages')
            .where((r) => r['direction'] == 'out' && r['peer_id'] == _s),
        isEmpty,
      );
      await devClose(t);
    });

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

  group('one person, two ways in', () {
    // C, a contact, wrote once through the developer chat and once not
    Future<void> friend() async {
      await _mem.insert('contacts', {
        'halo_id': _c,
        'onion': '',
        'xpub': 'x-$_c',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
      });
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final (text, via) in const [('from the row', 1), ('just me', 0)]) {
        await _mem.insert('messages', {
          'peer_id': _c,
          'direction': 'in',
          'plaintext': text,
          'sent_at': now,
          'via_dev': via,
        });
      }
      await appState.refreshContacts();
    }

    Widget chat(String id, {bool support = false}) => ChatScreen(
      peerHaloId: id,
      peerOnion: '',
      peerXPub: 'x-$id',
      avatarSeed: id,
      support: support,
    );

    // a page under the chat, so leaving it has somewhere to go
    Future<NavigatorState> host(WidgetTester t, {bool still = false}) async {
      final nav = GlobalKey<NavigatorState>();
      await devOpen(
        t,
        Navigator(
          key: nav,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('under')),
          ),
        ),
        still: still,
      );
      return nav.currentState!;
    }

    Future<void> menu(WidgetTester t) async {
      await t.tap(find.byTooltip(l10n.chatContactOptions));
      await _settle(t);
    }

    Finder bubbleOf(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Bubble',
      ),
    );

    testWidgets('the message that came through the developer chat says so, '
        'the other does not', (t) async {
      await _world();
      await friend();
      await devOpen(t, chat(_c));
      expect(find.text(l10n.supportViaDev), findsOneWidget);
      expect(
        find.descendant(
          of: bubbleOf('from the row'),
          matching: find.text(l10n.supportViaDev),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bubbleOf('just me'),
          matching: find.text(l10n.supportViaDev),
        ),
        findsNothing,
      );
      // amber, never grey
      final tag = t.widget<Text>(find.text(l10n.supportViaDev));
      expect(tag.style?.color, HaloColors.amber);
      await devClose(t);
    });

    testWidgets('the chat menu moves it to the inbox, and it leaves Chats '
        'folding', (t) async {
      await _world();
      await friend();
      expect([for (final c in appState.contacts) c.haloId], [_c]);
      final nav = await host(t);
      final open = nav.push(MaterialPageRoute<void>(builder: (_) => chat(_c)));
      await _settle(t);
      await menu(t);
      await t.tap(find.text(l10n.supportMoveToInbox));
      await _settle(t);
      await open;
      expect(find.text('under'), findsOneWidget);
      expect(find.text(l10n.supportMovedToInbox), findsOneWidget);
      expect(_state(_c), 'open');
      expect(appState.contacts, isEmpty);
      // answered: the inbox shows it there, and counts no one more waiting
      expect(appState.supportWaiting, 1);
      await t.pump(const Duration(seconds: 3));
      await devClose(t);

      // on home the row folds out rather than vanishing
      await _world();
      await friend();
      await devOpen(t, _home());
      expect(find.text(_c), findsOneWidget);
      await appState.moveToInbox(_c);
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(find.text(_c), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(find.text(_c), findsNothing);
      await devClose(t);
    });

    testWidgets('no move for a contact who never came that way, nor on '
        'anyone else\'s phone', (t) async {
      await _world();
      await friend();
      await _mem.update('messages', {'via_dev': 0});
      await devOpen(t, chat(_c));
      await menu(t);
      expect(find.text(l10n.chatArchiveChat), findsOneWidget);
      expect(find.text(l10n.supportMoveToInbox), findsNothing);
      await devClose(t);

      await _world(dev: false);
      await friend();
      await devOpen(t, chat(_c));
      await menu(t);
      expect(find.text(l10n.supportMoveToInbox), findsNothing);
      await devClose(t);
    });

    testWidgets('the inbox moves an answered chat to Chats; a waiting one '
        'has no such row', (t) async {
      await _world();
      await devOpen(t, const SupportScreen());
      await t.longPress(find.text(_s));
      await _settle(t);
      expect(find.text(l10n.supportMoveToChats), findsNothing);
      await t.tapAt(const Offset(10, 10));
      await _settle(t);
      await t.longPress(find.text(_t));
      await _settle(t);
      await t.tap(find.text(l10n.supportMoveToChats));
      await _settle(t);
      expect(find.text(_t), findsNothing);
      expect(_state(_t), 'out');
      expect(find.text(l10n.supportMovedToChats), findsOneWidget);
      expect([for (final c in appState.contacts) c.haloId], [_t]);
      await t.pump(const Duration(seconds: 3));
      await devClose(t);
    });

    Future<Future<bool>> ask(WidgetTester t, String id) async {
      await devOpen(t, const Scaffold(body: Text('under')));
      final going = askMoveIntoChats(t.element(find.text('under')), id);
      // the sheet opens once the inbox has answered
      await t.pump();
      await _settle(t);
      return going;
    }

    testWidgets('added: asked once, and Move puts the chat in Chats', (
      t,
    ) async {
      await _world();
      final going = await ask(t, _t);
      expect(find.text(l10n.supportMoveAsk), findsOneWidget);
      expect(find.text(l10n.supportMoveLine), findsOneWidget);
      expect(find.text(l10n.supportKeepApart), findsOneWidget);
      await t.tap(find.text(l10n.supportMove));
      await _settle(t);
      expect(await going, isTrue);
      expect(_state(_t), 'out');
      expect([for (final c in appState.contacts) c.haloId], [_t]);
      expect(find.text(l10n.supportMovedToChats), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await devClose(t);
    });

    testWidgets('Keep apart, or no answer at all, changes nothing', (t) async {
      await _world();
      var going = await ask(t, _t);
      await t.tap(find.text(l10n.supportKeepApart));
      await _settle(t);
      expect(await going, isFalse);
      expect(_state(_t), 'open');
      expect(appState.contacts, isEmpty);
      await devClose(t);
      // dismissed: keep apart is the default
      going = await ask(t, _t);
      await t.tapAt(const Offset(10, 10));
      await _settle(t);
      expect(await going, isFalse);
      expect(_state(_t), 'open');
      await devClose(t);
    });

    testWidgets('nobody asks about a chat that is not in the inbox, or on '
        'anyone else\'s phone', (t) async {
      await _world();
      var going = await ask(t, 'not-in-inbox');
      expect(find.text(l10n.supportMoveAsk), findsNothing);
      expect(await going, isFalse);
      await devClose(t);
      await _world(dev: false);
      going = await ask(t, _t);
      expect(find.text(l10n.supportMoveAsk), findsNothing);
      expect(await going, isFalse);
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
