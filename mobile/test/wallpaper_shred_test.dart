// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's own photo behind it goes with the chat: zeroed, then unlinked,
// once the row no longer names it. a file a row still names stays, and
// what no row names is found at start. the real database methods over
// rows kept in maps, the files real ones in a scratch folder
import 'dart:io';
import 'dart:typed_data';

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
}
