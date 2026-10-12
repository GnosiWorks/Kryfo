// SPDX-License-Identifier: GPL-3.0-or-later
// a restore reads every relay again from the start. what of a group or a
// room came in and went before the backup, burned, deleted, cleared or
// taken back, arrives once more and stays gone. the app's receive path on
// its own schema, in the host's sqlite
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        goneKey,
        searchTables,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'sqlite_ffi.dart';

class _Rows extends HaloDb {
  _Rows(this.s);
  final SqliteMem s;
  @override
  Future<Database> open() async => s;
}

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;
  late Directory docs;
  late SqliteMem s;
  late _Rows db;
  late ArrivalIo io;
  late AppState app;
  var n = 0;

  // a phone just started: nothing held in memory
  Future<AppState> start() async {
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useDatabasesForTest(db, Session(db));
    return AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
  }

  setUp(() async {
    if (skip != null) return;
    docs = Directory.systemTemp.createTempSync('group_gone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    useEngineForTest(_Engine());
    s = SqliteMem.open(path: p.join(docs.path, 'halo.db'))!;
    await appSchemaOn(s);
    await searchTables(s, fresh: true);
    for (final who in ['bob', 'carol']) {
      await s.insert('contacts', {
        'halo_id': who,
        'onion': '',
        'xpub': 'x-$who',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
        'back_paired': 1,
      });
    }
    await s.insert('groups', {
      'group_id': 'g1',
      'name': 'Friends',
      'created_at': 1,
      'is_admin': 0,
      'admin_id': 'someone-else',
    });
    for (final (i, m) in ['me', 'bob', 'carol'].indexed) {
      await s.insert('group_members', {
        'group_id': 'g1',
        'halo_id': m,
        'joined_at': i,
      });
    }
    db = _Rows(s);
    io = ArrivalIo();
    app = await start();
  });

  tearDown(() async {
    if (skip != null) return;
    await s.close();
    docs.deleteSync(recursive: true);
  });

  // read off a lane once more: a fresh cipher each time
  Future<void> comes(String from, String wire) async {
    final c = 'again-${n++}';
    io.opens[c] = (from, wire);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<int> rows(String uid) async => (await s.rawQuery(
    'SELECT 1 FROM messages WHERE msg_uid = ?',
    [uid],
  )).length;

  Future<String> said(String uid, {String by = 'bob', int? burn}) =>
      wrapMessage(
        'see you there',
        msgUid: uid,
        groupId: 'g1',
        burnSeconds: burn,
        sender: asSender(by),
      );

  for (final how in ['burned', 'deleted', 'cleared']) {
    test('one $how before the backup stays gone', () async {
      final w = await said('gm-$how', burn: how == 'burned' ? 60 : null);
      await comes('bob', w);
      expect(await rows('gm-$how'), 1);
      switch (how) {
        case 'burned':
          await s.update(
            'messages',
            {'burn_at': 1},
            where: 'msg_uid = ?',
            whereArgs: ['gm-$how'],
          );
          await db.purgeExpired();
        case 'deleted':
          await db.deleteMessage('gm-$how');
        default:
          await db.clearGroupConversation('g1');
      }
      expect(await rows('gm-$how'), 0);
      app = await start();
      await comes('bob', w);
      expect(await rows('gm-$how'), 0);
    }, skip: skip);
  }

  test('one taken back before it came stays away after a restart', () async {
    final un = await wrapMessage(
      '',
      unsend: 'gm-back',
      groupId: 'g1',
      sender: asSender('bob'),
    );
    await comes('bob', un);
    app = await start();
    await comes('bob', await said('gm-back'));
    expect(await rows('gm-back'), 0);
  }, skip: skip);

  test('one member\'s word never takes another\'s message', () async {
    final un = await wrapMessage(
      '',
      unsend: 'gm-hers',
      groupId: 'g1',
      sender: asSender('carol'),
    );
    await comes('carol', un);
    app = await start();
    await comes('bob', await said('gm-hers'));
    expect(await rows('gm-hers'), 1);
  }, skip: skip);

  test('a group that goes takes what it knew went', () async {
    await comes('bob', await said('gm-left'));
    await db.deleteMessage('gm-left');
    expect(
      [
        for (final r in await s.rawQuery('SELECT peer_id FROM gone_in'))
          r['peer_id'],
      ],
      [goneKey('bob', group: 'g1')],
    );
    await db.deleteGroup('g1');
    expect(await s.rawQuery('SELECT 1 FROM gone_in'), isEmpty);
  }, skip: skip);
}
