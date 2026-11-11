// SPDX-License-Identifier: GPL-3.0-or-later
// the flame's sheet, one for chats and groups: how long timed messages
// live. a tap on the flame opens it; while a timer is on, "Off" sits on top
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
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
