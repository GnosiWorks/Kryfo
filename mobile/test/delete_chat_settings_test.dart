// SPDX-License-Identifier: GPL-3.0-or-later
// a deleted chat takes what was set for it along, so when they write again
// they come back as a new person: no disguise, wallpaper, note, mute or pin,
// a fresh shield check and a new notification tag. the block, the verified
// mark on its key and the vouches for them stay
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/drafts.dart';
import 'package:kryfo/main.dart' show HaloDb, session;
import 'package:kryfo/screens/chat_screen.dart' show dropChatDraft;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _peer = 'someone-we-dressed-up';
const _friend = 'someone-who-vouched';

Future<_Rows> _seeded() async {
  final db = _Rows(MemDb());
  for (final id in [_peer, _friend]) {
    await db.mem.insert('contacts', {
      'halo_id': id,
      'onion': 'o',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
    });
  }
  await db.mem.update(
    'contacts',
    {
      'nickname': 'Mum',
      'note': 'birthday in may',
      'atmosphere': 'dusk',
      'voice_disguise': 1,
      'muted': 1,
      'pinned': 1,
      'unread': 3,
      'blocked': 1,
      'verified': 1,
      'verified_key': 'k1',
      'key_changed': 1,
      'peer_bundle': 'b',
      'back_paired': 1,
      'supporter_badge': 'gold',
      'avatar': 4,
    },
    where: 'halo_id = ?',
    whereArgs: [_peer],
  );
  await db.mem.insert('shield', {
    'halo_id': _peer,
    'headline': '',
    'lines': '[]',
    'dismissed': 1,
    'at': 1,
  });
  await db.mem.insert('notif_tags', {'chat': _peer, 'tag': 't-peer'});
  await db.mem.insert('notif_tags', {'chat': _friend, 'tag': 't-friend'});
  await db.mem.insert('vouches', {
    'halo_id': _peer,
    'voucher_id': _friend,
    'created_at': 1,
  });
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('delete chat clears what was set for the chat', () async {
    final db = await _seeded();
    await db.deleteConversation(_peer);
    final row = db.mem
        .rows('contacts')
        .singleWhere((r) => r['halo_id'] == _peer);
    expect(row['voice_disguise'], isNull);
    expect(row['atmosphere'], isNull);
    expect(row['note'], isNull);
    expect(row['nickname'], isNull);
    expect(row['muted'], 0);
    expect(row['pinned'], 0);
    expect(row['unread'], 0);
    expect(row['accepted'], 0);
    expect(row['archived'], 1);
  });

  test('delete chat keeps what must outlive it', () async {
    final db = await _seeded();
    await db.deleteConversation(_peer);
    final row = db.mem
        .rows('contacts')
        .singleWhere((r) => r['halo_id'] == _peer);
    // the subscription and the session are built from these
    expect(row['xpub'], 'x-$_peer');
    expect(row['peer_bundle'], 'b');
    expect(row['back_paired'], 1);
    // a block, the verified key and a key change are not the chat's
    expect(row['blocked'], 1);
    expect(row['verified'], 1);
    expect(row['verified_key'], 'k1');
    expect(row['key_changed'], 1);
    // theirs, not ours
    expect(row['supporter_badge'], 'gold');
    expect(row['avatar'], 4);
    expect(db.mem.rows('vouches'), hasLength(1));
  });

  test('delete chat drops the shield and the notification tag', () async {
    final db = await _seeded();
    await db.deleteConversation(_peer);
    expect(await db.shieldFor(_peer), isNull);
    expect(db.mem.rows('notif_tags').map((r) => r['chat']), [_friend]);
    // the other chat is untouched
    final friend = db.mem
        .rows('contacts')
        .singleWhere((r) => r['halo_id'] == _friend);
    expect(friend['accepted'], 1);
  });

  test('a deleted chat leaves no draft behind', () {
    final key = session.chatKey(_peer);
    final other = session.chatKey(_friend);
    draftPerPeer[key] = 'half a thought';
    draftPerPeer[other] = 'keep me';
    addTearDown(draftPerPeer.clear);
    dropChatDraft(_peer);
    expect(draftPerPeer.containsKey(key), isFalse);
    expect(draftPerPeer[other], 'keep me');
  });
}
