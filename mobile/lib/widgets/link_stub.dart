// SPDX-License-Identifier: GPL-3.0-or-later
// the line under a bubble that holds a link: the bare domain, and the page
// title when the sender fetched one over tor and shipped it inside the
// message. the reader's phone never asks the network for anything here.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../link_preview.dart';
import '../theme.dart';

class LinkStub extends StatelessWidget {
  final String url;
  final String? title;
  final bool isOut;
  // the title came inside the message, fetched by the sender over tor
  final bool bySender;
  const LinkStub({
    super.key,
    required this.url,
    required this.isOut,
    this.title,
    this.bySender = false,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
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
                        if (bySender) ...[
                          const SizedBox(height: 3),
                          Text(
                            isOut
                                ? 'fetched over tor · by your device'
                                : 'fetched over tor · by their device',
                            style: HaloType.mono(
                              size: 9.5,
                              color: isOut
                                  ? HaloColors.onAmber.withValues(alpha: 0.7)
                                  : HaloColors.text3,
                              letter: 0.02,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
