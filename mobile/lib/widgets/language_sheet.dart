// SPDX-License-Identifier: GPL-3.0-or-later
// the language sheet: match phone first, then every language kryfo has by
// its own name, the current one ticked. one sheet, from onboarding and from
// settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import 'confirm_sheet.dart';
import 'press_scale.dart';
import 'stroke_icon.dart';

/// the language row's value: the chosen language's own name, or match
/// phone and the language that is
String languageValue() => appLocalePref == 'system'
    ? l10n.languageMatchPhoneValue(kLanguageNames[systemLanguage]!)
    : kLanguageNames[currentLanguage]!;

/// [fromSettings]: the switch takes the person back to their chats, and the
/// sheet says so. in onboarding it just redraws the screen they are on.
Future<void> pickLanguage(
  BuildContext context, {
  bool fromSettings = true,
}) async {
  final choice = await showChoiceSheet<String>(
    context,
    title: l10n.languageTitle,
    line: fromSettings ? l10n.languageRedrawLine : null,
    current: appLocalePref,
    choices: [
      SheetChoice(
        'system',
        l10n.languageMatchPhone,
        hint: kLanguageNames[systemLanguage],
      ),
      for (final t in availableLanguages) SheetChoice(t, kLanguageNames[t]!),
    ],
  );
  if (choice == null || choice == appLocalePref) return;
  HapticFeedback.selectionClick();
  await setAppLocale(choice);
}

const _globe = [
  'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z',
  'M3.5 9h17M3.5 15h17',
  'M12 3c-2.4 2.5-3.6 5.5-3.6 9s1.2 6.5 3.6 9',
  'M12 3c2.4 2.5 3.6 5.5 3.6 9s-1.2 6.5-3.6 9',
];

/// the small language button on the first onboarding screen: the language
/// kryfo is in, by its own name
class LanguageChip extends StatelessWidget {
  const LanguageChip({super.key});

  @override
  Widget build(BuildContext context) {
    final name = kLanguageNames[currentLanguage]!;
    return PressScale(
      label: l10n.languageButton(name),
      onTap: () => pickLanguage(context, fromSettings: false),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 12, 7),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StrokeIcon(_globe, size: 14, color: HaloColors.amber, stroke: 1.5),
            const SizedBox(width: 6),
            Text(
              name,
              style: HaloType.sans(
                size: 12,
                weight: FontWeight.w500,
                color: HaloColors.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
