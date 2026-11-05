// SPDX-License-Identifier: GPL-3.0-or-later
// what a linked device shows once it unlinked: everything Kryfo kept here
// is erased already, and the page says why, plainly. over everything,
// the lock included: nothing behind it opens any more
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../devices/linked_lock.dart' show LinkedEnd;
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/stagger_in.dart';

/// why the device unlinked, in the person's words
String unlinkedLine(LinkedEnd why) => switch (why) {
  LinkedEnd.removed => l10n.unlinkedRemovedLine,
  LinkedEnd.unused => l10n.unlinkedUnusedLine,
  LinkedEnd.clock => l10n.unlinkedClockLine,
  LinkedEnd.broken => l10n.unlinkedBrokenLine,
  LinkedEnd.self => l10n.unlinkedSelfLine,
  LinkedEnd.silent => l10n.unlinkedSilentLine,
};

class UnlinkedScreen extends StatelessWidget {
  const UnlinkedScreen({super.key, required this.why, required this.onClose});

  final LinkedEnd why;

  /// the app closes: android's erase, else the exit
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FitColumn(
              padding: const EdgeInsets.fromLTRB(28, 48, 28, 28),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StaggerIn(
                  index: 0,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: HaloColors.amber.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.link_off_rounded,
                      color: HaloColors.amber,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                StaggerIn(
                  index: 1,
                  child: Text(
                    l10n.unlinkedTitle,
                    style: HaloType.serif(size: 26, color: HaloColors.text),
                  ),
                ),
                const SizedBox(height: 14),
                StaggerIn(
                  index: 2,
                  child: Text(
                    unlinkedLine(why),
                    style: HaloType.sans(
                      size: 14.5,
                      color: HaloColors.text,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                StaggerIn(
                  index: 3,
                  child: Text(
                    l10n.unlinkedAgainLine,
                    style: HaloType.sans(
                      size: 14.5,
                      color: HaloColors.text2,
                      height: 1.5,
                    ),
                  ),
                ),
                const Spacer(),
                StaggerIn(
                  index: 4,
                  child: HaloPrimaryButton(
                    label: l10n.unlinkedClose,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onClose();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
