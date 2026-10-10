// SPDX-License-Identifier: GPL-3.0-or-later
// a deleted chat takes the name given them with it, so a re-add starts from
// their own name. the verified mark stays on the key it was given for: a
// re-add on another key is still held. the real database methods over rows
// kept in maps
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
}
