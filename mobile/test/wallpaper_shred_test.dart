// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's own photo behind it goes with the chat: zeroed, then unlinked,
// once the row no longer names it. a file a row still names stays, and
// what no row names is found at start. the real database methods over
// rows kept in maps, the files real ones in a scratch folder
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _peer = 'someone-with-a-photo';
const _other = 'someone-else';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('wallpaper_shred');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs.path,
        );
  });

  tearDown(() => docs.deleteSync(recursive: true));

  Future<_Rows> rows([HaloContainer c = HaloContainer.everyday]) async {
    final db = _Rows(MemDb(), c);
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
    return db;
  }

  // a photo on disk in the container's wallpapers folder, named on a row
  Future<File> photo(
    _Rows db, {
    String who = _peer,
    String name = '$_peer.jpg',
    int accepted = 1,
  }) async {
    final dir = await db.container.folder('wallpapers');
    final f = File(p.join(dir.path, name))..writeAsBytesSync([1, 2, 3]);
    await db.mem.update(
      'contacts',
      {'atmosphere': 'image:${f.path}', 'accepted': accepted},
      where: 'halo_id = ?',
      whereArgs: [who],
    );
    return f;
  }

  String? atmo(_Rows db, String who) =>
      db.mem
              .rows('contacts')
              .singleWhere((r) => r['halo_id'] == who)['atmosphere']
          as String?;

  test('delete chat shreds its wallpaper', () async {
    final db = await rows();
    final f = await photo(db);
    await db.deleteConversation(_peer);
    expect(atmo(db, _peer), isNull);
    expect(f.existsSync(), isFalse);
  });

  test('a hidden chat deleted shreds its wallpaper in the vault', () async {
    final db = await rows(HaloContainer.vault);
    final f = await photo(db);
    expect(p.basename(f.parent.path), 'wallpapers_v');
    await db.deleteConversation(_peer);
    expect(f.existsSync(), isFalse);
  });

  test('a request turned away takes its wallpaper along', () async {
    // block and delete on a request declines it, then blocks
    final db = await rows();
    final f = await photo(db, accepted: 0);
    await db.declineRequest(_peer);
    await db.setBlocked(_peer, true);
    expect(atmo(db, _peer), isNull);
    expect(f.existsSync(), isFalse);
  });

  test('a request forgotten shreds its wallpaper', () async {
    final db = await rows();
    final f = await photo(db, accepted: 0);
    await db.forgetRequest(_peer);
    expect(
      db.mem.rows('contacts').where((r) => r['halo_id'] == _peer),
      isEmpty,
    );
    expect(f.existsSync(), isFalse);
  });

  test('a name let go shreds its wallpaper', () async {
    final db = await rows();
    final f = await photo(db);
    await db.forgetName(_peer);
    expect(atmo(db, _peer), isNull);
    expect(f.existsSync(), isFalse);
  });

  test('a wallpaper reset to a preset shreds the photo', () async {
    final db = await rows();
    final f = await photo(db);
    await db.setAtmosphere(_peer, 'dusk');
    expect(atmo(db, _peer), 'dusk');
    expect(f.existsSync(), isFalse);
  });

  test('a photo replaced by another shreds the old one', () async {
    final db = await rows();
    final old = await photo(db);
    final dir = await db.container.folder('wallpapers');
    final next = File(p.join(dir.path, '${_peer}_2.jpg'))
      ..writeAsBytesSync([4, 5]);
    await db.setAtmosphere(_peer, 'image:${next.path}');
    expect(old.existsSync(), isFalse);
    expect(next.existsSync(), isTrue);
  });

  test('a new photo lands under a name of its own', () async {
    final db = await rows();
    final a = await db.setWallpaperPhoto(_peer, Uint8List.fromList([1]));
    final b = await db.setWallpaperPhoto(_peer, Uint8List.fromList([2, 2]));
    expect(a, isNot(b));
    expect(File(a).existsSync(), isFalse);
    expect(File(b).readAsBytesSync(), [2, 2]);
    expect(atmo(db, _peer), 'image:$b');
    expect(p.basename(File(b).parent.path), 'wallpapers');
  });

  test('the photo stays when the row is not written', () async {
    final db = await rows();
    final f = await photo(db);
    db.mem.failOn = 'update:contacts';
    await expectLater(db.setAtmosphere(_peer, 'dusk'), throwsStateError);
    expect(f.existsSync(), isTrue);
  });

  test('a photo another chat still names stays', () async {
    final db = await rows();
    final f = await photo(db);
    await photo(db, who: _other);
    await db.deleteConversation(_peer);
    expect(f.existsSync(), isTrue);
    await db.deleteConversation(_other);
    expect(f.existsSync(), isFalse);
  });

  test(
    'a row naming a file outside the wallpapers folder shreds nothing',
    () async {
      final db = await rows();
      final f = File(p.join(docs.path, 'elsewhere', 'keep.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([9]);
      await db.mem.update(
        'contacts',
        {'atmosphere': 'image:${f.path}'},
        where: 'halo_id = ?',
        whereArgs: [_peer],
      );
      await db.deleteConversation(_peer);
      expect(f.existsSync(), isTrue);
    },
  );

  group('the start sweep', () {
    final before = DateTime.now().subtract(const Duration(minutes: 10));
    final old = before.subtract(const Duration(hours: 1));

    test('keeps what a row names and finds the rest', () async {
      final db = await rows();
      final named = await photo(db)
        ..setLastModifiedSync(old);
      final dir = await db.container.folder('wallpapers');
      // a group's row counts as naming one too
      final g = File(p.join(dir.path, 'grp.jpg'))
        ..writeAsBytesSync([1])
        ..setLastModifiedSync(old);
      await db.mem.insert('groups', {
        'group_id': 'g1',
        'name': 'g',
        'admin_id': 'a',
        'created_at': 1,
        'atmosphere': 'image:${g.path}',
      });
      final orphan = File(p.join(dir.path, 'left.jpg'))
        ..writeAsBytesSync([1])
        ..setLastModifiedSync(old);
      // one written moments ago may be a pick still being filed
      final young = File(p.join(dir.path, 'young.jpg'))..writeAsBytesSync([1]);
      final gone = await db.unnamedWallpapers(before: before);
      expect(gone.map((f) => f.path), [orphan.path]);
      expect(
        named.existsSync() && g.existsSync() && young.existsSync(),
        isTrue,
      );
    });

    test('looks only in its own container', () async {
      final db = await rows(HaloContainer.decoy);
      final mine = await db.container.folder('wallpapers');
      final theirs = await HaloContainer.everyday.folder('wallpapers');
      final a = File(p.join(mine.path, 'a.jpg'))
        ..writeAsBytesSync([1])
        ..setLastModifiedSync(old);
      File(p.join(theirs.path, 'b.jpg'))
        ..writeAsBytesSync([1])
        ..setLastModifiedSync(old);
      final gone = await db.unnamedWallpapers(before: before);
      expect(gone.map((f) => f.path), [a.path]);
    });
  });
}
