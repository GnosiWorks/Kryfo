// SPDX-License-Identifier: GPL-3.0-or-later
// Kryfo's licence and source, libsignal's licence and source, and every
// package the app and the signal library are built from
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../licences.dart';
import '../theme.dart';
import '../widgets/halo_rows.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';

const _kryfoSource = 'https://github.com/GnosiWorks/Kryfo';
const _signalSource = 'https://github.com/signalapp/libsignal';

class LicencesScreen extends StatefulWidget {
  const LicencesScreen({super.key, this.rust, this.dart});

  // for tests: what the screen would load
  final Future<RustLicences>? rust;
  final Future<List<LicencedPart>>? dart;

  @override
  State<LicencesScreen> createState() => _LicencesScreenState();
}

class _LicencesScreenState extends State<LicencesScreen> {
  RustLicences? _rust;
  List<LicencedPart>? _dart;

  @override
  void initState() {
    super.initState();
    (widget.rust ?? loadRustLicences()).then((r) {
      if (mounted) setState(() => _rust = r);
    });
    (widget.dart ?? loadDartLicences()).then((d) {
      if (mounted) setState(() => _dart = d);
    });
  }

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showHaloToast(context, l10n.settingsLinkCopied);
  }

  void _open(Widget page) => Navigator.of(context).push(haloRoute(page));

  @override
  Widget build(BuildContext context) {
    final rust = _rust;
    final dart = _dart;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: _bar(l10n.settingsLicences),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: staggerAll([
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 16),
              child: Text(
                l10n.licencesKryfoLine,
                style: HaloType.sans(
                  size: 14,
                  color: HaloColors.text,
                  height: 1.5,
                ),
              ),
            ),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.code,
                  label: l10n.licencesSourceCode,
                  value: 'github.com/GnosiWorks/Kryfo',
                  onTap: () => _copy(_kryfoSource),
                ),
              ],
            ),
            HaloSection(l10n.licencesSignalTitle),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 14),
              child: FadeSwap(
                child: Text(
                  key: ValueKey(rust != null),
                  rust == null ? '' : l10n.licencesSignalLine(rust.libsignal),
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text2,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.gavel_outlined,
                  label: l10n.licencesAgplText,
                  pending: rust == null,
                  onTap: rust == null
                      ? null
                      : () => _open(
                          _TextScreen(
                            title: 'GNU AGPL 3.0',
                            texts: [rust.agpl],
                          ),
                        ),
                ),
                HaloRow(
                  icon: Icons.code,
                  label: l10n.licencesSignalSource,
                  value: 'github.com/signalapp/libsignal',
                  onTap: () => _copy(_signalSource),
                ),
              ],
            ),
            HaloSection(l10n.licencesParts),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.lock_outline,
                  label: l10n.licencesInSignal,
                  value: rust == null
                      ? null
                      : l10n.licencesPartCount(rust.crates.length),
                  pending: rust == null,
                  onTap: rust == null
                      ? null
                      : () => _open(
                          _PartsScreen(
                            title: l10n.licencesInSignal,
                            parts: rust.crates,
                          ),
                        ),
                ),
                HaloRow(
                  icon: Icons.widgets_outlined,
                  label: l10n.licencesInApp,
                  value: dart == null
                      ? null
                      : l10n.licencesPartCount(dart.length),
                  pending: dart == null,
                  onTap: dart == null
                      ? null
                      : () => _open(
                          _PartsScreen(title: l10n.licencesInApp, parts: dart),
                        ),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

PreferredSizeWidget _bar(String title) => AppBar(
  backgroundColor: HaloColors.surface,
  elevation: 0,
  iconTheme: IconThemeData(color: HaloColors.text2),
  title: Text(title, style: HaloType.pageTitle()),
);

// a long list, built as it scrolls
class _PartsScreen extends StatelessWidget {
  const _PartsScreen({required this.title, required this.parts});
  final String title;
  final List<LicencedPart> parts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: _bar(title),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
          itemCount: parts.length,
          separatorBuilder: (_, _) => Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Container(height: 0.5, color: HaloColors.line),
          ),
          itemBuilder: (context, i) {
            final p = parts[i];
            final sub = [?p.version, ?p.licence].join(' · ');
            return StaggerIn(
              index: i,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  haloRoute(
                    _TextScreen(
                      title: p.version == null
                          ? p.name
                          : '${p.name} ${p.version}',
                      texts: p.texts,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: HaloType.sans(
                                size: 14,
                                color: HaloColors.text,
                              ),
                            ),
                            if (sub.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  sub,
                                  style: HaloType.sans(
                                    size: 12.5,
                                    color: HaloColors.text2,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // mirrors itself in rtl, as HaloRow's does
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: HaloColors.text3,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// licence texts are english and left to right whatever the app's language.
// split at blank lines, so a long one is laid out as it scrolls
class _TextScreen extends StatelessWidget {
  const _TextScreen({required this.title, required this.texts});
  final String title;
  final List<String> texts;

  @override
  Widget build(BuildContext context) {
    final blocks = [
      for (var t = 0; t < texts.length; t++) ...[
        if (t > 0) null,
        ...texts[t].trim().split(RegExp(r'\n\s*\n')),
      ],
    ];
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: _bar(title),
      body: SafeArea(
        child: SelectionArea(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: blocks.length,
            itemBuilder: (_, i) {
              final b = blocks[i];
              if (b == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Container(height: 0.5, color: HaloColors.line),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  b,
                  textDirection: TextDirection.ltr,
                  style: HaloType.mono(
                    size: 12,
                    weight: FontWeight.w400,
                    color: HaloColors.text,
                  ).copyWith(height: 1.5),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
