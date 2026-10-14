// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's wallpaper photo and the default live in the container's own
// encrypted database: made on create and on the upgrade to 80, the last
// step. a photo lasts while its chat's atmosphere says photo: a chat
// deleted, or a built-in or the default picked, takes it. the default stays
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/jpeg_strip.dart' show jpegHasExif;
import 'package:kryfo/main.dart'
    show HaloDb, adoptWallpaperFiles, kPhotoWall, wallKey, wallpaperTable;
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

  test('made on create, and on the upgrade to 80 after every older step', () {
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), greaterThanOrEqualTo(80));
    expect(create, contains('await wallpaperTable(db);'));
    expect(
      RegExp(
        r'if \(oldV < 80\) \{[^}]*await wallpaperTable\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    final at80 = steps.indexOf('if (oldV < 80) {');
    for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(steps)) {
      if (int.parse(m.group(1)!) < 80) expect(m.start, lessThan(at80));
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

  test('a phone from 79 gets the table once, and a photo reads back byte '
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
    // a path nothing here wrote is never named for a shred
    await db.insert('contacts', {
      'halo_id': 'odd',
      'atmosphere': 'image:${docs.path}/notes.txt',
    });
    await wallpaperTable(db);
    final files = await adoptWallpaperFiles(db);
    expect(files.toSet(), {kept.path, '${dir.path}/gone.jpg', broken.path});
    final row = await db.rawQuery(
      'SELECT photo FROM wallpapers WHERE chat = ?',
      [_peer],
    );
    final photo = row.single['photo']! as Uint8List;
    expect(jpegHasExif(photo), isFalse);
    expect(await db.rawQuery('SELECT halo_id, atmosphere FROM contacts'), [
      {'halo_id': _peer, 'atmosphere': kPhotoWall},
      {'halo_id': _other, 'atmosphere': null},
      {'halo_id': 'plain', 'atmosphere': 'dusk'},
      {'halo_id': 'odd', 'atmosphere': null},
    ]);
    expect(await db.rawQuery('SELECT atmosphere FROM groups'), [
      {'atmosphere': null},
    ]);
    expect(await db.rawQuery('SELECT chat FROM wallpapers ORDER BY chat'), [
      {'chat': _peer},
    ]);
  }, skip: skip);

  test('the upgrade shreds what it took in once it is written', () {
    final at = steps.indexOf('if (oldV < 80) {');
    expect(
      steps.substring(at),
      contains('adopted = await adoptWallpaperFiles(db);'),
    );
    final after = src.substring(
      src.indexOf('adopted = await adoptWallpaperFiles'),
    );
    final shred = after.indexOf('await shredFile(f);');
    expect(shred, greaterThan(0));
    expect(shred, lessThan(after.indexOf('// retired while it was opening')));
  });
}
