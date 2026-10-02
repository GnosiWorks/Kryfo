// SPDX-License-Identifier: GPL-3.0-or-later
// a timed text, sticker or poll in a group starts its clock when a member
// has it, as a 1:1 message and a group file do. one still waiting for a
// route is not burnt unsent, however long its timer. the database methods
// and the app's send are the real ones, over rows kept in maps; signal and
// the wire are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
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
  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async => const [];
}

// a member's route can be down
class _Io extends ArrivalIo {
  final cut = <String>{};

  @override
  Future<String> relaySend(String xPub, String cipher) async {
    if (cut.contains(cipher.split(' ')[1])) return 'error: down';
    return super.relaySend(xPub, cipher);
  }
}

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _g = 'grp000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;
  late _Io io;
  late AppState app;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('group_burn_send');
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
    for (final p in ['bob', 'carol']) {
      await mem.insert('contacts', {
        'halo_id': p,
        'onion': '',
        'xpub': 'x-$p',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
        'back_paired': 1,
      });
    }
    await mem.insert('groups', {
      'group_id': _g,
      'name': 'Friends',
      'created_at': 1,
      'is_admin': 0,
      'admin_id': 'someone-else',
    });
    for (final (i, m) in ['me', 'bob', 'carol'].indexed) {
      await mem.insert('group_members', {
        'group_id': _g,
        'halo_id': m,
        'joined_at': i,
      });
    }
    db = _Rows(mem);
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useDatabasesForTest(db, Session(db));
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
  });

  tearDown(() => docs.deleteSync(recursive: true));

  Map<String, Object?> row(String uid) =>
      mem.rows('messages').firstWhere((r) => r['msg_uid'] == uid);

  test('one nobody took keeps its timer unstarted, and starts it on the '
      'send that reaches someone', () async {
    io.cut.addAll(['bob', 'carol']);
    expect(
      await app.sendToGroup(_g, 'hello', msgUid: 't1', burnSeconds: 30),
      isFalse,
    );
    expect(
      await app.sendToGroup(
        _g,
        '🙂',
        msgUid: 's1',
        burnSeconds: 30,
        sticker: 'fokia:1:1',
      ),
      isFalse,
    );
    expect(
      await app.sendToGroup(
        _g,
        'Lunch?',
        msgUid: 'p1',
        burnSeconds: 30,
        poll: const PollSpec(options: ['Yes', 'No']),
      ),
      isFalse,
    );
    for (final uid in ['t1', 's1', 'p1']) {
      expect(row(uid)['sent'], 0, reason: uid);
      expect(row(uid)['burn_at'], isNull, reason: uid);
      expect(row(uid)['burn_secs'], 30, reason: uid);
    }

    // the route is back: the retry passes the same uid
    io.cut.clear();
    final before = DateTime.now().millisecondsSinceEpoch;
    expect(
      await app.sendToGroup(_g, 'hello', msgUid: 't1', burnSeconds: 30),
      isTrue,
    );
    final after = DateTime.now().millisecondsSinceEpoch;
    expect(row('t1')['sent'], 1);
    final at = row('t1')['burn_at'] as int;
    expect(at, inInclusiveRange(before + 30000, after + 30000));
    // the others still wait, unstarted
    expect(row('s1')['burn_at'], isNull);
  });

  test('one that went at once starts at once', () async {
    final before = DateTime.now().millisecondsSinceEpoch;
    expect(
      await app.sendToGroup(_g, 'hi', msgUid: 't2', burnSeconds: 60),
      isTrue,
    );
    final at = row('t2')['burn_at'] as int;
    expect(at, greaterThanOrEqualTo(before + 60000));
    expect(
      at,
      lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch + 60000),
    );
  });

  test('one with no timer has none', () async {
    expect(await app.sendToGroup(_g, 'plain', msgUid: 't3'), isTrue);
    expect(row('t3')['burn_at'], isNull);
    expect(row('t3')['burn_secs'], isNull);
  });

  group('the sweep', () {
    Future<void> put(String uid, String dir, int sent) =>
        mem.insert('messages', {
          'peer_id': dir == 'out' ? 'me' : 'bob',
          'group_id': _g,
          'direction': dir,
          'plaintext': uid,
          'sent_at': 1,
          'msg_uid': uid,
          'sent': sent,
          'burn_at': 1,
          'burn_secs': 30,
        });

    Future<List<String>> left() async => [
      for (final r in mem.rows('messages')) r['msg_uid'] as String,
    ];

    test('the periodic one keeps a row of ours that has not gone', () async {
      await put('waiting', 'out', 0);
      await put('went', 'out', 1);
      await put('came', 'in', 1);
      await db.purgeExpired();
      expect(await left(), ['waiting']);
    });

    test('so does the one a chat runs when it opens', () async {
      await put('waiting', 'out', 0);
      await put('went', 'out', 1);
      await put('came', 'in', 1);
      await db.purgeExpiredBurns();
      expect(await left(), ['waiting']);
    });
  });

  test('a group bubble shows its countdown only once the send went', () {
    final screen = sourceOf('lib/screens/group_chat_screen.dart');
    for (final fn in [
      'Future<void> _send(',
      'Future<void> _sendSticker(',
      'Future<void> _newPoll(',
      'Future<void> _retryGroup(',
    ]) {
      final body = bodyOf(screen, fn);
      expect(body, isNot(contains('millisecondsSinceEpoch +')), reason: fn);
      expect(body, contains('await _burnFrom(uid, ok)'), reason: fn);
      expect(body, contains('live.burnAt = burnAt'), reason: fn);
    }
  });
}
