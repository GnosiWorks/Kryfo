// SPDX-License-Identifier: GPL-3.0-or-later
// a group cleared, left or taken out of, and a room that ends, take the
// files still coming in them: a group file's slices are kept under their
// group, and a room's under its members' keys, those that left too. a key
// taken out of a room keeps the first frame number of theirs no longer let
// in. the real database methods over rows kept in maps, and the upgrade
// over the system's sqlite
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb, roomTeardownTables;
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/rooms.dart' show goneKeys, goneText;
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
    expect(await db.noteRoomKeys(_room, [_k1, _left]), isTrue);
    await half('from-member', _k1);
    await half('from-one-who-left', _left);
    await half('posted-in-room', _k1, group: _room);
    await half('from-elsewhere', _stranger);
    await db.deleteGroupMessages(_room);
    await db.deleteGroup(_room);
    expect(chunksLeft(), {'from-elsewhere'});
    expect(mem.rows('room_keys'), isEmpty);
    // a room no longer here notes nothing
    expect(await db.noteRoomKeys(_room, [_k1]), isFalse);
    await db.noteRoomHeard(_room, _k1, 3);
    expect(mem.rows('room_keys'), isEmpty);
  });

  test('a key taken out keeps its cut, a key that left none, and the roster '
      'still reads both as gone', () async {
    await group(_room, [_mine, _k1, _left], roomPub: _mine);
    await db.noteRosterGone(_room, [_k1], cuts: {_k1: 4});
    await db.noteRosterGone(_room, [_left]);
    expect(await db.rosterGone(_room), {_k1, _left});
    expect(await db.rosterCuts(_room), {_k1: 4});
    // the frames below the cut, each number once it is heard
    await db.noteRoomHeard(_room, _k1, 1);
    expect(await db.lateRoomFrame(_room, _k1, 1), isFalse);
    expect(await db.lateRoomFrame(_room, _k1, 2), isTrue);
    expect(await db.lateRoomFrame(_room, _k1, 3), isTrue);
    await db.noteRoomHeard(_room, _k1, 3);
    expect(await db.lateRoomFrame(_room, _k1, 2), isFalse);
    expect(await db.lateRoomFrame(_room, _k1, 4), isFalse);
    expect(await db.lateRoomFrame(_room, _k1, null), isFalse);
    expect(await db.lateRoomFrame(_room, _left, 1), isFalse);
    // heard only goes up
    await db.noteRoomHeard(_room, _k1, 2);
    expect(await db.roomHeard(_room, _k1), 3);
    // a second note keeps the stricter: a lower cut, or none at all
    await db.noteRosterGone(_room, [_k1], cuts: {_k1: 9});
    expect(await db.rosterCuts(_room), {_k1: 4});
    await db.noteRosterGone(_room, [_k1], cuts: {_k1: 2});
    expect(await db.rosterCuts(_room), {_k1: 2});
    await db.noteRosterGone(_room, [_k1]);
    expect(await db.rosterCuts(_room), isEmpty);
    expect(await db.rosterGone(_room), {_k1, _left});
  });

  test('the gone list reads what an older version wrote, and writes keys '
      'with their cut', () {
    expect(goneKeys(null), isEmpty);
    expect(goneKeys('$_k1,$_left'), {_k1: null, _left: null});
    expect(goneKeys('$_k1@4,$_left'), {_k1: 4, _left: null});
    // one not read is no cut at all
    expect(goneKeys('$_k1@x,$_left@0,@3'), {_k1: null, _left: null});
    // the same key twice keeps the stricter
    expect(goneKeys('$_k1@4,$_k1@2'), {_k1: 2});
    expect(goneKeys('$_k1@4,$_k1'), {_k1: null});
    expect(goneText({_k1: 4, _left: null}), '$_k1@4,$_left');
    expect(goneKeys(goneText({_k1: 4, _left: null})), {_k1: 4, _left: null});
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
    await roomTeardownTables(RealExecutor(real));
    await roomTeardownTables(RealExecutor(real));
    final cols = real
        .run('PRAGMA table_info(media_chunks)')
        .map((c) => c['name']);
    expect(cols.where((c) => c == 'group_id'), hasLength(1));
    expect(real.run('SELECT * FROM media_chunks').single['group_id'], isNull);
    expect(real.run('SELECT * FROM room_keys'), isEmpty);
    final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
    final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));
    expect(
      RegExp(
        r'if \(oldV < 71\) \{[^}]*await roomTeardownTables\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    expect(src, contains('version: 71,'));
  }, skip: sql == null ? 'no sqlite library here' : null);
}
