// SPDX-License-Identifier: GPL-3.0-or-later
// a group its admin ends goes from every member's phone as a leave takes
// it: its messages, files, reactions, votes, search words, what was owed
// and its notifications. one line stays in the chat list until its person
// deletes it, and nothing for the group comes in again. only its admin ends
// it, an end made offline waits in the lanes, a delete after it too, and a
// member still writing is told again. the app's receive and send paths on
// its own schema, in the host's sqlite; signal and the wire are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/group_end.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        groupEndColumns,
        searchTables,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/polls.dart' show PollSpec;
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

// a member's route can be down
class _Io extends ArrivalIo {
  final cut = <String>{};

  @override
  Future<String> relaySend(String xPub, String cipher) async {
    final to = cipher.split(' ')[1];
    if (cut.contains(to)) return 'error: down';
    return super.relaySend(xPub, cipher);
  }

  List<UnwrappedMessage> to(String member) => [
    for (final (_, c) in sent)
      if (c.startsWith('to $member '))
        unwrapMessage(c.substring('to $member '.length)),
  ];

  // what went to [member]: a control by its type, a message by its text
  List<String> got(String member) => [
    for (final m in to(member))
      m.groupControl == null ? m.message : 'ctl:${m.groupControl!.type}',
  ];
}

const _theirs = 'g1'; // bob made it, me and carol in it
const _mine = 'g2'; // this phone made it, bob and carol in it

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

  Future<void> addGroup(String id, {required String? admin}) async {
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
    docs = Directory.systemTemp.createTempSync('group_end');
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
    // made apart in the app (its poll tables), a statement of pieces
    await s.execute(
      'CREATE TRIGGER IF NOT EXISTS poll_votes_follow AFTER DELETE ON messages '
      'WHEN old.msg_uid IS NOT NULL BEGIN '
      'DELETE FROM poll_votes WHERE poll_uid = old.msg_uid; END',
    );
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
    await addGroup(_theirs, admin: 'bob');
    await addGroup(_mine, admin: 'me');
    db = _Rows(s);
    io = _Io();
    app = await start();
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

  Future<String> said(
    String uid, {
    String by = 'bob',
    String g = _theirs,
    String text = 'see you at the lake',
    Map<String, Object>? poll,
  }) => wrapMessage(
    text,
    msgUid: uid,
    groupId: g,
    poll: poll,
    sender: asSender(by),
  );

  Future<String> ctl(
    GroupControl gc, {
    String by = 'bob',
    String g = _theirs,
  }) => wrapMessage('', groupId: g, groupControl: gc, sender: asSender(by));

  Future<int> count(String sql, [List<Object?> args = const []]) async =>
      (await s.rawQuery(sql, args)).length;

  Future<Map<String, Object?>> row(String g) async =>
      (await s.query('groups', where: 'group_id = ?', whereArgs: [g])).single;

  // the group as a member's phone holds it, with something of everything
  Future<File> filled() async {
    await comes('bob', await said('m1'));
    await comes('carol', await said('m2', by: 'carol', text: 'bring the boat'));
    await comes(
      'bob',
      await said(
        'p1',
        text: 'when',
        poll: const PollSpec(options: ['sat', 'sun']).toWire(),
      ),
    );
    await comes(
      'carol',
      await wrapMessage(
        '',
        groupId: _theirs,
        vote: const VoteFrame(pollUid: 'p1', choices: [0], seq: 1),
        sender: asSender('carol'),
      ),
    );
    await comes(
      'carol',
      await wrapMessage(
        '',
        groupId: _theirs,
        reaction: const ReactionFrame(targetUid: 'm1', emoji: '🔥'),
        sender: asSender('carol'),
      ),
    );
    // a photo on disk, and a member owed a file of ours
    final photo = File(p.join(docs.path, 'lake.jpg'))..writeAsBytesSync([1]);
    await s.insert('messages', {
      'peer_id': 'me',
      'direction': 'out',
      'plaintext': '',
      'sent_at': 5,
      'msg_uid': 'f1',
      'group_id': _theirs,
      'media_path': photo.path,
    });
    await s.insert('group_media_owed', {
      'msg_uid': 'f1',
      'group_id': _theirs,
      'member': 'carol',
      'total': 1,
      'sent_to': 1,
      'since': 5,
      'next_at': 5,
    });
    await s.insert('notif_tags', {'chat': 'group:$_theirs', 'tag': 't1'});
    return photo;
  }

  group('an end from the admin', () {
    test('takes everything the group held, and leaves its line', () async {
      final photo = await filled();
      expect(
        await count('SELECT 1 FROM messages WHERE group_id = ?', [_theirs]),
        4,
      );
      expect(await count('SELECT 1 FROM reactions'), 1);
      expect(await count('SELECT 1 FROM poll_votes'), 1);
      expect(
        await count("SELECT 1 FROM msg_fts WHERE msg_fts MATCH 'lake'"),
        1,
      );
      await comes('bob', await ctl(const GroupControl(type: 'end')));
      expect(
        await count('SELECT 1 FROM messages WHERE group_id = ?', [_theirs]),
        0,
      );
      expect(await count('SELECT 1 FROM reactions'), 0);
      expect(await count('SELECT 1 FROM poll_votes'), 0);
      expect(await count('SELECT 1 FROM msg_fts'), 0);
      expect(await count('SELECT 1 FROM group_media_owed'), 0);
      expect(await count('SELECT 1 FROM notif_tags'), 0);
      expect(photo.existsSync(), isFalse);
      // its notifications leave the shade
      expect(io.unrang, contains('group:$_theirs'));
      // the row stays, ended by bob, with its members
      final g = await row(_theirs);
      expect(groupEndOf(g)?.by, 'bob');
      expect(g['unread'], 0);
      expect(
        await count('SELECT 1 FROM group_members WHERE group_id = ?', [
          _theirs,
        ]),
        3,
      );
      // the chat list has it, ended
      expect(
        app.groups.singleWhere((x) => x.groupId == _theirs).endedBy,
        'bob',
      );
      // the other group is untouched
      expect(groupEndOf(await row(_mine)), isNull);
    }, skip: skip);

    test('is taken from the admin alone', () async {
      await comes('bob', await said('m1'));
      await comes(
        'carol',
        await ctl(const GroupControl(type: 'end'), by: 'carol'),
      );
      expect(groupEndOf(await row(_theirs)), isNull);
      expect(
        await count('SELECT 1 FROM messages WHERE group_id = ?', [_theirs]),
        1,
      );
      // a group with no admin on record ends by no one's word
      await s.update(
        'groups',
        {'admin_id': null},
        where: 'group_id = ?',
        whereArgs: [_theirs],
      );
      await comes('bob', await ctl(const GroupControl(type: 'end')));
      expect(groupEndOf(await row(_theirs)), isNull);
      // nor one this phone does not have
      await comes('bob', await ctl(const GroupControl(type: 'end'), g: 'g9'));
      expect(await count("SELECT 1 FROM groups WHERE group_id = 'g9'"), 0);
    }, skip: skip);

    test('a burner room never ends by it', () async {
      await s.update(
        'groups',
        {'room_pub': 'aa', 'expires_at': 9999999999999},
        where: 'group_id = ?',
        whereArgs: [_theirs],
      );
      await comes('bob', await ctl(const GroupControl(type: 'end')));
      expect(groupEndOf(await row(_theirs)), isNull);
    }, skip: skip);

    test('nothing for the group comes in after it, from anyone', () async {
      await comes('bob', await said('m1'));
      await comes('bob', await ctl(const GroupControl(type: 'end')));
      io.rang.clear();
      // written before the end or after: all of it is gone here
      await comes('carol', await said('late', by: 'carol'));
      await comes('bob', await said('again'));
      await comes(
        'carol',
        await wrapMessage(
          '',
          groupId: _theirs,
          reaction: const ReactionFrame(targetUid: 'm1', emoji: '🔥'),
          sender: asSender('carol'),
        ),
      );
      await comes(
        'bob',
        await ctl(const GroupControl(type: 'rename', name: 'X')),
      );
      await comes(
        'bob',
        await ctl(const GroupControl(type: 'remove', members: ['carol'])),
      );
      await comes(
        'carol',
        await ctl(const GroupControl(type: 'leave'), by: 'carol'),
      );
      await comes(
        'bob',
        await ctl(
          const GroupControl(
            type: 'create',
            name: 'Back',
            members: ['bob', 'me', 'carol'],
          ),
        ),
      );
      // taken out after the end: the line stays all the same
      await comes(
        'bob',
        await ctl(const GroupControl(type: 'remove', members: ['me'])),
      );
      expect(
        await count('SELECT 1 FROM messages WHERE group_id = ?', [_theirs]),
        0,
      );
      expect(await count('SELECT 1 FROM reactions'), 0);
      final g = await row(_theirs);
      expect(g['name'], 'Friends');
      expect(groupEndOf(g)?.by, 'bob');
      expect(
        await count('SELECT 1 FROM group_members WHERE group_id = ?', [
          _theirs,
        ]),
        3,
      );
      // nothing rang for any of it
      expect(io.rang.where((r) => r.contains(_theirs)), isEmpty);
    }, skip: skip);

    test('keeps the group ended once its admin is gone from here', () async {
      await comes('bob', await ctl(const GroupControl(type: 'end')));
      await s.update(
        'groups',
        {'admin_id': null},
        where: 'group_id = ?',
        whereArgs: [_theirs],
      );
      await s.delete('group_members', where: 'halo_id = ?', whereArgs: ['bob']);
      await s.delete('contacts', where: 'halo_id = ?', whereArgs: ['bob']);
      app = await start();
      await app.refreshGroups();
      expect(groupEndOf(await row(_theirs))?.by, 'bob');
      expect(app.groups.singleWhere((x) => x.groupId == _theirs).ended, isTrue);
      await comes('carol', await said('still', by: 'carol'));
      expect(
        await count('SELECT 1 FROM messages WHERE group_id = ?', [_theirs]),
        0,
      );
    }, skip: skip);

    test('its words for older versions are never kept here', () async {
      await comes(
        'bob',
        await wrapMessage(
          'I ended this group',
          msgUid: 'n1',
          groupId: _theirs,
          endNotice: true,
          sender: asSender('bob'),
        ),
      );
      expect(await count("SELECT 1 FROM messages WHERE msg_uid = 'n1'"), 0);
      expect(io.rang, isEmpty);
    }, skip: skip);

    test('deleting the ended group takes its line and tells no one', () async {
      await comes('bob', await ctl(const GroupControl(type: 'end')));
      io.sent.clear();
      await app.leaveGroupAndAnnounce(_theirs);
      await app.ctlPassForTest;
      expect(await count("SELECT 1 FROM groups WHERE group_id = 'g1'"), 0);
      expect(io.got('bob'), isEmpty);
      expect(io.got('carol'), isEmpty);
    }, skip: skip);
  });

  group('the admin ending it', () {
    test('wipes it here too, and the end goes to every member with the '
        'words for older versions', () async {
      await comes('bob', await said('m1', g: _mine));
      io.sent.clear();
      expect(await app.endGroupAndAnnounce(_mine), isTrue);
      await app.ctlPassForTest;
      expect(
        await count('SELECT 1 FROM messages WHERE group_id = ?', [_mine]),
        0,
      );
      expect(groupEndOf(await row(_mine))?.by, 'me');
      expect(io.unrang, contains('group:$_mine'));
      for (final m in ['bob', 'carol']) {
        expect(io.got(m), ['ctl:end', l10n.groupEndedOldNotice]);
        final notice = io.to(m).last;
        expect(notice.endNotice, isTrue);
        expect(notice.groupId, _mine);
        // the end and the words carry one stamp
        expect(notice.writtenAt, io.to(m).first.writtenAt);
      }
      // once
      expect(await app.endGroupAndAnnounce(_mine), isFalse);
      // nothing more goes from here for it
      expect(await app.sendToGroup(_mine, 'one more'), isFalse);
      await app.renameGroupAndAnnounce(_mine, 'Other');
      expect((await row(_mine))['name'], 'Friends');
    }, skip: skip);

    test('only the admin, of a group with its admin on record', () async {
      expect(await app.endGroupAndAnnounce(_theirs), isFalse);
      expect(groupEndOf(await row(_theirs)), isNull);
      await s.update(
        'groups',
        {'admin_id': null},
        where: 'group_id = ?',
        whereArgs: [_mine],
      );
      expect(await app.endGroupAndAnnounce(_mine), isFalse);
      expect(groupEndOf(await row(_mine)), isNull);
    }, skip: skip);

    test('offline, the end waits, and goes after a delete too', () async {
      io.cut.addAll(['bob', 'carol']);
      expect(await app.endGroupAndAnnounce(_mine), isTrue);
      await app.ctlPassForTest;
      expect(io.got('bob'), isEmpty);
      await app.leaveGroupAndAnnounce(_mine);
      expect(await count("SELECT 1 FROM groups WHERE group_id = 'g2'"), 0);
      // the end and its words wait for each, and no leave follows them
      expect(await count('SELECT 1 FROM group_ctl_out'), 4);
      io.cut.clear();
      await s.update('group_ctl_out', {'next_at': 0});
      await app.drainOutbox();
      await app.ctlPassForTest;
      for (final m in ['bob', 'carol']) {
        expect(io.got(m), ['ctl:end', l10n.groupEndedOldNotice]);
      }
      expect(await count('SELECT 1 FROM group_ctl_out'), 0);
    }, skip: skip);

    test('a member still writing is told again, twice a day at most', () async {
      expect(await app.endGroupAndAnnounce(_mine), isTrue);
      await app.ctlPassForTest;
      io.sent.clear();
      await comes('bob', await said('hello?', g: _mine));
      await app.ctlPassForTest;
      expect(io.got('bob'), ['ctl:end']);
      expect(io.got('carol'), isEmpty);
      expect(await count("SELECT 1 FROM messages WHERE msg_uid = 'hello?'"), 0);
      await comes('bob', await said('anyone?', g: _mine));
      await app.ctlPassForTest;
      expect(io.got('bob'), ['ctl:end']);
    }, skip: skip);
  });

  group('older versions', () {
    test('an end reads as a control of its own kind, nothing else', () async {
      final w = await ctl(const GroupControl(type: 'end'));
      final body = w.substring('halo/1:'.length);
      expect(body, contains('"gc":{"t":"end"}'));
      final gc = unwrapMessage(w).groupControl!;
      expect(gc.type, 'end');
      expect(gc.name, isNull);
      expect(gc.members, isNull);
    });

    test('a kind a version does not know changes nothing there', () async {
      // as 0.5.0 and 0.5.1 take 'end': no case of theirs matches it
      await comes('bob', await said('m1'));
      await comes('bob', await ctl(const GroupControl(type: 'zz')));
      expect(
        await count('SELECT 1 FROM messages WHERE group_id = ?', [_theirs]),
        1,
      );
      expect(groupEndOf(await row(_theirs)), isNull);
    }, skip: skip);
  });

  test('the upgrade to 81 adds the end to every group, none ended', () async {
    if (skip != null) return;
    final old = SqliteMem.open(path: p.join(docs.path, 'old.db'))!;
    await old.execute(
      'CREATE TABLE groups (group_id TEXT PRIMARY KEY, name TEXT NOT NULL, '
      'created_at INTEGER NOT NULL, is_admin INTEGER NOT NULL DEFAULT 0, '
      'admin_id TEXT, voice_disguise INTEGER)',
    );
    await old.insert('groups', {'group_id': 'g', 'name': 'n', 'created_at': 1});
    await groupEndColumns(old);
    // twice is safe: an upgrade cut short runs it again
    await groupEndColumns(old);
    final r = (await old.query('groups')).single;
    expect(r.containsKey('ended_at'), isTrue);
    expect(r.containsKey('ended_by'), isTrue);
    expect(groupEndOf(r), isNull);
    await old.close();
  }, skip: skip);

  test('who may end a group', () {
    Map<String, Object?> g({
      int admin = 1,
      String? id = 'me',
      String? room,
      int? ended,
    }) => {
      'is_admin': admin,
      'admin_id': id,
      'room_pub': room,
      'ended_at': ended,
    };
    expect(mayEndGroup(g(), 'me'), isTrue);
    expect(mayEndGroup(g(admin: 0), 'me'), isFalse);
    expect(mayEndGroup(g(id: null), 'me'), isFalse);
    expect(mayEndGroup(g(id: 'old-key'), 'me'), isFalse);
    expect(mayEndGroup(g(room: 'aa'), 'me'), isFalse);
    expect(mayEndGroup(g(ended: 1), 'me'), isFalse);
    expect(mayEndGroup(null, 'me'), isFalse);
    expect(mayEndGroup(g(), ''), isFalse);
  });
}
