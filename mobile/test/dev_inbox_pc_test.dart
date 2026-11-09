// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's inbox on his linked devices: his phone passes on what
// waits there with its place, a waiting request outside it stays; a hidden
// one never goes; the chat's place rides its rows both ways; a device files
// nothing by itself and moves a chat only by the phone's rules; the phone's
// profile says the inbox shows there
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
import 'package:kryfo/devices/own_gone.dart';
import 'package:kryfo/heal.dart' show restoreCutsLinkedDevices;
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
        linkedChatsComing,
        historyCopyShown,
        ownShownId,
        appState,
        AppStateSession,
        ownApplyForTest,
        ownPassForTest,
        ownTellMeForTest,
        AppStateRefresh,
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
        AppStateContacts,
        AppStateDevchat,
        AppStateInbox,
        devInboxHere,
        devInboxForTest;
import 'package:kryfo/devices/history_link.dart'
    show HistoryCopyStage, HistoryCopyStep;
import 'package:kryfo/devices/own_device_store.dart' show ownPhoneHeard;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/supporter.dart';
import 'package:kryfo/devchat/dev_key.dart';
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
  void devDesk() {
    linkedRoleForTest = true;
    devInboxForTest = true;
  }

  tearDown(() {
    useDevKeysForTest(null);
    devInboxForTest = false;
  });

  Future<void> inbox(String id, String state, {int accepted = 1}) async {
    await person(id, caps: '', accepted: accepted);
    await s.insert('support_chats', {
      'halo_id': id,
      'first_at': 7,
      'state': state,
    });
  }

  Future<Map<String, Object?>?> place(String id) async {
    final r = await s.query(
      'support_chats',
      where: 'halo_id = ?',
      whereArgs: [id],
    );
    return r.isEmpty ? null : r.single;
  }

  Future<bool> forward(String from, String f, Map<String, dynamic>? sp) =>
      ownApplyForTest.forward(0, from, f, 9, inbox: sp);

  group('his phone', () {
    test('what reaches the inbox goes on to my devices with its place, '
        'waiting or not; a request outside it stays', () async {
      devPhone();
      await inbox('waiting', 'open', accepted: 0);
      await inbox('answered', 'done');
      await inbox('moved', 'out');
      await person('asking', caps: '', accepted: 0);
      await comes('waiting', _f({'u': 'u-w', 'm': 'help', 'sp': 1}));
      await comes('answered', _f({'u': 'u-a', 'm': 'again', 'sp': 1}));
      await comes('moved', _f({'u': 'u-m', 'm': 'moved one', 'sp': 1}));
      await comes('asking', _f({'u': 'u-r', 'm': 'a request'}));
      expect(told.forwards.map((x) => x.$1), ['waiting', 'answered', 'moved']);
      expect(told.inboxes, [
        {'s': 'open', 'f': 7},
        // a message brings one put away back
        {'s': 'open', 'f': 7},
        {'s': 'out', 'f': 7},
      ]);
      // the marker rides on: the device tags what it should
      expect(jsonDecode(told.forwards.first.$2.substring(7))['sp'], 1);
    }, skip: skip);

    test('a waiting chat goes only once my devices say they show the inbox; '
        'an answered one goes either way', () async {
      devPhone();
      told.takesInbox = false;
      await inbox('waiting', 'open', accepted: 0);
      await inbox('answered', 'done');
      await comes('waiting', _f({'u': 'u-w', 'm': 'help', 'sp': 1}));
      await comes('answered', _f({'u': 'u-a', 'm': 'again', 'sp': 1}));
      expect(told.forwards.map((x) => x.$1), ['answered']);
      await ownPassForTest();
      await s.update('contacts', {
        'nickname': 'W',
      }, where: "halo_id = 'waiting'");
      await s.update('contacts', {
        'nickname': 'A',
      }, where: "halo_id = 'answered'");
      told.ops.clear();
      await ownPassForTest();
      final named = {
        for (final (k, c, _) in told.ops)
          if (k == 'contact') c,
      };
      expect(named, {'p:answered'});
      told.takesInbox = true;
      told.ops.clear();
      await ownPassForTest();
      expect(told.ops.where((o) => o.$2 == 'p:waiting'), isNotEmpty);
    }, skip: skip);

    test('a waiting chat\'s frame held in the decoy goes on only while my '
        'devices say they show the inbox', () async {
      devPhone();
      await inbox('waiting', 'open', accepted: 0);
      final decoy = _Rows(s, HaloContainer.decoy);
      useDatabasesForTest(db, Session(decoy));
      await comes('waiting', _f({'u': 'u-dh', 'm': 'in the decoy', 'sp': 1}));
      expect(await s.query('own_held'), hasLength(1));
      // a device linked meanwhile that does not show the inbox
      told.takesInbox = false;
      useDatabasesForTest(db, Session(db));
      await ownHeldGoForTest();
      expect(told.forwards, isEmpty);
    }, skip: skip);

    test('a hidden inbox chat never goes', () async {
      devPhone();
      await s.insert('support_chats', {
        'halo_id': 'hid',
        'first_at': 1,
        'state': 'open',
      });
      await comes('hid', _f({'u': 'u-h', 'm': 'hidden words', 'sp': 1}));
      expect(told.forwards, isEmpty);
      expect(await copy('p:hid', _f({'u': 'u-h2', 'm': 'mine'})), isFalse);
    }, skip: skip);

    test('a frame for a waiting chat held while the decoy is open goes '
        'with its place once it closes', () async {
      devPhone();
      await inbox('waiting', 'open', accepted: 0);
      final decoy = _Rows(s, HaloContainer.decoy);
      useDatabasesForTest(db, Session(decoy));
      await comes('waiting', _f({'u': 'u-d', 'm': 'in the decoy', 'sp': 1}));
      expect(told.forwards, isEmpty);
      expect(await s.query('own_held'), hasLength(1));
      useDatabasesForTest(db, Session(db));
      await ownHeldGoForTest();
      expect(told.forwards.map((x) => x.$1), ['waiting']);
      expect(told.inboxes.single, {'s': 'open', 'f': 7});
    }, skip: skip);

    test('a chat\'s place rides its rows to my devices, a waiting one '
        'too; a chat outside the inbox carries none', () async {
      devPhone();
      await inbox('waiting', 'open', accepted: 0);
      await inbox('answered', 'done');
      await ownPassForTest();
      await s.update('support_chats', {
        'state': 'out',
      }, where: "halo_id = 'answered'");
      await s.update('support_chats', {
        'state': 'done',
      }, where: "halo_id = 'waiting'");
      await s.update('contacts', {'nickname': 'Bob'}, where: "halo_id = 'bob'");
      await ownPassForTest();
      final ops = {
        for (final (k, c, a) in told.ops)
          if (k == 'contact') c: a,
      };
      expect(ops['p:answered']?['sp'], {'s': 'out', 'f': 7});
      expect(ops['p:waiting']?['sp'], {'s': 'done', 'f': 7});
      expect(ops['p:bob']!.containsKey('sp'), isFalse);
      // a request outside the inbox is no chat of my devices
      await person('asking', caps: '', accepted: 0);
      told.ops.clear();
      await s.update('contacts', {
        'nickname': 'A',
      }, where: "halo_id = 'asking'");
      await ownPassForTest();
      expect(told.ops.where((o) => o.$2 == 'p:asking'), isEmpty);
    }, skip: skip);

    test('my desk moves a chat by the phone\'s rules: put away, back, to '
        'Chats; a chat that never came through the developer chat moves '
        'nowhere', () async {
      devPhone();
      await inbox('answered', 'open');
      await inbox('moved', 'out');
      Future<void> moves(String id, String to) => op('contact', 'p:$id', {
        'r': {'nickname': null},
        'sp': {'s': to},
      });
      await moves('answered', 'done');
      expect((await place('answered'))!['state'], 'done');
      await moves('answered', 'open');
      expect((await place('answered'))!['state'], 'open');
      await moves('answered', 'out');
      expect((await place('answered'))!['state'], 'out');
      // put away is for a chat in the inbox: one in Chats stays there
      await moves('answered', 'done');
      expect((await place('answered'))!['state'], 'out');
      await moves('moved', 'open');
      expect((await place('moved'))!['state'], 'open');
      // bob never wrote through the developer chat
      await moves('bob', 'open');
      expect(await place('bob'), isNull);
      // one who did comes into the inbox only on a move there
      await person('via');
      await s.insert('messages', {
        'peer_id': 'via',
        'direction': 'in',
        'plaintext': 'through the dev chat',
        'sent_at': 1,
        'via_dev': 1,
      });
      await moves('via', 'done');
      await moves('via', 'out');
      expect(await place('via'), isNull);
      await moves('via', 'open');
      expect((await place('via'))!['state'], 'open');
      // and a state the inbox has no place for moves nothing
      await moves('answered', 'gone');
      expect((await place('answered'))!['state'], 'out');
    }, skip: skip);

    test('my profile tells my devices the inbox is here; anyone else\'s '
        'does not', () async {
      await ownTellMeForTest();
      final plain = told.ops.where((o) => o.$1 == 'profile').single.$3;
      expect(plain.containsKey('dv'), isFalse);
      told.ops.clear();
      devPhone();
      await ownTellMeForTest();
      final his = told.ops.where((o) => o.$1 == 'profile').single.$3;
      expect(his['dv'], isTrue);
    }, skip: skip);
  });

  group('his phone, the guards', () {
    test('my passes keep telling my devices the inbox is here', () async {
      devPhone();
      await ownPassForTest();
      await s.delete('own_told', where: "chat = 'me'");
      told.ops.clear();
      await ownPassForTest();
      final me = told.ops.where((o) => o.$1 == 'profile').single.$3;
      expect(me['dv'], isTrue);
    }, skip: skip);

    test('my desk reads a waiting chat for me too', () async {
      devPhone();
      await inbox('waiting', 'open', accepted: 0);
      expect(await op('read', 'p:waiting', {}), isTrue);
      await person('asking', caps: '', accepted: 0);
      expect(await op('read', 'p:asking', {}), isFalse);
    }, skip: skip);

    test(
      'anyone else\'s phone passes no request on, whatever rows it has',
      () async {
        await inbox('waiting', 'open', accepted: 0);
        await comes('waiting', _f({'u': 'u-x', 'm': 'hi', 'sp': 1}));
        expect(told.forwards, isEmpty);
      },
      skip: skip,
    );

    test('anyone else\'s phone moves nothing on a device\'s word, whatever '
        'rows it has', () async {
      await inbox('answered', 'open');
      await op('contact', 'p:answered', {
        'r': {'nickname': null},
        'sp': {'s': 'done'},
      });
      expect((await place('answered'))!['state'], 'open');
    }, skip: skip);
  });

  group('a computer linked to his phone', () {
    test('a waiting chat new here is filed where the phone says, before '
        'it lands, and waits in the inbox, not in requests', () async {
      devDesk();
      expect(
        await forward(
          'new-one',
          _f({
            'u': 'u-n',
            'm': 'first words',
            'sp': 1,
            'h': 'new-one',
            'x': _x,
            'o': '',
          }),
          {'s': 'open', 'f': 5},
        ),
        isTrue,
      );
      expect((await place('new-one'))!['state'], 'open');
      expect((await place('new-one'))!['first_at'], 5);
      expect((await rows('u-n')).single['plaintext'], 'first words');
      await app.refreshContacts();
      expect(app.supportWaiting, 1);
    }, skip: skip);

    test('a waiting chat\'s frame with no place from the phone is dropped, '
        'and nothing files a chat here by its marker', () async {
      devDesk();
      await person('stranger', caps: '', accepted: 0);
      expect(
        await forward('stranger', _f({'u': 'u-s', 'm': 'hi', 'sp': 1}), null),
        isFalse,
      );
      expect(await rows('u-s'), isEmpty);
      expect(await place('stranger'), isNull);
    }, skip: skip);

    test('the phone\'s rows set a chat\'s place here, and rows without one '
        'take it out', () async {
      devDesk();
      await inbox('answered', 'open');
      await op('contact', 'p:answered', {
        'r': {'halo_id': 'answered', 'accepted': 1},
        'sp': {'s': 'done'},
      });
      expect((await place('answered'))!['state'], 'done');
      await op('contact', 'p:answered', {
        'r': {'halo_id': 'answered', 'accepted': 1},
      });
      expect(await place('answered'), isNull);
    }, skip: skip);

    test('a move made here goes to the phone on the chat\'s rows', () async {
      devDesk();
      await inbox('answered', 'open');
      await ownPassForTest();
      told.ops.clear();
      await app.moveToChats('answered');
      await ownPassForTest();
      final o = told.ops.where((o) => o.$2 == 'p:answered').single;
      expect(o.$1, 'contact');
      expect(o.$3['sp'], {'s': 'out'});
    }, skip: skip);

    test('a chat that came through the developer chat moves to the inbox '
        'from here too, and goes to the phone on its rows', () async {
      devDesk();
      await person('via');
      await s.insert('messages', {
        'peer_id': 'via',
        'direction': 'in',
        'plaintext': 'through the dev chat',
        'sent_at': 1,
        'via_dev': 1,
      });
      await ownPassForTest();
      told.ops.clear();
      expect(await app.movableToInbox('via'), isTrue);
      await app.moveToInbox('via');
      expect((await place('via'))!['state'], 'open');
      await ownPassForTest();
      final o = told.ops.where((o) => o.$2 == 'p:via').single;
      expect(o.$3['sp'], {'s': 'open'});
    }, skip: skip);

    test('a quiet session shows no inbox', () async {
      devDesk();
      expect(devInboxHere, isTrue);
      useDatabasesForTest(db, Session(_Rows(s, HaloContainer.decoy)));
      expect(devInboxHere, isFalse);
      useDatabasesForTest(db, Session(db));
    }, skip: skip);

    test('the developer chat is never a chat of the inbox here', () async {
      devDesk();
      await s.insert('support_chats', {
        'halo_id': 'dev:k1',
        'first_at': 1,
        'state': 'open',
      });
      expect(await app.inboxChatHere('dev:k1'), isFalse);
      await inbox('answered', 'open');
      expect(await app.inboxChatHere('answered'), isTrue);
    }, skip: skip);

    test('a state the inbox has no place for files nothing here', () async {
      devDesk();
      await inbox('answered', 'open');
      await op('contact', 'p:answered', {
        'r': {'halo_id': 'answered', 'accepted': 1},
        'sp': {'s': 'gone'},
      });
      expect((await place('answered'))!['state'], 'open');
      await person('new-one', caps: '', accepted: 0);
      expect(
        await forward('new-one', _f({'u': 'u-g', 'm': 'hi', 'sp': 1}), {
          's': 'gone',
        }),
        isFalse,
      );
      expect(await place('new-one'), isNull);
    }, skip: skip);

    test('a waiting chat takes the inbox\'s five, not a stranger\'s two, '
        'as the phone filed it', () async {
      devDesk();
      await inbox('waiting', 'open', accepted: 0);
      for (var i = 0; i < 4; i++) {
        expect(
          await forward('waiting', _f({'u': 'u-$i', 'm': 'help $i', 'sp': 1}), {
            's': 'open',
          }),
          isTrue,
          reason: '$i',
        );
      }
      for (var i = 0; i < 4; i++) {
        expect(await rows('u-$i'), hasLength(1), reason: '$i');
      }
    }, skip: skip);

    test('a message through the developer chat wears its tag here as on the '
        'phone; one in a chat the inbox filed does not', () async {
      devDesk();
      expect(
        await forward(
          'bob',
          _f({'u': 'u-v', 'm': 'via the dev chat', 'sp': 1}),
          null,
        ),
        isTrue,
      );
      expect((await rows('u-v')).single['via_dev'], 1);
      await inbox('answered', 'open');
      expect(
        await forward('answered', _f({'u': 'u-f', 'm': 'filed one', 'sp': 1}), {
          's': 'open',
        }),
        isTrue,
      );
      expect((await rows('u-f')).single['via_dev'], 0);
    }, skip: skip);

    test('the phone\'s profile says whether the inbox shows here', () async {
      linkedRoleForTest = true;
      await op('profile', null, {'h': 'scare-raven-rare', 'dv': true});
      expect(devInboxHere, isTrue);
      expect(app.devInbox, isTrue);
      await op('profile', null, {'h': 'scare-raven-rare'});
      expect(devInboxHere, isFalse);
    }, skip: skip);
  });
}
