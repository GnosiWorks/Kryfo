// SPDX-License-Identifier: GPL-3.0-or-later
// a computer set up as its own Kryfo links to a phone from settings: what
// goes, a backup first if wanted, the wipe word, then the erase. the next
// run opens onboarding's own link with the code (desktop_platform.dart
// relaunchLink): a link cancelled or failed there is a clean start, never
// a half-erased app. the erase comes before the code because the code
// carries this computer's key, which must be a new one
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../container.dart' show HaloContainer;
import '../l10n/l10n.dart';
import '../last_backup.dart' show backupWhen, loadLastBackup;
import '../theme.dart';
import '../wide/read_width.dart' show DeskPage;
import '../widgets/confirm_sheet.dart' show showInputSheet;
import '../widgets/ease_size.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_rows.dart';
import '../widgets/onion_loader.dart';
import '../widgets/page_head.dart' show PageBar;
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart' show FadeSwap, RiseSwap;
import '../wipe_word.dart' show isWipeWord;
import 'backup_screen.dart';
import '../widgets/motion.dart' show haloRoute;

class DeskLinkScreen extends StatefulWidget {
  const DeskLinkScreen({
    super.key,
    required this.erase,
    this.backup,
    this.side = HaloContainer.everyday,
  });

  /// the erase, once the word is typed: the app ends in it and comes back
  /// at the code. null: the link does not start here, the word only brings
  /// a plain error and nothing changes
  final Future<void> Function()? erase;

  /// the side whose last backup the row shows
  final HaloContainer side;

  /// the backup page, a copy to keep and never a move
  final Widget Function()? backup;

  @override
  State<DeskLinkScreen> createState() => _DeskLinkScreenState();
}

class _DeskLinkScreenState extends State<DeskLinkScreen> {
  bool _read = false;
  DateTime? _last;
  bool _erasing = false;
  bool _notStarted = false;

  @override
  void initState() {
    super.initState();
    _readLast();
  }

  void _readLast() {
    loadLastBackup(widget.side).then((v) {
      if (mounted) {
        setState(() {
          _read = true;
          _last = v;
        });
      }
    });
  }

  Future<void> _backUp() async {
    HapticFeedback.selectionClick();
    final page = widget.backup?.call() ?? const BackupScreen(keepOnly: true);
    await Navigator.of(context).push(haloRoute(page));
    // back here whatever the backup did
    if (mounted) _readLast();
  }

  Future<void> _go() async {
    HapticFeedback.selectionClick();
    final typed = await showInputSheet(
      context,
      title: l10n.settingsTypeWipeToConfirm(l10n.settingsWipeWord),
      line: l10n.deskLinkConfirmLine,
      hint: l10n.settingsWipeWord,
      mono: true,
      rose: true,
      save: l10n.deskLinkConfirmYes,
    );
    if (!mounted || !isWipeWord(typed, l10n.settingsWipeWord)) return;
    HapticFeedback.mediumImpact();
    final erase = widget.erase;
    if (erase == null) {
      setState(() => _notStarted = true);
      return;
    }
    setState(() => _erasing = true);
    await erase();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_erasing,
      child: Scaffold(
        backgroundColor: HaloColors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_erasing)
                PageBar(title: l10n.onboardingLinkToMyPhone)
              else
                const SizedBox(height: 56),
              Expanded(
                child: FadeSwap(
                  child: _erasing
                      ? const _Erasing(key: ValueKey('erasing'))
                      : KeyedSubtree(
                          key: const ValueKey('ask'),
                          child: _ask(context),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ask(BuildContext context) {
    return DeskPage(
      child: FitColumn(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: staggerAllIn(context, [
          Semantics(
            header: true,
            child: Text(
              l10n.deskLinkHead,
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.deskLinkLine,
            style: HaloType.sans(
              size: 14.5,
              color: HaloColors.text,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          _Goes(),
          const SizedBox(height: 22),
          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.save_alt,
                label: l10n.deskLinkBackupRow,
                hint: l10n.deskLinkBackupHint,
                value: _read ? backupWhen(_last) : null,
                pending: !_read,
                onTap: _backUp,
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 24),
          // the link did not start: a plain line, nothing changed
          EaseSize(
            child: RiseSwap(
              alignment: Alignment.topCenter,
              child: !_notStarted
                  ? const SizedBox(key: ValueKey(false), width: double.infinity)
                  : Semantics(
                      key: const ValueKey(true),
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          l10n.deskLinkNotStarted,
                          textAlign: TextAlign.center,
                          style: HaloType.sans(
                            size: 13.5,
                            color: HaloColors.roseText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          HaloPrimaryButton(label: l10n.commonContinue, onTap: _go),
        ]),
      ),
    );
  }
}

// what the erase takes, set apart in rose
class _Goes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: HaloColors.rose.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HaloColors.rose.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: HaloColors.rose,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deskLinkGoesTitle,
                  style: HaloType.sans(
                    size: 14.5,
                    weight: FontWeight.w600,
                    color: HaloColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.deskLinkGoesLine,
                  style: HaloType.sans(
                    size: 13.5,
                    color: HaloColors.text,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// the erase under way: the app ends in it and opens again at the code
class _Erasing extends StatelessWidget {
  const _Erasing({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OnionLoader(size: 104, color: HaloColors.amber),
              const SizedBox(height: 28),
              Semantics(
                liveRegion: true,
                child: Column(
                  children: [
                    Text(
                      l10n.deskLinkErasing,
                      textAlign: TextAlign.center,
                      style: HaloType.serif(size: 24, color: HaloColors.text),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.deskLinkErasingLine,
                      textAlign: TextAlign.center,
                      style: HaloType.sans(
                        size: 14,
                        color: HaloColors.text,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
