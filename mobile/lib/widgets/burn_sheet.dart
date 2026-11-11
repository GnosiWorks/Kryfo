// SPDX-License-Identifier: GPL-3.0-or-later
// the flame's sheet, one for chats and groups: how long timed messages
// live. a tap on the flame opens it; while a timer is on, "Off" sits on top
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../theme.dart';
import 'confirm_sheet.dart' show SheetChoice, showChoiceSheet;

/// what the sheet hands back for "Off"
const kBurnOff = 0;

/// the times on offer, shortest first. [short] leaves out the ones under
/// an hour (an answer the phone sends lives an hour at least)
List<(int, String)> burnTimes({bool short = true}) => [
  if (short) ...[
    (30, l10n.chat30Seconds),
    (60, l10n.chat1Minute),
    (300, l10n.chat5Minutes),
  ],
  (3600, l10n.chat1Hour),
  (86400, l10n.chat24Hours),
];

/// the seconds picked, [kBurnOff] for off, null when let go. [on] is
/// whether a timer is set now, and [secs] which
Future<int?> showBurnSheet(
  BuildContext context, {
  required bool on,
  required int secs,
  bool short = true,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final picked = await showChoiceSheet<int>(
    context,
    title: l10n.chatGhostTimer,
    line: l10n.chatHowLongAfterReading,
    current: on ? secs : null,
    choices: [
      if (on) SheetChoice(kBurnOff, l10n.commonOff),
      for (final (s, label) in burnTimes(short: short)) SheetChoice(s, label),
    ],
  );
  if (picked != null) HapticFeedback.selectionClick();
  return picked;
}

/// how long the chat's timed messages live, as short as it goes: "30s",
/// "5m", "1h", "1d"
String burnShort(int secs) {
  if (secs < 60) return l10n.chatS(whole(secs));
  if (secs < 3600) return l10n.chatM(whole(secs ~/ 60));
  if (secs < 86400) return l10n.chatH(whole(secs ~/ 3600));
  return l10n.chatD(whole(secs ~/ 86400));
}

/// the timer beside the flame while it is on: it eases in and out
class FlameTime extends StatelessWidget {
  final bool on;
  final int secs;
  const FlameTime({super.key, required this.on, required this.secs});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final time = const Duration(milliseconds: 200);
    final label = AnimatedSwitcher(
      duration: still ? Duration.zero : time,
      child: on
          ? Padding(
              key: ValueKey(secs),
              padding: const EdgeInsetsDirectional.only(start: 3, end: 2),
              child: Text(
                burnShort(secs),
                maxLines: 1,
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.3),
                style: HaloType.mono(
                  size: 11,
                  weight: FontWeight.w600,
                  color: HaloColors.amberText,
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('off')),
    );
    // with no motion asked for it simply is there or not: AnimatedSize
    // with no time trips the layout
    return ExcludeSemantics(
      child: still
          ? label
          : AnimatedSize(
              duration: time,
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional.centerStart,
              child: label,
            ),
    );
  }
}
