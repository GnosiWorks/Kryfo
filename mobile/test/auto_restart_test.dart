// SPDX-License-Identifier: GPL-3.0-or-later
// the restart out of sight: only for a route stalled for minutes and a
// reconnect it would not take, at most once in half an hour since boot, and
// never on screen, in the decoy, offline or while something would be cut
// short

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/auto_restart.dart';
import 'package:kryfo/backup.dart' show restoreRunningForTest, whileBackingUp;
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/drafts.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        restartQuietly,
        torValve,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/session.dart' show Session;
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

class _Db extends HaloDb {
  _Db(this.log);
  final List<String> log;
  @override
  Future<void> close() async => log.add('close');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t0 = DateTime(2026, 10, 11, 3);
  DateTime at(int min) => t0.add(Duration(minutes: min));
  const min = 60000;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    restartHolds.clear();
    draftPerPeer.clear();
    draftPerGroup.clear();
  });

  group('when', () {
    // stalled since t0, a reconnect at nine minutes that failed
    final stalled = _view(ctrlSilent: 2, stuckSince: t0);
    AutoStep failed(AutoView v, {bool due = true}) => autoStepAt(
      v,
      now: at(10),
      reconnectedAt: at(9),
      reconnectFailed: true,
      due: due,
    );

    test('a stalled route gets a reconnect first, silent port or not', () {
      expect(autoStepAt(stalled, now: at(10)), AutoStep.reconnect);
      expect(
        autoStepAt(_view(stuckSince: t0), now: at(10)),
        AutoStep.reconnect,
      );
    });

    test('a young bootstrap with a silent port: nothing', () {
      final young = _view(ctrlSilent: 2, stuckSince: at(8));
      expect(autoStepAt(young, now: at(10)), AutoStep.none);
      expect(failed(young), AutoStep.none);
    });

    test('a failed reconnect restarts', () {
      expect(failed(stalled), AutoStep.restart);
    });

    test('never on screen', () {
      final v = _view(inFront: true, ctrlSilent: 5, stuckSince: t0);
      expect(autoStepAt(v, now: at(10)), AutoStep.none);
      expect(failed(v), AutoStep.none);
    });

    test('never in the decoy', () {
      final v = _view(quiet: true, ctrlSilent: 5, stuckSince: t0);
      expect(autoStepAt(v, now: at(10)), AutoStep.none);
      expect(failed(v), AutoStep.none);
    });

    test('never offline', () {
      final v = _view(online: false, ctrlSilent: 5, stuckSince: t0);
      expect(autoStepAt(v, now: at(10)), AutoStep.none);
      expect(failed(v), AutoStep.none);
    });

    test('never while something is held', () {
      expect(
        failed(_view(held: true, ctrlSilent: 5, stuckSince: t0)),
        AutoStep.none,
      );
    });

    test('never before the half hour is over', () {
      expect(failed(stalled, due: false), AutoStep.none);
    });

    test('never outside always-on, with tor asleep or outside onion', () {
      for (final v in [
        _view(alwaysOn: false, ctrlSilent: 5, stuckSince: t0),
        _view(torHeld: true, ctrlSilent: 5, stuckSince: t0),
        _view(private: false, ctrlSilent: 5, stuckSince: t0),
        _view(torReady: true, ctrlSilent: 5, stuckSince: t0),
      ]) {
        expect(autoStepAt(v, now: at(10)), AutoStep.none);
        expect(failed(v), AutoStep.none);
      }
    });

    test('a slow bootstrap never restarts, a stalled one reconnects', () {
      // still climbing: nothing
      expect(autoStepAt(_view(stuckSince: at(27)), now: at(30)), AutoStep.none);
      final v = _view(stuckSince: at(0));
      expect(autoStepAt(v, now: at(30)), AutoStep.reconnect);
      // one that tor took is not tried again for a while, nor restarted
      expect(autoStepAt(v, now: at(35), reconnectedAt: at(30)), AutoStep.none);
      expect(
        autoStepAt(v, now: at(41), reconnectedAt: at(30)),
        AutoStep.reconnect,
      );
    });

    test('what counts as a reconnect that failed', () {
      const timeout = 'error: control port timeout on DisableNetwork 1';
      // one unanswered call is not a dead port, two in a row are
      expect(reconnectFailedWith(timeout, ctrlSilent: 1), isFalse);
      expect(reconnectFailedWith(timeout, ctrlSilent: 2), isTrue);
      expect(reconnectFailedWith('error: timeout'), isTrue);
      for (final r in [
        'ok',
        'error: tor is asleep',
        'error: superseded',
        'error: one already running',
        'error: no network',
      ]) {
        expect(reconnectFailedWith(r, ctrlSilent: 5), isFalse, reason: r);
      }
    });

    test('half an hour on the clock since boot', () {
      const last = BootTime(100 * min, 7);
      expect(autoRestartDue(null, const BootTime(5 * min, 7)), isTrue);
      expect(autoRestartDue(last, const BootTime(129 * min, 7)), isFalse);
      expect(autoRestartDue(last, const BootTime(130 * min, 7)), isTrue);
      // another boot, or a clock since boot that went back
      expect(autoRestartDue(last, const BootTime(5 * min, 8)), isTrue);
      expect(
        autoRestartDue(
          const BootTime(10 * min, 7),
          const BootTime(20 * min, 8),
        ),
        isTrue,
      );
      expect(
        autoRestartDue(
          const BootTime(100 * min, -1),
          const BootTime(5 * min, -1),
        ),
        isTrue,
      );
      expect(
        autoRestartDue(
          const BootTime(100 * min, -1),
          const BootTime(110 * min, -1),
        ),
        isFalse,
      );
      expect(BootTime.parse(last.encode())?.upMs, 100 * min);
      expect(BootTime.parse('nonsense'), isNull);
    });
  });

  group('the restart', () {
    late AutoView seen;
    late List<String> log;
    late bool reopens;
    late String answer;
    late BootTime? up;

    AutoRestart process({AutoView Function()? view}) => AutoRestart(
      view: view ?? () => seen,
      reconnect: () async {
        log.add('reconnect');
        return answer;
      },
      restart: () async {
        log.add('restart');
        return reopens;
      },
      clock: () async => up,
      now: () => at(10),
    );

    // a new process meets tor dead: a reconnect that fails, then the restart
    // if it may
    Future<List<AutoStep>> life() async {
      final p = process();
      return [await p.tick(), await p.tick()];
    }

    setUp(() {
      seen = _view(ctrlSilent: 2, stuckSince: t0);
      log = [];
      reopens = true;
      answer = 'error: control port timeout on DisableNetwork 1';
      up = const BootTime(100 * min, 7);
    });

    test('a reconnect first, the restart once it failed', () async {
      expect(await life(), [AutoStep.reconnect, AutoStep.restart]);
      expect(log, ['reconnect', 'restart']);
    });

    test('one unanswered call is not a failed reconnect', () async {
      seen = _view(ctrlSilent: 1, stuckSince: t0);
      expect(await life(), [AutoStep.reconnect, AutoStep.none]);
      answer = 'ok';
      seen = _view(ctrlSilent: 2, stuckSince: t0);
      expect(await life(), [AutoStep.reconnect, AutoStep.none]);
      expect(log, ['reconnect', 'reconnect']);
    });

    test('the half hour holds across restarts', () async {
      expect(await life(), [AutoStep.reconnect, AutoStep.restart]);
      up = const BootTime(105 * min, 7);
      expect(await life(), [AutoStep.reconnect, AutoStep.none]);
      up = const BootTime(129 * min, 7);
      expect(await life(), [AutoStep.reconnect, AutoStep.none]);
      up = const BootTime(130 * min, 7);
      expect(await life(), [AutoStep.reconnect, AutoStep.restart]);
      expect(log.where((e) => e == 'restart').length, 2);
    });

    test('a phone started again may restart at once', () async {
      expect(await life(), [AutoStep.reconnect, AutoStep.restart]);
      up = const BootTime(3 * min, 8);
      expect(await life(), [AutoStep.reconnect, AutoStep.restart]);
    });

    test('a clock that will not read restarts nothing', () async {
      up = null;
      expect(await life(), [AutoStep.reconnect, AutoStep.none]);
      expect(log, ['reconnect']);
    });

    test('a restart android would not take still counts', () async {
      reopens = false;
      expect(await life(), [AutoStep.reconnect, AutoStep.restart]);
      up = const BootTime(110 * min, 7);
      expect(await life(), [AutoStep.reconnect, AutoStep.none]);
      expect(log.where((e) => e == 'restart').length, 1);
    });

    test('back on screen while the stamp was written: no restart', () async {
      var looks = 0;
      final p = process(
        view: () {
          looks++;
          // the reconnect's two looks and the restart's first see it out
          // of sight, the look after the stamp in front
          return looks <= 3
              ? seen
              : _view(inFront: true, ctrlSilent: 2, stuckSince: t0);
        },
      );
      expect(await p.tick(), AutoStep.reconnect);
      expect(await p.tick(), AutoStep.none);
      expect(log, ['reconnect']);
    });

    test('drafts are kept, and taken back when it did not happen', () async {
      final every = '${HaloContainer.everyday.id}|alice';
      draftPerPeer[every] = 'half a thought';
      expect(await life(), [AutoStep.reconnect, AutoStep.restart]);
      draftPerPeer.clear();
      await restoreKeptDrafts();
      expect(draftPerPeer, {every: 'half a thought'});

      SharedPreferences.setMockInitialValues({});
      reopens = false;
      draftPerPeer[every] = 'half a thought';
      expect(await life(), [AutoStep.reconnect, AutoStep.restart]);
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

    AutoStep failed(AppState app) => autoStepAt(
      app.autoView(),
      now: at(10),
      reconnectedAt: at(9),
      reconnectFailed: true,
    );

    test('a silent port out of sight gets its reconnect, then restarts', () {
      eng.silent = 2;
      final app = stuck();
      final v = app.autoView();
      expect(v.ctrlSilent, 2);
      expect(v.stuckSince, t0);
      expect(autoStepAt(v, now: at(10)), AutoStep.reconnect);
      expect(failed(app), AutoStep.restart);
    });

    test('on screen, offline or holding a voice note it does not', () {
      eng.silent = 2;
      final front = stuck()..appInFront(true);
      expect(front.autoView().inFront, isTrue);
      expect(failed(front), AutoStep.none);

      final off = stuck()..noteOnline(false, now: t0);
      expect(off.autoView().online, isFalse);
      expect(failed(off), AutoStep.none);

      final rec = Object();
      restartHolds.add(rec);
      expect(torValve.restartBlocked, isTrue);
      expect(failed(stuck()), AutoStep.none);
      restartHolds.remove(rec);
    });

    test('never while a backup is written', () async {
      final app = stuck();
      final gate = Completer<void>();
      final run = whileBackingUp(() => gate.future);
      expect(app.autoView().held, isTrue);
      expect(failed(app), AutoStep.none);
      gate.complete();
      await run;
      expect(app.autoView().held, isFalse);
      expect(failed(app), AutoStep.restart);
    });

    test('never while a restore runs', () {
      final app = stuck();
      restoreRunningForTest = true;
      addTearDown(() => restoreRunningForTest = false);
      expect(app.autoView().held, isTrue);
      expect(failed(app), AutoStep.none);
      restoreRunningForTest = false;
      expect(failed(app), AutoStep.restart);
    });

    test('check-ins never restart', () {
      eng.silent = 2;
      final app = stuck()..deliveryModeForTest = DeliveryMode.checkins;
      expect(app.autoView().alwaysOn, isFalse);
      expect(failed(app), AutoStep.none);
    });
  });

  group('the process end', () {
    const ch = MethodChannel('halo/restart');
    late List<String> log;
    late bool arms;

    setUp(() {
      log = [];
      arms = true;
      final db = _Db(log);
      useDatabasesForTest(db, Session(db));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async {
            log.add(call.method);
            return call.method == 'arm' ? arms : true;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, null),
    );

    test('the databases are shut between android\'s yes and the end', () async {
      expect(await restartQuietly(), isTrue);
      expect(log, ['arm', 'close', 'end']);
    });

    test('a no from android shuts nothing', () async {
      arms = false;
      expect(await restartQuietly(), isFalse);
      expect(log, ['arm']);
    });

    test('the kill looks again inside its runnable', () {
      final src = File(
        'android/app/src/main/kotlin/app/kryfo/QuietRestart.kt',
      ).readAsStringSync();
      final at = src.indexOf('postDelayed({');
      expect(at, greaterThan(0));
      final runnable = src.substring(at, src.indexOf('}, ', at));
      expect(runnable, contains('HaloListenerService.running'));
      expect(runnable, contains('onScreen(importance())'));
      expect(runnable, contains('killProcess'));
      // and android is only asked where it lets the service back
      expect(src, contains('isIgnoringBatteryOptimizations'));
    });
  });
}
