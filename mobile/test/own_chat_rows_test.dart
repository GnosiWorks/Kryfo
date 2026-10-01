// SPDX-License-Identifier: GPL-3.0-or-later
// clearing, deleting or declining a person reaches their own chat only:
// what they wrote in a group stays in the group, its reactions and files
// with it. the stranger cap counts their own chat too. the real database
// methods over rows kept in maps, the files real ones in a scratch folder
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _bob = 'bob-in-family';
const _g = 'grp000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late Directory media;
  late _Rows db;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('own_chat_rows');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs.path,
        );
    media = await HaloContainer.everyday.mediaDir();
    db = _Rows(MemDb());
    await db.mem.insert('contacts', {
      'halo_id': _bob,
      'onion': 'o',
      'xpub': 'x',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 0,
    });
  });

  tearDown(() => docs.deleteSync(recursive: true));

  // a message from bob with a file and a reaction, in his chat or a group
  Future<File> row(String uid, {String? group}) async {
    final f = File(p.join(media.path, 'in_$uid.bin'))
      ..writeAsBytesSync([1, 2, 3]);
    await db.mem.insert('messages', {
      'peer_id': _bob,
      'direction': 'in',
      'plaintext': uid,
      'sent_at': 1,
      'msg_uid': uid,
      'group_id': group,
      'media_path': f.path,
    });
    await db.mem.insert('reactions', {
      'msg_uid': uid,
      'reactor': '',
      'emoji': 'x',
      'reacted_at': 1,
    });
    return f;
  }

  Future<void> expectGroupKept(File f) async {
    final left = db.mem.rows('messages');
    expect(left.map((r) => r['msg_uid']), ['g1']);
    expect(db.mem.rows('reactions').map((r) => r['msg_uid']), ['g1']);
    expect(f.existsSync(), isTrue);
  }

  for (final (name, run) in <(String, Future<void> Function(HaloDb))>[
    ('clear', (d) => d.clearConversation(_bob)),
    ('delete', (d) => d.deleteConversation(_bob)),
    ('decline', (d) => d.declineRequest(_bob)),
  ]) {
    test('$name takes their chat and leaves the group alone', () async {
      final own = await row('d1');
      final inGroup = await row('g1', group: _g);
      await run(db);
      expect(own.existsSync(), isFalse);
      await expectGroupKept(inGroup);
    });
  }

  test('the stranger cap counts only their own chat', () async {
    await row('g1', group: _g);
    await row('g2', group: _g);
    await row('g3', group: _g);
    expect(await db.countMessagesFrom(_bob), 0);
    expect(await db.countMessagesFrom(_bob, inGroups: true), 3);
    await row('d1');
    expect(await db.countMessagesFrom(_bob), 1);
  });

  test('what we sent counts only our side of their chat', () async {
    await db.mem.insert('messages', {
      'peer_id': _bob,
      'direction': 'out',
      'plaintext': 'to the group',
      'sent_at': 1,
      'msg_uid': 'o1',
      'group_id': _g,
    });
    expect(await db.countMessagesTo(_bob), 0);
  });
}
