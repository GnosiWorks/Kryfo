#!/usr/bin/env python3
# discord-style shared pins for groups. pinning multicasts a 'pn' control
# frame; every member's copy pins/unpins the same message. mirror of the
# reaction frame plumbing. run from ~/halo/mobile.
import io

# --- envelope: PinFrame + wire field ---
pe = 'lib/message_envelope.dart'
e = io.open(pe, encoding='utf-8').read()
def repe(old, new):
    global e
    c = e.count(old); assert c == 1, f"env anchor x{c}: {old[:50]!r}"
    e = e.replace(old, new)

repe("""class ReactionFrame {
  final String targetUid; // the msg_uid this reaction applies to
  final String emoji; // '' means remove the reactor's reaction
  const ReactionFrame({required this.targetUid, required this.emoji});
}""",
"""class ReactionFrame {
  final String targetUid; // the msg_uid this reaction applies to
  final String emoji; // '' means remove the reactor's reaction
  const ReactionFrame({required this.targetUid, required this.emoji});
}

class PinFrame {
  final String targetUid;
  final bool pinned;
  const PinFrame({required this.targetUid, required this.pinned});
}""")

repe("""  final ReactionFrame? reaction; // 'r' field — present on reaction control msgs""",
"""  final ReactionFrame? reaction; // 'r' field — present on reaction control msgs
  final PinFrame? pin; // 'pn' field — shared pin/unpin control msgs""")

repe("""    this.groupId,
    this.groupControl,""",
"""    this.pin,
    this.groupId,
    this.groupControl,""")

repe("""  if (reaction != null) {
    body['r'] = {'u': reaction.targetUid, 'e': reaction.emoji};
  }""",
"""  if (reaction != null) {
    body['r'] = {'u': reaction.targetUid, 'e': reaction.emoji};
  }
  if (pin != null) {
    body['pn'] = {'u': pin.targetUid, 'p': pin.pinned ? 1 : 0};
  }""")

repe("""    ReactionFrame? reaction;
    final rRaw = json['r'];
    if (rRaw is Map) {
      reaction = ReactionFrame(
        targetUid: (rRaw['u'] as String?) ?? '',
        emoji: (rRaw['e'] as String?) ?? '',
      );
    }""",
"""    ReactionFrame? reaction;
    final rRaw = json['r'];
    if (rRaw is Map) {
      reaction = ReactionFrame(
        targetUid: (rRaw['u'] as String?) ?? '',
        emoji: (rRaw['e'] as String?) ?? '',
      );
    }
    PinFrame? pin;
    final pnRaw = json['pn'];
    if (pnRaw is Map) {
      pin = PinFrame(
        targetUid: (pnRaw['u'] as String?) ?? '',
        pinned: (pnRaw['p'] as int? ?? 0) == 1,
      );
    }""")

repe("""      reaction: reaction,""",
"""      reaction: reaction,
      pin: pin,""")

# wrapMessage param
repe("""  String? unsend,
  String? fileB64,""",
"""  String? unsend,
  PinFrame? pin,
  String? fileB64,""")

io.open(pe, 'w', encoding='utf-8').write(e)
print('envelope: PinFrame wired')

# --- main.dart: multicast + receiver ---
pm = 'lib/main.dart'
m = io.open(pm, encoding='utf-8').read()
def repm(old, new):
    global m
    c = m.count(old); assert c == 1, f"main anchor x{c}: {old[:50]!r}"
    m = m.replace(old, new)

repm("""  // pairwise reaction multicast for group messages.""",
"""  // discord-style shared pin: everyone in the group sees the same pins.
  Future<void> pinInGroup(
    String groupId,
    String targetMsgUid,
    bool pinned,
  ) async {
    await db.setPinned(targetMsgUid, pinned);
    notifyListeners();
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      pin: PinFrame(targetUid: targetMsgUid, pinned: pinned),
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
  }

  // pairwise reaction multicast for group messages.""")

repm("""    // 2) reaction
    if (env.reaction != null) {""",
"""    // shared pin - every member mirrors it
    if (env.pin != null) {
      await db.setPinned(env.pin!.targetUid, env.pin!.pinned);
      notifyListeners();
      return;
    }
    // 2) reaction
    if (env.reaction != null) {""")

io.open(pm, 'w', encoding='utf-8').write(m)
print('main: pinInGroup + receiver branch')

# --- group screen: toggle goes through the multicast ---
pg = 'lib/screens/group_chat_screen.dart'
g = io.open(pg, encoding='utf-8').read()
old = """    await db.setPinned(m.msgUid!, !m.pinned);
    if (mounted) setState(() => m.pinned = !m.pinned);
  }"""
c = g.count(old); assert c == 1, f"group anchor x{c}"
g = g.replace(old, """    final next = !m.pinned;
    if (mounted) setState(() => m.pinned = next);
    await appState.pinInGroup(widget.groupId, m.msgUid!, next);
  }""")
io.open(pg, 'w', encoding='utf-8').write(g)
print('p19 pin sync ok')
