// SPDX-License-Identifier: GPL-3.0-or-later
// a receipt ticks a message of ours only when it comes from the person the
// message went to, or for a group message from one of its members. the
// real database methods over rows kept in maps
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _v = 'plain-member-one';
const _x = 'contact-not-member';
const _g = 'grp000000001';

Future<_Rows> _phone() async {
  final db = _Rows(MemDb());
  Future<void> out(String uid, String peer, {String? group}) =>
      db.mem.insert('messages', {
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
}
