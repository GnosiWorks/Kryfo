// SPDX-License-Identifier: GPL-3.0-or-later
// a process the service or the job started has no window and draws no
// frame: it listens for its contacts, its hidden chats and its rooms all
// the same, once, and a window opening later adds nothing. a shut vault
// stays shut, its arrivals sealed, and a check-in kicks the relays only
// once the keys are listened on. no frame is drawn in a plain test unless
// one is asked for, as on a phone with no surface
import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/vault_life.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _c = 'contact-we-know';
const _h = 'hidden-contact';

SenderInfo _as(String id) =>
    SenderInfo(haloId: id, edPub: 'ed-$id', onion: 'o-$id', xPub: 'x-$id');

// the vault's own life: nothing here may be asked while it is shut
class _Host implements VaultHost {
  final asked = <String>[];

  @override
  dynamic noSuchMethod(Invocation i) {
    asked.add('${i.memberName}');
    throw StateError('vault host: ${i.memberName}');
  }
}

// the relays as a check-in reaches them: one message waits on the
// contact's address and is handed over by a kick only to a key listened on
class _Engine implements HaloEngine {
  _Engine(this.io);
  final ArrivalIo io;
  late AppState app;
  var walking = 0;
  var begun = 1;
  var kicks = 0;
  final waiting = <({String peer, String cipher})>[];
  // the keys listened on when each kick came
  final heardAtKick = <List<String>>[];

  @override
  (int, int) catchupState() => (walking, begun);

  @override
  String nostrKick() {
    kicks++;
    begun++;
    walking = 1;
    heardAtKick.add([...io.listened]);
    final due = [
      for (final m in waiting)
        if (io.listened.contains(m.peer)) m,
    ];
    waiting.removeWhere(due.contains);
    unawaited(() async {
      if (due.isNotEmpty) await app.receiveRelay(due);
      walking = 0;
    }());
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

// the everyday rows, no file waiting for its slices
class _Rows extends ArrivalRows {
  _Rows() : super(HaloContainer.everyday);

  @override
  Future<List<Map<String, Object?>>> mediaWants() async => const [];
}

class _World {
  final live = _Rows();
  final vault = ArrivalRows(HaloContainer.vault);
  final store = ArrivalStore();
  final io = ArrivalIo();
  final host = _Host();
  late final engine = _Engine(io);
  late AppState app;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_c, onion: 'o-$_c', xpub: 'x-$_c');
    w.vault.person(_h, onion: 'o-$_h', xpub: 'x-$_h');
    await w.store.putHidden(
      _h,
      kHiddenPeer,
      peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
      1,
    );
    await w.store.putMeta('pub', 'pub-A');
    final router = VaultRouter(w.store, ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router, host: w.host)
      ..myId = 'me'
      ..containersOpenedForTest()
      // short, so the tests do not wait the phone's two seconds
      ..noFrameWait = const Duration(milliseconds: 200);
    w.engine.app = w.app;
    useEngineForTest(w.engine);
    // the start's session: the everyday one, the vault shut
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  int heard(String xPub) => io.listened.where((x) => x == xPub).length;
}

// a frame drawn, as when a window opens
void _frame() {
  final b = SchedulerBinding.instance;
  b.handleBeginFrame(Duration.zero);
  b.handleDrawFrame();
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('windowless_listen_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('a start with no window listens for everyone', () async {
    final w = await _World.make();
    w.app.listenAtStart();
    await w.app.listenedAtStart.timeout(const Duration(seconds: 5));
    expect(w.heard('x-$_c'), 1);
    // the hidden chat's key too, off the router's card
    expect(w.heard('x-$_h'), 1);
  });

  test('a window opening after it listens no second time', () async {
    final w = await _World.make();
    w.app.listenAtStart();
    await w.app.listenedAtStart.timeout(const Duration(seconds: 5));
    final once = [...w.io.listened];
    _frame();
    // past the beat a frame waits before listening
    await _wait(500);
    // and a second boot path asking again
    w.app.listenAtStart();
    await _wait(400);
    expect(w.io.listened, once);
    expect(w.heard('x-$_c'), 1);
  });

  test('a window first, then the wait for none, listens once', () async {
    final w = await _World.make();
    w.app.noFrameWait = const Duration(milliseconds: 600);
    w.app.listenAtStart();
    _frame();
    await w.app.listenedAtStart.timeout(const Duration(seconds: 5));
    await _wait(900);
    expect(w.heard('x-$_c'), 1);
    expect(w.heard('x-$_h'), 1);
  });

  test('a shut vault stays shut, what comes for it sealed', () async {
    final w = await _World.make();
    w.app.listenAtStart();
    await w.app.listenedAtStart.timeout(const Duration(seconds: 5));
    w.io.opens['v1'] = (
      _h,
      await wrapMessage('for the vault', msgUid: 'v', sender: _as(_h)),
    );
    await w.app.receiveRelay([(peer: 'x-$_h', cipher: 'v1')]);
    await _wait(20);
    expect(w.host.asked, isEmpty);
    expect(w.vault.calls, isEmpty);
    expect(w.store.inbox.map((r) => r['uid']), ['v']);
    expect(w.live.rowWrites, isEmpty);
    expect(w.io.shown, isEmpty);
  });

  test(
    'a check-in job drains what waited for a contact',
    () async {
      final w = await _World.make();
      w.app
        ..deliveryModeForTest = DeliveryMode.checkins
        ..sendModeForTest = 'fast'
        ..docsPathForTest = docs.path
        ..noFrameWait = const Duration(milliseconds: 300);
      w.io.opens['w1'] = (
        _c,
        await wrapMessage('while you slept', msgUid: 'w', sender: _as(_c)),
      );
      w.engine.waiting.add((peer: 'x-$_c', cipher: 'w1'));
      // the boot, then the job's knock before the start has listened
      w.app.listenAtStart();
      final drained = await w.app.drainNow();
      expect(w.engine.heardAtKick.first, contains('x-$_c'));
      expect(drained, 1);
      expect(w.live.msgs.map((m) => m['msg_uid']), ['w']);
      expect(w.io.rang, isNotEmpty);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
