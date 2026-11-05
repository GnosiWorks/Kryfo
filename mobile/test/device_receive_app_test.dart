// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices, receiving in the app (step 7 job 5, review fixes): a
// contact's device's copy never moves their caps, and a frame of device
// words alone is never filed on any route: not on the everyday side, not
// into an open vault, not as a shut one opens. a hidden chat's contact's
// device line while the vault is shut is sealed as it came and opened by
// the vault's side as it opens. the databases and the engine stand-ins,
// the switch on
import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devices/device_receive.dart';
import 'package:kryfo/devices/device_send.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/device_store.dart' show deviceTables;
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        deviceReceiveForTest,
        deviceStateForTest,
        hiddenPhoneSendForTest,
        vaultDeviceReceive,
        vaultDevicesForTest,
        AppStateVaultDevices,
        AppStateOutbox,
        useDatabasesForTest,
        useEngineForTest,
        AppStateReceive,
        AppStateVault;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'sqlite_ffi.dart';

const _v = 'plain-friend-here';
const _h = 'quiet-hidden-one';
const _x = '7a1f0c3e9b2d4a5f6e7d8c9b0a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c7b8a9f';

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// the receiving side as the app reaches it: each line opens to what is set
class _Recv implements DeviceReceive {
  final copies = <String, DevCopyIn>{};
  final asked = <String>[];
  // run as a copy opens, before it is handed back
  void Function()? opening;
  @override
  Future<DevCopyIn?> receive(
    String tag,
    String cipher, {
    int? heldSince,
  }) async {
    asked.add('$tag $cipher');
    opening?.call();
    return copies[cipher];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// the engine's calls as the app makes them, each answered by [on]
class _Eng implements DeviceEngine {
  _Eng(this.on);
  final Map<String, dynamic> Function(String op, Map<String, Object?> args) on;
  final ops = <(String, Map<String, Object?>)>[];
  @override
  String call(String op, Map<String, Object?> args) {
    ops.add((op, args));
    return jsonEncode({'rows': [], ...on(op, args)});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoWire implements DeviceWire {
  @override
  Future<String> send(int ident, String arg, String cipher) async => 'down';
  @override
  Future<String> sendOpener(int ident, String arg, String cipher) async =>
      'down';
}

// rows a test reads as sql: open() is the in-memory database
class _MemRows extends ArrivalRows {
  _MemRows(super.c, this.mem);
  final SqliteMem mem;
  @override
  Future<Database> open() async => mem;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    linkedDevicesForTest = true;
  });
  tearDown(() {
    linkedDevicesForTest = false;
    deviceReceiveForTest(null);
    deviceStateForTest(null);
    vaultDevicesForTest(null, null, null);
    hiddenPhoneSendForTest = null;
  });

  test('a copy from a contact\'s computer files their words and leaves their '
      'caps as their phone last said', () async {
    final live = ArrivalRows(HaloContainer.everyday)
      ..person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    live.people[_v]!['caps'] = 'dv,op,ty';
    live.people[_v]!['caps_at'] = 5;
    final io = ArrivalIo()..sessions = [_v];
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    final app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
    final recv = _Recv();
    deviceReceiveForTest(recv);
    // as device_receive.dart hands it on: its own caps taken out, its uid
    // and time kept
    recv.copies['d1'] = (
      peer: _v,
      frame: 'halo/1:{"u":"u-desk","m":"from my computer","w":1780000000000}',
    );
    final failed = await app.receiveRelay([(peer: '$_x/5/1', cipher: 'd1')]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(failed, isEmpty);
    expect(live.msg('u-desk')?['plaintext'], 'from my computer');
    expect(live.people[_v]!['caps'], 'dv,op,ty');
  });

  group('a hidden contact\'s list push', () {
    late ArrivalRows live;
    late ArrivalRows vault;
    late ArrivalStore store;
    late ArrivalIo io;
    late AppState app;
    late VaultRouter router;
    var n = 0;

    setUp(() async {
      live = ArrivalRows(HaloContainer.everyday)
        ..person(_v, onion: 'o-$_v', xpub: 'x-$_v');
      vault = ArrivalRows(HaloContainer.vault)
        ..person(_h, onion: 'o-$_h', xpub: 'x-$_h');
      store = ArrivalStore();
      await store.putHidden(
        _h,
        kHiddenPeer,
        peerCard(
          RouterCard(
            _h,
            'o-$_h',
            'x-$_h',
            backPaired: true,
            devices: HiddenDevices('05$_x', 0, lists: true, [
              (
                their: 5,
                my: 1,
                key: '05${'55' * 32}',
                seed: null,
                opener: true,
              ),
            ]),
          ),
        ),
        1,
      );
      await store.putMeta('pub', 'pub-A');
      router = VaultRouter(store, ArrivalSeal());
      await router.load();
      io = ArrivalIo();
      useEngineForTest(_Engine());
      app = AppState(io: io, router: router)..myId = 'me';
      useDatabasesForTest(live, Session(live));
    });

    Future<void> from(String who, String plain) async {
      final c = 'c${n++}';
      io.opens[c] = (who, plain);
      await app.receiveOnion([c]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    const push = 'halo/1:{"u":"dl:7001","dl":"S0RMMg","db":["S0RCMQ"]}';

    Future<String> riding() async => (await wrapMessage(
      'hidden hello',
      msgUid: 'u-h1',
      sender: asSender(_h),
    )).replaceFirst('halo/1:{', 'halo/1:{"dq":[5],');

    test('to a shut vault: sealed whole and unticked, its words taken as it '
        'opens and no row filed', () async {
      await from(_h, push);
      expect(store.inbox, hasLength(1));
      expect(io.ticksFor('dl:7001'), isEmpty);
      await from(_h, await riding());
      expect(store.inbox, hasLength(2));
      useDatabasesForTest(live, await Session.withVault(live, vault));
      await app.drainSealed(vault, 'priv-A');
      expect(vault.msg('dl:7001'), isNull);
      expect(vault.msg('u-h1')?['plaintext'], 'hidden hello');
      expect(io.ticksFor('dl:7001'), isEmpty);
    });

    test('to an open vault: no row and no receipt, a message riding with '
        'device words is filed as itself', () async {
      useDatabasesForTest(live, await Session.withVault(live, vault));
      await app.drainSealed(vault, 'priv-A');
      await from(_h, push);
      await from(_h, await riding());
      expect(vault.msg('dl:7001'), isNull);
      expect(io.ticksFor('dl:7001'), isEmpty);
      expect(vault.msg('u-h1')?['plaintext'], 'hidden hello');
      expect(live.msgs, isEmpty);
    });

    test('a line on their desk\'s pair while the vault is shut is sealed as '
        'it came, the everyday side opens nothing of it, and the vault\'s '
        'side files it as the vault opens', () async {
      final everyday = _Recv();
      deviceReceiveForTest(everyday);
      final failed = await app.receiveRelay([
        (peer: '$_x/5/1/opn', cipher: 'desk-1'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(failed, isEmpty);
      expect(everyday.asked, isEmpty);
      expect(store.inbox, hasLength(1));
      expect(live.msgs, isEmpty);
      final hidden = _Recv();
      hidden.copies['desk-1'] = (
        peer: _h,
        frame: 'halo/1:{"u":"u-desk-h","m":"from the desk","w":1780000000000}',
      );
      useDatabasesForTest(live, await Session.withVault(live, vault));
      vaultDevicesForTest(hidden, null, vault);
      await app.drainSealed(vault, 'priv-A');
      expect(hidden.asked, ['$_x/5/1/opn desk-1']);
      expect(vault.msg('u-desk-h')?['plaintext'], 'from the desk');
      expect(live.msgs, isEmpty);
      expect(store.inbox, isEmpty);
    });

    test(
      'a sealed line waits while the vault\'s side is not running',
      () async {
        deviceReceiveForTest(_Recv());
        await app.receiveRelay([(peer: '$_x/5/1/opn', cipher: 'desk-2')]);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        useDatabasesForTest(live, await Session.withVault(live, vault));
        await app.drainSealed(vault, 'priv-A');
        expect(store.inbox, hasLength(1));
      },
    );

    test('a desk copy opened as the vault shuts is sealed as a device\'s, '
        'and as it opens leaves their caps as their phone last said', () async {
      vault.people[_h]!['caps'] = 'dv,op,ty';
      vault.people[_h]!['caps_at'] = 5;
      useDatabasesForTest(live, await Session.withVault(live, vault));
      await app.drainSealed(vault, 'priv-A');
      deviceReceiveForTest(_Recv());
      final hidden = _Recv()
        ..copies['desk-3'] = (
          peer: _h,
          frame: 'halo/1:{"u":"u-desk-c","m":"as it shut","w":1780000000000}',
        );
      // the lock goes up while it opens
      hidden.opening = () => useDatabasesForTest(live, Session(live));
      vaultDevicesForTest(hidden, null, vault);
      await app.receiveRelay([(peer: '$_x/5/1/opn', cipher: 'desk-3')]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.inbox, hasLength(1));
      expect(vault.msg('u-desk-c'), isNull);
      useDatabasesForTest(live, await Session.withVault(live, vault));
      await app.drainSealed(vault, 'priv-A');
      expect(vault.msg('u-desk-c')?['plaintext'], 'as it shut');
      expect(vault.people[_h]!['caps'], 'dv,op,ty');
    });

    test('a copy opened as a close starts holds nothing while it waits for '
        'that close, and is sealed as a device\'s once it ends', () async {
      vault.people[_h]!['caps'] = 'dv,op,ty';
      vault.people[_h]!['caps_at'] = 5;
      useDatabasesForTest(live, await Session.withVault(live, vault));
      await app.drainSealed(vault, 'priv-A');
      deviceReceiveForTest(_Recv());
      final closing = Completer<void>();
      final hidden = _Recv()
        ..copies['desk-5'] = (
          peer: _h,
          frame: 'halo/1:{"u":"u-desk-d","m":"in the close","w":1780000000000}',
        );
      hidden.opening = () {
        app.closingForTest = closing;
        useDatabasesForTest(live, Session(live));
      };
      vaultDevicesForTest(hidden, null, vault);
      final going = app.receiveRelay([(peer: '$_x/5/1/opn', cipher: 'desk-5')]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // the close waits for arrivals: this one must not hold it up
      expect(app.arrivingForTest, isFalse);
      expect(store.inbox, isEmpty);
      app.closingForTest = null;
      closing.complete();
      await going;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.inbox, hasLength(1));
      useDatabasesForTest(live, await Session.withVault(live, vault));
      await app.drainSealed(vault, 'priv-A');
      expect(vault.msg('u-desk-d')?['plaintext'], 'in the close');
      expect(vault.people[_h]!['caps'], 'dv,op,ty');
    });

    test('a sealed line whose open throws stays for the next open; one older '
        'than the relays keep goes', () async {
      deviceReceiveForTest(_Recv());
      await app.receiveRelay([(peer: '$_x/5/1/opn', cipher: 'desk-4')]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await router.seal(
        Unsealed(
          _h,
          'desk-old',
          false,
          DateTime.now().millisecondsSinceEpoch - kBlockListenFor - 1,
          deviceTag: '$_x/5/1/opn',
        ),
      );
      expect(store.inbox, hasLength(2));
      final hidden = _Recv()..opening = () => throw StateError('busy');
      useDatabasesForTest(live, await Session.withVault(live, vault));
      vaultDevicesForTest(hidden, null, vault);
      await app.drainSealed(vault, 'priv-A');
      expect(hidden.asked, hasLength(2));
      expect(store.inbox, hasLength(1));
    });

    test('a removal owed to hidden chats is kept with no names: it goes to '
        'their phone while the vault is shut, again at every start until it '
        'went, and the vault\'s open queues it as its own push instead of '
        'letting it go', () async {
      final everyday = SqliteMem.open();
      if (everyday == null) {
        markTestSkipped('no sqlite on this host');
        return;
      }
      await everyday.execute(
        'CREATE TABLE signal_meta (k TEXT PRIMARY KEY, v TEXT)',
      );
      await everyday.execute(
        'CREATE TABLE contacts (halo_id TEXT, ident INTEGER, ikey TEXT, '
        'accepted INTEGER, blocked INTEGER DEFAULT 0, caps TEXT)',
      );
      await deviceTables(everyday, (db, sql) async {
        try {
          await db.execute(sql);
        } catch (_) {
          // no identities table here
        }
      });
      final rows = _MemRows(HaloContainer.everyday, everyday)
        ..person(_v, onion: 'o-$_v', xpub: 'x-$_v');
      useDatabasesForTest(rows, Session(rows));
      final list = base64Encode([
        ...List.filled(37, 1),
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        8,
        ...List.filled(60, 2),
      ]);
      final ds = DeviceState(_Eng((op, _) => {'list': list}));
      deviceStateForTest(ds);
      final sent = <(int, String, String, String)>[];
      var ok = false;
      Future<bool> phoneSend(
        int ident,
        String peer,
        String identity,
        String frame,
      ) async {
        sent.add((ident, peer, identity, frame));
        return ok;
      }

      hiddenPhoneSendForTest = phoneSend;
      // an addition waits for the open: nothing owed
      await app.hiddenListsChangedForTest([
        (ident: 0, version: 8, added: [4], removed: false),
      ]);
      expect(sent, isEmpty);
      // the everyday send loop keeps a removal owed in its own write
      final everydaySend = DeviceSend(
        state: ds,
        db: () async => everyday,
        sessions: (_) async => throw StateError('no sessions here'),
        wire: _NoWire(),
        hiddenRemovals: true,
      );
      await everydaySend.listsChanged([
        (ident: 0, version: 8, added: const [], removed: true),
      ]);
      expect((await everyday.query('signal_meta')).single, {
        'k': '${kHiddenRemovalMeta}0',
        'v': '8',
      });
      await app.hiddenListsChangedForTest([
        (ident: 0, version: 8, added: const [], removed: true),
      ]);
      expect(sent, hasLength(1));
      final (ident, peer, identity, frame) = sent.single;
      expect((ident, peer, identity), (0, _h, '05$_x'));
      final j = jsonDecode(frame.substring('halo/1:'.length)) as Map;
      expect(j, {'u': 'dl:8', 'dl': list});
      // it did not go: the next pump tries it again, then no more
      ok = true;
      await app.pushHiddenRemovalsForTest();
      expect(sent, hasLength(2));
      await app.pushHiddenRemovalsForTest();
      expect(sent, hasLength(2));
      // a restart: it goes again, still owed
      hiddenPhoneSendForTest = phoneSend;
      await app.pushHiddenRemovalsForTest();
      expect(sent, hasLength(3));
      // the vault opens: the removal is its own push now, kept there
      // until their phone answers, and owed no more on the everyday side
      final vmem = SqliteMem.open()!;
      await vmem.execute(
        'CREATE TABLE contacts (halo_id TEXT, ident INTEGER, ikey TEXT, '
        'accepted INTEGER, blocked INTEGER DEFAULT 0, caps TEXT)',
      );
      await deviceTables(vmem, (db, sql) async {
        try {
          await db.execute(sql);
        } catch (_) {
          // no identities table here
        }
      });
      await vmem.execute(
        "INSERT INTO contacts VALUES ('$_h', 0, '05$_x', 1, 0, 'dv')",
      );
      final vsend = DeviceSend(
        state: ds,
        db: () async => vmem,
        mine: () async => everyday,
        noOwn: true,
        sessions: (_) async => throw StateError('no sessions here'),
        wire: _NoWire(),
      );
      vaultDevicesForTest(null, vsend, _MemRows(HaloContainer.vault, vmem));
      await app.pushHiddenRemovalsForTest();
      final queued = (await vmem.query('dev_pushes')).single;
      expect(queued['peer'], '05$_x');
      expect(queued['kind'], 'remove');
      expect(queued['version'], 8);
      expect(await everyday.query('signal_meta'), isEmpty);
      expect(sent, hasLength(3));
    });
  });

  test('a lock while the vault\'s side starts lets go of what it took in, '
      'and leaves no side running for the shut vault', () async {
    final mem = SqliteMem.open();
    if (mem == null) {
      markTestSkipped('no sqlite on this host');
      return;
    }
    await mem.execute(
      'CREATE TABLE contacts (halo_id TEXT, ident INTEGER, ikey TEXT, '
      'accepted INTEGER, blocked INTEGER DEFAULT 0, caps TEXT)',
    );
    await deviceTables(mem, (db, sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // no identities table here
      }
    });
    await mem.execute(
      "INSERT INTO contacts VALUES ('$_h', 0, '05$_x', 1, 0, 'dv')",
    );
    final everyday = SqliteMem.open()!;
    await everyday.execute(
      'CREATE TABLE contacts (halo_id TEXT, ikey TEXT, accepted INTEGER)',
    );
    final live = _MemRows(HaloContainer.everyday, everyday);
    final vault = _MemRows(HaloContainer.vault, mem)
      ..person(_h, onion: 'o-$_h', xpub: 'x-$_h');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    final app = AppState(io: ArrivalIo(), router: router)..myId = 'me';
    final eng = _Eng((op, _) {
      // the lock goes up as the engine takes them in
      if (op == 'load_peers') useDatabasesForTest(live, Session(live));
      return {};
    });
    deviceStateForTest(DeviceState(eng));
    deviceReceiveForTest(_Recv());
    useDatabasesForTest(live, await Session.withVault(live, vault));
    await app.vaultDevicesInForTest(vault);
    expect([for (final (op, _) in eng.ops) op], ['load_peers', 'drop_peers']);
    expect(eng.ops.last.$2['peers'], ['05$_x']);
    expect(vaultDeviceReceive, isNull);
  });
}
