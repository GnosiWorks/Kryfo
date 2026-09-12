// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../link_preview.dart' show domainOf;
import '../theme.dart';
import 'press_scale.dart';

// the sender's consent, above the composer: a link in the text offers
// "add preview"; tapping it fetches the page title over tor on this phone
// and shows what will ride inside the message. nothing happens on its own.
class PreviewStrip extends StatelessWidget {
  final String? url;
  final Map<String, String>? pending;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onDrop;
  const PreviewStrip({
    super.key,
    required this.url,
    required this.pending,
    required this.busy,
    required this.onAdd,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final p = pending;
    final show = p != null || url != null;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: p != null
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                      decoration: BoxDecoration(
                        color: HaloColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: HaloColors.line, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link, size: 14, color: HaloColors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['title'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HaloType.sans(
                                    size: 12.5,
                                    weight: FontWeight.w600,
                                    color: HaloColors.text,
                                  ),
                                ),
                                Text(
                                  '${domainOf(p['url'] ?? '')} · fetched over tor',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HaloType.mono(
                                    size: 9.5,
                                    color: HaloColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PressScale(
                            label: 'Drop the preview',
                            onTap: onDrop,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: HaloColors.text2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: PressScale(
                        label: 'Add preview',
                        onTap: busy ? null : onAdd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: HaloColors.amberSoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: HaloColors.amber.withValues(alpha: 0.35),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                busy ? Icons.hourglass_top_rounded : Icons.link,
                                size: 13,
                                color: HaloColors.amber,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                busy ? 'Fetching over tor…' : 'Add preview',
                                style: HaloType.mono(
                                  size: 10.5,
                                  color: HaloColors.amber,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
    );
  }
}
