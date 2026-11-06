// SPDX-License-Identifier: GPL-3.0-or-later
// someone whose hello was answered here knows this computer before anything
// of theirs comes: the open row of their one-time invite says so, until they
// add us back. a link of theirs that i added from (their main invite) says
// nothing of the kind. the database method is the real one over rows kept
// in maps
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb, kHelloOpen;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _x = 'a8c736e4457b5cb8aa854782c7e9b0e181b4ed7a6c6189e667f821ab26f1c278';

void main() {
  late MemDb mem;
  late _Rows db;

  setUp(() async {
    mem = MemDb();
    db = _Rows(mem);
    await mem.insert('contacts', {
      'halo_id': 'samsung-test-phone',
      'onion': '',
      'xpub': _x,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 0,
    });
  });

  Future<void> hello(String way, int once, {String key = '05$_x'}) =>
      mem.insert('hellos', {
        'ident': 0,
        'way': way,
        'peer': key,
        'invite_id': '0' * 32,
        'fc': 'ab' * 32,
        'at': 1,
        'once': once,
      });

  test('their hello answered: they asked', () async {
    expect(await db.theyAsked('samsung-test-phone'), isFalse);
    await hello(kHelloOpen, 1);
    expect(await db.theyAsked('samsung-test-phone'), isTrue);
    expect(await db.theyAsked('someone-not-here'), isFalse);
  });

  test('added from their link, a hello still waiting or another key\'s row: '
      'they did not', () async {
    await hello(kHelloOpen, 0);
    await hello('in', 1);
    await hello(kHelloOpen, 1, key: '05${'cd' * 32}');
    expect(await db.theyAsked('samsung-test-phone'), isFalse);
  });
}
