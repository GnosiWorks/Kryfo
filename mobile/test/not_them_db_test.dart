// SPDX-License-Identifier: GPL-3.0-or-later
// "this isn't them" on the database: every row that names one person goes,
// in every table there is, with what they wrote in groups and their seat
// there, in one go, and their files after it. the key their number was made
// from is blocked, by the key alone. the person beside them keeps all of
// theirs. an upgrade from 80 makes the tables and keeps every row. the
// database runs on the host's sqlite
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show HaloDb, kAdminGone, tidyIfOwed;
import 'package:kryfo/router.dart' show RouterRows;
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
  'name_tombs',
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
      if (t == 'blocked_keys' || t == 'name_tombs' || t.startsWith('msg_fts')) {
        continue;
      }
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

    // a group they ran, and one they did not
    await raw.insert('groups', {
      'group_id': 'gran0000001',
      'name': 'theirs',
      'created_at': 1,
      'admin_id': _p,
    });
    final went = await db.removeAndBlockKey(_p, _key);
    expect(went.toSet(), {uid(_p), 'u-out-$_p', groupUid(_p), pollUid(_p)});

    expect(await naming(raw, _p), isEmpty);
    // the words are let go, and the group they ran has no admin
    expect(await db.tombed(_p), isTrue);
    expect(await db.tombed(_q), isFalse);
    final ran = await raw.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: ['gran0000001'],
    );
    expect(ran.single['admin_id'], kAdminGone);
    await db.clearTomb(_p);
    expect(await db.tombed(_p), isFalse);
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

  test('a seat elsewhere goes: group seats, a key-only row and an admin, '
      'never a chat', () async {
    if (skip()) return;
    final raw = await db.open();
    await person(_q);
    await raw.insert('contacts', {
      'halo_id': _p,
      'onion': 'o',
      'xpub': _key,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 0,
    });
    await db.createGroup(
      _gid,
      'walkers',
      [_p, _q, 'no-key-here'],
      isAdmin: false,
      adminId: _p,
    );
    // the same words on another key are someone else: nothing of theirs goes
    await db.dropSeats(_p, 'cd' * 32);
    expect(await db.getGroupMembers(_gid), hasLength(3));
    expect(await db.getContact(_p), isNotNull);
    expect((await db.getGroup(_gid))?['admin_id'], _p);
    await db.dropSeats(_p, _key);
    await db.dropSeats(_q, 'x-$_q');
    // a seat with no row, and so no key, goes too
    await db.dropSeats('no-key-here', _key);
    expect(await db.getGroupMembers(_gid), isEmpty);
    expect(await db.getContact(_p), isNull);
    // a chat of their own stays
    expect(await db.getContact(_q), isNotNull);
    expect((await db.getGroup(_gid))?['admin_id'], kAdminGone);
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

  // every word of [words] in any file of the container's folder
  List<String> inFiles(List<String> words) {
    final hits = <String>{};
    for (final f in docs.listSync(recursive: true)) {
      if (f is! File) continue;
      final text = latin1.decode(f.readAsBytesSync(), allowInvalid: true);
      for (final w in words) {
        if (text.contains(w)) hits.add(w);
      }
    }
    return hits.toList()..sort();
  }

  for (final how in ['not them', 'delete chat']) {
    test('$how: once its owed tidy ran, no word of theirs is left in the '
        'file', () async {
      if (skip()) return;
      final raw = await db.open();
      for (final (who, x) in [(_p, 'ab'), (_q, 'cd')]) {
        await raw.insert('contacts', {
          'halo_id': who,
          'onion': 'o',
          'xpub': x * 32,
          'first_seen': 1,
          'last_seen': 1,
          'accepted': 1,
        });
      }
      for (var i = 0; i < 300; i++) {
        await db.saveMessage(
          _p,
          'in',
          'zqxjfakeword$i plumbuscrypt secretfakephrase',
          msgUid: 'uf$i',
        );
        await db.saveMessage(_q, 'in', 'keepme$i harmless', msgUid: 'uo$i');
      }
      if (how == 'not them') {
        await db.removeAndBlockKey(_p, _key);
      } else {
        await db.deleteConversation(_p);
      }
      const theirs = ['plumbuscrypt', 'secretfakephrase', 'zqxjfakeword'];
      // the search index still holds them in leaves it no longer reads
      await raw.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      expect(inFiles(theirs), isNotEmpty);
      await tidyIfOwed(raw);
      await raw.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await db.close();
      expect(inFiles(theirs), isEmpty);
      expect(inFiles(['keepme']), ['keepme']);
      // done: nothing owed any more
      final again = await db.open();
      expect(await RouterRows.tidyOwed(again), isFalse);
    });
  }

  test('on the real database: the remove, the words, the admins, the seats '
      'and the tidy, among many rows', () async {
    if (skip()) return;
    final raw = await db.open();
    for (final (id, x) in [
      ('fake-word-one', 'ab' * 32),
      ('other-word-two', 'cd' * 32),
    ]) {
      await raw.insert('contacts', {
        'halo_id': id,
        'onion': 'o',
        'xpub': x,
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
      });
    }
    for (final g in ['g1', 'g2']) {
      await db.createGroup(
        g,
        'g',
        ['fake-word-one', 'my-own-words'],
        isAdmin: false,
        adminId: 'fake-word-one',
      );
    }
    for (var i = 0; i < 300; i++) {
      await db.saveMessage(
        'fake-word-one',
        'in',
        'zqxjfakeword$i plumbuscrypt secretfakephrase',
        msgUid: 'uf$i',
      );
    }
    final pad = 'lorem ipsum dolor sit amet ' * 15;
    await raw.transaction((t) async {
      for (var i = 0; i < 2000; i++) {
        await t.insert('messages', {
          'peer_id': 'other-word-two',
          'direction': 'in',
          'plaintext': 'keepme$i $pad',
          'sent_at': i,
          'msg_uid': 'uo$i',
        });
      }
    });
    expect(await RouterRows.tidyOwed(raw), isFalse);
    final went = await db.removeAndBlockKey('fake-word-one', 'ab' * 32);
    expect(went, hasLength(300));
    expect(await RouterRows.tidyOwed(raw), isTrue);
    expect(await db.tombed('fake-word-one'), isTrue);
    expect(await db.tombed('other-word-two'), isFalse);
    expect(
      {
        for (final r in await raw.query('groups', columns: ['admin_id']))
          r['admin_id'],
      },
      {kAdminGone},
    );
    expect(await db.keyBlocked('AB' * 32), isTrue);
    await db.createGroup(
      'g3',
      'g',
      ['seat-only-x', 'my-own-words'],
      isAdmin: false,
      adminId: 'seat-only-x',
    );
    await raw.insert('contacts', {
      'halo_id': 'seat-only-x',
      'onion': 'o',
      'xpub': 'ef' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 0,
    });
    await db.dropSeats('seat-only-x', 'ef' * 32);
    expect(await db.getGroupMembers('g3'), ['my-own-words']);
    expect(await db.getContact('seat-only-x'), isNull);
    expect(await db.groupAdminId('g3'), kAdminGone);
    await tidyIfOwed(raw);
    expect(await RouterRows.tidyOwed(raw), isFalse);
    await db.deleteConversation('other-word-two');
    expect(await RouterRows.tidyOwed(raw), isTrue);
    await tidyIfOwed(raw);
    await db.close();
    expect(
      inFiles(['plumbuscrypt', 'secretfakephrase', 'zqxjfakeword', 'keepme1']),
      isEmpty,
    );
  });

  test('R3-6 a file at this branch\'s old 80, with the blocked keys and no '
      'ack column, opens at 81 with both', () async {
    if (skip()) return;
    var raw = await db.open();
    await raw.execute('ALTER TABLE contacts DROP COLUMN ack_owed');
    await raw.setVersion(80);
    await db.close();
    db = HaloDb();
    raw = await db.open();
    expect(await raw.getVersion(), 83);
    final cols = await raw.rawQuery("PRAGMA table_info('contacts')");
    expect(cols.any((c) => c['name'] == 'ack_owed'), isTrue);
    expect(
      await raw.rawQuery("PRAGMA table_info('blocked_keys')"),
      hasLength(2),
    );
  });

  test('an upgrade from 80 makes the tables and keeps every row', () async {
    if (skip()) return;
    var raw = await db.open();
    expect(await raw.getVersion(), 83);
    await person(_q);
    await raw.execute('DROP TABLE blocked_keys');
    await raw.execute('DROP TABLE name_tombs');
    await raw.setVersion(80);
    await db.close();
    db = HaloDb();
    raw = await db.open();
    expect(await raw.getVersion(), 83);
    expect(
      await raw.rawQuery("PRAGMA table_info('blocked_keys')"),
      hasLength(2),
    );
    expect(await raw.rawQuery("PRAGMA table_info('name_tombs')"), hasLength(2));
    expect(await db.getContact(_q), isNotNull);
    expect(
      await raw.query('messages', where: 'peer_id = ?', whereArgs: [_q]),
      hasLength(4),
    );
    await db.removeAndBlockKey(_p, _key);
    expect(await db.keyBlocked(_key), isTrue);
  });
}
