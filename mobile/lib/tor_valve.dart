// SPDX-License-Identifier: GPL-3.0-or-later
// a send that has waited on tor too long gets a way out: a reconnect done
// for real, and when tor will not take it, a restart that keeps the queue.
// nobody should ever have to reinstall to get a message out
import 'package:flutter/foundation.dart';

enum ValveStage { hidden, offer, working, restart }

/// how long a send may wait on tor before the way out is shown
const kValveAfter = Duration(seconds: 60);

/// how long a reconnect gets to bring the route back before a restart is
/// offered in its place
const kValveGrace = Duration(seconds: 60);

/// what the way out shows now. [waitingSince] is when the oldest send
/// still going began to wait, null when nothing is waiting
ValveStage valveStageAt({
  required bool private,
  required bool quiet,
  required DateTime? waitingSince,
  required DateTime now,
  required bool linkUp,
  required bool busy,
  required DateTime? triedAt,
  required bool triedFailed,
}) {
  // a decoy sends nothing, and outside onion there is no tor to restart
  if (quiet || !private) return ValveStage.hidden;
  if (busy) return ValveStage.working;
  final since = waitingSince;
  if (since == null || now.difference(since) < kValveAfter) {
    return ValveStage.hidden;
  }
  final tried = triedAt;
  if (tried != null &&
      !linkUp &&
      (triedFailed || now.difference(tried) >= kValveGrace)) {
    return ValveStage.restart;
  }
  return ValveStage.offer;
}

/// one per app: every chat and the home card share it, so a reconnect done
/// in one is not offered again in the next
class TorValve extends ChangeNotifier {
  TorValve({
    required this.reconnect,
    required this.restart,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// tor reconnected now, past every guard. 'ok' or why not
  final Future<String> Function() reconnect;

  /// the app started again in a new process. the queue is in the database
  final Future<void> Function() restart;

  final DateTime Function() _clock;

  bool _busy = false;
  DateTime? _triedAt;
  bool _triedFailed = false;

  DateTime now() => _clock();
  bool get busy => _busy;
  DateTime? get triedAt => _triedAt;
  bool get triedFailed => _triedFailed;

  /// the route is back: the next wait starts with a reconnect again. said
  /// from a build, so it tells nobody: whoever reads the stage next sees it
  void sawLink(bool up) {
    if (!up || _busy || _triedAt == null) return;
    _triedAt = null;
    _triedFailed = false;
  }

  Future<void> tryReconnect() async {
    if (_busy) return;
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
    // asleep on purpose is the check-ins mode's doing, not a stuck tor
    _triedFailed = r.startsWith('error') && r != 'error: tor is asleep';
    notifyListeners();
  }

  Future<void> tryRestart() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await restart();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  ValveStage stageFor({
    required bool private,
    required bool quiet,
    required DateTime? waitingSince,
    required bool linkUp,
    DateTime? now,
  }) => valveStageAt(
    private: private,
    quiet: quiet,
    waitingSince: waitingSince,
    now: now ?? _clock(),
    linkUp: linkUp,
    busy: _busy,
    triedAt: _triedAt,
    triedFailed: _triedFailed,
  );
}
