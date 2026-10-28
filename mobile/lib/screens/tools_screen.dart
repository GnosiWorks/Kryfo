// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/stroke_icon.dart';
import '../l10n/l10n.dart';

// the eye is drawn in two passes so the iris can carry its own colour: a
// single StrokeIcon paints every path the same
const _eyeOutline = [
  'M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z',
];
final _eyeIris = [svgCircle(12, 12, 3)];
final _picture = [
  svgRect(3.5, 4.5, 17, 15, 3),
  svgCircle(9, 10, 1.8),
  'M20.5 15.5l-5-5-9 9',
];
final _qr = [
  svgRect(4, 4, 6, 6, 1.2),
  svgRect(14, 4, 6, 6, 1.2),
  svgRect(4, 14, 6, 6, 1.2),
  'M14 14h2.5v2.5H14zM17.5 17.5H20V20h-2.5zM14 19.5h1M19.5 14v1',
];
final _lock = [
  svgRect(5, 10.5, 14, 10, 2.5),
  'M8 10.5V8a4 4 0 0 1 8 0v2.5',
  'M12 14.5v2.2',
];
final _unlock = [svgRect(5, 10.5, 14, 10, 2.5), 'M8 10.5V8a4 4 0 0 1 7.6-1.7'];
const _chevron = ['M9 5l7 7-7 7'];

class ToolsScreen extends StatelessWidget {
  final VoidCallback? onPickPhoto;
  // a video is read and cleaned the same way: one tool for both
  final VoidCallback? onPickVideo;
  final VoidCallback? onQr;
  final VoidCallback? onLock;
  final VoidCallback? onOpenLocked;
  const ToolsScreen({
    super.key,
    this.onPickPhoto,
    this.onPickVideo,
    this.onQr,
    this.onLock,
    this.onOpenLocked,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HaloColors.surface,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggerAll([
              const _Head(),
              _PhotoCard(onPhoto: onPickPhoto, onVideo: onPickVideo),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                child: Text(
                  l10n.toolsMoreTools,
                  style: HaloType.mono(
                    size: 12,
                    weight: FontWeight.w600,
                    color: HaloColors.text,
                    letter: 0.14,
                  ),
                ),
              ),
              _ToolRow(
                icon: _qr,
                tint: HaloColors.violet,
                tile: HaloColors.violet.withValues(alpha: 0.25),
                title: l10n.toolsMakeAPrivateQr,
                sub: l10n.toolsLinksWiFiContacts,
                onTap: onQr,
              ),
              _ToolRow(
                icon: _lock,
                tint: HaloColors.amber,
                tile: HaloColors.amber.withValues(alpha: 0.26),
                title: l10n.toolsLockAFile,
                sub: l10n.toolsWithAPasswordOpens,
                onTap: onLock,
              ),
              _ToolRow(
                icon: _unlock,
                tint: HaloColors.warm,
                tile: HaloColors.surface3,
                title: l10n.toolsOpenALockedFile,
                sub: l10n.toolsAnyAgeFileSomeone,
                onTap: onOpenLocked,
                last: true,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _BreathingDot(),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.toolsWorksOfflineNoContacts,
                  style: HaloType.mono(
                    size: 10.5,
                    color: HaloColors.green,
                    letter: 0.14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.toolsUsefulFrom,
            style: HaloType.serif(
              size: 31,
              color: HaloColors.text,
            ).copyWith(letterSpacing: track(-0.62), height: 1.05),
          ),
          Text(
            l10n.toolsTheFirstMinute,
            style:
                HaloType.serif(
                  size: 31,
                  italic: true,
                  color: HaloColors.amberText,
                ).copyWith(
                  letterSpacing: track(-0.62),
                  height: 1.1,
                  fontWeight: FontWeight.w300,
                ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Text(
              l10n.toolsEverythingHereHappensOn,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.warm,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreathingDot extends StatefulWidget {
  const _BreathingDot();
  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool _breathed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.stop();
      _c.value = 0;
    } else if (!_breathed) {
      // two pulses as the tab opens, then it stays lit
      _breathed = true;
      _c.repeat(reverse: true, count: 4);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 1.0,
        end: 0.35,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: HaloColors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// the photo cleaner leads the tab in the tools' own colours: a soft wash of
// the accent and its hairline, so it sits calmly with the rows under it in
// either theme
class _PhotoCard extends StatelessWidget {
  final VoidCallback? onPhoto;
  final VoidCallback? onVideo;
  const _PhotoCard({required this.onPhoto, required this.onVideo});

  @override
  Widget build(BuildContext context) {
    final tint = HaloColors.amber;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [photoCardWash(0.10), photoCardWash(0.04)],
        ),
        border: Border.all(color: tint.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tint.withValues(alpha: 0.22),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    StrokeIcon(
                      _eyeOutline,
                      size: 21,
                      color: HaloColors.amberText,
                    ),
                    StrokeIcon(
                      _eyeIris,
                      size: 21,
                      stroke: 2.4,
                      color: HaloColors.violet,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.toolsPhotoCleaner,
                      style: HaloType.sans(
                        size: 15.5,
                        weight: FontWeight.w600,
                        color: HaloColors.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.toolsRemovesHiddenInfo,
                      style: HaloType.sans(
                        size: 12.5,
                        color: HaloColors.warm,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.toolsPickAPhotoAnd,
            style: HaloType.sans(size: 13, color: HaloColors.text, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CardButton(
                  label: l10n.toolsPickAPhoto,
                  icon: _picture,
                  filled: true,
                  onTap: onPhoto,
                ),
              ),
              const SizedBox(width: 8),
              // as wide as its word, and a long word wraps before the main
              // button is squeezed
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: _CardButton(
                  label: l10n.toolsVideo,
                  filled: false,
                  onTap: onVideo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// the card's ground: the accent washed over the raised surface
@visibleForTesting
Color photoCardWash(double alpha) => Color.alphaBlend(
  HaloColors.amber.withValues(alpha: alpha),
  HaloColors.surface2,
);

/// what the main button wears over the card: a deeper wash of the same
/// accent, never a solid block
@visibleForTesting
Color photoButtonFill() => HaloColors.amber.withValues(alpha: 0.16);

class _CardButton extends StatelessWidget {
  final String label;
  final List<String>? icon;
  final bool filled;
  final VoidCallback? onTap;
  const _CardButton({
    required this.label,
    this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.96,
        onTap: onTap,
        child: Container(
          // large text takes a second line, never "…"
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: filled ? photoButtonFill() : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled
                  ? HaloColors.amber.withValues(alpha: 0.30)
                  : HaloColors.line2,
              width: filled ? 0.8 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                StrokeIcon(icon!, size: 17, color: HaloColors.amberText),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(
                    size: 13.5,
                    weight: filled ? FontWeight.w600 : FontWeight.w500,
                    color: HaloColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolRow extends StatefulWidget {
  final List<String> icon;
  final Color tint;
  final Color tile;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final bool last;
  const _ToolRow({
    required this.icon,
    required this.tint,
    required this.tile,
    required this.title,
    required this.sub,
    required this.onTap,
    this.last = false,
  });

  @override
  State<_ToolRow> createState() => _ToolRowState();
}

// pressed, the row takes its tool's colour, the tile dips and the chevron
// leans the way the tool opens. let go, the tile springs back
class _ToolRowState extends State<_ToolRow> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final down = _down && !still;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final side = BorderSide(color: HaloColors.line2, width: 0.5);
    return Semantics(
      button: true,
      enabled: w.onTap != null,
      label: '${w.title}. ${w.sub}',
      onTap: w.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: w.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                w.onTap!();
              },
        child: AnimatedContainer(
          duration: Duration(milliseconds: _down ? 60 : 260),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: w.tint.withValues(alpha: _down ? 0.07 : 0),
            border: Border(top: side, bottom: w.last ? side : BorderSide.none),
          ),
          child: Row(
            children: [
              AnimatedScale(
                scale: down ? 0.92 : 1,
                duration: Duration(milliseconds: down ? 90 : 320),
                curve: down ? Curves.easeOut : Curves.easeOutBack,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    // the tile lifts towards its own tint at the top left, so
                    // it reads as a thing to press
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.alphaBlend(
                          w.tint.withValues(alpha: 0.10),
                          w.tile,
                        ),
                        w.tile,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: w.tint.withValues(alpha: 0.22),
                      width: 0.8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: StrokeIcon(
                    w.icon,
                    size: 22,
                    color: w.tint,
                    stroke: 1.9,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.title,
                      style: HaloType.sans(
                        size: 15,
                        weight: FontWeight.w600,
                        color: HaloColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      w.sub,
                      style: HaloType.sans(size: 12.5, color: HaloColors.warm),
                    ),
                  ],
                ),
              ),
              AnimatedSlide(
                offset: Offset(down ? (rtl ? -0.12 : 0.12) : 0, 0),
                duration: Duration(milliseconds: down ? 90 : 320),
                curve: down ? Curves.easeOut : Curves.easeOutBack,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(color: HaloColors.line2, width: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: StrokeIcon(
                    _chevron,
                    size: 14,
                    color: HaloColors.text,
                    stroke: 1.9,
                    pointing: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
