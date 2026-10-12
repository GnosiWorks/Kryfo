// SPDX-License-Identifier: GPL-3.0-or-later
// keeping the route honest. relay mode reads its relay on its own clock, so
// an outage shows while tor sits still and a mended relay clears the hint. a
// tor wake that fails is tried again while the app is open, and a tor the
// engine already lets run is put to sleep again. a mode switch sets its
// relay list before anything subscribes, one switch at a time, and moves
// everyone listened for. a spell offline or another mode's outage never
// shows as our relay's. a friend's lines count only when the engine took one.
// a tor stuck on a network that blocks it brings up the bridges card on time
// alone, and a route torn down that climbs back to where it stuck keeps it.
// bridges, a reconnect, a mode or a network the person changed start a try
// of their own, and no card shows while it climbs. a mode that does not
// save moves nothing, runners that did not move go on the next try, the
// app takes a mode once the engine has it, and a tap on the modes page is
// never undone by a read still on its way or a tap before it. a stop tor
// refuses is tried again, further apart each time, a check-in no relay
// answered is not taken for one and a slow wake leaves the relays their
// time, and automatic stuck is asked again on coming back, once a minute.
// the engine and the rows are stand-ins
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

class _Engine implements HaloEngine {
  _Engine(this.log);
  final List<String> log;

  List<Object?> relays = const [];
  @override
  Map<String, dynamic> transportState() => {'relays': relays};

  // the engine's own pause flag: a stop sets it, a resume clears it before
  // it asks tor, so a failed resume leaves it clear
  bool paused = false;
  // what each resume answers, the last one repeating
  List<String> resumes = ['ok'];
  // a stop that takes its time, as one over a slow control port
  Completer<void>? stopGate;
  // what each stop answers, the last one repeating. a refused one leaves
  // tor on the network, as the engine does
  List<String> stops = ['ok'];
  @override
  Future<String> torStop() async {
    log.add('stop');
    await stopGate?.future;
    final r = stops.length > 1 ? stops.removeAt(0) : stops.first;
    if (!r.startsWith('error')) paused = true;
    return r;
  }

  @override
  Future<String> torResume() async {
    log.add('resume');
    paused = false;
    return resumes.length > 1 ? resumes.removeAt(0) : resumes.first;
  }

  @override
  bool torPaused() => paused;

  @override
  Future<String> startListenerBg(String dataDir) async {
    log.add('start');
    return 'abcdef.onion';
  }

  @override
  String setTransportMode(String mode) {
    log.add('mode:$mode');
    return 'ok';
  }

  @override
  String nostrInit(String relaysCSV) {
    log.add('init:$relaysCSV');
    return 'ok';
  }

  // the answer to a mode, and its checks of the lines
  String mode = 'ok';
  String checks = '[]';
  @override
  String setBridgeMode(String m, String opts) => mode;
  @override
  String bridgeLineChecks() => checks;

  @override
  void restartTor() => log.add('restart');
  @override
  void bridgeRetry() => log.add('retry');
  @override
  void networkChanged({bool online = true}) =>
      log.add(online ? 'network' : 'offline');
  @override
  void networkDetail(String json) => log.add('detail');
  @override
  void connectivitySeen(bool on) => log.add('seen:$on');
  @override
  Future<String> reconnectNow() async {
    log.add('now');
    return 'ok';
  }

  // the route the engine says it is on, '' for an engine that cannot say
  String engineMode = '';
  @override
  String transportMode() => engineMode;

  // (walking, begun) of the relays' catch-up
  (int, int) catchup = (0, 1);
  @override
  (int, int) catchupState() => catchup;
  @override
  String nostrKick() {
    log.add('kick');
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Io extends ArrivalIo {
  _Io(this.log);
  final List<String> log;
  @override
  void listen(String xPub) {
    log.add('listen:$xPub');
    super.listen(xPub);
  }
}

// a chat deleted here: its row goes, its runner lives on so they can still
// reach us
class _Rows extends ArrivalRows {
  _Rows() : super(HaloContainer.everyday);
  @override
  Future<void> deleteConversation(String haloId) async {
    calls.add('deleteConversation:$haloId');
    people.remove(haloId);
  }
}

// secure storage that can refuse the mode, as a keystore that fails does
class _Store extends MapBase<String, String> {
  final _m = <String, String>{};
  bool refuse = false;
  // a mode it will not take
  String? refuseMode;
  @override
  String? operator [](Object? key) => _m[key];
  @override
  void operator []=(String key, String value) {
    if (key == 'send_mode' && (refuse || value == refuseMode)) {
      throw PlatformException(code: 'keystore');
    }
    _m[key] = value;
  }

  @override
  void clear() => _m.clear();
  @override
  Iterable<String> get keys => _m.keys;
  @override
  String? remove(Object? key) => _m.remove(key);
}

// rows whose contact list can fail, or wait until let go
class _Flaky extends ArrivalRows {
  _Flaky() : super(HaloContainer.everyday);
  bool down = false;
  Completer<void>? gate;
  @override
  Future<List<Map<String, Object?>>> mediaWants() async => [];
  @override
  Future<List<Map<String, Object?>>> contacts() async {
    await gate?.future;
    if (down) throw StateError('db');
    return super.contacts();
  }
}

const _failing = [
  {'url': 'wss://relay.kryfo.app', 'fails': 3},
];
const _fine = [
  {'url': 'wss://relay.kryfo.app', 'fails': 0},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> log;
  late _Engine eng;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    log = [];
    eng = _Engine(log);
    useEngineForTest(eng);
  });

  group('relay mode reads its relay on its own', () {
    final t0 = DateTime(2026, 10, 1, 12);

    test('an outage shows while tor sits still, and goes when the relay '
        'answers', () {
      final app = AppState()..sendModeForTest = 'balanced';
      var told = 0;
      app.addListener(() => told++);

      eng.relays = _failing;
      app.sampleRelayHealth(now: t0);
      expect(app.suggestFastFallbackAt(t0), isFalse);
      app.sampleRelayHealth(now: t0.add(const Duration(seconds: 60)));
      expect(told, 0);
      app.sampleRelayHealth(now: t0.add(const Duration(seconds: 95)));
      expect(
        app.suggestFastFallbackAt(t0.add(const Duration(seconds: 95))),
        isTrue,
      );
      expect(told, 1);

      eng.relays = _fine;
      final later = t0.add(const Duration(hours: 2));
      app.sampleRelayHealth(now: later);
      expect(app.suggestFastFallbackAt(later), isFalse);
      expect(told, 2);
    });

    test('a spell offline is not an outage, and the clock starts again when '
        'the network is back', () {
      final app = AppState()..sendModeForTest = 'balanced';
      eng.relays = _failing;
      app.noteOnline(false);
      for (var s = 0; s <= 120; s += 5) {
        app.sampleRelayHealth(now: t0.add(Duration(seconds: s)));
      }
      app.noteOnline(true);
      // the runner is still waiting out its backoff, so the row still fails
      app.sampleRelayHealth(now: t0.add(const Duration(seconds: 125)));
      expect(
        app.suggestFastFallbackAt(t0.add(const Duration(seconds: 126))),
        isFalse,
      );
      // still down a full spell after it came back: that one is the relay
      app.sampleRelayHealth(now: t0.add(const Duration(seconds: 220)));
      expect(
        app.suggestFastFallbackAt(t0.add(const Duration(seconds: 220))),
        isTrue,
      );
    });

    test('back online, the clock starts again with no read in between', () {
      final app = AppState()..sendModeForTest = 'balanced';
      eng.relays = _failing;
      app.sampleRelayHealth(now: t0);
      app.noteOnline(false);
      app.noteOnline(true);
      expect(
        app.suggestFastFallbackAt(t0.add(const Duration(seconds: 95))),
        isFalse,
      );
    });

    test('the status poll samples it in relay mode', () {
      final src = File('lib/main.dart').readAsStringSync();
      final poll = src.substring(
        src.indexOf('Timer.periodic(const Duration(seconds: 1), (t) {'),
      );
      final head = poll.substring(0, poll.indexOf('final raw = engine'));
      expect(head, contains("_sendMode == 'balanced'"));
      expect(head, contains('sampleRelayHealth()'));
    });
  });

  group('a tor wake that fails', () {
    // a check-ins phone: left, so tor sleeps, then opened again
    Future<AppState> asleep(WidgetTester t) async {
      final app = AppState()..deliveryModeForTest = DeliveryMode.checkins;
      app.appInFront(false);
      await t.pump(const Duration(seconds: 95));
      expect(log, ['stop']);
      expect(app.torHeld, isTrue);
      log.clear();
      return app;
    }

    testWidgets('is tried again while the app is open', (t) async {
      final app = await asleep(t);
      eng.resumes = ['error: timeout', 'ok'];
      app.appInFront(true);
      await t.pump();
      expect(log, ['resume']);
      expect(app.torHeld, isTrue);

      await t.pump(const Duration(seconds: 16));
      expect(log, ['resume', 'resume', 'start']);
      expect(app.torHeld, isFalse);
      expect(app.myOnion, 'abcdef.onion');
    });

    testWidgets('is not tried again once the app is left', (t) async {
      final app = await asleep(t);
      eng.resumes = ['error: timeout'];
      app.appInFront(true);
      await t.pump();
      app.appInFront(false);
      await t.pump(const Duration(seconds: 30));
      expect(log, ['resume']);
      // the sleep that follows leaving is all that happens
      await t.pump(const Duration(seconds: 65));
      expect(log, ['resume', 'stop']);
    });

    testWidgets('leaves a tor the engine lets run, which the next sleep '
        'stops', (t) async {
      final app = await asleep(t);
      eng.resumes = ['error: timeout'];
      app.appInFront(true);
      await t.pump();
      expect(eng.paused, isFalse);
      app.appInFront(false);
      await t.pump(const Duration(seconds: 95));
      expect(log, ['resume', 'stop']);
      expect(eng.paused, isTrue);
      expect(app.torHeld, isTrue);

      // asleep for real, a second sleep asks nothing of the engine
      log.clear();
      app.appInFront(false);
      await t.pump(const Duration(seconds: 95));
      expect(log, isEmpty);
    });
  });

  group('a mode switch', () {
    const c = 'contact-we-know';

    Future<AppState> world() async {
      final live = ArrivalRows(HaloContainer.everyday)
        ..person(c, onion: 'o-$c', xpub: 'x-$c');
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      final app = AppState(io: _Io(log), router: router)..myId = 'me';
      useDatabasesForTest(live, Session(live));
      return app;
    }

    test('sets its relay list before anything subscribes, one switch at a '
        'time', () async {
      final app = await world();
      final a = app.setSendMode('balanced');
      final b = app.setSendMode('private');
      await Future.wait([a, b]);
      expect(log, [
        'mode:balanced',
        'init:${app.relaysFor('balanced')}',
        'listen:x-$c',
        'mode:private',
        'init:${app.relaysFor('private')}',
        'listen:x-$c',
      ]);
      expect(app.sendMode, 'private');
    });

    test('moves everyone listened for, not just contacts, once each', () async {
      final live = _Rows()
        ..person(c, xpub: 'x-$c')
        ..person('asked', accepted: 0, xpub: 'x-asked')
        ..person('parked', accepted: 0, archived: 1, xpub: 'x-parked')
        ..person('introduced', accepted: 0, xpub: 'x-introduced')
        ..person('gone', xpub: 'x-gone');
      live.vouches['introduced'] = {c};
      final io = _Io(log);
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      final app = AppState(io: io, router: router)..myId = 'me';
      useDatabasesForTest(live, Session(live));
      await app.subscribeKnown();
      // since the boot: a stranger who back-paired, and a chat deleted
      final plain = await wrapMessage(
        'hi',
        powNonce: grindPow('hi', powBits),
        powBitsUsed: powBits,
        sender: asSender('newcomer'),
      );
      io.firstContact = (
        haloId: 'newcomer',
        plain: plain,
        env: unwrapMessage(plain),
      );
      await app.receiveOnion([
        base64Encode([3, 1, 2, 3]),
      ]);
      await app.deleteConversation('gone');
      expect(live.people['newcomer']?['accepted'], 0);
      log.clear();

      await app.setSendMode('balanced');
      final moved = [
        for (final l in log)
          if (l.startsWith('listen:')) l.substring('listen:'.length),
      ]..sort();
      expect(moved, [
        'x-asked',
        'x-$c',
        'x-gone',
        'x-introduced',
        'x-newcomer',
        'x-parked',
      ]);
      expect(log.first, 'mode:balanced');
    });

    test('an outage seen before a switch is not carried back', () async {
      final app = await world();
      final t0 = DateTime.now().subtract(const Duration(minutes: 5));
      app.sendModeForTest = 'balanced';
      eng.relays = _failing;
      app.sampleRelayHealth(now: t0);
      app.sampleRelayHealth(now: t0.add(const Duration(seconds: 95)));
      expect(app.suggestFastFallback, isTrue);
      await app.setSendMode('private');
      await app.setSendMode('balanced');
      expect(app.suggestFastFallback, isFalse);
    });

    test('one that does not save moves nothing, and the next try still '
        'moves the engine', () async {
      final store = _Store();
      FlutterSecureStorage.setMockInitialValues(store);
      final app = await world();
      store.refuse = true;
      await expectLater(
        app.setSendMode('balanced'),
        throwsA(isA<PlatformException>()),
      );
      expect(app.sendMode, 'private');
      expect(log.where((l) => l.startsWith('mode:')), isEmpty);

      store.refuse = false;
      await app.setSendMode('balanced');
      expect(log.first, 'mode:balanced');
      expect(app.sendMode, 'balanced');
      expect(store['send_mode'], 'balanced');
    });

    test('runners that did not move are moved by the next try, and the '
        'switch is not told as failed', () async {
      final live = _Flaky()..person(c, onion: 'o-$c', xpub: 'x-$c');
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      final app = AppState(io: _Io(log), router: router)..myId = 'me';
      useDatabasesForTest(live, Session(live));
      live.down = true;
      await app.setSendMode('balanced');
      expect(app.sendMode, 'balanced');
      expect(log.first, 'mode:balanced');
      expect(log.where((l) => l.startsWith('listen:')), isEmpty);

      live.down = false;
      log.clear();
      await app.setSendMode('balanced');
      expect(log, contains('listen:x-$c'));
      expect(log.where((l) => l.startsWith('mode:')), isEmpty);
      // moved, a tap on the same mode does nothing more
      log.clear();
      await app.setSendMode('balanced');
      expect(log, isEmpty);
    });

    test(
      'the engine is asked which route it is on, not assumed on onion',
      (() async {
        eng.engineMode = 'balanced';
        final app = await world();
        await app.setSendMode('balanced');
        expect(log.where((l) => l.startsWith('mode:')), isEmpty);
        expect(app.sendMode, 'balanced');
        await app.setSendMode('private');
        expect(log.first, 'mode:private');
      }),
    );

    test('the app takes the new mode once the engine has it', () async {
      final app = await world();
      final told = <String>[];
      app.addListener(() {
        final engineOn = log.lastWhere(
          (l) => l.startsWith('mode:'),
          orElse: () => 'mode:private',
        );
        told.add('${app.sendMode} ${engineOn.substring(5)}');
      });
      await app.setSendMode('balanced');
      await app.setSendMode('private');
      expect(told, isNotEmpty);
      for (final t in told) {
        final [app, engine] = t.split(' ');
        expect(app, engine, reason: '$told');
      }
    });

    testWidgets('a tap on the modes page is not undone by what the page read '
        'as it opened', (t) async {
      FlutterSecureStorage.setMockInitialValues({'send_mode': 'private'});
      appState.sendModeForTest = 'private';
      addTearDown(() => appState.sendModeForTest = 'private');
      final live = ArrivalRows(HaloContainer.everyday);
      useDatabasesForTest(live, Session(live));
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ModesScreen(),
        ),
      );
      await t.pump();
      await t.tap(find.text(l10n.modesRelay));
      await t.pump();
      // anything the page still had on its way comes in after the tap
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump(const Duration(seconds: 1));
      expect(log.lastWhere((l) => l.startsWith('mode:')), 'mode:balanced');
      expect(appState.sendMode, 'balanced');
      // the switch's runners finish off the test's clock
      await t.runAsync(() => appState.setSendMode('balanced'));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('taps queued behind a switch: the picked card says it is '
        'switching, and the last one done shows the mode in use', (t) async {
      final store = _Store()..['send_mode'] = 'fast';
      FlutterSecureStorage.setMockInitialValues(store);
      appState.sendModeForTest = 'fast';
      addTearDown(() => appState.sendModeForTest = 'private');
      final live = _Flaky()..gate = Completer<void>();
      useDatabasesForTest(live, Session(live));
      t.view.physicalSize = const Size(1000, 2400);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ModesScreen(),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      // a switch already under way holds the queue
      final first = appState.setSendMode('balanced');
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
      expect(appState.sendMode, 'balanced');
      // the next save of relay is refused, onion's goes
      store.refuseMode = 'balanced';
      await t.tap(find.text(l10n.modesRelay));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.modesSwitching), findsOneWidget);
      await t.tap(find.text(l10n.modesOnion));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.modesSwitching), findsOneWidget);
      live.gate!.complete();
      await first;
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(appState.sendMode, 'private');
      expect(find.text(l10n.modesSwitching), findsNothing);
      Finder chosen(String name) => find.ancestor(
        of: find.text(name),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.selected == true,
        ),
      );
      expect(chosen(l10n.modesOnion), findsOneWidget);
      expect(chosen(l10n.modesRelay), findsNothing);
      // the refused tap says so
      expect(find.text(l10n.modesNotChanged), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 4));
    });

    test('the boot sets the list before the invite address listens', () {
      final src = File('lib/main.dart').readAsStringSync();
      final boot = src.substring(src.indexOf("dlog('transport: booting in"));
      final init = boot.indexOf('engine.nostrInit(relaysFor(_sendMode));');
      expect(init, greaterThan(0));
      expect(init, lessThan(boot.indexOf('_loadFirstContact();')));
    });
  });

  group('a tor stop that fails', () {
    testWidgets('is tried again while tor is meant to sleep', (t) async {
      eng.stops = ['error: timeout', 'ok'];
      final app = AppState()..deliveryModeForTest = DeliveryMode.checkins;
      app.appInFront(false);
      await t.pump(const Duration(seconds: 95));
      expect(log, ['stop']);
      expect(eng.paused, isFalse);
      await t.pump(const Duration(seconds: 31));
      expect(log, ['stop', 'stop']);
      expect(eng.paused, isTrue);
      expect(app.torHeld, isTrue);
      // asleep for real: nothing more
      await t.pump(const Duration(minutes: 3));
      expect(log, ['stop', 'stop']);
    });

    testWidgets('waits twice as long each time it is refused', (t) async {
      eng.stops = ['error: timeout'];
      final app = AppState()..deliveryModeForTest = DeliveryMode.checkins;
      app.appInFront(false);
      int stops() => log.where((l) => l == 'stop').length;
      await t.pump(const Duration(seconds: 95));
      expect(stops(), 1);
      await t.pump(const Duration(seconds: 30));
      expect(stops(), 2);
      await t.pump(const Duration(seconds: 60));
      expect(stops(), 3);
      await t.pump(const Duration(seconds: 60));
      expect(stops(), 3);
      await t.pump(const Duration(seconds: 60));
      expect(stops(), 4);
      // never more than ten minutes apart
      await t.pump(const Duration(minutes: 30));
      final later = stops();
      await t.pump(const Duration(minutes: 10, seconds: 1));
      expect(stops(), later + 1);
      app.appInFront(true);
      await t.pump();
    });

    testWidgets('is not tried again once the app is back', (t) async {
      eng.stops = ['error: timeout'];
      final app = AppState()..deliveryModeForTest = DeliveryMode.checkins;
      app.appInFront(false);
      await t.pump(const Duration(seconds: 95));
      app.appInFront(true);
      await t.pump();
      await t.pump(const Duration(minutes: 2));
      expect(log.where((l) => l == 'stop'), hasLength(1));
    });
  });

  group('a check-in', () {
    testWidgets('that no relay answered is not taken for one', (t) async {
      final app = AppState()
        ..sendModeForTest = 'balanced'
        ..deliveryModeForTest = DeliveryMode.checkins;
      var at = DateTime(2026, 10, 11, 12);
      app.checkClockForTest = () => at;
      var n = -1;
      unawaited(app.checkIn(why: 'job').then((v) => n = v));
      for (var i = 0; i < 70; i++) {
        at = at.add(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
      }
      expect(n, 0);
      expect(app.lastCheckAt, 0);
      expect(checkInOk(app.lastCheckHow), isFalse);
      expect(checkInLine(app.lastCheckHow), contains(l10n.appNoRelayReached));
    });
  });

  group('a check-in with sockets on their turns', () {
    testWidgets('waits for the last one, a minute and its catch-up after '
        'the kick', (t) async {
      final live = _Flaky();
      useDatabasesForTest(live, Session(live));
      final app = AppState()
        ..sendModeForTest = 'balanced'
        ..deliveryModeForTest = DeliveryMode.checkins;
      var at = DateTime(2026, 10, 11, 12);
      app.checkClockForTest = () => at;
      var n = -1;
      Object? err;
      unawaited(
        app.checkIn(why: 'job').then((v) => n = v, onError: (e) => err = e),
      );
      int? kicked;
      int? done;
      for (var i = 0; i < 170 && n < 0; i++) {
        if (kicked == null && log.contains('kick')) {
          kicked = i;
          // every socket counted from the kick, the last done 100 s on
          eng.catchup = (3, 4);
        }
        if (kicked != null && i == kicked + 100) eng.catchup = (0, 4);
        at = at.add(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
        if (n >= 0) done = i;
      }
      expect(n, isNot(-1), reason: '$err ${app.lastCheckHow}');
      expect(kicked, isNotNull, reason: app.lastCheckHow);
      expect(done! - kicked!, greaterThanOrEqualTo(100));
      expect(app.lastCheckHow, contains('"how":"ok"'));
    });

    testWidgets('that starts late after its job ends by the job\'s budget, '
        'not its own', (t) async {
      final live = _Flaky();
      useDatabasesForTest(live, Session(live));
      final app = AppState()
        ..sendModeForTest = 'balanced'
        ..deliveryModeForTest = DeliveryMode.checkins;
      var at = DateTime(2026, 10, 11, 12);
      app.checkClockForTest = () => at;
      var n = -1;
      // the job began 40 s before dart was asked: a cold boot's wait
      unawaited(
        app
            .checkIn(
              why: 'job',
              jobAt: at.subtract(const Duration(seconds: 40)),
            )
            .then((v) => n = v),
      );
      int? kicked;
      var took = 0;
      for (var i = 0; i < 200 && n < 0; i++) {
        if (kicked == null && log.contains('kick')) {
          kicked = i;
          // a socket that never finishes
          eng.catchup = (1, 2);
        }
        at = at.add(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
        took = i;
      }
      expect(n, isNot(-1));
      // the wait ends 120 s into the job and the tail follows: all of it by
      // about 137, well before the job's stop at 170
      expect(took + 40, lessThanOrEqualTo(137));
      expect(app.lastCheckHow, contains('"how":"ok_capped"'));
    });

    testWidgets('with almost none of its job left, wakes nothing', (t) async {
      final live = _Flaky();
      useDatabasesForTest(live, Session(live));
      final app = AppState()
        ..sendModeForTest = 'private'
        ..deliveryModeForTest = DeliveryMode.checkins;
      var at = DateTime(2026, 10, 11, 12);
      app.checkClockForTest = () => at;
      log.clear();
      var n = -1;
      unawaited(
        app
            .checkIn(
              why: 'job',
              jobAt: at.subtract(const Duration(seconds: 88)),
            )
            .then((v) => n = v),
      );
      await t.pump(const Duration(seconds: 1));
      expect(n, 0);
      expect(app.lastCheckHow, contains('"how":"late"'));
      expect(log, isNot(contains('resume')));
      expect(log, isNot(contains('kick')));
    });

    testWidgets('waits for tor no further than its job allows', (t) async {
      final live = _Flaky();
      useDatabasesForTest(live, Session(live));
      final app = AppState()
        ..sendModeForTest = 'private'
        ..deliveryModeForTest = DeliveryMode.checkins;
      app.setTorStatusForTest(TorStatus.starting);
      app.setRouteOKForTest(false);
      addTearDown(() {
        app.setTorStatusForTest(TorStatus.off);
        app.setRouteOKForTest(true);
      });
      var at = DateTime(2026, 10, 11, 12);
      app.checkClockForTest = () => at;
      var n = -1;
      unawaited(
        app
            .checkIn(
              why: 'job',
              jobAt: at.subtract(const Duration(seconds: 40)),
            )
            .then((v) => n = v),
      );
      var took = 0;
      for (var i = 0; i < 200 && n < 0; i++) {
        at = at.add(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
        took = i;
      }
      expect(n, 0);
      // tor has until 90 s into the job
      expect(took + 40, lessThanOrEqualTo(92));
      expect(log, isNot(contains('kick')));
    });

    testWidgets('is not taken for no relay while one still waits its '
        'turn', (t) async {
      final live = _Flaky();
      useDatabasesForTest(live, Session(live));
      final app = AppState()
        ..sendModeForTest = 'balanced'
        ..deliveryModeForTest = DeliveryMode.checkins;
      var at = DateTime(2026, 10, 11, 12);
      app.checkClockForTest = () => at;
      var n = -1;
      unawaited(app.checkIn(why: 'job').then((v) => n = v));
      int? kicked;
      for (var i = 0; i < 170 && n < 0; i++) {
        if (kicked == null && log.contains('kick')) {
          kicked = i;
          // one socket waits its turn, nothing has begun yet
          eng.catchup = (1, 1);
        }
        // its turn ends a minute on and its catch-up runs ten seconds
        if (kicked != null && i == kicked + 60) eng.catchup = (1, 2);
        if (kicked != null && i == kicked + 70) eng.catchup = (0, 2);
        at = at.add(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
      }
      expect(n, isNot(-1));
      expect(app.lastCheckHow, contains('"how":"ok"'));
      expect(app.lastCheckAt, isNot(0));
    });
  });

  group('a check-in on a slow wake', () {
    testWidgets('gives the relays their own time from the kick', (t) async {
      final live = _Flaky();
      useDatabasesForTest(live, Session(live));
      final app = AppState()
        ..sendModeForTest = 'private'
        ..deliveryModeForTest = DeliveryMode.checkins;
      app.setTorStatusForTest(TorStatus.starting);
      app.setRouteOKForTest(false);
      addTearDown(() {
        app.setTorStatusForTest(TorStatus.off);
        app.setRouteOKForTest(true);
      });
      var at = DateTime(2026, 10, 11, 12);
      app.checkClockForTest = () => at;
      var n = -1;
      Object? err;
      unawaited(
        app.checkIn(why: 'job').then((v) => n = v, onError: (e) => err = e),
      );
      int? kicked;
      for (var i = 0; i < 150 && n < 0; i++) {
        // tor takes most of a minute to carry anything
        if (i == 50) {
          app.setTorStatusForTest(TorStatus.publishing);
          app.setRouteOKForTest(true);
        }
        if (kicked == null && log.contains('kick')) kicked = i;
        // the first relay gets going ten seconds after the kick
        if (kicked != null && i == kicked + 10) eng.catchup = (0, 2);
        at = at.add(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
      }
      expect(n, isNot(-1), reason: '$err');
      expect(checkInOk(app.lastCheckHow), isTrue, reason: app.lastCheckHow);
      expect(app.lastCheckAt, isNot(0));
    });
  });

  group('automatic stuck, on coming back', () {
    final t0 = DateTime(2026, 10, 11, 12);
    AppState stuck(BridgeStatus s) {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..bridgeSetupForTest = const BridgeSetup(choice: BridgeChoice.auto);
      app.noteOnline(true);
      app.setBridgeStatusForTest(s);
      return app;
    }

    int retries() => log.where((l) => l == 'retry').length;

    test('out of ways or held with none in place, it tries again, once a '
        'minute at most', () {
      for (final s in const [
        BridgeStatus(mode: 'auto', phase: 'exhausted'),
        BridgeStatus(mode: 'auto', phase: 'trying', errorCode: 'pt_failed'),
      ]) {
        log.clear();
        final app = stuck(s);
        app.appInFront(true);
        expect(retries(), 1, reason: s.phase);
        app.appInFront(false);
        app.appInFront(true);
        app.retryStuckAuto(
          now: DateTime.now().add(const Duration(seconds: 30)),
        );
        expect(retries(), 1, reason: s.phase);
        app.retryStuckAuto(
          now: DateTime.now().add(const Duration(seconds: 61)),
        );
        expect(retries(), 2, reason: s.phase);
      }
    });

    testWidgets('in check-ins, once tor is awake and says it is stuck', (
      t,
    ) async {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..deliveryModeForTest = DeliveryMode.checkins
        ..bridgeSetupForTest = const BridgeSetup(choice: BridgeChoice.auto);
      app.noteOnline(true);
      app.appInFront(false);
      await t.pump(const Duration(seconds: 95));
      expect(app.torHeld, isTrue);
      app.setBridgeStatusForTest(
        const BridgeStatus(mode: 'auto', phase: 'paused'),
      );
      app.appInFront(true);
      await t.pump();
      expect(app.torHeld, isFalse);
      expect(retries(), 0);
      // awake, the engine's next word is that automatic is out of ways
      app.takeBridgeStatus('{"mode":"auto","phase":"exhausted"}');
      expect(retries(), 1);
      app.takeBridgeStatus('{"mode":"auto","phase":"trying"}');
      app.takeBridgeStatus('{"mode":"auto","phase":"exhausted"}');
      expect(retries(), 1);
    });

    test('not while it gets somewhere, not off onion, never in a decoy', () {
      stuck(
        const BridgeStatus(mode: 'auto', phase: 'connected', canSend: true),
      ).retryStuckAuto(now: t0);
      stuck(
        const BridgeStatus(mode: 'auto', phase: 'trying', progress: 40),
      ).retryStuckAuto(now: t0);
      (stuck(
        const BridgeStatus(mode: 'auto', phase: 'exhausted'),
      )..sendModeForTest = 'balanced').retryStuckAuto(now: t0);
      lockState.inDecoy = true;
      addTearDown(() => lockState.inDecoy = false);
      stuck(
        const BridgeStatus(mode: 'auto', phase: 'exhausted'),
      ).retryStuckAuto(now: t0);
      expect(retries(), 0);
    });
  });

  group('bridges', () {
    test('lines the engine could not read are not used', () async {
      final app = AppState();
      eng
        ..mode = 'error: lines_bad'
        ..checks = '[{"i":0,"state":"broken"},{"i":1,"state":"broken"}]';
      final r = await app.useFriendLines('obfs4 mangled\nwrapped');
      expect(r.used, isFalse);
      expect(r.broken, 2);
      expect(app.bridgeChoice, BridgeChoice.auto);
      expect(app.manualBridge, isFalse);

      eng
        ..mode = 'ok'
        ..checks = '[{"i":0,"state":"ok"},{"i":1,"state":"broken"}]';
      final s = await app.useFriendLines('a\nb');
      expect(s.used, isTrue);
      expect(s.broken, 1);
      expect(app.bridgeChoice, BridgeChoice.friend);
      expect(app.manualBridge, isTrue);
    });
  });

  group('the bridges card', () {
    final t0 = DateTime(2026, 10, 1, 12);
    DateTime at(int s) => t0.add(Duration(seconds: s));

    // a second of the status poll, the same status every time
    void poll(AppState app, String raw, int from, int to) {
      for (var s = from; s <= to; s++) {
        app.takeTorStatus(raw, now: at(s));
      }
    }

    test('a tor stuck under half way shows it by time alone', () {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..bridgeSetupForTest = const BridgeSetup(choice: BridgeChoice.direct);
      var told = 0;
      app.addListener(() => told++);
      poll(app, 'starting|5|0|0|0', 0, 119);
      expect(app.suggestBridgesAt(at(119)), isFalse);
      expect(told, 1);
      // nothing about tor changed, the poll still says so
      poll(app, 'starting|5|0|0|0', 120, 125);
      expect(app.suggestBridgesAt(at(125)), isTrue);
      expect(told, 2);
    });

    test('a route torn down that climbs back to where it stuck keeps it', () {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..bridgeSetupForTest = const BridgeSetup(choice: BridgeChoice.direct);
      poll(app, 'starting|5|0|0|0', 0, 130);
      expect(app.suggestBridgesAt(at(130)), isTrue);
      // the engine's rescue: down to nothing and back to the same place
      poll(app, 'starting|0|0|0|1', 131, 140);
      poll(app, 'starting|5|0|0|1', 141, 150);
      expect(app.suggestBridgesAt(at(150)), isTrue);
      // a climb past it is progress, a slow network and not a wall
      poll(app, 'starting|20|0|0|1', 151, 160);
      expect(app.suggestBridgesAt(at(160)), isFalse);
    });

    // a minute's climb from nothing that stays under the old best, with
    // neither card up at any second of it
    void climb(AppState app, int from) {
      for (final (i, pct) in [0, 10, 20, 25].indexed) {
        for (var s = 0; s < 15; s++) {
          final now = at(from + i * 15 + s);
          app.takeTorStatus('starting|$pct|0|0|1', now: now);
          expect(app.suggestBridgesAt(now), isFalse, reason: '$pct% $now');
          expect(app.suggestBridgesOffAt(now), isFalse, reason: '$pct% $now');
        }
      }
    }

    test('bridges turned on get a try of their own', () async {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..bridgeSetupForTest = const BridgeSetup(choice: BridgeChoice.direct);
      poll(app, 'starting|30|0|0|0', 0, 130);
      expect(app.suggestBridgesAt(at(130)), isTrue);
      await app.useFriendLines('a\nb');
      expect(app.manualBridge, isTrue);
      climb(app, 131);
      // stuck from here on, it is the bridges that are not working
      poll(app, 'starting|25|0|0|1', 191, 300);
      expect(app.suggestBridgesOffAt(at(300)), isTrue);
    });

    test('bridges turned off do not bring the other card back', () async {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..bridgeSetupForTest = const BridgeSetup(choice: BridgeChoice.direct);
      await app.useFriendLines('a\nb');
      poll(app, 'starting|30|0|0|0', 0, 130);
      expect(app.suggestBridgesOffAt(at(130)), isTrue);
      await app.chooseBridge(BridgeChoice.direct);
      app.applyBridgeNow();
      app.restartTor();
      expect(log, ['restart']);
      climb(app, 131);
    });

    test('a reconnect or another network is a try of its own', () {
      for (final change in ['reconnect', 'network']) {
        final app = AppState()
          ..sendModeForTest = 'private'
          ..bridgeSetupForTest = const BridgeSetup(choice: BridgeChoice.direct);
        poll(app, 'starting|30|0|0|0', 0, 130);
        expect(app.suggestBridgesAt(at(130)), isTrue);
        if (change == 'reconnect') {
          app.restartTor();
        } else {
          app.networkMoved();
        }
        climb(app, 131);
      }
      expect(log, ['restart', 'network']);
    });

    test('so is a mode switched away and back', () async {
      final live = ArrivalRows(HaloContainer.everyday);
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      final app = AppState(io: _Io(log), router: router)
        ..myId = 'me'
        ..sendModeForTest = 'private'
        ..bridgeSetupForTest = const BridgeSetup(choice: BridgeChoice.direct);
      useDatabasesForTest(live, Session(live));
      poll(app, 'starting|30|0|0|0', 0, 130);
      expect(app.suggestBridgesAt(at(130)), isTrue);
      await app.setSendMode('balanced');
      await app.setSendMode('private');
      poll(app, 'starting|30|0|0|0', 131, 200);
      expect(app.suggestBridgesAt(at(200)), isFalse);
    });

    test('nothing to say once tor carries traffic', () {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..bridgeSetupForTest = const BridgeSetup(choice: BridgeChoice.direct);
      var told = 0;
      poll(app, 'starting|5|0|0|0', 0, 130);
      app.addListener(() => told++);
      poll(app, 'bootstrapped|100|0|1|0', 131, 140);
      expect(app.suggestBridgesAt(at(140)), isFalse);
      expect(told, 1);
    });
  });
  // doze, or a network android never reported, can leave tor on a route
  // that is gone. coming back to the app with nothing carried is taken as a
  // network change, and the way out of a stuck send reconnects for real
  group('back in front', () {
    final t0 = DateTime(2026, 10, 10, 12);
    AppState app0() {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..deliveryModeForTest = DeliveryMode.always;
      app.noteOnline(true);
      return app;
    }

    test('tor off: the engine hears of it as a network change', () {
      final app = app0();
      app.takeTorStatus('off|0|0|0|3', now: t0);
      app.backInFront(now: t0.add(const Duration(seconds: 10)));
      expect(log, ['network']);
    });

    test('starting while online and climbing: left alone', () {
      final app = app0();
      app.takeTorStatus('starting|30|0|0|3', now: t0);
      app.takeTorStatus(
        'starting|60|0|0|3',
        now: t0.add(const Duration(minutes: 3)),
      );
      app.backInFront(now: t0.add(const Duration(minutes: 5)));
      expect(log, isEmpty);
    });

    test('stuck at one percentage for minutes: a network change', () {
      final app = app0();
      app.takeTorStatus('starting|30|0|0|3', now: t0);
      app.backInFront(now: t0.add(const Duration(minutes: 5)));
      expect(log, ['network']);
    });

    test('not when tor is fine, offline, outside onion, or in a decoy', () {
      final app = app0();
      app.takeTorStatus('publishing|100|0|1|3', now: t0);
      app.backInFront(now: t0.add(const Duration(minutes: 9)));
      app.takeTorStatus('off|0|0|0|3', now: t0);
      app.noteOnline(false);
      app.backInFront(now: t0.add(const Duration(minutes: 9)));
      app.noteOnline(true);
      app.sendModeForTest = 'balanced';
      app.backInFront(now: t0.add(const Duration(minutes: 9)));
      app.sendModeForTest = 'private';
      final decoy = ArrivalRows(HaloContainer.decoy);
      useDatabasesForTest(decoy, Session(decoy));
      app.backInFront(now: t0.add(const Duration(minutes: 9)));
      final live = ArrivalRows(HaloContainer.everyday);
      useDatabasesForTest(live, Session(live));
      expect(log, isEmpty);
    });

    test('the way out reconnects through the engine, waited on', () async {
      final app = AppState()..sendModeForTest = 'private';
      expect(await app.reconnectNow(), 'ok');
      expect(log, ['now']);
    });
  });

  // check-ins: a wake that crosses a sleep still going waits its turn, so
  // the app and the engine end up agreeing
  test(
    'a wake behind a slow sleep leaves tor awake, and the app knows',
    () async {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..deliveryModeForTest = DeliveryMode.checkins;
      eng.stopGate = Completer<void>();
      final sleep = app.torSleepForTest();
      await Future<void>.delayed(Duration.zero);
      app.appInFront(true);
      await Future<void>.delayed(Duration.zero);
      eng.stopGate!.complete();
      await sleep;
      await app.torWakeForTest();
      expect(eng.paused, isFalse);
      expect(app.torHeld, isFalse);
    },
  );

  // a flight: wifi to mobile, airplane on and off, a vpn up and down,
  // offline and back. the engine hears every one, and settles them itself
  group('every network change', () {
    const wifi = ConnectivityResult.wifi;
    const mobile = ConnectivityResult.mobile;
    const vpn = ConnectivityResult.vpn;
    const none = ConnectivityResult.none;
    // what the engine heard of the network
    List<String> net() => log
        .where((e) => const {'network', 'offline', 'detail'}.contains(e))
        .toList();

    test('reaches the engine, and nothing that is not a change does', () {
      final app = AppState()..sendModeForTest = 'private';
      app.connectivityEvent([wifi]); // offline to online
      app.connectivityEvent([wifi]); // the same again: no change
      app.connectivityEvent([mobile]); // wifi to mobile
      app.connectivityEvent([wifi]); // mobile to wifi
      app.connectivityEvent([none]); // airplane on
      app.connectivityEvent([none]);
      app.connectivityEvent([wifi]); // airplane off
      app.connectivityEvent([wifi, vpn]); // vpn up
      app.connectivityEvent([wifi]); // vpn down
      expect(log.where((e) => e == 'network').length, 6);
      // airplane on says there is no network, so the engine waits for one
      expect(log.where((e) => e == 'offline').length, 1);
      expect(app.online, isTrue);
    });

    test('a burst of airplane toggles is passed on as it comes', () {
      final app = AppState()..sendModeForTest = 'private';
      app.connectivityEvent([mobile]);
      for (var i = 0; i < 10; i++) {
        app.connectivityEvent([none]);
        app.connectivityEvent([mobile]);
      }
      expect(log.where((e) => e == 'network').length, 11);
      expect(log.where((e) => e == 'offline').length, 10);
    });

    test('a none while android\'s watch sees a network is not taken', () {
      final app = AppState()..sendModeForTest = 'private';
      app.connectivityEvent([wifi]);
      app.netDetailEvent('{"on":true,"validated":true,"kind":"wifi"}');
      log.clear();
      // the engine hears connectivity's own word and weighs it itself
      app.connectivityEvent([none]);
      expect(log, contains('seen:false'));
      expect(net(), ['offline']);
      expect(app.online, isTrue);
      // seen again, the network is bounced
      app.connectivityEvent([wifi]);
      expect(net(), ['offline', 'network']);
      // the watch says none: offline whatever connectivity says
      app.netDetailEvent('{"on":false,"kind":"other"}');
      expect(app.online, isFalse);
      app.connectivityEvent([mobile]);
      expect(app.online, isFalse);
    });

    test('connectivity seeing a network reaches the engine as it is', () {
      final app = AppState()..sendModeForTest = 'private';
      app.netDetailEvent('{"on":false,"kind":"other"}');
      app.connectivityEvent([none]);
      log.clear();
      // the watch wrongly says none, connectivity sees wifi: the engine
      // hears online, so it can tell the dispute
      app.connectivityEvent([wifi]);
      expect(log, contains('seen:true'));
      expect(net(), ['network']);
      expect(app.online, isFalse);
    });

    test('relays through tor outrank the watch saying none', () {
      final app = AppState()..sendModeForTest = 'private';
      app.netDetailEvent('{"on":false,"kind":"other"}');
      expect(app.online, isFalse);
      app.takeTorStatus('publishing|100|1|1|0');
      expect(app.online, isTrue);
      // a recheck that brings the same none is no news
      log.clear();
      app.recheckNetDetail('{"on":false,"kind":"other"}');
      expect(app.online, isTrue);
      expect(net(), isEmpty);
      app.recheckNetDetail('{"on":false,"kind":"wifi"}');
      expect(app.online, isFalse);
    });

    test('the watch alone bringing the network back brings the app online', () {
      final app = AppState()..sendModeForTest = 'private';
      app.connectivityEvent([none]);
      expect(app.online, isFalse);
      log.clear();
      app.netDetailEvent('{"on":true,"validated":true,"kind":"wifi"}');
      expect(app.online, isTrue);
      expect(net(), ['detail', 'network']);
    });
  });
}
