// SPDX-License-Identifier: GPL-3.0-or-later
// the slim bar at the top of a chat whose messages are in a language the
// person does not read: one tap translates the whole chat, the next shows
// it as it came. its menu sets the language for every chat, or puts the
// bar away here. it is worked out on the phone from the guesses the chat
// already holds, so nothing of it is stored but the person's choices.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/message_menu.dart' show MenuSheet, MenuSheetRow;
import '../widgets/motion.dart' show kHouseCurve, kHouseTime, motionStill;
import 'catalog.dart' show LangBundle;
import 'chat_translation.dart';
import 'foreign.dart';
import 'hant.dart' show HantForm;
import 'lang_names.dart';
import 'pack_sheet.dart';
import 'translate_menu.dart' show neverOffer;

// the language a reader gets: traditional chinese says so
String _into(Offer o) => o.hant != HantForm.none ? 'zh_hant' : o.to;

// where the bar sits: it slides in under the head and folds away again
// on the house spring, or simply appears and goes with reduced motion
class TranslateBarSlot extends StatelessWidget {
  final ChatTranslation? chat;
  // their recent messages' words, newest last
  final List<String> theirs;
  // false where no bar is offered at all: the decoy, the developer chat
  final bool allowed;
  const TranslateBarSlot({
    super.key,
    required this.chat,
    required this.theirs,
    this.allowed = true,
  });

  @override
  Widget build(BuildContext context) {
    final chat = this.chat;
    if (chat == null || !allowed) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([chat, chat.hub.downloads]),
      builder: (context, _) {
        final o = chat.barOffer(theirs);
        final still = motionStill(context);
        return AnimatedSwitcher(
          duration: still ? Duration.zero : kHouseTime,
          switchInCurve: kHouseCurve,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => ClipRect(
            child: SizeTransition(
              sizeFactor: anim.drive(Tween(begin: 0.0, end: 1.0)),
              axisAlignment: -1,
              child: SlideTransition(
                position: anim.drive(
                  Tween(begin: const Offset(0, -0.4), end: Offset.zero),
                ),
                child: FadeTransition(opacity: anim, child: child),
              ),
            ),
          ),
          child: o == null
              ? const SizedBox(key: ValueKey('tr-bar-none'), width: 0)
              : TranslateBar(
                  key: const ValueKey('tr-bar'),
                  chat: chat,
                  offer: o,
                ),
        );
      },
    );
  }
}

class TranslateBar extends StatelessWidget {
  final ChatTranslation chat;
  final Offer offer;
  const TranslateBar({super.key, required this.chat, required this.offer});

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final all = chat.autoOn(o);
    final missing = all ? const <LangBundle>[] : chat.hub.missing(o);
    final size = missing.fold<int>(0, (n, b) => n + b.gz);
    final label = all
        ? l10n.translateShowOriginal
        : l10n.translateBarTo(langName(_into(o)));
    final still = motionStill(context);
    final style = HaloType.sans(
      size: 13.5,
      weight: FontWeight.w600,
      color: HaloColors.amberText,
      height: 1.3,
    );
    return Container(
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: Border(bottom: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: size > 0 ? '$label, ${packSize(size)}' : label,
              // the ink's own tap is excluded with its words: a double tap
              // needs one here
              onTap: () => _main(context, all),
              excludeSemantics: true,
              child: InkWell(
                onTap: () => _main(context, all),
                child: ConstrainedBox(
                  // the bar's full height, so the ripple has no dead strip
                  constraints: const BoxConstraints(
                    minHeight: kMinInteractiveDimension,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 9, 4, 9),
                    child: Row(
                      children: [
                        Icon(
                          Icons.translate_rounded,
                          size: 16,
                          color: HaloColors.amberText,
                        ),
                        const SizedBox(width: 9),
                        // large text: the size takes its own line and the
                        // label wraps whole, never cut short
                        Flexible(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              AnimatedSwitcher(
                                duration: still
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                layoutBuilder: (cur, prev) => Stack(
                                  alignment: AlignmentDirectional.centerStart,
                                  children: [...prev, ?cur],
                                ),
                                child: Text(
                                  label,
                                  key: ValueKey(label),
                                  style: style,
                                ),
                              ),
                              if (size > 0)
                                Text(
                                  packSize(size),
                                  key: const ValueKey('tr-bar-size'),
                                  style: HaloType.mono(
                                    size: 11,
                                    color: HaloColors.text,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('tr-bar-more'),
            tooltip: l10n.translateBarMore,
            onPressed: () => _menu(context),
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: HaloColors.text2,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Future<void> _main(BuildContext context, bool all) async {
    HapticFeedback.selectionClick();
    if (all) return chat.showOriginalAll();
    final need = await chat.translateAll(offer);
    if (need == null || !context.mounted) return;
    // a pack that is not there yet: its size, and a download only on a tap
    // in the sheet, wi-fi rule and all
    await showPackSheet(
      context,
      hub: chat.hub,
      language: langName(need.offer.seen),
      missing: need.missing,
      why: need.why,
    );
    if (!context.mounted) return;
    if (await chat.hub.blockFor(offer) == null) await chat.translateAll(offer);
  }

  Future<void> _menu(BuildContext context) async {
    HapticFeedback.selectionClick();
    final lang = langName(offer.seen);
    final pick = await showHaloSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        top: false,
        child: MenuSheet(
          groups: [
            [
              MenuSheetRow(
                icon: Icons.do_not_disturb_on_outlined,
                label: l10n.translateBarNever(lang),
                onTap: () => Navigator.pop(ctx, 'never'),
              ),
            ],
            [
              MenuSheetRow(
                icon: Icons.visibility_off_outlined,
                label: l10n.translateBarHide,
                onTap: () => Navigator.pop(ctx, 'hide'),
              ),
            ],
          ],
        ),
      ),
    );
    switch (pick) {
      case 'never':
        if (context.mounted) await neverOffer(context, chat.hub, offer);
      case 'hide':
        unawaited(chat.hideBar());
    }
  }
}
