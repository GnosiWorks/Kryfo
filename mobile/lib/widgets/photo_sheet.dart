// SPDX-License-Identifier: GPL-3.0-or-later
// what a tap on a face offers: a photo from the camera or the gallery, the
// drawn faces for your own, a larger look, or the photo off again
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'halo_rows.dart';
import 'halo_sheet.dart';
import 'kryfo_avatar.dart';
import 'sheet_handle.dart';

enum PhotoChoice { camera, gallery, faces, view, remove }

/// null when dismissed. [add] offers the camera and the gallery, [faces]
/// the face picker, [has] a look and the remove. [look] false keeps the
/// look off where the face shows
Future<PhotoChoice?> showPhotoSheet(
  BuildContext context, {
  required String title,
  required String line,
  required String seed,
  int? choice,
  required bool add,
  required bool has,
  bool? look,
  bool faces = false,
}) => showHaloSheet<PhotoChoice>(
  context,
  builder: (ctx) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 14),
          Row(
            children: [
              KryfoAvatar(seed: seed, size: 52, choice: choice),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: HaloType.serif(size: 20, color: HaloColors.text),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      line,
                      style: HaloType.sans(
                        size: 13,
                        color: HaloColors.text2,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          HaloGroup(
            children: [
              if (add) ...[
                HaloRow(
                  icon: Icons.photo_camera_outlined,
                  label: l10n.photoTake,
                  onTap: () => Navigator.pop(ctx, PhotoChoice.camera),
                ),
                HaloRow(
                  icon: Icons.photo_library_outlined,
                  label: l10n.photoChoose,
                  onTap: () => Navigator.pop(ctx, PhotoChoice.gallery),
                ),
              ],
              if (faces)
                HaloRow(
                  icon: Icons.face_outlined,
                  label: l10n.photoPickFace,
                  onTap: () => Navigator.pop(ctx, PhotoChoice.faces),
                ),
              if (look ?? has)
                HaloRow(
                  icon: Icons.zoom_out_map,
                  label: l10n.photoView,
                  onTap: () => Navigator.pop(ctx, PhotoChoice.view),
                ),
            ],
          ),
          if (has) ...[
            const SizedBox(height: 12),
            HaloGroup(
              rose: true,
              children: [
                HaloRow(
                  icon: Icons.delete_outline,
                  label: l10n.photoRemove,
                  rose: true,
                  onTap: () => Navigator.pop(ctx, PhotoChoice.remove),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  ),
);
