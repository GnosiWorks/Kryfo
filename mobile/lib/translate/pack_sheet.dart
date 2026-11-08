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
  DlFail.noEngine => l10n.translateFailNoEngineShown,
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

// what can be done with packs now, a language's or a route's, as one
// download: their size together, how far they got, a way to stop and to
// try again. asked for off wi-fi with wi-fi only on, it waits and goes on
// by itself
class PackControls extends StatelessWidget {
  final TranslationHub hub;
  final List<LangBundle> packs;
  // the sheet closes on done; the settings page has nothing to close
  final VoidCallback? onDone;
  const PackControls({
    super.key,
    required this.hub,
    required this.packs,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final dl = hub.downloads;
    final ids = [for (final b in packs) b.id];
    return ListenableBuilder(
      listenable: dl,
      builder: (context, _) {
        final left = [
          for (final b in packs)
            if (!dl.installed(b.id)) b.gz,
        ].fold(0, (n, g) => n + g);
        return _Controls(
          s: dl.ofMany(ids, [for (final b in packs) b.gz]),
          size: left,
          failText: failLine,
          waitLine: l10n.translateWaitsWifiShown,
          start: ({bool anyNetwork = false}) =>
              dl.startMany(ids, anyNetwork: anyNetwork),
          cancel: () => dl.cancelMany(ids),
          onDone: onDone,
        );
      },
    );
  }
}

// one download's controls, the speech model's: its size first, then how
// far it got, with a way to stop it and to try again
class DownloadControls extends StatelessWidget {
  final ModelDownloads downloads;
  final String id;
  // what it takes once fetched
  final int size;
  final String Function(DlFail? f) failText;
  final VoidCallback? onDone;
  const DownloadControls({
    super.key,
    required this.downloads,
    required this.id,
    required this.size,
    required this.failText,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) => _Controls(
        s: downloads.of(id),
        size: size,
        failText: failText,
        waitLine: l10n.translateNeedsWifiShown,
        start: ({bool anyNetwork = false}) =>
            downloads.start(id, anyNetwork: anyNetwork),
        cancel: () => downloads.cancel(id),
        onDone: onDone,
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final DlState s;
  final int size;
  final String Function(DlFail? f) failText;
  final String waitLine;
  final Future<void> Function({bool anyNetwork}) start;
  final VoidCallback cancel;
  final VoidCallback? onDone;
  const _Controls({
    required this.s,
    required this.size,
    required this.failText,
    required this.waitLine,
    required this.start,
    required this.cancel,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final size = packSize(this.size);
    Widget line(String t, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        t,
        style: HaloType.sans(
          size: 12.5,
          color: color ?? HaloColors.text,
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
                    packSize(s.total > 0 ? s.total : this.size),
                  ),
            key: const ValueKey('pack-progress'),
            style: HaloType.mono(size: 11, color: HaloColors.text),
          ),
          const SizedBox(height: 12),
          HaloGhostButton(label: l10n.commonCancel, quiet: true, onTap: cancel),
        ]);
      case DlPhase.wifiNeeded:
        children.addAll([
          line(waitLine),
          HaloPrimaryButton(
            label: l10n.translateDownloadAnyway,
            onTap: () => start(anyNetwork: true),
          ),
        ]);
      case DlPhase.paused:
        children.addAll([
          if (s.onDisk > 0) line(l10n.translatePaused(packSize(s.onDisk))),
          HaloPrimaryButton(label: l10n.translateResume, onTap: start),
        ]);
      case DlPhase.failed:
        children.addAll([
          line(failText(s.fail), color: HaloColors.rose),
          if (s.fail != DlFail.noEngine)
            HaloPrimaryButton(label: l10n.commonTryAgain, onTap: start),
        ]);
      case DlPhase.installed:
        children.addAll([
          line(l10n.translateInstalledShown(packSize(s.onDisk))),
          if (onDone != null)
            HaloPrimaryButton(label: l10n.commonDone, onTap: onDone),
        ]);
      case DlPhase.unknown:
      case DlPhase.absent:
        children.add(
          HaloPrimaryButton(label: l10n.translateDownload(size), onTap: start),
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
  }
}

// the sheet a "translate" tap opens when a pack or the library is missing.
// without the library a pack would be no use, so none is offered
Future<void> showPackSheet(
  BuildContext context, {
  required TranslationHub hub,
  required String language,
  required List<LangBundle> missing,
  required TranslateBlock why,
}) {
  final noLib = why == TranslateBlock.noLib;
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
              l10n.translatePackTitleShown(language),
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            if (!noLib && missing.isNotEmpty) ...[
              Text(
                _packLine(missing),
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              PackControls(
                hub: hub,
                packs: missing,
                onDone: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 12),
            ],
            if (noLib) ...[
              Text(
                l10n.translatePackNoLibShown,
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (noLib || missing.isEmpty) ...[
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

// what the packs are, by language, and their size together
String _packLine(List<LangBundle> packs) {
  final langs = [
    ...{for (final b in packs) ...b.langs},
  ];
  final size = packSize(packs.fold(0, (n, b) => n + b.gz));
  if (langs.length >= 2) {
    return l10n.translatePackLineTwoShown(
      langName(langs[0]),
      langName(langs[1]),
      size,
    );
  }
  return l10n.translatePackLineShown(
    langName(langs.isEmpty ? '' : langs.first),
    size,
  );
}
