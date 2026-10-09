// SPDX-License-Identifier: GPL-3.0-or-later
// what a chat shows while nothing has gone to someone just added: they do
// not know about this phone until a first message lands. one tap waves.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../stickers/sticker_pack.dart';
import '../stickers/sticker_view.dart';
import '../theme.dart';
import 'motion.dart';
import 'press_scale.dart';

/// what the wave sends when no pack has a waving sticker
const kWaveEmoji = '👋';

/// the pack's waving sticker, if this version has one that moves
(StickerPack, Sticker)? wavingSticker(StickerLibrary? lib) {
  final pack = lib?.pack('fokia');
  if (pack == null) return null;
  for (final id in pack.playable) {
    final s = pack.sticker(id);
    if (s != null && s.emoji == kWaveEmoji) return (pack, s);
  }
  return null;
}

class SayHiCard extends StatefulWidget {
  const SayHiCard({super.key, required this.sticker, required this.onWave});

  /// the waving sticker, or null for the emoji
  final Sticker? sticker;

  /// where the sticker was drawn and how far into its loop, so it can fly
  /// to its bubble; an empty rect when it was not drawn
  final void Function(Rect from, double at) onWave;

  @override
  State<SayHiCard> createState() => _SayHiCardState();
}

class _SayHiCardState extends State<SayHiCard>
    with SingleTickerProviderStateMixin {
  final _art = GlobalKey();
  late final _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );
  bool _waved = false;

  @override
  void initState() {
    super.initState();
    // once it has risen in, the hand waves once on its own
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted && !_waved && !motionStill(context)) _wiggle.forward();
    });
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _wave() {
    if (_waved) return;
    HapticFeedback.lightImpact();
    if (!motionStill(context)) _wiggle.forward(from: 0);
    final box = drawnSticker(_art.currentContext, widget.sticker);
    final from = box == null
        ? Rect.zero
        : box.localToGlobal(Offset.zero) & box.size;
    // the sticker flies from here, and the card's copy hides: one is seen
    setState(() => _waved = true);
    widget.onWave(from, box?.time ?? -1);
  }

  // a hand that waves from the wrist, settling as it goes
  Widget _waving(Widget child) => AnimatedBuilder(
    animation: _wiggle,
    builder: (_, c) {
      final t = _wiggle.value;
      return Transform.rotate(
        key: const ValueKey('wave-hand'),
        angle: math.sin(t * math.pi * 4) * 0.42 * (1 - t),
        alignment: const Alignment(0.45, 0.75),
        child: c,
      );
    },
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final s = widget.sticker;
    return LayoutBuilder(
      builder: (context, box) {
        // a short room (keyboard up, big text) gets a smaller sticker
        final art = box.maxHeight < 440 ? 88.0 : 120.0;
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: kHouseTime,
            curve: kHouseCurve,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                key: const ValueKey('say-hi-rise'),
                offset: Offset(0, still ? 0 : (1 - t) * 18),
                child: Transform.scale(
                  scale: still ? 1 : 0.94 + 0.06 * t,
                  child: child,
                ),
              ),
            ),
            // scrolls rather than overflows with the keyboard up at a big
            // font
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: HaloColors.line, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: HaloColors.amber.withValues(alpha: 0.08),
                        blurRadius: 32,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _wave,
                            child: SizedBox(
                              key: _art,
                              width: art,
                              height: art,
                              child: s != null
                                  ? Opacity(
                                      opacity: _waved ? 0 : 1,
                                      child: StickerView(
                                        sticker: s,
                                        size: art,
                                        loops: 3,
                                      ),
                                    )
                                  : Center(child: _glow(art)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.chatSayHiSoThey,
                          textAlign: TextAlign.center,
                          style: HaloType.serif(
                            size: 22,
                            weight: FontWeight.w300,
                            italic: true,
                            color: HaloColors.text,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.chatTheyWonTKnow,
                          textAlign: TextAlign.center,
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text2,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _button(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // the emoji in the soft amber glow the empty chats use
  Widget _glow(double art) {
    final d = art * 0.62;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HaloColors.amberSoft,
        border: Border.all(
          color: HaloColors.amber.withValues(alpha: 0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: HaloColors.amber.withValues(alpha: 0.18),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: _waving(
        Text(kWaveEmoji, style: TextStyle(fontSize: d * 0.46, height: 1.1)),
      ),
    );
  }

  Widget _button() => PressScale(
    label: l10n.chatWave,
    onTap: _wave,
    scale: 0.96,
    // the wave has its own, a touch firmer
    haptic: false,
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: HaloColors.amber,
        borderRadius: BorderRadius.circular(13),
      ),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _waving(
              const Text(
                kWaveEmoji,
                style: TextStyle(fontSize: 18, height: 1.2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.chatWave,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: HaloType.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: HaloColors.onAmber,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
