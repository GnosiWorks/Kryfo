// SPDX-License-Identifier: GPL-3.0-or-later
// a group's screenshot block. one state per group, set by its admin alone:
// on or off, whether every member's Kryfo can block, and the stamp it was
// set at, with the same stamp rules as a 1:1 chat (chat_shots.dart). an
// updated phone blocks as soon as it is on; the group says it is on for
// everyone only once every member's app can (caps.dart). rooms always block
import 'caps.dart';
import 'chat_shots.dart';
import 'group_end.dart';

/// the state next to the admin's roster, on its messages and a create
const kGroupShotsWire = 'gs';

/// the admin's words for versions that cannot block in groups. they show
/// it as a message, this version never keeps it
const kGroupNudgeWire = 'gu';

// the line a group shows where its block last changed
const kGroupLineNone = 0;
// turned on, every member can
const kGroupLineOn = 1;
// turned on, waiting for someone
const kGroupLineOnWait = 2;
// the last one waited for can now
const kGroupLineStarted = 3;
// someone who cannot came in, or went back to an older app
const kGroupLinePaused = 4;
const kGroupLineOff = 5;

const _kStampWidth = 13;
final _stampShape = RegExp(r'^\d{13}$');

/// the state as the wire carries it: the same width whatever it says
class GroupShotsWord {
  const GroupShotsWord({required this.on, required this.all, required this.at});
  final bool on;
  final bool all;
  final int at;

  Map<String, Object> toWire() => {
    'o': on ? 1 : 0,
    'e': all ? 1 : 0,
    'a': at.clamp(0, kShotsStampMost).toString().padLeft(_kStampWidth, '0'),
  };

  static GroupShotsWord? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final o = raw['o'];
    final e = raw['e'];
    final a = raw['a'];
    if (o is! int || (o != 0 && o != 1)) return null;
    if (e is! int || (e != 0 && e != 1)) return null;
    if (a is! String || !_stampShape.hasMatch(a)) return null;
    return GroupShotsWord(on: o == 1, all: e == 1, at: int.parse(a));
  }

  @override
  bool operator ==(Object other) =>
      other is GroupShotsWord &&
      other.on == on &&
      other.all == all &&
      other.at == at;

  @override
  int get hashCode => Object.hash(on, all, at);
}

/// a group's block as its row keeps it
class GroupShots {
  const GroupShots({
    this.on = false,
    this.all = false,
    this.at = 0,
    this.by = kShotsByNone,
    this.when = 0,
    this.line = kGroupLineNone,
    this.told = 0,
    this.room = false,
    this.ended = false,
    this.quiet = false,
    this.known = false,
  });

  /// [quiet]: a decoy's group, which keeps its switch here alone
  factory GroupShots.ofRow(Map<String, Object?>? r, {bool quiet = false}) {
    int n(String k) => (r?[k] as num?)?.toInt() ?? 0;
    return GroupShots(
      on: n('shots_on') == 1,
      all: n('shots_all') == 1,
      at: n('shots_at'),
      by: n('shots_by'),
      when: n('shots_when'),
      line: n('shots_line'),
      told: n('shots_told'),
      room: r?['room_pub'] != null,
      ended: groupEndOf(r) != null,
      quiet: quiet,
      known: r != null,
    );
  }

  // what the upgrade adds. shots_told: the newest stamp this member's
  // phone answered with its bits, 1 once it said them after an update
  static const columns = [
    'shots_on',
    'shots_at',
    'shots_all',
    'shots_by',
    'shots_when',
    'shots_line',
    'shots_told',
  ];

  final bool on;
  final bool all;
  final int at;
  final int by;
  // when the last change was made or came, by this clock: where its line
  // sits in the chat
  final int when;
  final int line;
  final int told;
  final bool room;
  final bool ended;
  final bool quiet;
  final bool known;

  /// every member's phone blocks: what the header and the rows may say
  bool get forAll => on && (all || quiet);

  /// on, and someone's app cannot yet
  bool get waiting => on && !forAll;

  /// what this phone does now: a room always, a group once it is on
  bool get blocking => known && !ended && (room || on);

  GroupShotsWord get word => GroupShotsWord(on: on, all: all, at: at);
}

/// [me] may turn it: the admin on record, still in it, while it runs, and
/// no room, which always blocks
bool mayTurnGroupShots(
  Map<String, Object?>? row,
  String me,
  List<String> members,
) => mayEndGroup(row, me) && members.contains(me);

/// a word from [sender] is the group's: its admin on record who is still a
/// member, in a group that runs and is no room
bool groupShotsFrom(
  String sender,
  Map<String, Object?>? row,
  List<String> members,
) =>
    row != null &&
    row['room_pub'] == null &&
    groupEndOf(row) == null &&
    sender.isNotEmpty &&
    row['admin_id'] == sender &&
    members.contains(sender);

/// the members whose app is not known to block in groups. the admin counts
/// themself and needs no word: a group of the admin alone waits for no one
List<String> groupShotsWaitsFor(
  List<String> members,
  String me,
  Map<String, int> caps,
) => [
  for (final m in members)
    if (m != me && !capsHave(caps[m] ?? 0, kCapGroupShots)) m,
];

bool groupShotsAll(List<String> members, String me, Map<String, int> caps) =>
    groupShotsWaitsFor(members, me, caps).isEmpty;

/// the line after a move from ([wasOn], [wasAll]) to ([on], [all]), or null
/// when the one there stays
int? groupShotsLineAfter({
  required bool wasOn,
  required bool wasAll,
  required bool on,
  required bool all,
}) {
  if (on && !wasOn) return all ? kGroupLineOn : kGroupLineOnWait;
  if (!on && wasOn) return kGroupLineOff;
  if (!on) return null;
  if (all && !wasAll) return kGroupLineStarted;
  if (!all && wasAll) return kGroupLinePaused;
  return null;
}

/// the row after this phone's admin turns it, at [now]
Map<String, Object> groupShotsTurned(
  GroupShots was, {
  required bool on,
  required bool all,
  required int now,
}) {
  final line = groupShotsLineAfter(
    wasOn: was.on,
    wasAll: was.all,
    on: on,
    all: all,
  );
  return {
    'shots_on': on ? 1 : 0,
    'shots_all': on && all ? 1 : 0,
    'shots_at': shotsNextStamp(was.at, now),
    if (line != null) ...{
      'shots_line': line,
      'shots_by': kShotsByMe,
      'shots_when': now,
    },
  };
}

/// the admin's row once who can has changed, or null when nothing moves:
/// off, or the same as before. a new stamp, so every member takes it
Map<String, Object>? groupShotsAllMoved(
  GroupShots was, {
  required bool all,
  required int now,
}) {
  if (!was.on || was.all == all) return null;
  return {
    'shots_all': all ? 1 : 0,
    'shots_at': shotsNextStamp(was.at, now),
    'shots_line': all ? kGroupLineStarted : kGroupLinePaused,
    'shots_when': now,
  };
}

/// the row after a word from the admin, or null when it is not taken: no
/// newer than the one held, or from further ahead than a day
Map<String, Object>? groupShotsTaken(
  GroupShots was,
  GroupShotsWord w, {
  required int now,
}) {
  if (!shotsInTime(ShotsWord(on: w.on, at: w.at), now)) return null;
  final newer =
      w.at > 0 &&
      (w.at > was.at ||
          (w.at == was.at && ((w.on && !was.on) || (w.all && !was.all))));
  if (!newer) return null;
  final line = groupShotsLineAfter(
    wasOn: was.on,
    wasAll: was.all,
    on: w.on,
    all: w.all,
  );
  return {
    'shots_on': w.on ? 1 : 0,
    'shots_all': w.on && w.all ? 1 : 0,
    'shots_at': w.at,
    if (line != null) ...{
      'shots_line': line,
      'shots_by': kShotsByThem,
      'shots_when': now,
    },
  };
}

/// a member's phone owes the admin its bits: the state waits on someone
/// and this phone has not answered that stamp
bool groupShotsOwesCaps(GroupShots s) =>
    !s.room && !s.ended && s.on && !s.all && s.told < s.at;
