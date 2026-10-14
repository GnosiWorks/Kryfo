// SPDX-License-Identifier: GPL-3.0-or-later
// a chat shows its messages by when each was written, oldest first, and
// in the order they came where two say the same time. ours by this
// phone's clock, theirs by the sender's, held to what can be true
import 'dart:math' as math;

/// how far past the time it came a message may say it was written
const kWrittenAhead = Duration(minutes: 1);

/// how far before the first contact with its sender a message may say it
/// was written: as long as relays keep a wrap
const kWrittenBefore = Duration(days: 14);

/// when an arrival was written, by the sender's clock, held between the
/// first contact with them less [kWrittenBefore] and the time it came plus
/// [kWrittenAhead], so a clock set wrong, or on purpose, can never keep a
/// message under every later one or above the whole chat. [firstSeen] is
/// null when there is no contact yet; with no time of its own it is when
/// it came
int writtenAtOf(int? written, {required int came, int? firstSeen}) {
  final hi = came + kWrittenAhead.inMilliseconds;
  final lo = math.min((firstSeen ?? came) - kWrittenBefore.inMilliseconds, hi);
  if (written == null) return came;
  return written.clamp(lo, hi);
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
