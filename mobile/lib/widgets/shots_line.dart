// SPDX-License-Identifier: GPL-3.0-or-later
// the line a chat shows where its screenshot block last changed, by either
// phone: a quiet pill in the thread, like a day's. it eases in where it
// lands, simply there with less movement
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'motion.dart' show motionStill;

/// what the line says: who changed the block, and to what
String shotsLineText({required bool on, required bool mine, String? name}) {
  if (mine) {
    return on ? l10n.chatShotsYouTurnedOn : l10n.chatShotsYouTurnedOff;
  }
  final who = name ?? '';
  return on
      ? l10n.chatShotsTheyTurnedOn(who)
      : l10n.chatShotsTheyTurnedOff(who);
}

class ShotsLine extends StatelessWidget {
  final String text;
  final bool on;
  const ShotsLine({super.key, required this.text, required this.on});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final pill = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 12, 5),
      decoration: BoxDecoration(
        color: HaloColors.surface2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            on ? Icons.phonelink_lock_outlined : Icons.phonelink_erase_outlined,
            size: 12,
            color: HaloColors.text2,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 11.5,
                color: HaloColors.text2,
                weight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: TweenAnimationBuilder<double>(
          // a new text is a new line: it comes in again
          key: ValueKey(text),
          tween: Tween(begin: still ? 1 : 0, end: 1),
          duration: Duration(milliseconds: still ? 0 : 260),
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 6),
              child: child,
            ),
          ),
          child: pill,
        ),
      ),
    );
  }
}
