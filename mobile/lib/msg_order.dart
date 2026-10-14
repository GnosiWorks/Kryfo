// SPDX-License-Identifier: GPL-3.0-or-later
// a chat shows its messages by when each was written, oldest first, and
// in the order they came where two say the same time. ours by this
// phone's clock, theirs by when they reached it (writtenAtOf)
import 'dart:math' as math;

import 'relay_poll.dart' show Reached;

/// how long relays keep a wrap: nothing that reaches this phone was
/// written longer ago than this
const kWrittenBefore = Duration(days: 14);

/// where an arrival goes: when its sender wrote it, by this phone's clock.
/// it reached the relay or this phone within [reached], by this clock, and
/// was written as long before that as its wrap time less [written], their
/// own two stamps, whatever their clock reads. one that came live is placed by that
/// alone. one from a catch-up keeps its sender's time within that window,
/// so a batch stays in the order it was sent. never later than it came, or
/// a clock set ahead keeps it under every later message, and never earlier
/// than the relays keep a wrap or [since], when this phone joined its
/// group. with no lane stamp, [came] is the window
int writtenAtOf(
  int? written, {
  int? wrapped,
  Reached? reached,
  required int came,
  int? since,
}) {
  final keep = kWrittenBefore.inMilliseconds;
  final until = reached?.until ?? came;
  final age = written != null && wrapped != null
      ? (wrapped - written).clamp(0, keep)
      : 0;
  final hi = until - age;
  var lo = until - keep;
  if (reached != null && reached.from > 0) {
    lo = math.max(lo, reached.from - age);
  }
  if (since != null) lo = math.max(lo, since);
  lo = math.min(lo, hi);
  final w = written ?? wrapped;
  return w == null ? hi : w.clamp(lo, hi);
}

/// the time a row is shown and placed by: when it was written, or when it
/// came for a row that does not say
int rowWrittenAt(Map<String, Object?> r) =>
    ((r['written_at'] ?? r['sent_at']) as num?)?.toInt() ?? 0;

/// two rows in a chat's order, by time and then by row id. one not stored
/// yet (id 0 or less) goes after every stored one of the same time
int byWritten(int atA, int idA, int atB, int idB) {
  final c = atA.compareTo(atB);
  if (c != 0) return c;
  final a = idA > 0 ? idA : 1 << 62;
  final b = idB > 0 ? idB : 1 << 62;
  return a.compareTo(b);
}
