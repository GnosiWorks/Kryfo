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
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/main.dart' show LinkKin;
import 'package:kryfo/rooms.dart';
import 'package:kryfo/screens/room_preview_sheet.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/kryfo_link_text.dart';

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

class _World {
  var locked = false;
  late final guard = LockGuard(isLocked: () => locked);
  final door = _Door();
  late BuildContext ctx;
  Object? result;
  var finished = false;

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
    takeOwnLink(ctx, raw, guard: guard, act: door.call).then((r) {
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
    ).then((r) {
      result = r;
      finished = true;
    });
    await t.pumpAndSettle();
  }
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

  testWidgets('a room link carries no member count, and none is shown', (
    t,
  ) async {
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

  testWidgets('with less movement the sheet is the same, and still', (t) async {
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
    final app = File('lib/main.dart').readAsStringSync();
    final add = RegExp(
      r'Future<void> showAddContact\(([\s\S]*?)\n}\n',
    ).firstMatch(app)?.group(1);
    expect(add, isNotNull);
    expect(add, contains('takeOwnLink('));
    expect(add, isNot(contains('handleHaloUri(')));
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
