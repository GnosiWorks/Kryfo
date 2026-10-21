// SPDX-License-Identifier: GPL-3.0-or-later
// the home pill holds "Tor ready" through a short blip: a network handover,
// a bounce, a relay that dropped and came back. the outbox and every send
// check still go by the route itself
import 'widgets/motion.dart' show TorStatus;

/// how long the pill keeps saying ready once the route stopped carrying
const kPillGrace = Duration(seconds: 20);

/// offline for longer than a network handover takes: the grace is over,
/// so the pill goes from offline to connecting, never back to ready first
const kPillHandover = Duration(seconds: 5);

/// whether the pill says ready now
bool pillHoldsReady({
  required bool usable,
  required DateTime? usableAt,
  required TorStatus status,
  required bool online,
  required DateTime now,
}) {
  if (usable) return true;
  if (!online || status == TorStatus.off || usableAt == null) return false;
  final gone = now.difference(usableAt);
  return !gone.isNegative && gone < kPillGrace;
}

/// when a pill held ready has to look again, or null when it is not held
DateTime? pillGraceEnds({
  required bool usable,
  required DateTime? usableAt,
  required TorStatus status,
  required bool online,
  required DateTime now,
}) {
  if (usable || usableAt == null) return null;
  final held = pillHoldsReady(
    usable: usable,
    usableAt: usableAt,
    status: status,
    online: online,
    now: now,
  );
  return held ? usableAt.add(kPillGrace) : null;
}
