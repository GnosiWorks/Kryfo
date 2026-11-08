// SPDX-License-Identifier: GPL-3.0-or-later
// a send that has waited on tor too long gets a way out: a reconnect done
// for real, and when tor will not take it, a restart that keeps the queue.
// nobody should ever have to reinstall to get a message out
import 'package:flutter/foundation.dart';

import 'auto_restart.dart';

enum ValveStage { hidden, offer, working, cooling, restart }

/// how long a send may wait on tor before the way out is shown
const kValveAfter = Duration(seconds: 60);

/// how long a reconnect gets to bring the route back. the button rests that
/// long after one tor took, and a restart is offered after it
const kValveGrace = Duration(seconds: 60);

/// a strip on screen this long with the route still down reconnects by
/// itself: the tap nobody should have to make. once per wait
const kValveAutoAfter = Duration(seconds: 90);

/// and never more often than this, however the route comes and goes
const kValveAutoEvery = Duration(minutes: 5);

/// what keeps a restart from being offered: a voice note being recorded.
/// each recorder puts itself in while it records
final Set<Object> restartHolds = {};

/// what the way out shows now. [waitingSince] is when the oldest send still
/// going was written, null when nothing is waiting
ValveStage valveStageAt({
  required bool private,
  required bool quiet,
  required bool online,
  required DateTime? waitingSince,
  required DateTime now,
  required bool linkUp,
  required bool busy,
  required DateTime? triedAt,
  required bool triedFailed,
  bool restartBlocked = false,
}) {
  // a decoy sends nothing, outside onion there is no tor to restart, and
  // with no network at all neither would help
  if (quiet || !private || !online) return ValveStage.hidden;
  if (busy) return ValveStage.working;
  final since = waitingSince;
  if (since == null || now.difference(since) < kValveAfter) {
    return ValveStage.hidden;
  }
  final tried = triedAt;
  if (tried != null) {
    final waited = now.difference(tried);
    if (!triedFailed && waited < kValveGrace) return ValveStage.cooling;
    if (!linkUp && (triedFailed || waited >= kValveGrace)) {
      return restartBlocked ? ValveStage.offer : ValveStage.restart;
    }
  }
  return ValveStage.offer;
}

/// when a chat's wait on tor began, from [oldest], the oldest send still
/// going. a send held for their answer waits on them, not on tor: no wait
/// then. one their answer let go waits from the answer, so the route it
/// takes then gets its full minute
DateTime? valveWaitFrom(
  DateTime? oldest, {
  required bool awaitsAnswer,
  int? answeredAtMs,
}) {
  if (oldest == null || awaitsAnswer) return null;
  if (answeredAtMs == null) return oldest;
  final answered = DateTime.fromMillisecondsSinceEpoch(answeredAtMs);
  return answered.isAfter(oldest) ? answered : oldest;
}

/// one per app: every chat and the home card share it, so a reconnect done
/// in one is not offered again in the next
class TorValve extends ChangeNotifier {
  TorValve({
    required this.reconnect,
    required this.restart,
    this.beforeRestart,
    this.busyElsewhere,
    this.passRuns,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// tor reconnected now, past every guard. 'ok' or why not
  final Future<String> Function() reconnect;

  /// the app started again in a new process. the queue is in the database
  final Future<void> Function() restart;

  /// what has to be kept before the process goes: the drafts
  final Future<void> Function()? beforeRestart;

  /// a file going out or coming in: a restart would cut it
  final bool Function()? busyElsewhere;

  /// automatic is trying a way in
  final bool Function()? passRuns;

  DateTime Function() _clock;

  @visibleForTesting
  set clockForTest(DateTime Function() c) => _clock = c;

  bool _busy = false;
  DateTime? _triedAt;
  bool _triedFailed = false;
  DateTime? _autoAt;

  DateTime now() => _clock();
  bool get busy => _busy;
  DateTime? get triedAt => _triedAt;
  bool get triedFailed => _triedFailed;

  bool get restartBlocked =>
      restartHolds.isNotEmpty || (busyElsewhere?.call() ?? false);

  /// the route is back: once the rest after a reconnect is over, the next
  /// wait starts with a reconnect again. said from a build, so it tells
  /// nobody: whoever reads the stage next sees it
  void sawLink(bool up) {
    final tried = _triedAt;
    if (!up || _busy || tried == null) return;
    if (!_triedFailed && _clock().difference(tried) < kValveGrace) return;
    _triedAt = null;
    _triedFailed = false;
  }

  Future<void> tryReconnect() async {
    await _reconnect();
  }

  /// whether the strip reconnects by itself now: it offers a reconnect, has
  /// for kValveAutoAfter of waiting, and none was tried in this wait
  bool autoDue({
    required bool private,
    required bool quiet,
    required bool online,
    required DateTime? waitingSince,
    required bool linkUp,
  }) {
    final now = _clock();
    final since = waitingSince;
    if (linkUp || since == null || _triedAt != null) return false;
    if (now.difference(since) < kValveAutoAfter) return false;
    final last = _autoAt;
    if (last != null && now.difference(last) < kValveAutoEvery) return false;
    return stageFor(
          private: private,
          quiet: quiet,
          online: online,
          waitingSince: since,
          linkUp: linkUp,
          now: now,
        ) ==
        ValveStage.offer;
  }

  /// the reconnect the strip offers, done for whoever waits. a wait on
  /// purpose (automatic finding a way, no network) tried nothing, so the
  /// strip goes on offering it rather than a restart
  Future<void> autoTry({
    required bool private,
    required bool quiet,
    required bool online,
    required DateTime? waitingSince,
    required bool linkUp,
  }) async {
    if (!autoDue(
      private: private,
      quiet: quiet,
      online: online,
      waitingSince: waitingSince,
      linkUp: linkUp,
    )) {
      return;
    }
    _autoAt = _clock();
    final r = await _reconnect();
    if (torWaitsWith(r, passRuns: passRuns?.call() ?? false)) {
      _triedAt = null;
      _triedFailed = false;
      notifyListeners();
    }
  }

  Future<String> _reconnect() async {
    if (_busy) return 'busy';
    final tried = _triedAt;
    if (tried != null &&
        !_triedFailed &&
        _clock().difference(tried) < kValveGrace) {
      return 'resting';
    }
    _busy = true;
    notifyListeners();
    String r;
    try {
      r = await reconnect();
    } catch (e) {
      r = 'error: $e';
    }
    _busy = false;
    _triedAt = _clock();
    // a wait on purpose is not a stuck tor: asleep for the check-ins, no
    // network, or automatic still finding its way in
    _triedFailed =
        r.startsWith('error') &&
        !torWaitsWith(r, passRuns: passRuns?.call() ?? false);
    notifyListeners();
    return r;
  }

  Future<void> tryRestart() async {
    if (_busy || restartBlocked) return;
    _busy = true;
    notifyListeners();
    try {
      await beforeRestart?.call();
      await restart();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  ValveStage stageFor({
    required bool private,
    required bool quiet,
    required bool online,
    required DateTime? waitingSince,
    required bool linkUp,
    DateTime? now,
  }) => valveStageAt(
    private: private,
    quiet: quiet,
    online: online,
    waitingSince: waitingSince,
    now: now ?? _clock(),
    linkUp: linkUp,
    busy: _busy,
    triedAt: _triedAt,
    triedFailed: _triedFailed,
    restartBlocked: restartBlocked,
  );
}
