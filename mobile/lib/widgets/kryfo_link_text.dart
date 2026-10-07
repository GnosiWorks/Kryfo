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
import '../main.dart' show LinkKin, handleHaloUri, linkKinOf, parseHaloUri;
import '../rooms.dart';
import '../theme.dart';
import 'confirm_sheet.dart';
import '../l10n/l10n.dart';

/// takes a tapped link through the one door every link goes through, and
/// says what came of it. a room opens itself once joined.
Future<void> followKryfoLink(BuildContext context, String link) async {
  final room = RoomLink.parse(link);
  if (room == null) {
    final who = parseHaloUri(link)?['id'];
    if (who == null) {
      showHaloToast(context, l10n.kryfoLinkTextThatLinkIsNot);
      return;
    }
    if (!await _askAdd(context, who) || !context.mounted) return;
  }
  HapticFeedback.selectionClick();
  final r = await handleHaloUri(link);
  if (context.mounted) showHaloToast(context, r);
}

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
/// held up against the people here first ([kin]). what it came to, or null
/// when they said no
Future<String?> takeOutsideLink(
  BuildContext context,
  String raw, {
  String? selfId,
  LockGuard? guard,
  Future<String> Function(String link) act = handleHaloUri,
  Future<(LinkKin, String)> Function(String link) kin = linkKinOf,
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
  if (room != null) {
    // a closed room joins nothing: the door only says so
    ok =
        room.expiresAt <= DateTime.now().millisecondsSinceEpoch ||
        await showConfirmSheet(
          context,
          title: l10n.kryfoLinkTextJoinRoom(room.name),
          line: l10n.kryfoLinkTextThisIsARoom,
          yes: l10n.kryfoLinkTextJoin2,
          keep: l10n.kryfoLinkTextNotNow,
          rose: false,
          shutOnLock: g,
          titleLines: 2,
        );
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
        // the words of someone here on another key: never shown as them,
        // and the door would turn it away
        await showNoticeSheet(
          context,
          title: l10n.kryfoLinkTextNotTheOne(unmarked(name)),
          line: l10n.appLinkOtherKey(who!),
          ok: l10n.appOk,
          shutOnLock: g,
          titleLines: 2,
        );
        return null;
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
  HapticFeedback.selectionClick();
  return act(link);
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
  Widget build(BuildContext context) {
    final fg = onAmber ? HaloColors.onAmber : HaloColors.text;
    final sub = onAmber ? HaloColors.onAmber : HaloColors.text2;
    final closed = room.expiresAt <= DateTime.now().millisecondsSinceEpoch;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.kryfoLinkTextBurnerRoom,
            style: HaloType.mono(size: 9.5, color: sub, letter: 0.9),
          ),
          const SizedBox(height: 3),
          Text(
            room.name,
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
                    color: onAmber ? HaloColors.amber : HaloColors.onAmber,
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
