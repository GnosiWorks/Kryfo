// SPDX-License-Identifier: GPL-3.0-or-later
// a group's screenshot block between phones: its admin's turn goes to
// every member through the lanes, a member's does nothing, a word is taken
// from the admin alone, a member answers with its bits once per stamp and
// on joining, the upgrade tells each admin once, and the admin works out
// again who can when someone writes, comes or goes. the app's receive and
// send paths on its own schema, in the host's sqlite; signal and the wire
// are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/typing.dart' show kCapGroupShots;
import 'package:kryfo/chat_shots.dart' show kShotsByMe, kShotsByThem;
import 'package:kryfo/group_shots.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        searchTables,
        useDatabasesForTest,
        useEngineForTest,
        AppStateGroupLanes,
        AppStateGroupShots,
        groupCapsGap,
        groupShotsEvery,
        AppStateGroups,
        AppStateReceive,
        AppStateRefresh,
        AppStateRoute,
        AppStateScreen;
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

class _Io extends ArrivalIo {
  List<UnwrappedMessage> to(String member) => [
    for (final (_, c) in sent)
      if (c.startsWith('to $member '))
        unwrapMessage(c.substring('to $member '.length)),
  ];

  List<GroupControl> ctls(String member, String type) => [
    for (final m in to(member))
      if (m.groupControl?.type == type) m.groupControl!,
  ];

  List<UnwrappedMessage> nudges(String member) => [
    for (final m in to(member))
      if (m.shotsNudge) m,
  ];
}

const _theirs = 'g1'; // bob runs it, me and carol in it
const _mine = 'g2'; // this phone runs it, bob and carol in it

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;
  late Directory docs;
  late SqliteMem s;
  late _Rows db;
  late _Io io;
  late AppState app;
  var n = 0;

  Future<AppState> start() async {
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useDatabasesForTest(db, Session(db));
    return AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
  }

  Future<void> addGroup(String id, {required String admin}) async {
    await s.insert('groups', {
      'group_id': id,
      'name': 'Friends',
      'created_at': 1,
      'is_admin': admin == 'me' ? 1 : 0,
      'admin_id': admin,
    });
    for (final (i, m) in ['me', 'bob', 'carol'].indexed) {
      await s.insert('group_members', {
        'group_id': id,
        'halo_id': m,
        'joined_at': i,
      });
    }
  }

  setUp(() async {
    if (skip != null) return;
    groupShotsEvery = Duration.zero;
    groupCapsGap = () => Duration.zero;
    docs = Directory.systemTemp.createTempSync('group_shots');
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
    for (final who in ['bob', 'carol', 'dan']) {
      await s.insert('contacts', {
        'halo_id': who,
        'onion': 'o-$who',
        'xpub': 'x-$who',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
        'back_paired': 1,
      });
    }
    await addGroup(_theirs, admin: 'bob');
    await addGroup(_mine, admin: 'me');
    db = _Rows(s);
    io = _Io();
    app = await start();
    await app.refreshGroups();
  });

  tearDown(() async {
    if (skip != null) return;
    await s.close();
    docs.deleteSync(recursive: true);
  });

  Future<void> comes(String from, String wire) async {
    final c = 'c-${n++}';
    io.opens[c] = (from, wire);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  // what an older app sends: no bits on it
  String old(String wire) => wire.replaceFirst(RegExp(r',"cp":\[[^\]]*\]'), '');

  Future<String> said(
    String uid, {
    String by = 'bob',
    String g = _theirs,
    GroupShotsWord? shots,
  }) => wrapMessage(
    'see you at the lake',
    msgUid: uid,
    groupId: g,
    groupShots: shots,
    sender: asSender(by),
  );

  Future<String> ctl(
    GroupControl gc, {
    String by = 'bob',
    String g = _theirs,
  }) => wrapMessage('', groupId: g, groupControl: gc, sender: asSender(by));

  Future<GroupShots> shotsOf(String g) async => GroupShots.ofRow(
    (await s.query('groups', where: 'group_id = ?', whereArgs: [g])).single,
  );

  Future<void> canBlock(String who, {int at = 5}) => s.update(
    'contacts',
    {'caps': 'gs,ty', 'caps_at': at},
    where: 'halo_id = ?',
    whereArgs: [who],
  );

  Future<String> capsOf(String who) async =>
      (await s.query(
            'contacts',
            where: 'halo_id = ?',
            whereArgs: [who],
          )).single['caps']
          as String;

  final later = DateTime.now().millisecondsSinceEpoch + 60000;

  group('the admin turning it', () {
    test('goes to every other member, and waits on anyone not heard '
        'from', () async {
      await canBlock('bob');
      await app.setGroupShots(_mine, true);
      await app.ctlPassForTest;
      for (final m in ['bob', 'carol']) {
        final c = io.ctls(m, 'shots');
        expect(c, hasLength(1), reason: m);
        expect(c.single.shots!.on, isTrue);
        expect(c.single.shots!.all, isFalse);
      }
      final row = await shotsOf(_mine);
      expect(row.on, isTrue);
      expect(row.all, isFalse);
      expect(row.blocking, isTrue);
      expect(row.forAll, isFalse);
      expect(row.line, kGroupLineOnWait);
      expect(row.by, kShotsByMe);
      // the list knows it before any screen reads the rows
      expect(app.shotsBlocksGroup(_mine), isTrue);
      expect(
        app.groups.singleWhere((g) => g.groupId == _mine).shotsForAll,
        isFalse,
      );
      // its shade goes at once
      expect(io.unrang, contains('group:$_mine'));
      // the words for older apps go to the one not heard from alone
      expect(io.nudges('bob'), isEmpty);
      final nudge = io.nudges('carol').single;
      expect(nudge.message, l10n.groupShotsOldNotice);
      expect(nudge.msgUid, isNotNull);
      expect(nudge.groupId, _mine);
    }, skip: skip);

    test('with everyone able, it is on for everyone at once and nobody '
        'is nudged', () async {
      await canBlock('bob');
      await canBlock('carol');
      await app.setGroupShots(_mine, true);
      await app.ctlPassForTest;
      expect(io.ctls('carol', 'shots').single.shots!.all, isTrue);
      expect((await shotsOf(_mine)).forAll, isTrue);
      expect((await shotsOf(_mine)).line, kGroupLineOn);
      expect(io.nudges('bob'), isEmpty);
      expect(io.nudges('carol'), isEmpty);
      // off goes at once, for everyone
      await app.setGroupShots(_mine, false);
      await app.ctlPassForTest;
      expect(io.ctls('bob', 'shots').last.shots!.on, isFalse);
      expect((await shotsOf(_mine)).blocking, isFalse);
      expect((await shotsOf(_mine)).line, kGroupLineOff);
    }, skip: skip);

    test('a member\'s switch does nothing', () async {
      await app.setGroupShots(_theirs, true);
      await app.ctlPassForTest;
      expect((await shotsOf(_theirs)).on, isFalse);
      expect(io.ctls('bob', 'shots'), isEmpty);
      expect(io.ctls('carol', 'shots'), isEmpty);
    }, skip: skip);

    test('the admin\'s messages carry it, and a room\'s never', () async {
      await canBlock('bob');
      await canBlock('carol');
      await app.setGroupShots(_mine, true);
      await app.ctlPassForTest;
      io.sent.clear();
      await app.sendToGroup(_mine, 'hi');
      final w = io.to('bob').single.groupShots;
      expect(w, isNotNull);
      expect(w!.on, isTrue);
      expect(w.all, isTrue);
      // a member's messages carry none
      io.sent.clear();
      await app.sendToGroup(_theirs, 'hello');
      expect(io.to('bob').single.groupShots, isNull);
    }, skip: skip);
  });

  group('a member taking it', () {
    test('from the admin alone, and answers with its bits once per '
        'stamp', () async {
      final w = GroupShotsWord(on: true, all: false, at: later);
      await comes(
        'carol',
        await ctl(
          GroupControl(type: 'shots', shots: w),
          by: 'carol',
        ),
      );
      expect((await shotsOf(_theirs)).on, isFalse);
      await comes('bob', await ctl(GroupControl(type: 'shots', shots: w)));
      final row = await shotsOf(_theirs);
      expect(row.on, isTrue);
      expect(row.blocking, isTrue);
      expect(row.forAll, isFalse);
      expect(row.by, kShotsByThem);
      expect(row.line, kGroupLineOnWait);
      expect(io.unrang, contains('group:$_theirs'));
      await app.ctlPassForTest;
      expect(io.ctls('bob', 'caps'), hasLength(1));
      expect(io.to('bob').last.caps, contains(kCapGroupShots));
      expect(io.ctls('carol', 'caps'), isEmpty);
      // the same word again, on a message: no second answer
      await comes('bob', await said('m1', shots: w));
      await app.ctlPassForTest;
      expect(io.ctls('bob', 'caps'), hasLength(1));
      // on for everyone: nothing owed
      await comes(
        'bob',
        await said(
          'm2',
          shots: GroupShotsWord(on: true, all: true, at: later + 1),
        ),
      );
      await app.ctlPassForTest;
      expect(io.ctls('bob', 'caps'), hasLength(1));
      expect((await shotsOf(_theirs)).forAll, isTrue);
      expect((await shotsOf(_theirs)).line, kGroupLineStarted);
    }, skip: skip);

    test('heals from the admin\'s messages, never a member\'s', () async {
      final w = GroupShotsWord(on: true, all: true, at: later);
      await comes('carol', await said('c1', by: 'carol', shots: w));
      expect((await shotsOf(_theirs)).on, isFalse);
      await comes('bob', await said('b1', shots: w));
      expect((await shotsOf(_theirs)).forAll, isTrue);
      // an older word changes nothing
      await comes(
        'bob',
        await said(
          'b2',
          shots: GroupShotsWord(on: false, all: false, at: later - 10),
        ),
      );
      expect((await shotsOf(_theirs)).on, isTrue);
    }, skip: skip);

    test('a fresh create is answered with this app\'s bits', () async {
      // a creator with a person's id: the roster keeps only those
      const ann = 'amber-fox-run';
      await s.insert('contacts', {
        'halo_id': ann,
        'onion': 'o-$ann',
        'xpub': 'x-$ann',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
        'back_paired': 1,
      });
      await comes(
        ann,
        await ctl(
          const GroupControl(
            type: 'create',
            name: 'New',
            members: [ann, 'me'],
            participants: [
              {'h': ann, 'o': 'o-$ann', 'x': 'x-$ann'},
            ],
          ),
          by: ann,
          g: 'g3',
        ),
      );
      await app.ctlPassForTest;
      final caps = io.ctls(ann, 'caps');
      expect(caps, hasLength(1));
      expect(io.to(ann).last.groupId, 'g3');
      expect(io.to(ann).last.caps, contains(kCapGroupShots));
      // a create that carries the block takes it
      await comes(
        ann,
        await ctl(
          GroupControl(
            type: 'create',
            name: 'Newer',
            members: const [ann, 'me'],
            shots: GroupShotsWord(on: true, all: true, at: later),
          ),
          by: ann,
          g: 'g4',
        ),
      );
      expect((await shotsOf('g4')).forAll, isTrue);
    }, skip: skip);

    test('the words for older versions are never kept', () async {
      await comes(
        'bob',
        await wrapMessage(
          l10n.groupShotsOldNotice,
          msgUid: 'n1',
          groupId: _theirs,
          shotsNudge: true,
          sender: asSender('bob'),
        ),
      );
      expect(
        await s.rawQuery("SELECT 1 FROM messages WHERE msg_uid = 'n1'"),
        isEmpty,
      );
      expect(io.rang, isEmpty);
    }, skip: skip);
  });

  group('the update', () {
    test('tells each admin once, never for a room or a group this phone '
        'runs', () async {
      await s.insert('groups', {
        'group_id': 'r1',
        'name': 'Room',
        'created_at': 1,
        'is_admin': 0,
        'admin_id': 'bob',
        'room_pub': 'a' * 64,
        'expires_at': later,
      });
      await s.insert('group_members', {
        'group_id': 'r1',
        'halo_id': 'bob',
        'joined_at': 1,
      });
      await app.announceCapsForTest(db);
      await app.ctlPassForTest;
      final caps = [
        for (final m in io.to('bob'))
          if (m.groupControl?.type == 'caps') m.groupId,
      ];
      expect(caps, [_theirs]);
      expect(io.ctls('carol', 'caps'), isEmpty);
      await app.announceCapsForTest(db);
      await app.ctlPassForTest;
      expect(io.ctls('bob', 'caps'), hasLength(1));
    }, skip: skip);

    test('an admin who left hears nothing', () async {
      await s.delete(
        'group_members',
        where: 'group_id = ? AND halo_id = ?',
        whereArgs: [_theirs, 'bob'],
      );
      await app.announceCapsForTest(db);
      await app.ctlPassForTest;
      expect(io.ctls('bob', 'caps'), isEmpty);
    }, skip: skip);
  });

  group('the admin working out who can', () {
    test('it starts once the last one writes from an app that can, and '
        'pauses when one writes from an older app', () async {
      await app.setGroupShots(_mine, true);
      await app.ctlPassForTest;
      expect((await shotsOf(_mine)).forAll, isFalse);
      await comes('bob', await said('b1', by: 'bob', g: _mine));
      expect(await capsOf('bob'), contains(kCapGroupShots));
      expect((await shotsOf(_mine)).forAll, isFalse);
      // a caps answer says it too
      await comes(
        'carol',
        await ctl(
          const GroupControl(type: 'caps'),
          by: 'carol',
          g: _mine,
        ),
      );
      await app.ctlPassForTest;
      final row = await shotsOf(_mine);
      expect(row.forAll, isTrue);
      expect(row.line, kGroupLineStarted);
      expect(io.ctls('carol', 'shots').last.shots!.all, isTrue);
      expect(io.ctls('bob', 'shots').last.shots!.all, isTrue);
      expect(
        app.groups.singleWhere((g) => g.groupId == _mine).shotsForAll,
        isTrue,
      );
      // back on an older app: its next message pauses the group
      await comes('carol', old(await said('c2', by: 'carol', g: _mine)));
      await app.ctlPassForTest;
      expect(await capsOf('carol'), '');
      expect((await shotsOf(_mine)).forAll, isFalse);
      expect((await shotsOf(_mine)).line, kGroupLinePaused);
      expect((await shotsOf(_mine)).blocking, isTrue);
      expect(io.ctls('bob', 'shots').last.shots!.all, isFalse);
    }, skip: skip);

    test('adding someone unknown pauses it; removing them starts it '
        'again', () async {
      await canBlock('bob');
      await canBlock('carol');
      await app.setGroupShots(_mine, true);
      expect((await shotsOf(_mine)).forAll, isTrue);
      await app.addMembersToGroup(_mine, ['dan']);
      await app.ctlPassForTest;
      expect((await shotsOf(_mine)).forAll, isFalse);
      expect((await shotsOf(_mine)).line, kGroupLinePaused);
      // dan's create carries the block, then the pause follows it
      final dan = io.to('dan');
      expect(dan.first.groupControl!.type, 'create');
      expect(dan.first.groupControl!.shots!.on, isTrue);
      expect(io.ctls('dan', 'shots').last.shots!.all, isFalse);
      await app.removeMembersFromGroup(_mine, ['dan']);
      await app.ctlPassForTest;
      expect((await shotsOf(_mine)).forAll, isTrue);
      expect((await shotsOf(_mine)).line, kGroupLineStarted);
    }, skip: skip);

    test('a member who leaves is waited for no more', () async {
      await canBlock('bob');
      await app.setGroupShots(_mine, true);
      expect((await shotsOf(_mine)).forAll, isFalse);
      await comes(
        'carol',
        await ctl(
          const GroupControl(type: 'leave'),
          by: 'carol',
          g: _mine,
        ),
      );
      await app.ctlPassForTest;
      expect((await shotsOf(_mine)).forAll, isTrue);
      expect(io.ctls('bob', 'shots').last.shots!.all, isTrue);
    }, skip: skip);

    test('a group of the admin alone is on for everyone at once', () async {
      await s.delete(
        'group_members',
        where: 'group_id = ? AND halo_id != ?',
        whereArgs: [_mine, 'me'],
      );
      await app.setGroupShots(_mine, true);
      expect((await shotsOf(_mine)).forAll, isTrue);
    }, skip: skip);
  });

  group('what the admin sends, and how often', () {
    test('a member flipping their list moves the word once a window, as '
        'the newest state, and a move back sends nothing', () async {
      groupShotsEvery = const Duration(seconds: 2);
      await canBlock('bob');
      await app.setGroupShots(_mine, true);
      await app.ctlPassForTest;
      expect(io.ctls('bob', 'shots'), hasLength(1));
      // carol can, then cannot, then can again, inside the window
      await comes(
        'carol',
        await ctl(
          const GroupControl(type: 'caps'),
          by: 'carol',
          g: _mine,
        ),
      );
      await comes('carol', old(await said('c1', by: 'carol', g: _mine)));
      await comes('carol', await said('c2', by: 'carol', g: _mine));
      await app.ctlPassForTest;
      expect(io.ctls('bob', 'shots'), hasLength(1));
      // the window ends: the newest state goes, once
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      await app.ctlPassForTest;
      final words = io.ctls('bob', 'shots');
      expect(words, hasLength(2));
      expect(words.last.shots!.all, isTrue);
      // back to not all and back again inside the next window: nothing
      await comes('carol', old(await said('c3', by: 'carol', g: _mine)));
      await comes('carol', await said('c4', by: 'carol', g: _mine));
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      await app.ctlPassForTest;
      expect(io.ctls('bob', 'shots'), hasLength(2));
    }, skip: skip);

    test(
      'the old-version words go once to each member, not on every turn',
      () async {
        await app.setGroupShots(_mine, true);
        await app.setGroupShots(_mine, false);
        await app.setGroupShots(_mine, true);
        await app.ctlPassForTest;
        expect(io.nudges('carol'), hasLength(1));
        expect(io.nudges('bob'), hasLength(1));
      },
      skip: skip,
    );

    test('a list written more than a day ahead is not taken', () async {
      final ahead = DateTime.now()
          .add(const Duration(days: 2))
          .millisecondsSinceEpoch;
      await comes(
        'carol',
        await wrapMessage(
          'from the future',
          msgUid: 'f1',
          groupId: _mine,
          sender: asSender('carol'),
          writtenAt: ahead,
        ),
      );
      expect(await capsOf('carol'), '');
    }, skip: skip);
  });
}
