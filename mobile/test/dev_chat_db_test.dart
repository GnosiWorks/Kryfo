// SPDX-License-Identifier: GPL-3.0-or-later
// the developer chat's row in a container's database: seeded fresh on a new
// install and on an upgrade, never overwritten by a seed, started once, and
// deleted for good: every row of it goes, its files are shredded, and no
// migration, key list or restart brings it back. only the settings row
// does. home keeps it beside the contacts, a decoy shows its own, and a
// vault never holds it. an anonymous chat's own signal store sits in the
// dev_ tables of v55, goes with a delete, and stays behind with its made
// name when a copy of the database leaves the phone: the copy reads, and
// sends and hears nothing. the database is a stand-in with the app's own
// tables (mem_db.dart), so nothing here needs sqlite
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_gate.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devchat/dev_lane.dart';
import 'package:kryfo/devchat/support.dart' show SupportChats;
import 'package:kryfo/main.dart' show AppState, HaloDb, useDatabasesForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_stores.dart' show kDevSignalPrefix, kSignalTables;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show DatabaseExecutor;

import 'mem_db.dart';

DevKey _key(String id, int n, {DevKeyStatus status = DevKeyStatus.current}) =>
    DevKey(
      keyId: id,
      threeWords: 'word-$n-$id',
      xPub: n.toRadixString(16).padLeft(2, '0') * 32,
      bundle: 'bundle-$id',
      fc: (n + 1).toRadixString(16).padLeft(2, '0') * 32,
      status: status,
    );

final _m1 = _key('m1', 0x11);
final _m2 = _key('m2', 0x22);
final _m1old = _key('m1', 0x11, status: DevKeyStatus.previous);
final _m1retired = _key('m1', 0x11, status: DevKeyStatus.retired);

const _dev = 'dev:m1';
const _other = 'amber-fox-river';
const _anon = DevAnon(
  id: 'made-for-this',
  edPriv: 'anon-ed-priv',
  xPriv: 'anon-x-priv',
);

// a database as an upgrade from v53 finds it: every table but the dev
// chat's
MemDb _v53() => MemDb(except: {'devchat'});

Future<MemDb> _fresh({int now = 1}) async {
  final db = _v53();
  await devChatTables(db, now: now);
  return db;
}

Future<void> _contact(MemDb db, String id, {int accepted = 1}) =>
    db.insert('contacts', {
      'halo_id': id,
      'onion': 'o-$id',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': accepted,
    });

Future<File> _file(Directory dir, String name) async =>
    File('${dir.path}/$name')..writeAsStringSync('bytes of $name');

// a chat with every kind of row a chat can leave: text, a photo, a file, a
// poll with a vote, a reaction, a pin and an edit on their way out, a file
// coming in slices, a held cipher, search words, the shield's note, a
// vouch, a group seat, a signal session and identity, a wallpaper
Future<List<String>> _fill(MemDb db, String id, Directory dir) async {
  final photo = await _file(dir, '$id-photo.jpg');
  final doc = await _file(dir, '$id-doc.pdf');
  final wall = await _file(dir, '$id-wall.jpg');
  var n = 0;
  Future<int> msg(Map<String, Object?> m) => db.insert('messages', {
    'peer_id': id,
    'direction': 'in',
    'plaintext': '',
    'sent_at': 10 + n++,
    ...m,
  });
  final text = await msg({'msg_uid': '$id-1', 'plaintext': 'hello from $id'});
  await msg({'msg_uid': '$id-2', 'media_path': photo.path});
  await msg({
    'msg_uid': '$id-3',
    'file_path': doc.path,
    'file_name': 'doc.pdf',
    'direction': 'out',
  });
  await msg({'msg_uid': '$id-4', 'poll': '{"q":"x"}'});
  await db.insert('msg_fts', {'rowid': text, 'body': 'hello from $id'});
  await db.insert('reactions', {
    'msg_uid': '$id-1',
    'reactor': 'me',
    'emoji': 'y',
    'reacted_at': 1,
  });
  await db.insert('poll_votes', {
    'poll_uid': '$id-4',
    'voter': 'me',
    'choices': '[0]',
    'seq': 1,
    'at': 1,
  });
  await db.insert('pins_out', {
    'msg_uid': '$id-1',
    'peer_id': id,
    'pinned': 1,
    'at': 1,
  });
  await db.insert('edits_out', {
    'msg_uid': '$id-3',
    'peer_id': id,
    'new_text': 'edited',
    'at': 1,
  });
  await db.insert('frames_out', {
    'msg_uid': '$id-gone',
    'kind': 'unsend',
    'peer_id': id,
    'body': '',
    'at': 1,
  });
  await db.insert('media_wants', {
    'media_id': '$id-slices',
    'peer_id': id,
    'total': 3,
    'can_resend': 1,
    'last_at': 1,
  });
  await db.insert('media_chunks', {
    'media_id': '$id-slices',
    'idx': 0,
    'slice': 'AAAA',
    'total': 3,
    'at': 1,
  });
  await db.insert('held_onion', {'peer_id': id, 'cipher': 'c-$id', 'at': 1});
  await db.insert('shield', {
    'halo_id': id,
    'headline': 'h',
    'lines': '[]',
    'at': 1,
  });
  await db.insert('vouches', {
    'halo_id': id,
    'voucher_id': 'someone-else',
    'created_at': 1,
  });
  await db.insert('group_members', {
    'group_id': 'g1',
    'halo_id': id,
    'joined_at': 1,
  });
  await db.insert('sessions', {
    'address': id,
    'device_id': 1,
    'record': Uint8List.fromList([1, 2, 3]),
  });
  await db.insert('peer_identities', {
    'address': id,
    'identity_key': Uint8List.fromList([5, 1]),
  });
  await db.update(
    'contacts',
    {'atmosphere': 'image:${wall.path}'},
    where: 'halo_id = ?',
    whereArgs: [id],
  );
  return [photo.path, doc.path, wall.path];
}

// an anonymous chat's own store: its registration, his session and key
Future<void> _fillAnonStore(MemDb db) async {
  await db.insert('dev_signal_meta', {'k': 'regId', 'v': '77'});
  await db.insert('dev_sessions', {
    'address': _dev,
    'device_id': 1,
    'record': Uint8List.fromList([7, 7, 7]),
  });
  await db.insert('dev_peer_identities', {
    'address': _dev,
    'identity_key': Uint8List.fromList([5, 7]),
  });
}

Map<String, int> _anonStore(MemDb db) => {
  for (final t in kSignalTables)
    if (db.rows('$kDevSignalPrefix$t').isNotEmpty)
      t: db.rows('$kDevSignalPrefix$t').length,
};

// every row anywhere that names [id], table by table
Map<String, int> _named(MemDb db, String id) {
  final out = <String, int>{};
  const cols = {
    'contacts': ['halo_id'],
    'messages': ['peer_id'],
    'pins_out': ['peer_id'],
    'edits_out': ['peer_id'],
    'frames_out': ['peer_id'],
    'media_wants': ['peer_id'],
    'held_onion': ['peer_id'],
    'shield': ['halo_id'],
    'vouches': ['halo_id', 'voucher_id'],
    'group_members': ['halo_id'],
    'sessions': ['address'],
    'peer_identities': ['address'],
  };
  for (final e in cols.entries) {
    final n = db
        .rows(e.key)
        .where((r) => e.value.any((c) => r[c] == id))
        .length;
    if (n > 0) out[e.key] = n;
  }
  // and what hangs off its messages
  final uids = {'$id-1', '$id-2', '$id-3', '$id-4', '$id-slices'};
  for (final (table, col) in const [
    ('reactions', 'msg_uid'),
    ('poll_votes', 'poll_uid'),
    ('media_chunks', 'media_id'),
    ('polls_gone', 'uid'),
  ]) {
    final n = db.rows(table).where((r) => uids.contains(r[col])).length;
    if (n > 0) out[table] = n;
  }
  final words = db
      .rows('msg_fts')
      .where((r) => (r['body'] as String).contains(id))
      .length;
  if (words > 0) out['msg_fts'] = words;
  return out;
}

// the everyday or a decoy's database, as the session reaches it
class _Db implements HaloDb {
  _Db(this.mem, [this.container = HaloContainer.everyday]);

  final MemDb mem;
  @override
  final HaloContainer container;
  ({Map<String, bool> people, Set<String> groups}) held = (
    people: {},
    groups: {},
  );

  @override
  DevChat get devChat => DevChat(() async => mem, shred: (_) async {});

  @override
  SupportChats get support => SupportChats(() async => mem);

  @override
  Future<List<Map<String, Object?>>> contacts() =>
      mem.query('contacts', where: 'accepted = ?', whereArgs: [1]);

  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async {
    final out = <String, Map<String, Object?>>{};
    for (final r in mem.rows('messages')) {
      if (r['group_id'] != null) continue;
      final id = r['peer_id'] as String;
      if ((out[id]?['id'] as int? ?? 0) < (r['id'] as int)) out[id] = r;
    }
    return out;
  }

  @override
  Future<int> pendingRequestCount() async => 0;

  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      held;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late int clock;
  late List<String> shredded;

  DevChat chatOf(MemDb db) => DevChat(
    () async => db,
    shred: (p) async {
      shredded.add(p);
      File(p).deleteSync();
    },
    now: () => clock,
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dev_chat_db');
    clock = 1000;
    shredded = [];
    useDevKeysForTest([_m1]);
  });

  tearDown(() {
    useDevKeysForTest(null);
    dir.deleteSync(recursive: true);
  });

  group('the seed', () {
    test(
      'a new database has the row fresh, pinned, for the current key',
      () async {
        final db = await _fresh(now: 7);
        final r = (await chatOf(db).load())!;
        expect(r.state, DevState.fresh);
        expect(r.keyId, 'm1');
        expect(r.pinned, isTrue);
        expect(r.muted, isFalse);
        expect(r.archived, isFalse);
        expect(r.createdAt, 7);
        expect(r.startedAt, isNull);
        expect(r.anonId, isNull);
        expect(r.chatId, _dev);
        expect(r.key, same(_m1));
        // nothing of the chat exists yet: no contact row, so nothing at boot
        // subscribes for it, and no message
        expect(db.rows('contacts'), isEmpty);
        expect(db.rows('messages'), isEmpty);
        expect(db.rows('sessions'), isEmpty);
      },
    );

    test('an upgrade seeds it too, and leaves every chat alone', () async {
      final db = _v53();
      await _contact(db, _other);
      await _fill(db, _other, dir);
      final before = {
        for (final t in ['contacts', 'messages', 'reactions', 'sessions'])
          t: db.rows(t),
      };
      expect(db.has('devchat'), isFalse);
      await devChatTables(db, now: 9);
      expect((await chatOf(db).load())!.state, DevState.fresh);
      for (final e in before.entries) {
        expect(db.rows(e.key), e.value, reason: e.key);
      }
    });

    test('a seed never writes over the row', () async {
      final db = await _fresh();
      final chat = chatOf(db);
      await chat.setMuted(true);
      expect(await chat.begin(_m1), isTrue);
      final was = db.rows('devchat');
      for (final keys in [
        [_m1],
        [_m2, _m1old],
        <DevKey>[],
      ]) {
        useDevKeysForTest(keys);
        await devChatTables(db, now: 99);
        await devChatTables(db);
        expect(db.rows('devchat'), was);
      }
      expect(db.log.where((l) => l.startsWith('replace:devchat')), isEmpty);
    });

    test('with no key the table is seeded and nothing shows', () async {
      useDevKeysForTest(const []);
      final db = await _fresh();
      final chat = chatOf(db);
      final r = (await chat.load())!;
      expect(r.state, DevState.fresh);
      expect(r.keyId, '');
      expect(r.key, isNull);
      expect(r.chatId, isNull);
      expect(devRowOf(r), isNull);
      expect(await chat.writeToMarios(), isNull);
      expect(await chat.begin(_m1), isFalse);
      expect(db.rows('contacts'), isEmpty);
      // the key the next build pins lights it up
      useDevKeysForTest([_m1]);
      expect(devRowOf(await chat.load())!.chatId, _dev);
    });

    test('a state this build does not know reads as gone', () {
      expect(devStateOf('fresh'), DevState.fresh);
      expect(devStateOf('anon'), DevState.anon);
      expect(devStateOf('later'), DevState.gone);
      expect(devStateOf(null), DevState.gone);
    });
  });

  group('the first send', () {
    test('three words: the pinned key, its bundle, and the flags set while '
        'fresh', () async {
      final db = await _fresh();
      final chat = chatOf(db);
      expect(await chat.setMuted(true), isTrue);
      expect(await chat.setArchived(true), isTrue);
      expect(await chat.setPinned(false), isTrue);
      expect(db.rows('contacts'), isEmpty);
      clock = 5000;
      expect(await chat.begin(_m1), isTrue);
      final c = db.rows('contacts').single;
      expect(c['halo_id'], _dev);
      expect(c['xpub'], _m1.xPub);
      expect(c['onion'], '');
      expect(c['peer_bundle'], _m1.bundle);
      expect(c['accepted'], 1);
      expect(c['verified'], 1);
      expect(c['muted'], 1);
      expect(c['archived'], 1);
      expect(c['pinned'], 0);
      expect(c['first_seen'], 5000);
      final r = (await chat.load())!;
      expect(r.state, DevState.everyday);
      expect(r.keyId, 'm1');
      expect(r.startedAt, 5000);
      expect(r.anonId, isNull);
      // once is all
      expect(await chat.begin(_m1), isFalse);
      expect(await chat.begin(_m1, anon: _anon), isFalse);
    });

    test(
      'anonymous: the name is kept, the contact row has no bundle',
      () async {
        final db = await _fresh();
        final chat = chatOf(db);
        expect(await chat.begin(_m1, anon: _anon), isTrue);
        final c = db.rows('contacts').single;
        expect(c['xpub'], _m1.xPub);
        expect(c['peer_bundle'], isNull);
        expect(c['onion'], '');
        final r = (await chat.load())!;
        expect(r.state, DevState.anon);
        expect(r.anonId, 'made-for-this');
        expect(r.anonEdPriv, 'anon-ed-priv');
        expect(r.anonXPriv, 'anon-x-priv');
      },
    );

    test('refused, and nothing written: an old key, a key not pinned, a row '
        'naming another key, a name without keys, a deleted chat', () async {
      final db = await _fresh();
      final chat = chatOf(db);
      final was = db.rows('devchat');
      useDevKeysForTest([_m2, _m1old]);
      expect(await chat.begin(_m1old), isFalse);
      useDevKeysForTest([_m1]);
      expect(await chat.begin(_key('m1', 0x33)), isFalse);
      // the pinned key's id and xpub with another bundle
      expect(
        await chat.begin(
          DevKey(
            keyId: 'm1',
            threeWords: _m1.threeWords,
            xPub: _m1.xPub,
            bundle: 'bundle-else',
            fc: _m1.fc,
          ),
        ),
        isFalse,
      );
      expect(await chat.begin(_m2), isFalse);
      expect(
        await chat.begin(
          _m1,
          anon: const DevAnon(id: 'x', edPriv: '', xPriv: 'y'),
        ),
        isFalse,
      );
      await db.insert('contacts', {
        'halo_id': _dev,
        'onion': '',
        'xpub': _m2.xPub,
        'first_seen': 1,
        'last_seen': 1,
      });
      final row = db.rows('contacts');
      expect(await chat.begin(_m1), isFalse);
      expect(db.rows('contacts'), row);
      expect(db.rows('devchat'), was);
      await chat.delete();
      expect(await chat.begin(_m1), isFalse);
      expect(db.rows('contacts'), isEmpty);
    });

    test('flags: the row while fresh, the contact row once started, nothing '
        'once gone', () async {
      final db = await _fresh();
      final chat = chatOf(db);
      await chat.setMuted(true);
      expect(db.rows('devchat').single['muted'], 1);
      await chat.begin(_m1);
      expect(await chat.setArchived(true), isTrue);
      expect(await chat.setMuted(false), isTrue);
      expect(db.rows('contacts').single['archived'], 1);
      expect(db.rows('contacts').single['muted'], 0);
      expect(db.rows('devchat').single['archived'], 0);
      await chat.delete();
      final gone = db.rows('devchat');
      expect(await chat.setMuted(true), isFalse);
      expect(await chat.setPinned(true), isFalse);
      expect(db.rows('devchat'), gone);
      expect(db.rows('contacts'), isEmpty);
    });
  });

  group('delete', () {
    for (final anon in [false, true]) {
      test('deleted means gone: every row of it and its files '
          '(${anon ? 'anonymous' : 'three words'})', () async {
        final db = await _fresh();
        final chat = chatOf(db);
        await _contact(db, _other);
        final keep = await _fill(db, _other, dir);
        expect(await chat.begin(_m1, anon: anon ? _anon : null), isTrue);
        final files = await _fill(db, _dev, dir);
        if (anon) await _fillAnonStore(db);
        final theirs = {
          for (final t in [
            'contacts',
            'messages',
            'reactions',
            'poll_votes',
            'pins_out',
            'edits_out',
            'frames_out',
            'media_wants',
            'media_chunks',
            'held_onion',
            'msg_fts',
            'shield',
            'vouches',
            'group_members',
            'sessions',
            'peer_identities',
          ])
            t: [
              for (final r in db.rows(t))
                if (!r.values.any((v) => '$v'.contains(_dev))) r,
            ],
        };
        expect(_named(db, _dev), hasLength(greaterThan(10)));
        expect(_anonStore(db), anon ? hasLength(3) : isEmpty);
        await chat.delete();
        expect(_named(db, _dev), isEmpty);
        expect(_anonStore(db), isEmpty);
        for (final e in theirs.entries) {
          expect(db.rows(e.key), e.value, reason: e.key);
        }
        expect(_named(db, _other), isNotEmpty);
        // the files it named are shredded, nobody else's
        expect(shredded..sort(), files..sort());
        for (final f in keep) {
          expect(File(f).existsSync(), isTrue);
        }
        final r = (await chat.load())!;
        expect(r.state, DevState.gone);
        expect(r.anonId, isNull);
        expect(r.anonEdPriv, isNull);
        expect(r.anonXPriv, isNull);
        expect(r.startedAt, isNull);
        expect(r.chatId, isNull);
        expect(devRowOf(r), isNull);
      });
    }

    test(
      'it stays gone: restarts, every migration again, a new key list',
      () async {
        for (final start in [null, false, true]) {
          useDevKeysForTest([_m1]);
          final db = await _fresh();
          final chat = chatOf(db);
          if (start != null) await chat.begin(_m1, anon: start ? _anon : null);
          await chat.delete();
          for (final keys in [
            [_m1],
            [_m2, _m1old],
            [_m2, _m1retired],
            <DevKey>[],
          ]) {
            useDevKeysForTest(keys);
            await devChatTables(db);
            await devChatTables(db, now: 1);
            final r = await chatOf(db).load();
            expect(r!.state, DevState.gone, reason: '$start $keys');
            expect(devRowOf(r), isNull);
            expect(await chatOf(db).begin(_m2), isFalse);
          }
          expect(db.rows('contacts'), isEmpty);
          expect(
            db.rows('messages').where((m) => isDevChat(m['peer_id'] as String)),
            isEmpty,
          );
        }
      },
    );

    test('one transaction: a failure leaves everything as it was', () async {
      final db = await _fresh();
      final chat = chatOf(db);
      await chat.begin(_m1, anon: _anon);
      await _fill(db, _dev, dir);
      final before = {
        for (final t in ['devchat', 'contacts', 'messages', 'reactions'])
          t: db.rows(t),
      };
      db.failOn = 'delete:contacts';
      await expectLater(chat.delete(), throwsStateError);
      for (final e in before.entries) {
        expect(db.rows(e.key), e.value, reason: e.key);
      }
      expect(shredded, isEmpty);
      expect((await chat.load())!.state, DevState.anon);
      // and freed pages go back to how they were
      expect(db.log.last, 'PRAGMA secure_delete = 0');
      db.failOn = null;
      await chat.delete();
      expect((await chat.load())!.state, DevState.gone);
    });

    test('freed pages are zeroed while it runs', () async {
      final db = await _fresh();
      final chat = chatOf(db);
      await chat.begin(_m1);
      await _fill(db, _dev, dir);
      db.log.clear();
      await chat.delete();
      final on = db.log.indexOf('PRAGMA secure_delete = 1');
      final off = db.log.indexOf('PRAGMA secure_delete = 0');
      final first = db.log.indexWhere((l) => l.startsWith('delete:'));
      final last = db.log.lastIndexWhere((l) => l.startsWith('replace:'));
      expect(on, isNonNegative);
      expect(on, lessThan(first));
      expect(off, greaterThan(last));
      expect(db.log.last, 'PRAGMA wal_checkpoint(TRUNCATE)');
    });

    test('only the settings row brings it back, fresh, on its tap', () async {
      final db = await _fresh(now: 1);
      final chat = chatOf(db);
      await chat.begin(_m1, anon: _anon);
      await chat.setMuted(true);
      // not deleted: the chat as it is
      expect(await chat.writeToMarios(), _dev);
      expect((await chat.load())!.state, DevState.anon);
      await chat.delete();
      clock = 8000;
      expect(await chat.writeToMarios(), _dev);
      final r = (await chat.load())!;
      expect(r.state, DevState.fresh);
      expect(r.pinned, isTrue);
      expect(r.muted, isFalse);
      expect(r.archived, isFalse);
      expect(r.anonId, isNull);
      expect(r.createdAt, 8000);
      expect(r.startedAt, isNull);
      expect(db.rows('contacts'), isEmpty);
      // a fresh one again: it can start either way
      expect(await chat.begin(_m1), isTrue);
      // after a rotation it talks to the new key
      await chat.delete();
      useDevKeysForTest([_m2, _m1old]);
      expect(await chat.writeToMarios(), 'dev:m2');
      expect((await chat.load())!.keyId, 'm2');
      // with no key there is nothing to write to, and it stays gone
      await chat.delete();
      useDevKeysForTest(const []);
      expect(await chat.writeToMarios(), isNull);
      expect((await chat.load())!.state, DevState.gone);
    });
  });

  group('the home row', () {
    DevChatRow row(DevState s, {String key = 'm1', bool anon = false}) =>
        DevChatRow(
          state: s,
          keyId: key,
          muted: true,
          createdAt: 1,
          anonId: anon ? 'a' : null,
        );

    test('fresh: the welcome, no time, no unread count, pinned', () {
      final d = devRowOf(row(DevState.fresh))!;
      expect(d.chatId, _dev);
      expect(d.keyId, 'm1');
      expect(d.preview, isNull);
      expect(d.when, isNull);
      expect(d.unread, 0);
      expect(d.pinned, isTrue);
      expect(d.muted, isTrue);
      expect(d.started, isFalse);
      expect(d.anonymous, isFalse);
      expect(d.status, DevKeyStatus.current);
    });

    test('none when gone, on the developer phone, or with no key', () {
      expect(devRowOf(null), isNull);
      expect(devRowOf(row(DevState.gone)), isNull);
      expect(devRowOf(row(DevState.fresh), devMode: true), isNull);
      expect(devRowOf(row(DevState.everyday), devMode: true), isNull);
      useDevKeysForTest(const []);
      expect(devRowOf(row(DevState.fresh)), isNull);
    });

    test('started: the contact row speaks for it', () {
      final when = DateTime(2026, 9, 27);
      final d = devRowOf(
        row(DevState.anon, anon: true),
        contact: {'muted': 0, 'archived': 1, 'pinned': 0, 'unread': 3},
        preview: 'thanks',
        when: when,
      )!;
      expect(d.chatId, _dev);
      expect(d.preview, 'thanks');
      expect(d.when, when);
      expect(d.unread, 3);
      expect(d.muted, isFalse);
      expect(d.archived, isTrue);
      expect(d.pinned, isFalse);
      expect(d.started, isTrue);
      expect(d.anonymous, isTrue);
    });

    test('a rotation: a fresh row moves to the new key, a started chat keeps '
        'its own', () {
      useDevKeysForTest([_m2, _m1old]);
      expect(devRowOf(row(DevState.fresh))!.chatId, 'dev:m2');
      final d = devRowOf(row(DevState.everyday))!;
      expect(d.chatId, _dev);
      expect(d.status, DevKeyStatus.previous);
      useDevKeysForTest([_m2, _m1retired]);
      expect(devRowOf(row(DevState.everyday))!.status, DevKeyStatus.retired);
      // a key gone from the list reads as retired: the chat stays readable
      useDevKeysForTest([_m2]);
      final lost = devRowOf(row(DevState.everyday))!;
      expect(lost.chatId, _dev);
      expect(lost.status, DevKeyStatus.retired);
    });

    test('developer mode takes the private key of a working pinned key', () {
      useDevKeysForTest(const []);
      expect(devModeOf(_m1.xPub), isFalse);
      expect(devModeOf(''), isFalse);
      useDevKeysForTest([_m1]);
      expect(devModeOf(_m1.xPub), isTrue);
      expect(devModeOf(_m1.xPub.toUpperCase()), isTrue);
      expect(devModeOf(_m2.xPub), isFalse);
      useDevKeysForTest([_m2, _m1old]);
      expect(devModeOf(_m1.xPub), isTrue);
      useDevKeysForTest([_m2, _m1retired]);
      expect(devModeOf(_m1.xPub), isFalse);
    });
  });

  group('beside the contacts', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => dir.path,
          );
    });

    test('home: the row of its own, never one of the contacts', () async {
      final mem = await _fresh();
      await _contact(mem, _other);
      final db = _Db(mem);
      useDatabasesForTest(db, Session(db));
      final app = AppState();
      await app.refreshContacts();
      expect(app.contacts.map((c) => c.haloId), [_other]);
      expect(app.devRow!.chatId, _dev);
      expect(app.devRow!.started, isFalse);
      expect(app.devRow!.preview, isNull);
      // started, with a reply
      await chatOf(mem).begin(_m1);
      await mem.insert('messages', {
        'peer_id': _dev,
        'direction': 'in',
        'plaintext': 'thanks, fixed',
        'sent_at': 42,
      });
      await app.refreshContacts();
      expect(app.contacts.map((c) => c.haloId), [_other]);
      expect(app.devRow!.started, isTrue);
      expect(app.devRow!.preview, 'thanks, fixed');
      expect(app.devRow!.when, DateTime.fromMillisecondsSinceEpoch(42));
      // the developer's own phone shows none
      app.myXPub = _m1.xPub;
      await app.refreshContacts();
      expect(app.devRow, isNull);
      expect(app.contacts.map((c) => c.haloId), [_other]);
      // deleted: none either
      app.myXPub = '';
      await chatOf(mem).delete();
      await app.refreshContacts();
      expect(app.devRow, isNull);
      expect(app.contacts.map((c) => c.haloId), [_other]);
    });

    test(
      'a decoy shows its own fresh row, even on the developer phone',
      () async {
        final everyday = await _fresh();
        await chatOf(everyday).delete();
        final decoy = _Db(await _fresh(), HaloContainer.decoy);
        useDatabasesForTest(_Db(everyday), Session(decoy));
        final app = AppState()..myXPub = _m1.xPub;
        await app.refreshContacts();
        expect(app.devRow!.chatId, _dev);
        expect(app.devRow!.started, isFalse);
      },
    );

    test('a row that will not read is no row, and home still shows', () async {
      final mem = _v53();
      await _contact(mem, _other);
      final db = _Db(mem);
      useDatabasesForTest(db, Session(db));
      final app = AppState();
      await app.refreshContacts();
      expect(app.devRow, isNull);
      expect(app.contacts.map((c) => c.haloId), [_other]);
    });

    test('a vault never holds it, whatever its rows say', () async {
      final primary = _Db(await _fresh(now: 1));
      final vault = _Db(await _fresh(now: 2), HaloContainer.vault)
        ..held = (people: {_dev: true, _other: true}, groups: {});
      final s = await Session.withVault(primary, vault);
      expect(s.isHidden(_other), isTrue);
      expect(s.isHidden(_dev), isFalse);
      // its row is the primary's, never the vault's own
      expect((await s.devChat.load())!.createdAt, 1);
    });
  });

  // read off the source: the schema and the hide loop
  test('v54 seeds it on create and on upgrade, and the hide loop skips it', () {
    final src = File('lib/main.dart').readAsStringSync();
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), greaterThanOrEqualTo(55));
    final create = src.indexOf('onCreate: (db, _) async {');
    final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
    expect(create, isNonNegative);
    expect(upgrade, greaterThan(create));
    expect(
      src.substring(create, upgrade),
      contains('await _devChatTables(db);'),
    );
    expect(
      RegExp(
        r'if \(oldV < 54\) \{[^}]*await _devChatTables\(db\);',
      ).hasMatch(src.substring(upgrade)),
      isTrue,
    );
    expect(
      src,
      contains('if (isDevChat(c.id) || !await m.hideable(c)) continue;'),
    );
  });

  test('v55 makes the anonymous store on create and on upgrade, the same '
      'tables as the everyday one', () {
    final src = File('lib/main.dart').readAsStringSync();
    final create = src.indexOf('onCreate: (db, _) async {');
    final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
    expect(
      src.substring(create, upgrade),
      contains('await _devSignalTables(db);'),
    );
    expect(
      RegExp(
        r'if \(oldV < 55\) \{[^}]*await _devSignalTables\(db\);',
      ).hasMatch(src.substring(upgrade)),
      isTrue,
    );
    // wrapped: a throw in a migration and the app never opens again
    final wrap = src.indexOf('Future<void> _devSignalTables(Database db)');
    final body = src.substring(wrap, src.indexOf('\n}\n', wrap));
    expect(body, contains('try {'));
    expect(body, contains('_signalTables(db, prefix: kDevSignalPrefix)'));
    final tables = src.substring(
      src.indexOf('Future<void> _signalTables('),
      src.indexOf('Future<void> _devSignalTables('),
    );
    for (final t in kSignalTables) {
      expect(tables, contains('CREATE TABLE IF NOT EXISTS \${prefix}$t ('));
    }
    // and the stand-in database has both sets, alike
    final db = MemDb();
    for (final t in kSignalTables) {
      expect(db.has(t), isTrue);
      expect(db.has('$kDevSignalPrefix$t'), isTrue);
    }
  });

  test('without the anonymous store, which a migration could not make, a '
      'delete still deletes', () async {
    final db = MemDb(
      except: {for (final t in kSignalTables) '$kDevSignalPrefix$t'},
    );
    await devChatTables(db, now: 1);
    final chat = chatOf(db);
    expect(await chat.begin(_m1), isTrue);
    await _fill(db, _dev, dir);
    await chat.delete();
    expect((await chat.load())!.state, DevState.gone);
    expect(_named(db, _dev), isEmpty);
  });

  group('what leaves the phone', () {
    // a copy of a database with an anonymous chat running, and everything
    // else a chat leaves
    Future<MemDb> copy() async {
      final db = await _fresh();
      await _contact(db, _other);
      await _fill(db, _other, dir);
      expect(await chatOf(db).begin(_m1, anon: _anon), isTrue);
      await _fill(db, _dev, dir);
      await _fillAnonStore(db);
      return db;
    }

    Map<String, String> rest(MemDb db) => {
      for (final t in [
        'contacts',
        'messages',
        'reactions',
        'poll_votes',
        'pins_out',
        'edits_out',
        'media_wants',
        'media_chunks',
        'held_onion',
        'msg_fts',
        'shield',
        'vouches',
        'group_members',
        ...kSignalTables,
      ])
        t: '${db.rows(t)}',
    };

    test(
      'the made name and its store stay behind, all else goes along',
      () async {
        final db = await copy();
        final was = rest(db);
        await db.transaction(scrubDevAnon);
        expect(_anonStore(db), isEmpty);
        final r = (await chatOf(db).load())!;
        expect(r.anonId, isNull);
        expect(r.anonEdPriv, isNull);
        expect(r.anonXPriv, isNull);
        // the chat itself goes along as it was
        expect(r.state, DevState.anon);
        expect(r.keyId, 'm1');
        expect(r.startedAt, isNotNull);
        expect(rest(db), was);
        // nothing of the made name is anywhere in the copy
        final all = [for (final t in _tablesOf(db)) '${db.rows(t)}'].join();
        for (final secret in [_anon.edPriv, _anon.xPriv, _anon.id]) {
          expect(all, isNot(contains(secret)));
        }
      },
    );

    test(
      'where it lands the chat reads, and sends and hears nothing',
      () async {
        final db = await copy();
        await db.transaction(scrubDevAnon);
        final chat = chatOf(db);
        final r = (await chat.load())!;
        expect(r.nameless, isTrue);
        final row = devRowOf(r)!;
        expect(row.started, isTrue);
        expect(row.anonymous, isTrue);
        // the wire refuses it every way, and it has no store
        for (final way in [
          DevGate.relayWay(r, _m1, 'c', (_) => true),
          DevGate.firstContactWay(r, _m1, _m1, 'c', (_) => true),
          DevGate.listenWay(r, _m1),
        ]) {
          expect(way, DevWay.refused);
        }
        expect(DevGate.roomOk(r, _m1, ''), isFalse);
        final lane = DevLane(chat: chat.load, open: () async => db);
        expect(await lane.seat(_dev), isNull);
        await expectLater(
          lane.encrypt(_dev, 'halo/1:{"m":"hi"}'),
          throwsStateError,
        );
        // it can be deleted, and a new one started with a new name
        await chat.delete();
        expect((await chat.load())!.state, DevState.gone);
        await chat.writeToMarios();
        expect(
          await chat.begin(
            _m1,
            anon: const DevAnon(id: 'another', edPriv: 'e2', xPriv: 'x2'),
          ),
          isTrue,
        );
        expect((await chat.load())!.nameless, isFalse);
      },
    );

    test('with three words there is nothing of it to leave behind', () async {
      final db = await _fresh();
      expect(await chatOf(db).begin(_m1), isTrue);
      await _fill(db, _dev, dir);
      final was = {for (final t in _tablesOf(db)) t: '${db.rows(t)}'};
      await db.transaction(scrubDevAnon);
      expect({for (final t in _tablesOf(db)) t: '${db.rows(t)}'}, was);
      expect((await chatOf(db).load())!.state, DevState.everyday);
    });

    test('a table that is not there holds nothing, one that will not clear '
        'fails the copy', () async {
      final old = MemDb(
        except: {
          'devchat',
          for (final t in kSignalTables) '$kDevSignalPrefix$t',
        },
      );
      await old.transaction(scrubDevAnon);
      final db = await copy();
      db.failOn = 'delete:dev_sessions';
      await expectLater(db.transaction(scrubDevAnon), throwsStateError);
      // the copy is left as it was, and does not go
      expect(_anonStore(db), hasLength(3));
      expect((await chatOf(db).load())!.anonXPriv, _anon.xPriv);
    });

    // the checks above would catch the scrub gone half way
    test('a scrub that forgets a part is caught', () async {
      for (final half in [
        (DatabaseExecutor t) async {
          for (final n in kSignalTables) {
            await t.delete('$kDevSignalPrefix$n');
          }
        },
        (DatabaseExecutor t) async {
          await t.update('devchat', {'anon_x_priv': null});
        },
      ]) {
        final db = await copy();
        await db.transaction(half);
        final r = (await chatOf(db).load())!;
        final left = [
          ..._anonStore(db).keys,
          if (r.anonId != null) 'anon_id',
          if (r.anonEdPriv != null) 'anon_ed_priv',
          if (r.anonXPriv != null) 'anon_x_priv',
        ];
        expect(left, isNotEmpty);
      }
    });
  });
}

Iterable<String> _tablesOf(MemDb db) => [
  for (final t in [
    'devchat',
    'contacts',
    'messages',
    'reactions',
    ...kSignalTables,
    for (final n in kSignalTables) '$kDevSignalPrefix$n',
  ])
    if (db.has(t)) t,
];
