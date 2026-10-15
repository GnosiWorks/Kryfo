// SPDX-License-Identifier: GPL-3.0-or-later
// albums in the database, on the host's sqlite: the step to 81 adds their
// columns and keeps every row, a row keeps its place in its album, and an
// album burns as one, ours from the first clock set, theirs from the first
// read, an item that lands late taking the album's clock
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart';
import 'package:kryfo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlite_channel.dart';

const _alice = 'amber-otter-lake';
const _bob = 'brisk-cedar-moon';
const _id = '0123456789abcdef';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('album_store');
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': '0e' * 32,
    });
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    sql?.uninstall();
    m.setMockMethodCallHandler(paths, null);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  bool skip() {
    if (sql != null) return false;
    markTestSkipped('no sqlite on this host');
    return true;
  }

  Future<Map<String, Object?>> row(HaloDb db, String uid) async =>
      (await db.sentMediaRow(uid))!;

  Future<void> theirs(
    HaloDb db,
    String uid,
    int i, {
    String from = _alice,
    int n = 3,
    int? burnSecs = 30,
  }) => db.saveMessage(
    from,
    'in',
    i == 0 ? 'look' : '',
    msgUid: uid,
    mediaPath: '/m/$uid.jpg',
    burnSecs: burnSecs,
    album: AlbumTag(_id, n, i),
  );

  test('the step to 81 adds the album and keeps every row', () async {
    if (skip()) return;
    final db = HaloDb();
    final raw = await db.open();
    expect(await raw.getVersion(), 81);
    await db.saveMessage(_alice, 'in', 'before', msgUid: 'u-old');
    // the file as 80 left it: no album columns, no index
    await raw.execute('DROP INDEX idx_messages_album');
    for (final c in ['album_i', 'album_n', 'album_id']) {
      await raw.execute('ALTER TABLE messages DROP COLUMN $c');
    }
    await raw.setVersion(80);
    await db.close();

    final again = HaloDb();
    final up = await again.open();
    expect(await up.getVersion(), 81);
    final cols = [
      for (final c in await up.rawQuery("PRAGMA table_info('messages')"))
        c['name'],
    ];
    expect(cols, containsAll(['album_id', 'album_n', 'album_i']));
    final idx = await up.rawQuery(
      "SELECT name FROM sqlite_master WHERE name = 'idx_messages_album'",
    );
    expect(idx, hasLength(1));
    final old = await row(again, 'u-old');
    expect(old['plaintext'], 'before');
    expect(AlbumTag.ofRow(old), isNull);
    // and a new row keeps its place
    await theirs(again, 'u1', 1);
    expect(AlbumTag.ofRow(await row(again, 'u1')), const AlbumTag(_id, 3, 1));
    await again.close();
  });

  test('a row keeps its place, and the album is known by sender', () async {
    if (skip()) return;
    final db = HaloDb();
    await db.open();
    expect(await db.albumHeld(_id, _alice, null), isNull);
    await theirs(db, 'u2', 2);
    await theirs(db, 'u0', 0);
    expect(AlbumTag.ofRow(await row(db, 'u2')), const AlbumTag(_id, 3, 2));
    final held = (await db.albumHeld(_id, _alice, null))!;
    expect(held.n, 3);
    expect(held.taken, {0, 2});
    expect(await db.albumHeld(_id, _bob, null), isNull);
    expect(await db.albumHeld(_id, _alice, 'g1'), isNull);
    await db.close();
  });

  test(
    'a late item never takes a clock that leaves it under the grace',
    () async {
      if (skip()) return;
      final db = HaloDb();
      await db.open();
      for (var i = 0; i < 2; i++) {
        await db.saveMessage(
          _alice,
          'out',
          '',
          msgUid: 'g$i',
          mediaPath: '/m/g$i.jpg',
          burnSecs: 60,
          sent: 0,
          album: AlbumTag(_id, 2, i),
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.setMsgBurnAt('g0', now + 1000);
      final at = await db.setMsgBurnAt('g1', now + 60000);
      expect(at, greaterThanOrEqualTo(now + kAlbumBurnGrace.inMilliseconds));
      expect(at, lessThan(now + 60000));
      await db.close();
    },
  );

  test('one deleted by hand leaves its album open to what comes', () async {
    if (skip()) return;
    final db = HaloDb();
    await db.open();
    await theirs(db, 'd0', 0, burnSecs: null);
    await db.deleteMessage('d0');
    expect(await db.goneFrom(goneKey(_alice), 'd0'), isTrue);
    expect(await db.goneFrom(goneKey(_alice), albumGoneUid(_id)), isFalse);
    await theirs(db, 'c0', 0, burnSecs: null);
    await db.clearConversation(_alice);
    expect(await db.goneFrom(goneKey(_alice), albumGoneUid(_id)), isFalse);
    await db.close();
  });

  test(
    'an album that burns is remembered, so nothing joins it after',
    () async {
      if (skip()) return;
      final db = HaloDb();
      await db.open();
      await theirs(db, 'b0', 0, burnSecs: null);
      await db.setMsgBurnAt('b0', DateTime.now().millisecondsSinceEpoch - 1000);
      await db.purgeExpired();
      expect(await db.messageExists('b0'), isFalse);
      expect(await db.goneFrom(goneKey(_alice), albumGoneUid(_id)), isTrue);
      expect(await db.goneFrom(goneKey(_bob), albumGoneUid(_id)), isFalse);
      await db.close();
    },
  );

  test('ours burns on the first clock set', () async {
    if (skip()) return;
    final db = HaloDb();
    await db.open();
    for (var i = 0; i < 3; i++) {
      await db.saveMessage(
        _alice,
        'out',
        '',
        msgUid: 'o$i',
        mediaPath: '/m/o$i.jpg',
        burnSecs: 30,
        sent: 0,
        album: AlbumTag(_id, 3, i),
      );
    }
    await db.saveMessage(_alice, 'out', 'alone', msgUid: 'x', burnSecs: 30);
    const t = 1800000000000;
    expect(await db.setMsgBurnAt('o1', t), t);
    // a later item takes the album's clock, not its own
    expect(await db.setMsgBurnAt('o0', t + 4000), t);
    expect(await db.setMsgBurnAt('o2', t + 9000), t);
    for (final u in ['o0', 'o1', 'o2']) {
      expect((await row(db, u))['burn_at'], t, reason: u);
    }
    // one of no album keeps its own
    expect(await db.setMsgBurnAt('x', t + 9000), t + 9000);
    await db.close();
  });

  test('theirs is read as one and burns as one', () async {
    if (skip()) return;
    final db = HaloDb();
    await db.open();
    await theirs(db, 'a0', 0);
    await theirs(db, 'a1', 1);
    // another sender's album of the same id is another album
    await theirs(db, 'b0', 0, from: _bob);
    final lit = await db.lightReadBurns(['a0']);
    expect(lit.keys.toSet(), containsAll({'a0', 'a1'}));
    expect(lit['a1'], lit['a0']);
    expect((await row(db, 'a1'))['burn_at'], lit['a0']);
    expect((await row(db, 'b0'))['burn_at'], isNull);
    // the last item lands after the rest were read: it takes their clock
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await theirs(db, 'a2', 2);
    final late = await db.lightReadBurns(['a2']);
    expect(late['a2'], lit['a0']);
    expect((await row(db, 'a2'))['burn_at'], lit['a0']);
    await db.close();
  });
}
