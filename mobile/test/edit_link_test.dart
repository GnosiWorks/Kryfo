// SPDX-License-Identifier: GPL-3.0-or-later
// an edit that moves a message to another link drops the page title it
// carried for the old one. an edit that keeps the link keeps the title.
// the database method is the real one over rows kept in maps
import 'dart:convert';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemDb mem;
  late _Rows db;

  setUp(() async {
    mem = MemDb();
    db = _Rows(mem);
    await mem.insert('messages', {
      'peer_id': 'amy-who-links',
      'direction': 'out',
      'plaintext': 'look https://a.example/one',
      'sent_at': 1,
      'msg_uid': 'm1',
      'sent': 1,
      'preview': jsonEncode({
        'url': 'https://a.example/one',
        'title': 'The first page',
        'by': 'sender',
      }),
    });
  });

  Object? preview() => mem.rows('messages').single['preview'];

  test('to another link, the old title goes', () async {
    await db.editMessage('m1', 'look https://b.example/two');
    expect(preview(), isNull);
  });

  test('to no link at all, it goes too', () async {
    await db.editMessage('m1', 'never mind');
    expect(preview(), isNull);
  });

  test('the same link with other words keeps it', () async {
    await db.editMessage('m1', 'look at this https://a.example/one');
    expect(preview(), isNotNull);
  });
}
