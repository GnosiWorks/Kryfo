// SPDX-License-Identifier: GPL-3.0-or-later
// the translate line's menu under a message: this chat always translated,
// or the language never offered again, with an undo
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/message_menu.dart' show MenuSheet, MenuSheetRow;
import 'chat_translation.dart';
import 'foreign.dart';
import 'hub.dart';
import 'lang_names.dart';

Future<void> showTranslateMenu(
  BuildContext context,
  ChatTranslation chat,
  Offer offer,
) async {
  HapticFeedback.selectionClick();
  final always = chat.auto == true;
  final lang = langName(offer.seen);
  final pick = await showHaloSheet<String>(
    context,
    builder: (ctx) => SafeArea(
      top: false,
      child: MenuSheet(
        groups: [
          [
            MenuSheetRow(
              icon: Icons.translate_rounded,
              label: l10n.translateAlwaysChat,
              toggled: always,
              onTap: () => Navigator.pop(ctx, 'always'),
            ),
            MenuSheetRow(
              icon: Icons.do_not_disturb_on_outlined,
              label: l10n.translateBarNever(lang),
              onTap: () => Navigator.pop(ctx, 'never'),
            ),
          ],
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (pick) {
    case 'always':
      try {
        await chat.setAuto(!always);
      } catch (_) {}
    case 'never':
      await neverOffer(context, chat.hub, offer);
  }
}

// the language goes on the never list, and a short note offers it back
Future<void> neverOffer(
  BuildContext context,
  TranslationHub hub,
  Offer offer,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final lang = offer.from;
  try {
    await hub.neverFor(lang);
  } catch (_) {
    return;
  }
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // an action makes a snack bar stay by default: this one goes
        duration: const Duration(seconds: 5),
        persist: false,
        backgroundColor: HaloColors.surface3,
        content: Text(
          l10n.translateNeverDone(langName(offer.seen)),
          style: HaloType.sans(size: 13.5, color: HaloColors.text),
        ),
        action: SnackBarAction(
          label: l10n.translateUndo,
          textColor: HaloColors.amberText,
          onPressed: () => unawaited(hub.offerAgain(lang)),
        ),
      ),
    );
}
