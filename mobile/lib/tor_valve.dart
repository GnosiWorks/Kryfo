// SPDX-License-Identifier: GPL-3.0-or-later
// a send that has waited on tor too long gets a way out: a reconnect done
// for real, and when tor will not take it, a restart that keeps the queue.
// nobody should ever have to reinstall to get a message out
import 'package:flutter/foundation.dart';

enum ValveStage { hidden, offer, working, cooling, restart }

/// how long a send may wait on tor before the way out is shown
const kValveAfter = Duration(seconds: 60);

/// how long a reconnect gets to bring the route back. the button rests that
/// long after one tor took, and a restart is offered after it
const kValveGrace = Duration(seconds: 60);

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

/// one per app: every chat and the home card share it, so a reconnect done
/// in one is not offered again in the next
class TorValve extends ChangeNotifier {
  TorValve({
    required this.reconnect,
    required this.restart,
    this.beforeRestart,
    this.busyElsewhere,
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

  final DateTime Function() _clock;

  bool _busy = false;
  DateTime? _triedAt;
  bool _triedFailed = false;

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
    if (_busy) return;
    final tried = _triedAt;
    if (tried != null &&
        !_triedFailed &&
        _clock().difference(tried) < kValveGrace) {
      return;
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
    // asleep on purpose is the check-ins mode's doing, not a stuck tor, and
    // with no network tor waits for one
    _triedFailed =
        r.startsWith('error') &&
        r != 'error: tor is asleep' &&
        r != 'error: no network';
    notifyListeners();
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
