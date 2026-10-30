// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../l10n/l10n.dart';
import 'confirm_sheet.dart';
import 'fit_column.dart';
import 'press_scale.dart';

// shown when boot() throws. the fault is usually local, so the tor splash
// would point at the wrong thing.
class BootFailedScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  // set when only a new process can help: a retry here waits behind the
  // call that never answered
  final VoidCallback? onReopen;
  // the ways out when trying again does not help: a backup over what is
  // here, or nothing at all. never offered for a store that only stalled
  final VoidCallback? onRestore;
  final VoidCallback? onStartFresh;
  const BootFailedScreen({
    super.key,
    required this.error,
    required this.onRetry,
    this.onReopen,
    this.onRestore,
    this.onStartFresh,
  });

  // asked twice, each time saying what goes: nothing is deleted by one tap
  Future<void> _startFresh(BuildContext context) async {
    HapticFeedback.selectionClick();
    final first = await showConfirmSheet(
      context,
      title: l10n.bootFailedStartFreshTitle,
      line: l10n.bootFailedStartFreshLineShown,
      yes: l10n.bootFailedStartFreshNext,
      keep: l10n.confirmSheetCancel,
    );
    if (!first || !context.mounted) return;
    final sure = await showConfirmSheet(
      context,
      title: l10n.bootFailedStartFreshSureShown,
      line: l10n.bootFailedStartFreshSureLine,
      yes: l10n.bootFailedStartFreshYes,
      keep: l10n.confirmSheetCancel,
    );
    if (!sure || !context.mounted) return;
    HapticFeedback.heavyImpact();
    onStartFresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ways =
        onReopen == null && (onRestore != null || onStartFresh != null);
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: SafeArea(
        // a large font or a short phone scrolls, nothing is cut
        child: FitColumn(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(
              l10n.bootFailedKryfoCouldNotStart,
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 22, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              onReopen == null
                  ? l10n.bootFailedThisIsAFault
                  : l10n.bootFailedKeysDidNotAnswerShown,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HaloColors.line),
              ),
              child: SelectableText(
                error,
                style: HaloType.mono(size: 11, color: HaloColors.text2),
              ),
            ),
            const SizedBox(height: 14),
            if (onReopen case final reopen?) ...[
              Center(child: _main(l10n.bootFailedCloseAndReopen, reopen)),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  _copy(),
                  TextButton(
                    onPressed: onRetry,
                    child: Text(
                      l10n.commonTryAgain,
                      style: HaloType.sans(size: 13, color: HaloColors.text2),
                    ),
                  ),
                ],
              ),
            ] else
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [_copy(), _main(l10n.commonTryAgain, onRetry)],
              ),
            if (ways) ...[
              const SizedBox(height: 28),
              Text(
                l10n.bootFailedStillStuck,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              if (onRestore case final restore?)
                _outline(l10n.bootFailedRestoreBackup, () {
                  HapticFeedback.selectionClick();
                  restore();
                }),
              if (onStartFresh != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => _startFresh(context),
                    child: Text(
                      l10n.bootFailedStartFresh,
                      textAlign: TextAlign.center,
                      style: HaloType.sans(
                        size: 13,
                        color: HaloColors.roseText,
                      ),
                    ),
                  ),
                ),
              ],
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _copy() => TextButton(
    onPressed: () => Clipboard.setData(ClipboardData(text: error)),
    child: Text(
      l10n.commonCopy,
      style: HaloType.mono(size: 12, color: HaloColors.text2),
    ),
  );

  Widget _main(String label, VoidCallback onPressed) => ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: HaloColors.amber,
      foregroundColor: HaloColors.onAmber,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: HaloType.sans(size: 14, color: HaloColors.onAmber),
    ),
  );

  Widget _outline(String label, VoidCallback onTap) => PressScale(
    label: label,
    onTap: onTap,
    scale: 0.96,
    child: Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: HaloColors.line2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: HaloType.sans(
          size: 14,
          weight: FontWeight.w600,
          color: HaloColors.text,
        ),
      ),
    ),
  );
}
