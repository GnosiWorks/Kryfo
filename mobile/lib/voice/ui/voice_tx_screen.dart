// SPDX-License-Identifier: GPL-3.0-or-later
// voice transcription's settings: on or off, the speech model on the
// phone, and what stays private. the transcribing itself happens on the
// phone.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../theme.dart';
import '../../translate/downloads.dart';
import '../../translate/lang_names.dart' show packSize;
import '../../widgets/confirm_sheet.dart';
import '../../widgets/halo_rows.dart';
import '../../widgets/stagger_in.dart';
import '../voice_transcripts.dart';
import 'model_sheet.dart';
import '../../wide/read_width.dart' show DeskPage;

class VoiceTxScreen extends StatefulWidget {
  final VoiceTranscripts hub;
  const VoiceTxScreen({super.key, required this.hub});

  @override
  State<VoiceTxScreen> createState() => _VoiceTxScreenState();
}

class _VoiceTxScreenState extends State<VoiceTxScreen> {
  VoiceTranscripts get hub => widget.hub;
  bool _read = false;

  @override
  void initState() {
    super.initState();
    hub.ready().then((_) {
      if (mounted) setState(() => _read = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = HaloType.sans(size: 12.5, color: HaloColors.text, height: 1.4);
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(l10n.voiceSettingsTitle, style: HaloType.pageTitle()),
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
                      key: const ValueKey('voice-tx-on'),
                      icon: Icons.notes_rounded,
                      label: l10n.voiceOnRow,
                      hint: l10n.voiceOnHint,
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
                  key: const ValueKey('voice-tx-off-note'),
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 0),
                  child: Text(l10n.voiceOffDeletes, style: note),
                ),
                HaloSection(l10n.voiceModelTitle),
                _ModelCard(hub: hub),
                HaloSection(l10n.translatePrivacyTitle),
                Container(
                  key: const ValueKey('voice-tx-privacy'),
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
                          '${l10n.voiceModelPrivacyShown} '
                          '${l10n.voiceKeptNoteShown}',
                          style: note.copyWith(height: 1.45),
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
}

// the one model: what it takes, and the way to get it or let it go. the
// transcripts made stay when it goes
class _ModelCard extends StatelessWidget {
  final VoiceTranscripts hub;
  const _ModelCard({required this.hub});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hub.downloads,
      builder: (context, _) {
        final s = hub.downloads.of(kVoiceModelId);
        final status = switch (s.phase) {
          DlPhase.installed => l10n.translateInstalledShown(packSize(s.onDisk)),
          DlPhase.running || DlPhase.starting => l10n.translateDownloading,
          _ => l10n.translateNotDownloaded(packSize(hub.modelSize)),
        };
        return Container(
          key: const ValueKey('voice-model'),
          padding: const EdgeInsets.all(14),
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
                      Icons.graphic_eq_rounded,
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
                          l10n.voiceModelTitle,
                          style: HaloType.sans(
                            size: 14,
                            color: HaloColors.text,
                          ),
                        ),
                        Text(
                          status,
                          style: HaloType.sans(
                            size: 12.5,
                            color: HaloColors.text,
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
                      key: const ValueKey('voice-model-remove'),
                      tooltip: l10n.commonRemove,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: HaloColors.rose,
                      ),
                      onPressed: () async {
                        final ok = await showConfirmSheet(
                          context,
                          title: l10n.voiceModelRemoveTitle,
                          line: l10n.voiceModelRemoveLine,
                          yes: l10n.commonRemove,
                        );
                        if (ok) await hub.downloads.remove(kVoiceModelId);
                      },
                    ),
                ],
              ),
              if (s.phase != DlPhase.installed) ...[
                const SizedBox(height: 14),
                VoiceModelControls(hub: hub),
              ],
            ],
          ),
        );
      },
    );
  }
}
