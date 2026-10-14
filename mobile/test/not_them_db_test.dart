// SPDX-License-Identifier: GPL-3.0-or-later
// "this isn't them" on the database: every row that names one person goes,
// in every table there is, with what they wrote in groups and their seat
// there, in one go, and their files after it. the key their number was made
// from is blocked, by the key alone. the person beside them keeps all of
// theirs. an upgrade from 79 makes the table and keeps every row. the
// database runs on the host's sqlite
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlite_channel.dart';

const _p = 'train-ball-cliff';
const _q = 'amber-otter-lake';
const _gid = 'g0a1b2c3d4e5f60718293a4b5c6d7e8f9';
final _key = 'ab' * 32;

// the columns a person, or one of their messages, is named in
const _personCols = {
  'peer_id',
  'halo_id',
  'peer',
  'member',
  'voucher_id',
  'reactor',
  'voter',
  'sender',
  'chat',
  'address',
};
const _uidCols = {'msg_uid', 'poll_uid', 'uid'};
// the phone's, the identity's, the router's or the developer's: no person's
// rows. contacts, messages and groups are written as the app writes them
const _apart = {
  'identity',
  'seen_msgs',
  'prekeys',
  'signed_prekeys',
  'signal_meta',
  'search_meta',
  'hidden_chats',
  'vault_meta',
  'vault_inbox',
  'devchat',
  'blocked_keys',
  'sqlite_sequence',
  'contacts',
  'messages',
  'groups',
  'room_keys',
  'group_roster',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;
  late HaloDb db;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('not_them_db');
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    sql = SqliteChannel.install();
    db = HaloDb();
  });

  tearDown(() async {
    if (sql != null) {
      await db.close();
      sql!.uninstall();
    }
    m.setMockMethodCallHandler(paths, null);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  bool skip() {
    if (sql != null) return false;
    markTestSkipped('no sqlite on this host');
    return true;
  }

  // a file of [who]'s in a container folder
  Future<String> file(String folder, String name) async {
    final d = await HaloContainer.everyday.folder(folder);
    final f = File(p.join(d.path, name))..writeAsBytesSync([1, 2, 3, 4]);
    return f.path;
  }

  String uid(String who) => 'u-one-$who';
  String groupUid(String who) => 'u-group-$who';
  String pollUid(String who) => 'u-poll-$who';

  // [who] as a chat, a group member and a sender in it, with a file in
  // each and a wallpaper of their own
  Future<Map<String, String>> person(String who) async {
    final raw = await db.open();
    final wall = await file('wallpapers', '$who.jpg');
    await raw.insert('contacts', {
      'halo_id': who,
      'onion': 'o-$who',
      'xpub': 'x-$who',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'unread': 1,
      'atmosphere': 'image:$wall',
    });
    final photo = await file('media', 'in_$who.jpg');
    final sent = await file('media', 'out_$who.jpg');
    final inGroup = await file('media', 'g_$who.bin');
    await db.saveMessage(
      who,
      'in',
      'hello',
      msgUid: uid(who),
      mediaPath: photo,
    );
    await db.saveMessage(
      who,
      'out',
      'back',
      msgUid: 'u-out-$who',
      mediaPath: sent,
    );
    await db.saveMessage(
      who,
      'in',
      'to the group',
      msgUid: groupUid(who),
      groupId: _gid,
      filePath: inGroup,
      fileName: 'g.bin',
    );
    await db.saveMessage(
      who,
      'in',
      'a poll',
      msgUid: pollUid(who),
      groupId: _gid,
      poll: '{"q":"?","o":["a","b"]}',
    );
    return {'wall': wall, 'photo': photo, 'sent': sent, 'group': inGroup};
  }

  // a row naming [who] in every other table that names anyone: the person
  // columns take them, the message columns one of theirs, the rest what
  // the column must hold
  Future<Set<String>> everywhere(Database raw, String who) async {
    final filled = <String>{};
    final tables = [
      for (final r in await raw.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        r['name'] as String,
    ];
    for (final t in tables) {
      if (_apart.contains(t) || t.startsWith('dev_') || t.contains('fts')) {
        continue;
      }
      final cols = await raw.rawQuery("PRAGMA table_info('$t')");
      if (!cols.any(
        (c) => _personCols.contains(c['name']) || _uidCols.contains(c['name']),
      )) {
        continue;
      }
      final row = <String, Object?>{};
      for (final c in cols) {
        final n = c['name'] as String;
        final type = (c['type'] as String).toUpperCase();
        if (_personCols.contains(n)) {
          row[n] = n == 'chat' && t == 'notif_rings' ? 'group:$_gid' : who;
        } else if (_uidCols.contains(n)) {
          row[n] = t == 'polls_gone' || n == 'poll_uid'
              ? pollUid(who)
              : t == 'notif_rings'
              ? groupUid(who)
              : uid(who);
        } else if (n == 'group_id') {
          row[n] = _gid;
        } else if (c['notnull'] == 1 && c['dflt_value'] == null) {
          row[n] = type.contains('INT')
              ? 1
              : type.contains('BLOB')
              ? Uint8List.fromList([1])
              : 'v-$t-$n-$who';
        }
      }
      if (row.containsKey('id') && cols.any((c) => c['pk'] == 1)) {
        row.remove('id');
      }
      await raw.insert(t, row, conflictAlgorithm: ConflictAlgorithm.ignore);
      filled.add(t);
    }
    // what of theirs went in the group, by group and sender
    await raw.insert('gone_in', {
      'msg_uid': 'gone-$who',
      'peer_id': 'group:$_gid:$who',
      'at': 1,
    });
    return filled;
  }

  // every row of every table that still names [who] or one of theirs
  Future<List<String>> naming(Database raw, String who) async {
    final out = <String>[];
    final theirs = {who, uid(who), groupUid(who), pollUid(who), 'u-out-$who'};
    for (final r in await raw.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )) {
      final t = r['name'] as String;
      if (t == 'blocked_keys' || t.startsWith('msg_fts')) continue;
      for (final row in await raw.query(t)) {
        for (final e in row.entries) {
          final v = e.value;
          if (v is! String) continue;
          if (theirs.contains(v) || v.endsWith(':$who') || v.contains(who)) {
            out.add('$t.${e.key}');
          }
        }
      }
    }
    return out;
  }

  test('every row naming them goes, in one go, and their files after; the '
      'one beside them keeps all of theirs', () async {
    if (skip()) return;
    final raw = await db.open();
    final pf = await person(_p);
    final qf = await person(_q);
    await db.createGroup(_gid, 'walkers', [_p, _q], isAdmin: false);
    // each reacted to the other
    for (final (by, on) in [(_p, uid(_q)), (_q, uid(_p))]) {
      await raw.insert('reactions', {
        'msg_uid': on,
        'reactor': by,
        'emoji': '*',
        'reacted_at': 1,
      });
    }
    await raw.update(
      'groups',
      {'unread': 4},
      where: 'group_id = ?',
      whereArgs: [_gid],
    );
    final filled = await everywhere(raw, _p);
    await everywhere(raw, _q);
    // the generic rows reached the tables a person has rows in
    expect(
      filled,
      containsAll([
        'reactions',
        'poll_votes',
        'frames_out',
        'edits_out',
        'pins_out',
        'held_onion',
        'first_kept',
        'opener_again',
        'frame_order',
        'media_wants',
        'media_chunks',
        'gone_in',
        'notif_tags',
        'notif_rings',
        'shield',
        'vouches',
        'block_spans',
        'blocked_drops',
        'group_members',
        'group_media_owed',
        'group_ctl_out',
        'group_resent',
        'support_chats',
        'sessions',
        'peer_identities',
        'polls_gone',
      ]),
    );
    expect(await naming(raw, _p), isNotEmpty);
    final qBefore = (await naming(raw, _q)).toSet();

    await db.removeAndBlockKey(_p, _key);

    expect(await naming(raw, _p), isEmpty);
    // the reaction they made on the other's message went; the other's own
    // rows are all there
    expect((await naming(raw, _q)).toSet(), qBefore);
    expect(
      await raw.query('reactions', where: 'reactor = ?', whereArgs: [_q]),
      hasLength(greaterThanOrEqualTo(1)),
    );
    expect(await db.getGroupMembers(_gid), [_q]);
    expect(await db.getContact(_q), isNotNull);
    // their two unread rows in the group left the count
    final g = await raw.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: [_gid],
    );
    expect(g.single['unread'], 2);
    // nothing of theirs is left in the search index either
    expect(
      await raw.rawQuery(
        "SELECT rowid FROM msg_fts WHERE msg_fts MATCH 'hello'",
      ),
      hasLength(1),
    );
    for (final f in pf.values) {
      expect(File(f).existsSync(), isFalse, reason: f);
    }
    for (final f in qf.values) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    // the key is what is blocked, never the words
    expect(await db.keyBlocked(_key), isTrue);
    expect(await db.keyBlocked(_key.toUpperCase()), isTrue);
    expect(await db.keyBlocked('cd' * 32), isFalse);
    expect([for (final k in await db.blockedKeys()) k.x], [_key]);
    expect(await raw.query('blocked_keys', columns: ['x']), [
      {'x': _key},
    ]);
  });

  test('an unblock lets the key go and nothing else', () async {
    if (skip()) return;
    await person(_q);
    await db.removeAndBlockKey(_p, _key);
    await db.removeAndBlockKey('quiet-other-name', 'cd' * 32);
    expect({for (final k in await db.blockedKeys()) k.x}, {_key, 'cd' * 32});
    await db.unblockKey(_key);
    expect(await db.keyBlocked(_key), isFalse);
    expect(await db.keyBlocked('cd' * 32), isTrue);
    expect(await db.getContact(_q), isNotNull);
  });

  test('a fault part way leaves every row as it was', () async {
    if (skip()) return;
    final raw = await db.open();
    await person(_p);
    // the last step has nowhere to write
    await raw.execute('DROP TABLE blocked_keys');
    await expectLater(db.removeAndBlockKey(_p, _key), throwsA(anything));
    expect(await db.getContact(_p), isNotNull);
    expect(
      await raw.query('messages', where: 'peer_id = ?', whereArgs: [_p]),
      hasLength(4),
    );
  });

  test('an upgrade from 79 makes the table and keeps every row', () async {
    if (skip()) return;
    var raw = await db.open();
    expect(await raw.getVersion(), 80);
    await person(_q);
    await raw.execute('DROP TABLE blocked_keys');
    await raw.setVersion(79);
    await db.close();
    db = HaloDb();
    raw = await db.open();
    expect(await raw.getVersion(), 80);
    expect(
      await raw.rawQuery("PRAGMA table_info('blocked_keys')"),
      hasLength(2),
    );
    expect(await db.getContact(_q), isNotNull);
    expect(
      await raw.query('messages', where: 'peer_id = ?', whereArgs: [_q]),
      hasLength(4),
    );
    await db.removeAndBlockKey(_p, _key);
    expect(await db.keyBlocked(_key), isTrue);
  });
}
