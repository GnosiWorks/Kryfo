// SPDX-License-Identifier: GPL-3.0-or-later
// a group message carries one uid to every member. one member who sends
// a frame with another's uid first gets a row of their own, and the real
// message, its edit and its take-back still land on the right row. the
// app's receive path on its own schema, in the host's sqlite
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        searchTables,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateReceive;
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
    docs = Directory.systemTemp.createTempSync('group_uid_twin');
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

  Future<List<(String, String)>> held(String uid) async => [
    for (final r in await s.rawQuery(
      'SELECT peer_id, plaintext FROM messages WHERE msg_uid = ? '
      'ORDER BY peer_id',
      [uid],
    ))
      (r['peer_id'] as String, r['plaintext'] as String),
  ];

  Future<String> edit(String uid, String by, String text) => wrapMessage(
    '',
    edit: EditFrame(targetUid: uid, newText: text),
    groupId: 'g1',
    sender: asSender(by),
  );

  Future<String> unsend(String uid, String by) =>
      wrapMessage('', unsend: uid, groupId: 'g1', sender: asSender(by));

  test(
    'a uid taken first by another member still files the real one',
    () async {
      await comes('carol', await said('gm-x', by: 'carol'));
      await comes('bob', await said('gm-x'));
      expect(await held('gm-x'), [
        ('bob', 'see you there'),
        ('carol', 'see you there'),
      ]);
      // the same frame again from bob is a resend, not a third row
      await comes('bob', await said('gm-x'));
      expect(await rows('gm-x'), 2);
    },
    skip: skip,
  );

  test('an edit rewrites only its sender\'s row', () async {
    await comes('carol', await said('gm-e', by: 'carol'));
    await comes('bob', await said('gm-e'));
    await comes('bob', await edit('gm-e', 'bob', 'running late'));
    expect(await held('gm-e'), [
      ('bob', 'running late'),
      ('carol', 'see you there'),
    ]);
  }, skip: skip);

  test('a take-back takes only its sender\'s row', () async {
    await comes('carol', await said('gm-u', by: 'carol'));
    await comes('bob', await said('gm-u'));
    await comes('carol', await unsend('gm-u', 'carol'));
    expect(await held('gm-u'), [('bob', 'see you there')]);
    await comes('bob', await unsend('gm-u', 'bob'));
    expect(await rows('gm-u'), 0);
  }, skip: skip);

  test('an edit before its message, with the uid taken first by another, '
      'waits for the message', () async {
    await comes('carol', await said('gm-ee', by: 'carol'));
    await comes('bob', await edit('gm-ee', 'bob', 'running late'));
    await comes('bob', await said('gm-ee'));
    expect(await held('gm-ee'), [
      ('bob', 'running late'),
      ('carol', 'see you there'),
    ]);
  }, skip: skip);

  test('a take-back before its message, with the uid taken first by '
      'another, keeps the message away', () async {
    await comes('carol', await said('gm-eu', by: 'carol'));
    await comes('bob', await unsend('gm-eu', 'bob'));
    await comes('bob', await said('gm-eu'));
    expect(await held('gm-eu'), [('carol', 'see you there')]);
  }, skip: skip);
}
