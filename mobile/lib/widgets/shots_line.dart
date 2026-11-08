// SPDX-License-Identifier: GPL-3.0-or-later
// the line a chat shows where its screenshot block last changed, by either
// phone, and where it went over to post-quantum: a quiet pill in the
// thread, like a day's. it eases in where it
// lands, no animation with reduced motion
import 'package:flutter/material.dart';

import '../capture_watch.dart' show Capture;
import '../group_shots.dart';
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

/// what a group's line says: [line] as group_shots.dart names them, made
/// by this phone's admin or by [name]. null for none
String? groupShotsLineText(int line, {required bool mine, String? name}) {
  final who = name ?? '';
  return switch (line) {
    kGroupLineOn => shotsLineText(on: true, mine: mine, name: who),
    kGroupLineOnWait =>
      mine
          ? l10n.groupShotsYouTurnedOnWait
          : l10n.groupShotsTheyTurnedOnWait(who),
    kGroupLineStarted => l10n.groupShotsStartedShown,
    kGroupLinePaused => l10n.groupShotsPaused,
    kGroupLineOff => shotsLineText(on: false, mine: mine, name: who),
    _ => null,
  };
}

/// the quiet line for a capture android told this phone of
String captureLine(Capture what) => switch (what) {
  Capture.shot => l10n.captureShotTaken,
  Capture.recording => l10n.captureRecording,
};

/// where a kept file is: each says so in its own words
enum KeptIn { chat, group, room }

String keptOpenLine(KeptIn where) => switch (where) {
  KeptIn.chat => l10n.chatShotsKeptOpen,
  KeptIn.group => l10n.groupShotsKeptOpen,
  KeptIn.room => l10n.roomShotsKeptOpen,
};

class ShotsLine extends StatelessWidget {
  final String text;
  final bool on;
  // another line of the same kind (a chat going over to post-quantum):
  // its own icon
  final IconData? icon;
  const ShotsLine({super.key, required this.text, required this.on, this.icon});

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
            icon ??
                (on
                    ? Icons.phonelink_lock_outlined
                    : Icons.phonelink_erase_outlined),
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
                color: HaloColors.text,
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
