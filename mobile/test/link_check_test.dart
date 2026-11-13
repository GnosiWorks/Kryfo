// SPDX-License-Identifier: GPL-3.0-or-later
// a linked computer's start check on stand-ins: a removal the walk brings
// wipes before the gate gives way, a list that names it opens it, no
// network shows the chats read only after the gate's time and goes on
// until it can tell, and a removal that comes then still wipes
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/link_check.dart';
import 'package:kryfo/devices/linked_lock.dart' show LinkedEnd;

class _World {
  final stage = ValueNotifier<LinkCheckStage?>(LinkCheckStage.checking);
  var now = DateTime(2026, 11, 13, 9);
  LinkedEnd? standing;
  var caught = false;
  var drained = true;
  var online = true;
  var routeUp = false;
  final removed = <LinkedEnd>[];
  var confirmed = 0;
  var over = false;
  // what the turn after [turns] waits does to the world
  final at = <int, void Function()>{};
  var turns = 0;
  // the stage at each turn
  final seen = <LinkCheckStage?>[];

  LinkCheck check() => LinkCheck(
    stage: stage,
    standing: () async => standing,
    caught: () async => caught,
    drained: () async => drained,
    removed: (why) async {
      removed.add(why);
      over = true;
    },
    confirmed: () => confirmed++,
    over: () => over,
    online: () => online,
    routeUp: () => routeUp,
    clock: () => now,
    wait: (d) async {
      seen.add(stage.value);
      now = now.add(d);
      turns++;
      at[turns]?.call();
      if (turns > 2000) throw StateError('never ended');
    },
  );

  Duration get since => now.difference(DateTime(2026, 11, 13, 9));
}

void main() {
  test('removed while closed: the walk brings my phone\'s list without '
      'this computer, and it wipes before any chat shows', () async {
    final w = _World();
    w.at[3] = () {
      w.caught = true;
      // the removal is taken as the walk is opened
      w.standing = LinkedEnd.removed;
    };
    await w.check().run();
    expect(w.removed, [LinkedEnd.removed]);
    expect(w.confirmed, 0);
    // the gate stood the whole time: nothing showed, nothing was let go
    expect(w.stage.value, LinkCheckStage.checking);
    expect(w.seen, everyElement(LinkCheckStage.checking));
  });

  test(
    'a removal taken before a kill wipes at once, before any walk',
    () async {
      final w = _World()..standing = LinkedEnd.removed;
      await w.check().run();
      expect(w.removed, [LinkedEnd.removed]);
      expect(w.turns, 0);
    },
  );

  test('still linked: once the walk is in and opened, it opens', () async {
    final w = _World()..routeUp = true;
    w.at[4] = () => w.caught = true;
    await w.check().run();
    expect(w.stage.value, isNull);
    expect(w.confirmed, 1);
    expect(w.removed, isEmpty);
    expect(w.since, const Duration(seconds: 4));
  });

  test('a walk in whose lines were not opened yet does not open it', () async {
    final w = _World()
      ..caught = true
      ..drained = false;
    w.at[6] = () => w.drained = true;
    await w.check().run();
    expect(w.confirmed, 1);
    expect(w.turns, 6);
  });

  test('offline: the chats show read only after the gate\'s time, sending '
      'held, and it opens once the list comes', () async {
    final w = _World()..online = false;
    w.at[90] = () {
      w.online = true;
      w.routeUp = true;
    };
    w.at[100] = () => w.caught = true;
    final run = w.check().run();
    await run;
    // read only from the twentieth second on, never before
    final first = w.seen.indexOf(LinkCheckStage.readOnly);
    expect(first, kLinkGateLeast.inSeconds);
    expect(w.seen.take(first), everyElement(LinkCheckStage.checking));
    expect(w.seen.skip(first), everyElement(LinkCheckStage.readOnly));
    expect(w.stage.value, isNull);
    expect(w.confirmed, 1);
    expect(w.removed, isEmpty);
  });

  test('read only, then the removal comes: it wipes', () async {
    final w = _World()..online = false;
    w.at[200] = () {
      w.caught = true;
      w.standing = LinkedEnd.removed;
    };
    await w.check().run();
    expect(w.seen[150], LinkCheckStage.readOnly);
    expect(w.removed, [LinkedEnd.removed]);
    expect(w.confirmed, 0);
    expect(w.stage.value, LinkCheckStage.readOnly);
    // after two minutes it looks every five seconds
    expect(w.since, greaterThan(const Duration(minutes: 2)));
  });

  test('tor coming up late: the gate waits for it and the fetch, up to its '
      'most', () async {
    // the route up at 15 s: read only at 35 s
    final w = _World();
    w.at[15] = () => w.routeUp = true;
    w.at[60] = () => w.caught = true;
    await w.check().run();
    expect(w.seen.indexOf(LinkCheckStage.readOnly), 35);

    // never up: read only at the most
    final n = _World();
    n.at[80] = () => n.caught = true;
    await n.check().run();
    expect(n.seen.indexOf(LinkCheckStage.readOnly), kLinkGateMost.inSeconds);
  });

  test('a wipe under way ends the check, nothing let go', () async {
    final w = _World();
    w.at[5] = () => w.over = true;
    await w.check().run();
    expect(w.confirmed, 0);
    expect(w.stage.value, LinkCheckStage.checking);
  });

  test('a turn that throws is tried again', () async {
    var n = 0;
    final w = _World();
    final c = LinkCheck(
      stage: w.stage,
      standing: () async => null,
      caught: () async {
        if (++n < 3) throw StateError('not read');
        return true;
      },
      drained: () async => true,
      removed: (_) async {},
      confirmed: () => w.confirmed++,
      over: () => false,
      online: () => true,
      routeUp: () => true,
      clock: () => w.now,
      wait: (d) async => w.now = w.now.add(d),
    );
    await c.run();
    expect(w.confirmed, 1);
  });

  test('the gate\'s time', () {
    bool ends(int s, {bool online = true, int? up}) => linkGateEnds(
      since: Duration(seconds: s),
      online: online,
      routeUpFor: up == null ? null : Duration(seconds: up),
    );
    expect(ends(19, online: false), isFalse);
    expect(ends(20, online: false), isTrue);
    expect(ends(20, up: 19), isFalse);
    expect(ends(20, up: 20), isTrue);
    expect(ends(30, up: 10), isFalse);
    expect(ends(40, up: 20), isTrue);
    expect(ends(44), isFalse);
    expect(ends(45), isTrue);
  });
}
