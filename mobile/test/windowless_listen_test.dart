// SPDX-License-Identifier: GPL-3.0-or-later
// a process the service or the job started has no window and draws no
// frame: it listens for its contacts, its hidden chats, its rooms and the
// dev chat's lane all the same, once, and a window opening later adds
// nothing. a shut vault stays shut, its arrivals sealed, and a check-in
// kicks the relays only once the keys are listened on, also when the job
// knocks before the boot got that far. one contact that fails is tried
// again once, and the contacts wait a while for signal. no frame is drawn
// in a plain test unless one is asked for, as on a phone with no surface
import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/vault_life.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'dev_chat_fakes.dart' show devCard;
import 'mem_db.dart';

const _c = 'contact-we-know';
const _h = 'hidden-contact';
const _b = 'contact-that-fails';
const _room = 'room00000001';
const _roomPub = 'aa';
const _creator = 'cc';

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

// the relays as a start and a check-in reach them: the room lanes opened,
// and one message waiting on the contact's address, handed over by a kick
// only to a key listened on
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
  // the room members listened to
  final roomHeard = <String>[];

  @override
  void roomSubscribeBg(String priv, String peerPub) => roomHeard.add(peerPub);

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

// signal and the relays, with a key whose listen fails [failsFor] times
class _Io extends ArrivalIo {
  String? failing;
  var failsFor = 0;

  @override
  void listen(String xPub) {
    if (xPub == failing && failsFor > 0) {
      failsFor--;
      throw StateError('no runner');
    }
    super.listen(xPub);
  }
}

// the everyday rows, no file waiting for its slices, the dev chat started
class _Rows extends ArrivalRows {
  _Rows(this.dev) : super(HaloContainer.everyday);
  final MemDb dev;
  // the contacts cannot be read while set
  var contactsDown = false;

  @override
  Future<List<Map<String, Object?>>> mediaWants() async => const [];

  @override
  DevChat get devChat => DevChat(() async => dev, shred: (_) async {});

  @override
  Future<List<Map<String, Object?>>> contacts() async {
    if (contactsDown) throw StateError('locked');
    return super.contacts();
  }
}

final _devKey = devCard('m1');

class _World {
  final dev = MemDb();
  late final live = _Rows(dev);
  final vault = ArrivalRows(HaloContainer.vault);
  final store = ArrivalStore();
  final io = _Io();
  final host = _Host();
  late final engine = _Engine(io);
  late AppState app;

  static Future<_World> make({bool signal = true}) async {
    final w = _World();
    w.live.person(_c, onion: 'o-$_c', xpub: 'x-$_c');
    w.live.group(_room, [_roomPub, _creator], admin: _creator);
    w.live.groupRows[_room]!.addAll({
      'room_priv': 'priv',
      'room_pub': _roomPub,
      'expires_at': DateTime.now().millisecondsSinceEpoch + 3600000,
      'creator_pub': _creator,
    });
    await devChatTables(w.dev, now: 1);
    await w.dev.update(
      'devchat',
      {'state': DevState.everyday.name, 'key_id': 'm1', 'started_at': 1},
      where: 'k = ?',
      whereArgs: [1],
    );
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
      // short, so the tests do not wait the phone's seconds
      ..noFrameWait = const Duration(milliseconds: 200)
      ..listenRetryGap = const Duration(milliseconds: 300)
      ..signalWait = const Duration(seconds: 20);
    if (signal) w.app.signalReadyForTest();
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
    useDevKeysForTest([_devKey]);
  });

  tearDown(() => useDevKeysForTest(null));

  test('a start with no window listens for everyone', () async {
    final w = await _World.make();
    w.app.listenAtStart();
    await w.app.listenedAtStart.timeout(const Duration(seconds: 5));
    expect(w.heard('x-$_c'), 1);
    // the hidden chat's key too, off the router's card
    expect(w.heard('x-$_h'), 1);
    // the room's members, the dev chat's lane, and what is held marked
    expect(w.engine.roomHeard, [_creator]);
    expect(w.heard(_devKey.xPub), 1);
    expect(w.io.marked, [
      ['x-$_c'],
    ]);
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
    expect(w.engine.roomHeard, [_creator]);
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
    expect(w.heard(_devKey.xPub), 1);
    expect(w.engine.roomHeard, [_creator]);
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

  Future<_World> waitingCheckIn() async {
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
    return w;
  }

  void drainedIt(_World w, int drained) {
    expect(w.engine.heardAtKick.first, contains('x-$_c'));
    expect(drained, 1);
    expect(w.live.msgs.map((m) => m['msg_uid']), ['w']);
    expect(w.io.rang, isNotEmpty);
  }

  test(
    'a check-in job drains what waited for a contact',
    () async {
      final w = await waitingCheckIn();
      // the boot, then the job's knock before the start has listened
      w.app.listenAtStart();
      drainedIt(w, await w.app.drainNow());
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('a knock from the helper app is the same check-in, locked and in a '
      'decoy, and counts as a wake-up', () async {
    final w = await waitingCheckIn();
    w.app.deliveryModeForTest = DeliveryMode.helper;
    lockState.openForTest(enabled: true);
    lockState.lock();
    lockState.inDecoy = true;
    addTearDown(() {
      lockState.inDecoy = false;
      lockState.openForTest();
    });
    expect(lockState.locked, isTrue);
    w.app.listenAtStart();
    drainedIt(w, await w.app.drainNow(why: 'push'));
    expect(w.app.lastCheckHow, contains('"why":"push"'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(kLastWakeKey), greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    'a knock while a check-in runs is owed, and asked for once it ends',
    () async {
      final asked = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('halo/helper'), (
            call,
          ) async {
            asked.add(call.method);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('halo/helper'), null),
      );
      final w = await waitingCheckIn();
      w.app.deliveryModeForTest = DeliveryMode.helper;
      w.app.listenAtStart();
      final first = w.app.drainNow();
      await _wait(50);
      expect(w.app.checkingIn, isTrue);
      expect(await w.app.drainNow(why: 'push'), 0);
      expect(asked, isNot(contains('helperKnockAgain')));
      await first;
      expect(asked, contains('helperKnockAgain'));
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a job that knocks before the boot listens waits for it',
    () async {
      final w = await waitingCheckIn();
      // the boot under way and not yet at the listen
      w.app.bootingForTest = true;
      final drained = w.app.drainNow();
      await _wait(500);
      expect(w.engine.kicks, 0);
      w.app.listenAtStart();
      drainedIt(w, await drained);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('one that fails leaves the rest listened, and is tried again '
      'once', () async {
    final w = await _World.make();
    w.live.person(_b, onion: 'o-$_b', xpub: 'x-$_b');
    w.io
      ..failing = 'x-$_b'
      ..failsFor = 1;
    w.app.listenAtStart();
    await w.app.listenedAtStart.timeout(const Duration(seconds: 5));
    expect(w.heard('x-$_b'), 0);
    expect(w.heard('x-$_c'), 1);
    expect(w.heard('x-$_h'), 1);
    await _wait(600);
    expect(w.heard('x-$_b'), 1);
    // those already listened on keep their runners
    expect(w.heard('x-$_c'), 1);
    expect(w.heard('x-$_h'), 1);
  });

  test('contacts that could not be read are listened for later', () async {
    final w = await _World.make();
    w.live.contactsDown = true;
    w.app.listenAtStart();
    await w.app.listenedAtStart.timeout(const Duration(seconds: 5));
    expect(w.heard('x-$_c'), 0);
    w.live.contactsDown = false;
    await _wait(600);
    expect(w.heard('x-$_c'), 1);
    expect(w.heard('x-$_h'), 1);
  });

  test('the contacts wait for signal, for a while', () async {
    final w = await _World.make(signal: false);
    w.app.listenAtStart();
    await _wait(500);
    // rooms and the dev chat's lane do not wait
    expect(w.engine.roomHeard, [_creator]);
    expect(w.heard(_devKey.xPub), 1);
    expect(w.heard('x-$_c'), 0);
    w.app.signalReadyForTest();
    await w.app.listenedAtStart.timeout(const Duration(seconds: 5));
    expect(w.heard('x-$_c'), 1);

    // and a signal that never comes holds them up only so long
    final v = await _World.make(signal: false);
    v.app.signalWait = const Duration(milliseconds: 300);
    v.app.listenAtStart();
    await v.app.listenedAtStart.timeout(const Duration(seconds: 5));
    expect(v.heard('x-$_c'), 1);
  });
}
