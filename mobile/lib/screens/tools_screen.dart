// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/stroke_icon.dart';

final _eye = [
  'M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z',
  svgCircle(12, 12, 3),
];
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
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                child: Text(
                  'More tools',
                  style: HaloType.mono(
                    size: 10,
                    color: HaloColors.warm,
                    letter: 0.14,
                  ),
                ),
              ),
              _ToolRow(
                icon: _sparkle,
                tint: HaloColors.green,
                tile: HaloColors.green.withValues(alpha: 0.12),
                title: 'Clean a photo or video',
                sub: 'Or share one to Kryfo from your gallery',
                onTap: onClean,
              ),
              _ToolRow(
                icon: _qr,
                tint: HaloColors.violet,
                tile: HaloColors.violet.withValues(alpha: 0.13),
                title: 'Make a private QR code',
                sub: 'Links, Wi-Fi, contacts and more. Made offline',
                onTap: onQr,
              ),
              _ToolRow(
                icon: _lock,
                tint: HaloColors.amber,
                tile: HaloColors.amber.withValues(alpha: 0.14),
                title: 'Lock a file',
                sub: 'With a password. Opens anywhere with age',
                onTap: onLock,
              ),
              _ToolRow(
                icon: _unlock,
                tint: HaloColors.warm,
                tile: HaloColors.surface2,
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
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HaloColors.amberBright, HaloColors.amberBrightDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: HaloColors.amberBright.withValues(alpha: 0.45),
            blurRadius: 30,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: StrokeIcon(
                  _eye,
                  size: 22,
                  color: HaloColors.amberBright,
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
                        size: 16,
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
          const SizedBox(height: 12),
          Text(
            'Pick a photo and see what it gives away. Then keep a clean copy.',
            style: HaloType.sans(size: 13, color: ink, height: 1.5),
          ),
          const SizedBox(height: 14),
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
          height: 44,
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
    final side = BorderSide(color: HaloColors.line, width: 0.5);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$title. $sub',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: side, bottom: last ? side : BorderSide.none),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: StrokeIcon(icon, size: 21, color: tint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: HaloColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: HaloType.sans(size: 12, color: HaloColors.warm),
                    ),
                  ],
                ),
              ),
              StrokeIcon(_chevron, size: 16, color: HaloColors.warm),
            ],
          ),
        ),
      ),
    );
  }
}
