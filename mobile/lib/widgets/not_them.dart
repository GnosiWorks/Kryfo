// SPDX-License-Identifier: GPL-3.0-or-later
// under a safety number, and on the compare card: the numbers on the two
// phones are not the same. saying so brings up "this isn't them", which asks
// once. then the contact goes from this phone and the key the number was
// made from is blocked
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../main.dart' show appState;
import '../theme.dart';
import 'confirm_sheet.dart';
import 'ease_size.dart';
import 'press_scale.dart';
import 'swap.dart';

// asks once, in plain words, then takes [peer] off this phone and blocks
// [keyHex], the key the number was made from, and goes back to the chats.
// false when nothing went: kept, or the key moved meanwhile
Future<bool> removeAsNotThem(
  BuildContext context,
  String peer,
  String keyHex,
) async {
  final yes = await showConfirmSheet(
    context,
    title: l10n.notThemSheetTitle,
    line: l10n.notThemSheetLine,
    yes: l10n.notThemRemove,
    keep: l10n.commonCancel,
  );
  if (!yes || !context.mounted) return false;
  final nav = Navigator.of(context);
  final done = await appState.notThem(peer, keyHex);
  if (!context.mounted) return done;
  if (!done) {
    // the number moved while the sheet was up: the new one is compared
    showHaloToast(context, l10n.keyVerificationKeyMoved);
    return false;
  }
  HapticFeedback.mediumImpact();
  showHaloToast(context, l10n.notThemDone);
  nav.popUntil((r) => r.isFirst);
  return true;
}

// the quiet way in: the numbers on the two phones are not the same
class NotThemAsk extends StatelessWidget {
  const NotThemAsk({super.key, required this.onTap, this.compact = false});

  final VoidCallback onTap;
  // on the compare card in a chat: smaller, as the card is
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: PressScale(
        scale: 0.97,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                Icons.gpp_bad_outlined,
                size: compact ? 15 : 17,
                color: HaloColors.text2,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.notThemNumbersDiffer,
                  style: HaloType.sans(
                    size: compact ? 12.5 : 13.5,
                    weight: FontWeight.w500,
                    color: HaloColors.text2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// under the safety number: the ask, which opens into what it means and
// the one way to act on it
class NotThemFold extends StatefulWidget {
  const NotThemFold({super.key, required this.peer, required this.keyHex});

  final String peer;
  // the key the number on screen was made from
  final String keyHex;

  @override
  State<NotThemFold> createState() => _NotThemFoldState();
}

class _NotThemFoldState extends State<NotThemFold> {
  bool _open = false;
  bool _busy = false;

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    await removeAsNotThem(context, widget.peer, widget.keyHex);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return EaseSize(
      child: FadeSwap(
        child: _open
            ? KeyedSubtree(key: const ValueKey('open'), child: _panel())
            : KeyedSubtree(
                key: const ValueKey('ask'),
                child: NotThemAsk(onTap: () => setState(() => _open = true)),
              ),
      ),
    );
  }

  Widget _panel() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: HaloColors.rose.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: HaloColors.rose.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_bad_outlined, size: 17, color: HaloColors.rose),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.notThemNumbersDiffer,
                  style: HaloType.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: HaloColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.notThemLine,
            style: HaloType.sans(
              size: 13.5,
              color: HaloColors.text2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          PressScale(
            label: l10n.notThemButton,
            scale: 0.96,
            onTap: _busy ? null : _remove,
            child: AnimatedOpacity(
              opacity: _busy ? 0.6 : 1,
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HaloColors.rose.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: HaloColors.rose.withValues(alpha: 0.55),
                  ),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    l10n.notThemButton,
                    textAlign: TextAlign.center,
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: HaloColors.rose,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
