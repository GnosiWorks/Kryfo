// SPDX-License-Identifier: GPL-3.0-or-later
// Kryfo's licence and source, libsignal's licence and source, and the parts
// each piece of the app is built from: the dart packages and data files, the
// signal library's crates, the engine's go modules and c libraries, and,
// once their switches are on, the voice and translation libraries' parts
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../licences.dart';
import '../theme.dart';
import '../translate/hub_live.dart' show kOfflineTranslation;
import '../voice/voice_transcripts.dart' show kVoiceTranscripts;
import '../widgets/halo_rows.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/stagger_in.dart';
import '../wide/read_width.dart' show DeskPage;

const _kryfoSource = 'https://github.com/GnosiWorks/Kryfo';
const _signalSource = 'https://github.com/signalapp/libsignal';
// where a licence text is when its asset will not load
const _gplLink = 'https://www.gnu.org/licenses/gpl-3.0.txt';
const _agplLink = 'https://www.gnu.org/licenses/agpl-3.0.txt';

class LicencesScreen extends StatefulWidget {
  const LicencesScreen({
    super.key,
    this.rust,
    this.dart,
    this.engine,
    this.gpl,
    this.native,
    this.voice = kVoiceTranscripts,
    this.translation = kOfflineTranslation,
  });

  // for tests: what the screen would load
  final Future<RustLicences>? rust;
  final Future<List<LicencedPart>>? dart;
  final Future<EngineLicences>? engine;
  final Future<String>? gpl;
  final Future<NativeLicences>? native;
  // their libraries ship only with their switches, and their notices with them
  final bool voice;
  final bool translation;

  @override
  State<LicencesScreen> createState() => _LicencesScreenState();
}

// one thing the screen loads: still coming, there, or failed
class _Load<T> {
  T? value;
  bool failed = false;
  bool get pending => value == null && !failed;
}

class _LicencesScreenState extends State<LicencesScreen> {
  final _rust = _Load<RustLicences>();
  final _dart = _Load<List<LicencedPart>>();
  final _engine = _Load<EngineLicences>();
  final _gpl = _Load<String>();
  final _native = _Load<NativeLicences>();

  @override
  void initState() {
    super.initState();
    _watch(widget.rust ?? loadRustLicences(), _rust);
    _watch(widget.dart ?? loadDartLicences(), _dart);
    _watch(widget.engine ?? loadEngineLicences(), _engine);
    _watch(widget.gpl ?? loadGpl(), _gpl);
    if (widget.voice || widget.translation) {
      _watch(widget.native ?? loadNativeLicences(), _native);
    }
  }

  void _watch<T>(Future<T> future, _Load<T> slot) {
    future.then(
      (v) {
        if (mounted) setState(() => slot.value = v);
      },
      onError: (Object e) {
        dlog('licences: a list did not load: $e');
        if (mounted) setState(() => slot.failed = true);
      },
    );
  }

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showHaloToast(context, l10n.settingsLinkCopied);
  }

  void _open(Widget page) => Navigator.of(context).push(haloRoute(page));

  // a licence text: opens when loaded, and becomes a link to the same text
  // on gnu.org when its asset fails
  Widget _textRow(String label, String title, _Load<String> text, String link) {
    if (text.failed) {
      return HaloRow(
        icon: Icons.gavel_outlined,
        label: label,
        value: link.replaceFirst('https://www.', ''),
        tapHint: l10n.settingsCopyLinkHint,
        onTap: () => _copy(link),
      );
    }
    // the chevron shows while it loads, so the label never rewraps
    return HaloRow(
      icon: Icons.gavel_outlined,
      label: label,
      pending: text.pending,
      onTap: () => _open(_TextScreen(title: title, texts: [text.value!])),
    );
  }

  // a list of parts: its count once loaded, a calm line when it failed.
  // while it loads a count of about the same width and the chevron hold the
  // place
  Widget _listRow(
    IconData icon,
    String label,
    List<LicencedPart>? parts, {
    required bool failed,
  }) {
    return HaloRow(
      icon: icon,
      label: label,
      value: failed
          ? l10n.licencesLoadFailed
          : l10n.licencesPartCount(parts?.length ?? 100),
      pending: !failed && parts == null,
      onTap: failed
          ? null
          : () => _open(_PartsScreen(title: label, parts: parts!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rust = _rust.value;
    final engine = _engine.value;
    final dart = _dart.value;
    final native = _native.value;
    final app = dart == null || engine == null
        ? null
        : appParts(dart, engine.data);
    final agpl = _Load<String>()
      ..value = rust?.agpl
      ..failed = _rust.failed;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: _bar(l10n.settingsLicences),
      body: DeskPage(
        child: SafeArea(
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
                  _textRow(l10n.licencesGplText, 'GNU GPL 3.0', _gpl, _gplLink),
                  HaloRow(
                    icon: Icons.code,
                    label: l10n.licencesSourceCode,
                    value: 'github.com/GnosiWorks/Kryfo',
                    tapHint: l10n.settingsCopyLinkHint,
                    onTap: () => _copy(_kryfoSource),
                  ),
                ],
              ),
              HaloSection(l10n.licencesSignalTitle),
              // the tag is known before anything loads, so the line never
              // moves the rows below it
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 14),
                child: Text(
                  l10n.licencesSignalLine(kLibsignalTag),
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text,
                    height: 1.5,
                  ),
                ),
              ),
              HaloGroup(
                children: [
                  _textRow(
                    l10n.licencesAgplText,
                    'GNU AGPL 3.0',
                    agpl,
                    _agplLink,
                  ),
                  HaloRow(
                    icon: Icons.code,
                    label: l10n.licencesSignalSource,
                    value: 'github.com/signalapp/libsignal',
                    tapHint: l10n.settingsCopyLinkHint,
                    onTap: () => _copy(_signalSource),
                  ),
                ],
              ),
              HaloSection(l10n.licencesParts),
              HaloGroup(
                children: [
                  _listRow(
                    Icons.widgets_outlined,
                    l10n.licencesInApp,
                    app,
                    failed: _dart.failed || _engine.failed,
                  ),
                  _listRow(
                    Icons.lock_outline,
                    l10n.licencesInSignal,
                    rust?.crates,
                    failed: _rust.failed,
                  ),
                  _listRow(
                    Icons.hub_outlined,
                    l10n.licencesInEngine,
                    engine?.parts,
                    failed: _engine.failed,
                  ),
                  if (widget.voice)
                    _listRow(
                      Icons.graphic_eq,
                      l10n.licencesInVoice,
                      native?.voice,
                      failed: _native.failed,
                    ),
                  if (widget.translation)
                    _listRow(
                      Icons.translate,
                      l10n.licencesInTranslation,
                      native?.translation,
                      failed: _native.failed,
                    ),
                ],
              ),
            ]),
          ),
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
      body: DeskPage(
        child: SafeArea(
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
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      12,
                      16,
                      12,
                    ),
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
                                      color: HaloColors.text,
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
      body: DeskPage(
        child: SafeArea(
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
      ),
    );
  }
}
