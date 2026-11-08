// SPDX-License-Identifier: GPL-3.0-or-later
// the speech model before, during and after its one download: what it is,
// its size, where it comes from and that the notes stay here. the download
// starts only from its own button.
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme.dart';
import '../../translate/downloads.dart' show DlFail;
import '../../translate/lang_names.dart' show packSize;
import '../../translate/pack_sheet.dart' show DownloadControls, failLine;
import '../../widgets/halo_buttons.dart';
import '../../widgets/halo_sheet.dart';
import '../../widgets/sheet_handle.dart';
import '../voice_transcripts.dart';

String voiceFailLine(DlFail? f) =>
    f == DlFail.noTor ? l10n.voiceModelFailNoTor : failLine(f);

// the model's controls, in the sheet and on the settings page
class VoiceModelControls extends StatelessWidget {
  final VoiceTranscripts hub;
  final VoidCallback? onDone;
  const VoiceModelControls({super.key, required this.hub, this.onDone});

  @override
  Widget build(BuildContext context) => DownloadControls(
    downloads: hub.downloads,
    id: kVoiceModelId,
    size: hub.modelSize,
    failText: voiceFailLine,
    onDone: onDone,
  );
}

// the sheet the first "See transcription" opens while the model is not on
// the phone
Future<void> showVoiceModelSheet(BuildContext context, VoiceTranscripts hub) {
  final body = HaloType.sans(size: 12.5, color: HaloColors.text, height: 1.45);
  return showHaloSheet<void>(
    context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          key: const ValueKey('voice-model-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text(
              l10n.voiceOnRow,
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            Text(l10n.voiceModelLine(packSize(hub.modelSize)), style: body),
            const SizedBox(height: 6),
            Text(l10n.voiceModelPrivacyShown, style: body),
            const SizedBox(height: 16),
            VoiceModelControls(hub: hub, onDone: () => Navigator.of(ctx).pop()),
            ListenableBuilder(
              listenable: hub.downloads,
              builder: (context, _) => hub.modelReady
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: HaloGhostButton(
                        label: l10n.voiceNotNow,
                        quiet: true,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
