// SPDX-License-Identifier: GPL-3.0-or-later
// a group cleared, left or taken out of, and a room that ends, take the
// files still coming in them: a group file's slices are kept under their
// group, and a room's under its members' keys, those that left too. a key
// taken out of a room owes only what its admin had from it, and a row of
// ours goes in only while its group is here, or its file goes. the real
// database methods over rows kept in maps, and the upgrade over the
// system's sqlite
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb, roomTeardownTables;
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/rooms.dart'
    show roomEntry, roomFileBody, roomSliceDigest, roomTextBody;
import 'package:kryfo/screens/group_chat_screen.dart' show keepOwnGroupFile;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'real_sqlite.dart';

const _g = 'grp000000001';
const _other = 'grp000000002';
const _room = 'room00000001';
const _bob = 'bob-in-the-group';
final _mine = 'a1' * 32;
final _k1 = 'b2' * 32;
final _left = 'c3' * 32;
final _stranger = 'd4' * 32;

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;

  Future<void> group(String id, List<String> who, {String? roomPub}) async {
    await mem.insert('groups', {
      'group_id': id,
      'name': id,
      'created_at': 1,
      'is_admin': 0,
      'room_pub': ?roomPub,
      'room_priv': ?(roomPub == null ? null : 'priv'),
    });
    for (final h in who) {
      await mem.insert('group_members', {
        'group_id': id,
        'halo_id': h,
        'joined_at': 1,
      });
    }
  }

  // two of a file's four slices, from [from]
  Future<void> half(String mid, String from, {String? group}) async {
    for (var i = 0; i < 2; i++) {
      await db.putMediaChunk(mid, i, 'AAAA', 4, null, from: from, group: group);
    }
  }

  Set<Object?> chunksLeft() => {
    for (final r in mem.rows('media_chunks')) r['media_id'],
  };

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('group_end_files');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    db = _Rows(mem);
  });

  tearDown(() {
    docs.deleteSync(recursive: true);
    for (final k in incomingMediaProgress.keys.toList()) {
      incomingMediaDone(k);
    }
  });

  for (final (name, run) in <(String, Future<void> Function(HaloDb))>[
    ('cleared', (d) => d.clearGroupConversation(_g)),
    (
      'left or taken out of',
      (d) async {
        await d.clearGroupConversation(_g);
        await d.deleteGroup(_g);
      },
    ),
    ('deleted', (d) => d.deleteGroup(_g)),
  ]) {
    test('a group $name takes the files still coming in it', () async {
      await group(_g, ['me', _bob]);
      await group(_other, ['me', _bob]);
      await half('in-group', _bob, group: _g);
      await half('in-other-group', _bob, group: _other);
      await half('in-their-chat', _bob);
      incomingMediaUpdate(db.container.chatKey(_g), 2, 4);
      incomingMediaUpdate(db.container.chatKey(_other), 2, 4);
      // the weights read once, as a slice coming in reads them
      expect(await db.trimUnfinishedMedia(), isEmpty);
      await run(db);
      expect(chunksLeft(), {'in-other-group', 'in-their-chat'});
      // no paused banner left over the emptied group, the other's stays
      expect(incomingMediaProgress.keys, [db.container.chatKey(_other)]);
      // what is left is weighed again, without the files that went
      expect(await db.trimUnfinishedMedia(files: 2), isEmpty);
    });
  }

  test('a room that ends takes what its keys were still sending, a key '
      'that left too, and slices kept before their group was noted', () async {
    await group(_room, [_mine, _k1], roomPub: _mine);
    await group(_other, ['me', _bob]);
    expect(await db.noteRoomKeys(_room, [_k1, _left]), isTrue);
    await half('from-member', _k1);
    await half('from-one-who-left', _left);
    await half('posted-in-room', _k1, group: _room);
    await half('from-elsewhere', _stranger);
    // filed under another group: not the room's to take
    await half('member-key-elsewhere', _k1, group: _other);
    await db.deleteGroupMessages(_room);
    await db.deleteGroup(_room);
    expect(chunksLeft(), {'from-elsewhere', 'member-key-elsewhere'});
    expect(mem.rows('room_keys'), isEmpty);
    // a room no longer here notes nothing
    expect(await db.noteRoomKeys(_room, [_k1]), isFalse);
    await db.noteRoomEntry(
      _room,
      _k1,
      roomEntry(_room, 'u1', roomTextBody(message: 'hi')),
    );
    expect(await db.noteRoomKeyOut(_room, _k1), isEmpty);
    expect(mem.rows('room_keys'), isEmpty);
  });

  test('a clear takes the slices a message of the group left from before '
      'slices named their group', () async {
    await group(_g, ['me', _bob]);
    await mem.insert('messages', {
      'peer_id': _bob,
      'direction': 'in',
      'plaintext': '',
      'sent_at': 1,
      'msg_uid': 'old-file',
      'group_id': _g,
    });
    await half('old-file', _bob);
    await half('unknown', _bob);
    await db.clearGroupConversation(_g);
    expect(chunksLeft(), {'unknown'});
  });

  test('a key taken out owes what the admin had from it and this phone has '
      'not, each once, until its lane stops', () async {
    await group(_room, [_mine, _k1], roomPub: _mine);
    String e(String uid, [String words = 'hi']) =>
        roomEntry(_room, uid, roomTextBody(message: words));
    for (var i = 0; i < 40; i++) {
      await db.noteRoomEntry(_room, _k1, e('m$i'));
    }
    // the last ones, oldest first, one taken again moved to the end
    await db.noteRoomEntry(_room, _k1, e('m20'));
    final recent = await db.roomRecent(_room, _k1);
    expect(recent, hasLength(32));
    expect(recent.first, e('m8'));
    expect(recent.last, e('m20'));
    final owed = await db.noteRoomKeyOut(
      _room,
      _k1,
      listed: [e('m39'), e('x1'), e('x2')],
    );
    expect(owed, {e('x1'), e('x2')});
    expect(await db.roomOwes(_room, _k1, e('x2')), isTrue);
    // the same uid with other words is not owed
    expect(await db.roomOwes(_room, _k1, e('x2', 'other')), isFalse);
    expect(await db.roomOwesUid(_room, _k1, 'x2'), isTrue);
    expect(await db.roomOwes(_room, _k1, e('m39')), isFalse);
    expect(await db.roomOwes(_room, _k1, e('never-named')), isFalse);
    expect(await db.roomOwesUid(_room, _k1, 'never-named'), isFalse);
    expect(await db.roomKeysGoing(_room), {_k1});
    // in any order
    expect(await db.roomOwedIn(_room, _k1, 'x2'), 1);
    expect(await db.roomOwes(_room, _k1, e('x2')), isFalse);
    // a second remove takes nothing back in
    await db.noteRoomKeyOut(_room, _k1, listed: [e('x1'), e('x2'), e('x3')]);
    expect(await db.roomOwes(_room, _k1, e('x1')), isTrue);
    expect(await db.roomOwes(_room, _k1, e('x2')), isFalse);
    expect(await db.roomOwes(_room, _k1, e('x3')), isFalse);
    await db.roomKeyStopped(_room, _k1);
    expect(await db.roomOwes(_room, _k1, e('x1')), isFalse);
    expect(await db.roomKeysGoing(_room), isEmpty);
    // one that left on its own owes nothing
    expect(await db.noteRoomKeyOut(_room, _left), isEmpty);
    expect(await db.roomKeysGoing(_room), {_left});
  });

  test('a message is named by its room, its uid and what it holds', () async {
    String text(String room, String uid, String words) =>
        roomEntry(room, uid, roomTextBody(message: words));
    final named = text(_room, 'u1', 'hi');
    expect(named, hasLength(32));
    expect(text(_room, 'u1', 'hi'), named);
    expect(text(_room, 'u1', 'hi!'), isNot(named));
    expect(text(_other, 'u1', 'hi'), isNot(named));
    // the uid half alone holds a file's slices till it is whole
    expect(text(_room, 'u1', 'other').substring(0, 16), named.substring(0, 16));
    Future<String> file(List<String> slices) async => roomEntry(
      _room,
      'f1',
      roomFileBody(
        total: slices.length,
        slices: await roomSliceDigest(slices.length, (i) async => slices[i]),
        caption: '',
      ),
    );
    final f = await file(['AAAA', 'BBBB']);
    expect(await file(['AAAA', 'BBBB']), f);
    expect(await file(['AAAA', 'BBBC']), isNot(f));
    // slices are not run together: a split elsewhere is other bytes
    expect(await file(['AAAAB', 'BBB']), isNot(f));
  });

  test('a row of ours in a group is kept only while the group is, and a '
      'file whose row is not kept goes', () async {
    await group(_g, ['me', _bob]);
    Future<bool> save(String uid, String path) => db.saveInGroup(
      'me',
      '',
      groupId: _g,
      msgUid: uid,
      filePath: path,
      fileName: 'voice.wav',
    );
    Future<String> written(String name) async {
      final f = File('${docs.path}/$name');
      await f.writeAsBytes(List.filled(64, 7));
      return f.path;
    }

    final kept = await written('kept.wav');
    expect(await keepOwnGroupFile(kept, () => save('k1', kept)), isTrue);
    expect(File(kept).existsSync(), isTrue);
    expect(mem.rows('messages').single['msg_uid'], 'k1');
    // the group ends while the recorder or the picker is open
    await db.clearGroupConversation(_g);
    await db.deleteGroup(_g);
    final late = await written('late.wav');
    expect(await keepOwnGroupFile(late, () => save('k2', late)), isFalse);
    expect(File(late).existsSync(), isFalse);
    expect(mem.rows('messages'), isEmpty);
    // a row that could not be kept takes its file too
    final failed = await written('failed.wav');
    expect(
      await keepOwnGroupFile(failed, () async => throw StateError('full')),
      isFalse,
    );
    expect(File(failed).existsSync(), isFalse);
  });

  final sql = RealSqlite.open();
  test('a phone from 70 gets the group of each slice and the room keys, '
      'twice over', () async {
    final real = sql!;
    final src = File('lib/main.dart').readAsStringSync();
    final made = src.substring(
      src.indexOf('onCreate: (db, _) async {'),
      src.indexOf('onUpgrade: (db, oldV, newV) async {'),
    );
    final table = RegExp(
      r"'''\s*(CREATE TABLE media_chunks \(.*?\))\s*'''",
      dotAll: true,
    ).firstMatch(made)!.group(1)!;
    expect(table, contains('group_id TEXT'));
    expect(made, contains('await roomKeysTable(db);'));
    final v70 = table.replaceFirst(RegExp(r',\s*group_id TEXT'), '');
    real.run(v70);
    real.run(
      "INSERT INTO media_chunks (media_id, idx, slice, total, at, sender) "
      "VALUES ('m', 0, 'AAAA', 2, 1, '$_bob')",
    );
    // a room_keys of the shape an unreleased build made
    real.run(
      'CREATE TABLE room_keys (group_id TEXT NOT NULL, member TEXT NOT NULL, '
      'heard INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (group_id, member))',
    );
    real.run("INSERT INTO room_keys VALUES ('r', 'k', 3)");
    await roomTeardownTables(RealExecutor(real));
    await roomTeardownTables(RealExecutor(real));
    final keyCols = {
      for (final c in real.run('PRAGMA table_info(room_keys)')) c['name'],
    };
    expect(keyCols, containsAll(['recent', 'owed', 'out']));
    final cols = real
        .run('PRAGMA table_info(media_chunks)')
        .map((c) => c['name']);
    expect(cols.where((c) => c == 'group_id'), hasLength(1));
    expect(real.run('SELECT * FROM media_chunks').single['group_id'], isNull);
    // the old row reads as a key listened to and nothing more
    final row = real.run('SELECT * FROM room_keys').single;
    expect([row['recent'], row['owed'], row['out']], ['', '', '0']);
    final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
    final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));
    expect(
      RegExp(
        r'if \(oldV < 71\) \{[^}]*await roomTeardownTables\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    expect(src, contains('version: 74,'));
  }, skip: sql == null ? 'no sqlite library here' : null);
}
