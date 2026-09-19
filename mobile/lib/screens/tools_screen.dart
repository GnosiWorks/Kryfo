// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/stroke_icon.dart';

// drawn in two passes so the iris can carry its own colour: one amber
// outline, one violet centre. a single StrokeIcon paints every path the
// same, and an eye that is all one colour reads as a symbol rather than
// something looking back.
const _eyeOutline = [
  'M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z',
];
final _eyeIris = [svgCircle(12, 12, 3)];
final _picture = [
  svgRect(3.5, 4.5, 17, 15, 3),
  svgCircle(9, 10, 1.8),
  'M20.5 15.5l-5-5-9 9',
];
const _sparkle = [
  'M12 3l1.8 4.6L18.5 9l-4.7 1.5L12 15l-1.8-4.5L5.5 9l4.7-1.4z',
  'M18.5 15.5l.8 2 2 .7-2 .8-.8 2-.7-2-2-.8 2-.7z',
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
  final VoidCallback? onPickVideo;
  final VoidCallback? onClean;
  final VoidCallback? onQr;
  final VoidCallback? onLock;
  final VoidCallback? onOpenLocked;
  const ToolsScreen({
    super.key,
    this.onPickPhoto,
    this.onPickVideo,
    this.onClean,
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
                  'More tools',
                  style: HaloType.mono(
                    size: 12,
                    weight: FontWeight.w600,
                    color: HaloColors.text,
                    letter: 0.14,
                  ),
                ),
              ),
              _ToolRow(
                icon: _sparkle,
                tint: HaloColors.green,
                tile: HaloColors.green.withValues(alpha: 0.24),
                title: 'Clean a photo or video',
                sub: 'Or share one to Kryfo from your gallery',
                onTap: onClean,
              ),
              _ToolRow(
                icon: _qr,
                tint: HaloColors.violet,
                tile: HaloColors.violet.withValues(alpha: 0.25),
                title: 'Make a private QR code',
                sub: 'Links, Wi-Fi, contacts and more. Made offline',
                onTap: onQr,
              ),
              _ToolRow(
                icon: _lock,
                tint: HaloColors.amber,
                tile: HaloColors.amber.withValues(alpha: 0.26),
                title: 'Lock a file',
                sub: 'With a password. Opens anywhere with age',
                onTap: onLock,
              ),
              _ToolRow(
                icon: _unlock,
                tint: HaloColors.warm,
                tile: HaloColors.surface3,
                title: 'Open a locked file',
                sub: 'Any .age file someone sent you',
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
                  'Works offline · no contacts needed',
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
            'Useful from',
            style: HaloType.serif(
              size: 31,
              color: HaloColors.text,
            ).copyWith(letterSpacing: -0.62, height: 1.05),
          ),
          Text(
            'the first minute.',
            style:
                HaloType.serif(
                  size: 31,
                  italic: true,
                  color: HaloColors.amber,
                ).copyWith(
                  letterSpacing: -0.62,
                  height: 1.1,
                  fontWeight: FontWeight.w300,
                ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Text(
              'Everything here happens on this phone. Nothing is uploaded, '
              'and nobody else has to be on Kryfo.',
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
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

class _PhotoCard extends StatelessWidget {
  final VoidCallback? onPhoto;
  final VoidCallback? onVideo;
  const _PhotoCard({required this.onPhoto, required this.onVideo});

  @override
  Widget build(BuildContext context) {
    const ink = HaloColors.amberInk;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HaloColors.amberBright, HaloColors.amberBrightDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: HaloColors.amberBright.withValues(alpha: 0.28),
            blurRadius: 26,
            spreadRadius: -12,
            offset: const Offset(0, 14),
          ),
        ],
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
                  color: ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    StrokeIcon(
                      _eyeOutline,
                      size: 21,
                      color: HaloColors.amberBright,
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
                      'What does this photo know?',
                      style: HaloType.sans(
                        size: 15.5,
                        weight: FontWeight.w600,
                        color: ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Place · phone · time',
                      style: HaloType.mono(
                        size: 10,
                        color: ink.withValues(alpha: 0.7),
                        letter: 0.14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pick a photo and see what it gives away. Then keep a clean copy.',
            style: HaloType.sans(size: 13, color: ink, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  label: 'Pick a photo',
                  icon: _picture,
                  filled: true,
                  onTap: onPhoto,
                ),
              ),
              const SizedBox(width: 8),
              _CardButton(label: 'Video', filled: false, onTap: onVideo),
            ],
          ),
        ],
      ),
    );
  }
}

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
    const ink = HaloColors.amberInk;
    final fg = filled ? HaloColors.amberBright : ink;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: filled ? 0 : 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? ink : null,
            borderRadius: BorderRadius.circular(12),
            border: filled
                ? null
                : Border.all(color: ink.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                StrokeIcon(icon!, size: 17, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: HaloType.sans(
                  size: 13.5,
                  weight: filled ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final side = BorderSide(color: HaloColors.line2, width: 0.5);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$title. $sub',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            border: Border(top: side, bottom: last ? side : BorderSide.none),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  // a little depth: the tile lifts towards its own tint at
                  // the top left and keeps a hairline of it all round, so
                  // the row reads as a thing to press rather than a flat
                  // square sitting on the background.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(tint.withValues(alpha: 0.10), tile),
                      tile,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tint.withValues(alpha: 0.22),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: StrokeIcon(icon, size: 22, color: tint, stroke: 1.9),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: HaloType.sans(
                        size: 15,
                        weight: FontWeight.w600,
                        color: HaloColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: HaloType.sans(size: 12.5, color: HaloColors.warm),
                    ),
                  ],
                ),
              ),
              Container(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
