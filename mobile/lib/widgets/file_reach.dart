// SPDX-License-Identifier: GPL-3.0-or-later
// under a group message or file of ours that some members still lack: how
// many of the members it went to have it. it goes once they all do, and
// the bubble is back to its plain sent state. once every member still
// lacking it is past its tries, it says how many did not get it instead.
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';

/// only members past their tries are left: nothing more is coming
bool fileReachGaveUp(int have, int of, int gaveUp) =>
    gaveUp > 0 && have + gaveUp >= of;

/// the pill's words. while anyone is still tried it counts who has it
String fileReachWords(int have, int of, int gaveUp) =>
    fileReachGaveUp(have, of, gaveUp)
    ? l10n.groupChatFileGaveUp(gaveUp)
    : l10n.groupChatFileReach(have, of);

class FileReachPill extends StatelessWidget {
  final int have;
  final int of;
  // of those who lack it, the ones past their tries
  final int gaveUp;
  const FileReachPill({
    super.key,
    required this.have,
    required this.of,
    this.gaveUp = 0,
  });

  @override
  Widget build(BuildContext context) {
    final words = fileReachWords(have, of, gaveUp);
    final lost = fileReachGaveUp(have, of, gaveUp);
    return Semantics(
      label: words,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: lost
              ? HaloColors.rose.withValues(alpha: 0.14)
              : HaloColors.amberSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          words,
          style: HaloType.mono(
            size: 9.5,
            letter: 0.5,
            color: lost ? HaloColors.rose : HaloColors.amber,
          ),
        ),
      ),
    );
  }
}
