// SPDX-License-Identifier: GPL-3.0-or-later
// a bubble's words with a translate line under them, and the translation
// in their place once made, marked as one. the line is there only for a
// message in a language the person does not read, guessed with confidence,
// with a few words to it. no chat handed in, no change
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/ease_size.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime, motionStill;
import 'catalog.dart' show LangBundle;
import 'chat_translation.dart';
import 'downloads.dart' show DlPhase;
import 'lang_names.dart';
import 'pack_sheet.dart';
import 'translate_menu.dart';

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

class TranslatedBody extends StatefulWidget {
  final ChatTranslation? chat;
  // what the chat knows the message by
  final String msgKey;
  final String text;
  // when it came: the download offer shows only under the newest message
  // in its language. none, and every one offers
  final int? came;
  // false for our own, a sticker, a search: the words as they are
  final bool enabled;
  final Widget original;
  final Widget Function(String translated) translated;
  const TranslatedBody({
    super.key,
    required this.chat,
    required this.msgKey,
    required this.text,
    this.came,
    required this.original,
    required this.translated,
    this.enabled = true,
  });

  @override
  State<TranslatedBody> createState() => _TranslatedBodyState();
}

class _TranslatedBodyState extends State<TranslatedBody> {
  // once a line was shown it folds away when it goes, never jumps
  bool _hadFoot = false;

  @override
  Widget build(BuildContext context) {
    final chat = widget.enabled ? widget.chat : null;
    if (chat == null) return widget.original;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final key = widget.msgKey, text = widget.text;
        final m = chat.of(key, text);
        final now = chat.offer(text);
        final o = now == null ? null : (m.offer ?? now);
        if (o == null && !_hadFoot) return widget.original;
        _hadFoot = true;
        if (o != null && m.phase == MsgPhase.idle && chat.autoOn(o)) {
          scheduleMicrotask(() => chat.autoFor(key, text));
        }
        final shown = o != null && m.phase == MsgPhase.shown && m.text != null;
        final still = motionStill(context);
        void tap() {
          HapticFeedback.selectionClick();
          unawaited(askTranslate(context, chat, key, text));
        }

        void menu() {
          if (o != null) unawaited(showTranslateMenu(context, chat, o));
        }

        // a pack not on the phone: its size, fetched only from the sheet
        final missing = o == null || m.text != null || chat.hasLib == false
            ? const <LangBundle>[]
            : chat.hub.missing(o);
        final size = missing.fold<int>(0, (n, b) => n + b.gz);
        final got = missing.isEmpty
            ? null
            : chat.hub.downloads.ofMany(
                [for (final b in missing) b.id],
                [for (final b in missing) b.gz],
              );
        final name = o == null ? '' : langName(o.seen);
        final came = widget.came;
        // a pack to fetch first: said once per language, not per message
        final here =
            o == null ||
            size == 0 ||
            m.phase != MsgPhase.idle ||
            came == null ||
            chat.offerHere(o.from, key, came);
        final Widget? foot = o == null
            ? null
            : switch (m.phase) {
                MsgPhase.shown => _Foot(
                  key: const ValueKey('tr-shown'),
                  icon: true,
                  lead: l10n.translateFrom(langName(o.seen)),
                  action: l10n.translateShowOriginal,
                  onTap: tap,
                  onMenu: menu,
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
                  onMenu: menu,
                ),
                MsgPhase.idle when !here => null,
                // the packs it needs are coming, or wait for wi-fi
                MsgPhase.idle when got != null && got.busy => _Foot(
                  key: const ValueKey('tr-getting'),
                  icon: true,
                  lead: l10n.translateLineDownloading(name),
                  onTap: tap,
                  onMenu: menu,
                ),
                MsgPhase.idle when got?.phase == DlPhase.wifiNeeded => _Foot(
                  key: const ValueKey('tr-wifi'),
                  icon: true,
                  lead: l10n.translateLineWaitsWifi(name),
                  onTap: tap,
                  onMenu: menu,
                ),
                // packs to fetch first: the offer says what and how much
                MsgPhase.idle when size > 0 => _Foot(
                  key: const ValueKey('tr-offer'),
                  icon: true,
                  action: l10n.translateOfferDownload(name, packSize(size)),
                  onTap: tap,
                  onMenu: menu,
                  // the x: never offered for this language again
                  onClose: () {
                    HapticFeedback.selectionClick();
                    unawaited(neverOffer(context, chat.hub, o));
                  },
                  closeLabel: l10n.translateBarNever(name),
                ),
                MsgPhase.idle => _Foot(
                  key: const ValueKey('tr-idle'),
                  icon: true,
                  action: l10n.translateAction,
                  onTap: tap,
                  onMenu: menu,
                ),
              };
        // the translation reads as one to a screen reader too
        final words = KeyedSubtree(
          key: ValueKey(shown),
          child: shown
              ? Semantics(
                  container: true,
                  label: l10n.translateFrom(langName(o.seen)),
                  child: widget.translated(m.text!),
                )
              : widget.original,
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
              if (still)
                ?foot
              else
                AnimatedSwitcher(
                  duration: kHouseTime,
                  switchInCurve: kHouseCurve,
                  switchOutCurve: kHouseCurve,
                  layoutBuilder: (cur, prev) => Stack(
                    alignment: AlignmentDirectional.topStart,
                    children: [...prev, ?cur],
                  ),
                  child: foot ?? const SizedBox(key: ValueKey('tr-none')),
                ),
            ],
          ),
        );
      },
    );
  }
}

// the line under the words: what happened, what a tap does, and its menu
class _Foot extends StatelessWidget {
  final String? lead;
  final String? action;
  final bool icon;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final VoidCallback? onClose;
  final String? closeLabel;
  const _Foot({
    super.key,
    this.lead,
    this.action,
    this.icon = false,
    this.onTap,
    this.onMenu,
    this.onClose,
    this.closeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final quiet = HaloType.sans(
      size: 11.5,
      color: HaloColors.text,
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
    // the menu: a long press, or a screen reader's own action. no glyph of
    // its own, so a foreign message is no taller
    final menu = onMenu;
    final line = Semantics(
      button: true,
      label: [?lead, ?action].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: menu,
      customSemanticsActions: menu == null
          ? null
          : {CustomSemanticsAction(label: l10n.translateBarMore): menu},
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: menu,
        child: padded,
      ),
    );
    final close = onClose;
    if (close == null) return line;
    // a small x beside the line, its touch area wider than it looks
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: line),
        Semantics(
          button: true,
          label: closeLabel,
          excludeSemantics: true,
          onTap: close,
          child: GestureDetector(
            key: const ValueKey('tr-offer-close'),
            behavior: HitTestBehavior.opaque,
            onTap: close,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 6, 1),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: HaloColors.amberText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
