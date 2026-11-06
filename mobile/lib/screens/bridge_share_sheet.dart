// SPDX-License-Identifier: GPL-3.0-or-later
// one kept bridge, for a friend whose tor is blocked too: a code to scan
// from this screen, a copy, or the line in a chat's composer. never from a
// decoy, and nothing goes until the person sends it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/l10n.dart';
import '../main.dart' show appState, AppStateSession;
import '../theme.dart';
import '../widgets/copied_mark.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/qr_wipe.dart';
import '../widgets/sheet_handle.dart';
import 'forward_sheet.dart';

/// [line] as a code, a copy, or in a chat. a decoy gets nothing
Future<void> showBridgeShareSheet(BuildContext context, String line) async {
  if (appState.inDecoyView) return;
  await showHaloSheet<void>(
    context,
    builder: (_) => BridgeShareSheet(line: line.trim()),
  );
}

class BridgeShareSheet extends StatefulWidget {
  final String line;
  const BridgeShareSheet({super.key, required this.line});
  @override
  State<BridgeShareSheet> createState() => _BridgeShareSheetState();
}

class _BridgeShareSheetState extends State<BridgeShareSheet> {
  // bumped on each copy, for the tick on the button
  int _copies = 0;

  // the chat opens with the line in its composer, for the person to send
  Future<void> _toChat() async {
    final nav = Navigator.of(context);
    final id = await pickWordsChat(
      context,
      title: l10n.bridgesSendBridgeTo,
      empty: l10n.roomLinkNoContactsYet,
      words: widget.line,
    );
    if (id == null || !mounted || appState.inDecoyView) return;
    nav.pop();
    await landWords(nav.context, id, widget.line);
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 18),
            Text(
              l10n.bridgesShareThisBridge,
              style: HaloType.serif(
                size: 20,
                italic: true,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 18),
            // the code assembles corner to corner once the sheet is up
            Center(
              child: QrWipe(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  // dark on light in both themes: some scanners refuse an
                  // inverted code
                  decoration: BoxDecoration(
                    color: HaloColors.qrPaper,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Semantics(
                    label: l10n.bridgesShareThisBridge,
                    image: true,
                    child: QrImageView(
                      data: line,
                      version: QrVersions.auto,
                      size: 224,
                      backgroundColor: HaloColors.qrPaper,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: HaloColors.qrInk,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: HaloColors.qrInk,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.bridgesShareItPrivately,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.text,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _CopyButton(
              copies: _copies,
              onTap: () {
                copySensitive(line);
                HapticFeedback.selectionClick();
                setState(() => _copies++);
                showHaloToast(context, l10n.bridgesBridgeCopied);
              },
            ),
            const SizedBox(height: 4),
            Center(
              child: PressScale(
                label: l10n.roomLinkSendToAContact,
                scale: 0.94,
                haptic: false,
                onTap: _toChat,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  child: Text(
                    l10n.roomLinkSendToAContact,
                    semanticsLabel: '',
                    style: HaloType.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: HaloColors.violetText,
                    ),
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

// the one violet button: a tick takes the copy glyph's place for a moment
// after each copy
class _CopyButton extends StatelessWidget {
  final int copies;
  final VoidCallback onTap;
  const _CopyButton({required this.copies, required this.onTap});
  @override
  Widget build(BuildContext context) => PressScale(
    label: l10n.bridgesCopyBridge,
    scale: 0.97,
    haptic: false,
    onTap: onTap,
    child: Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HaloColors.violet,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CopiedMark(
            copies: copies,
            size: 15,
            color: HaloColors.ink,
            done: HaloColors.ink,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.bridgesCopyBridge,
            semanticsLabel: '',
            style: HaloType.sans(
              size: 14,
              weight: FontWeight.w600,
              color: HaloColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}
