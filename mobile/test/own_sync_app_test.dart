// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices, own-device sync in the app (step 7 job 8): a copy of
// mine is filed once, as mine, in its chat, and never in a hidden chat, a
// chat with screenshots blocked or a chat it does not name; my words on a
// message land only on mine; read state, deletes and clears converge and a
// late copy of a deleted one stays out; a chat gone on my phone (deleted
// or hidden) is forgotten on a linked device and what comes for it after
// files nothing; the phone tells my devices what moved, never a hidden
// chat's, never from the decoy; what a contact on an older Kryfo sends goes
// on to my devices, what a contact who reaches them sends does not. the
// app's own schema in the host's sqlite, the engine stood in for
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devices/device_receive.dart';
import 'package:kryfo/devices/device_send.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/device_store.dart' show deviceTables;
import 'package:kryfo/devices/own_sync.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        devContactByKeyForTest,
        deviceReceiveForTest,
        engineDeviceWireForTest,
        ownAddedForTest,
        linkedRoleForTest,
        ownApplyForTest,
        ownPassForTest,
        ownHeldGoForTest,
        ownNoteForTest,
        ownAroundHideForTest,
        deviceSealOutcome,
        DeviceSent,
        DeviceCannotReach,
        kNotFromDevice,
        phonePqForTest,
        ownSyncForTest,
        searchTables,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateOutbox,
        AppStateReceive,
        AppStateContacts;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'sqlite_ffi.dart';

class _Rows extends HaloDb {
  _Rows(this.s, [super.container]);
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
  final came = <int>[];

  @override
  Future<List<OwnPeer>> others(int ident) async => [(id: 4, key: 'k', reg: 1)];

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
  Future<bool> forward(int ident, String sender, String frame, int came) async {
    forwards.add((sender, frame));
    this.came.add(came);
    return true;
  }

  @override
  Future<bool> copy(
    int ident,
    OwnChat chat,
    String frame, {
    List<String> notReached = const [],
  }) async => true;
}

String _f(Map<String, Object?> j) => 'halo/1:${jsonEncode(j)}';

// the receiving side as the app reaches it: each line opens to what is set
class _Recv implements DeviceReceive {
  final copies = <String, DevCopyIn>{};
  @override
  Future<DevCopyIn?> receive(
    String tag,
    String cipher, {
    int? heldSince,
  }) async => copies[cipher];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _x = '7a1f0c3e9b2d4a5f6e7d8c9b0a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c7b8a9f';

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
  var n = 0;

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

  // a frame from [from] on its session, read off a lane
  Future<void> comes(String from, String wire) async {
    final c = 'c-${n++}';
    io.opens[c] = (from, wire);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('a copy of mine is filed once, as mine, in the chat it names', () async {
    final f = _f({'u': 'u-1', 'm': 'from my desk', 'w': 5});
    expect(await copy('p:bob', f), isTrue);
    expect(await copy('p:bob', f), isFalse);
    final r = await rows('u-1');
    expect(r, hasLength(1));
    expect(r.single['direction'], 'out');
    expect(r.single['peer_id'], 'bob');
    expect(r.single['plaintext'], 'from my desk');
    // a group's under the group, as this phone's own
    final g = _f({'u': 'u-g', 'm': 'hi all', 'g': 'g1'});
    expect(await copy('g:g1', g), isTrue);
    final gr = (await rows('u-g')).single;
    expect(
      (gr['peer_id'], gr['group_id'], gr['direction']),
      ('me', 'g1', 'out'),
    );
    // a frame of another chat than it names, a group frame named as a 1:1
    expect(await copy('p:bob', _f({'u': 'u-x', 'm': 'x', 'g': 'g1'})), isFalse);
    expect(await copy('g:g1', _f({'u': 'u-y', 'm': 'y'})), isFalse);
    expect(await rows('u-x'), isEmpty);
    expect(await rows('u-y'), isEmpty);
  }, skip: skip);

  test('a group frame my desk could not send goes on from the phone to the '
      'members it names, as the phone\'s own, and to no one else', () async {
    final g = _f({
      'u': 'u-gp',
      'm': 'from the desk',
      'g': 'g1',
      'h': 'desk-id',
      'o': 'desk-onion.onion',
    });
    expect(
      await copy('g:g1', g, n: ['old-friend', 'not-a-member', 'me']),
      isTrue,
    );
    final went = [
      for (final (to, c) in io.sent)
        if (c.contains('from the desk')) (to, c),
    ];
    expect(went, hasLength(1));
    expect(went.single.$1, contains('x-old-friend'));
    // the desk's own onion and id never go on
    expect(went.single.$2, isNot(contains('desk-onion')));
    expect(went.single.$2, isNot(contains('desk-id')));
    // and a linked device passes nothing on
    linkedRoleForTest = true;
    io.sent.clear();
    await copy(
      'g:g1',
      _f({'u': 'u-gq', 'm': 'again', 'g': 'g1'}),
      n: ['old-friend'],
    );
    expect(io.sent, isEmpty);
  }, skip: skip);

  test('a linked device never seals on the identity pair: what it cannot '
      'send on its device sessions goes nowhere', () async {
    linkedRoleForTest = true;
    final ok = await app.sendEnvelopeForTest(
      'bob',
      _f({'u': 'u-s', 'm': 'from the desk'}),
    );
    expect(ok, isFalse);
    expect(io.sent, isEmpty);
  }, skip: skip);

  test('a picture of mine sent in slices is put together and filed once, '
      'as mine', () async {
    final bytes = List.generate(300, (i) => i % 256);
    final b = base64Encode(bytes);
    // each slice but the last a multiple of four characters
    final a = b.substring(0, 200), c = b.substring(200);
    Map<String, Object?> slice(int i, String part) => {
      'u': 'm-1',
      'mid': 'm-1',
      'ci': i,
      'ct': 2,
      'i': part,
      'm': 'a picture',
    };
    expect(await copy('p:bob', _f(slice(0, a))), isFalse);
    expect(await rows('m-1'), isEmpty);
    expect(await copy('p:bob', _f(slice(1, c))), isTrue);
    final r = (await rows('m-1')).single;
    expect(r['direction'], 'out');
    expect(File(r['media_path'] as String).readAsBytesSync(), bytes);
    expect(await s.query('media_chunks'), isEmpty);
    expect(await copy('p:bob', _f(slice(1, c))), isFalse);
  }, skip: skip);

  test('never a hidden chat\'s, nor one with screenshots blocked', () async {
    expect(await copy('p:hid', _f({'u': 'u-h', 'm': 'hidden'})), isFalse);
    expect(await copy('p:carol', _f({'u': 'u-c', 'm': 'shots'})), isFalse);
    expect(await rows('u-h'), isEmpty);
    expect(await rows('u-c'), isEmpty);
  }, skip: skip);

  test('my word on a message lands only on mine', () async {
    await s.insert('messages', {
      'peer_id': 'bob',
      'direction': 'in',
      'plaintext': 'his',
      'sent_at': 1,
      'msg_uid': 'u-his',
    });
    await copy('p:bob', _f({'u': 'u-mine', 'm': 'mine', 'w': 2}));
    await copy(
      'p:bob',
      _f({
        'ed': {'u': 'u-his', 'm': 'changed'},
        'w': 3,
      }),
    );
    await copy(
      'p:bob',
      _f({
        'ed': {'u': 'u-mine', 'm': 'mine, changed'},
        'w': 3,
      }),
    );
    // my row of another chat is not this chat's to edit
    await copy('p:old-friend', _f({'u': 'u-there', 'm': 'there', 'w': 2}));
    await copy(
      'p:bob',
      _f({
        'ed': {'u': 'u-there', 'm': 'moved'},
        'w': 3,
      }),
    );
    expect((await rows('u-there')).single['plaintext'], 'there');
    await copy('p:bob', _f({'un': 'u-his'}));
    expect((await rows('u-his')).single['plaintext'], 'his');
    expect((await rows('u-mine')).single['plaintext'], 'mine, changed');
    await copy('p:bob', _f({'un': 'u-mine'}));
    expect(await rows('u-mine'), isEmpty);
    // taken back here: a late copy of it never comes back
    await copy('p:bob', _f({'u': 'u-mine', 'm': 'mine', 'w': 2}));
    expect(await rows('u-mine'), isEmpty);
  }, skip: skip);

  test('read state, deletes and clears converge; a late copy of a deleted '
      'message stays out; a clear keeps what came after it', () async {
    await s.update('contacts', {'unread': 3}, where: "halo_id = 'bob'");
    expect(await op('read', 'p:bob', {'t': 9}), isTrue);
    expect(
      (await s.query('contacts', where: "halo_id = 'bob'")).single['unread'],
      0,
    );
    await copy('p:bob', _f({'u': 'u-d', 'm': 'to delete', 'w': 2}));
    expect(
      await op('del', 'p:bob', {
        'u': ['u-d'],
      }),
      isTrue,
    );
    expect(await rows('u-d'), isEmpty);
    await copy('p:bob', _f({'u': 'u-d', 'm': 'to delete', 'w': 2}));
    expect(await rows('u-d'), isEmpty);
    // a delete naming a message of another chat takes nothing
    await copy('p:old-friend', _f({'u': 'u-o', 'm': 'other', 'w': 2}));
    expect(
      await op('del', 'p:bob', {
        'u': ['u-o'],
      }),
      isFalse,
    );
    expect(await rows('u-o'), hasLength(1));
    await s.insert('messages', {
      'peer_id': 'bob',
      'direction': 'in',
      'plaintext': 'old',
      'sent_at': 100,
      'msg_uid': 'u-old',
    });
    await s.insert('messages', {
      'peer_id': 'bob',
      'direction': 'in',
      'plaintext': 'new',
      'sent_at': 300,
      'msg_uid': 'u-new',
    });
    expect(await op('clear', 'p:bob', {'t': 200}), isTrue);
    expect(await rows('u-old'), isEmpty);
    expect(await rows('u-new'), hasLength(1));
  }, skip: skip);

  test('a linked device forgets a chat gone on my phone, and what comes for it '
      'after files nothing (P1)', () async {
    linkedRoleForTest = true;
    await copy('p:bob', _f({'u': 'u-1', 'm': 'before', 'w': 1}));
    final ikey =
        (await s.query('contacts', where: "halo_id = 'bob'")).single['ikey']
            as String;
    expect(await op('gone', 'p:bob', {}), isTrue);
    expect(await rows('u-1'), isEmpty);
    expect(
      (await s.query('contacts', where: "halo_id = 'bob'")).single['accepted'],
      isNot(1),
    );
    // his devices' copies find no contact here
    expect(await devContactByKeyForTest(0, ikey), isNull);
    // nor does my phone's forward or copy of his chat
    expect(
      await ownApplyForTest.forward(
        0,
        'bob',
        _f({'u': 'u-2', 'm': 'after'}),
        5,
      ),
      isFalse,
    );
    expect(await copy('p:bob', _f({'u': 'u-3', 'm': 'after'})), isFalse);
    expect(await rows('u-2'), isEmpty);
    expect(await rows('u-3'), isEmpty);
  }, skip: skip);

  test('a linked device takes its phone\'s rows: a contact new here, a group '
      'with its members, a group gone', () async {
    linkedRoleForTest = true;
    expect(
      await op('contact', 'p:dan', {
        'r': {
          'nickname': 'Dan',
          'accepted': 1,
          'ikey': '05${'ab' * 32}',
          'caps': 'dv',
        },
      }),
      isTrue,
    );
    final dan = (await s.query('contacts', where: "halo_id = 'dan'")).single;
    expect((dan['nickname'], dan['accepted']), ('Dan', 1));
    expect(
      await op('group', 'g:g2', {
        'r': {'name': 'Climbing', 'created_at': 7},
        'm': ['me', 'bob', 'eve'],
        'p': [
          {'h': 'eve', 'o': 'o-eve', 'x': 'x-eve'},
        ],
      }),
      isTrue,
    );
    expect(
      (await s.query('groups', where: "group_id = 'g2'")).single['name'],
      'Climbing',
    );
    final members = await s.query('group_members', where: "group_id = 'g2'");
    expect({for (final r in members) r['halo_id']}, {'me', 'bob', 'eve'});
    expect(await s.query('contacts', where: "halo_id = 'eve'"), hasLength(1));
    expect(await op('ungroup', 'g:g2', {}), isTrue);
    expect(await s.query('groups', where: "group_id = 'g2'"), isEmpty);
    // a phone never takes a group from a device
    linkedRoleForTest = false;
    expect(
      await op('group', 'g:g3', {
        'r': {'name': 'x'},
        'm': ['me'],
      }),
      isFalse,
    );
  }, skip: skip);

  test('the phone tells my devices what moved: nothing on the first pass, then '
      'a rename, a chat gone; never a hidden chat\'s', () async {
    await ownPassForTest();
    expect(told.ops, isEmpty);
    await s.update('contacts', {'nickname': 'Bobby'}, where: "halo_id = 'bob'");
    await ownPassForTest();
    expect(told.ops.map((o) => (o.$1, o.$2)), [('contact', 'p:bob')]);
    expect((told.ops.single.$3['r'] as Map)['nickname'], 'Bobby');
    // the same again tells nothing
    await ownPassForTest();
    expect(told.ops, hasLength(1));
    // a chat that leaves the everyday side goes as gone
    await s.update('contacts', {'accepted': 0}, where: "halo_id = 'bob'");
    await ownPassForTest();
    expect(told.ops.last.$1, 'gone');
    expect(told.ops.last.$2, 'p:bob');
    // and nothing ever names the hidden chat
    expect(told.ops.where((o) => o.$2 == 'p:hid'), isEmpty);
  }, skip: skip);

  test('nothing is told while the decoy is open', () async {
    final decoy = _Rows(s, HaloContainer.decoy);
    useDatabasesForTest(db, Session(decoy));
    await ownPassForTest();
    await s.update('contacts', {'nickname': 'B'}, where: "halo_id = 'bob'");
    await ownPassForTest();
    expect(told.ops, isEmpty);
    final noted = <String>[];
    ownNoted = (kind, chat, a) => noted.add(kind);
    await Session(decoy).clearUnread('bob');
    expect(noted, isEmpty);
    // the everyday side's own session tells it
    await Session(db).clearUnread('bob');
    expect(noted, ['read']);
  }, skip: skip);

  test(
    'what a contact on an older Kryfo, or one my list has not reached, '
    'sends goes on to my devices; a chat with screenshots blocked does not',
    () async {
      phonePqForTest = (_) async => true;
      // bob reads lists, on a pq session, and holds mine: he reaches my desk
      await comes(
        'bob',
        _f({
          'u': 'u-b0',
          'm': 'he reaches it',
          'cp': ['dv', 'pq', 'ty'],
        }),
      );
      expect(told.forwards, isEmpty);
      await comes('old-friend', _f({'u': 'u-o', 'm': 'from 0.5'}));
      expect(told.forwards.map((x) => x.$1), ['old-friend']);
      expect(jsonDecode(told.forwards.single.$2.substring(7))['m'], 'from 0.5');
      // bob reads lists, and mine naming the desk is still on its way
      final ikey = (await s.query(
        'contacts',
        where: "halo_id = 'bob'",
      )).single['ikey'];
      await s.insert('dev_pushes', {
        'ident': 0,
        'peer': ikey,
        'version': 9,
        'kind': 'add',
        'due_at': 0,
      });
      await comes(
        'bob',
        _f({
          'u': 'u-b',
          'm': 'from bob',
          'cp': ['dv', 'pq', 'ty'],
        }),
      );
      expect(told.forwards.map((x) => x.$1), ['old-friend', 'bob']);
      await comes('carol', _f({'u': 'u-c', 'm': 'shots on'}));
      expect(told.forwards, hasLength(2));
    },
    skip: skip,
  );

  test('nothing of a device copy leaves while the decoy is open', () async {
    final decoy = _Rows(s, HaloContainer.decoy);
    useDatabasesForTest(db, Session(decoy));
    // the engine stand-in throws on any call: none is made
    expect(await engineDeviceWireForTest.send(0, 'x/5/1.00', 'c'), 'held');
    expect(
      await engineDeviceWireForTest.sendOpener(0, 'x/5/1.00', 'c'),
      'held',
    );
  }, skip: skip);

  test('a linked device takes no contact device\'s copy of a chat with '
      'screenshots blocked', () async {
    linkedRoleForTest = true;
    final recv = _Recv();
    deviceReceiveForTest(recv);
    try {
      recv.copies['d1'] = (
        peer: 'carol',
        frame: _f({'u': 'u-cs', 'm': 'blocked shots', 'w': 1}),
      );
      recv.copies['d2'] = (
        peer: 'bob',
        frame: _f({'u': 'u-bs', 'm': 'fine', 'w': 1}),
      );
      await app.receiveRelay([
        (peer: '$_x/5/4', cipher: 'd1'),
        (peer: '$_x/5/4', cipher: 'd2'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await rows('u-cs'), isEmpty);
      expect(await rows('u-bs'), hasLength(1));
    } finally {
      deviceReceiveForTest(null);
    }
  }, skip: skip);

  test('a device of mine my list names comes with its notice, once', () async {
    final k = '05${'cd' * 32}';
    await ownAddedForTest(0, [(id: 6, key: k, reg: 3)]);
    await ownAddedForTest(0, [(id: 6, key: k, reg: 3)]);
    final rows = await s.query('own_devices');
    expect(rows, hasLength(1));
    expect(rows.single['notice'], 1);
    final keys = await s.query('own_device_keys');
    expect((keys.single['dev_id'], keys.single['key']), (6, k));
  }, skip: skip);

  test('M1 a group frame my desk names members for goes on only as a '
      'message: never a profile photo, a pq restart or an introduction, '
      'and nothing but what a message says', () async {
    Future<List<String>> sent(Map<String, Object?> j) async {
      io.sent.clear();
      await copy('g:g1', _f(j), n: ['old-friend']);
      return [
        for (final (_, c) in io.sent)
          if (c.contains('from the desk')) c,
      ];
    }

    for (final bad in <Map<String, Object?>>[
      {'pp': 'slice', 'u': 'u-pp'},
      {'rq': 'kdb1', 'u': 'u-rq'},
      {
        'in': {'h': 'x', 'o': 'o', 'x': 'x'},
        'u': 'u-in',
      },
      {'nd': {}, 'u': 'u-nd'},
      {'dl': 'x', 'u': 'u-dl'},
      {
        'u': 'u-ss',
        'ss': {'o': 1},
      },
    ]) {
      expect(
        await sent({'m': 'from the desk', 'g': 'g1', ...bad}),
        isEmpty,
        reason: '$bad',
      );
    }
    final ok = await sent({
      'u': 'u-ok',
      'm': 'from the desk',
      'g': 'g1',
      'bg': 'badge',
      'rs': ['bob'],
      'gs': {'o': 1},
      'fs': 'ab',
    });
    expect(ok, hasLength(1));
    for (final k in ['"bg"', '"rs"', '"gs"', '"fs"']) {
      expect(ok.single, isNot(contains(k)), reason: k);
    }
  }, skip: skip);

  test('M2 a hide tells my devices gone at once, and no pass runs while '
      'the chats move', () async {
    await ownPassForTest();
    expect(told.ops, isEmpty);
    await ownAroundHideForTest(['bob'], () async {
      // what the move drops of him (vault_life _ownRows)
      await s.delete('own_told', where: "chat = 'p:bob'");
      await s.update('contacts', {'accepted': 0}, where: "halo_id = 'bob'");
      await s.update('contacts', {
        'nickname': 'B',
      }, where: "halo_id = 'old-friend'");
      await ownPassForTest();
      expect(told.ops, isEmpty);
      expect(await s.query('own_told', where: "chat = 'p:bob'"), isEmpty);
    });
    expect(told.ops.map((o) => (o.$1, o.$2)), [('gone', 'p:bob')]);
    // and the passes run again after it
    await ownPassForTest();
    expect(
      told.ops.map((o) => (o.$1, o.$2)),
      contains(('contact', 'p:old-friend')),
    );
    expect(told.ops.where((o) => o.$2 == 'p:bob'), hasLength(1));
  }, skip: skip);

  test('M3 what a 0.5.x contact sends while the decoy is open waits on the '
      'everyday side, and goes on to my devices once it closes, stamped '
      'then', () async {
    phonePqForTest = (_) async => true;
    final decoy = _Rows(s, HaloContainer.decoy);
    useDatabasesForTest(db, Session(decoy));
    await comes('old-friend', _f({'u': 'u-od', 'm': 'during the decoy'}));
    expect(told.forwards, isEmpty);
    expect(await s.query('own_held'), hasLength(1));
    // nothing of it leaves while the decoy is open
    await ownHeldGoForTest();
    expect(told.forwards, isEmpty);
    useDatabasesForTest(db, Session(db));
    final before = DateTime.now().millisecondsSinceEpoch;
    await ownHeldGoForTest();
    expect(told.forwards.map((x) => x.$1), ['old-friend']);
    expect(
      jsonDecode(told.forwards.single.$2.substring(7))['m'],
      'during the decoy',
    );
    expect(told.came.single, greaterThanOrEqualTo(before));
    expect(await s.query('own_held'), isEmpty);
    // one of a chat gone since takes nothing
    useDatabasesForTest(db, Session(decoy));
    await comes('old-friend', _f({'u': 'u-od2', 'm': 'again'}));
    expect(await s.query('own_held'), hasLength(1));
    await s.update('contacts', {
      'accepted': 0,
    }, where: "halo_id = 'old-friend'");
    useDatabasesForTest(db, Session(db));
    await ownHeldGoForTest();
    expect(told.forwards, hasLength(1));
    expect(await s.query('own_held'), isEmpty);
  }, skip: skip);

  test('M4 L3 a chat gone on my phone leaves the shade of a linked device, '
      'and the device keeps no more of the person than the phone does after '
      'a hide', () async {
    linkedRoleForTest = true;
    await s.insert('notif_tags', {'chat': 'bob', 'tag': 't-bob'});
    await s.insert('gone_in', {'msg_uid': 'x', 'peer_id': 'bob', 'at': 1});
    await s.insert('frame_order', {
      'msg_uid': 'os:p:bob',
      'sender': 'own:0/1/k',
      'kind': 'st',
      'w': 1,
    });
    expect(await op('gone', 'p:bob', {}), isTrue);
    expect(io.unrang, contains('bob'));
    expect(io.unrangTags, contains('t-bob'));
    // a group still names him: a key-only row
    final b = (await s.query('contacts', where: "halo_id = 'bob'")).single;
    expect((b['accepted'], b['nickname'], b['note']), (0, null, null));
    expect(b['ikey'], isNotNull);
    expect(await s.query('gone_in', where: "peer_id = 'bob'"), isEmpty);
    expect(
      await s.query('frame_order', where: "msg_uid = 'os:p:bob'"),
      isEmpty,
    );
    // one nothing names goes
    await s.update('contacts', {'shots_on': 0}, where: "halo_id = 'carol'");
    expect(await op('gone', 'p:carol', {}), isTrue);
    expect(await s.query('contacts', where: "halo_id = 'carol'"), isEmpty);
    // a group gone leaves the shade too
    await op('group', 'g:g2', {
      'r': {'name': 'Climbing', 'created_at': 7},
      'm': ['me', 'bob'],
    });
    expect(await op('ungroup', 'g:g2', {}), isTrue);
    expect(io.unrang, contains('group:g2'));
  }, skip: skip);

  test('M5 a linked device\'s seal that went counts as sent; one that cannot '
      'reach them says so', () {
    expect(deviceSealOutcome(const DeviceSent()), 'ok');
    expect(deviceSealOutcome(const DeviceCannotReach('bob')), kNotFromDevice);
    expect(deviceSealOutcome(StateError('x')), isNull);
  });

  test('a block made on a linked device stays its own until my phone\'s '
      'block moves; one my phone makes or lifts is taken', () async {
    linkedRoleForTest = true;
    await person('dan');
    Future<int?> blocked(String id) async =>
        (await s.query(
              'contacts',
              where: 'halo_id = ?',
              whereArgs: [id],
            )).single['blocked']
            as int?;
    Future<List<Map<String, Object?>>> meta(String id) =>
        s.query('signal_meta', where: 'k = ?', whereArgs: ['own_pb:$id']);
    Future<void> phone(String id, int b, [String? name]) async {
      expect(
        await op('contact', 'p:$id', {
          'r': {'blocked': b, 'nickname': ?name},
        }),
        isTrue,
      );
    }

    await phone('bob', 0, 'B');
    await app.block('bob');
    expect(await blocked('bob'), 1);
    // the phone's next row, its block as it was: this one stays
    await phone('bob', 0, 'Bobby');
    expect(await blocked('bob'), 1);
    final b = (await s.query('contacts', where: "halo_id = 'bob'")).single;
    expect(b['nickname'], 'Bobby');
    // the phone blocks and lifts it: taken
    await phone('bob', 1);
    expect(await blocked('bob'), 1);
    await phone('bob', 0);
    expect(await blocked('bob'), 0);
    // a block here before any row of the phone's came
    await app.block('old-friend');
    await phone('old-friend', 0, 'Old');
    expect(await blocked('old-friend'), 1);
    // and one here lifted, the phone's still on: stays lifted
    await phone('dan', 1);
    expect(await blocked('dan'), 1);
    expect(await s.query('block_spans', where: "peer_id = 'dan'"), isNotEmpty);
    await app.unblock('dan');
    await phone('dan', 1, 'H');
    expect(await blocked('dan'), 0);
    // the chat gone: nothing of it stays
    expect(await op('gone', 'p:bob', {}), isTrue);
    expect(await meta('bob'), isEmpty);
  }, skip: skip);

  test('M6 a linked device keeps a whole chat\'s delete, its clear and its '
      'block to itself; my phone takes no block from it', () async {
    linkedRoleForTest = true;
    await ownPassForTest();
    await s.update('contacts', {'blocked': 1}, where: "halo_id = 'bob'");
    await ownPassForTest();
    expect(told.ops, isEmpty);
    await s.update('contacts', {'nickname': 'Bobby'}, where: "halo_id = 'bob'");
    await ownPassForTest();
    expect(told.ops.single.$1, 'contact');
    expect((told.ops.single.$3['r'] as Map).containsKey('blocked'), isFalse);
    await s.update('contacts', {'accepted': 0}, where: "halo_id = 'bob'");
    await ownPassForTest();
    expect(told.ops.where((o) => o.$1 == 'gone'), isEmpty);
    ownNoted = ownNoteForTest;
    await Session(db).clearConversation('old-friend');
    await Session(db).clearUnread('old-friend');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(told.ops.where((o) => o.$1 == 'clear'), isEmpty);
    expect(told.ops.where((o) => o.$1 == 'read'), hasLength(1));
    // the phone
    linkedRoleForTest = false;
    expect(
      await op('contact', 'p:old-friend', {
        'r': {'blocked': 1, 'nickname': 'Old'},
      }),
      isTrue,
    );
    final o = (await s.query(
      'contacts',
      where: "halo_id = 'old-friend'",
    )).single;
    expect((o['blocked'], o['nickname']), (0, 'Old'));
  }, skip: skip);

  test(
    'L4 a chat deleted on my phone is told gone at once, as a hide is',
    () async {
      await ownPassForTest();
      await app.deleteConversation('old-friend');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(told.ops.map((o) => (o.$1, o.$2)), [('gone', 'p:old-friend')]);
    },
    skip: skip,
  );

  test('L5 a delete here lets go of own_gone rows past their time', () async {
    await s.insert('own_gone', {'uid': 'u-very-old', 'at': 1});
    await copy('p:bob', _f({'u': 'u-dd', 'm': 'x', 'w': 2}));
    expect(
      await op('del', 'p:bob', {
        'u': ['u-dd'],
      }),
      isTrue,
    );
    final kept = {for (final r in await s.query('own_gone')) r['uid']};
    expect(kept, {'u-dd'});
  }, skip: skip);
}
