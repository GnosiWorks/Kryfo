// SPDX-License-Identifier: GPL-3.0-or-later
// a 1:1 chat's screenshot block. both phones hold one state, on or off with
// the stamp it was set at, and every 1:1 envelope carries it as 'ss'. the
// key itself says the sender's phone knows the block: until theirs has said
// so, the switch stays off and nothing claims to block. the newer stamp
// wins, and on a tie the block stays on
import 'dart:async';
import 'dart:convert';
import 'dart:math';

const kShotsWire = 'ss';

// shots_by: who made the last change, which the chat shows as a line
const kShotsByNone = 0;
const kShotsByMe = 1;
const kShotsByThem = 2;

// the stamp goes as thirteen digits whatever it is, so a chat never set
// sends as many bytes as one set. past this it is no clock's
const _kStampWidth = 13;
const kShotsStampMost = 9999999999999;

// a stamp further ahead of this clock is not taken
const kShotsAheadMost = Duration(days: 1);

// their changes move the line at most this often; a burst reads as one
const kShotsLineGap = Duration(minutes: 1);

final _stampShape = RegExp(r'^\d{13}$');

/// the state as the wire carries it
class ShotsWord {
  const ShotsWord({required this.on, required this.at});
  final bool on;
  final int at;

  Map<String, Object> toWire() => {
    'o': on ? 1 : 0,
    'a': at.clamp(0, kShotsStampMost).toString().padLeft(_kStampWidth, '0'),
  };

  static ShotsWord? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final o = raw['o'];
    final a = raw['a'];
    if (o is! int || (o != 0 && o != 1)) return null;
    if (a is! String || !_stampShape.hasMatch(a)) return null;
    return ShotsWord(on: o == 1, at: int.parse(a));
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
    this.blocked = false,
    this.quiet = false,
    this.known = false,
  });

  /// [quiet]: a decoy's chat, which keeps its switch here alone
  factory ChatShots.ofRow(Map<String, Object?>? r, {bool quiet = false}) {
    int n(String k) => (r?[k] as num?)?.toInt() ?? 0;
    return ChatShots(
      on: n('shots_on') == 1,
      at: n('shots_at'),
      can: n('shots_can'),
      by: n('shots_by'),
      when: n('shots_when'),
      blocked: n('blocked') == 1,
      quiet: quiet,
      known: r != null,
    );
  }

  // what the upgrade adds
  static const columns = [
    'shots_on',
    'shots_at',
    'shots_can',
    'shots_by',
    'shots_when',
  ];

  // what a read takes
  static const reads = [...columns, 'blocked'];

  final bool on;
  final int at;
  // when their newest envelope was written, by their clock: positive when
  // it carried the state, negative when it did not
  final int can;
  final int by;
  // when the last change was made or came, by this clock: where its line
  // sits in the chat
  final int when;
  final bool blocked;
  final bool quiet;
  // the chat has a row here
  final bool known;

  // the switch can be used: their phone knows the block, or in a decoy,
  // where it stays on this phone
  bool get peerCan => quiet || can > 0;
  // what this phone does now. someone blocked holds nothing
  bool get blocking => on && peerCan && !blocked;

  ShotsWord get word => ShotsWord(on: on, at: at);
}

/// a message a chat keeps to itself: the other person's, in a chat that
/// blocks. it is not copied, forwarded, shared, saved or opened in another
/// app. this phone's own are its own
bool shotsKeeps({required bool blocking, required bool mine}) =>
    blocking && !mine;

/// [w] takes the place of the state held as ([on], [at])
bool shotsWins(ShotsWord w, {required bool on, required int at}) =>
    w.at > 0 && (w.at > at || (w.at == at && w.on && !on));

/// the stamp for a change made now: past every one seen, whatever the
/// clock, and never past what the wire carries
int shotsNextStamp(int at, int now) => min(max(now, at + 1), kShotsStampMost);

/// [w] as this phone takes it: nothing from further ahead than a day
bool shotsInTime(ShotsWord w, int now) =>
    w.at <= now + kShotsAheadMost.inMilliseconds;

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

const _prefix = 'halo/1:';

/// the body of a 1:1 envelope, or null for a group's frame and anything
/// that is no envelope: those go as they are
Map<String, dynamic>? shotsBodyOf(String wrapped) {
  if (!wrapped.startsWith(_prefix)) return null;
  final Object? body;
  try {
    body = jsonDecode(wrapped.substring(_prefix.length));
  } catch (_) {
    return null;
  }
  if (body is! Map<String, dynamic> || body.containsKey('g')) return null;
  return body;
}

/// [body] with [word] on it, as the wire takes it
String shotsPut(Map<String, dynamic> body, ShotsWord word) {
  body[kShotsWire] = word.toWire();
  return '$_prefix${jsonEncode(body)}';
}

/// [wrapped] with [word] on it, for a 1:1 chat
String shotsStamped(String wrapped, ShotsWord word) {
  final body = shotsBodyOf(wrapped);
  return body == null ? wrapped : shotsPut(body, word);
}

/// the window's flag as a chat asks for it. on goes at once; off waits
/// until [gap] after the last change, so a phone flipping the block fast
/// cannot flash the window. the last word wins. [now] for this phone's own
/// tap, which goes at once either way
class ShotsPacer {
  ShotsPacer(
    this.apply, {
    this.gap = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final void Function(bool on) apply;
  final Duration gap;
  final DateTime Function() _clock;
  bool _held = false;
  bool _want = false;
  DateTime? _last;
  Timer? _t;

  bool get held => _held;

  void want(bool on, {bool now = false}) {
    _want = on;
    _t?.cancel();
    _t = null;
    if (on == _held) return;
    final last = _last;
    final since = last == null ? gap : _clock().difference(last);
    if (on || now || since >= gap) return _set(on);
    _t = Timer(gap - since, () {
      _t = null;
      _set(_want);
    });
  }

  // the screen goes: the flag with it, at once
  void release() {
    _t?.cancel();
    _t = null;
    _want = false;
    _set(false);
  }

  void _set(bool on) {
    if (on == _held) return;
    _held = on;
    _last = _clock();
    apply(on);
  }
}
