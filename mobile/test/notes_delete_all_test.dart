// SPDX-License-Identifier: GPL-3.0-or-later
// deleting every note takes the notes and their reactions, and nothing of
// any other chat. the rows are the app's own tables, kept in maps
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:kryfo/screens/notes_screen.dart' show kNotesPeerId;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
  });

  test(
    'every note goes, with its reactions; other chats keep theirs',
    () async {
      final mem = MemDb();
      Future<void> msg(String peer, String uid, {String? group}) =>
          mem.insert('messages', {
            'peer_id': peer,
            'direction': 'in',
            'plaintext': uid,
            'sent_at': 1,
            'msg_uid': uid,
            'group_id': ?group,
          });
      await msg(kNotesPeerId, 'n1');
      await msg(kNotesPeerId, 'n2');
      await msg('amber-fox-river', 'c1');
      await msg(kNotesPeerId, 'g1', group: 'grp000000001');
      await mem.insert('reactions', {
        'msg_uid': 'n1',
        'reactor': 'me',
        'emoji': '❤️',
        'reacted_at': 1,
      });
      final went = await _Rows(mem).deleteAllOf(kNotesPeerId);
      expect(went, 2);
      expect([
        for (final r in mem.rows('messages')) r['msg_uid'],
      ], unorderedEquals(['c1', 'g1']));
      expect(mem.rows('reactions'), isEmpty);
    },
  );
}
