// SPDX-License-Identifier: GPL-3.0-or-later
// what gif search does before it is on. settings shows three plain points
// and a choice; the picker asks once in a sentence, then only says it is off.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/marked.dart';
import '../theme.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/stagger_in.dart';
import '../widgets/stroke_icon.dart';

// an onion, ring in ring
final _onionGlyph = [
  svgCircle(12, 12, 9),
  svgCircle(12, 12, 5),
  svgCircle(12, 12, 1.5),
];

Widget _badge(double size) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    color: HaloColors.amberSoft,
    borderRadius: BorderRadius.circular(size * 0.32),
  ),
  alignment: Alignment.center,
  child: ExcludeSemantics(
    child: Text(
      l10n.gifBadge,
      style: HaloType.mono(
        size: size * 0.29,
        color: HaloColors.amberText,
        letter: 1,
      ),
    ),
  ),
);

class GifOptIn extends StatelessWidget {
  const GifOptIn({
    super.key,
    required this.overTor,
    required this.onTurnOn,
    required this.onNotNow,
  });

  // the onion route: the search goes over tor. on the others it goes to
  // our server directly, and the first point says that instead
  final bool overTor;
  final VoidCallback onTurnOn;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final points = [
      _point(
        StrokeIcon(_onionGlyph, size: 18, color: HaloColors.violet),
        HaloColors.violet,
        overTor ? l10n.gifOptInOverTor : l10n.gifOptInThroughKryfo,
        l10n.gifOptInAsksForYou,
      ),
      _point(
        Icon(Icons.lock_outline_rounded, size: 18, color: HaloColors.amber),
        HaloColors.amber,
        l10n.gifSentInside,
        l10n.gifOptInLikeAPhoto,
      ),
      _point(
        Icon(
          Icons.power_settings_new_rounded,
          size: 18,
          color: HaloColors.green,
        ),
        HaloColors.green,
        l10n.gifOptInOffWhenever,
        l10n.gifOptInWhereToTurnOff,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(56),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              l10n.gifOptInTitle,
              style: HaloType.serif(
                size: 26,
                weight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.gifOptInLead,
            style: HaloType.sans(size: 15, color: HaloColors.text2),
          ),
          const SizedBox(height: 22),
          for (final (i, p) in points.indexed)
            StaggerIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: p,
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: HaloPrimaryButton(
              label: l10n.gifTurnOn,
              onTap: () {
                HapticFeedback.lightImpact();
                onTurnOn();
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: HaloGhostButton(
              label: l10n.gifNotNow,
              quiet: true,
              onTap: onNotNow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _point(Widget icon, Color tint, String title, String body) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(child: icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: HaloType.sans(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: HaloType.sans(
                    size: 14,
                    color: HaloColors.text2,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// the picker's one question, the first time the gifs tab opens while off
class GifAsk extends StatelessWidget {
  const GifAsk({
    super.key,
    required this.overTor,
    required this.brand,
    required this.onTurnOn,
    required this.onNotNow,
  });

  // tor is named only on the onion route
  final bool overTor;
  final String brand;
  final VoidCallback onTurnOn;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HaloColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _badge(40),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    overTor
                        ? l10n.gifAskOverTor(brand)
                        : l10n.gifAskThroughKryfo(brand),
                    style: HaloType.sans(size: 15, height: 1.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: HaloGhostButton(
                    label: l10n.gifNotNow,
                    quiet: true,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onNotNow();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HaloPrimaryButton(
                    label: l10n.gifAskTurnOn,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTurnOn();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// the gifs tab while search is off, once it has asked: a line, a quiet
/// way to turn it on, and where the phone's own gifs are
class GifOff extends StatelessWidget {
  const GifOff({super.key, required this.onTurnOn, required this.onPhone});

  final VoidCallback onTurnOn;
  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) {
    final text2 = HaloType.sans(size: 14, color: HaloColors.text2, height: 1.4);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.gifSearchOff,
                  style: HaloType.sans(size: 15, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              PressScale(
                label: l10n.gifAskTurnOn,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTurnOn();
                },
                scale: 0.94,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: HaloColors.line2),
                  ),
                  child: Align(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: ExcludeSemantics(
                      child: Text(
                        l10n.gifAskTurnOn,
                        style: HaloType.sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: HaloColors.amberText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PressScale(
            // the tab change clicks
            onTap: onPhone,
            scale: 0.98,
            haptic: false,
            child: Semantics(
              button: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.photo_library_outlined,
                      size: 18,
                      color: HaloColors.text2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: markedSpans(
                          l10n.gifSavedOnPhone,
                          HaloType.sans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: HaloColors.text,
                          ),
                        ),
                      ),
                      style: text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// the same as a sheet: true when it was turned on
Future<bool> showGifOptInSheet(BuildContext context, {required bool overTor}) {
  HapticFeedback.selectionClick();
  return showHaloSheet<bool>(
    context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHandle(),
        GifOptIn(
          overTor: overTor,
          onTurnOn: () => Navigator.of(ctx).pop(true),
          onNotNow: () => Navigator.of(ctx).pop(false),
        ),
        SizedBox(height: MediaQuery.paddingOf(ctx).bottom),
      ],
    ),
  ).then((v) => v ?? false);
}
