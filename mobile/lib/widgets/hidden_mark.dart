// SPDX-License-Identifier: GPL-3.0-or-later
// hidden chats as their own session shows them: a small mark on the row,
// and the move out of the chat list or back into it. only the hidden chats
// PIN opens a session where either is ever drawn.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../main.dart' show appState;
import '../theme.dart';

// the mark after a hidden chat's name. it comes and goes with a small
// spring; a row that is new draws it as it is
class HiddenMark extends StatelessWidget {
  const HiddenMark({super.key, required this.on, this.size = 12});
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 240),
      reverseDuration: still
          ? Duration.zero
          : const Duration(milliseconds: 160),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: a,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        ),
      ),
      child: on
          ? Padding(
              key: const ValueKey(true),
              padding: const EdgeInsetsDirectional.only(start: 5),
              child: Semantics(
                label: l10n.chatHidden,
                child: Icon(
                  Icons.visibility_off_outlined,
                  size: size,
                  color: HaloColors.violet,
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey(false)),
    );
  }
}

// a chat or group out of the everyday list, or back in it. true when it
// moved. the rows move between containers, so a screen showing the chat
// leaves it once this is done
Future<bool> moveHiddenChat(
  BuildContext context,
  String id, {
  required bool group,
  required bool hide,
}) async {
  HapticFeedback.mediumImpact();
  final people = group ? const <String>[] : [id];
  final groups = group ? [id] : const <String>[];
  var n = 0;
  try {
    n = hide
        ? await appState.hideChats(people: people, groups: groups)
        : await appState.unhideChats(people: people, groups: groups);
  } catch (_) {
    n = 0;
  }
  if (!context.mounted) return n > 0;
  if (n == 0) {
    HapticFeedback.heavyImpact();
    showHaloToast(context, l10n.commonTryAgain);
    return false;
  }
  if (hide) showHaloToast(context, l10n.chatHiddenToast);
  return true;
}
