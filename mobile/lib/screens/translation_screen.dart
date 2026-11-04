// SPDX-License-Identifier: GPL-3.0-or-later
// translation's settings: on or off, the language packs on the phone, the
// languages the person reads and the ones never offered, what to translate
// into, and what a download says to whom. the translating itself happens
// on the phone.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart' show availableLanguages, kLanguageNames;
import '../l10n/l10n.dart';
import '../theme.dart';
import '../translate/catalog.dart';
import '../translate/downloads.dart';
import '../translate/hub.dart';
import '../translate/lang_names.dart';
import '../translate/pack_sheet.dart';
import '../translate/settings.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_rows.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime, motionStill;
import '../widgets/sheet_handle.dart';
import '../widgets/stagger_in.dart';
import '../wide/read_width.dart' show DeskPage;

class TranslationScreen extends StatefulWidget {
  final TranslationHub hub;
  const TranslationScreen({super.key, required this.hub});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  TranslationHub get hub => widget.hub;
  bool _read = false;

  @override
  void initState() {
    super.initState();
    hub.ready().then((_) {
      if (mounted) setState(() => _read = true);
    });
  }

  Future<void> _save(TranslateSettings s) async {
    HapticFeedback.selectionClick();
    await hub.saveSettings(s);
  }

  String _mineValue(TranslateSettings s) {
    final app = hub.appLang();
    return [
      langName(app),
      for (final l in s.mine)
        if (l != app) langName(l),
    ].join(', ');
  }

  String _targetValue(TranslateSettings s) =>
      s.target.isEmpty ? l10n.translateAppLanguage : langName(s.target);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(l10n.translateSettingsTitle, style: HaloType.pageTitle()),
      ),
      body: DeskPage(
        child: ListenableBuilder(
          listenable: hub,
          builder: (context, _) {
            final s = hub.settings;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              children: staggerAll([
                HaloGroup(
                  children: [
                    HaloRow(
                      key: const ValueKey('translate-on'),
                      icon: Icons.translate_rounded,
                      label: l10n.translateSettingsRow,
                      hint: l10n.translateOnHint,
                      toggled: s.on,
                      pending: !_read,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        hub.setOn(!s.on);
                      },
                    ),
                  ],
                ),
                Padding(
                  key: const ValueKey('translate-off-note'),
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 0),
                  child: Text(
                    l10n.translateOffDeletes,
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text2,
                      height: 1.4,
                    ),
                  ),
                ),
                HaloSection(l10n.translatePacksSection),
                for (final (i, b) in hub.catalog.langs.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                    child: _PackCard(hub: hub, bundle: b),
                  ),
                // the rest only matters while translation is on: it folds
                // away with the switch and back
                EaseSize(
                  duration: kHouseTime,
                  child: AnimatedSwitcher(
                    duration: motionStill(context) ? Duration.zero : kHouseTime,
                    switchInCurve: kHouseCurve,
                    switchOutCurve: kHouseCurve,
                    layoutBuilder: (cur, prev) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...prev, ?cur],
                    ),
                    child: s.on
                        ? Column(
                            key: const ValueKey('translate-on-rest'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _whileOn(context, s),
                          )
                        : const SizedBox(
                            key: ValueKey('translate-off-rest'),
                            width: double.infinity,
                          ),
                  ),
                ),
                HaloSection(l10n.translatePrivacyTitle),
                Container(
                  key: const ValueKey('translate-privacy'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HaloColors.line, width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        size: 18,
                        color: HaloColors.amberText,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${l10n.translatePrivacyNoteShown} '
                          '${l10n.translatePrivacyKeptShown}',
                          style: HaloType.sans(
                            size: 12.5,
                            color: HaloColors.text2,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }

  // the languages, the ones never offered, and how chats and downloads go
  List<Widget> _whileOn(BuildContext context, TranslateSettings s) => [
    HaloSection(l10n.translateLanguagesSection),
    HaloGroup(
      children: [
        HaloRow(
          icon: Icons.menu_book_outlined,
          label: l10n.translateMyLanguages,
          hint: l10n.translateMyLanguagesHint,
          value: _mineValue(s),
          onTap: !_read
              ? null
              : () async {
                  final picked = await _pickMine(context, s);
                  if (picked != null) {
                    await _save(s.copyWith(mine: picked));
                  }
                },
        ),
        HaloRow(
          icon: Icons.translate_rounded,
          label: l10n.translateInto,
          value: _targetValue(s),
          onTap: !_read
              ? null
              : () async {
                  final t = await _pickTarget(context, s);
                  if (t != null) await _save(s.copyWith(target: t));
                },
        ),
      ],
    ),
    // each one taken off the list here is offered again
    EaseSize(
      duration: kHouseTime,
      child: s.never.isEmpty
          ? const SizedBox(width: double.infinity)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HaloSection(l10n.translateNeverSection),
                HaloGroup(
                  key: const ValueKey('translate-never'),
                  children: [
                    for (final l in s.never)
                      HaloRow(
                        key: ValueKey('never-$l'),
                        icon: Icons.do_not_disturb_on_outlined,
                        label: langName(l),
                        value: l10n.translateOfferAgain,
                        tapHint: l10n.translateOfferAgain,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          hub.offerAgain(l);
                        },
                      ),
                  ],
                ),
              ],
            ),
    ),
    HaloSection(l10n.translateBehaviourSection),
    HaloGroup(
      children: [
        HaloRow(
          icon: Icons.auto_awesome_outlined,
          label: l10n.translateAutoDefault,
          hint: l10n.translateAutoDefaultHint,
          toggled: s.autoDefault,
          pending: !_read,
          onTap: () => _save(s.copyWith(autoDefault: !s.autoDefault)),
        ),
        HaloRow(
          icon: Icons.wifi_rounded,
          label: l10n.translateWifiOnly,
          toggled: s.wifiOnly,
          pending: !_read,
          onTap: () => _save(s.copyWith(wifiOnly: !s.wifiOnly)),
        ),
      ],
    ),
  ];

  Future<List<String>?> _pickMine(BuildContext context, TranslateSettings s) {
    final app = hub.appLang();
    final picked = {...s.mine};
    return showHaloSheet<List<String>>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _SheetFrame(
          title: l10n.translateMyLanguages,
          line: l10n.translateMyLanguagesHint,
          children: [
            for (final tag in availableLanguages)
              _PickRow(
                label: langName(tag),
                sub: kLanguageNames[tag] ?? tag,
                on: tag == app || picked.contains(tag),
                locked: tag == app,
                onTap: () => set(
                  () => picked.contains(tag)
                      ? picked.remove(tag)
                      : picked.add(tag),
                ),
              ),
            const SizedBox(height: 14),
            HaloPrimaryButton(
              label: l10n.commonDone,
              onTap: () => Navigator.pop(ctx, [
                for (final t in availableLanguages)
                  if (picked.contains(t) && t != app) t,
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickTarget(BuildContext context, TranslateSettings s) {
    final options = <String>[
      '',
      'en',
      for (final b in hub.catalog.langs) b.lang,
    ];
    return showHaloSheet<String>(
      context,
      builder: (ctx) => _SheetFrame(
        title: l10n.translateInto,
        children: [
          for (final t in options)
            _PickRow(
              label: t.isEmpty ? l10n.translateAppLanguage : langName(t),
              sub: t.isEmpty ? langName(hub.appLang()) : null,
              on: s.target == t,
              round: true,
              onTap: () => Navigator.pop(ctx, t),
            ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final TranslationHub hub;
  final LangBundle bundle;
  const _PackCard({required this.hub, required this.bundle});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hub.downloads,
      builder: (context, _) {
        final s = hub.downloads.of(bundle.lang);
        final name = langName(bundle.lang);
        final status = switch (s.phase) {
          DlPhase.installed => l10n.translateInstalledShown(packSize(s.onDisk)),
          DlPhase.running || DlPhase.starting => l10n.translateDownloading,
          _ => l10n.translateNotDownloaded(packSize(bundle.gz)),
        };
        return Container(
          key: ValueKey('pack-${bundle.lang}'),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HaloColors.line, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: HaloColors.amberSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.translate_rounded,
                      size: 17,
                      color: HaloColors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translatePackPair(name),
                          style: HaloType.sans(
                            size: 14,
                            color: HaloColors.text,
                          ),
                        ),
                        Text(
                          status,
                          style: HaloType.sans(
                            size: 12.5,
                            color: HaloColors.text2,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s.phase == DlPhase.installed ||
                      s.phase == DlPhase.paused ||
                      (s.phase == DlPhase.failed && s.onDisk > 0))
                    IconButton(
                      tooltip: l10n.commonDelete,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: HaloColors.rose,
                      ),
                      onPressed: () async {
                        final ok = await showConfirmSheet(
                          context,
                          title: l10n.translateDeleteTitle(name),
                          line: l10n.translateDeleteLine(name),
                          yes: l10n.commonDelete,
                        );
                        if (ok) await hub.downloads.remove(bundle.lang);
                      },
                    ),
                ],
              ),
              if (s.phase != DlPhase.installed) ...[
                const SizedBox(height: 14),
                PackControls(hub: hub, bundle: bundle),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final String? line;
  final List<Widget> children;
  const _SheetFrame({required this.title, this.line, required this.children});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text(
              title,
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            if (line != null) ...[
              const SizedBox(height: 6),
              Text(
                line!,
                style: HaloType.sans(size: 12.5, color: HaloColors.text2),
              ),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final String label;
  final String? sub;
  final bool on;
  // the app's own language: always read, never unticked
  final bool locked;
  final bool round;
  final VoidCallback onTap;
  const _PickRow({
    required this.label,
    this.sub,
    required this.on,
    required this.onTap,
    this.locked = false,
    this.round = false,
  });

  @override
  Widget build(BuildContext context) {
    final mark = round
        ? (on ? Icons.radio_button_checked : Icons.radio_button_unchecked)
        : (on ? Icons.check_box_rounded : Icons.check_box_outline_blank);
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: locked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                mark,
                size: 20,
                color: on
                    ? (locked ? HaloColors.text3 : HaloColors.amber)
                    : HaloColors.text3,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: HaloType.sans(size: 14, color: HaloColors.text),
                ),
              ),
              if (sub != null)
                Text(
                  sub!,
                  style: HaloType.sans(size: 12.5, color: HaloColors.text3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
