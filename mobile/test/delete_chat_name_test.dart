// SPDX-License-Identifier: GPL-3.0-or-later
// a deleted chat takes the name given them with it, so a re-add starts from
// their own name. the verified mark stays on the key it was given for: a
// re-add on another key is still held. words a request, an introduction or
// a group gave start out not checked, and once such a chat is deleted they
// hold nothing against a link. the real database methods over rows kept in
// maps
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        NameHold,
        kNameAsk,
        kNameSays,
        nameAsks,
        nameCheckOf,
        nameHoldOf,
        nameUnchecked;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _peer = 'someone-we-named';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('delete chat drops the nickname and keeps the verified key', () async {
    final db = _Rows(MemDb());
    await db.mem.insert('contacts', {
      'halo_id': _peer,
      'onion': 'o',
      'xpub': 'x',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'nickname': 'Mum',
      'verified': 1,
      'verified_key': 'k1',
    });
    await db.deleteConversation(_peer);
    final row = db.mem.rows('contacts').single;
    expect(row['nickname'], isNull);
    expect(row['accepted'], 0);
    expect(row['archived'], 1);
    expect(row['verified_key'], 'k1');
  });

  test('words a request or a card gave start out not checked, an add does '
      'not', () async {
    final db = _Rows(MemDb());
    await db.upsertContact('asked-first-words', 'o', 'x', accepted: 0);
    await db.upsertContactStub('group-card-words', 'o', 'x');
    await db.upsertContact('added-here-words', 'o', 'x');
    Map<String, Object?> row(String id) =>
        db.mem.rows('contacts').firstWhere((r) => r['halo_id'] == id);
    expect(nameCheckOf(row('asked-first-words')), kNameAsk | kNameSays);
    expect(nameCheckOf(row('group-card-words')), kNameAsk | kNameSays);
    expect(nameCheckOf(row('added-here-words')), 0);
    expect(nameUnchecked(row('asked-first-words')), isTrue);
    // a request asks for the number once it is taken in
    expect(nameAsks(row('asked-first-words')), isFalse);
    await db.acceptRequest('asked-first-words');
    expect(nameAsks(row('asked-first-words')), isTrue);
    expect(nameUnchecked(row('added-here-words')), isFalse);
  });

  test('what a link may do about the one holding its words', () {
    Map<String, Object?> r({
      int flags = 3,
      int accepted = 0,
      int archived = 0,
      int verified = 0,
      int blocked = 0,
      String id = 'some-held-words',
    }) => {
      'halo_id': id,
      'name_check': flags,
      'accepted': accepted,
      'archived': archived,
      'verified': verified,
      'blocked': blocked,
    };
    expect(nameHoldOf(r()), NameHold.ask);
    expect(nameHoldOf(r(accepted: 1)), NameHold.ask);
    // deleted: nothing here holds it
    expect(nameHoldOf(r(archived: 1)), NameHold.free);
    // verified, blocked, checked by a scan or added by hand: it stays
    expect(nameHoldOf(r(verified: 1)), NameHold.kept);
    expect(nameHoldOf(r(verified: 1, archived: 1)), NameHold.kept);
    expect(nameHoldOf(r(blocked: 1)), NameHold.kept);
    expect(nameHoldOf(r(flags: 0, archived: 1)), NameHold.kept);
    expect(nameHoldOf(r(flags: kNameAsk, accepted: 1)), NameHold.kept);
    expect(nameHoldOf(null), NameHold.kept);
    // nor is the developer's ever let go
    expect(nameHoldOf(r(id: 'dev:marios')), NameHold.kept);
  });

  test('a name let go keeps no key and nothing said about it', () async {
    final db = _Rows(MemDb());
    await db.mem.insert('contacts', {
      'halo_id': _peer,
      'onion': 'o',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 0,
      'archived': 1,
      'peer_bundle': 'b',
      'avatar': 4,
      'name_check': 3,
    });
    await db.mem.insert('vouches', {
      'halo_id': _peer,
      'voucher_id': 'a-friend-here',
      'created_at': 1,
    });
    await db.forgetName(_peer);
    final row = db.mem.rows('contacts').single;
    expect(row['xpub'], '');
    expect(row['peer_bundle'], isNull);
    expect(row['avatar'], isNull);
    expect(row['verified'], 0);
    expect(row['name_check'], kNameAsk | kNameSays);
    expect(db.mem.rows('vouches'), isEmpty);
  });
}
