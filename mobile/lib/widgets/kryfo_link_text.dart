// SPDX-License-Identifier: GPL-3.0-or-later
// message text that knows a kryfo link when it holds one. a message that is
// only a room link is drawn as an invitation with a button; a link among
// other words is drawn short and can be tapped. the text on the wire is the
// same, so an older kryfo shows it as plain text.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bidi_safe.dart';
import '../lock_guard.dart';
import '../main.dart'
    show
        LinkKin,
        appState,
        handleHaloUri,
        linkKinOf,
        parseHaloUri,
        rootNavKey,
        session;
import '../rooms.dart';
import '../screens/room_preview_sheet.dart';
import '../theme.dart';
import 'confirm_sheet.dart';
import '../l10n/l10n.dart';

/// takes a tapped link through the one door every link goes through, and
/// says what came of it. a room shows what its link says first and opens
/// itself once joined. an invite is held up against the people here first,
/// as one from outside is
Future<void> followKryfoLink(
  BuildContext context,
  String link, {
  LockGuard? guard,
  String? Function()? self,
  Future<String> Function(String link) act = handleHaloUri,
  Future<(LinkKin, String)> Function(String link) kin = linkKinOf,
  Future<bool> Function(String roomId) here = roomHere,
  Future<bool> Function(RoomLink room) movable = roomDoorMovable,
}) async {
  final r = await takeOutsideLink(
    context,
    link,
    selfId: (self ?? _sessionId)(),
    guard: guard,
    act: act,
    kin: kin,
    here: here,
    movable: movable,
  );
  if (r != null && context.mounted) showHaloToast(context, r);
}

String? _sessionId() => appState.sessionId;

/// a room the open session already holds: made here, joined, or still
/// waiting to be let in. read off this phone alone
Future<bool> roomHere(String roomId) async {
  try {
    final g = await session.getGroup(roomId);
    return g != null && g['room_pub'] != null;
  } catch (e) {
    return false;
  }
}

/// a waiting join here whose own door went unanswered or full, and a link
/// to the same room with another door: asked about as a room not here
Future<bool> roomDoorMovable(RoomLink room) async {
  try {
    return await appState.roomDoorMovable(room);
  } catch (e) {
    return false;
  }
}

// whether a room link goes on to the door, and whether on the sheet's join
// to another door. one already here opens as it did, and a join still
// waiting knocks again; a join gone unanswered or full moves to another
// door only on join. anything else shows what its link says and goes only
// on join
Future<(bool, bool)> _roomGoes(
  BuildContext context,
  RoomLink room,
  LockGuard g,
  Future<bool> Function(String roomId) here,
  Future<bool> Function(RoomLink room) movable,
) async {
  final held = await here(room.roomId);
  if (held && !await movable(room)) return (true, false);
  if (!context.mounted || g.isLocked()) return (false, false);
  final ok = await showRoomPreviewSheet(
    context,
    room,
    shutOnLock: g,
    ended: _endedHere(room),
  );
  return (ok, ok && held);
}

// a room this phone made and left: over, whatever its link says
bool _endedHere(RoomLink room) =>
    endedRooms.ended(session.container.id, room.roomId);

Future<bool> _askAdd(
  BuildContext context,
  String who, {
  LockGuard? guard,
  String? line,
}) {
  who = unmarked(who);
  return showConfirmSheet(
    context,
    title: l10n.kryfoLinkTextAdd(who),
    line: line ?? l10n.kryfoLinkTextThisIsAnInvite(who),
    yes: l10n.kryfoLinkTextAddThem,
    keep: l10n.kryfoLinkTextNotNow,
    rose: false,
    shutOnLock: guard,
    titleLines: 2,
  );
}

/// a link from outside the app: another app, a web page, a cold start. any
/// of them can fire one, so nothing is added or joined until the person
/// says yes here, and the question goes if the lock comes up. an invite is
/// held up against the people here first ([kin]), and so is one tapped in
/// a chat. what it came to, or null when they said no
Future<String?> takeOutsideLink(
  BuildContext context,
  String raw, {
  String? selfId,
  LockGuard? guard,
  Future<String> Function(String link) act = handleHaloUri,
  Future<(LinkKin, String)> Function(String link) kin = linkKinOf,
  Future<bool> Function(String roomId) here = roomHere,
  Future<bool> Function(RoomLink room) movable = roomDoorMovable,
}) async {
  // the link alone, as the door reads it, so the question is about what
  // the door then does
  final link = firstKryfoLink(raw.trim());
  final room = link == null ? null : RoomLink.parse(link);
  final who = link == null || room != null ? null : parseHaloUri(link)?['id'];
  if (link == null || (room == null && who == null)) {
    return l10n.kryfoLinkTextThatLinkIsNot;
  }
  final g = guard ?? lockGuard;
  if (g.isLocked()) return null;
  final bool ok;
  var moves = false;
  if (room != null) {
    // what the link says, and nothing sent before join. a closed room
    // has no join
    (ok, moves) = await _roomGoes(context, room, g, here, movable);
  } else if (who == selfId) {
    // one's own invite adds no one: the door only says so
    ok = true;
  } else {
    final (k, name) = await kin(link);
    if (!context.mounted || g.isLocked()) return null;
    switch (k) {
      case LinkKin.kept:
        // their chat is here: the card goes nowhere near the door again
        return l10n.kryfoLinkTextYouAlreadyHave(unmarked(name));
      case LinkKin.otherKey:
      case LinkKin.verified:
        // the words of someone here on another key, verified or checked:
        // the door would turn it away. which of the two is who they say
        // only the safety number tells
        await showNoticeSheet(
          context,
          title: l10n.nameTakenTitle,
          line: k == LinkKin.verified
              ? l10n.appLinkWordsVerified(who!)
              : l10n.appLinkWordsTaken(who!),
          ok: l10n.appOk,
          shutOnLock: g,
          titleLines: 2,
        );
        return null;
      case LinkKin.claimed:
        // the words a request, an introduction or a group gave someone
        // here, never checked: the door asks which one keeps them
        ok = true;
      case LinkKin.lookalike:
        ok = await _askAdd(
          context,
          who!,
          guard: g,
          line: l10n.kryfoLinkTextSomeoneElse(who),
        );
      case LinkKin.stranger:
        ok = await _askAdd(context, who!, guard: g);
    }
  }
  // a no, or the lock came up while it asked
  if (!ok || g.isLocked()) return null;
  if (moves) takenDoors.take(room!);
  HapticFeedback.selectionClick();
  return act(link);
}

/// an invite read with the camera, the way two people add each other side
/// by side: it clears the marks a code or a link leaves. it proves no more
/// than the screen it was read off
Future<String> addScanned(String link) => handleHaloUri(link, scanned: true);

/// the question when a link names someone here whose words a request, an
/// introduction or a group gave, on another key, and nobody checked them:
/// true lets the link have them. [chat]: the other one's chat goes too
Future<bool> askTakeNameSheet(String id, {required bool chat}) async {
  final ctx = rootNavKey.currentContext;
  if (ctx == null || !ctx.mounted || lockGuard.isLocked()) return false;
  return showConfirmSheet(
    ctx,
    title: l10n.nameTakenTitle,
    figure: id,
    line: chat ? l10n.nameTakenChatLine : l10n.nameTakenLine,
    yes: l10n.nameTakenUse,
    keep: l10n.nameTakenKeep,
    // a chat goes with a yes
    rose: chat,
    shutOnLock: lockGuard,
    titleLines: 2,
  );
}

/// a link scanned or pasted here. a room shows what its link says and
/// joins only on join; anything else goes to the door as it was given.
/// null when the room was not joined
Future<String?> takeOwnLink(
  BuildContext context,
  String raw, {
  LockGuard? guard,
  Future<String> Function(String link) act = handleHaloUri,
  Future<bool> Function(String roomId) here = roomHere,
  Future<bool> Function(RoomLink room) movable = roomDoorMovable,
}) async {
  // the same reading the door makes of it
  final link = firstKryfoLink(raw.trim());
  final room = link == null ? null : RoomLink.parse(link);
  if (room == null) return act(raw);
  final g = guard ?? lockGuard;
  if (g.isLocked()) return null;
  final (ok, moves) = await _roomGoes(context, room, g, here, movable);
  if (!ok || g.isLocked()) return null;
  if (moves) takenDoors.take(room);
  HapticFeedback.selectionClick();
  return act(link!);
}

class KryfoLinkText extends StatefulWidget {
  final String text;
  final TextStyle style;
  // on an amber bubble amber does not read; the caller says what does
  final Color linkColor;
  final bool onAmber;
  const KryfoLinkText({
    super.key,
    required this.text,
    required this.style,
    required this.linkColor,
    this.onAmber = false,
  });
  @override
  State<KryfoLinkText> createState() => _KryfoLinkTextState();
}

class _KryfoLinkTextState extends State<KryfoLinkText> {
  final List<TapGestureRecognizer> _taps = [];

  void _drop() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  static String _label(String link) {
    final room = RoomLink.parse(link);
    if (room != null) return l10n.kryfoLinkTextJoin(room.name);
    final who = parseHaloUri(link)?['id'];
    return who == null
        ? l10n.kryfoLinkTextKryfoLink
        : l10n.kryfoLinkTextAdd2(who);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final dir = writtenDir(text);
    if (!text.contains('kryfo://')) {
      return Text(text, style: widget.style, textDirection: dir);
    }
    final only = text.trim();
    final room = RoomLink.parse(only);
    if (room != null && firstKryfoLink(only) == only) {
      return RoomInviteCard(room: room, link: only, onAmber: widget.onAmber);
    }
    _drop();
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in kryfoLinksIn(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      final link = m.group(0)!;
      final tap = TapGestureRecognizer()
        ..onTap = () => followKryfoLink(context, link);
      _taps.add(tap);
      spans.add(
        TextSpan(
          text: _label(link),
          recognizer: tap,
          style: TextStyle(
            color: widget.linkColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
        ),
      );
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      textDirection: dir,
    );
  }
}

/// a room link on its own in a message
class RoomInviteCard extends StatelessWidget {
  final RoomLink room;
  final String link;
  final bool onAmber;
  const RoomInviteCard({
    super.key,
    required this.room,
    required this.link,
    this.onAmber = false,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: endedRooms,
    builder: (context, _) => _card(context),
  );

  Widget _card(BuildContext context) {
    final fg = onAmber ? HaloColors.onAmber : HaloColors.text;
    final sub = onAmber ? HaloColors.onAmber : HaloColors.text2;
    final closed =
        room.expiresAt <= DateTime.now().millisecondsSinceEpoch ||
        _endedHere(room);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.kryfoLinkTextBurnerRoom,
            style: HaloType.mono(size: 9.5, color: sub, letter: 0.3),
          ),
          const SizedBox(height: 3),
          Text(
            room.name,
            textDirection: writtenDir(room.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HaloType.serif(size: 19, color: fg),
          ),
          const SizedBox(height: 4),
          if (closed)
            Text(
              l10n.kryfoLinkTextThisRoomHasClosed,
              style: HaloType.sans(size: 12.5, color: sub),
            )
          else
            // said once, in the bubble's own colour: the ticking countdown
            // picks its tone from the theme and vanishes on an amber bubble
            Text(
              room.cap != null
                  ? l10n.kryfoLinkTextClosesInUpTo(room.cap!, _left(room))
                  : l10n.kryfoLinkTextClosesIn(_left(room)),
              style: HaloType.mono(size: 10, color: sub),
            ),
          if (!closed) ...[
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => followKryfoLink(context, link),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: onAmber ? HaloColors.onAmber : HaloColors.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.kryfoLinkTextJoin2,
                  style: HaloType.sans(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: onAmber ? HaloColors.amberText : HaloColors.onAmber,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.kryfoLinkTextYouJoinUnderA,
              style: HaloType.sans(size: 11.5, color: sub, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

String _left(RoomLink room) => countdownLabel(
  DateTime.fromMillisecondsSinceEpoch(
    room.expiresAt,
  ).difference(DateTime.now()),
);
