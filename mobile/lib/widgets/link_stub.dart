// SPDX-License-Identifier: GPL-3.0-or-later
// the line under a bubble that holds a link: the bare domain, and either
// the title the reader asked for or the offer to ask. previews are off; a
// tap is consent to one request for the page's title, over the current
// route. nothing is fetched on its own, and no image ever is.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../link_preview.dart';
import '../theme.dart';
import 'halo_sheet.dart';
import 'sheet_handle.dart';

// said once per run, on the first ask
bool _toldThisRun = false;

Future<bool> askLinkPreviewConsent(BuildContext context) async {
  if (_toldThisRun) return true;
  final ok = await showHaloSheet<bool>(
    context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text(
              'preview this link?',
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              'previews are off. tapping one asks that website for its title, '
              'and it will see you did.',
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  'ask for the title',
                  style: HaloType.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: HaloColors.onAmber,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    'not now',
                    style: HaloType.sans(size: 13, color: HaloColors.text2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (ok == true) _toldThisRun = true;
  return ok == true;
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
