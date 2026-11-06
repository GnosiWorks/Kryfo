// SPDX-License-Identifier: GPL-3.0-or-later
// every language there is a pack for: its download size, how far it got,
// download and remove, and which ways it goes with english. the app's
// language and the ones the person reads come first. a language with no
// pack is not listed
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart' show kLanguageNames;
import '../l10n/l10n.dart';
import '../theme.dart';
import '../translate/catalog.dart';
import '../translate/downloads.dart';
import '../translate/foreign.dart' show baseLang;
import '../translate/hub.dart';
import '../translate/lang_names.dart';
import '../translate/pack_sheet.dart' show PackBar, failLine;
import '../widgets/confirm_sheet.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_rows.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime, motionStill;
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../wide/read_width.dart' show DeskPage;

// the app's language, then the ones the person reads, then the rest by
// name; each list in that order
(List<String>, List<String>) orderLanguages(
  TranslateCatalog catalog, {
  required String appLang,
  required List<String> mine,
}) {
  final all = catalog.languages;
  final first = <String>[];
  for (final l in [baseLang(appLang), for (final m in mine) baseLang(m)]) {
    if (all.contains(l) && !first.contains(l)) first.add(l);
  }
  final rest = [
    for (final l in all)
      if (!first.contains(l)) l,
  ]..sort((a, b) => langName(a).compareTo(langName(b)));
  return (first, rest);
}

class TranslateLanguagesScreen extends StatefulWidget {
  final TranslationHub hub;
  const TranslateLanguagesScreen({super.key, required this.hub});

  @override
  State<TranslateLanguagesScreen> createState() =>
      _TranslateLanguagesScreenState();
}

class _TranslateLanguagesScreenState extends State<TranslateLanguagesScreen> {
  TranslationHub get hub => widget.hub;

  @override
  void initState() {
    super.initState();
    hub.ready();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(
          l10n.translateLanguagesSection,
          style: HaloType.pageTitle(),
        ),
      ),
      body: DeskPage(
        child: ListenableBuilder(
          listenable: hub,
          builder: (context, _) {
            final app = baseLang(hub.appLang());
            final mine = {for (final m in hub.settings.mine) baseLang(m)};
            final (first, rest) = orderLanguages(
              hub.catalog,
              appLang: hub.appLang(),
              mine: hub.settings.mine,
            );
            Widget group(List<String> langs) => HaloGroup(
              children: [
                for (final l in langs)
                  _LangRow(
                    key: ValueKey('lang-$l'),
                    hub: hub,
                    lang: l,
                    tag: l == app
                        ? l10n.translateTagApp
                        : mine.contains(l)
                        ? l10n.translateTagRead
                        : null,
                  ),
              ],
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              children: staggerAllIn(context, [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 0),
                  child: Text(
                    l10n.translateLanguagesHintShown,
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text,
                      height: 1.4,
                    ),
                  ),
                ),
                if (first.isNotEmpty) ...[
                  HaloSection(l10n.translateSuggested),
                  group(first),
                ],
                if (rest.isNotEmpty) ...[
                  HaloSection(
                    first.isEmpty
                        ? l10n.translateLanguagesSection
                        : l10n.translateMoreLanguages,
                  ),
                  group(rest),
                ],
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _LangRow extends StatelessWidget {
  final TranslationHub hub;
  final String lang;
  // why it is suggested
  final String? tag;
  const _LangRow({super.key, required this.hub, required this.lang, this.tag});

  Future<void> _remove(BuildContext context, DlState s) async {
    HapticFeedback.selectionClick();
    final name = langName(lang);
    final ok = await showConfirmSheet(
      context,
      title: l10n.translateRemoveTitle(name),
      line: l10n.translateRemoveLine(
        packSize(s.onDisk > 0 ? s.onDisk : hub.catalog.sizeOf(lang)),
      ),
      yes: l10n.translateRemove,
    );
    if (!ok) return;
    HapticFeedback.mediumImpact();
    await hub.removeLang(lang);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hub.downloads,
      builder: (context, _) {
        final s = hub.langState(lang);
        final name = langName(lang);
        final native = kLanguageNames[lang];
        final size = hub.langLeft(lang);
        final ways = switch (hub.catalog.waysOf(lang)) {
          LangWays.intoEnglish => l10n.translateWaysInto,
          LangWays.fromEnglish => l10n.translateWaysFrom,
          _ => l10n.translateWaysBoth,
        };
        final finishing = s.busy && s.total > 0 && s.done >= s.total;
        final status = switch (s.phase) {
          DlPhase.installed => l10n.translateInstalledShown(packSize(s.onDisk)),
          DlPhase.starting || DlPhase.running =>
            finishing
                ? l10n.translateFinishing
                : l10n.translateProgress(packSize(s.done), packSize(s.total)),
          DlPhase.wifiNeeded => l10n.translateWaitsWifiShort,
          DlPhase.paused => l10n.translatePaused(packSize(s.onDisk)),
          DlPhase.failed => failLine(s.fail),
          _ => l10n.translateNotDownloaded(packSize(size)),
        };
        final still = motionStill(context);
        final text = HaloType.sans(
          size: 12.5,
          color: HaloColors.text,
          height: 1.35,
        );
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: s.phase == DlPhase.installed
                          ? HaloColors.amber
                          : HaloColors.amberSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: still ? Duration.zero : kHouseTime,
                      switchInCurve: kHouseCurve,
                      child: Icon(
                        s.phase == DlPhase.installed
                            ? Icons.check_rounded
                            : Icons.translate_rounded,
                        key: ValueKey(s.phase == DlPhase.installed),
                        size: 17,
                        color: s.phase == DlPhase.installed
                            ? HaloColors.onAmber
                            : HaloColors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                name,
                                style: HaloType.sans(
                                  size: 14.5,
                                  weight: FontWeight.w600,
                                  color: HaloColors.text,
                                ),
                              ),
                              if (native != null &&
                                  native.toLowerCase() != name.toLowerCase())
                                Text(native, style: text),
                              if (tag != null) _Tag(tag!),
                            ],
                          ),
                          const SizedBox(height: 2),
                          AnimatedSwitcher(
                            duration: still ? Duration.zero : kHouseTime,
                            switchInCurve: kHouseCurve,
                            switchOutCurve: kHouseCurve,
                            layoutBuilder: (cur, prev) => Stack(
                              alignment: AlignmentDirectional.topStart,
                              children: [...prev, ?cur],
                            ),
                            child: Text(
                              status,
                              key: ValueKey('status-${s.phase}'),
                              style: text.copyWith(
                                color: s.phase == DlPhase.failed
                                    ? HaloColors.rose
                                    : null,
                                fontFeatures: s.busy
                                    ? const [FontFeature.tabularFigures()]
                                    : null,
                              ),
                            ),
                          ),
                          Text(ways, key: ValueKey('ways-$lang'), style: text),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _action(context, s, name, size),
                ],
              ),
              EaseSize(
                duration: kHouseTime,
                child: s.busy
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 44,
                          top: 10,
                        ),
                        child: PackBar(s.share ?? 0),
                      )
                    : s.phase == DlPhase.wifiNeeded
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 36,
                            top: 2,
                          ),
                          child: TextButton(
                            key: ValueKey('anyway-$lang'),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              hub.downloadLang(lang, anyNetwork: true);
                            },
                            child: Text(
                              l10n.translateDownloadAnyway,
                              style: HaloType.sans(
                                size: 13,
                                weight: FontWeight.w600,
                                color: HaloColors.amberText,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }

  // the one thing to do now
  Widget _action(BuildContext context, DlState s, String name, int size) {
    void get() {
      HapticFeedback.selectionClick();
      hub.downloadLang(lang);
    }

    void stop() {
      HapticFeedback.selectionClick();
      hub.cancelLang(lang);
    }

    final (label, tap, kind) = switch (s.phase) {
      DlPhase.installed => (
        l10n.translateRemove,
        () => _remove(context, s),
        _Kind.rose,
      ),
      DlPhase.starting ||
      DlPhase.running ||
      DlPhase.wifiNeeded => (l10n.commonCancel, stop, _Kind.quiet),
      DlPhase.paused => (l10n.translateResumeShort, get, _Kind.amber),
      DlPhase.failed => (l10n.commonTryAgain, get, _Kind.amber),
      _ => (l10n.translateGet, get, _Kind.amber),
    };
    final remove = s.phase != DlPhase.installed && s.onDisk > 0 && !s.busy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (remove)
          IconButton(
            key: ValueKey('remove-$lang'),
            tooltip: l10n.translateRemove,
            icon: Icon(Icons.delete_outline, size: 20, color: HaloColors.rose),
            onPressed: () => _remove(context, s),
          ),
        _Pill(
          key: ValueKey('act-$lang'),
          label: label,
          // a screen reader hears which language and how much
          semantics: s.phase == DlPhase.absent || s.phase == DlPhase.unknown
              ? '$label, $name, ${packSize(size)}'
              : '$label, $name',
          kind: kind,
          onTap: tap,
        ),
      ],
    );
  }
}

enum _Kind { amber, quiet, rose }

class _Pill extends StatelessWidget {
  final String label;
  final String semantics;
  final _Kind kind;
  final VoidCallback onTap;
  const _Pill({
    super.key,
    required this.label,
    required this.semantics,
    required this.kind,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = kind == _Kind.amber ? HaloColors.amber : Colors.transparent;
    final ink = switch (kind) {
      _Kind.amber => HaloColors.onAmber,
      _Kind.rose => HaloColors.rose,
      _Kind.quiet => HaloColors.text,
    };
    return PressScale(
      label: semantics,
      onTap: onTap,
      scale: 0.94,
      haptic: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
        child: AnimatedContainer(
          duration: motionStill(context) ? Duration.zero : kHouseTime,
          curve: kHouseCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: kind == _Kind.amber
                ? null
                : Border.all(
                    color: kind == _Kind.rose
                        ? HaloColors.rose.withValues(alpha: 0.5)
                        : HaloColors.line2,
                  ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 13, weight: FontWeight.w600, color: ink),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: HaloColors.amberSoft,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: HaloType.sans(
        size: 11,
        weight: FontWeight.w600,
        color: HaloColors.amberText,
      ),
    ),
  );
}
