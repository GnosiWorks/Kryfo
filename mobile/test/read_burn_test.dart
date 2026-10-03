// SPDX-License-Identifier: GPL-3.0-or-later
// a timed message that came in starts its clock when it is first read, not
// when it arrived. the clock is written the moment it starts, so a phone
// killed right after still burns it at the next start. rows that already
// had a clock from arrival keep it. the real database methods over rows
// kept in maps
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show settleWaitingBurns;
import 'package:kryfo/main.dart' show HaloDb;
import 'package:kryfo/read_burn.dart' show ReadBurns, burnLeft;
import 'package:kryfo/seen_timers.dart';
import 'package:kryfo/widgets/row_anchor.dart';
import 'package:kryfo/widgets/burn_fade.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _peer = 'amber-fox-run';
const _g = 'grp000000001';

Future<void> _row(
  MemDb mem,
  String uid, {
  String direction = 'in',
  int? burnSecs,
  int? burnAt,
  int sentAt = 1,
  String? group,
  String peer = _peer,
  String? media,
}) => mem.insert('messages', {
  'peer_id': peer,
  'media_path': media,
  'direction': direction,
  'plaintext': 'hi $uid',
  'sent_at': sentAt,
  'msg_uid': uid,
  'group_id': group,
  'burn_secs': burnSecs,
  'burn_at': burnAt,
  'sent': 1,
});

Map<String, Object?>? _get(MemDb mem, String uid) {
  for (final r in mem.rows('messages')) {
    if (r['msg_uid'] == uid) return r;
  }
  return null;
}

void main() {
  test('a timed message nobody has read does not burn, however old', () async {
    final mem = MemDb();
    final db = _Rows(mem);
    // came a day ago with a 30 second timer
    final dayAgo = DateTime.now().millisecondsSinceEpoch - 86400000;
    await _row(mem, 'unread', burnSecs: 30, sentAt: dayAgo);
    await _row(mem, 'ingroup', burnSecs: 30, sentAt: dayAgo, group: _g);
    await db.purgeExpiredBurns();
    await db.purgeExpired();
    expect(_get(mem, 'unread'), isNotNull);
    expect(_get(mem, 'ingroup'), isNotNull);
    expect(_get(mem, 'unread')!['burn_at'], isNull);
  });

  test('reading starts the clock and writes it at once', () async {
    final mem = MemDb();
    final db = _Rows(mem);
    await _row(mem, 'a', burnSecs: 300);
    await _row(mem, 'g', burnSecs: 60, group: _g);
    await _row(mem, 'plain');
    final before = DateTime.now().millisecondsSinceEpoch;
    final lit = await db.lightReadBurns(['a', 'g', 'plain', 'nothere']);
    final after = DateTime.now().millisecondsSinceEpoch;
    expect(lit.keys, unorderedEquals(['a', 'g']));
    for (final (uid, secs) in [('a', 300), ('g', 60)]) {
      final at = _get(mem, uid)!['burn_at'] as int;
      expect(at, lit[uid]);
      expect(at, inInclusiveRange(before + secs * 1000, after + secs * 1000));
    }
    expect(_get(mem, 'plain')!['burn_at'], isNull);
    // read again later: the clock it has stays
    final again = await db.lightReadBurns(['a']);
    expect(again['a'], lit['a']);
    expect(_get(mem, 'a')!['burn_at'], lit['a']);
  });

  test('only what came in is lit by reading', () async {
    final mem = MemDb();
    final db = _Rows(mem);
    // ours, not gone yet: its clock starts when it goes
    await _row(mem, 'mine', direction: 'out', burnSecs: 30);
    expect(await db.lightReadBurns(['mine']), isEmpty);
    expect(_get(mem, 'mine')!['burn_at'], isNull);
  });

  test('read, then killed before the screen counted: it still burns at the '
      'next start', () async {
    final mem = MemDb();
    await _row(mem, 'brief', burnSecs: 1);
    // came after: reading the first does not read it
    await _row(mem, 'unread', burnSecs: 1, sentAt: 2);
    await _Rows(mem).lightReadBurns(['brief']);
    // the process dies here; a new one opens the same file later
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final next = _Rows(mem);
    await next.purgeExpiredBurns();
    expect(_get(mem, 'brief'), isNull);
    expect(_get(mem, 'unread'), isNotNull);
  });

  // rows from before this change already have a clock from when they came.
  // they keep it: nothing on the phone says which were read, and a read one
  // must never outlive the time it was given
  test('a clock started on arrival is kept', () async {
    final mem = MemDb();
    final db = _Rows(mem);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _row(mem, 'due', burnAt: now - 1000);
    await _row(mem, 'running', burnAt: now + 60000);
    final lit = await db.lightReadBurns(['running']);
    expect(lit['running'], now + 60000);
    expect(_get(mem, 'running')!['burn_at'], now + 60000);
    await db.purgeExpiredBurns();
    expect(_get(mem, 'due'), isNull);
    expect(_get(mem, 'running'), isNotNull);
  });

  // as the unread count clears for all of it: what came before the row
  // read has been read too, scrolled past or not
  test('reading one starts the clock of every timed one before it in the '
      'chat, and nothing after or elsewhere', () async {
    final mem = MemDb();
    final db = _Rows(mem);
    await _row(mem, 'old', burnSecs: 60, sentAt: 10);
    await _row(mem, 'same', burnSecs: 60, sentAt: 20);
    await _row(mem, 'read', burnSecs: 300, sentAt: 20);
    await _row(mem, 'newer', burnSecs: 60, sentAt: 30);
    await _row(mem, 'mine', direction: 'out', burnSecs: 60, sentAt: 5);
    await _row(mem, 'other', burnSecs: 60, sentAt: 5, peer: 'blue-owl-sky');
    await _row(mem, 'ingroup', burnSecs: 60, sentAt: 5, group: _g);
    final before = DateTime.now().millisecondsSinceEpoch;
    final lit = await db.lightReadBurns(['read']);
    expect(lit.keys, unorderedEquals(['old', 'same', 'read']));
    for (final uid in ['old', 'same']) {
      expect(_get(mem, uid)!['burn_at'], lit[uid]);
      expect(lit[uid], greaterThanOrEqualTo(before + 60000), reason: uid);
    }
    for (final uid in ['newer', 'mine', 'other', 'ingroup']) {
      expect(_get(mem, uid)!['burn_at'], isNull, reason: uid);
    }

    // in a group, the group's own and nobody else's
    await _row(mem, 'g-old', burnSecs: 60, sentAt: 1, group: _g, peer: 'x');
    await _row(mem, 'g-read', burnSecs: 60, sentAt: 9, group: _g);
    final g = await db.lightReadBurns(['g-read']);
    expect(g.keys, unorderedEquals(['ingroup', 'g-old', 'g-read']));
    expect(_get(mem, 'newer')!['burn_at'], isNull);
    expect(_get(mem, 'other')!['burn_at'], isNull);
  });

  // a photo in the strip or a gallery is no read: it shows in the thread
  // alone until then
  test('a timed photo nobody has read stays out of the shared media', () async {
    final mem = MemDb();
    final db = _Rows(mem);
    final soon = DateTime.now().millisecondsSinceEpoch + 60000;
    await _row(mem, 'plain', media: '/m/plain.jpg');
    await _row(mem, 'waits', burnSecs: 30, media: '/m/waits.jpg');
    await _row(mem, 'lit', burnSecs: 30, burnAt: soon, media: '/m/lit.jpg');
    await _row(
      mem,
      'mine',
      direction: 'out',
      burnSecs: 30,
      media: '/m/mine.jpg',
    );
    final shown = [for (final r in await db.mediaFor(_peer)) r['media_path']];
    expect(
      shown,
      unorderedEquals(['/m/plain.jpg', '/m/lit.jpg', '/m/mine.jpg']),
    );
    await db.lightReadBurns(['waits']);
    expect(await db.mediaFor(_peer), hasLength(4));
  });

  // read and burned after the backup, a restore sweeps it by then and never
  // shows it again with a whole window
  test('a backup copy counts what waits from when it was made', () async {
    final mem = MemDb();
    await _row(mem, 'waits', burnSecs: 30);
    await _row(mem, 'lit', burnSecs: 30, burnAt: 5);
    await _row(mem, 'mine', direction: 'out', burnSecs: 30);
    await _row(mem, 'plain');
    await mem.transaction((t) => settleWaitingBurns(t, 1000));
    expect(_get(mem, 'waits')!['burn_at'], 1000 + 30000);
    expect(_get(mem, 'lit')!['burn_at'], 5);
    expect(_get(mem, 'mine')!['burn_at'], isNull);
    expect(_get(mem, 'plain')!['burn_at'], isNull);
  });

  test('both chats read a countdown the same way', () {
    // a fresh 5 minute clock, a moment in
    expect(burnLeft(300000), '5m 00s');
    expect(burnLeft(299990), '5m 00s');
    expect(burnLeft(61000), '1m 01s');
    expect(burnLeft(59000), '59s');
    expect(burnLeft(3600000), '1h 00m');
    expect(burnLeft(0), '0s');
  });

  // the look a chat takes twice a second, on a clock the test moves
  group('the beat', () {
    late int now;
    late SeenTimers timers;
    late ReadBurns reads;
    late List<String> waiting;
    var readingAsked = 0;
    var lit = <List<String>>[];

    Future<void> open(
      WidgetTester t,
      Future<Map<String, int>> Function(List<String> ids) light,
    ) async {
      now = 0;
      readingAsked = 0;
      lit = [];
      waiting = ['x'];
      final anchors = RowAnchors();
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView(
            children: [
              RowAnchor(
                anchors: anchors,
                id: 'x',
                child: const SizedBox(height: 50),
              ),
            ],
          ),
        ),
      );
      timers = SeenTimers(clock: () => now);
      reads = ReadBurns(
        anchors: anchors,
        allowed: () => true,
        reading: () {
          readingAsked++;
          return true;
        },
        waiting: () => waiting,
        light: (ids) {
          lit.add(ids);
          return light(ids);
        },
        clock: () => now,
      )..keepTime(timers);
    }

    Future<void> wait(WidgetTester t, int ms) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        now += 100;
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    void close() {
      reads.dispose();
      timers.dispose();
    }

    testWidgets('it rests while nothing waits', (t) async {
      // as the screen does: a row lit waits no more
      await open(t, (ids) async {
        waiting = [];
        return {for (final id in ids) id: 1};
      });
      await wait(t, 1000);
      expect(lit, [
        ['x'],
      ]);
      readingAsked = 0;
      await wait(t, 5000);
      expect(readingAsked, 0);
      // something new waits and the chat looks: it beats again
      waiting = ['y'];
      reads.look();
      await wait(t, 1000);
      expect(readingAsked, greaterThan(0));
      close();
    });

    testWidgets('a write that fails is tried again later, not twice a '
        'second', (t) async {
      await open(t, (ids) async => throw StateError('disk full'));
      // the chat looks often, a countdown ticking say
      for (var i = 0; i < 70; i++) {
        reads.check();
        await wait(t, 100);
      }
      // at the first beat, then after two seconds, then after four more
      expect(lit.length, inInclusiveRange(2, 3));
      close();
    });

    testWidgets('a row that comes back unlit is not asked again', (t) async {
      await open(t, (ids) async => const {});
      await wait(t, 5000);
      expect(lit, [
        ['x'],
      ]);
      close();
    });
  });

  group('the flame', () {
    Widget flame({required bool waiting, bool still = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: BurnFlame(waiting: waiting, child: const SizedBox(width: 10)),
      ),
    );

    double scale(WidgetTester t) =>
        t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    double opacity(WidgetTester t) =>
        t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    testWidgets('rests low while the clock waits and kindles as it starts', (
      t,
    ) async {
      await t.pumpWidget(flame(waiting: true));
      expect(scale(t), BurnFlame.restScale);
      expect(opacity(t), BurnFlame.restOpacity);
      await t.pumpWidget(flame(waiting: false));
      expect(scale(t), 1);
      expect(opacity(t), 1);
      // it grows into place, not in one jump
      await t.pump(const Duration(milliseconds: 60));
      final mid = t
          .renderObject<RenderBox>(find.byType(SizedBox))
          .localToGlobal(Offset.zero);
      await t.pumpAndSettle();
      final end = t
          .renderObject<RenderBox>(find.byType(SizedBox))
          .localToGlobal(Offset.zero);
      expect(mid, isNot(end));
    });

    testWidgets('with less movement it only brightens', (t) async {
      await t.pumpWidget(flame(waiting: true, still: true));
      expect(scale(t), 1);
      expect(opacity(t), BurnFlame.restOpacity);
      await t.pumpWidget(flame(waiting: false, still: true));
      expect(scale(t), 1);
      expect(
        t.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
      );
    });
  });
}
