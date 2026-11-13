// SPDX-License-Identifier: GPL-3.0-or-later
// a linked computer whose start check has not confirmed it yet shows its
// chats read only: this stands where the composer was, and on the chat
// list, until it is confirmed
import 'package:flutter/material.dart';

import '../devices/link_check.dart';
import '../l10n/l10n.dart';
import '../theme.dart';

class LinkWaitStrip extends StatelessWidget {
  const LinkWaitStrip({super.key, this.list = false});

  /// on the chat list, under its head, rather than under a chat
  final bool list;

  @override
  Widget build(BuildContext context) {
    final strip = Container(
      margin: list
          ? const EdgeInsets.fromLTRB(16, 4, 16, 8)
          : const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 16, color: HaloColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.linkCheckWaitLine,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.text,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
    return list ? strip : SafeArea(top: false, child: strip);
  }
}

/// [child] while nothing is held for the start check, the strip while it
/// is. it follows the check as it moves
class LinkHeldSwap extends StatelessWidget {
  const LinkHeldSwap({super.key, required this.child, this.list = false});

  final Widget child;
  final bool list;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<LinkCheckStage?>(
    valueListenable: linkCheck,
    builder: (context, stage, child) =>
        stage == null ? child! : LinkWaitStrip(list: list),
    child: child,
  );
}
