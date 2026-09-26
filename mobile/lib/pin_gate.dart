// SPDX-License-Identifier: GPL-3.0-or-later
// who may pin what. a pin frame names a message by uid only and arrives above
// the stranger gate, so it is checked against the row's own chat: in a 1:1
// only the other person, in a group only a member, via a frame for that group.

/// [rowPeer] and [rowGroup] are the target row's own columns; a null
/// [rowPeer] means there is no such row. [frameGroup] is the group id the
/// frame claims, null for a 1:1 frame. [members] is the roster of [rowGroup].
bool pinAllowed({
  required String? rowPeer,
  required String? rowGroup,
  required String sender,
  required String? frameGroup,
  required List<String> members,
}) {
  if (rowPeer == null) return false;
  if (rowGroup == null) {
    // a 1:1 row: both directions are filed under the other person's id
    return frameGroup == null && rowPeer == sender;
  }
  return frameGroup == rowGroup && members.contains(sender);
}
