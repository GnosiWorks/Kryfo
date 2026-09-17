// SPDX-License-Identifier: GPL-3.0-or-later
// message text that knows a kryfo link when it holds one.
//
// a room link sent to a contact arrived as two hundred characters of plain
// text that nothing could be done with: not tapped, and copied only along
// with the rest of the message, which the paste box then refused. a message
// that is a room link and nothing else is drawn as an invitation with a
// button. a link among other words is drawn short and can be tapped.
// nothing new goes over the wire: it is the same text either way, and an
// older kryfo shows it as the text it is.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show handleHaloUri, parseHaloUri;
import '../rooms.dart';
import '../theme.dart';
import 'confirm_sheet.dart';

/// takes a tapped link through the one door every link goes through, and
/// says what came of it. a room opens itself once joined.
Future<void> followKryfoLink(BuildContext context, String link) async {
  final room = RoomLink.parse(link);
  if (room == null) {
    final who = parseHaloUri(link)?['id'];
    if (who == null) {
      showHaloToast(context, 'That link is not one kryfo can read');
      return;
    }
    final ok = await showConfirmSheet(
      context,
      title: 'Add $who?',
      line:
          'This is an invite to talk to $who. Add them only if you know '
          'where the link came from.',
      yes: 'Add them',
      keep: 'Not now',
      rose: false,
    );
    if (!ok || !context.mounted) return;
  }
  HapticFeedback.selectionClick();
  final r = await handleHaloUri(link);
  if (context.mounted) showHaloToast(context, r);
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
    if (room != null) return 'Join ${room.name}';
    final who = parseHaloUri(link)?['id'];
    return who == null ? 'kryfo link' : 'Add $who';
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (!text.contains('kryfo://')) return Text(text, style: widget.style);
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
    return Text.rich(TextSpan(style: widget.style, children: spans));
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
            'BURNER ROOM',
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
              'This room has closed',
              style: HaloType.sans(size: 12.5, color: sub),
            )
          else
            // said once, in the bubble's own colour: the ticking countdown
            // picks its tone from the theme and vanishes on an amber bubble
            Text(
              'Closes in ${countdownLabel(DateTime.fromMillisecondsSinceEpoch(room.expiresAt).difference(DateTime.now()))}'
              '${room.cap != null ? ' · up to ${room.cap}' : ''}',
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
                  'Join',
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
              'You join under a key made for this room. Nobody in it sees '
              'your kryfo id.',
              style: HaloType.sans(size: 11.5, color: sub, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
