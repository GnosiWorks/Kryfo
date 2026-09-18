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

import 'package:shared_preferences/shared_preferences.dart';

enum DeliveryMode { always, checkins, helper }

const kDeliveryModeKey = 'delivery_mode';
const kLastCheckKey = 'delivery_last_check';
const kLastWakeKey = 'delivery_last_wake';
const kHeartbeatKey = 'delivery_heartbeat';
const kKillsKey = 'delivery_kills';
const kNudgeShownKey = 'delivery_nudge_shown';

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
  DeliveryMode.always => 'Always on',
  DeliveryMode.checkins => 'Check-ins',
  DeliveryMode.helper => 'Through a helper app',
};

String agoLine(int thenMs, int nowMs) {
  final d = nowMs - thenMs;
  if (thenMs <= 0 || d < 0) return 'not yet';
  final min = d ~/ 60000;
  if (min < 1) return 'just now';
  if (min < 60) return '$min min ago';
  final h = min ~/ 60;
  if (h < 24) return h == 1 ? '1 hour ago' : '$h hours ago';
  final days = h ~/ 24;
  return days == 1 ? 'yesterday' : '$days days ago';
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
  required int lastCheckMs,
  required int lastWakeMs,
  required int nowMs,
  String? helperName,
}) {
  switch (mode) {
    case DeliveryMode.always:
      if (connected) return const DeliveryStatus('Connected', live: true);
      return DeliveryStatus(connecting ? 'Connecting' : 'Not connected');
    case DeliveryMode.checkins:
      if (connected || connecting) {
        return const DeliveryStatus('Checking now', live: true);
      }
      if (lastCheckMs <= 0) return const DeliveryStatus('Not checked yet');
      return DeliveryStatus('Last checked ${agoLine(lastCheckMs, nowMs)}');
    case DeliveryMode.helper:
      final who = (helperName == null || helperName.isEmpty)
          ? 'a helper app'
          : helperName;
      if (lastWakeMs <= 0) {
        return DeliveryStatus('Woken by $who · no wake-up yet');
      }
      return DeliveryStatus(
        'Woken by $who · last wake-up ${agoLine(lastWakeMs, nowMs)}',
      );
  }
}

// ---- the nudge ----
//
// no reading of miui or any other vendor's settings. the app notices on its
// own that it was dead: while it lives in always-on it writes the time every
// few minutes, and a start that finds that time long past, on a phone that
// was not switched off in between, was a kill. three in a day and the card
// is shown, once, ever.

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
