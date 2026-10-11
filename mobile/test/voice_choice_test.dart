// SPDX-License-Identifier: GPL-3.0-or-later
// whether a chat's notes go out disguised: each chat's own choice, kept in
// its own row in the container that holds it. without one a burner room
// starts disguised and every other chat takes the old one switch as its
// default. a hidden chat's choice never reaches the everyday side, and the
// decoy has its own. the databases are rows kept in maps
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, useDatabasesForTest, voiceDisguiseColumns;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/voice_choice.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database, DatabaseExecutor;

import 'arrival_fakes.dart';
import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem, [HaloContainer c = HaloContainer.everyday]) : super(c);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

// what an upgrade asks of the database
class _Sql implements DatabaseExecutor {
  final said = <String>[];
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async =>
      said.add(sql);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _person(MemDb m, String id) => m.insert('contacts', {
  'halo_id': id,
  'onion': '',
  'xpub': 'x-$id',
  'first_seen': 1,
  'last_seen': 1,
  'accepted': 1,
});

Future<void> _group(MemDb m, String id, {bool room = false}) =>
    m.insert('groups', {
      'group_id': id,
      'name': id,
      'created_at': 1,
      if (room) 'room_pub': 'pub-$id',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late AppState app;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('voice_choice');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  Future<void> open(Session s) async {
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useDatabasesForTest(s.primary, s);
    app = AppState(io: ArrivalIo(), router: router);
  }

  group('the rule', () {
    test('a chat that chose keeps its choice, room or not', () {
      expect(chatDisguise(own: false, burner: true, fallback: true), isFalse);
      expect(chatDisguise(own: true, fallback: false), isTrue);
    });

    test('with no choice a burner room starts disguised', () {
      expect(chatDisguise(burner: true), isTrue);
      expect(chatDisguise(), isFalse);
      expect(chatDisguise(fallback: true), isTrue);
    });
  });

  group('one database', () {
    late MemDb mem;
    setUp(() async {
      mem = MemDb();
      await _person(mem, 'bob');
      await _person(mem, 'carol');
      await _group(mem, 'friends');
      await _group(mem, 'burner', room: true);
      await open(Session(_Rows(mem)));
    });

    test('nothing chosen: off, and on in a burner room', () async {
      expect(await app.loadChatDisguise('bob'), isFalse);
      expect(await app.loadChatDisguise('friends', group: true), isFalse);
      expect(
        await app.loadChatDisguise('burner', group: true, burner: true),
        isTrue,
      );
    });

    test('a choice is kept in that chat\'s own row, and only there', () async {
      await app.saveChatDisguise('bob', true);
      await app.saveChatDisguise('burner', false, group: true);
      expect(await app.loadChatDisguise('bob'), isTrue);
      expect(await app.loadChatDisguise('carol'), isFalse);
      expect(
        await app.loadChatDisguise('burner', group: true, burner: true),
        isFalse,
      );
      final people = {
        for (final r in mem.rows('contacts')) r['halo_id']: r['voice_disguise'],
      };
      expect(people, {'bob': 1, 'carol': null});
      final groups = {
        for (final r in mem.rows('groups')) r['group_id']: r['voice_disguise'],
      };
      expect(groups, {'friends': null, 'burner': 0});
      // nothing of it in the identity's settings
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    });

    test('the old switch on is the default where nothing was chosen', () async {
      FlutterSecureStorage.setMockInitialValues({'disguise_on': '1'});
      expect(await app.loadChatDisguise('bob'), isTrue);
      expect(await app.loadChatDisguise('friends', group: true), isTrue);
      await app.saveChatDisguise('bob', false);
      expect(await app.loadChatDisguise('bob'), isFalse);
      expect(await app.loadChatDisguise('carol'), isTrue);
      // and turned off, the chats that chose keep their choice
      FlutterSecureStorage.setMockInitialValues({'disguise_on': '0'});
      await app.saveChatDisguise('carol', true);
      expect(await app.loadChatDisguise('carol'), isTrue);
      expect(await app.loadChatDisguise('friends', group: true), isFalse);
    });

    test('an upgrade adds the choice to people and groups', () async {
      final sql = _Sql();
      await voiceDisguiseColumns(sql);
      expect(sql.said, [
        'ALTER TABLE contacts ADD COLUMN voice_disguise INTEGER',
        'ALTER TABLE groups ADD COLUMN voice_disguise INTEGER',
      ]);
      final src = File('lib/main.dart').readAsStringSync();
      final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
      expect(int.parse(version), greaterThanOrEqualTo(76));
      expect(
        src,
        contains(
          'if (oldV < 76) {\n'
          '          // a chat\'s own choice to disguise the voice\n'
          '          await voiceDisguiseColumns(db);',
        ),
      );
      // after every older step
      final at = src.indexOf('if (oldV < 76) {');
      for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(src)) {
        if (int.parse(m.group(1)!) < 76) expect(m.start, lessThan(at));
      }
    });
  });

  test('a hidden chat\'s choice stays in the vault', () async {
    final everyday = MemDb(), vault = MemDb();
    await _person(everyday, 'bob');
    await _group(everyday, 'friends');
    await _person(vault, 'hid');
    await _group(vault, 'secret');
    FlutterSecureStorage.setMockInitialValues({'disguise_on': '0'});
    final s = await Session.withVault(
      _Rows(everyday),
      _Rows(vault, HaloContainer.vault),
    );
    await open(s);
    final before = everyday.dump();
    everyday.log.clear();
    await app.saveChatDisguise('hid', true);
    await app.saveChatDisguise('secret', true, group: true);
    expect(await app.loadChatDisguise('hid'), isTrue);
    expect(await app.loadChatDisguise('secret', group: true), isTrue);
    expect(vault.rows('contacts').single['voice_disguise'], 1);
    expect(vault.rows('groups').single['voice_disguise'], 1);
    // the everyday side has not moved, in its rows or its settings
    expect(everyday.dump(), before);
    expect(everyday.log, isEmpty);
    expect(await const FlutterSecureStorage().readAll(), {'disguise_on': '0'});
    // and its own chats still read their own
    await app.saveChatDisguise('bob', true);
    expect(everyday.rows('contacts').single['voice_disguise'], 1);
    expect(vault.rows('contacts').single['voice_disguise'], 1);
  });

  test('the decoy keeps its own choices and its own default', () async {
    final decoy = MemDb();
    await _person(decoy, 'bob');
    // the everyday identity's default says nothing in the decoy
    FlutterSecureStorage.setMockInitialValues({'disguise_on': '1'});
    await open(Session(_Rows(decoy, HaloContainer.decoy)));
    expect(await app.loadChatDisguise('bob'), isFalse);
    FlutterSecureStorage.setMockInitialValues({'d.disguise_on': '1'});
    expect(await app.loadChatDisguise('bob'), isTrue);
    await app.saveChatDisguise('bob', false);
    expect(await app.loadChatDisguise('bob'), isFalse);
    expect(decoy.rows('contacts').single['voice_disguise'], 0);
    expect(await const FlutterSecureStorage().readAll(), {
      'd.disguise_on': '1',
    });
  });
}
