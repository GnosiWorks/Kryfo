// SPDX-License-Identifier: GPL-3.0-or-later
// keeping the route honest. relay mode reads its relay on its own clock, so
// an outage shows while tor sits still and a mended relay clears the hint. a
// tor wake that fails is tried again while the app is open, and a tor the
// engine already lets run is put to sleep again. a mode switch sets its
// relay list before anything subscribes, one switch at a time, and moves
// everyone listened for. a spell offline or another mode's outage never
// shows as our relay's. bridges count as on only when the engine took one.
// a tor stuck on a network that blocks it brings up the bridges card on time
// alone, and a route torn down that climbs back to where it stuck keeps it.
// bridges, a reconnect, a mode or a network the person changed start a try
// of their own, and no card shows while it climbs.
// the engine and the rows are stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/bridges_screen.dart'
    show bridgesResultBad, bridgesResultLine;
import 'package:kryfo/session.dart';
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
  @override
  Future<String> torStop() async {
    log.add('stop');
    paused = true;
    return 'ok';
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

  // the answer to a save, and what the engine then holds
  String saved = 'ok: 1 bridges';
  String state = 'true|1|0';
  @override
  String setBridges(String lines, bool on) => saved;
  @override
  String bridgeState() => state;

  @override
  void restartTor() => log.add('restart');
  @override
  void networkChanged() => log.add('network');
  @override
  (int, int) catchupState() => (0, 1);

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

    test('the boot sets the list before the invite address listens', () {
      final src = File('lib/main.dart').readAsStringSync();
      final boot = src.substring(src.indexOf("dlog('transport: booting in"));
      final init = boot.indexOf('engine.nostrInit(relaysFor(_sendMode));');
      expect(init, greaterThan(0));
      expect(init, lessThan(boot.indexOf('_loadFirstContact();')));
    });
  });

  group('bridges', () {
    test('lines the engine could not read leave them off', () async {
      final app = AppState();
      eng
        ..saved = 'ok: 0 accepted, 3 not understood'
        ..state = 'false|0|0';
      final r = await app.applyBridges('obfs4 mangled\nwrapped\nhalf', true);
      expect(app.bridgesOn, isFalse);
      expect(bridgesResultBad(r), isTrue);
      expect(bridgesResultLine(r), l10n.bridgesNoneUsable);

      eng
        ..saved = 'ok: 2 accepted, 1 not understood'
        ..state = 'true|2|41234';
      final s = await app.applyBridges('a\nb\nc', true);
      expect(app.bridgesOn, isTrue);
      expect(bridgesResultBad(s), isFalse);
      expect(bridgesResultLine(s), l10n.bridgesSavedSomeBad(2, 1));

      // off is off, whatever the engine holds
      eng.state = 'true|2|41234';
      await app.applyBridges('a\nb', false);
      expect(app.bridgesOn, isFalse);
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
      final app = AppState()..sendModeForTest = 'private';
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
      final app = AppState()..sendModeForTest = 'private';
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
      final app = AppState()..sendModeForTest = 'private';
      poll(app, 'starting|30|0|0|0', 0, 130);
      expect(app.suggestBridgesAt(at(130)), isTrue);
      await app.applyBridges('a\nb', true);
      expect(app.bridgesOn, isTrue);
      climb(app, 131);
      // stuck from here on, it is the bridges that are not working
      poll(app, 'starting|25|0|0|1', 191, 300);
      expect(app.suggestBridgesOffAt(at(300)), isTrue);
    });

    test('bridges turned off do not bring the other card back', () async {
      final app = AppState()..sendModeForTest = 'private';
      await app.applyBridges('a\nb', true);
      poll(app, 'starting|30|0|0|0', 0, 130);
      expect(app.suggestBridgesOffAt(at(130)), isTrue);
      eng.state = 'false|1|0';
      await app.applyBridges('a\nb', false);
      app.restartTor();
      expect(log, ['restart']);
      climb(app, 131);
    });

    test('a reconnect or another network is a try of its own', () {
      for (final change in ['reconnect', 'network']) {
        final app = AppState()..sendModeForTest = 'private';
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
        ..sendModeForTest = 'private';
      useDatabasesForTest(live, Session(live));
      poll(app, 'starting|30|0|0|0', 0, 130);
      expect(app.suggestBridgesAt(at(130)), isTrue);
      await app.setSendMode('balanced');
      await app.setSendMode('private');
      poll(app, 'starting|30|0|0|0', 131, 200);
      expect(app.suggestBridgesAt(at(200)), isFalse);
    });

    test('nothing to say once tor carries traffic', () {
      final app = AppState()..sendModeForTest = 'private';
      var told = 0;
      poll(app, 'starting|5|0|0|0', 0, 130);
      app.addListener(() => told++);
      poll(app, 'bootstrapped|100|0|1|0', 131, 140);
      expect(app.suggestBridgesAt(at(140)), isFalse);
      expect(told, 1);
    });
  });
}
