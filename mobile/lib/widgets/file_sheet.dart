// SPDX-License-Identifier: GPL-3.0-or-later
// a received file's sheet: what it is and how big, then where it goes.
// another app opens it, the system's save window keeps it, or the share
// sheet hands it on. each is one tap, and the sheet closes before it
import 'dart:io';

import 'package:flutter/material.dart';

import '../desktop/desktop_mode.dart' show canShareOut;
import '../file_kind.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import 'halo_sheet.dart';
import 'file_badge.dart';
import 'file_viewer_parts.dart' show OpenWithNote;
import 'media_bubbles.dart' show humanFileSize;
import 'press_scale.dart';
import 'sheet_handle.dart';
import 'stagger_in.dart';

enum FileSheetPick { open, save, share }

/// the picks a file has. an app installer only ever leaves through a save
List<FileSheetPick> fileSheetPicks(FileFacts facts) => [
  if (!facts.installer) FileSheetPick.open,
  FileSheetPick.save,
  if (!facts.installer && canShareOut) FileSheetPick.share,
];

/// a test's own answer in place of the sheet
@visibleForTesting
FileSheetPick? Function()? fileSheetPickForTest;

Future<FileSheetPick?> showFileSheet(
  BuildContext context, {
  required String path,
  required String? name,
  required FileFacts facts,
}) async {
  final answer = fileSheetPickForTest;
  if (answer != null) return answer();
  int? size;
  try {
    size = await File(path).length();
  } catch (_) {
    // gone or unreadable: the sheet shows no size
  }
  if (!context.mounted) return null;
  final shown = safeFileName(name, facts: facts);
  final kind = facts.ext.isEmpty
      ? l10n.mediaBubblesFile
      : facts.ext.toUpperCase();
  return showHaloSheet<FileSheetPick>(
    context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: staggerAllIn(ctx, [
            const SheetHandle(),
            const SizedBox(height: 14),
            Row(
              children: [
                FileBadge(facts: facts, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shown,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HaloType.sans(
                          size: 15,
                          weight: FontWeight.w600,
                          color: HaloColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        size == null ? kind : '$kind · ${humanFileSize(size)}',
                        style: HaloType.mono(size: 11, color: HaloColors.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final p in fileSheetPicks(facts)) ...[
              _PickLine(
                icon: switch (p) {
                  FileSheetPick.open => Icons.open_in_new_rounded,
                  FileSheetPick.save => Icons.download_rounded,
                  FileSheetPick.share => Icons.ios_share_rounded,
                },
                label: switch (p) {
                  FileSheetPick.open => l10n.fileOpenWith,
                  FileSheetPick.save => l10n.fileSaveToDevice,
                  FileSheetPick.share => l10n.commonShare,
                },
                onTap: () => Navigator.pop(ctx, p),
              ),
              // the way out says what it means, under it
              if (p == FileSheetPick.open) const OpenWithNote(),
            ],
          ]),
        ),
      ),
    ),
  );
}

class _PickLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickLine({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.98,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 21, color: HaloColors.amber),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: HaloType.sans(size: 14.5, color: HaloColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
