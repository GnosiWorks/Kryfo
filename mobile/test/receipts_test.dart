// SPDX-License-Identifier: GPL-3.0-or-later
// a receipt ticks a message of ours only when it comes from the person the
// message went to, or for a group message from one of its members. the
// real database methods over rows kept in maps
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'source_body.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _v = 'plain-member-one';
const _x = 'contact-not-member';
const _g = 'grp000000001';

Future<_Rows> _phone({int? burnSecs, int? burnAt}) async {
  final db = _Rows(MemDb());
  Future<void> out(String uid, String peer, {String? group}) =>
      db.mem.insert('messages', {
        'burn_secs': burnSecs,
        'burn_at': burnAt,
        'peer_id': peer,
        'direction': 'out',
        'plaintext': 'hi',
        'sent_at': 1,
        'msg_uid': uid,
        'group_id': group,
        'sent': 0,
        'delivered': 0,
      });
  await out('tov1', _v);
  await out('ing1', _v, group: _g);
  await db.mem.insert('messages', {
    'peer_id': _x,
    'direction': 'in',
    'plaintext': 'theirs',
    'sent_at': 1,
    'msg_uid': 'fromx',
  });
  for (final m in ['me', _v]) {
    await db.mem.insert('group_members', {
      'group_id': _g,
      'halo_id': m,
      'joined_at': 1,
    });
  }
  return db;
}

Map<String, Object?> _row(_Rows db, String uid) =>
    db.mem.rows('messages').firstWhere((r) => r['msg_uid'] == uid);

void main() {
  test('a receipt from the person a message went to ticks it', () async {
    final db = await _phone();
    await db.markDelivered('tov1', from: _v);
    expect(_row(db, 'tov1')['delivered'], 1);
    expect(_row(db, 'tov1')['sent'], 1);
  });

  test('a receipt from anyone else leaves it as it was', () async {
    final db = await _phone();
    await db.markDelivered('tov1', from: _x);
    expect(_row(db, 'tov1')['delivered'], 0);
    expect(_row(db, 'tov1')['sent'], 0);
  });

  test('a group message takes a receipt from a member only', () async {
    final db = await _phone();
    await db.markDelivered('ing1', from: _x);
    expect(_row(db, 'ing1')['delivered'], 0);
    await db.markDelivered('ing1', from: _v);
    expect(_row(db, 'ing1')['delivered'], 1);
  });

  test('a message that came in is never ticked', () async {
    final db = await _phone();
    await db.markDelivered('fromx', from: _x);
    expect(_row(db, 'fromx')['delivered'], 0);
  });

  // its own send timed out or parked, and the receipt is what says it went
  test('a receipt starts the clock of a timed message', () async {
    final db = await _phone(burnSecs: 30);
    final before = DateTime.now().millisecondsSinceEpoch;
    await db.markDelivered('tov1', from: _v);
    final at = _row(db, 'tov1')['burn_at'] as int?;
    expect(at, isNotNull);
    expect(at! >= before + 30000, isTrue);
    expect(at <= DateTime.now().millisecondsSinceEpoch + 30000, isTrue);
  });

  test('a receipt leaves a clock that already runs alone', () async {
    final db = await _phone(burnSecs: 30, burnAt: 1234);
    await db.markDelivered('tov1', from: _v);
    expect(_row(db, 'tov1')['burn_at'], 1234);
  });

  test('a receipt for a message with no timer sets no clock', () async {
    final db = await _phone();
    await db.markDelivered('tov1', from: _v);
    expect(_row(db, 'tov1')['burn_at'], isNull);
  });

  test('a receipt from a stranger starts no clock', () async {
    final db = await _phone(burnSecs: 30);
    await db.markDelivered('tov1', from: _x);
    expect(_row(db, 'tov1')['burn_at'], isNull);
  });

  test('lightBurn starts an unlit clock once and keeps it', () async {
    expect(await (await _phone()).lightBurn('tov1'), isNull);
    final db = await _phone(burnSecs: 60);
    final at = await db.lightBurn('tov1');
    expect(at, _row(db, 'tov1')['burn_at']);
    expect(await db.lightBurn('tov1'), at);
    expect(await db.lightBurn('fromx'), isNull);
  });

  // the text retry is played through in text_resend_test
  test('a file retry that finds it went starts its clock', () {
    final body = bodyOf(
      sourceOf('lib/screens/chat_screen.dart'),
      'Future<bool> _alreadyGoing(',
    );
    final sent = body.indexOf('await session.isSent(');
    final lit = body.indexOf('await session.lightBurn(uid)');
    expect(lit > sent && sent >= 0, isTrue);
    expect(body, contains('msg.burnAt = burnAt'));
  });

  // sent and ticked on an older version, or stopped between being marked
  // sent and having its clock lit: nothing would ever light it again
  Future<_Rows> stranded() async {
    final db = _Rows(MemDb());
    Future<void> row(String uid, String dir, int sent, int? secs) =>
        db.mem.insert('messages', {
          'peer_id': _v,
          'direction': dir,
          'plaintext': 'hi',
          'sent_at': 1,
          'msg_uid': uid,
          'sent': sent,
          'delivered': sent,
          'burn_secs': secs,
        });
    await row('went', 'out', 1, 1);
    await row('waits', 'out', 0, 1);
    await row('plain', 'out', 1, null);
    await row('theirs', 'in', 1, 1);
    return db;
  }

  test(
    'a timed message that went with no clock burns after the sweep',
    () async {
      final db = await stranded();
      final before = DateTime.now().millisecondsSinceEpoch;
      await db.purgeExpired();
      final at = _row(db, 'went')['burn_at'] as int?;
      expect(at, isNotNull);
      expect(at! >= before + 1000, isTrue);
      expect(at <= DateTime.now().millisecondsSinceEpoch + 1000, isTrue);
      for (final uid in ['waits', 'plain', 'theirs']) {
        expect(_row(db, uid)['burn_at'], isNull, reason: uid);
      }
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.purgeExpired();
      final left = db.mem.rows('messages').map((r) => r['msg_uid']).toSet();
      expect(left, {'waits', 'plain', 'theirs'});
    },
  );

  test('opening a chat lights a stranded clock too', () async {
    final db = await stranded();
    await db.purgeExpiredBurns();
    expect(_row(db, 'went')['burn_at'], isNotNull);
    expect(_row(db, 'waits')['burn_at'], isNull);
  });

  test('the sweep leaves a clock that already runs alone', () async {
    final db = await stranded();
    expect(await db.lightStrandedBurns(), 1);
    final at = _row(db, 'went')['burn_at'];
    expect(await db.lightStrandedBurns(), 0);
    expect(_row(db, 'went')['burn_at'], at);
  });
}
