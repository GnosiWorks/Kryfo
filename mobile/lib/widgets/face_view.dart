// SPDX-License-Identifier: GPL-3.0-or-later
// a profile photo, larger: tapped open from a contact's page or your own,
// with nothing to save, share or copy, and screenshots held off while it
// is up. a face with no photo opens nothing
import 'package:flutter/widgets.dart';

import '../profile_photo.dart' show kPhotoSide, photoBook, photoImage;
import 'photo_viewer.dart' show openPhotoImage;

/// whether [id] has a photo to open
bool faceOpens(String id) => photoBook.has(id);

/// [id]'s photo full screen, flying out of [tag] when given
Future<void> openFace(
  BuildContext context,
  String id, {
  required String label,
  Object? tag,
  double radius = 0,
}) async {
  final bytes = photoBook.of(id);
  if (bytes == null) return;
  await openPhotoImage(
    context,
    photoImage(bytes, kPhotoSide),
    tag: tag,
    radius: radius,
    secure: true,
    label: label,
  );
}
