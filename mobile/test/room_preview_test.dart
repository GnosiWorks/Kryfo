// SPDX-License-Identifier: GPL-3.0-or-later
// a room link shows what the link itself says before anything is joined:
// the name, that it is a burner room, how long it has left. no member
// count, no join for a room that closed, and nothing reaches the door the
// join goes through until join is tapped. the door is a stand-in that
// counts its calls
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/main.dart' show LinkKin, handleHaloUriAdded;
import 'package:kryfo/rooms.dart';
import 'package:kryfo/screens/room_preview_sheet.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/kryfo_link_text.dart';
import 'package:kryfo/widgets/press_scale.dart';

RoomLink _link({
  Duration left = const Duration(hours: 3),
  String name = 'Night shift',
  int? cap,
}) => RoomLink(
  roomId: 'room-one',
  name: name,
  expiresAt: DateTime.now().add(left).millisecondsSinceEpoch,
  creatorPub: 'a' * 64,
  fcPk: 'b' * 64,
  cap: cap,
);

class _Door {
  final taken = <String>[];
  Future<String> call(String link) async {
    taken.add(link);
    return 'done';
  }
}

// every sheet that goes up, and a hook on every pop
class _Watch extends NavigatorObserver {
  final sheets = <Route<dynamic>>[];
  void Function()? onPop;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute) sheets.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onPop?.call();
}

class _World {
  var locked = false;
  late final guard = LockGuard(isLocked: () => locked);
  final door = _Door();
  final watch = _Watch();
  // the rooms this phone already holds
  final held = <String>{};
  final askedHere = <String>[];
  late BuildContext ctx;
  Object? result;
  var finished = false;

  Future<bool> here(String id) async {
    askedHere.add(id);
    return held.contains(id);
  }

  // held rooms whose waiting join may move to the door a link names
  final movable = <String>{};
  Future<bool> moves(RoomLink room) async => movable.contains(room.roomId);

  Future<void> start(WidgetTester t, {bool still = false}) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [watch],
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: still),
          child: child!,
        ),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
  }

  Future<void> sheet(WidgetTester t, RoomLink link) async {
    finished = false;
    result = null;
    showRoomPreviewSheet(ctx, link, shutOnLock: guard).then((r) {
      result = r;
      finished = true;
    });
    await t.pumpAndSettle();
  }

  // scanned or pasted in the app
  Future<void> own(WidgetTester t, String raw) async {
    finished = false;
    result = null;
    takeOwnLink(
      ctx,
      raw,
      guard: guard,
      act: door.call,
      here: here,
      movable: moves,
    ).then((r) {
      result = r;
      finished = true;
    });
    await t.pumpAndSettle();
  }

  // from another app, a page or a cold start
  Future<void> outside(WidgetTester t, String raw) async {
    finished = false;
    result = null;
    takeOutsideLink(
      ctx,
      raw,
      guard: guard,
      act: door.call,
      kin: (_) async => (LinkKin.stranger, ''),
      here: here,
      movable: moves,
    ).then((r) {
      result = r;
      finished = true;
    });
    await t.pumpAndSettle();
  }

  // tapped in a chat
  Future<void> tap(WidgetTester t, String link) async {
    finished = false;
    followKryfoLink(
      ctx,
      link,
      guard: guard,
      self: () => null,
      act: door.call,
      kin: (_) async => (LinkKin.stranger, ''),
      here: here,
      movable: moves,
    ).then((_) => finished = true);
    await t.pumpAndSettle();
  }
}

// a room link in every way but the shape of its start
List<String> _misshapen() {
  final good = _link().encode();
  expect(good, startsWith('kryfo://room?'));
  return [
    good.replaceFirst('kryfo://room?', 'kryfo://room/?'),
    good.replaceFirst('kryfo://room?', 'kryfo://roomx?'),
  ];
}

void main() {
  testWidgets('a live room shows its name, that it is a burner room and '
      'when it closes, with join and not now', (t) async {
    final w = _World();
    await w.start(t);
    await w.sheet(t, _link(left: const Duration(hours: 3, minutes: 30)));
    expect(find.text('Night shift'), findsOne);
    expect(find.text(l10n.kryfoLinkTextBurnerRoom), findsOne);
    expect(find.textContaining(l10n.roomsHM('3', '29')), findsOne);
    expect(find.text(l10n.kryfoLinkTextYouJoinUnderA), findsOne);
    expect(find.text(l10n.kryfoLinkTextJoin2), findsOne);
    expect(find.text(l10n.kryfoLinkTextNotNow), findsOne);
    expect(find.text(l10n.kryfoLinkTextThisRoomHasClosed), findsNothing);
    await t.tap(find.text(l10n.kryfoLinkTextJoin2));
    await t.pumpAndSettle();
    expect(w.finished, isTrue);
    expect(w.result, isTrue);
  });

  testWidgets('no member count and no cap are shown', (t) async {
    final w = _World();
    await w.start(t);
    await w.sheet(t, _link(cap: 7));
    expect(find.textContaining('7'), findsNothing);
    await t.tap(find.text(l10n.kryfoLinkTextNotNow));
    await t.pumpAndSettle();
    expect(w.result, isFalse);
  });

  testWidgets('a room link without an end time is no room link: no sheet, '
      'no join', (t) async {
    final w = _World();
    await w.start(t);
    final noEnd = _link().encode().replaceAll(RegExp(r'&exp=\d+'), '');
    expect(noEnd, isNot(contains('exp=')));
    expect(RoomLink.parse(noEnd), isNull);
    await w.outside(t, noEnd);
    expect(find.text(l10n.kryfoLinkTextBurnerRoom), findsNothing);
    expect(w.result, l10n.kryfoLinkTextThatLinkIsNot);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('a closed room says so and has no join', (t) async {
    final w = _World();
    await w.start(t);
    await w.sheet(t, _link(left: const Duration(minutes: -5)));
    expect(find.text('Night shift'), findsOne);
    expect(find.text(l10n.kryfoLinkTextThisRoomHasClosed), findsOne);
    expect(find.text(l10n.kryfoLinkTextJoin2), findsNothing);
    expect(find.textContaining(l10n.roomsExpired), findsNothing);
    await t.tap(find.text(l10n.appOk));
    await t.pumpAndSettle();
    expect(w.finished, isTrue);
    expect(w.result, isFalse);
  });

  testWidgets('a room this phone made and left reads closed on its card and '
      'its sheet, with no join', (t) async {
    addTearDown(endedRooms.clear);
    final link = _link();
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RoomInviteCard(room: link, link: link.encode()),
        ),
      ),
    );
    expect(find.text(l10n.kryfoLinkTextJoin2), findsOne);
    endedRooms.note(HaloContainer.everyday.id, link.roomId, link.expiresAt);
    await t.pump();
    expect(find.text(l10n.kryfoLinkTextThisRoomHasClosed), findsOne);
    expect(find.text(l10n.kryfoLinkTextJoin2), findsNothing);

    final w = _World();
    await w.start(t);
    await w.own(t, link.encode());
    expect(find.text(l10n.kryfoLinkTextThisRoomHasClosed), findsOne);
    expect(find.text(l10n.kryfoLinkTextJoin2), findsNothing);
    await t.tap(find.text(l10n.appOk));
    await t.pumpAndSettle();
    expect(w.result, isNull);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('a room that closes while the sheet is up loses its join', (
    t,
  ) async {
    final w = _World();
    await w.start(t);
    await w.sheet(t, _link(left: const Duration(seconds: 30)));
    expect(find.text(l10n.kryfoLinkTextJoin2), findsOne);
    await t.pump(const Duration(seconds: 31));
    await t.pumpAndSettle();
    expect(find.text(l10n.kryfoLinkTextJoin2), findsNothing);
    expect(find.text(l10n.kryfoLinkTextThisRoomHasClosed), findsOne);
    await t.tap(find.text(l10n.appOk));
    await t.pumpAndSettle();
    expect(w.result, isFalse);
  });

  testWidgets('reduced motion: the sheet is the same, and still', (t) async {
    final w = _World();
    await w.start(t, still: true);
    await w.sheet(t, _link());
    expect(find.text('Night shift'), findsOne);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
      findsNothing,
    );
    await t.tap(find.text(l10n.kryfoLinkTextNotNow));
    await t.pumpAndSettle();
  });

  testWidgets('the sheet goes as the lock comes up, and that is a no', (
    t,
  ) async {
    final w = _World();
    await w.start(t);
    await w.own(t, _link().encode());
    expect(find.text(l10n.kryfoLinkTextJoin2), findsOne);
    w.locked = true;
    w.guard.locking();
    await t.pumpAndSettle();
    expect(find.text(l10n.kryfoLinkTextJoin2), findsNothing);
    expect(w.finished, isTrue);
    expect(w.result, isNull);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('a scanned or pasted room link reaches the door only on join', (
    t,
  ) async {
    final w = _World();
    await w.start(t);
    final link = _link().encode();
    await w.own(t, 'come in $link');
    expect(find.text('Night shift'), findsOne);
    expect(w.door.taken, isEmpty, reason: 'nothing before join');
    await t.tap(find.text(l10n.kryfoLinkTextNotNow));
    await t.pumpAndSettle();
    expect(w.finished, isTrue);
    expect(w.result, isNull);
    expect(w.door.taken, isEmpty);

    await w.own(t, link);
    expect(w.door.taken, isEmpty);
    await t.tap(find.text(l10n.kryfoLinkTextJoin2));
    await t.pumpAndSettle();
    expect(w.door.taken, [link]);
    expect(w.result, 'done');
  });

  testWidgets('a scanned closed room never reaches the door', (t) async {
    final w = _World();
    await w.start(t);
    await w.own(t, _link(left: const Duration(hours: -1)).encode());
    expect(find.text(l10n.kryfoLinkTextThisRoomHasClosed), findsOne);
    await t.tap(find.text(l10n.appOk));
    await t.pumpAndSettle();
    expect(w.result, isNull);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('a scanned invite goes to the door as it was, with no sheet', (
    t,
  ) async {
    final w = _World();
    await w.start(t);
    const invite = 'kryfo://share?id=tourist-admit-sun&onion=x.onion';
    await w.own(t, invite);
    expect(find.byType(BottomSheet), findsNothing);
    expect(w.door.taken, [invite]);
  });

  testWidgets('under the lock a scanned room shows nothing and joins '
      'nothing', (t) async {
    final w = _World();
    await w.start(t);
    w.locked = true;
    await w.own(t, _link().encode());
    expect(find.byType(BottomSheet), findsNothing);
    expect(w.finished, isTrue);
    expect(w.door.taken, isEmpty);
  });

  test('a misshapen room link is no room link', () {
    for (final bad in _misshapen()) {
      expect(RoomLink.parse(bad), isNull, reason: bad);
      expect(RoomLink.parse('join us $bad'), isNull, reason: bad);
    }
  });

  test('the door turns a misshapen room link away and joins nothing', () async {
    for (final bad in _misshapen()) {
      expect(await handleHaloUriAdded(bad), (
        l10n.appInvalidUri,
        false,
      ), reason: bad);
      expect(await handleHaloUriAdded('come in $bad'), (
        l10n.appInvalidUri,
        false,
      ), reason: bad);
    }
  });

  testWidgets('a misshapen room link from outside or a chat is no link and '
      'reaches no door', (t) async {
    final w = _World();
    await w.start(t);
    for (final bad in _misshapen()) {
      await w.outside(t, bad);
      expect(w.result, l10n.kryfoLinkTextThatLinkIsNot, reason: bad);
      await w.tap(t, bad);
      expect(w.finished, isTrue, reason: bad);
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
    }
    expect(w.watch.sheets, isEmpty);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('a misshapen room link scanned or pasted goes to the door as '
      'it was, which turns it away', (t) async {
    final w = _World();
    await w.start(t);
    final links = _misshapen();
    for (final bad in links) {
      await w.own(t, bad);
    }
    expect(w.watch.sheets, isEmpty);
    // the door gets the raw text, and reads it with the same parse
    expect(w.door.taken, links);
    for (final bad in w.door.taken) {
      expect(RoomLink.parse(bad), isNull);
    }
  });

  testWidgets('a room already here opens as it did, with no sheet, from '
      'every way in', (t) async {
    final w = _World()..held.add('room-one');
    await w.start(t);
    final link = _link().encode();
    await w.own(t, link);
    expect(w.result, 'done');
    await w.outside(t, link);
    expect(w.result, 'done');
    await w.tap(t, link);
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(w.watch.sheets, isEmpty);
    expect(w.askedHere, ['room-one', 'room-one', 'room-one']);
    expect(w.door.taken, [link, link, link]);
  });

  testWidgets('a waiting join moves to the door a link names only on the '
      'sheet\'s join, from every way in', (t) async {
    final w = _World()
      ..held.add('room-one')
      ..movable.add('room-one');
    await w.start(t);
    final room = _link();
    final link = room.encode();
    final ways = [w.own, w.outside, w.tap];
    for (final open in ways) {
      await open(t, link);
      expect(find.text(l10n.kryfoLinkTextJoin2), findsOneWidget);
      await t.tap(find.text(l10n.kryfoLinkTextNotNow));
      await t.pumpAndSettle();
      expect(w.door.taken, isEmpty);
      expect(takenDoors.taken(room), isFalse);
    }
    for (final open in ways) {
      await open(t, link);
      await t.tap(find.text(l10n.kryfoLinkTextJoin2));
      await t.pumpAndSettle();
      expect(w.door.taken.last, link);
      expect(takenDoors.taken(room), isTrue);
    }
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(w.watch.sheets, hasLength(6));
    expect(w.door.taken, hasLength(3));
  });

  testWidgets('a room already here takes no other door with no sheet', (
    t,
  ) async {
    final w = _World()..held.add('room-one');
    await w.start(t);
    final room = _link();
    for (final open in [w.own, w.outside, w.tap]) {
      await open(t, room.encode());
      expect(takenDoors.taken(room), isFalse);
    }
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(w.watch.sheets, isEmpty);
    expect(w.door.taken, hasLength(3));
  });

  testWidgets('a room not here is asked about first', (t) async {
    final w = _World()..held.add('another-room');
    await w.start(t);
    await w.own(t, _link().encode());
    expect(w.askedHere, ['room-one']);
    expect(w.watch.sheets, hasLength(1));
    expect(w.door.taken, isEmpty);
    await t.tap(find.text(l10n.kryfoLinkTextNotNow));
    await t.pumpAndSettle();
  });

  testWidgets('under the lock no sheet is ever pushed', (t) async {
    final w = _World();
    await w.start(t);
    w.locked = true;
    final link = _link().encode();
    await w.own(t, link);
    await w.outside(t, link);
    await w.tap(t, link);
    expect(w.watch.sheets, isEmpty);
    // not even this phone's own rooms are read
    expect(w.askedHere, isEmpty);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('the lock coming up as join is tapped joins nothing', (t) async {
    final w = _World();
    await w.start(t);
    final link = _link().encode();
    for (final open in [w.own, w.outside]) {
      await open(t, link);
      expect(w.watch.sheets, isNotEmpty);
      // locked in the same moment the sheet goes, before any pump
      w.watch.onPop = () => w.locked = true;
      await t.tap(find.text(l10n.kryfoLinkTextJoin2));
      await t.pumpAndSettle();
      expect(w.finished, isTrue);
      expect(w.result, isNull);
      expect(w.door.taken, isEmpty);
      w.watch.onPop = null;
      w.locked = false;
    }
  });

  testWidgets('not now is a full finger high', (t) async {
    final w = _World();
    await w.start(t);
    await w.sheet(t, _link());
    final notNow = find.ancestor(
      of: find.text(l10n.kryfoLinkTextNotNow),
      matching: find.byType(PressScale),
    );
    expect(t.getSize(notNow.first).height, greaterThanOrEqualTo(48));
    await t.tap(find.text(l10n.kryfoLinkTextNotNow));
    await t.pumpAndSettle();
  });

  testWidgets('a room name keeps the direction it is written in, on the '
      'sheet and the card in a chat', (t) async {
    const name = 'شیفت شب';
    final w = _World();
    await w.start(t);
    await w.sheet(t, _link(name: name));
    expect(t.widget<Text>(find.text(name)).textDirection, TextDirection.rtl);
    await t.tap(find.text(l10n.kryfoLinkTextNotNow));
    await t.pumpAndSettle();

    final link = _link(name: name);
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        home: Scaffold(
          body: RoomInviteCard(room: link, link: link.encode()),
        ),
      ),
    );
    expect(t.widget<Text>(find.text(name)).textDirection, TextDirection.rtl);
  });

  test('the sheet reaches nothing: no engine, no session, no relay', () {
    final src = File('lib/screens/room_preview_sheet.dart').readAsStringSync();
    for (final word in [
      'main.dart',
      'engine',
      'session',
      'relay',
      'appState',
      'handleHaloUri',
      'joinRoom',
      'package:http',
      'dart:io',
    ]) {
      expect(src, isNot(contains(word)), reason: word);
    }
  });

  test('every way a room link is opened in the app asks first', () {
    final app = [
      'lib/app/shell.dart',
      'lib/app/dev_screen.dart',
    ].map((f) => File(f).readAsStringSync()).join('\n');
    final add = RegExp(
      r'Future<void> showAddContact\(([\s\S]*?)\n}\n',
    ).firstMatch(app)?.group(1);
    expect(add, isNotNull);
    expect(add, contains('takeOwnLink('));
    expect(add, isNot(contains('handleHaloUri(')));
    final dev = RegExp(
      r'Future<void> _importPeer\(\) async \{([\s\S]*?)\n  \}\n',
    ).firstMatch(app)?.group(1);
    expect(dev, isNotNull);
    expect(dev, contains('takeOwnLink('));
    expect(dev, isNot(contains('handleHaloUri(')));
    for (final f in [
      'lib/screens/my_kryfo_screen.dart',
      'lib/screens/onboarding_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('takeOwnLink('), reason: f);
      expect(src, isNot(contains('handleHaloUri(')), reason: f);
    }
    final link = File('lib/widgets/kryfo_link_text.dart').readAsStringSync();
    final follow = RegExp(
      r'Future<void> followKryfoLink\(([\s\S]*?)\n}\n',
    ).firstMatch(link)?.group(1);
    expect(follow, isNotNull);
    expect(follow, contains('takeOutsideLink('));
    expect(follow, isNot(contains('act(link)')));
  });
}
