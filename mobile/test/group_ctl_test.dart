// SPDX-License-Identifier: GPL-3.0-or-later
// a group's controls are queued per member and go in the order they were
// made, after a route that was down or a restart too: a member never gets
// a message of the group before the create that makes it there. a text, a
// poll or a sticker that missed a member reads sent once someone has it,
// is owed to the rest the way a file is, and its bubble says how many have
// it until they all do. the database methods and the app's sends are the
// real ones, over rows kept in maps; signal and the wire are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/group_media_send.dart' show kGroupOwedTries;
import 'package:kryfo/main.dart'
    show AppState, HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/outbox.dart';
import 'package:kryfo/polls.dart' show PollSpec;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'source_body.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // its or-clause is past what the map rows read
  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async => const [];
}

// signal and the wire: a member with no session has no stored bundle
// either, and a member's route can be down
class _Io extends ArrivalIo {
  final noSession = <String>{};
  final cut = <String>{};

  @override
  Future<bool> hasSession(String peer) async => !noSession.contains(peer);

  @override
  Future<String> relaySend(String xPub, String cipher) async {
    if (cut.contains(cipher.split(' ')[1])) return 'error: down';
    return super.relaySend(xPub, cipher);
  }

  List<UnwrappedMessage> to(String member) => [
    for (final (_, c) in sent)
      if (c.startsWith('to $member '))
        unwrapMessage(c.substring('to $member '.length)),
  ];

  // what went to [member], in order: a control by its type, a message by
  // its text
  List<String> got(String member) => [
    for (final m in to(member))
      m.groupControl == null ? m.message : 'ctl:${m.groupControl!.type}',
  ];
}

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
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

// a group someone else made, with me in it
Future<void> _theirGroup(MemDb mem, String id, List<String> members) async {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;
  late _Io io;
  late AppState app;

  Future<AppState> start() async {
    final d = _Rows(mem);
    db = d;
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useDatabasesForTest(d, Session(d));
    return AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
  }

  // the outbox's tick, and the passes it starts
  Future<void> tick(AppState a) async {
    await a.drainOutbox();
    await a.ctlPassForTest;
    await a.owedPassForTest;
    await a.ctlPassForTest;
  }

  // every wait is up
  Future<void> due({bool controls = true}) async {
    for (final t in ['group_ctl_out', 'group_media_owed']) {
      if (!controls && t == 'group_ctl_out') continue;
      for (final r in mem.rows(t)) {
        await mem.update(
          t,
          {'next_at': 0},
          where: t == 'group_ctl_out' ? 'id = ?' : 'msg_uid = ? AND member = ?',
          whereArgs: t == 'group_ctl_out'
              ? [r['id']]
              : [r['msg_uid'], r['member']],
        );
      }
    }
  }

  List<String> queued(String member) => [
    for (final r in mem.rows('group_ctl_out'))
      if (r['member'] == member) r['ctl'] as String,
  ];

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('group_ctl');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    useEngineForTest(_Engine());
    mem = MemDb();
    io = _Io();
    for (final p in ['bob', 'carol', 'dave']) {
      await _person(mem, p);
    }
    app = await start();
  });

  tearDown(() => docs.deleteSync(recursive: true));

  group('a control', () {
    test('a group made with no route reaches its members once the route is '
        'back, after a restart too', () async {
      io.cut.addAll(['bob', 'carol']);
      final g = await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      await app.ctlPassForTest;
      expect(io.got('bob'), isEmpty);
      expect(queued('bob'), hasLength(1));
      expect(queued('carol'), hasLength(1));
      final row = mem.rows('group_ctl_out').first;
      expect(row['tries'], 1);
      expect(
        row['next_at'] as int,
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );

      // before its wait is up nothing goes
      io.cut.clear();
      await tick(app);
      expect(io.got('bob'), isEmpty);

      // a restart: nothing in memory, the rows on disk
      app = await start();
      await due();
      await tick(app);
      for (final m in ['bob', 'carol']) {
        expect(io.got(m), ['ctl:create'], reason: m);
        final gc = io.to(m).single.groupControl!;
        expect(gc.members, ['me', 'bob', 'carol']);
        expect(gc.name, 'Trip');
        expect(gc.stamp, isNotNull);
      }
      expect(io.to('bob').single.groupId, g);
      expect(mem.rows('group_ctl_out'), isEmpty);
    });

    test('a member gets them in the order they were made, each once the one '
        'before went', () async {
      io.cut.add('carol');
      final g = await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      await app.renameGroupAndAnnounce(g, 'Trip two');
      await app.addMembersToGroup(g, ['dave']);
      await app.ctlPassForTest;
      expect(io.got('bob'), ['ctl:create', 'ctl:rename', 'ctl:add']);
      expect(io.got('dave'), ['ctl:create']);
      expect(io.got('carol'), isEmpty);
      // only the first was tried: the rest wait behind it
      expect(
        [for (final r in mem.rows('group_ctl_out')) r['tries']],
        [1, 0, 0],
      );

      io.cut.clear();
      await due();
      await tick(app);
      expect(io.got('carol'), ['ctl:create', 'ctl:rename', 'ctl:add']);
      expect(io.got('bob'), ['ctl:create', 'ctl:rename', 'ctl:add']);
      expect(mem.rows('group_ctl_out'), isEmpty);
    });

    test('a newer roster is stamped above the one before', () async {
      final g = await app.createGroupAndAnnounce('Trip', ['bob']);
      await app.ctlPassForTest;
      await app.addMembersToGroup(g, ['carol']);
      await app.ctlPassForTest;
      final first = io.to('bob').first.groupControl!.stamp!;
      final second = io.to('carol').single.groupControl!.stamp!;
      expect(second, greaterThan(first));
      expect(io.to('carol').single.groupControl!.members, [
        'me',
        'bob',
        'carol',
      ]);
    });

    test('a remove reaches the member it takes out, once it can', () async {
      final g = await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      await app.ctlPassForTest;
      io.cut.add('carol');
      await app.removeMembersFromGroup(g, ['carol']);
      await app.ctlPassForTest;
      expect(io.got('bob'), ['ctl:create', 'ctl:remove']);
      expect(io.got('carol'), ['ctl:create']);
      io.cut.clear();
      await due();
      await tick(app);
      expect(io.got('carol'), ['ctl:create', 'ctl:remove']);
      expect(io.to('carol').last.groupControl!.members, ['carol']);
      expect(mem.rows('group_ctl_out'), isEmpty);
    });

    test('one for a member no longer in the group is let go', () async {
      io.cut.add('carol');
      final g = await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      await app.renameGroupAndAnnounce(g, 'Trip two');
      await app.ctlPassForTest;
      // carol leaves before any of it got to her
      await db.removeGroupMember(g, 'carol');
      io.cut.clear();
      await due();
      await tick(app);
      expect(io.got('carol'), isEmpty);
      expect(mem.rows('group_ctl_out'), isEmpty);
    });

    test('a member whose session heals gets what waited at once', () async {
      io.noSession.add('carol');
      await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      await app.ctlPassForTest;
      expect(io.got('carol'), isEmpty);
      // its wait is far off
      expect(
        mem.rows('group_ctl_out').single['next_at'] as int,
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );
      io.noSession.clear();
      await app.owedDueForTest('carol');
      await app.ctlPassForTest;
      expect(io.got('carol'), ['ctl:create']);
    });

    test('a try a send forces costs it none of its tries', () async {
      io.cut.add('carol');
      final g = await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      await app.ctlPassForTest;
      expect(mem.rows('group_ctl_out').single['tries'], 1);
      // every send, and every owed pass after, tries carol's create first
      for (var i = 0; i < 4; i++) {
        await app.sendToGroup(g, 'm$i', msgUid: 'm$i');
      }
      await due(controls: false);
      await tick(app);
      expect(io.got('carol'), isEmpty);
      expect(mem.rows('group_ctl_out').single['tries'], 1);
    });

    test('a create past its tries is kept, and still goes before what '
        'follows it', () async {
      io.cut.add('carol');
      final g = await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      await app.ctlPassForTest;
      await app.sendToGroup(g, 'early', msgUid: 'e1');
      // days of passes on its own schedule
      final id = mem.rows('group_ctl_out').single['id'];
      await mem.update(
        'group_ctl_out',
        {'tries': kGroupOwedTries},
        where: 'id = ?',
        whereArgs: [id],
      );
      await due();
      await tick(app);
      expect(queued('carol'), hasLength(1));
      expect(mem.rows('group_ctl_out').single['tries'], kGroupOwedTries);
      expect(io.got('carol'), isEmpty);

      // carol is back: our next send takes the create to her first
      io.cut.clear();
      expect(await app.sendToGroup(g, 'back', msgUid: 'b1'), isTrue);
      expect(io.got('carol'), ['ctl:create', 'back']);
      expect(queued('carol'), isEmpty);
      await due();
      await tick(app);
      expect(io.got('carol'), ['ctl:create', 'back', 'early']);
      expect(mem.rows('group_media_owed'), isEmpty);
    });

    test('any other control past its tries is let go', () async {
      final g = await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      await app.ctlPassForTest;
      io.cut.add('carol');
      await app.renameGroupAndAnnounce(g, 'Trip two');
      await app.ctlPassForTest;
      final id = mem.rows('group_ctl_out').single['id'];
      await mem.update(
        'group_ctl_out',
        {'tries': kGroupOwedTries},
        where: 'id = ?',
        whereArgs: [id],
      );
      io.cut.clear();
      await due();
      await tick(app);
      expect(io.got('carol'), ['ctl:create']);
      expect(mem.rows('group_ctl_out'), isEmpty);
    });

    test('a quiet session queues nothing', () {
      final src = sourceOf('lib/main.dart');
      for (final fn in [
        'Future<String> createGroupAndAnnounce(',
        'Future<void> addMembersToGroup(',
        'Future<void> removeMembersFromGroup(',
        'Future<void> renameGroupAndAnnounce(',
        'Future<void> leaveGroupAndAnnounce(',
      ]) {
        final body = bodyOf(src, fn);
        expect(body, contains('sessionQuiet'), reason: fn);
        expect(body, contains('_queueControl('), reason: fn);
        expect(body, isNot(contains('_sendGroupEnvelope(')), reason: fn);
      }
    });
  });

  group('a message', () {
    test('to a member still waiting for the group goes after its create, '
        'never before', () async {
      io.cut.add('carol');
      final g = await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      await app.ctlPassForTest;
      expect(await app.sendToGroup(g, 'meet at 6', msgUid: 't1'), isTrue);
      expect(io.got('bob'), ['ctl:create', 'meet at 6']);
      expect(io.got('carol'), isEmpty);
      // sent, and owed to carol
      expect(mem.rows('messages').single['sent'], 1);
      expect(await db.groupFileReach(g), {'t1': (have: 1, of: 2)});

      // the message's wait is up before the create's: the create still
      // goes first
      io.cut.clear();
      await due(controls: false);
      await tick(app);
      expect(io.got('carol'), ['ctl:create', 'meet at 6']);
      expect(io.got('bob'), ['ctl:create', 'meet at 6']);
      expect(mem.rows('group_media_owed'), isEmpty);
      expect(await db.groupFileReach(g), isEmpty);
    });

    test('right after the group is made goes to everyone at once', () async {
      final g = await app.createGroupAndAnnounce('Trip', ['bob', 'carol']);
      // the create may still be on its way
      expect(await app.sendToGroup(g, 'hi all', msgUid: 't2'), isTrue);
      await app.ctlPassForTest;
      expect(io.got('bob'), ['ctl:create', 'hi all']);
      expect(io.got('carol'), ['ctl:create', 'hi all']);
      expect(mem.rows('group_media_owed'), isEmpty);
    });

    test('a poll and a sticker a member missed reach it as they were, once '
        'its session heals', () async {
      await _theirGroup(mem, 'grp000000001', ['me', 'bob', 'carol']);
      io.noSession.add('carol');
      const poll = PollSpec(options: ['Yes', 'No']);
      expect(
        await app.sendToGroup(
          'grp000000001',
          'Lunch?',
          msgUid: 'p1',
          poll: poll,
        ),
        isTrue,
      );
      expect(
        await app.sendToGroup(
          'grp000000001',
          '🙂',
          msgUid: 's1',
          sticker: 'fokia:1:1',
        ),
        isTrue,
      );
      expect(io.got('carol'), isEmpty);
      expect(await db.groupFileReach('grp000000001'), {
        'p1': (have: 1, of: 2),
        's1': (have: 1, of: 2),
      });

      // still no session: kept, tried, and waits longer
      await due();
      await tick(app);
      expect(io.got('carol'), isEmpty);
      expect(
        [for (final r in mem.rows('group_media_owed')) r['tries']],
        [1, 1],
      );

      io.noSession.clear();
      await due();
      await tick(app);
      final got = {for (final m in io.to('carol')) m.msgUid: m};
      expect(PollSpec.parse(got['p1']!.poll)?.options, ['Yes', 'No']);
      expect(got['p1']!.message, 'Lunch?');
      expect(got['s1']!.sticker, 'fokia:1:1');
      // bob had them already
      expect(io.got('bob'), ['Lunch?', '🙂']);
      expect(mem.rows('group_media_owed'), isEmpty);
    });

    test(
      'one nobody took stays unsent for the outbox, and is owed to no one',
      () async {
        await _theirGroup(mem, 'grp000000001', ['me', 'bob', 'carol']);
        io.cut.addAll(['bob', 'carol']);
        expect(
          await app.sendToGroup('grp000000001', 'hello', msgUid: 'u1'),
          isFalse,
        );
        expect(mem.rows('messages').single['sent'], 0);
        expect(mem.rows('group_media_owed'), isEmpty);
      },
    );

    test('a member who left meanwhile is owed it no more', () async {
      await _theirGroup(mem, 'grp000000001', ['me', 'bob', 'carol']);
      io.cut.add('carol');
      await app.sendToGroup('grp000000001', 'hello', msgUid: 'u2');
      expect(mem.rows('group_media_owed'), hasLength(1));
      await db.removeGroupMember('grp000000001', 'carol');
      expect(mem.rows('group_media_owed'), isEmpty);
    });
  });

  group('a roster stamp, on disk', () {
    test('only a newer one is taken, the first one too', () async {
      expect(await db.takeRosterStamp('g1', 200), isTrue);
      expect(await db.takeRosterStamp('g1', 100), isFalse);
      expect(await db.takeRosterStamp('g1', 200), isFalse);
      expect(await db.takeRosterStamp('g1', 300), isTrue);
      expect(mem.rows('group_roster'), [
        {'group_id': 'g1', 'stamp': 300, 'gone': '', 'seq': 0},
      ]);
      // each group keeps its own
      expect(await db.takeRosterStamp('g2', 50), isTrue);
      expect(await db.takeRosterStamp('g1', 250), isFalse);
    });

    test('the keys gone are kept once each, beside the stamp', () async {
      expect(await db.rosterGone('g1'), isEmpty);
      await db.noteRosterGone('g1', ['k1']);
      expect(mem.rows('group_roster').single['stamp'], 0);
      await db.noteRosterGone('g1', ['k2', 'k1', '', 'a,b']);
      expect(await db.rosterGone('g1'), {'k1', 'k2'});
      expect(mem.rows('group_roster').single['gone'], 'k1,k2');
      // a stamp after them keeps them, and they keep the stamp
      expect(await db.takeRosterStamp('g1', 10), isTrue);
      await db.noteRosterGone('g1', ['k3']);
      expect(await db.rosterGone('g1'), {'k1', 'k2', 'k3'});
      expect(await db.takeRosterStamp('g1', 10), isFalse);
      // a roster of ours goes above the one taken
      expect(await db.nextRosterStamp('g1', 5), 11);
      expect(await db.rosterGone('g1'), {'k1', 'k2', 'k3'});
      expect(await db.rosterGone('g2'), isEmpty);
    });

    test(
      'a room frame\'s number counts up from one, each room its own',
      () async {
        expect(await db.nextRoomSeq('g1'), 1);
        expect(await db.nextRoomSeq('g1'), 2);
        expect(await db.nextRoomSeq('g2'), 1);
        // a roster taken and keys gone leave it where it was, and it them
        expect(await db.takeRosterStamp('g1', 10), isTrue);
        await db.noteRosterGone('g1', ['k1']);
        expect(await db.nextRoomSeq('g1'), 3);
        expect(await db.rosterGone('g1'), {'k1'});
        expect(await db.nextRosterStamp('g1', 5), 11);
      },
    );

    test('goes with the group', () async {
      await _theirGroup(mem, 'grp000000001', ['me', 'bob']);
      await db.nextRoomSeq('grp000000001');
      await db.noteRosterGone('grp000000001', ['k1']);
      expect(await db.takeRosterStamp('grp000000001', 10), isTrue);
      await db.deleteGroup('grp000000001');
      expect(mem.rows('group_roster'), isEmpty);
      expect(await db.takeRosterStamp('grp000000001', 1), isTrue);
      expect(await db.nextRoomSeq('grp000000001'), 1);
    });
  });

  test('the outbox sends a poll again as a poll', () async {
    final wrapped = await wrapRedelivery({
      'plaintext': 'Lunch?',
      'msg_uid': 'p1',
      'group_id': 'grp000000001',
      'poll': const PollSpec(options: ['Yes', 'No']).toRow(),
    }, sender: asSender('me'));
    expect(PollSpec.parse(unwrapMessage(wrapped).poll)?.options, ['Yes', 'No']);
  });

  test('made on create and on the upgrades to 60 and 61', () {
    final src = File('lib/main.dart').readAsStringSync();
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), 61);
    final create = src.indexOf('onCreate: (db, _) async {');
    final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
    expect(
      src.substring(create, upgrade),
      contains('await groupCtlTables(db);'),
    );
    expect(
      RegExp(
        r'if \(oldV < 60\) \{[^}]*await groupCtlTables\(db\);',
      ).hasMatch(src.substring(upgrade)),
      isTrue,
    );
    // the room frame number, on a roster table from 60
    expect(
      RegExp(
        r"if \(oldV < 61\) \{[^}]*ALTER TABLE group_roster ADD COLUMN seq ",
      ).hasMatch(src.substring(upgrade)),
      isTrue,
    );
    final db = MemDb();
    expect(db.has('group_ctl_out'), isTrue);
    expect(db.has('group_roster'), isTrue);
  });
}
