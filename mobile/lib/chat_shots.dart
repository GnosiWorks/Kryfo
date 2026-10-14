// SPDX-License-Identifier: GPL-3.0-or-later
// a 1:1 chat's screenshot block. both phones hold one state, on or off with
// the stamp it was set at, and every 1:1 envelope carries it as 'ss'. the
// key itself says the sender's phone knows the block: until theirs has said
// so, the switch stays off and nothing claims to block. the newer stamp
// wins, and on a tie the block stays on
import 'dart:convert';
import 'dart:math';

const kShotsWire = 'ss';

// shots_by: who made the last change, which the chat shows as a line
const kShotsByNone = 0;
const kShotsByMe = 1;
const kShotsByThem = 2;

// a stamp past this is no clock's
const _kStampMost = 1 << 52;

/// the state as the wire carries it
class ShotsWord {
  const ShotsWord({required this.on, required this.at});
  final bool on;
  final int at;

  Map<String, int> toWire() => {'o': on ? 1 : 0, 'a': at};

  static ShotsWord? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final o = raw['o'];
    final a = raw['a'];
    if (o is! int || (o != 0 && o != 1)) return null;
    if (a is! int || a < 0 || a >= _kStampMost) return null;
    return ShotsWord(on: o == 1, at: a);
  }
}

/// a chat's block as its contact row keeps it
class ChatShots {
  const ChatShots({
    this.on = false,
    this.at = 0,
    this.can = 0,
    this.by = kShotsByNone,
    this.when = 0,
  });

  factory ChatShots.ofRow(Map<String, Object?>? r) {
    int n(String k) => (r?[k] as num?)?.toInt() ?? 0;
    return ChatShots(
      on: n('shots_on') == 1,
      at: n('shots_at'),
      can: n('shots_can'),
      by: n('shots_by'),
      when: n('shots_when'),
    );
  }

  static const columns = [
    'shots_on',
    'shots_at',
    'shots_can',
    'shots_by',
    'shots_when',
  ];

  final bool on;
  final int at;
  // when their newest envelope was written, by their clock: positive when
  // it carried the state, negative when it did not
  final int can;
  final int by;
  // when the last change was made or came, by this clock: where its line
  // sits in the chat
  final int when;

  // their phone knows the block
  bool get peerCan => can > 0;
  // what both phones do now
  bool get blocking => on && peerCan;

  ShotsWord get word => ShotsWord(on: on, at: at);
}

/// [w] takes the place of the state held as ([on], [at])
bool shotsWins(ShotsWord w, {required bool on, required int at}) =>
    w.at > 0 && (w.at > at || (w.at == at && w.on && !on));

/// the stamp for a change made now: past every one seen, whatever the clock
int shotsNextStamp(int at, int now) => max(now, at + 1);

/// what [ChatShots.can] becomes after an envelope written at [written],
/// or null when it stays. [counts]: a message of theirs, which every phone
/// that knows the block stamps, so one without the key is from a phone
/// that does not. a copy written before the newest one changes nothing
int? shotsCanAfter(
  int was, {
  required bool carried,
  required bool counts,
  int? written,
}) {
  if (!carried && !counts) return null;
  if (written == null || written <= 0) {
    return carried && was <= 0 ? 1 : null;
  }
  final next = carried ? written : -written;
  if (next == was || next.abs() < was.abs()) return null;
  return next;
}

/// [wrapped] with [word] on it, for a 1:1 chat. a group's frame and
/// anything that is no envelope go as they are
String shotsStamped(String wrapped, ShotsWord word) {
  const prefix = 'halo/1:';
  if (!wrapped.startsWith(prefix)) return wrapped;
  final Object? body;
  try {
    body = jsonDecode(wrapped.substring(prefix.length));
  } catch (_) {
    return wrapped;
  }
  if (body is! Map<String, dynamic> || body.containsKey('g')) return wrapped;
  body[kShotsWire] = word.toWire();
  return '$prefix${jsonEncode(body)}';
}
