// SPDX-License-Identifier: GPL-3.0-or-later
// the names kryfo gives what it saves. under a plain icon a new save looks
// like any phone's: the camera's IMG_ and VID_ names, plain words for the
// rest, nothing that says kryfo. what was saved before stays as it is, and
// under kryfo's own icon every name is the one it always was. the folders
// are android's side (SavePlace.kt)
import 'app_icon.dart';

/// a new save is named plainly unless android has said kryfo's own icon
/// is on: one not known names plainly, as android's side files it plainly
bool savesPlain() => !looksKryfo;

String _two(int n) => n.toString().padLeft(2, '0');

String _stamp(DateTime t) =>
    '${t.year}${_two(t.month)}${_two(t.day)}_'
    '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';

/// a photo or video the camera keeps a copy of
String cameraName({required bool video, required bool plain, DateTime? at}) {
  final t = at ?? DateTime.now();
  if (!plain) {
    return 'kryfo_${t.millisecondsSinceEpoch}.${video ? 'mp4' : 'jpg'}';
  }
  return '${video ? 'VID' : 'IMG'}_${_stamp(t)}.${video ? 'mp4' : 'jpg'}';
}

/// a backup file. its contents say what it is, so a restore finds it by
/// what the picker hands over, never by its name
String backupName({required bool plain, DateTime? at}) {
  final t = at ?? DateTime.now();
  if (!plain) return 'kryfo-backup-${t.millisecondsSinceEpoch ~/ 1000}.kryfo';
  return 'backup_${_stamp(t)}.bin';
}

/// a notes export; [day] is its date as the export writes it, [ext] what
/// follows the name
String notesName({
  required bool plain,
  required String day,
  required String ext,
}) => plain ? 'notes-$day.$ext' : 'kryfo-notes-$day.$ext';

/// a contact card handed to another app
String cardName({
  required bool plain,
  required String haloId,
  required String ext,
}) => plain ? 'card-$haloId.$ext' : 'kryfo-$haloId.$ext';
