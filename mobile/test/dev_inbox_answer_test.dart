// SPDX-License-Identifier: GPL-3.0-or-later
// answers from a computer in the developer's inbox: the computer hands
// them to his phone, never seals one itself; the phone sends one as its
// own only from a device still listed, only in a chat of the inbox, never
// a hidden one, the developer chat, a group or someone blocked; words and
// a word on a message only, never a file; so many an hour; held while the
// decoy is open; a first answer takes a waiting chat on; the phone's copy
// says it went, its refusal that it did not
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/device_send.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/device_store.dart' show deviceTables;
import 'package:kryfo/devices/own_sync.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        linkedRoleForTest,
        ownApplyForTest,
        ownTellMeForTest,
        deviceSealOutcome,
        DeviceCannotReach,
        phonePqForTest,
        ownSyncForTest,
        searchTables,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateOutbox,
        AppStateDevchat,
        devInboxForTest,
        devAnswersForTest,
        answerClock,
        signalSeal,
        kNotSent,
        kAnswerTooMany,
        kAnswerNotInbox,
        DeviceHanded,
        kAnswerUnseenBurn,
        AppStateAnswers;
import 'package:kryfo/restore_undo.dart' show takenTables;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/devchat/dev_key.dart';
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

class _NoState implements DeviceState {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoSend implements DeviceSend {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// own sync with one desk of mine, each frame it would send noted
class _Told extends OwnSync {
  _Told()
    : super(
        state: _NoState(),
        db: () async => throw StateError('no own rows here'),
        send: _NoSend(),
        me: (_) async => null,
        apply: ownApplyForTest,
      );
  final ops = <(String, String?, Map<String, Object?>)>[];
  final forwards = <(String, String)>[];
  final inboxes = <Map<String, Object?>?>[];
  final came = <int>[];

  @override
  Future<List<OwnPeer>> others(int ident) async => [(id: 4, key: 'k', reg: 1)];

  // whether my desk said it shows the inbox
  var takesInbox = true;
  @override
  Future<bool> devicesTakeInbox(int ident) async => takesInbox;

  @override
  Future<bool> op(
    int ident,
    String kind,
    OwnChat? chat,
    Map<String, Object?> a,
  ) async {
    ops.add((kind, chat == null ? null : ownChatName(chat), a));
    return true;
  }

  @override
  Future<bool> forward(
    int ident,
    String sender,
    String frame,
    int came, {
    Map<String, Object?>? inbox,
  }) async {
    forwards.add((sender, frame));
    inboxes.add(inbox);
    this.came.add(came);
    return true;
  }

  final answers = <(String, String)>[];
  @override
  Future<bool> answer(int ident, OwnChat chat, String frame) async {
    answers.add((ownChatName(chat), frame));
    return true;
  }

  @override
  Future<bool> copy(
    int ident,
    OwnChat chat,
    String frame, {
    List<String> notReached = const [],
    OwnPeer? only,
  }) async => true;
}

String _f(Map<String, Object?> j) => 'halo/1:${jsonEncode(j)}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;
  late Directory docs;
  late SqliteMem s;
  late _Rows db;
  late ArrivalIo io;
  late ArrivalStore store;
  late AppState app;
  late _Told told;

  Future<AppState> start() async {
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    useDatabasesForTest(db, Session(db));
    return AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
  }

  Future<void> person(
    String id, {
    String caps = 'dv,pq,ty',
    int shots = 0,
    int accepted = 1,
  }) => s.insert('contacts', {
    'halo_id': id,
    'onion': '',
    'xpub': 'x-$id',
    'first_seen': 1,
    'last_seen': 1,
    'accepted': accepted,
    'back_paired': 1,
    'ident': 0,
    'ikey': '05${id.hashCode.toRadixString(16).padLeft(8, '0') * 8}',
    'caps': caps,
    'shots_on': shots,
  });

  setUp(() async {
    if (skip != null) return;
    docs = Directory.systemTemp.createTempSync('own_sync_app');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    useEngineForTest(_Engine());
    linkedDevicesForTest = true;
    linkedRoleForTest = false;
    s = SqliteMem.open(path: p.join(docs.path, 'halo.db'))!;
    await appSchemaOn(s);
    await takenTables(s);
    await searchTables(s, fresh: true);
    await deviceTables(s, (d, sql) async {
      try {
        await d.execute(sql);
      } catch (_) {
        // a column the schema has already
      }
    });
    await person('bob');
    await person('carol', shots: 1);
    await person('old-friend', caps: 'ty');
    await person('hid');
    await s.insert('groups', {
      'group_id': 'g1',
      'name': 'Friends',
      'created_at': 1,
      'is_admin': 1,
      'admin_id': 'me',
    });
    for (final (i, m) in ['me', 'bob', 'hid', 'old-friend'].indexed) {
      await s.insert('group_members', {
        'group_id': 'g1',
        'halo_id': m,
        'joined_at': i,
      });
    }
    store = ArrivalStore();
    await store.putHidden(
      'hid',
      kHiddenPeer,
      peerCard(RouterCard('hid', '', 'x-hid', backPaired: true)),
      1,
    );
    db = _Rows(s);
    io = ArrivalIo();
    app = await start();
    told = _Told();
    ownSyncForTest(told);
  });

  tearDown(() async {
    if (skip != null) return;
    ownSyncForTest(null);
    linkedDevicesForTest = false;
    linkedRoleForTest = false;
    ownNoted = null;
    phonePqForTest = null;
    await s.close();
    docs.deleteSync(recursive: true);
  });

  Future<List<Map<String, Object?>>> rows(String uid) =>
      s.query('messages', where: 'msg_uid = ?', whereArgs: [uid]);

  Future<bool> copy(String chat, String f, {List<String> n = const []}) =>
      ownApplyForTest.copy(0, ownChatOf(chat)!, f, notReached: n);

  Future<bool> op(String kind, String? chat, Map<String, dynamic> a) =>
      ownApplyForTest.op(0, chat == null ? null : ownChatOf(chat), kind, a);

  // his phone: his pinned key is this phone's
  const devX =
      '2f3bddfadec1e445a44e0b7608b5fcaca5b84f00b1ba0341c233fc840ca87d3a';
  void devPhone() {
    useDevKeysForTest([
      const DevKey(
        keyId: 't1',
        threeWords: 'test-dev-key',
        xPub: devX,
        bundle: '',
        fc: '00',
      ),
    ]);
    app.myXPub = devX;
  }

  // a computer linked to his phone
  void devDesk({bool answers = true}) {
    linkedRoleForTest = true;
    devInboxForTest = true;
    devAnswersForTest = answers;
  }

  tearDown(() {
    useDevKeysForTest(null);
    devInboxForTest = false;
    devAnswersForTest = false;
    answerClock = () => DateTime.now().millisecondsSinceEpoch;
  });

  Future<void> inbox(String id, String state, {int accepted = 1}) async {
    await person(id, caps: '', accepted: accepted);
    await s.insert('support_chats', {
      'halo_id': id,
      'first_at': 7,
      'state': state,
    });
  }

  const OwnPeer desk = (id: 4, key: 'k', reg: 1);
  Future<bool> answer(String chat, Map<String, Object?> j, {OwnPeer? from}) =>
      ownApplyForTest.answer(0, from ?? desk, ownChatOf(chat)!, _f(j));

  // what the phone put on the wire to [peer], opened
  Future<List<Map<String, dynamic>>> wired(String peer) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return [
      for (final (_, c) in io.sent)
        if (c.startsWith('to $peer halo/1:'))
          jsonDecode(c.substring('to $peer halo/1:'.length))
              as Map<String, dynamic>,
    ];
  }

  List<Map<String, Object?>> refusals() => [
    for (final (k, c, a) in told.ops)
      if (k == 'answer') {'c': c, ...a},
  ];

  group('his phone', () {
    test('a first answer from my computer takes a waiting chat on and goes '
        'as mine, its words alone', () async {
      devPhone();
      await inbox('waiting', 'open', accepted: 0);
      expect(
        await answer('p:waiting', {
          'u': 'u-a1',
          'm': 'Hello, how can I help?',
          'w': 1,
          'h': 'desk-made-up',
          'x': 'x-desk',
          'pw': 9,
          'pb': 20,
          'bg': 'gold',
          'cp': 'dv',
        }),
        isTrue,
      );
      final c = await s.query('contacts', where: "halo_id = 'waiting'");
      expect(c.single['accepted'], 1);
      final r = (await rows('u-a1')).single;
      expect(r['direction'], 'out');
      expect(r['plaintext'], 'Hello, how can I help?');
      // the accept's own word to them, then the answer
      final w = [
        for (final j in await wired('waiting'))
          if (j['u'] != null) j,
      ];
      expect(w, hasLength(1));
      expect(w.single['m'], 'Hello, how can I help?');
      expect(w.single['u'], 'u-a1');
      expect(w.single['h'], 'me');
      expect(w.single.containsKey('pw'), isFalse);
      expect(w.single.containsKey('cp'), isFalse);
      expect(w.single['x'], isNot('x-desk'));
      expect((await rows('u-a1')).single['sent'], 1);
      // the same answer again sends nothing more
      expect(await answer('p:waiting', {'u': 'u-a1', 'm': 'again'}), isTrue);
      expect(
        (await wired('waiting')).where((j) => j['u'] != null),
        hasLength(1),
      );
    }, skip: skip);

    test('a reply, a link\'s title, a reaction, an edit and a take-back go '
        'too', () async {
      devPhone();
      await inbox('answered', 'done');
      await s.insert('messages', {
        'peer_id': 'answered',
        'direction': 'in',
        'plaintext': 'my question',
        'sent_at': 1,
        'msg_uid': 'u-q',
      });
      expect(
        await answer('p:answered', {
          'u': 'u-r1',
          'm': 'see https://kryfo.app',
          'q': 'u-q',
          'pv': {'url': 'https://kryfo.app', 'title': 'Kryfo', 'by': 'sender'},
        }),
        isTrue,
      );
      final r = (await rows('u-r1')).single;
      expect(r['reply_to'], 'u-q');
      expect(jsonDecode(r['preview'] as String)['title'], 'Kryfo');
      expect(
        await answer('p:answered', {
          'm': '',
          'r': {'u': 'u-q', 'e': '👍'},
        }),
        isTrue,
      );
      expect(
        await answer('p:answered', {
          'm': '',
          'ed': {'u': 'u-r1', 'm': 'see the site'},
        }),
        isTrue,
      );
      expect((await rows('u-r1')).single['plaintext'], 'see the site');
      expect(await answer('p:answered', {'m': '', 'un': 'u-r1'}), isTrue);
      expect(await rows('u-r1'), isEmpty);
      final w = await wired('answered');
      expect(w.any((j) => j['r'] is Map && j['r']['e'] == '👍'), isTrue);
      expect(w.any((j) => j['ed'] is Map), isTrue);
      expect(w.any((j) => j['un'] == 'u-r1'), isTrue);
      // a reply or a reaction to another chat's message stays out of it
      await s.insert('messages', {
        'peer_id': 'bob',
        'direction': 'in',
        'plaintext': 'bob here',
        'sent_at': 1,
        'msg_uid': 'u-bob',
      });
      expect(
        await answer('p:answered', {'u': 'u-r2', 'm': 'hm', 'q': 'u-bob'}),
        isTrue,
      );
      expect((await rows('u-r2')).single['reply_to'], isNull);
      expect(
        await answer('p:answered', {
          'm': '',
          'r': {'u': 'u-bob', 'e': '👍'},
        }),
        isFalse,
      );
      // an edit of their words is none of mine
      expect(
        await answer('p:answered', {
          'm': '',
          'ed': {'u': 'u-q', 'm': 'changed'},
        }),
        isFalse,
      );
      expect((await rows('u-q')).single['plaintext'], 'my question');
    }, skip: skip);

    test('a chat through the developer chat is answered where his own answer '
        'goes', () async {
      devPhone();
      await s.insert('messages', {
        'peer_id': 'bob',
        'direction': 'in',
        'plaintext': 'via the dev chat',
        'sent_at': 1,
        'via_dev': 1,
      });
      expect(await answer('p:bob', {'u': 'u-b', 'm': 'got it'}), isTrue);
      expect((await wired('bob')).single['m'], 'got it');
    }, skip: skip);

    test('nothing outside the inbox: a chat never filed, a hidden one, the '
        'developer chat, a group, someone blocked; my computer hears it did '
        'not go', () async {
      devPhone();
      await s.insert('support_chats', {
        'halo_id': 'hid',
        'first_at': 1,
        'state': 'open',
      });
      await inbox('blocked', 'open');
      await s.update('contacts', {'blocked': 1}, where: "halo_id = 'blocked'");
      // a row the developer chat could leave, filed: still never answered
      await inbox('dev:k1', 'open');
      String uid(String c) => 'u-${c.substring(2).replaceAll(':', '-')}';
      for (final c in ['p:bob', 'p:hid', 'p:dev:k1', 'p:blocked']) {
        expect(await answer(c, {'u': uid(c), 'm': 'no'}), isFalse, reason: c);
        expect(await rows(uid(c)), isEmpty, reason: c);
      }
      expect(await answer('g:g1', {'u': 'u-g', 'm': 'no'}), isFalse);
      expect(io.sent, isEmpty);
      // nor on another identity of mine
      expect(
        await ownApplyForTest.answer(
          1,
          desk,
          ownChatOf('p:bob')!,
          _f({'u': 'u-i', 'm': 'no'}),
        ),
        isFalse,
      );
      expect(refusals().map((r) => (r['c'], r['u'], r['x'])), [
        for (final c in ['p:bob', 'p:hid', 'p:dev:k1', 'p:blocked'])
          (c, uid(c), kAnswerNotInbox),
      ]);
    }, skip: skip);

    test('a refused answer leaves no key: my computer\'s try again goes once '
        'the chat is in the inbox', () async {
      devPhone();
      expect(await answer('p:bob', {'u': 'u-again', 'm': 'later'}), isFalse);
      expect(await rows('u-again'), isEmpty);
      await s.insert('support_chats', {
        'halo_id': 'bob',
        'first_at': 7,
        'state': 'open',
      });
      expect(await answer('p:bob', {'u': 'u-again', 'm': 'later'}), isTrue);
      expect((await rows('u-again')).single['plaintext'], 'later');
    }, skip: skip);

    test('never a file, a picture, a voice note, a sticker, a poll or an '
        'introduction', () async {
      devPhone();
      await inbox('answered', 'open');
      for (final j in <Map<String, Object?>>[
        {'u': 'u-1', 'm': 'a file', 'f': 'AAAA', 'fn': 'x.pdf'},
        {'u': 'u-2', 'm': '', 'i': 'AAAA'},
        {'u': 'u-3', 'm': 'note', 'vo': 1, 'mid': 'm1', 'ci': 0, 'ct': 1},
        {'u': 'u-4', 'm': 'hi', 'st': 'fokia:1'},
        {'u': 'u-5', 'm': 'poll', 'pl': {}},
        {
          'u': 'u-6',
          'm': 'meet',
          'in': {'h': 'x'},
        },
        {
          'u': 'u-7',
          'm': 'pic link',
          'pv': {'url': 'u', 'img': 'AAAA'},
        },
        {'u': 'u-8', 'm': 'group', 'g': 'g1'},
        {'u': 'u-9', 'm': 'ask', 'nd': {}},
        {
          'u': 'u-10',
          'm': 'both',
          'r': {'u': 'x', 'e': '1'},
        },
      ]) {
        expect(await answer('p:answered', j), isFalse, reason: '${j['u']}');
        expect(await rows(j['u'] as String), isEmpty);
      }
      expect(io.sent, isEmpty);
    }, skip: skip);

    test('a device no longer on my list hands nothing', () async {
      devPhone();
      await inbox('answered', 'open');
      expect(
        await answer(
          'p:answered',
          {'u': 'u-x', 'm': 'from a removed desk'},
          from: (id: 4, key: 'old-key', reg: 1),
        ),
        isFalse,
      );
      expect(
        await answer(
          'p:answered',
          {'u': 'u-y', 'm': 'from no desk'},
          from: (id: 9, key: 'k', reg: 1),
        ),
        isFalse,
      );
      expect(await rows('u-x'), isEmpty);
      expect(await rows('u-y'), isEmpty);
      expect(refusals(), isEmpty);
    }, skip: skip);

    test(
      '120 answers an hour from one computer; past that none goes, it '
      'hears so, and the phone shows a notice',
      () async {
        devPhone();
        await inbox('answered', 'open');
        await s.insert('own_devices', {
          'uid': 'desk-1',
          'name': 'Desk',
          'kind': 'computer',
          'linked_at': 1,
        });
        await s.insert('own_device_keys', {
          'uid': 'desk-1',
          'ident': 0,
          'dev_id': 4,
          'key': 'k',
          'reg': 1,
        });
        var now = 1_800_000_000_000;
        answerClock = () => now;
        for (var i = 0; i < 120; i++) {
          expect(
            await answer('p:answered', {'u': 'u-c$i', 'm': 'answer $i'}),
            isTrue,
            reason: '$i',
          );
          now += 1000;
        }
        expect(
          await answer('p:answered', {'u': 'u-over', 'm': 'over'}),
          isFalse,
        );
        expect(await rows('u-over'), isEmpty);
        expect(refusals().single['x'], kAnswerTooMany);
        final marks = await s.query(
          'dev_marks',
          where: "kind = 'alarm:many_answers'",
        );
        expect(marks.single['key'], 'desk-1');
        // an hour after the first, one goes again
        now = 1_800_000_000_000 + 3600 * 1000 + 1;
        expect(
          await answer('p:answered', {'u': 'u-next', 'm': 'next'}),
          isTrue,
        );
        // the sends it started end before the rows close
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      skip: skip,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('an answer that comes while the decoy is open waits, and goes once '
        'it closes', () async {
      devPhone();
      await inbox('waiting', 'open', accepted: 0);
      app.quietMarkedForTest = true;
      expect(await answer('p:waiting', {'u': 'u-d', 'm': 'later'}), isTrue);
      expect(await rows('u-d'), isEmpty);
      expect(await s.query('own_answers_held'), hasLength(1));
      app.quietMarkedForTest = false;
      await app.drainOutbox();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect((await rows('u-d')).single['direction'], 'out');
      expect(await s.query('own_answers_held'), isEmpty);
      expect(
        (await wired('waiting')).where((j) => j['u'] == 'u-d').single['m'],
        'later',
      );
    }, skip: skip);

    test('an answer sent again goes once: after a take-back, from another '
        'wrap, or in the decoy, where it counts once too', () async {
      devPhone();
      await inbox('answered', 'open');
      final j = {'u': 'u-once', 'm': 'only once'};
      expect(await answer('p:answered', j), isTrue);
      expect(await answer('p:answered', {'m': '', 'un': 'u-once'}), isTrue);
      expect(await rows('u-once'), isEmpty);
      // the same frame again, and the same words wrapped anew
      expect(await answer('p:answered', j), isTrue);
      expect(await answer('p:answered', {...j, 'w': 7}), isTrue);
      expect(await rows('u-once'), isEmpty);
      expect(
        (await wired('answered')).where((x) => x['u'] == 'u-once'),
        hasLength(1),
      );
      // in the decoy a resend is no second answer
      app.quietMarkedForTest = true;
      var now = 1_800_000_000_000;
      answerClock = () => now++;
      final d = {'u': 'u-dc', 'm': 'held'};
      expect(await answer('p:answered', d), isTrue);
      expect(await answer('p:answered', d), isTrue);
      expect(await s.query('own_answers_held'), hasLength(1));
      final count = await s.query(
        'signal_meta',
        where: "k = 'own_answers:4:k'",
      );
      expect(jsonDecode(count.single['v'] as String), hasLength(1));
      app.quietMarkedForTest = false;
    }, skip: skip);

    test('an edit sent again late undoes no later one', () async {
      devPhone();
      await inbox('answered', 'open');
      expect(await answer('p:answered', {'u': 'u-e', 'm': 'zero'}), isTrue);
      final one = {
        'm': '',
        'ed': {'u': 'u-e', 'm': 'one'},
      };
      expect(await answer('p:answered', one), isTrue);
      expect(
        await answer('p:answered', {
          'm': '',
          'ed': {'u': 'u-e', 'm': 'two'},
        }),
        isTrue,
      );
      expect(await answer('p:answered', one), isTrue);
      expect((await rows('u-e')).single['plaintext'], 'two');
    }, skip: skip);

    test('a take-back or an edit that comes before its words waits for '
        'them', () async {
      devPhone();
      await inbox('answered', 'open');
      expect(await answer('p:answered', {'m': '', 'un': 'u-early'}), isTrue);
      expect(
        await answer('p:answered', {'u': 'u-early', 'm': 'taken back'}),
        isTrue,
      );
      expect(await rows('u-early'), isEmpty);
      expect(
        await answer('p:answered', {
          'm': '',
          'ed': {'u': 'u-ed', 'm': 'as edited'},
        }),
        isTrue,
      );
      expect(await answer('p:answered', {'u': 'u-ed', 'm': 'first'}), isTrue);
      expect((await rows('u-ed')).single['plaintext'], 'as edited');
      final w = await wired('answered');
      expect(w.where((x) => x['u'] == 'u-early'), isEmpty);
      expect(w.singleWhere((x) => x['u'] == 'u-ed')['m'], 'as edited');
    }, skip: skip);

    test('a held answer goes in order, only from a device still listed, '
        'and leaves the hold once it went', () async {
      devPhone();
      await inbox('answered', 'open');
      app.quietMarkedForTest = true;
      for (final u in ['u-h1', 'u-h2']) {
        expect(await answer('p:answered', {'u': u, 'm': u}), isTrue);
      }
      expect(
        await answer(
          'p:answered',
          {'u': 'u-gone', 'm': 'from a desk removed since'},
          from: (id: 5, key: 'k5', reg: 1),
        ),
        isFalse,
      );
      // as if the decoy had taken it from a desk listed then
      await s.insert('own_answers_held', {
        'uid': 'held-gone',
        'chat': 'p:answered',
        'frame': _f({'u': 'u-gone', 'm': 'from a desk removed since'}),
        'dev': 5,
        'dkey': 'k5',
      });
      app.quietMarkedForTest = false;
      await app.drainOutbox();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(await rows('u-gone'), isEmpty);
      final sent = [
        for (final x in await wired('answered'))
          if (x['u'] != null) x['u'],
      ];
      expect(sent, ['u-h1', 'u-h2']);
      expect(await s.query('own_answers_held'), isEmpty);
    }, skip: skip);

    test('a timed answer lives an hour at least, and its clock here starts '
        'once the chat is opened on the phone', () async {
      devPhone();
      await inbox('answered', 'open');
      expect(
        await answer('p:answered', {'u': 'u-t5', 'm': 'gone soon', 'b': 5}),
        isFalse,
      );
      expect(await rows('u-t5'), isEmpty);
      expect(
        await answer('p:answered', {'u': 'u-t1', 'm': 'an hour', 'b': 3600}),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final r = (await rows('u-t1')).single;
      expect(r['burn_secs'], 3600);
      expect(r['burn_at'], kAnswerUnseenBurn);
      expect((await wired('answered')).single['b'], 3600);
      await app.answersSeen('answered');
      final lit = (await rows('u-t1')).single['burn_at'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(lit, inInclusiveRange(now + 3590 * 1000, now + 3600 * 1000));
    }, skip: skip);

    test('a device lifts no block on his phone', () async {
      devPhone();
      await inbox('blocked', 'open');
      await s.update('contacts', {'blocked': 1}, where: "halo_id = 'blocked'");
      await op('contact', 'p:blocked', {
        'r': {'blocked': 0},
      });
      final c = await s.query('contacts', where: "halo_id = 'blocked'");
      expect(c.single['blocked'], 1);
    }, skip: skip);
  });

  group('a computer linked to his phone', () {
    test('an answer in an inbox chat goes to the phone, nothing sealed here, '
        'and its row waits for the phone', () async {
      devDesk();
      await inbox('waiting', 'open', accepted: 0);
      const f = 'halo/1:{"m":"hello","w":1,"u":"u-p1","h":"me"}';
      Object? thrown;
      try {
        await signalSeal('waiting', f);
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<DeviceHanded>());
      expect(deviceSealOutcome(thrown!), 'parked');
      expect(told.answers, [('p:waiting', f)]);
    }, skip: skip);

    test('without the phone\'s word, a file, or a typing frame: nothing goes, '
        'and the chat says the phone answers it', () async {
      devDesk(answers: false);
      await inbox('answered', 'open');
      Future<Object?> seal(String f, {bool settled = false}) async {
        try {
          await signalSeal('answered', f, onlySettled: settled);
        } catch (e) {
          return e;
        }
        return null;
      }

      const text = 'halo/1:{"m":"hi","u":"u-1"}';
      expect(await seal(text), isA<DeviceCannotReach>());
      devAnswersForTest = true;
      expect(
        await seal('halo/1:{"m":"","u":"u-2","f":"AAAA","fn":"a.pdf"}'),
        isA<DeviceCannotReach>(),
      );
      expect(await seal(text, settled: true), isA<DeviceCannotReach>());
      expect(told.answers, isEmpty);
      // an ordinary chat is no inbox chat: it is not handed
      expect(await app.answersViaPhone('bob'), isFalse);
      expect(await app.answersViaPhone('answered'), isTrue);
    }, skip: skip);

    test('the phone\'s copy says it went; its word that it did not marks the '
        'row not sent', () async {
      devDesk();
      await inbox('answered', 'open');
      for (final u in ['u-s', 'u-n']) {
        await s.insert('messages', {
          'peer_id': 'answered',
          'direction': 'out',
          'plaintext': 'from here',
          'sent_at': 1,
          'msg_uid': u,
          'sent': 0,
        });
      }
      expect(
        await copy('p:answered', _f({'u': 'u-s', 'm': 'from here'})),
        isTrue,
      );
      expect((await rows('u-s')).single['sent'], 1);
      expect(
        await op('answer', 'p:answered', {'u': 'u-n', 'x': 'inbox'}),
        isTrue,
      );
      expect((await rows('u-n')).single['sent'], kNotSent);
      // a word on a row that went, or another chat's, changes nothing
      expect(await op('answer', 'p:answered', {'u': 'u-s'}), isFalse);
      expect(await op('answer', 'p:bob', {'u': 'u-n'}), isFalse);
    }, skip: skip);

    test(
      'the phone\'s profile says whether it sends answers from here',
      () async {
        linkedRoleForTest = true;
        devInboxForTest = true;
        await inbox('answered', 'open');
        await op('profile', null, {
          'h': 'scare-raven-rare',
          'dv': true,
          'oa': true,
        });
        expect(await app.answersViaPhone('answered'), isTrue);
        await op('profile', null, {'h': 'scare-raven-rare', 'dv': true});
        expect(await app.answersViaPhone('answered'), isFalse);
      },
      skip: skip,
    );
  });

  test('anyone else\'s phone sends no answer, whatever rows it has', () async {
    await inbox('answered', 'open');
    expect(await answer('p:answered', {'u': 'u-o', 'm': 'no'}), isFalse);
    expect(await rows('u-o'), isEmpty);
  }, skip: skip);

  test('his phone tells my devices it sends their answers', () async {
    devPhone();
    await ownTellMeForTest();
    final me = told.ops.where((o) => o.$1 == 'profile').single.$3;
    expect(me['oa'], isTrue);
  }, skip: skip);
}
