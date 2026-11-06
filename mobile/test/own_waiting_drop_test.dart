// SPDX-License-Identifier: GPL-3.0-or-later
// a message that stops being here takes its own copies still waiting
// unsealed for a device of mine with it (dev_out own rows, own_held): a
// delete for me, a whole chat's delete or clear, a take-back, a timer, a
// delete or take-back from another device of mine, a contact's take-back,
// a group's clear. a sealed copy, a take-back's own copy, the ops and a
// linked device's group copy its phone passes on to members stay; the del
// op still goes to my devices; the decoy touches nothing of the everyday
// side. the app's own schema in the host's sqlite, the engine stood in for
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
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
        ownGroupCopyForTest,
        ownGroupFlushForTest,
        ownSyncForTest,
        searchTables,
        useDatabasesForTest,
        useEngineForTest,
        AppStateReceive,
        AppStateRoute;
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

// own sync with one desk of mine, each copy it would send noted
class _Told extends OwnSync {
  _Told()
    : super(
        state: _NoState(),
        db: () async => throw StateError('no own rows here'),
        send: _NoSend(),
        me: (_) async => null,
        apply: ownApplyForTest,
      );
  final copies = <(String, String, List<String>)>[];

  @override
  Future<List<OwnPeer>> others(int ident) async => [(id: 4, key: 'k', reg: 1)];

  @override
  Future<bool> op(
    int ident,
    String kind,
    OwnChat? chat,
    Map<String, Object?> a,
  ) async => true;

  @override
  Future<bool> forward(
    int ident,
    String sender,
    String frame,
    int came,
  ) async => true;

  @override
  Future<bool> copy(
    int ident,
    OwnChat chat,
    String frame, {
    List<String> notReached = const [],
    OwnPeer? only,
  }) async {
    copies.add((ownChatName(chat), frame, notReached));
    return true;
  }
}

String _f(Map<String, Object?> j) => 'halo/1:${jsonEncode(j)}';

// my own copy of [inner] in [chat], as the burst or OwnSync.copy wraps it
String _oc(String chat, Map<String, Object?> inner, {List<String>? n}) => _f({
  'u': 'oc:x',
  'oc': {'i': 0, 'c': chat, 'f': _f(inner), 'n': ?n},
});

// a contact's frame my phone passes on
String _of(String from, Map<String, Object?> inner) => _f({
  'u': 'of:x',
  'of': {'h': from, 't': 1, 'f': _f(inner)},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;
  late Directory docs;
  late SqliteMem s;
  late _Rows db;
  late ArrivalIo io;
  late AppState app;
  late _Told told;
  var n = 0;

  Future<void> person(String id, {String caps = 'dv,pq,ty'}) =>
      s.insert('contacts', {
        'halo_id': id,
        'onion': '',
        'xpub': 'x-$id',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
        'back_paired': 1,
        'ident': 0,
        'ikey': '05${id.hashCode.toRadixString(16).padLeft(8, '0') * 8}',
        'caps': caps,
      });

  setUp(() async {
    if (skip != null) return;
    docs = Directory.systemTemp.createTempSync('own_waiting_drop');
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
    await person('old-friend', caps: 'ty');
    await s.insert('groups', {
      'group_id': 'g1',
      'name': 'Friends',
      'created_at': 1,
      'is_admin': 1,
      'admin_id': 'me',
    });
    for (final (i, m) in ['me', 'bob', 'old-friend'].indexed) {
      await s.insert('group_members', {
        'group_id': 'g1',
        'halo_id': m,
        'joined_at': i,
      });
    }
    db = _Rows(s);
    io = ArrivalIo();
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useDatabasesForTest(db, Session(db));
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    told = _Told();
    ownSyncForTest(told);
  });

  tearDown(() async {
    if (skip != null) return;
    ownSyncForTest(null);
    linkedDevicesForTest = false;
    linkedRoleForTest = false;
    ownNoted = null;
    await s.close();
    docs.deleteSync(recursive: true);
  });

  // a message here; a timed one of mine that went, burning at [burnAt]
  Future<void> msg(
    String uid, {
    String peer = 'bob',
    String dir = 'out',
    String? group,
    int sentAt = 100,
    int? burnAt,
  }) => s.insert('messages', {
    'peer_id': peer,
    'direction': dir,
    'plaintext': 'words of $uid',
    'sent_at': sentAt,
    'msg_uid': uid,
    'group_id': ?group,
    if (burnAt != null) ...{'burn_secs': 5, 'burn_at': burnAt, 'sent': 1},
  });

  // a frame waiting for my device [dev] under the name [tag]: unsealed
  // unless [sealed]
  Future<void> waiting(
    String tag,
    String plain, {
    int dev = 4,
    bool sealed = false,
  }) => s.insert('dev_out', {
    'uid': tag,
    'ident': 0,
    'peer': 'me',
    'device': dev,
    'at': 1,
    'own': 1,
    'plain': sealed ? null : plain,
    'wire': sealed ? 'c2VhbGVk' : null,
    'state': sealed ? 'go' : 'wait',
  });

  Future<List<String>> left() async => [
    for (final r in await s.query('dev_out', orderBy: 'rowid'))
      r['uid'] as String,
  ];

  test('a delete for me takes every unsealed copy of the message and of my '
      'words on it; a take-back, an op, a sealed one, another message and '
      'another chat stay, and the del still goes to my devices', () async {
    await msg('u-1');
    await msg('u-2');
    await waiting('c1', _oc('p:bob', {'u': 'u-1', 'm': 'mine'}));
    await waiting(
      'c1-slice',
      _oc('p:bob', {'u': 'u-1', 'mid': 'u-1', 'ci': 0, 'ct': 2, 'f': 'QQ=='}),
      dev: 5,
    );
    await waiting(
      'c1-drop',
      _oc('p:bob', {
        'u': 'u-1',
        'm': '',
        'bl': {'id': 'ab', 'k': 'cd', 't': 'token'},
      }),
    );
    await waiting(
      'c1-edit',
      _oc('p:bob', {
        'ed': {'u': 'u-1', 'm': 'new words'},
      }),
    );
    await waiting(
      'c1-react',
      _oc('p:bob', {
        'r': {'u': 'u-1', 'e': 'x'},
      }),
    );
    await waiting('c1-un', _oc('p:bob', {'un': 'u-1'}));
    // a take-back that names a uid of its own still goes
    await waiting('c1-un2', _oc('p:bob', {'un': 'u-1', 'u': 'u-1'}));
    await waiting('c2', _oc('p:bob', {'u': 'u-2', 'm': 'other'}));
    await waiting('cx', _oc('p:old-friend', {'u': 'u-1', 'm': 'other chat'}));
    await waiting(
      'c1-sealed',
      _oc('p:bob', {'u': 'u-1', 'm': 'mine'}),
      sealed: true,
    );
    await waiting(
      'os',
      _f({
        'u': 'os:1:5',
        'os': {
          'n': 5,
          'k': 'del',
          'c': 'p:bob',
          'u': ['u-1'],
        },
      }),
    );
    final noted = <String>[];
    ownNoted = (kind, chat, a) =>
        noted.add('$kind ${ownChatName(chat)} ${jsonEncode(a['u'])}');
    await Session(db).deleteMessage('u-1');
    expect(await left(), ['c1-un', 'c1-un2', 'c2', 'cx', 'c1-sealed', 'os']);
    expect(noted, ['del p:bob ["u-1"]']);
  }, skip: skip);

  test('a whole chat deleted, or cleared, takes its waiting copies, a '
      'contact\'s passed-on frames with them', () async {
    await msg('u-1');
    await msg('u-in', dir: 'in');
    await msg('u-o', peer: 'old-friend');
    await waiting('c1', _oc('p:bob', {'u': 'u-1', 'm': 'mine'}));
    await waiting('f1', _of('bob', {'u': 'u-in', 'm': 'theirs'}));
    await waiting('co', _oc('p:old-friend', {'u': 'u-o', 'm': 'kept'}));
    await Session(db).deleteConversation('bob');
    expect(await left(), ['co']);
    await msg('u-o2', peer: 'old-friend', dir: 'in');
    await waiting('fo', _of('old-friend', {'u': 'u-o2', 'm': 'theirs'}));
    await Session(db).clearConversation('old-friend');
    expect(await left(), isEmpty);
  }, skip: skip);

  test('a group cleared or left takes its waiting copies and its members\' '
      'passed-on frames; a person\'s word elsewhere stays', () async {
    await msg('g-1', peer: 'me', group: 'g1');
    await msg('g-2', peer: 'bob', dir: 'in', group: 'g1');
    await msg('u-b', dir: 'in');
    await waiting('gc', _oc('g:g1', {'u': 'g-1', 'm': 'mine', 'g': 'g1'}));
    await waiting('gf', _of('bob', {'u': 'g-2', 'm': 'theirs', 'g': 'g1'}));
    await waiting('pf', _of('bob', {'u': 'u-b', 'm': 'to me'}));
    await Session(db).clearGroupConversation('g1');
    expect(await left(), ['pf']);
    await msg('g-3', peer: 'me', group: 'g1');
    await waiting('gc3', _oc('g:g1', {'u': 'g-3', 'm': 'mine', 'g': 'g1'}));
    // a leave: the group's rows go without gone records
    await db.clearGroupConversation('g1', noteGone: false);
    expect(await left(), ['pf']);
    // a room's messages, and a group no longer here swept at start
    await msg('g-4', peer: 'me', group: 'g1');
    await waiting('gc4', _oc('g:g1', {'u': 'g-4', 'm': 'mine', 'g': 'g1'}));
    await db.deleteGroupMessages('g1');
    expect(await left(), ['pf']);
    await msg('g-5', peer: 'me', group: 'g-old');
    await waiting('gc5', _oc('g:g-old', {'u': 'g-5', 'm': 'mine'}));
    await db.dropGroupLeftovers();
    expect(await left(), ['pf']);
  }, skip: skip);

  test('a chat of many messages cleared reads each waiting row once and '
      'takes the same', () async {
    for (var i = 0; i < 70; i++) {
      await msg('m-$i');
    }
    await msg('m-o', peer: 'old-friend');
    await waiting('c3', _oc('p:bob', {'u': 'm-3', 'm': 'mine'}));
    await waiting('c69', _oc('p:bob', {'u': 'm-69', 'm': 'mine'}));
    await waiting('co', _oc('p:old-friend', {'u': 'm-o', 'm': 'kept'}));
    await waiting('cx', _oc('p:old-friend', {'u': 'm-3', 'm': 'other chat'}));
    await Session(db).clearConversation('bob');
    expect(await left(), ['co', 'cx']);
  }, skip: skip);

  test('a timed message that burns takes its waiting copies, a timed one '
      'still running keeps them', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await msg('u-t', burnAt: now - 1000);
    await msg('u-l', burnAt: now + 600000);
    await waiting('ct', _oc('p:bob', {'u': 'u-t', 'm': 'timed', 'b': 5}));
    await waiting('cl', _oc('p:bob', {'u': 'u-l', 'm': 'later', 'b': 5}));
    await db.purgeExpired();
    expect(await left(), ['cl']);
    await s.update('messages', {
      'burn_at': now - 1000,
    }, where: "msg_uid = 'u-l'");
    await Session(db).purgeExpiredBurns();
    expect(await left(), isEmpty);
  }, skip: skip);

  test(
    'a delete or a take-back from another device of mine, and a '
    'contact\'s take-back, take what still waits here for my others',
    () async {
      await msg('u-d');
      await msg('u-un');
      await waiting('cd', _oc('p:bob', {'u': 'u-d', 'm': 'mine'}), dev: 5);
      await waiting('cun', _oc('p:bob', {'u': 'u-un', 'm': 'mine'}), dev: 5);
      expect(
        await ownApplyForTest.op(0, ownChatOf('p:bob'), 'del', {
          'u': ['u-d'],
        }),
        isTrue,
      );
      expect(await left(), ['cun']);
      expect(
        await ownApplyForTest.copy(0, ownChatOf('p:bob')!, _f({'un': 'u-un'})),
        isTrue,
      );
      expect(await left(), isEmpty);
      // old-friend takes one back: my phone's passed-on copy goes
      await msg('u-of', peer: 'old-friend', dir: 'in');
      await waiting('fo', _of('old-friend', {'u': 'u-of', 'm': 'theirs'}));
      final c = 'c-${n++}';
      io.opens[c] = ('old-friend', _f({'un': 'u-of'}));
      await app.receiveOnion([c]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await s.query('messages', where: "msg_uid = 'u-of'"), isEmpty);
      expect(await left(), isEmpty);
    },
    skip: skip,
  );

  test('a frame held for my devices while the decoy was open goes with its '
      'message', () async {
    await msg('u-h', peer: 'old-friend', dir: 'in');
    await msg('u-k', peer: 'old-friend', dir: 'in');
    for (final u in ['u-h', 'u-k']) {
      await s.insert('own_held', {
        'uid': 'h-$u',
        'chat': 'p:old-friend',
        'sender': 'old-friend',
        'frame': _f({'u': u, 'm': 'theirs'}),
      });
    }
    await Session(db).deleteMessage('u-h');
    expect([for (final r in await s.query('own_held')) r['uid']], ['h-u-k']);
  }, skip: skip);

  test('a linked device\'s group copy its phone still passes on to members '
      'stays; its copy for another device goes', () async {
    await msg('g-p', peer: 'me', group: 'g1');
    await waiting(
      'to-phone',
      _oc('g:g1', {'u': 'g-p', 'm': 'mine', 'g': 'g1'}, n: ['old-friend']),
      dev: 1,
    );
    await waiting(
      'to-desk',
      _oc('g:g1', {'u': 'g-p', 'm': 'mine', 'g': 'g1'}, n: ['old-friend']),
      dev: 5,
    );
    await Session(db).deleteMessage('g-p');
    expect(await left(), ['to-phone']);
  }, skip: skip);

  test('a group copy still gathering on a linked device goes no more once '
      'its message is deleted, unless members are owed it', () async {
    linkedRoleForTest = true;
    await msg('g-a', peer: 'me', group: 'g1');
    await msg('g-b', peer: 'me', group: 'g1');
    final a = _f({'u': 'g-a', 'm': 'gone soon', 'g': 'g1'});
    final b = _f({'u': 'g-b', 'm': 'owed', 'g': 'g1'});
    ownGroupCopyForTest('g1', 'bob', a, reached: true);
    ownGroupCopyForTest('g1', 'old-friend', b, reached: false);
    await Session(db).deleteMessage('g-a');
    await Session(db).deleteMessage('g-b');
    await ownGroupFlushForTest();
    expect(told.copies.map((c) => c.$2), [b]);
    expect(told.copies.single.$3, ['old-friend']);
  }, skip: skip);

  test('the decoy\'s delete touches nothing of the everyday side', () async {
    final other = SqliteMem.open(path: p.join(docs.path, 'decoy.db'))!;
    await appSchemaOn(other);
    await deviceTables(other, (d, sql) async {
      try {
        await d.execute(sql);
      } catch (_) {}
    });
    final decoy = _Rows(other, HaloContainer.decoy);
    useDatabasesForTest(db, Session(decoy));
    await msg('u-1');
    await other.insert('messages', {
      'peer_id': 'bob',
      'direction': 'out',
      'plaintext': 'the decoy\'s',
      'sent_at': 100,
      'msg_uid': 'u-1',
    });
    await waiting('c1', _oc('p:bob', {'u': 'u-1', 'm': 'mine'}));
    await s.insert('own_held', {
      'uid': 'h-1',
      'chat': 'p:bob',
      'sender': 'bob',
      'frame': _f({'u': 'u-1', 'm': 'theirs'}),
    });
    final noted = <String>[];
    ownNoted = (kind, chat, a) => noted.add(kind);
    await Session(decoy).deleteMessage('u-1');
    await Session(decoy).deleteConversation('bob');
    await Session(decoy).clearConversation('bob');
    await decoy.purgeExpired();
    expect(await left(), ['c1']);
    expect(await s.query('own_held'), hasLength(1));
    expect(noted, isEmpty);
    await other.close();
  }, skip: skip);
}
