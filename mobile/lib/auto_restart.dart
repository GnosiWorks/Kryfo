// SPDX-License-Identifier: GPL-3.0-or-later
// a restart nobody asked for, for a tor this process cannot bring back: its
// control port gone silent, or a reconnect it would not take. only out of
// sight with the always-on service up, at most once in half an hour across
// processes, and never where it would cut something short
import 'package:flutter/foundation.dart';
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
  });

  final bool inFront;
  final bool alwaysOn;
  final bool private;

  /// a decoy is open
  final bool quiet;
  final bool online;

  /// a voice note, a file going or coming, a picker out, a wipe
  final bool held;

  /// tor put to sleep on purpose
  final bool torHeld;
  final bool torReady;
  final int ctrlSilent;

  /// since when the bootstrap has not climbed, null when it is not trying
  final DateTime? stuckSince;
}

/// what is done about tor now. a slow bootstrap only ever gets a reconnect:
/// a restart needs a silent control port or a reconnect that failed
AutoStep autoStepAt(
  AutoView v, {
  required DateTime now,
  DateTime? reconnectedAt,
  bool reconnectFailed = false,
  DateTime? restartedAt,
}) {
  if (v.inFront || !v.alwaysOn || !v.private || v.quiet || !v.online) {
    return AutoStep.none;
  }
  if (v.torHeld || v.torReady) return AutoStep.none;
  final tried = reconnectedAt;
  final recent =
      tried != null && now.difference(tried).abs() < kAutoReconnectEvery;
  final silent = v.ctrlSilent >= kCtrlSilentDead;
  if (silent || (recent && reconnectFailed)) {
    final last = restartedAt;
    // either way round: a clock set back must not open a loop either
    final due = last == null || now.difference(last).abs() >= kAutoRestartEvery;
    return due && !v.held ? AutoStep.restart : AutoStep.none;
  }
  final since = v.stuckSince;
  if (since == null || now.difference(since) < kAutoReconnectAfter) {
    return AutoStep.none;
  }
  return recent ? AutoStep.none : AutoStep.reconnect;
}

/// errors that say tor could not be reached in this process. asleep on
/// purpose, replaced by another or turned away by a guard is no failure
bool reconnectFailedWith(String r) =>
    r.startsWith('error') &&
    !const {
      'error: tor is asleep',
      'error: superseded',
      'error: one already running',
      'error: too soon',
      'error: no data dir',
    }.contains(r);

class AutoRestart {
  AutoRestart({
    required this.view,
    required this.reconnect,
    required this.restart,
    FlutterSecureStorage? draftStore,
    DateTime Function()? clock,
  }) : _drafts = draftStore ?? secureStore,
       _clock = clock ?? DateTime.now;

  final AutoView Function() view;

  /// tor reconnected now. 'ok' or why not
  final Future<String> Function() reconnect;

  /// the process ended with nothing on screen. false when android would not
  final Future<bool> Function() restart;

  final FlutterSecureStorage _drafts;
  final DateTime Function() _clock;

  bool _busy = false;
  bool _stampRead = false;
  DateTime? _restartedAt;
  DateTime? _reconnectedAt;
  bool _reconnectFailed = false;

  @visibleForTesting
  DateTime? get restartedAt => _restartedAt;

  // the last restart, as the process before this one wrote it
  Future<void> _readStamp() async {
    if (_stampRead) return;
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(kAutoRestartKey);
    _restartedAt = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    _stampRead = true;
  }

  AutoStep _step(DateTime now) => autoStepAt(
    view(),
    now: now,
    reconnectedAt: _reconnectedAt,
    reconnectFailed: _reconnectFailed,
    restartedAt: _restartedAt,
  );

  /// one look, from the status poll. what was done
  Future<AutoStep> tick() async {
    if (_busy) return AutoStep.none;
    _busy = true;
    try {
      // unread, nothing restarts: a loop is worse than a tor left down
      await _readStamp();
      final now = _clock();
      final step = _step(now);
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
          _reconnectedAt = _clock();
          _reconnectFailed = reconnectFailedWith(r);
          dlog('auto restart: reconnect $r');
        case AutoStep.restart:
          // written down before anything goes: the next process reads it
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setInt(
            kAutoRestartKey,
            now.millisecondsSinceEpoch,
          )) {
            return AutoStep.none;
          }
          final before = _restartedAt;
          _restartedAt = now;
          // the person may have come back while it was written
          final still = autoStepAt(
            view(),
            now: _clock(),
            reconnectedAt: _reconnectedAt,
            reconnectFailed: _reconnectFailed,
            restartedAt: before,
          );
          if (still != AutoStep.restart) return AutoStep.none;
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
