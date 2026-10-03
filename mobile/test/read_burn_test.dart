// SPDX-License-Identifier: GPL-3.0-or-later
// a timed message that came in starts its clock when it is first read, not
// when it arrived. the clock is written the moment it starts, so a phone
// killed right after still burns it at the next start. rows that already
// had a clock from arrival keep it. the real database methods over rows
// kept in maps
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb;
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
}) => mem.insert('messages', {
  'peer_id': _peer,
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
    await _row(mem, 'unread', burnSecs: 1);
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
