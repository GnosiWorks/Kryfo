// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices, receiving in the app (step 7 job 5, review fixes): a
// contact's device's copy never moves their caps, and a frame of device
// words alone is never filed on any route: not on the everyday side, not
// into an open vault, not as a shut one opens. a hidden chat's contact's
// device line while the vault is shut is sealed as it came and opened by
// the vault's side as it opens. the databases and the engine stand-ins,
// the switch on
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devices/device_receive.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        deviceReceiveForTest,
        vaultDevicesForTest,
        useDatabasesForTest,
        useEngineForTest,
        AppStateReceive,
        AppStateVault;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

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
  @override
  Future<DevCopyIn?> receive(
    String tag,
    String cipher, {
    int? heldSince,
  }) async {
    asked.add('$tag $cipher');
    return copies[cipher];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
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
    vaultDevicesForTest(null, null, null);
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
            devices: HiddenDevices('05$_x', 0, [
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
      final router = VaultRouter(store, ArrivalSeal());
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
  });
}
