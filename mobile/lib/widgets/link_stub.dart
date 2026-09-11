// SPDX-License-Identifier: GPL-3.0-or-later
// the line under a bubble that holds a link: the bare domain, and either
// the page title or the offer to fetch it. a title is one request for the
// page over the current route, and no image is ever loaded. whether that
// happens on its own or on a tap is the reader's one-time choice.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../link_prefs.dart';
import '../link_preview.dart';
import '../theme.dart';
import 'confirm_sheet.dart';

// the first tap on a link asks once how previews should work from now on.
// after that the answer is kept and settings can change it. returns the
// mode in force, or null when the sheet was dismissed without choosing.
Future<LinkPreviewMode?> decideLinkPreviews(BuildContext context) async {
  final known = linkPreviewMode ?? await loadLinkPreviewMode();
  if (known != null) return known;
  if (!context.mounted) return null;
  final pick = await showChoiceSheet<LinkPreviewMode>(
    context,
    title: 'show link previews?',
    line:
        'a preview puts the page title under the link. kryfo asks the '
        'website for it, the way a browser would. you choose once, and '
        'settings can change it later.',
    choices: const [
      SheetChoice(
        LinkPreviewMode.auto,
        'show them',
        hint: 'titles appear on their own',
      ),
      SheetChoice(
        LinkPreviewMode.onTap,
        'only when i tap',
        hint: 'a link stays plain until you ask',
      ),
      SheetChoice(
        LinkPreviewMode.off,
        'not at all',
        hint: 'links stay plain text',
      ),
    ],
  );
  if (pick == null) return null;
  await saveLinkPreviewMode(pick);
  return pick;
}

class LinkStub extends StatelessWidget {
  final String url;
  final String? title;
  final bool busy;
  // null means no offer: the sender is not an accepted contact
  final VoidCallback? onAsk;
  final bool isOut;
  const LinkStub({
    super.key,
    required this.url,
    required this.isOut,
    this.title,
    this.busy = false,
    this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isOut ? HaloColors.onAmber : HaloColors.text;
    final soft = isOut
        ? HaloColors.onAmber.withValues(alpha: 0.75)
        : HaloColors.text2;
    final t = title;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: (isOut ? HaloColors.onAmber : HaloColors.text).withValues(
          alpha: 0.07,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // the domain row opens the link, which is the reader's own doing
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              HapticFeedback.selectionClick();
              final u = Uri.tryParse(url);
              if (u != null && await canLaunchUrl(u)) {
                await launchUrl(u, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              children: [
                Icon(Icons.link, size: 12, color: soft),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    domainOf(url),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.mono(size: 10.5, color: soft, letter: 0.02),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: t != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      t,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: fg,
                        height: 1.3,
                      ),
                    ),
                  )
                : onAsk == null
                ? const SizedBox(width: double.infinity)
                : GestureDetector(
                    onTap: busy
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onAsk!();
                          },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        busy ? 'asking…' : 'preview this link',
                        style: HaloType.mono(
                          size: 10.5,
                          color: isOut ? fg : HaloColors.amber,
                          weight: FontWeight.w600,
                          letter: 0.04,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
