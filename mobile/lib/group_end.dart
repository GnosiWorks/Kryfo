// SPDX-License-Identifier: GPL-3.0-or-later
// a group its admin ended: its messages and media go from every member's
// phone, as a leave takes them, and one line stays in the chat list until
// its person deletes it. nothing for it is taken in again

import 'l10n/l10n.dart';

/// an ended group: when the end came here, and who ended it
typedef GroupEnd = ({int at, String by});

/// the end on a groups row, null while the group runs
GroupEnd? groupEndOf(Map<String, Object?>? row) {
  final at = (row?['ended_at'] as num?)?.toInt();
  if (at == null) return null;
  return (at: at, by: row?['ended_by'] as String? ?? '');
}

/// a group [me] may end: theirs by its admin on record, still running, and
/// no burner room, which ends when its maker leaves
bool mayEndGroup(Map<String, Object?>? row, String me) =>
    row != null &&
    (row['is_admin'] as num?)?.toInt() == 1 &&
    me.isNotEmpty &&
    row['admin_id'] == me &&
    row['room_pub'] == null &&
    groupEndOf(row) == null;

/// the line an ended group shows, in the chat and on its row
String endLine(GroupEnd end, {required String me, required String name}) =>
    end.by == me ? l10n.groupEndedYou : l10n.groupEndedBy(name);

// a member still writing into an ended group is told again no sooner
const kEndAgainGap = 12 * 3600000;
