// SPDX-License-Identifier: GPL-3.0-or-later
// a bubble's words with a translate line under them, and the translation
// in their place once made. no chat handed in, no change
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/ease_size.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime, motionStill;
import 'chat_translation.dart';
import 'lang_names.dart';
import 'pack_sheet.dart';

// a tap on translate, from the bubble or the menu: the translation, or the
// sheet for what it needs, then the translation once that is there
Future<void> askTranslate(
  BuildContext context,
  ChatTranslation chat,
  String key,
  String text,
) async {
  final need = await chat.toggle(key, text);
  if (need == null || !context.mounted) return;
  await showPackSheet(
    context,
    hub: chat.hub,
    language: langName(need.offer.seen),
    missing: need.missing,
    why: need.why,
  );
  if (!context.mounted) return;
  // the pack came while the sheet was up: the message the tap was for
  if (await chat.hub.blockFor(need.offer) == null) {
    await chat.toggle(key, text);
  }
}

class TranslatedBody extends StatelessWidget {
  final ChatTranslation? chat;
  // what the chat knows the message by
  final String msgKey;
  final String text;
  // false for our own, a sticker, a search: the words as they are
  final bool enabled;
  final Widget original;
  final Widget Function(String translated) translated;
  const TranslatedBody({
    super.key,
    required this.chat,
    required this.msgKey,
    required this.text,
    required this.original,
    required this.translated,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final chat = enabled ? this.chat : null;
    if (chat == null) return original;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final m = chat.of(msgKey, text);
        final o = m.offer ?? chat.offer(text);
        if (o == null) return original;
        if (m.phase == MsgPhase.idle && chat.autoOn(o)) {
          scheduleMicrotask(() => chat.autoFor(msgKey, text));
        }
        final shown = m.phase == MsgPhase.shown && m.text != null;
        final still = motionStill(context);
        void tap() {
          HapticFeedback.selectionClick();
          unawaited(askTranslate(context, chat, msgKey, text));
        }

        final Widget foot = switch (m.phase) {
          MsgPhase.shown => _Foot(
            key: const ValueKey('tr-shown'),
            lead: l10n.translateFrom(langName(o.seen)),
            action: l10n.translateShowOriginal,
            onTap: tap,
          ),
          MsgPhase.working => _Foot(
            key: const ValueKey('tr-working'),
            lead: l10n.translateWorking,
          ),
          MsgPhase.failed => _Foot(
            key: const ValueKey('tr-failed'),
            lead: l10n.translateFailed,
            action: l10n.commonTryAgain,
            onTap: tap,
          ),
          MsgPhase.idle => _Foot(
            key: const ValueKey('tr-idle'),
            icon: true,
            action: l10n.translateAction,
            onTap: tap,
          ),
        };
        final words = KeyedSubtree(
          key: ValueKey(shown),
          child: shown ? translated(m.text!) : original,
        );
        return EaseSize(
          duration: kHouseTime,
          alignment: AlignmentDirectional.topStart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (still)
                words
              else
                AnimatedSwitcher(
                  duration: kHouseTime,
                  switchInCurve: kHouseCurve,
                  switchOutCurve: kHouseCurve,
                  layoutBuilder: (cur, prev) => Stack(
                    alignment: AlignmentDirectional.topStart,
                    children: [...prev, ?cur],
                  ),
                  child: words,
                ),
              foot,
            ],
          ),
        );
      },
    );
  }
}

// the line under the words: what happened, and what a tap does
class _Foot extends StatelessWidget {
  final String? lead;
  final String? action;
  final bool icon;
  final VoidCallback? onTap;
  const _Foot({
    super.key,
    this.lead,
    this.action,
    this.icon = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final quiet = HaloType.sans(
      size: 11.5,
      color: HaloColors.text3,
      height: 1.3,
    );
    final act = HaloType.sans(
      size: 11.5,
      weight: FontWeight.w600,
      color: HaloColors.amberText,
      height: 1.3,
    );
    final row = Text.rich(
      TextSpan(
        children: [
          if (icon)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Icon(
                  Icons.translate_rounded,
                  size: 13,
                  color: HaloColors.amberText,
                ),
              ),
            ),
          if (lead != null) TextSpan(text: lead, style: quiet),
          if (lead != null && action != null)
            TextSpan(text: ' · ', style: quiet),
          if (action != null) TextSpan(text: action, style: act),
        ],
      ),
    );
    final padded = Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 1),
      child: row,
    );
    if (onTap == null) return padded;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: padded,
      ),
    );
  }
}
