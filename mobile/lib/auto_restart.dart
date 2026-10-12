// SPDX-License-Identifier: GPL-3.0-or-later
// a restart nobody asked for, for a tor this process cannot bring back: a
// route stalled for minutes and a reconnect it would not take. only out of
// sight with the always-on service up, at most once in half an hour of time
// since boot, and never where it would cut something short
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dlog.dart';
import 'drafts.dart';
import 'secure_store.dart';

/// the most often a restart happens on its own
const kAutoRestartEvery = Duration(minutes: 30);

/// a route that has not climbed for this long is given a reconnect first
const kAutoReconnectAfter = Duration(minutes: 5);

/// and no more often than this. a failed one counts for as long
const kAutoReconnectEvery = Duration(minutes: 10);

/// control calls in a row tor left unanswered: past this the port is gone
const kCtrlSilentDead = 2;

const kAutoRestartKey = 'auto_restart.at';

enum AutoStep { none, reconnect, restart }

/// a moment on the clock since boot, which a change of date does not move,
/// and which boot it was. boot is -1 where the phone does not say
class BootTime {
  const BootTime(this.upMs, this.boot);
  final int upMs;
  final int boot;

  String encode() => '$upMs/$boot';

  static BootTime? parse(String? s) {
    final parts = s?.split('/');
    if (parts == null || parts.length != 2) return null;
    final up = int.tryParse(parts[0]), boot = int.tryParse(parts[1]);
    return up == null || boot == null ? null : BootTime(up, boot);
  }
}

/// whether the half hour since the last restart is over. another boot, or a
/// clock since boot that went back, is a phone started again: due
bool autoRestartDue(BootTime? last, BootTime now) {
  if (last == null) return true;
  if (last.boot >= 0 && now.boot >= 0 && last.boot != now.boot) return true;
  if (now.upMs < last.upMs) return true;
  return now.upMs - last.upMs >= kAutoRestartEvery.inMilliseconds;
}

/// what the background sees of the app and of tor
class AutoView {
  const AutoView({
    required this.inFront,
    required this.alwaysOn,
    required this.private,
    required this.quiet,
    required this.online,
    required this.held,
    required this.torHeld,
    required this.torReady,
    required this.ctrlSilent,
    required this.stuckSince,
    this.passRuns = false,
  });

  final bool inFront;
  final bool alwaysOn;
  final bool private;

  /// a decoy is open
  final bool quiet;
  final bool online;

  /// a voice note, a file going or coming, a backup or a restore, a
  /// picker out, a wipe
  final bool held;

  /// tor put to sleep on purpose
  final bool torHeld;
  final bool torReady;
  final int ctrlSilent;

  /// since when the bootstrap has not climbed, null when it is not trying
  final DateTime? stuckSince;

  /// automatic is trying a way in
  final bool passRuns;
}

/// what is done about tor now. only a route stalled for minutes is looked
/// at, whatever the control port says, and it gets a reconnect first: a
/// restart follows only a reconnect that failed
AutoStep autoStepAt(
  AutoView v, {
  required DateTime now,
  DateTime? reconnectedAt,
  bool reconnectFailed = false,
  bool due = true,
}) {
  if (v.inFront || !v.alwaysOn || !v.private || v.quiet || !v.online) {
    return AutoStep.none;
  }
  if (v.torHeld || v.torReady) return AutoStep.none;
  final since = v.stuckSince;
  if (since == null || now.difference(since) < kAutoReconnectAfter) {
    return AutoStep.none;
  }
  final tried = reconnectedAt;
  final recent =
      tried != null && now.difference(tried).abs() < kAutoReconnectEvery;
  if (!recent) return AutoStep.reconnect;
  return reconnectFailed && due && !v.held ? AutoStep.restart : AutoStep.none;
}

/// what the engine answers while tor waits on purpose: asleep, replaced by
/// another, turned away by a guard, no network, bridges not taken yet, or
/// automatic finding its way in, which on a blocked network takes long. no
/// mode yet is no wait: only a new process hands the kept mode over again.
/// [passRuns]: automatic is trying, and starts the listeners again itself
bool torWaitsWith(String r, {bool passRuns = false}) {
  if (const {
    'error: tor is asleep',
    'error: superseded',
    'error: one already running',
    'error: too soon',
    'error: no data dir',
    'error: no network',
    'error: automatic is connecting',
    'error: automatic has no way in yet',
    'error: bridges not applied',
  }.contains(r)) {
    return true;
  }
  return passRuns && r == 'error: bridges could not start';
}

/// errors that say tor could not be reached in this process. a wait on
/// purpose is no failure, and one control call left unanswered is not yet
/// a dead port
bool reconnectFailedWith(
  String r, {
  int ctrlSilent = 0,
  bool passRuns = false,
}) {
  if (!r.startsWith('error')) return false;
  if (torWaitsWith(r, passRuns: passRuns)) return false;
  if (r.contains('control port timeout')) return ctrlSilent >= kCtrlSilentDead;
  return true;
}

class AutoRestart {
  AutoRestart({
    required this.view,
    required this.reconnect,
    required this.restart,
    required this.clock,
    FlutterSecureStorage? draftStore,
    DateTime Function()? now,
  }) : _drafts = draftStore ?? secureStore,
       _now = now ?? DateTime.now;

  final AutoView Function() view;

  /// tor reconnected now. 'ok' or why not
  final Future<String> Function() reconnect;

  /// the process ended with nothing on screen. false when android would not
  final Future<bool> Function() restart;

  /// the clock since boot, null when it cannot be read
  final Future<BootTime?> Function() clock;

  final FlutterSecureStorage _drafts;
  final DateTime Function() _now;

  bool _busy = false;
  DateTime? _reconnectedAt;
  bool _reconnectFailed = false;

  Future<BootTime?> _last() async {
    final prefs = await SharedPreferences.getInstance();
    return BootTime.parse(prefs.getString(kAutoRestartKey));
  }

  AutoStep _step(bool due) => autoStepAt(
    view(),
    now: _now(),
    reconnectedAt: _reconnectedAt,
    reconnectFailed: _reconnectFailed,
    due: due,
  );

  /// one look, from the status poll. what was done
  Future<AutoStep> tick() async {
    if (_busy) return AutoStep.none;
    _busy = true;
    try {
      // a step that could restart reads the last restart first. unread,
      // nothing restarts: a loop is worse than a tor left down
      var step = _step(true);
      BootTime? at;
      if (step == AutoStep.restart) {
        at = await clock();
        if (at == null || !autoRestartDue(await _last(), at)) {
          step = AutoStep.none;
        }
      }
      switch (step) {
        case AutoStep.none:
          break;
        case AutoStep.reconnect:
          String r;
          try {
            r = await reconnect();
          } catch (e) {
            r = 'error: $e';
          }
          _reconnectedAt = _now();
          final v = view();
          _reconnectFailed = reconnectFailedWith(
            r,
            ctrlSilent: v.ctrlSilent,
            passRuns: v.passRuns,
          );
          dlog('auto restart: reconnect $r');
        case AutoStep.restart:
          // written down before anything goes: the next process reads it
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString(kAutoRestartKey, at!.encode())) {
            return AutoStep.none;
          }
          // the person may have come back while it was written
          if (_step(true) != AutoStep.restart) return AutoStep.none;
          dlog('auto restart: tor dead in this process');
          await restartKeepingDrafts(restart, store: _drafts);
      }
      return step;
    } catch (e) {
      dlog('auto restart: ${e.runtimeType}');
      return AutoStep.none;
    } finally {
      _busy = false;
    }
  }
}
