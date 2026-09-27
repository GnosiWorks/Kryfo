// SPDX-License-Identifier: GPL-3.0-or-later
// the developer chat as people see it. its row sits at the very top on a
// fresh install, after an update and in a decoy, with no count while
// nothing has arrived, and it is never offered to the hidden chats. mute,
// archive and unpin work from the row; a delete is for good, and only
// Write to Marios brings a fresh chat back. the sheet says who he is and
// prints his key left to right. search finds him by his name, and his
// chat's messages once there are some; a forward reaches the chat once it
// has started. with no pinned key, and on his own phone, none of it shows.
// less movement and right to left are kept
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart' show LockGuard;
import 'package:kryfo/main.dart' show appState;
import 'package:kryfo/screens/archived_screen.dart';
import 'package:kryfo/screens/dev_about_sheet.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/screens/pin_flow_screen.dart' show PinsHost;
import 'package:kryfo/screens/search_screen.dart';
import 'package:kryfo/screens/seen_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/widgets/count_badge.dart';
import 'package:kryfo/widgets/dev_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';

late DevKey _key;
var _groups = <GroupSummary>[];

Finder get _devTitle => find.text(l10n.devRowTitle);

// the list's own heading, not the tab of the same name
Finder get _chatsHead => find.descendant(
  of: find.byType(ListView),
  matching: find.text(l10n.searchChats),
);

double _top(WidgetTester t, Finder f) => t.getTopLeft(f).dy;

Future<void> _longPress(WidgetTester t, Finder f) async {
  await t.longPress(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _tapIn(WidgetTester t, String label) async {
  await t.tap(find.text(label).last);
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
    _key = devCard('m1');
    useDevKeysForTest([_key]);
    _groups = [];
    devChatPageForTest = (id, text) =>
        Scaffold(body: Center(child: Text('the chat $id ${text ?? ''}')));
  });

  tearDown(() {
    useDevKeysForTest(null);
    devChatPageForTest = null;
    appState.myXPub = '';
    setL10nLocale(const Locale('en'));
  });

  group('the row', () {
    testWidgets('a fresh install: on top of the page that asks to add '
        'someone, the welcome, no time and no count', (t) async {
      await devWorld();
      await devOpen(t, devHome(groups: _groups));
      expect(_devTitle, findsOneWidget);
      expect(find.text(l10n.devWelcome), findsOneWidget);
      expect(find.text(l10n.homeNoKryfosYet), findsOneWidget);
      expect(
        _top(t, _devTitle),
        lessThan(_top(t, find.text(l10n.homeNoKryfosYet))),
      );
      // nothing arrived: no "1", no amber, no time
      final row = find.ancestor(of: _devTitle, matching: find.byType(InkWell));
      final badge = t.widget<CountBadge>(
        find.descendant(of: row.first, matching: find.byType(CountBadge)),
      );
      expect(badge.count, 0);
      expect(
        find.descendant(of: row.first, matching: find.text('1')),
        findsNothing,
      );
      expect(find.text(l10n.homeNow), findsNothing);
      // the ring, with the tick of a key built into the app
      expect(find.byType(DevAvatar), findsOneWidget);
      expect(find.byType(DevTick), findsOneWidget);
      // a tap opens its chat
      await t.tap(_devTitle);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('the chat dev:m1 '), findsOneWidget);
      await devClose(t);
    });

    testWidgets('after an update: above the groups and every chat, a pinned '
        'one too', (t) async {
      await devWorld(
        chats: [('amber-fox-river', 50, true), ('slow-moss-cave', 90, false)],
      );
      _groups = [
        const GroupSummary(
          groupId: 'g1',
          name: 'Saturday hike',
          memberCount: 3,
        ),
      ];
      await devOpen(t, devHome(groups: _groups));
      final dev = _top(t, _devTitle);
      expect(dev, lessThan(_top(t, find.text(l10n.homeGroups))));
      expect(dev, lessThan(_top(t, find.text('Saturday hike'))));
      expect(dev, lessThan(_top(t, find.text('amber-fox-river'))));
      expect(dev, lessThan(_top(t, find.text('slow-moss-cave'))));
      expect(find.text(l10n.homeNoKryfosYet), findsNothing);
      await devClose(t);
    });

    testWidgets('a decoy shows its own, even on the developer phone', (
      t,
    ) async {
      appState.myXPub = _key.xPub;
      await devWorld(container: HaloContainer.decoy);
      expect(appState.devRow, isNotNull);
      await devOpen(t, devHome(groups: _groups));
      expect(_devTitle, findsOneWidget);
      await devClose(t);
    });

    testWidgets('its menu: mute, archive, unpin, delete. no nickname, no '
        'block, never hidden', (t) async {
      await devWorld(chats: [('amber-fox-river', 50, false)]);
      // started, so it has a contact row the hide picker could have seen
      await devTestChat.begin(_key);
      await appState.refreshContacts();
      expect(
        {for (final c in const PinsHost().hideable()) c.id},
        {'amber-fox-river'},
      );
      await devOpen(t, devHome(groups: _groups));
      await _longPress(t, _devTitle);
      for (final w in [
        l10n.homeMute,
        l10n.homeArchive,
        l10n.contactUnpin,
        l10n.homeDeleteChat,
      ]) {
        expect(find.text(w), findsOneWidget, reason: w);
      }
      expect(find.text(l10n.chatHide), findsNothing);
      expect(find.text(l10n.commonBlock), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(4));
      await t.tapAt(const Offset(10, 10));
      await t.pump(const Duration(milliseconds: 500));
      await devClose(t);
    });
  });

  group('mute, archive, unpin', () {
    testWidgets('mute: the bell on the row, and the chat stays quiet', (
      t,
    ) async {
      await devWorld();
      await devOpen(t, devHome(groups: _groups));
      final row = find.ancestor(of: _devTitle, matching: find.byType(InkWell));
      expect(
        find.descendant(
          of: row.first,
          matching: find.byIcon(Icons.notifications_off_outlined),
        ),
        findsNothing,
      );
      await _longPress(t, _devTitle);
      await _tapIn(t, l10n.homeMute);
      expect(appState.devRow!.muted, isTrue);
      expect((await devTestChat.load())!.muted, isTrue);
      expect(
        find.descendant(
          of: find
              .ancestor(of: _devTitle, matching: find.byType(InkWell))
              .first,
          matching: find.byIcon(Icons.notifications_off_outlined),
        ),
        findsOneWidget,
      );
      // and back
      await _longPress(t, _devTitle);
      await _tapIn(t, l10n.homeUnmute);
      expect(appState.devRow!.muted, isFalse);
      await devClose(t);
    });

    testWidgets('archive: into the archive with the rest, opened from '
        'there, and back pinned', (t) async {
      await devWorld(chats: [('amber-fox-river', 50, false)]);
      await devOpen(t, devHome(groups: _groups));
      await _longPress(t, _devTitle);
      await _tapIn(t, l10n.homeArchive);
      await t.pump(const Duration(seconds: 1));
      expect(appState.devRow!.archived, isTrue);
      expect(_devTitle, findsNothing);
      expect(find.text(l10n.home1Chat(1)), findsOneWidget);
      await devClose(t);

      await devOpen(t, const ArchivedScreen());
      expect(_devTitle, findsOneWidget);
      expect(find.text(l10n.devWelcome), findsOneWidget);
      await t.tap(_devTitle);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('the chat dev:m1 '), findsOneWidget);
      t.state<NavigatorState>(find.byType(Navigator)).pop();
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text(l10n.archivedUnarchive));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(appState.devRow!.archived, isFalse);
      expect(appState.devRow!.pinned, isTrue);
      expect(_devTitle, findsNothing);
      await devClose(t);
    });

    testWidgets('unpin: out of the top, among the chats by time', (t) async {
      await devWorld(chats: [('amber-fox-river', 50, false)]);
      await devOpen(t, devHome(groups: _groups));
      expect(_top(t, _devTitle), lessThan(_top(t, find.text(l10n.homeGroups))));
      await _longPress(t, _devTitle);
      await _tapIn(t, l10n.contactUnpin);
      await t.pump(const Duration(seconds: 1));
      expect(appState.devRow!.pinned, isFalse);
      expect(_devTitle, findsOneWidget);
      // nothing sent yet: it has no time, so it goes last
      expect(_top(t, _devTitle), greaterThan(_top(t, _chatsHead)));
      expect(
        _top(t, _devTitle),
        greaterThan(_top(t, find.text('amber-fox-river'))),
      );
      // pinned again, it is on top again
      await _longPress(t, _devTitle);
      await _tapIn(t, l10n.contactPinToTop);
      await t.pump(const Duration(seconds: 1));
      expect(_top(t, _devTitle), lessThan(_top(t, find.text(l10n.homeGroups))));
      await devClose(t);
    });
  });

  group('delete', () {
    testWidgets('deleted means gone: asked once, gone for good, back only '
        'through Write to Marios', (t) async {
      await devWorld(chats: [('amber-fox-river', 50, false)]);
      await devOpen(t, devHome(groups: _groups));
      await _longPress(t, _devTitle);
      await _tapIn(t, l10n.homeDeleteChat);
      expect(find.text(l10n.homeDeleteThisChat), findsOneWidget);
      expect(find.text(l10n.devDeleteLine), findsOneWidget);
      await _tapIn(t, l10n.commonDelete);
      await t.pump(const Duration(seconds: 1));
      expect(appState.devRow, isNull);
      expect(_devTitle, findsNothing);
      expect((await devTestChat.load())!.state, DevState.gone);
      // every migration again, a restart: still gone
      await devChatTables(devMem, now: 9);
      await appState.refreshContacts();
      await t.pump(const Duration(seconds: 1));
      expect(appState.devRow, isNull);
      expect(_devTitle, findsNothing);
      await devClose(t);

      // the settings row brings a fresh one, on its tap
      await devOpen(t, const SettingsScreen());
      final write = find.text(l10n.settingsWriteToMarios);
      await t.scrollUntilVisible(
        write,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(t.element(write), alignment: 0.5);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.settingsWriteToMariosHint), findsOneWidget);
      expect(find.byType(DevRing), findsOneWidget);
      await t.tap(write);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('the chat dev:m1 '), findsOneWidget);
      expect((await devTestChat.load())!.state, DevState.fresh);
      expect(appState.devRow!.started, isFalse);
      await devClose(t);
    });

    testWidgets('an anonymous chat says its name goes too', (t) async {
      await devWorld(chats: [('amber-fox-river', 50, false)]);
      await devTestChat.begin(
        _key,
        anon: const DevAnon(id: 'made-for-this', edPriv: 'e', xPriv: 'x'),
      );
      await appState.refreshContacts();
      await devOpen(t, devHome(groups: _groups));
      await _longPress(t, _devTitle);
      await _tapIn(t, l10n.homeDeleteChat);
      expect(find.text(l10n.devDeleteLineAnon), findsOneWidget);
      // kept: nothing changes
      await _tapIn(t, l10n.confirmSheetKeep);
      expect(appState.devRow, isNotNull);
      await devClose(t);
    });
  });

  group('the sheet', () {
    Widget opener() => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showDevAboutSheet(context),
            child: const Text('about'),
          ),
        ),
      ),
    );

    Future<void> show(
      WidgetTester t, {
      Locale locale = const Locale('en'),
    }) async {
      await devOpen(t, opener(), locale: locale);
      await t.tap(find.text('about'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    }

    testWidgets('who he is, his words shown, his key in sixteen groups', (
      t,
    ) async {
      await devWorld();
      await show(t);
      expect(find.text(l10n.devRowTitle), findsOneWidget);
      expect(find.text(l10n.devAboutLine), findsOneWidget);
      expect(find.text(l10n.devPinned), findsOneWidget);
      expect(find.text(l10n.devKeyLabel), findsOneWidget);
      expect(find.text(_key.threeWords), findsOneWidget);
      final groups = devFingerprint(_key.xPub);
      expect(groups, hasLength(16));
      expect(groups.join(), _key.xPub);
      for (final g in groups) {
        expect(g, hasLength(4));
        expect(find.text(g), findsWidgets);
      }
      // no nickname, no block
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.text(l10n.commonBlock), findsNothing);
      expect(find.text(l10n.devAnonymous), findsNothing);
      await devClose(t);
    });

    testWidgets('right to left, the key still reads left to right', (t) async {
      await devWorld();
      await show(t, locale: const Locale('ar'));
      expect(t.takeException(), isNull);
      final groups = devFingerprint(_key.xPub);
      final first = t.getCenter(find.text(groups[0]).first);
      final second = t.getCenter(find.text(groups[1]).first);
      final fifth = t.getCenter(find.text(groups[4]).first);
      expect(first.dx, lessThan(second.dx));
      expect(first.dy, closeTo(second.dy, 0.5));
      expect(first.dy, lessThan(fifth.dy));
      expect(
        Directionality.of(t.element(find.text(_key.threeWords))),
        TextDirection.rtl,
      );
      expect(
        t.widget<Text>(find.text(_key.threeWords)).textDirection,
        TextDirection.ltr,
      );
      await devClose(t);
    });

    testWidgets('mute flips in place, delete asks and closes it', (t) async {
      await devWorld();
      await show(t);
      await t.tap(find.text(l10n.contactMute));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(appState.devRow!.muted, isTrue);
      expect(find.text(l10n.contactUnmute), findsOneWidget);
      await t.tap(find.text(l10n.contactDeleteChat));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await _tapIn(t, l10n.commonDelete);
      await t.pump(const Duration(seconds: 1));
      expect(appState.devRow, isNull);
      expect(find.text(l10n.devAboutLine), findsNothing);
      expect(find.text('about'), findsOneWidget);
      await devClose(t);
    });

    testWidgets('an anonymous chat wears its chip', (t) async {
      await devWorld();
      await devTestChat.begin(
        _key,
        anon: const DevAnon(id: 'made-for-this', edPriv: 'e', xPriv: 'x'),
      );
      await appState.refreshContacts();
      await show(t);
      expect(find.text(l10n.devAnonymous), findsOneWidget);
      await devClose(t);
    });
  });

  group('search and forward', () {
    Future<void> type(WidgetTester t, String q) async {
      await t.enterText(find.byType(TextField), q);
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 500));
    }

    testWidgets('found by his name, and opened from there', (t) async {
      await devWorld(chats: [('amber-fox-river', 50, false)]);
      await devOpen(t, const SearchScreen());
      await type(t, 'mari');
      expect(find.text(l10n.devRowTitle, findRichText: true), findsOneWidget);
      expect(find.text(l10n.devPinned), findsOneWidget);
      await t.tap(find.text(l10n.devRowTitle, findRichText: true));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('the chat dev:m1 '), findsOneWidget);
      await devClose(t);
    });

    testWidgets('its messages, once there are some', (t) async {
      await devWorld();
      await devTestChat.begin(_key);
      await devMem.insert('messages', {
        'peer_id': _key.chatId,
        'direction': 'in',
        'plaintext': 'thanks, fixed in the next one',
        'sent_at': 42,
        'msg_uid': 'u1',
      });
      await appState.refreshContacts();
      await devOpen(t, const SearchScreen());
      await type(t, 'fixed');
      expect(find.text(l10n.searchMessages), findsOneWidget);
      // the block is his, with his ring
      expect(find.text(l10n.devRowTitle), findsOneWidget);
      expect(find.byType(DevAvatar), findsOneWidget);
      await devClose(t);
    });

    test('a forward reaches the chat only once it has started', () async {
      await devWorld();
      expect(devForwardTarget, isNull);
      await devTestChat.begin(_key);
      await appState.refreshContacts();
      expect(devForwardTarget?.chatId, _key.chatId);
      // a retired key takes nothing more
      useDevKeysForTest([devCard('m1', status: DevKeyStatus.retired)]);
      await appState.refreshContacts();
      expect(devForwardTarget, isNull);
    });

    test('its place among chats: first when pinned, else by time', () {
      ContactPreview c(String id, int at, {bool pinned = false}) =>
          ContactPreview(
            haloId: id,
            avatarSeed: id,
            when: DateTime.fromMillisecondsSinceEpoch(at),
            pinned: pinned,
          );
      final chats = [c('a', 5, pinned: true), c('b', 30), c('c', 10)];
      DevRow d({bool pinned = false, int? at}) => DevRow(
        keyId: 'm1',
        chatId: 'dev:m1',
        pinned: pinned,
        when: at == null ? null : DateTime.fromMillisecondsSinceEpoch(at),
      );
      expect(devSlot(d(pinned: true), chats), 0);
      expect(devSlot(d(at: 20), chats), 2);
      expect(devSlot(d(at: 40), chats), 1);
      expect(devSlot(d(), chats), 3);
    });
  });

  group('none of it shows', () {
    Future<void> nothingAnywhere(WidgetTester t) async {
      expect(appState.devRow, isNull);
      await devOpen(t, devHome(groups: _groups));
      expect(_devTitle, findsNothing);
      expect(find.byType(DevAvatar), findsNothing);
      expect(find.text(l10n.homeNoKryfosYet), findsOneWidget);
      await devClose(t);

      await devOpen(t, const SettingsScreen());
      await t.scrollUntilVisible(
        find.text(l10n.settingsReportAnIssue),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.settingsWriteToMarios), findsNothing);
      await devClose(t);

      await devOpen(t, const SeenScreen());
      await t.scrollUntilVisible(
        find.text(l10n.seenASeizedUnlockedPhone),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.seenDevChat), findsNothing);
      await devClose(t);

      await devOpen(t, const SearchScreen());
      await t.enterText(find.byType(TextField), 'marios');
      await t.pump(const Duration(milliseconds: 700));
      expect(find.text(l10n.devRowTitle, findRichText: true), findsNothing);
      expect(devForwardTarget, isNull);
      await devClose(t);
    }

    testWidgets('with no pinned key', (t) async {
      useDevKeysForTest(const []);
      await devWorld();
      await nothingAnywhere(t);
    });

    testWidgets('on the developer phone', (t) async {
      appState.myXPub = _key.xPub;
      await devWorld();
      expect(devChatOffered, isFalse);
      await nothingAnywhere(t);
    });

    testWidgets('where a key is pinned, the honest list says what he sees', (
      t,
    ) async {
      await devWorld();
      await devOpen(t, const SeenScreen());
      await t.scrollUntilVisible(
        find.text(l10n.seenDevChat),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.seenDevChatCell), findsNWidgets(3));
      await t.tap(find.text(l10n.seenDevChat));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.seenDevChatLine), findsOneWidget);
      await devClose(t);
    });
  });

  group('motion', () {
    ScaleTransition tick(WidgetTester t) => t.widget<ScaleTransition>(
      find.descendant(
        of: find.byType(DevAvatar),
        matching: find.byType(ScaleTransition),
      ),
    );

    testWidgets('the tick pops once, after the row is in, then rests', (
      t,
    ) async {
      popDevTickAgainForTest();
      final was = devTickGuard;
      devTickGuard = LockGuard(isLocked: () => false);
      addTearDown(() => devTickGuard = was);
      await devWorld();
      t.view.physicalSize = const Size(1000, 1800);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(devApp(devHome(groups: _groups)));
      await t.pump(const Duration(milliseconds: 300));
      expect(tick(t).scale.value, lessThan(1));
      await t.pump(const Duration(seconds: 1));
      expect(tick(t).scale.value, 1);
      // a second home does not pop it again
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(devApp(devHome(groups: _groups)));
      await t.pump(const Duration(milliseconds: 300));
      expect(tick(t).scale.value, 1);
      await devClose(t);
    });

    testWidgets('under the lock the tick is simply there', (t) async {
      popDevTickAgainForTest();
      await devWorld();
      await devOpen(t, devHome(groups: _groups));
      expect(tick(t).scale.value, 1);
      await devClose(t);
    });

    testWidgets('with less movement the row and its tick are simply there', (
      t,
    ) async {
      popDevTickAgainForTest();
      final was = devTickGuard;
      devTickGuard = LockGuard(isLocked: () => false);
      addTearDown(() => devTickGuard = was);
      await devWorld();
      t.view.physicalSize = const Size(1000, 1800);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(devApp(devHome(groups: _groups), still: true));
      await t.pump();
      expect(tick(t).scale.value, 1);
      // no rise: the row is where it will stay
      final at = t.getTopLeft(_devTitle);
      await t.pump(const Duration(seconds: 1));
      expect(t.getTopLeft(_devTitle), at);
      await devClose(t);
    });

    testWidgets('right to left: the ring at the right, nothing overflows', (
      t,
    ) async {
      await devWorld(chats: [('amber-fox-river', 50, false)]);
      await devOpen(t, devHome(groups: _groups), locale: const Locale('ar'));
      expect(t.takeException(), isNull);
      final ring = t.getCenter(find.byType(DevAvatar));
      final title = t.getCenter(_devTitle);
      expect(ring.dx, greaterThan(title.dx));
      await devClose(t);
    });
  });
}
