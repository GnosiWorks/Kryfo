// SPDX-License-Identifier: GPL-3.0-or-later
// group control rows and the group list preview

part of '../main.dart';

// a group take-back waits in a member's control lane as a row of its own
// shape, and goes out as an unsend frame, never as a control
Map<String, String> groupUnsendRow(String uid) => {'un': uid};

String? groupUnsendOf(Object? ctl) {
  if (ctl is! String || !ctl.startsWith('{"un":')) return null;
  try {
    final raw = jsonDecode(ctl);
    final uid = raw is Map ? raw['un'] : null;
    return uid is String && uid.isNotEmpty ? uid : null;
  } catch (_) {
    return null;
  }
}

// a group pin, vote or poll close held by a decoy waits in each member's
// lane as it was sealed for them all, and goes once the decoy is left
Map<String, String> groupWrappedRow(String wrapped) => {'wr': wrapped};

/// a remove of ours in a lane
bool groupRemoveOut(Object? ctl) {
  if (ctl is! String || !ctl.contains('"remove"')) return false;
  try {
    return GroupControl.fromWire(jsonDecode(ctl))?.type == 'remove';
  } catch (_) {
    return false;
  }
}

/// an end of ours in a lane, or its words for older versions: each still
/// goes to the members it was queued for once the group went from here
bool groupEndOut(Object? ctl) {
  final wr = groupWrappedOf(ctl);
  if (wr != null) return unwrapMessage(wr).endNotice;
  if (ctl is! String || !ctl.contains('"end"')) return false;
  try {
    return GroupControl.fromWire(jsonDecode(ctl))?.type == 'end';
  } catch (_) {
    return false;
  }
}

String? groupWrappedOf(Object? ctl) {
  if (ctl is! String || !ctl.startsWith('{"wr":')) return null;
  try {
    final raw = jsonDecode(ctl);
    final w = raw is Map ? raw['wr'] : null;
    return w is String && w.isNotEmpty ? w : null;
  } catch (_) {
    return null;
  }
}

// a group edit or reaction of ours waits in each member's control lane too,
// one of each a message: a newer word replaces the one still waiting
Map<String, String> groupEditRow(String uid, String text) => {
  'ed': uid,
  't': text,
};
Map<String, String> groupReactRow(String uid, String emoji) => {
  're': uid,
  'e': emoji,
};

({String uid, String? edit, String? emoji})? groupFrameOf(Object? ctl) {
  if (ctl is! String) return null;
  if (!ctl.startsWith('{"ed":') && !ctl.startsWith('{"re":')) return null;
  try {
    final raw = jsonDecode(ctl);
    if (raw is! Map) return null;
    final ed = raw['ed'], t = raw['t'], re = raw['re'], e = raw['e'];
    if (ed is String && ed.isNotEmpty && t is String) {
      return (uid: ed, edit: t, emoji: null);
    }
    if (re is String && re.isNotEmpty && e is String) {
      return (uid: re, edit: null, emoji: e);
    }
  } catch (_) {}
  return null;
}

// a group asked to hold more than the cap. its message is read when shown,
// in the language of that moment
class GroupFull implements Exception {
  const GroupFull();
  String get message => l10n.appGroupHoldsUpTo(AppState.kGroupMemberCap);
}

/// a group's controls asked of a linked device. its phone takes no group
/// op from a device, so a rename, add, remove, end, leave or screenshot
/// switch made there would reach the members and never the phone (a leave
/// takes me out for them while the phone stays in): on the phone alone in
/// 0.6, as making a group is
class GroupOnPhone implements Exception {
  const GroupOnPhone();
  String get message => l10n.linkedDoOnPhone;
}

class GroupPreview {
  final String groupId;
  final String name;
  final int memberCount;
  final bool isAdmin;
  final DateTime createdAt;
  final int unread;
  final bool mentioned; // someone wrote your three words since you last read
  final int? expiresAt; // a burner room's end, null for a group
  // a room joined off a link and not let in yet: when the join went
  final int? joiningAt;
  // one of the open vault's: only its session shows it
  final bool hidden;
  // its admin ended it: who, null while it runs
  final String? endedBy;
  // its screenshot block holds on this phone, and on every member's
  final bool shotsBlocking;
  final bool shotsForAll;
  // its last message for the row: what it was in a row's words, whether it
  // was ours, who wrote it (null for ours or a group that blocks), and when
  final String? lastBody;
  final bool lastOut;
  final String? lastFrom;
  final DateTime? lastAt;
  const GroupPreview({
    this.lastBody,
    this.lastOut = false,
    this.lastFrom,
    this.lastAt,
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.isAdmin,
    required this.createdAt,
    this.unread = 0,
    this.mentioned = false,
    this.expiresAt,
    this.joiningAt,
    this.hidden = false,
    this.endedBy,
    this.shotsBlocking = false,
    this.shotsForAll = false,
  });

  bool get ended => endedBy != null;
}
