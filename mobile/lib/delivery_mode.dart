// SPDX-License-Identifier: GPL-3.0-or-later
// how kryfo gets new messages.
//
//   always    its own tor connection stays open behind the foreground
//             service. instant, nobody else involved, heaviest on battery
//   checkins  tor comes up every fifteen minutes or so, fetches, goes down
//             again. nobody else involved, lightest, messages can be late
//   helper    a unifiedpush app keeps one light connection and wakes kryfo.
//             instant and light, and the helper's server learns when
//
// the key is read by the android side too (as flutter.delivery_mode), which
// has to know whether to bring the foreground service back.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/l10n.dart';
import 'l10n/numbers.dart';

enum DeliveryMode { always, checkins, helper }

const kDeliveryModeKey = 'delivery_mode';
const kLastCheckKey = 'delivery_last_check';
const kLastWakeKey = 'delivery_last_wake';
const kHeartbeatKey = 'delivery_heartbeat';
const kKillsKey = 'delivery_kills';
const kNudgeShownKey = 'delivery_nudge_shown';
const kLastCheckHowKey = 'delivery_last_how';
// when the last check-in was attempted, whatever came of it, so a fresh
// failure is not shown with the last success's age
const kLastCheckTriedKey = 'delivery_last_tried';
const kLastCheckRelaysKey = 'delivery_last_relays';

DeliveryMode deliveryModeOf(String? raw) => switch (raw) {
  'checkins' => DeliveryMode.checkins,
  'helper' => DeliveryMode.helper,
  _ => DeliveryMode.always,
};

Future<DeliveryMode> loadDeliveryMode() async {
  final prefs = await SharedPreferences.getInstance();
  return deliveryModeOf(prefs.getString(kDeliveryModeKey));
}

Future<void> saveDeliveryMode(DeliveryMode m) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kDeliveryModeKey, m.name);
}

String deliveryModeName(DeliveryMode m) => switch (m) {
  DeliveryMode.always => l10n.deliveryModeAlwaysOn,
  DeliveryMode.checkins => l10n.deliveryModeCheckIns,
  DeliveryMode.helper => l10n.deliveryModeThroughAHelperApp,
};

String agoLine(int thenMs, int nowMs) {
  final d = nowMs - thenMs;
  if (thenMs <= 0 || d < 0) return l10n.deliveryModeNotYet;
  final min = d ~/ 60000;
  if (min < 1) return l10n.deliveryModeJustNow;
  if (min < 60) return l10n.deliveryModeMinAgo(min);
  final h = min ~/ 60;
  if (h < 24) {
    return l10n.deliveryMode1HourAgo(h);
  }
  final days = h ~/ 24;
  return days == 1
      ? l10n.deliveryModeYesterday
      : l10n.deliveryModeDaysAgo(days);
}

class DeliveryStatus {
  final String text;
  final bool live;
  const DeliveryStatus(this.text, {this.live = false});
}

/// the one line under the cards. it says what happened, never what was
/// promised: doze stretches a check-in, and the line shows the real last one.
DeliveryStatus deliveryStatus({
  required DeliveryMode mode,
  required bool connected,
  required bool connecting,
  // a check-in is running right now: woken by the job or by a knock
  bool checking = false,
  required int lastCheckMs,
  required int lastWakeMs,
  required int nowMs,
  String? helperName,
}) {
  switch (mode) {
    case DeliveryMode.always:
      if (connected) {
        return DeliveryStatus(l10n.deliveryModeConnected, live: true);
      }
      return DeliveryStatus(
        connecting
            ? l10n.deliveryModeConnecting
            : l10n.deliveryModeNotConnected,
      );
    case DeliveryMode.checkins:
      if (checking) {
        return DeliveryStatus(l10n.deliveryModeCheckingNow, live: true);
      }
      final last = lastCheckMs > 0
          ? l10n.deliveryModeLastCheckIn(agoLine(lastCheckMs, nowMs))
          : l10n.deliveryModeNoCheckInYet;
      // with kryfo open the connection is up anyway. the last check-in still
      // shows: this screen is only ever read with kryfo open
      if (connected) {
        return DeliveryStatus(l10n.deliveryModeConnectedNow(last), live: true);
      }
      if (connecting) return DeliveryStatus(l10n.deliveryModeConnecting2(last));
      if (lastCheckMs <= 0) {
        return DeliveryStatus(l10n.deliveryModeNoCheckInYet2);
      }
      return DeliveryStatus(
        l10n.deliveryModeLastChecked(agoLine(lastCheckMs, nowMs)),
      );
    case DeliveryMode.helper:
      final who = (helperName == null || helperName.isEmpty)
          ? l10n.deliveryModeAHelperApp
          : helperName;
      if (lastWakeMs <= 0) {
        return DeliveryStatus(l10n.deliveryModeWokenByNoWake(who));
      }
      return DeliveryStatus(
        l10n.deliveryModeWokenByLastWake(who, agoLine(lastWakeMs, nowMs)),
      );
  }
}

// ---- the nudge ----
// no reading of vendor settings. in always-on the app writes the time every
// few minutes; a start that finds it long past, with no reboot in between,
// was a kill. three in a day and the card shows, once ever.

const kHeartbeatEveryMs = 5 * 60 * 1000;
const kKillGapMs = 30 * 60 * 1000;
const kKillsForNudge = 3;
const kDayMs = 24 * 60 * 60 * 1000;

class RestartVerdict {
  final bool wasKill;
  final List<int> kills;
  final bool showNudge;
  const RestartVerdict(this.wasKill, this.kills, this.showNudge);
}

RestartVerdict judgeRestart({
  required int nowMs,
  required int lastBeatMs,
  required int bootedAtMs,
  required List<int> kills,
  required bool nudgeShown,
  required DeliveryMode mode,
}) {
  final recent = [
    for (final k in kills)
      if (k > 0 && nowMs - k < kDayMs && k <= nowMs) k,
  ];
  final gap = nowMs - lastBeatMs;
  final wasKill =
      mode == DeliveryMode.always &&
      lastBeatMs > 0 &&
      gap > kKillGapMs &&
      // the phone itself was off or restarted in between: not a kill
      bootedAtMs < lastBeatMs;
  if (wasKill) recent.add(nowMs);
  return RestartVerdict(
    wasKill,
    recent,
    !nudgeShown &&
        mode == DeliveryMode.always &&
        recent.length >= kKillsForNudge,
  );
}

// ---- the fifteen-minute job in always-on ----
// its kick is for relay sockets that died while the phone slept, and its
// wait keeps the phone awake while they come back. a process that has been
// awake and polling long enough for the engine's own relay probes to have
// run has already found and redialed a dead socket, so with the listener
// service up the job leaves at once. after any sleep it knocks and waits.

// a relay poll tick this late after the one before: the phone slept
const kPollStallMs = 10 * 1000;
// awake this long: the probe on our own relay (every 75 s, given up on
// after 30 s) has run since the last sleep
const kJobAwakeMs = 2 * 60 * 1000;

bool jobMayRest({
  required DeliveryMode mode,
  required bool serviceUp,
  required bool torReady,
  required int nowMs,
  required int lastPollMs,
  required int awakeSinceMs,
}) =>
    mode == DeliveryMode.always &&
    serviceUp &&
    torReady &&
    lastPollMs > 0 &&
    nowMs - lastPollMs < kPollStallMs &&
    awakeSinceMs > 0 &&
    nowMs - awakeSinceMs >= kJobAwakeMs;

// the last check-in, stored as {how, secs, why} and worded here. plain text
// from an older build is shown as it is.
Map<String, dynamic>? _json(String stored) {
  if (!stored.startsWith('{') && !stored.startsWith('[')) return null;
  try {
    final v = jsonDecode(stored);
    return v is Map<String, dynamic> ? v : {'list': v};
  } catch (_) {
    return null;
  }
}

String checkInLine(String stored) {
  final m = _json(stored);
  if (m == null) return stored;
  final how = switch (m['how']) {
    'nowake' => l10n.appTorWouldNotWake,
    'notready' => l10n.appTorNotReadyIn,
    'ok' => l10n.appOk,
    'ok_norelay' => l10n.appOkNoRelayBegan,
    'ok_capped' => l10n.appOkCapped,
    _ => l10n.appCheckStarted,
  };
  return l10n.appSBy(how, m['secs'] as int? ?? 0, '${m['why']}');
}

bool checkInOk(String stored) {
  final m = _json(stored);
  if (m == null) return stored.startsWith('ok');
  return '${m['how']}'.startsWith('ok');
}

// the per-relay catch-up line: host and seconds, and for a slow or dropped
// relay its slowest subscription - how many of the relay's subscriptions
// were held up, how long its connect took, and how far back it walked
String catchupLine(String stored) {
  final m = _json(stored);
  if (m == null) return stored;
  final parts = <String>[];
  for (final r in (m['list'] as List? ?? const [])) {
    final ms = r['ms'] as int? ?? 0;
    final dropped = r['dropped'] == true;
    final secs = decimal(ms / 1000, 1);
    var line = dropped
        ? l10n.appSDropped(r['host'], secs)
        : l10n.appS(r['host'], secs);
    if (r['long'] == true) line = l10n.appLongWindow(line);
    if (dropped || ms > 5000) {
      final c = decimal((r['connect_ms'] as int? ?? 0) / 1000, 1);
      final p = r['pages'] as int? ?? 0;
      final e = r['events'] as int? ?? 0;
      final subs = r['subs'] as int? ?? 0;
      final held = r['held'] as int? ?? 0;
      line = subs > 1
          ? l10n.appOf(line, dropped ? held : 1, subs, c, p, e)
          : l10n.appConnectSPagesEvents(line, c, p, e);
    }
    parts.add(line);
  }
  return parts.join(' · ');
}

bool catchupDropped(String stored) {
  final m = _json(stored);
  if (m == null) return stored.contains('dropped');
  return (m['list'] as List? ?? const []).any((r) => r['dropped'] == true);
}
