// SPDX-License-Identifier: GPL-3.0-or-later
// where Kryfo's maker posts, near the bottom of settings. each link leaves
// Kryfo, so a tap says so first and opens only on a second yes. nostr goes
// to a nostr app; with none, the address is copied instead
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/brand_glyph.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/halo_rows.dart' show HaloGroup, HaloSection;
import '../widgets/press_scale.dart';

const kGnosiworksNpub =
    'npub1rjnuf23jz8ufngpdd42ufhejf3kul2h8ms7ve2wg7rv0afnsf0dshzuqew';

class _Link {
  const _Link(this.brand, this.name, this.url, this.tint);
  final Brand brand;
  final String name;
  final String url;
  // the brand's own colour, or none where it would vanish on the page
  final Color? tint;
}

const _links = [
  _Link(
    Brand.mastodon,
    'Mastodon',
    'https://mastodon.social/@gnosiworks',
    Color(0xFF6364FF),
  ),
  _Link(Brand.nostr, 'Nostr', 'nostr:$kGnosiworksNpub', Color(0xFF8E30EB)),
  _Link(Brand.x, 'X', 'https://x.com/GnosiWorks', null),
  _Link(
    Brand.instagram,
    'Instagram',
    'https://www.instagram.com/kryfoapp/',
    Color(0xFFFF0069),
  ),
];

class FollowSection extends StatelessWidget {
  const FollowSection({super.key});

  Future<void> _open(BuildContext context, _Link l) async {
    final nostr = l.brand == Brand.nostr;
    final ok = await showConfirmSheet(
      context,
      title: l.name,
      line: nostr
          ? l10n.settingsFollowNostrNote
          : l10n.settingsFollowBrowserNote,
      yes: l10n.settingsFollowOpen,
      keep: l10n.commonCancel,
      rose: false,
    );
    if (!ok || !context.mounted) return;
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(l.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !nostr || !context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: kGnosiworksNpub));
    if (context.mounted) showHaloToast(context, l10n.settingsFollowNpubCopied);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HaloSection(l10n.settingsFollowTitle),
        HaloGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
              child: Row(
                children: [
                  for (final l in _links)
                    Expanded(
                      child: PressScale(
                        label: l10n.settingsFollowOn(l.name),
                        onTap: () => _open(context, l),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: (l.tint ?? HaloColors.text).withValues(
                                  alpha: 0.10,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: (l.tint ?? HaloColors.text).withValues(
                                    alpha: 0.28,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: BrandGlyph(
                                l.brand,
                                size: 23,
                                color: l.tint ?? HaloColors.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.sans(
                                size: 12,
                                color: HaloColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
