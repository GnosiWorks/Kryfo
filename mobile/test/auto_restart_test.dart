// SPDX-License-Identifier: GPL-3.0-or-later
// the restart out of sight: only for a tor dead in its process, at most once
// in half an hour across processes, and never on screen, in the decoy,
// offline or while something would be cut short

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/auto_restart.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/drafts.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, torValve, useEngineForTest;
import 'package:kryfo/tor_valve.dart' show restartHolds;
import 'package:shared_preferences/shared_preferences.dart';

AutoView _view({
  bool inFront = false,
  bool alwaysOn = true,
  bool private = true,
  bool quiet = false,
  bool online = true,
  bool held = false,
  bool torHeld = false,
  bool torReady = false,
  int ctrlSilent = 0,
  DateTime? stuckSince,
}) => AutoView(
  inFront: inFront,
  alwaysOn: alwaysOn,
  private: private,
  quiet: quiet,
  online: online,
  held: held,
  torHeld: torHeld,
  torReady: torReady,
  ctrlSilent: ctrlSilent,
  stuckSince: stuckSince,
);

class _Engine implements HaloEngine {
  int silent = 0;
  @override
  Map<String, dynamic> transportState() => {'ctrl_silent': silent};
  @override
  void networkChanged({bool online = true}) {}
  @override
  Future<String> reconnectNow() async => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t0 = DateTime(2026, 10, 11, 3);
  DateTime at(int min) => t0.add(Duration(minutes: min));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    restartHolds.clear();
    draftPerPeer.clear();
    draftPerGroup.clear();
  });

  group('when', () {
    final dead = _view(ctrlSilent: 2, stuckSince: t0);

    test('a silent control port restarts, out of sight', () {
      expect(autoStepAt(dead, now: at(1)), AutoStep.restart);
    });

    test('never on screen', () {
      final v = _view(inFront: true, ctrlSilent: 5, stuckSince: t0);
      expect(autoStepAt(v, now: at(30)), AutoStep.none);
      expect(
        autoStepAt(
          v,
          now: at(30),
          reconnectedAt: at(29),
          reconnectFailed: true,
        ),
        AutoStep.none,
      );
    });

    test('never in the decoy', () {
      final v = _view(quiet: true, ctrlSilent: 5, stuckSince: t0);
      expect(autoStepAt(v, now: at(30)), AutoStep.none);
    });

    test('never offline', () {
      final v = _view(online: false, ctrlSilent: 5, stuckSince: t0);
      expect(autoStepAt(v, now: at(30)), AutoStep.none);
    });

    test('never while something is held', () {
      final v = _view(held: true, ctrlSilent: 5, stuckSince: t0);
      expect(autoStepAt(v, now: at(30)), AutoStep.none);
    });

    test('never outside always-on, with tor asleep or outside onion', () {
      for (final v in [
        _view(alwaysOn: false, ctrlSilent: 5, stuckSince: t0),
        _view(torHeld: true, ctrlSilent: 5, stuckSince: t0),
        _view(private: false, ctrlSilent: 5, stuckSince: t0),
        _view(torReady: true, ctrlSilent: 5),
      ]) {
        expect(autoStepAt(v, now: at(30)), AutoStep.none);
      }
    });

    test('one silent call is not a dead port', () {
      final v = _view(ctrlSilent: 1, stuckSince: at(29));
      expect(autoStepAt(v, now: at(30)), AutoStep.none);
    });

    test('a slow bootstrap never restarts, a stalled one reconnects', () {
      // still climbing: nothing
      expect(autoStepAt(_view(stuckSince: at(27)), now: at(30)), AutoStep.none);
      // stalled: a reconnect, never a restart
      final stalled = _view(stuckSince: at(0));
      expect(autoStepAt(stalled, now: at(30)), AutoStep.reconnect);
      // one that tor took is not tried again for a while, nor restarted
      expect(
        autoStepAt(stalled, now: at(35), reconnectedAt: at(30)),
        AutoStep.none,
      );
      expect(
        autoStepAt(stalled, now: at(41), reconnectedAt: at(30)),
        AutoStep.reconnect,
      );
    });

    test('a failed reconnect restarts', () {
      final v = _view(stuckSince: at(0));
      expect(
        autoStepAt(
          v,
          now: at(31),
          reconnectedAt: at(30),
          reconnectFailed: true,
        ),
        AutoStep.restart,
      );
    });

    test('at most once in half an hour, whichever way the clock moved', () {
      expect(autoStepAt(dead, now: at(60), restartedAt: at(31)), AutoStep.none);
      expect(
        autoStepAt(dead, now: at(60), restartedAt: at(30)),
        AutoStep.restart,
      );
      // set back since: still too close
      expect(autoStepAt(dead, now: at(60), restartedAt: at(80)), AutoStep.none);
    });

    test('what counts as a reconnect that failed', () {
      expect(reconnectFailedWith('error: control port timeout on X'), isTrue);
      expect(reconnectFailedWith('error: timeout'), isTrue);
      for (final r in [
        'ok',
        'error: tor is asleep',
        'error: superseded',
        'error: one already running',
      ]) {
        expect(reconnectFailedWith(r), isFalse, reason: r);
      }
    });
  });

  group('the restart', () {
    late AutoView seen;
    late DateTime now;
    late List<String> log;
    late bool reopens;
    late String answer;

    AutoRestart process() => AutoRestart(
      view: () => seen,
      reconnect: () async {
        log.add('reconnect');
        return answer;
      },
      restart: () async {
        log.add('restart');
        return reopens;
      },
      clock: () => now,
    );

    setUp(() {
      seen = _view(ctrlSilent: 2, stuckSince: t0);
      now = at(1);
      log = [];
      reopens = true;
      answer = 'ok';
    });

    test('the half hour holds across restarts', () async {
      expect(await process().tick(), AutoStep.restart);
      expect(log, ['restart']);
      // the next process finds tor dead again at once
      now = at(5);
      final second = process();
      expect(await second.tick(), AutoStep.none);
      now = at(30);
      expect(await second.tick(), AutoStep.none);
      expect(log, ['restart']);
      // and a third, past the half hour, may
      now = at(31);
      expect(await process().tick(), AutoStep.restart);
      expect(log, ['restart', 'restart']);
    });

    test('a restart android would not take still counts', () async {
      reopens = false;
      expect(await process().tick(), AutoStep.restart);
      now = at(10);
      expect(await process().tick(), AutoStep.none);
      expect(log, ['restart']);
    });

    test(
      'a failed reconnect leads to the restart, one tor took does not',
      () async {
        seen = _view(stuckSince: t0);
        now = at(10);
        final p = process();
        expect(await p.tick(), AutoStep.reconnect);
        now = at(11);
        expect(await p.tick(), AutoStep.none);
        expect(log, ['reconnect']);

        log.clear();
        answer = 'error: control port timeout on DisableNetwork 1';
        final q = process();
        expect(await q.tick(), AutoStep.reconnect);
        expect(await q.tick(), AutoStep.restart);
        expect(log, ['reconnect', 'restart']);
      },
    );

    test('back on screen while the stamp was written: no restart', () async {
      final p = AutoRestart(
        view: () {
          final v = seen;
          // the first look sees it out of sight, every later one in front
          seen = _view(inFront: true, ctrlSilent: 2, stuckSince: t0);
          return v;
        },
        reconnect: () async => 'ok',
        restart: () async {
          log.add('restart');
          return true;
        },
        clock: () => now,
      );
      expect(await p.tick(), AutoStep.none);
      expect(log, isEmpty);
    });

    test('drafts are kept, and taken back when it did not happen', () async {
      final every = '${HaloContainer.everyday.id}|alice';
      draftPerPeer[every] = 'half a thought';
      expect(await process().tick(), AutoStep.restart);
      draftPerPeer.clear();
      await restoreKeptDrafts();
      expect(draftPerPeer, {every: 'half a thought'});

      SharedPreferences.setMockInitialValues({});
      reopens = false;
      draftPerPeer[every] = 'half a thought';
      expect(await process().tick(), AutoStep.restart);
      draftPerPeer.clear();
      await restoreKeptDrafts();
      expect(draftPerPeer, isEmpty);
    });
  });

  group('what the app shows it', () {
    late _Engine eng;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '.',
          );
      eng = _Engine();
      useEngineForTest(eng);
    });

    AppState stuck() {
      final app = AppState()
        ..sendModeForTest = 'private'
        ..deliveryModeForTest = DeliveryMode.always;
      app.appInFront(false);
      app.takeTorStatus('starting|5|0|0|0', now: t0);
      return app;
    }

    test('a silent port out of sight restarts', () {
      eng.silent = 2;
      final v = stuck().autoView();
      expect(v.ctrlSilent, 2);
      expect(v.stuckSince, t0);
      expect(autoStepAt(v, now: at(1)), AutoStep.restart);
    });

    test('on screen, offline or holding a voice note it does not', () {
      eng.silent = 2;
      final front = stuck()..appInFront(true);
      expect(autoStepAt(front.autoView(), now: at(1)), AutoStep.none);

      final off = stuck()..noteOnline(false, now: t0);
      expect(autoStepAt(off.autoView(), now: at(1)), AutoStep.none);

      final rec = Object();
      restartHolds.add(rec);
      expect(torValve.restartBlocked, isTrue);
      expect(autoStepAt(stuck().autoView(), now: at(1)), AutoStep.none);
      restartHolds.remove(rec);
    });

    test('check-ins never restart', () {
      eng.silent = 2;
      final app = stuck()..deliveryModeForTest = DeliveryMode.checkins;
      expect(autoStepAt(app.autoView(), now: at(1)), AutoStep.none);
    });
  });
}
