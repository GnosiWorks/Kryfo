// SPDX-License-Identifier: GPL-3.0-or-later
// a received file saved where the person picks, through the system's own
// save window, the way a backup is. android copies it from the media
// folder as a stream, so nothing big goes through memory. the only way an
// app installer leaves kryfo. a picture or video goes as a clean copy
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'clean_media.dart' show cleanedForSave;

import 'dlog.dart';
import 'file_kind.dart';
import 'l10n/l10n.dart';
import 'lock_guard.dart' show LockDropped;
import 'lock_state.dart';
import 'shred.dart';
import 'screens/backup_screen.dart' show SaveAnswer, SaveState, saveDocumentOut;
import 'theme.dart' show showHaloToast;

/// paths a save is under way for, so a bubble shows it however it began
final savingFiles = ValueNotifier<Set<String>>(const {});

void _saving(String path, bool on) {
  final now = {...savingFiles.value};
  on ? now.add(path) : now.remove(path);
  savingFiles.value = now;
}

/// what is said once a save is answered. nothing for a window backed out of
String? saveAnswerLine(SaveAnswer a) => switch (a.state) {
  SaveState.saved =>
    a.where == null ? l10n.fileSaved : l10n.fileSavedIn(a.where!),
  SaveState.unchecked => l10n.fileSavedUnchecked,
  SaveState.cancelled => null,
  SaveState.failed => l10n.fileNotSaved,
  SaveState.full => l10n.fileNotSavedNoSpace,
};

Future<void> saveReceivedFile(
  BuildContext context,
  String path,
  String? name,
) async {
  if (savingFiles.value.contains(path)) return;
  _saving(path, true);
  SaveAnswer? answer;
  String? copy;
  try {
    final facts = await readFileFacts(path, name);
    final shown = safeFileName(name, facts: facts);
    final out = await cleanedForSave(path, name, await getTemporaryDirectory());
    copy = out.copy;
    final from = out.path;
    if (from != null) {
      await lockState.hold(() async {
        answer = await saveDocumentOut(from, shown);
        return answer;
      });
    }
  } on LockDropped {
    // the chat it was saved from is not on screen any more
    return;
  } catch (e) {
    dlog('file save: ${e.runtimeType}');
  } finally {
    if (copy != null) await shredTree(copy);
    _saving(path, false);
  }
  if (!context.mounted) return;
  final a = answer;
  final line = a == null ? l10n.fileNotSaved : saveAnswerLine(a);
  if (line != null) showHaloToast(context, line);
}
