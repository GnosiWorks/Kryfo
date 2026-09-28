// SPDX-License-Identifier: GPL-3.0-or-later
// a message's files go with it: a photo, a voice note or any other file,
// when it is deleted, unsent, cleared with its chat or runs out of time.
// what no message names is found at start and goes too, so no later backup
// carries it. the real database methods over rows kept in maps, the files
// real ones in a scratch folder
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _peer = 'someone-we-know';
const _g = 'grp000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late Directory media;
  late _Rows db;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('media_shred');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs.path,
        );
    media = await HaloContainer.everyday.mediaDir();
    db = _Rows(MemDb());
  });

  tearDown(() => docs.deleteSync(recursive: true));

  // a message with a file on disk, in the column it would have
  Future<File> row(
    String uid, {
    String col = 'file_path',
    String peer = _peer,
    String? group,
    int? burnAt,
    String direction = 'in',
  }) async {
    final f = File(p.join(media.path, 'in_$uid.bin'))
      ..writeAsBytesSync([1, 2, 3]);
    await db.mem.insert('messages', {
      'peer_id': peer,
      'direction': direction,
      'plaintext': '',
      'sent_at': 1,
      'msg_uid': uid,
      'group_id': group,
      'burn_at': burnAt,
      col: f.path,
      if (col == 'file_path') 'file_name': 'voice.wav',
    });
    return f;
  }

  test(
    'a disappearing voice note leaves no file when its time is up',
    () async {
      final f = await row('burn1', burnAt: 1);
      expect(await db.purgeExpired(), 1);
      expect(f.existsSync(), isFalse);
    },
  );

  test('a disappearing photo leaves no file either', () async {
    final f = await row('burn2', col: 'media_path', burnAt: 1);
    expect(await db.purgeExpired(), 1);
    expect(f.existsSync(), isFalse);
  });

  test('a file deleted or unsent leaves no file', () async {
    final f = await row('uns1');
    final mine = await row('uns2', direction: 'out');
    await db.deleteMessage('uns1');
    await db.deleteMessage('uns2');
    expect(db.mem.rows('messages'), isEmpty);
    expect(f.existsSync(), isFalse);
    expect(mine.existsSync(), isFalse);
  });

  test('clearing a chat takes every file in it and nothing else', () async {
    final a = await row('c1');
    final b = await row('c2', col: 'media_path');
    final other = await row('o1', peer: 'another-one-here');
    await db.clearConversation(_peer);
    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('clearing a group takes every file in it', () async {
    final a = await row('g1', group: _g);
    final b = await row('g2', group: _g, col: 'media_path');
    await db.clearGroupConversation(_g);
    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isFalse);
  });

  test('deleting a chat takes its files; the person stays', () async {
    await db.mem.insert('contacts', {
      'halo_id': _peer,
      'onion': 'o',
      'xpub': 'x',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
    });
    final a = await row('d1');
    final b = await row('d2', col: 'media_path');
    await db.deleteConversation(_peer);
    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isFalse);
    expect(db.mem.rows('contacts').single['accepted'], 0);
  });

  test('declining a request takes the files it sent', () async {
    await db.mem.insert('contacts', {
      'halo_id': _peer,
      'onion': 'o',
      'xpub': 'x',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 0,
    });
    final a = await row('r1');
    await db.declineRequest(_peer);
    expect(a.existsSync(), isFalse);
  });

  group('files no message names', () {
    test('are found, and only they', () async {
      final kept = await row('k1');
      final photo = await row('k2', col: 'media_path');
      final left = File(p.join(media.path, 'f_old_voice.wav'))
        ..writeAsBytesSync([9]);
      final folder = Directory(p.join(media.path, 'sub'))..createSync();
      File(p.join(folder.path, 'x.bin')).writeAsBytesSync([9]);
      final gone = await db.unnamedMedia(
        before: DateTime.now().add(const Duration(minutes: 1)),
      );
      expect([for (final f in gone) f.path], [left.path]);
      expect(kept.existsSync() && photo.existsSync(), isTrue);
    });

    test('a row names its file by its name, whatever folder it was '
        'written under', () async {
      final f = File(p.join(media.path, 'in_moved.jpg'))..writeAsBytesSync([1]);
      await db.mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'in',
        'plaintext': '',
        'sent_at': 1,
        'msg_uid': 'm1',
        'media_path': '/data/user/0/app/media/in_moved.jpg',
      });
      final gone = await db.unnamedMedia(
        before: DateTime.now().add(const Duration(minutes: 1)),
      );
      expect(gone, isEmpty);
      expect(f.existsSync(), isTrue);
    });

    test('one written since is left alone', () async {
      File(p.join(media.path, 'in_new.jpg')).writeAsBytesSync([1]);
      final gone = await db.unnamedMedia(
        before: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(gone, isEmpty);
    });

    test('start sweeps them before anything else runs', () {
      final src = File('lib/main.dart').readAsStringSync();
      final boot = src.substring(src.indexOf('Future<void> _boot() async'));
      final sweep = boot.indexOf('_sweepUnnamedMedia(');
      expect(sweep, greaterThan(0));
      expect(sweep, lessThan(boot.indexOf('ready = true')));
      expect(boot.indexOf('repairVaultMoves()'), lessThan(sweep));
    });
  });
}
