// SPDX-License-Identifier: GPL-3.0-or-later
// which files come without a tap, kind by kind: on any network, on wi-fi
// only, or never. what is left waits on the file server as a card in its
// chat until it is tapped, a week at most
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../main.dart' show session;
import '../theme.dart';
import '../transfers.dart';
import '../widgets/halo_rows.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/stagger_in.dart';
import '../wide/read_width.dart' show DeskPage;

String autoGetName(AutoGet v) => switch (v) {
  AutoGet.always => l10n.autoGetAlways,
  AutoGet.wifi => l10n.autoGetWifi,
  AutoGet.never => l10n.autoGetNever,
};

String getKindName(GetKind k) => switch (k) {
  GetKind.photo => l10n.autoGetPhotos,
  GetKind.video => l10n.autoGetVideos,
  GetKind.file => l10n.autoGetFiles,
};

IconData _glyph(GetKind k) => switch (k) {
  GetKind.photo => Icons.image_outlined,
  GetKind.video => Icons.movie_outlined,
  GetKind.file => Icons.insert_drive_file_outlined,
};

class AutoGetScreen extends StatefulWidget {
  const AutoGetScreen({super.key});

  @override
  State<AutoGetScreen> createState() => _AutoGetScreenState();
}

class _AutoGetScreenState extends State<AutoGetScreen> {
  Map<GetKind, AutoGet>? _set;

  @override
  void initState() {
    super.initState();
    loadAutoGet(session.container).then((v) {
      if (mounted) setState(() => _set = v);
    });
  }

  Future<void> _pick(GetKind k) async {
    final now = _set;
    if (now == null) return;
    final v = await showHaloSheet<AutoGet>(
      context,
      builder: (ctx) => _ChoiceSheet(
        title: getKindName(k),
        on: now[k]!,
        onPick: (v) => Navigator.pop(ctx, v),
      ),
    );
    if (v == null || v == now[k] || !mounted) return;
    HapticFeedback.selectionClick();
    await saveAutoGet(k, v, session.container);
    if (mounted) setState(() => _set = {...now, k: v});
  }

  @override
  Widget build(BuildContext context) {
    final set = _set;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(l10n.autoGetTitle, style: HaloType.pageTitle()),
      ),
      body: DeskPage(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: staggerAllIn(context, [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
              child: Text(
                l10n.autoGetLine,
                style: HaloType.sans(size: 13, color: HaloColors.text),
              ),
            ),
            HaloGroup(
              children: [
                for (final k in kAutoGetChoices)
                  HaloRow(
                    icon: _glyph(k),
                    label: getKindName(k),
                    value: set == null ? null : autoGetName(set[k]!),
                    pending: set == null,
                    onTap: set == null ? null : () => _pick(k),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                '${l10n.autoGetVoice} ${l10n.autoGetFilesWait}',
                style: HaloType.sans(size: 12.5, color: HaloColors.text),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  final String title;
  final AutoGet on;
  final ValueChanged<AutoGet> onPick;
  const _ChoiceSheet({
    required this.title,
    required this.on,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
            const SizedBox(height: 12),
            for (final v in AutoGet.values)
              Semantics(
                selected: v == on,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onPick(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          v == on
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: v == on ? HaloColors.amber : HaloColors.text3,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            autoGetName(v),
                            style: HaloType.sans(
                              size: 14,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
