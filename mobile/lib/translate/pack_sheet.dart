// SPDX-License-Identifier: GPL-3.0-or-later
// a language pack before, during and after its download: the size first,
// then how far it got, with a way to stop it and a way to try again. the
// same controls sit in the sheet a chat opens and on the settings page.
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime, motionStill;
import '../widgets/sheet_handle.dart';
import 'catalog.dart';
import 'downloads.dart';
import 'hub.dart';
import 'lang_names.dart';
import 'translator.dart';

String failLine(DlFail? f) => switch (f) {
  DlFail.noTor => l10n.translateFailNoTor,
  DlFail.badFile => l10n.translateFailBadFile,
  DlFail.noEngine => l10n.translateFailNoEngine,
  _ => l10n.translateFailNetwork,
};

// a thin bar, filled to [share]; still when the phone asks for no motion
class PackBar extends StatelessWidget {
  final double share;
  const PackBar(this.share, {super.key});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 5,
        color: HaloColors.surface3,
        alignment: AlignmentDirectional.centerStart,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: share.clamp(0.0, 1.0)),
          duration: still ? Duration.zero : kHouseTime,
          curve: kHouseCurve,
          builder: (_, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(color: HaloColors.amber),
          ),
        ),
      ),
    );
  }
}

// what can be done with one pack now
class PackControls extends StatelessWidget {
  final TranslationHub hub;
  final LangBundle bundle;
  // the sheet closes on done; the settings page has nothing to close
  final VoidCallback? onDone;
  const PackControls({
    super.key,
    required this.hub,
    required this.bundle,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hub.downloads,
      builder: (context, _) {
        final dl = hub.downloads;
        final lang = bundle.lang;
        final s = dl.of(lang);
        final size = packSize(bundle.gz);
        Widget line(String t, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            t,
            style: HaloType.sans(
              size: 12.5,
              color: color ?? HaloColors.text2,
              height: 1.4,
            ),
          ),
        );
        final children = <Widget>[];
        switch (s.phase) {
          case DlPhase.starting:
          case DlPhase.running:
            final finishing = s.total > 0 && s.done >= s.total;
            children.addAll([
              PackBar(s.share ?? 0),
              const SizedBox(height: 8),
              Text(
                finishing
                    ? l10n.translateFinishing
                    : l10n.translateProgress(
                        packSize(s.done),
                        packSize(s.total > 0 ? s.total : bundle.gz),
                      ),
                key: const ValueKey('pack-progress'),
                style: HaloType.mono(size: 11, color: HaloColors.text2),
              ),
              const SizedBox(height: 12),
              HaloGhostButton(
                label: l10n.commonCancel,
                quiet: true,
                onTap: () => dl.cancel(lang),
              ),
            ]);
          case DlPhase.wifiNeeded:
            children.addAll([
              line(l10n.translateNeedsWifi),
              HaloPrimaryButton(
                label: l10n.translateDownloadAnyway,
                onTap: () => dl.start(lang, anyNetwork: true),
              ),
            ]);
          case DlPhase.paused:
            children.addAll([
              if (s.onDisk > 0) line(l10n.translatePaused(packSize(s.onDisk))),
              HaloPrimaryButton(
                label: l10n.translateResume,
                onTap: () => dl.start(lang),
              ),
            ]);
          case DlPhase.failed:
            children.addAll([
              line(failLine(s.fail), color: HaloColors.rose),
              if (s.fail != DlFail.noEngine)
                HaloPrimaryButton(
                  label: l10n.commonTryAgain,
                  onTap: () => dl.start(lang),
                ),
            ]);
          case DlPhase.installed:
            children.addAll([
              line(l10n.translateInstalled(packSize(s.onDisk))),
              if (onDone != null)
                HaloPrimaryButton(label: l10n.commonDone, onTap: onDone),
            ]);
          case DlPhase.unknown:
          case DlPhase.absent:
            children.add(
              HaloPrimaryButton(
                label: l10n.translateDownload(size),
                onTap: () => dl.start(lang),
              ),
            );
        }
        return EaseSize(
          duration: kHouseTime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );
      },
    );
  }
}

// the sheet a "translate" tap opens when a pack or the library is missing
Future<void> showPackSheet(
  BuildContext context, {
  required TranslationHub hub,
  required String language,
  required List<LangBundle> missing,
  required TranslateBlock why,
}) {
  return showHaloSheet<void>(
    context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text(
              l10n.translatePackTitle(language),
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            for (final b in missing) ...[
              Text(
                l10n.translatePackLine(langName(b.lang), packSize(b.gz)),
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              PackControls(
                hub: hub,
                bundle: b,
                onDone: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 12),
            ],
            if (why == TranslateBlock.noLib) ...[
              Text(
                l10n.translatePackNoLib,
                style: HaloType.mono(size: 11, color: HaloColors.text3),
              ),
              const SizedBox(height: 4),
            ],
            if (missing.isEmpty) ...[
              const SizedBox(height: 12),
              HaloPrimaryButton(
                label: l10n.commonDone,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
