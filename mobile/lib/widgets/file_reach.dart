// SPDX-License-Identifier: GPL-3.0-or-later
// under a group file of ours that some members still lack: how many of the
// members it went to have it. it goes once they all do, and the bubble is
// back to its plain sent state.
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';

class FileReachPill extends StatelessWidget {
  final int have;
  final int of;
  const FileReachPill({super.key, required this.have, required this.of});

  @override
  Widget build(BuildContext context) {
    final words = l10n.groupChatFileReach(have, of);
    return Semantics(
      label: words,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: HaloColors.amberSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          words,
          style: HaloType.mono(size: 9.5, letter: 0.5, color: HaloColors.amber),
        ),
      ),
    );
  }
}
