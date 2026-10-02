// SPDX-License-Identifier: GPL-3.0-or-later
// a group file reads sent once every slice has reached someone. a member
// still short then is owed the rest: kept per member on disk, sent only the
// slices it lacks once it can take them, after a restart too, with a wait
// that grows and an end. what is owed goes with its message, its member,
// its group and its chat's container, and the sender's bubble says how many
// have it until they all do. the database methods and the app's send are
// the real ones, over rows kept in maps; signal and the wire are stand-ins
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/group_media_send.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        appState,
        groupOwedTables,
        makePreKeyBundleB64,
        useDatabasesForTest;
import 'package:kryfo/media_send.dart' show mediaCancelled, mediaInflight;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/vault_life.dart' show chatTables;
import 'package:kryfo/widgets/chat_parts.dart' show GrowSwap;
import 'package:kryfo/widgets/file_reach.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:kryfo/wipe.dart' show haloWiping;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve, SignalProtocolAddress;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'pin_flow_fakes.dart' show app, phone;
import 'real_sqlite.dart';
import 'source_body.dart';

const _g = 'grp000000001';
const _uid = 'file-one';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // its or-clause is past what the map rows read
  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async => const [];
}

// signal and the wire: a member with no session has no stored bundle
// either, and a member's route can refuse some slices
class _Io extends ArrivalIo {
  // with no session here: signal's own store says when one is made
  final noSession = <String>{};
  bool Function(String to, int? slice) refuse = (_, _) => false;
  void Function(String to, String plain)? onSend;

  @override
  Future<bool> hasSession(String peer) async =>
      !noSession.contains(peer) ||
      signalSession.ready &&
          await signalSession.sessionStore.containsSession(
            SignalProtocolAddress(peer, 1),
          );

  @override
  Future<String> relaySend(String xPub, String cipher) async {
    // a key frame rides outside signal
    if (cipher.startsWith('{')) return super.relaySend(xPub, cipher);
    final to = cipher.split(' ')[1];
    onSend?.call(to, cipher.substring('to $to '.length));
    if (refuse(to, _slice(cipher, to))) return 'error: down';
    return super.relaySend(xPub, cipher);
  }

  // the unsends of [uid] that went to [member]
  int unsends(String member, String uid) => [
    for (final (_, c) in sent)
      if (c.startsWith('to $member ') &&
          unwrapMessage(c.substring('to $member '.length)).unsend == uid)
        c,
  ].length;

  static int? _slice(String cipher, String to) =>
      unwrapMessage(cipher.substring('to $to '.length)).chunkIndex;

  // the slices of the file each member took, in order
  List<int> took(String member) => [
    for (final (_, c) in sent)
      if (c.startsWith('to $member ')) ?_slice(c, member),
  ];
}

Future<void> _person(MemDb mem, String id) => mem.insert('contacts', {
  'halo_id': id,
  'onion': '',
  'xpub': 'x-$id',
  'first_seen': 1,
  'last_seen': 1,
  'accepted': 1,
  'back_paired': 1,
});

Future<void> _group(MemDb mem, String id, List<String> members) async {
  await mem.insert('groups', {
    'group_id': id,
    'name': 'Friends',
    'created_at': 1,
    'is_admin': 0,
    'admin_id': 'someone-else',
  });
  for (final (i, m) in members.indexed) {
    await mem.insert('group_members', {
      'group_id': id,
      'halo_id': m,
      'joined_at': i,
    });
  }
}

// an owed row as a send leaves it
Future<void> _owe(
  MemDb mem,
  String member, {
  String uid = _uid,
  String group = _g,
  String have = '',
  int sentTo = 2,
  int? since,
  int tries = 0,
  int nextAt = 0,
}) => mem.insert('group_media_owed', {
  'msg_uid': uid,
  'group_id': group,
  'member': member,
  'total': 3,
  'have': have,
  'sent_to': sentTo,
  'since': since ?? DateTime.now().millisecondsSinceEpoch,
  'tries': tries,
  'next_at': nextAt,
});

// a store that hands over whatever it holds, due or not
class _AllDue implements GroupOwedStore {
  _AllDue(this.rows);
  final List<GroupOwed> rows;
  final tried = <String>[];
  @override
  Future<List<GroupOwed>> dueGroupOwed(int now) async => rows;
  @override
  Future<void> triedGroupOwed(
    String msgUid,
    Iterable<String> members,
    int now,
  ) async => tried.addAll(members);
  @override
  Future<void> dropGroupOwed(String msgUid) async {}
}

// a condition the sends running beside the test come to
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<String> _bundleOf() async {
  final pair = Curve.generateKeyPair();
  final them = SignalSession();
  await them.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  return makePreKeyBundleB64(them);
}

Map<String, Object?> _owed(MemDb mem, String member, {String uid = _uid}) => mem
    .rows('group_media_owed')
    .singleWhere((r) => r['msg_uid'] == uid && r['member'] == member);

// a phone's database with one group and one file of ours in it, as the
// group screen reads them. [reach] is what its line says
class _ScreenDb implements HaloDb {
  _ScreenDb(this.reach);

  Map<String, ({int have, int of})> reach;

  final _rows = [
    {
      'rowid': 1,
      'id': 1,
      'peer_id': 'me',
      'group_id': _g,
      'direction': 'out',
      'plaintext': 'the plan',
      'msg_uid': _uid,
      'sent': 1,
      'sent_at': DateTime.now()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
      'file_name': 'notes.pdf',
    },
  ];

  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _g,
    'name': 'Friends',
    'is_admin': 0,
  };
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async => [
    'me',
    'bob',
    'carol',
    'dave',
  ];
  @override
  Future<Set<String>> blockedIds() async => {};
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int limit = 60,
  }) async => [..._rows];
  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async =>
      [..._rows];
  @override
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async => [];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async => {};
  @override
  Future<Map<String, ({int have, int of})>> groupFileReach(
    String groupId,
  ) async => reach;
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> markRoomSeen(String groupId) async {}
  @override
  Future<void> clearGroupUnread(String groupId) async {}

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  setUp(() {
    docs = Directory.systemTemp.createTempSync('group_owed');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    groupSliceDone.clear();
    groupSliceDoneAt.clear();
    docs.deleteSync(recursive: true);
  });

  group('the table', () {
    test('slices pack into runs and back', () {
      expect(packSlices({}), '');
      expect(packSlices({4, 0, 1, 2, 7, 8}), '0-2,4,7-8');
      expect(unpackSlices('0-2,4,7-8', 9), {0, 1, 2, 4, 7, 8});
      // past the file's end, or unreadable, is left out
      expect(unpackSlices('0-2,4,7-8', 5), {0, 1, 2, 4});
      expect(unpackSlices('x,3-1,-2,1-2-3,2', 5), {2});
      expect(unpackSlices(null, 5), isEmpty);
      final all = {for (var i = 0; i < 500; i++) i}..remove(250);
      expect(unpackSlices(packSlices(all), 500), all);
    });

    test('a new database has it', () {
      final db = MemDb();
      expect(db.has('group_media_owed'), isTrue);
    });

    test('an upgrade from the version before adds it, and only it', () async {
      // a database as an upgrade from v58 finds it
      final db = MemDb(except: {'group_media_owed'});
      await _person(db, 'bob');
      await db.insert('messages', {
        'peer_id': 'me',
        'direction': 'out',
        'plaintext': '',
        'sent_at': 1,
        'msg_uid': _uid,
        'group_id': _g,
      });
      final before = {
        for (final t in ['contacts', 'messages']) t: db.rows(t),
      };
      expect(db.has('group_media_owed'), isFalse);
      await groupOwedTables(db);
      expect(db.has('group_media_owed'), isTrue);
      await _owe(db, 'bob');
      for (final e in before.entries) {
        expect(db.rows(e.key), e.value, reason: e.key);
      }
      // the trigger that drops what is owed with its message
      expect(
        db.log.where((l) => l.startsWith('CREATE TRIGGER')).single,
        contains('AFTER DELETE ON messages'),
      );
      // again is nothing new, and loses nothing
      await groupOwedTables(db);
      expect(db.rows('group_media_owed'), hasLength(1));
    });

    group('on a real sqlite', () {
      final sql = RealSqlite.open();
      final skip = sql == null ? 'no sqlite library here' : null;

      // every table the app made before this version, and its triggers
      void v58(RealSqlite db) {
        final src = File('lib/main.dart').readAsStringSync();
        for (final m in RegExp(
          r"'''\s*(CREATE TABLE (?:IF NOT EXISTS )?(\w+)\s*\(.*?\))\s*'''",
          dotAll: true,
        ).allMatches(src)) {
          if (m.group(2) == 'group_media_owed') continue;
          db.run(
            m
                .group(1)!
                .replaceFirst('CREATE TABLE IF NOT EXISTS', 'CREATE TABLE')
                .replaceFirst('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'),
          );
        }
        final poll = bodyOf(src, 'Future<void> _pollTables(');
        final trigger = RegExp(
          r"'(CREATE TRIGGER IF NOT EXISTS poll_votes_follow[^']*)'\s*'([^']*)'\s*'([^']*)'",
        ).firstMatch(poll)!;
        db.run(trigger.group(1)! + trigger.group(2)! + trigger.group(3)!);
      }

      test('the upgrade from 58 runs, and the trigger drops what is owed '
          'with its message', () async {
        final db = sql!;
        v58(db);
        db.run(
          'INSERT INTO contacts (halo_id, onion, xpub, first_seen, last_seen) '
          "VALUES ('bob', '', 'x-bob', 1, 1)",
        );
        for (final uid in ['a', 'b']) {
          db.run(
            'INSERT INTO messages (peer_id, direction, plaintext, sent_at, '
            "msg_uid, group_id) VALUES ('me', 'out', '', 1, '$uid', 'g')",
          );
        }
        db.run(
          'INSERT INTO messages (peer_id, direction, plaintext, sent_at) '
          "VALUES ('me', 'out', 'no uid', 1)",
        );
        db.run(
          'INSERT INTO poll_votes (poll_uid, voter, choices, seq, at) '
          "VALUES ('a', 'bob', '[0]', 1, 1)",
        );
        expect(
          db.run(
            "SELECT name FROM sqlite_master WHERE name = 'group_media_owed'",
          ),
          isEmpty,
        );

        await groupOwedTables(RealExecutor(db));
        final cols = [
          for (final r in db.run('PRAGMA table_info(group_media_owed)'))
            r['name'],
        ];
        expect(cols, [
          'msg_uid',
          'group_id',
          'member',
          'total',
          'have',
          'sent_to',
          'since',
          'tries',
          'next_at',
        ]);
        for (final (uid, m) in [('a', 'bob'), ('a', 'carol'), ('b', 'bob')]) {
          db.run(
            'INSERT INTO group_media_owed (msg_uid, group_id, member, total, '
            "sent_to, since, next_at) VALUES ('$uid', 'g', '$m', 3, 2, 1, 1)",
          );
        }
        // one member, one file: the key holds
        expect(
          () => db.run(
            'INSERT INTO group_media_owed (msg_uid, group_id, member, total, '
            "sent_to, since, next_at) VALUES ('a', 'g', 'bob', 3, 2, 1, 1)",
          ),
          throwsStateError,
        );
        expect(
          db
              .run(
                "SELECT have, tries FROM group_media_owed WHERE msg_uid = 'b'",
              )
              .single,
          {'have': '', 'tries': '0'},
        );

        db.run("DELETE FROM messages WHERE msg_uid = 'a'");
        expect(db.run('SELECT msg_uid, member FROM group_media_owed'), [
          {'msg_uid': 'b', 'member': 'bob'},
        ]);
        // the trigger before it still runs beside it
        expect(db.run('SELECT * FROM poll_votes'), isEmpty);
        // a row with no uid goes as before
        db.run('DELETE FROM messages WHERE msg_uid IS NULL');

        // again is nothing new, and loses nothing
        await groupOwedTables(RealExecutor(db));
        expect(db.run('SELECT COUNT(*) AS n FROM group_media_owed').single, {
          'n': '1',
        });
        expect(db.run('SELECT COUNT(*) AS n FROM contacts').single, {'n': '1'});
        db.close();
      }, skip: skip);
    });

    test('made on create and on the upgrade to 59', () {
      final src = File('lib/main.dart').readAsStringSync();
      final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
      expect(int.parse(version), greaterThanOrEqualTo(59));
      final create = src.indexOf('onCreate: (db, _) async {');
      final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
      expect(
        src.substring(create, upgrade),
        contains('await groupOwedTables(db);'),
      );
      expect(
        RegExp(
          r'if \(oldV < 59\) \{[^}]*await groupOwedTables\(db\);',
        ).hasMatch(src.substring(upgrade)),
        isTrue,
      );
      final made = bodyOf(src, 'Future<void> groupOwedTables(');
      expect(made, contains('CREATE TABLE IF NOT EXISTS group_media_owed'));
      expect(made, contains('CREATE TRIGGER IF NOT EXISTS'));
      expect(
        made,
        contains('DELETE FROM group_media_owed WHERE msg_uid = old.msg_uid'),
      );
    });
  });

  group('a group file', () {
    late MemDb mem;
    late _Rows db;
    late _Io io;
    late AppState app;
    late String path;

    Future<AppState> start(HaloDb d, Session s) async {
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      useDatabasesForTest(d, s);
      return AppState(io: io, router: router)
        ..myId = 'me'
        ..sendModeForTest = 'fast';
    }

    Future<void> fileRow(MemDb m, {String uid = _uid, String group = _g}) =>
        m.insert('messages', {
          'peer_id': 'me',
          'direction': 'out',
          'plaintext': '',
          'sent_at': DateTime.now().millisecondsSinceEpoch,
          'msg_uid': uid,
          'group_id': group,
          'file_path': path,
          'file_name': 'notes.pdf',
          'sent': 0,
        });

    // as the group screen sends it, and marks it once it went
    Future<String> send() async {
      final r = await app.sendMediaToGroup(
        _g,
        path,
        msgUid: _uid,
        fileName: 'notes.pdf',
      );
      if (r == 'ok') await db.markSent(_uid);
      return r;
    }

    // the outbox's tick, and the owed pass it starts
    Future<void> tick([AppState? on]) async {
      final a = on ?? app;
      await a.drainOutbox();
      await a.owedPassForTest;
    }

    Future<void> due(MemDb m) async {
      for (final r in m.rows('group_media_owed')) {
        await m.update(
          'group_media_owed',
          {'next_at': 0},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [r['msg_uid'], r['member']],
        );
      }
    }

    setUp(() async {
      mem = MemDb();
      db = _Rows(mem);
      io = _Io();
      for (final p in ['bob', 'carol', 'dave']) {
        await _person(mem, p);
      }
      await _group(mem, _g, ['me', 'bob', 'carol']);
      path = '${docs.path}/notes.pdf';
      // three slices
      File(path).writeAsBytesSync(List.filled(12288 * 2 + 10, 7));
      await fileRow(mem);
      app = await start(db, Session(db));
    });

    tearDown(() => haloWiping = false);

    test('a member with no session is owed it, and gets it once healed, '
        'only the slices it lacks', () async {
      io.noSession.add('carol');
      expect(await send(), 'ok');
      expect(io.took('bob'), [0, 1, 2]);
      expect(io.took('carol'), isEmpty);
      final owed = _owed(mem, 'carol');
      expect(owed['have'], '');
      expect(owed['tries'], 0);
      expect(owed['next_at'] as int, greaterThan(owed['since'] as int));
      expect(await db.groupFileReach(_g), {_uid: (have: 1, of: 2)});

      // before its wait is up nothing goes
      await tick();
      expect(io.took('carol'), isEmpty);
      expect(_owed(mem, 'carol')['tries'], 0);

      // still no session: kept, tried, and waits longer
      await due(mem);
      final at = DateTime.now().millisecondsSinceEpoch;
      await tick();
      expect(io.took('carol'), isEmpty);
      final again = _owed(mem, 'carol');
      expect(again['tries'], 1);
      expect(again['next_at'] as int, greaterThanOrEqualTo(at + kGroupOwedGap));

      // the session heals: the whole file goes to carol, nothing to bob
      io.noSession.clear();
      await due(mem);
      await tick();
      expect(io.took('carol'), [0, 1, 2]);
      expect(io.took('bob'), [0, 1, 2]);
      expect(mem.rows('group_media_owed'), isEmpty);
      expect(await db.groupFileReach(_g), isEmpty);
    });

    test('a member whose route went down halfway gets the rest after a '
        'restart', () async {
      var down = true;
      io.refuse = (to, i) => down && to == 'carol' && (i ?? 0) >= 1;
      expect(await send(), 'ok');
      expect(io.took('carol'), [0]);
      expect(_owed(mem, 'carol')['have'], '0');

      // a restart: nothing in memory, the rows on disk
      groupSliceDone.clear();
      groupSliceDoneAt.clear();
      final db2 = _Rows(mem);
      final app2 = await start(db2, Session(db2));
      down = false;
      await due(mem);
      await tick(app2);
      expect(io.took('carol'), [0, 1, 2]);
      expect(io.took('bob'), [0, 1, 2]);
      expect(mem.rows('group_media_owed'), isEmpty);
    });

    test('what a member took on a try that stopped is kept', () async {
      await _owe(mem, 'carol');
      await db.markSent(_uid);
      io.refuse = (to, i) => to == 'carol' && (i ?? 0) >= 1;
      await tick();
      expect(io.took('carol'), [0]);
      expect(_owed(mem, 'carol')['have'], '0');
      expect(_owed(mem, 'carol')['tries'], 1);
    });

    test('a row the outbox still holds is left to it', () async {
      await _owe(mem, 'carol');
      await tick();
      expect(io.took('carol'), isEmpty);
      expect(mem.rows('group_media_owed'), hasLength(1));
    });

    test(
      'a session healed by a key exchange gets what it is owed at once',
      () async {
        io.noSession.add('carol');
        expect(await send(), 'ok');
        expect(io.took('carol'), isEmpty);
        // its wait is far off
        expect(
          _owed(mem, 'carol')['next_at'] as int,
          greaterThan(DateTime.now().millisecondsSinceEpoch),
        );
        // signal's store outlives the test: the next starts with no session
        addTearDown(
          () => signalSession.sessionStore.deleteSession(
            SignalProtocolAddress('carol', 1),
          ),
        );
        // carol's keys come in over the relay and the session is made
        await app.receiveRelay([
          (
            peer: 'x-carol',
            cipher: jsonEncode({
              'halo_ctl': 'bundle',
              'from': 'carol',
              'bundle': await _bundleOf(),
              'want': true,
            }),
          ),
        ]);
        await _until(() => io.took('carol').length == 3);
        await app.owedPassForTest;
        expect(io.took('carol'), [0, 1, 2]);
        expect(io.took('bob'), [0, 1, 2]);
        expect(mem.rows('group_media_owed'), isEmpty);
      },
    );

    test('a wipe begun during a pass starts no other send', () async {
      final second = '${docs.path}/second.pdf';
      File(second).writeAsBytesSync(List.filled(12288 * 2 + 10, 8));
      await db.markSent(_uid);
      await mem.insert('messages', {
        'peer_id': 'me',
        'direction': 'out',
        'plaintext': '',
        'sent_at': 1,
        'msg_uid': 'file-two',
        'group_id': _g,
        'file_path': second,
        'file_name': 'second.pdf',
        'sent': 1,
      });
      await _owe(mem, 'carol', nextAt: 0);
      await _owe(mem, 'carol', uid: 'file-two', nextAt: 1);
      io.onSend = (to, plain) => haloWiping = true;
      await tick();
      // the first was on its way when the wipe began; the second never went
      final files = {
        for (final (_, c) in io.sent)
          if (c.startsWith('to carol '))
            unwrapMessage(c.substring('to carol '.length)).mediaId,
      };
      expect(files, {_uid});
      expect(_owed(mem, 'carol', uid: 'file-two')['have'], '');
    });

    test('taken back while it goes to the owed: stopped, and the take-back '
        'said again once the send let go', () async {
      await db.markSent(_uid);
      await _owe(mem, 'carol');
      var once = false;
      io.onSend = (to, plain) {
        if (once || to != 'carol') return;
        once = true;
        unawaited(app.unsendInGroup(_g, _uid));
      };
      await tick();
      await _until(() => io.unsends('carol', _uid) == 2);
      expect(io.took('carol').length, lessThan(3));
      expect(io.unsends('bob', _uid), 2);
      expect(mem.rows('group_media_owed'), isEmpty);
      expect(mem.rows('messages'), isEmpty);
      expect(mediaInflight, isNot(contains(_uid)));
    });

    test('a row deleted here stops its send before its file goes', () async {
      final s = Session(db);
      mediaInflight.add(_uid);
      addTearDown(() {
        mediaInflight.remove(_uid);
        mediaCancelled.remove(_uid);
      });
      await s.deleteMessage(_uid);
      expect(mediaCancelled, contains(_uid));
    });

    test('a quiet session sends nothing of it', () async {
      await _owe(mem, 'carol');
      await db.markSent(_uid);
      final decoy = _Rows(MemDb(), HaloContainer.decoy);
      useDatabasesForTest(db, Session(decoy));
      await tick();
      expect(io.took('carol'), isEmpty);
      expect(_owed(mem, 'carol')['tries'], 0);
    });

    test('nothing goes while a wipe runs', () async {
      await _owe(mem, 'carol');
      await db.markSent(_uid);
      haloWiping = true;
      await tick();
      expect(io.took('carol'), isEmpty);
      expect(_owed(mem, 'carol')['tries'], 0);
    });

    group('goes with', () {
      setUp(() async {
        await mem.insert('group_members', {
          'group_id': _g,
          'halo_id': 'dave',
          'joined_at': 9,
        });
        await db.markSent(_uid);
        await _owe(mem, 'carol', sentTo: 3);
        await _owe(mem, 'dave', sentTo: 3);
        await _owe(
          mem,
          'bob',
          uid: 'elsewhere',
          group: 'grp000000002',
          nextAt: 1 << 50,
        );
      });

      List<String> left() => [
        for (final r in mem.rows('group_media_owed'))
          '${r['msg_uid']}:${r['member']}',
      ];

      test('a member taken out, and the line counts one fewer', () async {
        expect(await db.groupFileReach(_g), {_uid: (have: 1, of: 3)});
        await db.removeGroupMember(_g, 'dave');
        expect(left(), ['$_uid:carol', 'elsewhere:bob']);
        expect(await db.groupFileReach(_g), {_uid: (have: 1, of: 2)});
      });

      test('a member no longer on the list', () async {
        await db.keepGroupOwedTo(_g, ['me', 'bob', 'carol']);
        expect(left(), ['$_uid:carol', 'elsewhere:bob']);
        // and the list a control brings does the same
        final sync = bodyOf(
          sourceOf('lib/main.dart'),
          'Future<void> syncGroupMembers(',
        );
        expect(sync, contains('await keepGroupOwedTo(groupId, members);'));
      });

      test('a member the outbox finds gone', () async {
        await mem.delete(
          'group_members',
          where: 'group_id = ? AND halo_id = ?',
          whereArgs: [_g, 'dave'],
        );
        await tick();
        expect(io.took('dave'), isEmpty);
        expect(io.took('carol'), [0, 1, 2]);
        expect(left(), ['elsewhere:bob']);
      });

      test('a member past its tries is tried no more, yet still counted as '
          'not having it, until its session heals', () async {
        await mem.update(
          'group_media_owed',
          {'tries': kGroupOwedTries},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [_uid, 'dave'],
        );
        io.noSession.add('carol');
        await tick();
        expect(io.took('dave'), isEmpty);
        expect(left(), ['$_uid:carol', '$_uid:dave', 'elsewhere:bob']);
        expect(await db.groupFileReach(_g), {_uid: (have: 1, of: 3)});
        // a heal gives it one more go
        expect(await db.groupOwedDueNow('dave'), 1);
        expect(_owed(mem, 'dave')['tries'], kGroupOwedTries - 1);
        await tick();
        expect(io.took('dave'), [0, 1, 2]);
        expect(left(), ['$_uid:carol', 'elsewhere:bob']);
        expect(await db.groupFileReach(_g), {_uid: (have: 2, of: 3)});
      });

      test('leaving the group', () async {
        await app.leaveGroupAndAnnounce(_g);
        expect(left(), ['elsewhere:bob']);
      });

      test('the group taken back by its owner or ended', () async {
        await db.deleteGroup(_g);
        expect(left(), ['elsewhere:bob']);
      });

      test('the group cleared', () async {
        await db.clearGroupConversation(_g);
        expect(left(), ['elsewhere:bob']);
      });

      test('the message taken back', () async {
        await app.unsendInGroup(_g, _uid);
        expect(left(), ['elsewhere:bob']);
        expect(io.took('carol'), isEmpty);
      });

      test('the message burnt', () async {
        await mem.update(
          'messages',
          {'burn_at': 1},
          where: 'msg_uid = ?',
          whereArgs: [_uid],
        );
        await db.purgeExpiredBurns();
        expect(left(), ['elsewhere:bob']);
      });

      test('the message deleted here', () async {
        await db.deleteMessage(_uid);
        expect(left(), ['elsewhere:bob']);
      });

      test('a send ending after its row went leaves nothing', () async {
        await db.deleteMessage(_uid);
        await db.settleGroupOwed(
          _uid,
          _g,
          total: 3,
          tried: ['carol'],
          short: {
            'carol': {0},
          },
          sentTo: 3,
          first: true,
          now: 1,
        );
        expect(left(), ['elsewhere:bob']);
      });

      test('its file gone', () async {
        File(path).deleteSync();
        await tick();
        expect(left(), ['elsewhere:bob']);
      });
    });

    group('in each container', () {
      const hidden = 'grp00000000h';
      late MemDb vmem;
      late _Rows vault;

      setUp(() async {
        vmem = MemDb();
        vault = _Rows(vmem, HaloContainer.vault);
        await _person(vmem, 'carol');
        await _group(vmem, hidden, ['me', 'carol']);
        await fileRow(vmem, uid: 'hidden-file', group: hidden);
        await vmem.update(
          'messages',
          {'sent': 1},
          where: 'msg_uid = ?',
          whereArgs: ['hidden-file'],
        );
        await _owe(vmem, 'carol', uid: 'hidden-file', group: hidden);
      });

      test('a hidden group\'s goes while its vault is open', () async {
        app = await start(db, await Session.withVault(db, vault));
        await tick();
        expect(io.took('carol'), [0, 1, 2]);
        expect(vmem.rows('group_media_owed'), isEmpty);
      });

      test('only the container that holds the chat sends it', () async {
        // a move cut short leaves the everyday side a copy of its rows
        await _group(mem, hidden, ['me', 'carol']);
        await fileRow(mem, uid: 'hidden-file', group: hidden);
        await db.markSent('hidden-file');
        await _owe(
          mem,
          'carol',
          uid: 'hidden-file',
          group: hidden,
          have: '0-1',
        );
        app = await start(db, await Session.withVault(db, vault));
        await tick();
        expect(io.took('carol'), [0, 1, 2]);
        expect(vmem.rows('group_media_owed'), isEmpty);
        expect(mem.rows('group_media_owed'), hasLength(1));
      });

      test('and waits in it while it is shut', () async {
        await tick();
        expect(io.took('carol'), isEmpty);
        expect(_owed(vmem, 'carol', uid: 'hidden-file')['tries'], 0);
      });

      test('it moves with its group', () {
        expect(chatTables, contains('group_media_owed'));
        expect(
          sourceOf('lib/vault_life.dart'),
          contains("'group_media_owed': 'group_id = ?1',"),
        );
      });
    });
  });

  group('the wait', () {
    test('doubles from the first and stops growing at the longest', () {
      expect(groupOwedGap(0), kGroupOwedGap);
      expect(groupOwedGap(1), kGroupOwedGap * 2);
      var last = 0;
      for (var t = 0; t < kGroupOwedTries; t++) {
        final g = groupOwedGap(t);
        expect(g, greaterThanOrEqualTo(last));
        expect(g, lessThanOrEqualTo(kGroupOwedGapMost));
        last = g;
      }
      expect(groupOwedGap(kGroupOwedTries), kGroupOwedGapMost);
      // the tries last some days
      var span = 0;
      for (var t = 1; t < kGroupOwedTries; t++) {
        span += groupOwedGap(t);
      }
      expect(span, greaterThan(2 * 86400000));
    });

    group('over a store', () {
      late MemDb mem;
      late _Rows db;
      late List<Map<String, Set<int>>> asked;
      late String answer;

      Future<void> pass(int now) => resendGroupOwed(
        db,
        now: now,
        send: (uid, group, have, total) async {
          asked.add(have);
          return answer;
        },
      );

      setUp(() async {
        mem = MemDb();
        db = _Rows(mem);
        asked = [];
        answer = 'error: no session';
        await _owe(mem, 'carol', have: '0', since: 0, nextAt: 100);
      });

      test('is kept between tries, and longer each time', () async {
        await pass(99);
        expect(asked, isEmpty);
        var at = 100;
        for (var k = 1; k <= 12; k++) {
          await pass(at);
          final r = _owed(mem, 'carol');
          expect(r['tries'], k);
          expect(r['next_at'], at + groupOwedGap(k));
          at = r['next_at'] as int;
        }
        expect(asked, hasLength(12));
        expect(asked.first, {
          'carol': {0},
        });
      });

      test('is tried no more after its tries, and keeps its row', () async {
        await mem.update(
          'group_media_owed',
          {'tries': kGroupOwedTries - 1},
          where: 'member = ?',
          whereArgs: ['carol'],
        );
        await pass(100);
        expect(asked, hasLength(1));
        await pass(1 << 50);
        expect(asked, hasLength(1));
        expect(_owed(mem, 'carol')['tries'], kGroupOwedTries);
        // and is never due again
        expect(await db.dueGroupOwed(1 << 50), isEmpty);
      });

      test(
        'a store that hands over a member past its tries: it is not tried',
        () async {
          final past = GroupOwed(
            msgUid: _uid,
            groupId: _g,
            member: 'dave',
            total: 3,
            have: const {},
            since: 0,
            tries: kGroupOwedTries,
          );
          final store = _AllDue([past]);
          await resendGroupOwed(
            store,
            now: 1,
            send: (uid, group, have, total) async {
              asked.add(have);
              return 'ok';
            },
          );
          expect(asked, isEmpty);
          expect(store.tried, isEmpty);
        },
      );

      test('days with no pass cost it no try', () async {
        // the phone was off or had no route since the send
        await pass(1 << 50);
        expect(asked, hasLength(1));
        expect(_owed(mem, 'carol')['tries'], 1);
      });

      test('is let go when its row is gone', () async {
        answer = 'gone';
        await pass(100);
        expect(mem.rows('group_media_owed'), isEmpty);
      });

      test('waits while another send has the row', () async {
        mediaInflight.add(_uid);
        addTearDown(() => mediaInflight.remove(_uid));
        await pass(100);
        expect(asked, isEmpty);
        expect(_owed(mem, 'carol')['tries'], 0);
      });
    });
  });

  group('the bubble', () {
    tearDown(() => setL10nLocale(const Locale('en')));

    test('says how many have it, in every form', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.groupChatFileReach(3, 4), 'Sent · 3 of 4 have it');
      expect(en.groupChatFileReach(1, 4), 'Sent · 1 of 4 has it');
      expect(en.groupChatFileReach(0, 4), 'Sent · on its way');
      expect(
        en.groupChatFileReach(1200, 1500),
        'Sent · 1,200 of 1,500 have it',
      );
      final ru = lookupAppLocalizations(const Locale('ru'));
      expect(ru.groupChatFileReach(2, 5), 'Отправлено · есть у 2 из 5');
      expect(ru.groupChatFileReach(0, 5), 'Отправлено · в пути');
      final de = lookupAppLocalizations(const Locale('de'));
      expect(de.groupChatFileReach(1, 3), 'Gesendet · 1 von 3 hat es');
      expect(de.groupChatFileReach(2, 3), 'Gesendet · 2 von 3 haben es');
      final fa = lookupAppLocalizations(const Locale('fa'));
      expect(fa.groupChatFileReach(1, 3), contains('دریافت کرده'));
      expect(fa.groupChatFileReach(2, 3), contains('کرده\u200cاند'));
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        final none = l.groupChatFileReach(0, 4);
        for (final n in [1, 2, 3, 5, 11, 21, 100, 1000]) {
          final s = l.groupChatFileReach(n, n + 1);
          expect(s, isNot(contains('{')), reason: '$locale $n');
          expect(s, isNot(equals(none)), reason: '$locale $n');
          expect(s, isNot(contains('\u2014')), reason: '$locale $n');
        }
      }
    });

    test('arabic and persian keep their numbers whole in the line', () {
      for (final code in ['ar', 'fa']) {
        final s = lookupAppLocalizations(Locale(code)).groupChatFileReach(2, 3);
        expect('\u2068'.allMatches(s).length, 2, reason: code);
        expect('\u2069'.allMatches(s).length, 2, reason: code);
      }
    });

    Widget pill(int have, int of, {bool still = false, Locale? locale}) =>
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: still),
            child: Scaffold(
              body: Center(
                child: GrowSwap(
                  child: FileReachPill(
                    key: ValueKey('reach-$have-$of'),
                    have: have,
                    of: of,
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('changes smoothly as more have it', (t) async {
      await t.pumpWidget(pill(2, 4));
      expect(find.text('Sent · 2 of 4 have it'), findsOneWidget);
      await t.pumpWidget(pill(3, 4));
      await t.pump(const Duration(milliseconds: 60));
      // both for a moment, the old one on its way out
      expect(find.text('Sent · 2 of 4 have it'), findsOneWidget);
      expect(find.text('Sent · 3 of 4 have it'), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('Sent · 2 of 4 have it'), findsNothing);
      expect(find.text('Sent · 3 of 4 have it'), findsOneWidget);
      expect(find.bySemanticsLabel('Sent · 3 of 4 have it'), findsOneWidget);
    });

    testWidgets('at once when the phone asks for no movement', (t) async {
      await t.pumpWidget(pill(2, 4, still: true));
      await t.pumpWidget(pill(3, 4, still: true));
      await t.pump();
      expect(find.text('Sent · 2 of 4 have it'), findsNothing);
      expect(find.text('Sent · 3 of 4 have it'), findsOneWidget);
    });

    testWidgets('reads right to left in arabic', (t) async {
      setL10nLocale(const Locale('ar'));
      await t.pumpWidget(pill(2, 3, locale: const Locale('ar')));
      final words = l10n.groupChatFileReach(2, 3);
      final text = find.text(words);
      expect(text, findsOneWidget);
      expect(Directionality.of(t.element(text)), TextDirection.rtl);
      expect(t.takeException(), isNull);
    });

    Future<_ScreenDb> openScreen(WidgetTester t, {bool still = false}) async {
      phone(t);
      final db = _ScreenDb({_uid: (have: 1, of: 3)});
      useDatabasesForTest(db, Session(db));
      appState.sendModeForTest = 'private';
      appState.setTorStatusForTest(TorStatus.off);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await t.pumpWidget(app(const GroupChatScreen(groupId: _g), still: still));
      await t.pump(const Duration(seconds: 1));
      return db;
    }

    Future<void> closeScreen(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    }

    for (final still in [false, true]) {
      testWidgets('follows the members live in the open chat'
          '${still ? ', at once with no movement' : ''}', (t) async {
        final db = await openScreen(t, still: still);
        expect(find.text('Sent · 1 of 3 has it'), findsOneWidget);

        db.reach = {_uid: (have: 2, of: 3)};
        groupOwedTick.value++;
        await t.pump();
        await t.pump(Duration(milliseconds: still ? 0 : 400));
        await t.pump(Duration(milliseconds: still ? 0 : 400));
        expect(find.text('Sent · 1 of 3 has it'), findsNothing);
        expect(find.text('Sent · 2 of 3 have it'), findsOneWidget);

        // all have it: the plain sent state
        db.reach = {};
        groupOwedTick.value++;
        await t.pump();
        await t.pump(Duration(milliseconds: still ? 0 : 400));
        await t.pump(Duration(milliseconds: still ? 0 : 400));
        expect(find.textContaining('Sent · '), findsNothing);
        await closeScreen(t);
      });
    }

    test('its colour is the app\'s amber, never a grey', () {
      final src = sourceOf('lib/widgets/file_reach.dart');
      expect(src, contains('color: HaloColors.amber)'));
      expect(src, isNot(contains('text2')));
      expect(src, isNot(contains('text3')));
    });

    test('sits under our bubble once it is sent, until all have it', () {
      final screen = sourceOf('lib/screens/group_chat_screen.dart');
      final at = screen.indexOf('FileReachPill(have: r.have, of: r.of)');
      expect(at, greaterThan(0));
      final swap = screen.lastIndexOf('GrowSwap(', at);
      expect(screen.substring(swap, at), contains('!m.pending'));
      expect(screen, contains('groupOwedTick.addListener(_reachMoved);'));
      expect(screen, contains('groupOwedTick.removeListener(_reachMoved);'));
    });
  });
}
