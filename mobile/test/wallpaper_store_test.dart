// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's wallpaper photo and the default live in the container's own
// encrypted database: made on create and on the upgrade to 81, the last
// step. a photo lasts while its chat's atmosphere says photo: a chat
// deleted, or a built-in or the default picked, takes it. the default stays
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/jpeg_strip.dart' show jpegHasExif;
import 'package:kryfo/main.dart'
    show
        HaloDb,
        adoptWallpaperFiles,
        dropOrphanWallpapers,
        kOrphanWallpapers,
        kPhotoWall,
        wallKey,
        wallpaperTable;
import 'package:kryfo/vault_life.dart' show chatTables;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'sqlite_ffi.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _peer = 'someone-with-a-view';
const _other = 'someone-else';
const _group = 'g1walls00001';
final _photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3, 0xFF, 0xD9]);
final _beach = Uint8List.fromList([0xFF, 0xD8, 0xFF, 9, 9, 0xFF, 0xD9]);

Future<_Rows> _seeded() async {
  final db = _Rows(MemDb());
  for (final id in [_peer, _other]) {
    await db.mem.insert('contacts', {
      'halo_id': id,
      'onion': 'o',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
    });
  }
  await db.mem.insert('groups', {
    'group_id': _group,
    'name': 'night shift',
    'created_at': 1,
  });
  return db;
}

Future<String?> _atmo(_Rows db, String table, String col, String id) async {
  final r = await db.mem.query(
    table,
    columns: ['atmosphere'],
    where: '$col = ?',
    whereArgs: [id],
  );
  return r.isEmpty ? null : r.first['atmosphere'] as String?;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final src = File('lib/main.dart').readAsStringSync();
  final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
  final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));
  final create = src.substring(
    src.indexOf('onCreate: (db, _) async {'),
    upgrade,
  );

  test('made on create, and on the upgrade to 81 after every older step', () {
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), greaterThanOrEqualTo(81));
    expect(create, contains('await wallpaperTable(db);'));
    expect(
      RegExp(
        r'if \(oldV < 81\) \{[^}]*await wallpaperTable\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    final at81 = steps.indexOf('if (oldV < 81) {');
    for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(steps)) {
      if (int.parse(m.group(1)!) < 81) expect(m.start, lessThan(at81));
    }
    // it moves with a chat into the vault and back
    expect(chatTables, contains('wallpapers'));
  });

  test('a photo is set with its chat saying so, and a built-in or the '
      'default drops it', () async {
    final db = await _seeded();
    await db.setChatPhoto(_peer, _photo);
    expect(await _atmo(db, 'contacts', 'halo_id', _peer), kPhotoWall);
    expect((await db.wallpaperRow(_peer))?.photo, _photo);
    // a new one takes its place
    await db.setChatPhoto(_peer, _beach);
    expect((await db.wallpaperRow(_peer))?.photo, _beach);
    expect(await db.mem.query('wallpapers'), hasLength(1));
    await db.setChatAtmosphere(_peer, 'rain');
    expect(await _atmo(db, 'contacts', 'halo_id', _peer), 'rain');
    expect(await db.wallpaperRow(_peer), isNull);
    await db.setChatPhoto(_peer, _photo);
    await db.setChatAtmosphere(_peer, null);
    expect(await _atmo(db, 'contacts', 'halo_id', _peer), isNull);
    expect(await db.wallpaperRow(_peer), isNull);
  });

  test('a group\'s photo is kept under its own key, apart from a person '
      'of the same id', () async {
    final db = await _seeded();
    await db.setChatPhoto(_group, _photo, group: true);
    expect(await _atmo(db, 'groups', 'group_id', _group), kPhotoWall);
    expect(wallKey(_group, group: true), 'group:$_group');
    expect((await db.wallpaperRow('group:$_group'))?.photo, _photo);
    expect(await db.wallpaperRow(_group), isNull);
  });

  test('the default is a row of its own, a built-in or a photo', () async {
    final db = await _seeded();
    expect(await db.wallpaperRow(''), isNull);
    await db.setDefaultWallpaper('dusk');
    expect(await db.wallpaperRow(''), (atmo: 'dusk', photo: null));
    await db.setDefaultWallpaper(kPhotoWall, _beach);
    expect((await db.wallpaperRow(''))?.photo, _beach);
    expect(await db.mem.query('wallpapers'), hasLength(1));
  });

  test('a chat delete clears its atmosphere, which is what takes the '
      'photo', () {
    final at = src.indexOf('  Future<void> deleteConversation(String haloId)');
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    expect(body, contains("'atmosphere': null,"));
  });

  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  Future<SqliteMem> chats() async {
    final db = SqliteMem.open()!;
    await db.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, atmosphere TEXT)',
    );
    await db.execute(
      'CREATE TABLE groups (group_id TEXT PRIMARY KEY, atmosphere TEXT)',
    );
    for (final id in [_peer, _other]) {
      await db.execute("INSERT INTO contacts VALUES ('$id', 'photo')");
    }
    await db.execute("INSERT INTO groups VALUES ('$_group', 'photo')");
    await wallpaperTable(db);
    for (final chat in [_peer, _other, 'group:$_group']) {
      await db.insert('wallpapers', {
        'chat': chat,
        'atmo': kPhotoWall,
        'photo': _photo,
      });
    }
    await db.insert('wallpapers', {'chat': '', 'atmo': 'rain'});
    return db;
  }

  Future<List<Object?>> walls(SqliteMem db) async => [
    for (final r in await db.rawQuery(
      'SELECT chat FROM wallpapers ORDER BY chat',
    ))
      r['chat'],
  ];

  test(
    'whatever clears a chat\'s photo mark takes the photo: a delete, a '
    'built-in, the default; the default and other chats keep theirs',
    () async {
      final db = await chats();
      // what a chat delete does to its row
      await db.execute(
        "UPDATE contacts SET atmosphere = NULL WHERE halo_id = '$_peer'",
      );
      expect(await walls(db), ['', 'group:$_group', _other]);
      // a photo kept as a photo stays
      await db.execute(
        "UPDATE contacts SET atmosphere = 'photo' WHERE halo_id = '$_other'",
      );
      expect(await walls(db), ['', 'group:$_group', _other]);
      await db.execute(
        "UPDATE contacts SET atmosphere = 'rain' WHERE halo_id = '$_other'",
      );
      expect(await walls(db), ['', 'group:$_group']);
      await db.execute("DELETE FROM groups WHERE group_id = '$_group'");
      expect(await walls(db), ['']);
    },
    skip: skip,
  );

  test('a contact row that goes takes its photo', () async {
    final db = await chats();
    await db.execute("DELETE FROM contacts WHERE halo_id = '$_peer'");
    expect(await walls(db), ['', 'group:$_group', _other]);
    await db.execute(
      "UPDATE groups SET atmosphere = NULL WHERE group_id = '$_group'",
    );
    expect(await walls(db), ['', _other]);
  }, skip: skip);

  test('a phone from 80 gets the table once, and a photo reads back byte '
      'for byte', () async {
    final db = SqliteMem.open()!;
    await db.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, atmosphere TEXT)',
    );
    await db.execute(
      'CREATE TABLE groups (group_id TEXT PRIMARY KEY, atmosphere TEXT)',
    );
    await db.execute("INSERT INTO contacts VALUES ('$_peer', NULL)");
    await wallpaperTable(db);
    await wallpaperTable(db);
    expect(await db.rawQuery('SELECT halo_id FROM contacts'), [
      {'halo_id': _peer},
    ]);
    await db.execute(
      "UPDATE contacts SET atmosphere = 'photo' WHERE halo_id = '$_peer'",
    );
    final big = Uint8List.fromList(List.generate(300000, (i) => i % 251));
    await db.insert('wallpapers', {
      'chat': _peer,
      'atmo': kPhotoWall,
      'photo': big,
    });
    final back = await db.rawQuery(
      'SELECT photo FROM wallpapers WHERE chat = ?',
      [_peer],
    );
    expect(back.single['photo'], big);
    await expectLater(
      db.execute("INSERT INTO wallpapers (chat, atmo) VALUES ('$_peer', 'x')"),
      throwsA(anything),
    );
  }, skip: skip);

  test('the photo files of before are taken in at the upgrade, cleaned, '
      'and handed back to be shredded; one that will not read leaves its '
      'chat on the default', () async {
    final docs = Directory.systemTemp.createTempSync('walls');
    addTearDown(() => docs.deleteSync(recursive: true));
    final dir = Directory('${docs.path}/wallpapers_v')..createSync();
    final gps = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();
    expect(jpegHasExif(gps), isTrue);
    final kept = File('${dir.path}/$_peer.jpg')..writeAsBytesSync(gps);
    final broken = File('${dir.path}/broken.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE1, 0, 9]);
    final db = SqliteMem.open()!;
    await db.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, atmosphere TEXT)',
    );
    await db.execute(
      'CREATE TABLE groups (group_id TEXT PRIMARY KEY, atmosphere TEXT)',
    );
    await db.insert('contacts', {
      'halo_id': _peer,
      'atmosphere': 'image:${kept.path}',
    });
    await db.insert('contacts', {
      'halo_id': _other,
      'atmosphere': 'image:${dir.path}/gone.jpg',
    });
    await db.insert('contacts', {'halo_id': 'plain', 'atmosphere': 'dusk'});
    await db.insert('groups', {
      'group_id': _group,
      'atmosphere': 'image:${broken.path}',
    });
    // another container's photo is not this one's to take
    final theirs = Directory('${docs.path}/wallpapers_d')..createSync();
    final decoyFile = File('${theirs.path}/d.jpg')..writeAsBytesSync(gps);
    await db.insert('contacts', {
      'halo_id': 'elsewhere',
      'atmosphere': 'image:${decoyFile.path}',
    });
    // a path nothing here wrote is never named for a shred
    await db.insert('contacts', {
      'halo_id': 'odd',
      'atmosphere': 'image:${docs.path}/notes.txt',
    });
    await wallpaperTable(db);
    final files = await adoptWallpaperFiles(db, dir.path);
    expect(files.toSet(), {kept.path, '${dir.path}/gone.jpg', broken.path});
    final row = await db.rawQuery(
      'SELECT photo FROM wallpapers WHERE chat = ?',
      [_peer],
    );
    final photo = row.single['photo']! as Uint8List;
    expect(jpegHasExif(photo), isFalse);
    expect(decoyFile.existsSync(), isTrue);
    expect(await db.rawQuery('SELECT halo_id, atmosphere FROM contacts'), [
      {'halo_id': _peer, 'atmosphere': kPhotoWall},
      {'halo_id': _other, 'atmosphere': null},
      {'halo_id': 'plain', 'atmosphere': 'dusk'},
      {'halo_id': 'elsewhere', 'atmosphere': null},
      {'halo_id': 'odd', 'atmosphere': null},
    ]);
    expect(await db.rawQuery('SELECT atmosphere FROM groups'), [
      {'atmosphere': null},
    ]);
    expect(await db.rawQuery('SELECT chat FROM wallpapers ORDER BY chat'), [
      {'chat': _peer},
    ]);
  }, skip: skip);

  test('the upgrade shreds what it took in once it is written, and not '
      'while a backup or a restore holds the folder', () {
    final at = steps.indexOf('if (oldV < 81) {');
    expect(
      steps.substring(at),
      contains('adopted = await adoptWallpaperFiles('),
    );
    final after = src.substring(
      src.indexOf('adopted = await adoptWallpaperFiles'),
    );
    final shred = after.indexOf('await shredFile(f);');
    expect(shred, greaterThan(0));
    expect(shred, lessThan(after.indexOf('// retired while it was opening')));
    expect(
      after.substring(0, shred),
      contains('backupRunning || restoreRunning ? const [] : adopted'),
    );
    // its own folder, by the database's own place and suffix
    expect(
      steps,
      contains("p.join(p.dirname(path), 'wallpapers\${container.suffix}')"),
    );
  });

  test('a photo no chat says it shows is swept: one left by a group taken '
      'again whole, one for a chat that went; the default and the chats\' '
      'own stay', () async {
    final db = await chats();
    // INSERT OR REPLACE takes the row again with no delete trigger
    await db.execute(
      "INSERT OR REPLACE INTO groups (group_id, atmosphere) "
      "VALUES ('$_group', NULL)",
    );
    await db.insert('wallpapers', {
      'chat': 'nobody-here',
      'atmo': kPhotoWall,
      'photo': _photo,
    });
    await db.execute(
      "UPDATE contacts SET atmosphere = 'photo' WHERE halo_id = '$_other'",
    );
    expect(await walls(db), [
      '',
      'group:$_group',
      'nobody-here',
      _other,
      _peer,
    ]);
    await dropOrphanWallpapers(db);
    expect(await walls(db), ['', _other, _peer]);
  }, skip: skip);

  test('the sweep runs at every open', () {
    final at = src.indexOf('await dropOrphanWallpapers(_db!);');
    expect(at, greaterThan(src.indexOf('onUpgrade: (db, oldV, newV) async {')));
    expect(at, lessThan(src.indexOf('// retired while it was opening')));
  });

  test('a photo is written only once its chat took the mark', () async {
    final db = SqliteMem.open()!;
    await db.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, atmosphere TEXT)',
    );
    await db.execute(
      'CREATE TABLE groups (group_id TEXT PRIMARY KEY, atmosphere TEXT)',
    );
    await wallpaperTable(db);
    final on = _On(db);
    expect(await on.setChatPhoto(_peer, _photo), isFalse);
    expect(await walls(db), isEmpty);
    await db.insert('contacts', {'halo_id': _peer});
    expect(await on.setChatPhoto(_peer, _photo), isTrue);
    expect(await walls(db), [_peer]);
  }, skip: skip);

  test('the old setters take the same way in: a photo goes with the choice '
      'that replaced it', () async {
    final db = await _seeded();
    await db.setChatPhoto(_group, _photo, group: true);
    await db.setGroupAtmosphere(_group, 'dusk');
    expect(await db.wallpaperRow('group:$_group'), isNull);
    await db.setChatPhoto(_peer, _photo);
    await db.setAtmosphere(_peer, 'rain');
    expect(await db.wallpaperRow(_peer), isNull);
  });

  test('the upgrade cleans each old photo off the ui thread', () {
    final at = src.indexOf('Future<List<String>> adoptWallpaperFiles(');
    final body = src.substring(at, src.indexOf('\n}\n', at));
    expect(body, contains('await photoToSendOffUi('));
    expect(body, isNot(contains('photoToSend(')));
  });

  test(
    'the sweep finds a group by its key, not by reading every group',
    () async {
      final db = await chats();
      final plan = await db.rawQuery(
        'EXPLAIN QUERY PLAN SELECT 1 FROM wallpapers WHERE $kOrphanWallpapers',
      );
      final lines = [for (final r in plan) '${r['detail']}'];
      final groups = lines.where((l) => l.contains('groups')).toList();
      expect(groups, isNotEmpty, reason: '$lines');
      expect(
        groups.every((l) => l.contains('USING') && !l.startsWith('SCAN')),
        isTrue,
        reason: '$lines',
      );
    },
    skip: skip,
  );
}

class _On extends HaloDb {
  _On(this.db);
  final SqliteMem db;
  @override
  Future<Database> open() async => db;
}
