// SPDX-License-Identifier: GPL-3.0-or-later
// what a file in a chat can do: be looked at here, in kryfo's own viewers,
// so no other app gets a decrypted copy; go to another chat; be saved; or,
// last and said plainly, be handed to another app
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import '../file_kind.dart';
import '../file_save.dart';
import '../l10n/l10n.dart';
import '../lock_state.dart';
import '../main.dart' show session;
import '../open_file.dart';
import '../screens/dev_about_sheet.dart' show devForwardTarget;
import '../screens/forward_sheet.dart' show pickWordsChat;
import '../screens/share_files_sheet.dart' show landFiles;
import '../share_files.dart' show SharedCopy;
import '../sound_player.dart';
import '../theme.dart';
import '../voice_format.dart' show isVoiceName;
import 'file_badge.dart';
import 'pdf_viewer.dart';
import 'photo_viewer.dart';
import 'sound_views.dart' show openSoundPlayer, soundsKept;
import 'text_viewer.dart';
import 'video_viewer.dart';

export 'file_viewer_parts.dart' show fileHeroTag;

/// kryfo's own viewers
enum FileView { picture, video, text, pdf, audio }

/// the pdf viewer draws with the phone's own renderer, which only android
/// has. tests turn it on and off
@visibleForTesting
bool? pdfViewHereForTest;
bool get pdfViewHere =>
    pdfViewHereForTest ?? (Platform.isAndroid && !onDesktop);

/// a phone plays any sound file; a computer only what its own player reads
/// (ogg opus and wav, desktop_audio.dart)
@visibleForTesting
bool? audioViewHereForTest;
bool audioViewHere(FileFacts facts) =>
    audioViewHereForTest ??
    (onDesktop
        ? const {'ogg', 'opus', 'wav'}.contains(facts.ext)
        : Platform.isAndroid);

/// the facts read from the bytes, or by the name until they are
FileFacts fileFactsOrName(String path, String? name) =>
    fileFactsNow(path, name) ??
    FileFacts(kindOfName(name), extOf(safeFileName(name)));

/// the viewer that shows [facts] here, or null when none does. an app
/// installer never opens
FileView? fileViewOf(FileFacts facts) {
  if (facts.installer) return null;
  if (fileShapeOf(facts) == FileShape.picture) return FileView.picture;
  if (fileShapeOf(facts) == FileShape.video) return FileView.video;
  if (facts.kind == FileKind.pdf) return pdfViewHere ? FileView.pdf : null;
  if (facts.kind == FileKind.audio) {
    return audioViewHere(facts) ? FileView.audio : null;
  }
  if (textViewable(facts.ext)) return FileView.text;
  return null;
}

/// opens [path] in kryfo's viewer for it. false when none shows it. [kept]:
/// theirs in a chat that blocks, shown with screenshots blocked
Future<bool> viewInKryfo(
  BuildContext context,
  String path,
  String? name, {
  bool kept = false,
  // who sent it, for the viewer's header
  String? from,
  // the bubble's tile, which flies to the viewer's head
  Object? heroTag,
  // a sound: what plays after it
  List<SoundItem> Function()? upNext,
}) async {
  final facts = await readFileFacts(path, name);
  if (!context.mounted) return false;
  switch (fileViewOf(facts)) {
    case FileView.picture:
      await openPhoto(context, path, secure: kept);
    case FileView.video:
      await openVideo(context, path: path, fileName: name, kept: kept);
    case FileView.text:
      await openTextFile(
        context,
        path: path,
        name: name,
        facts: facts,
        kept: kept,
        from: from,
        heroTag: heroTag,
      );
    case FileView.pdf:
      int? size;
      try {
        size = await File(path).length();
      } catch (_) {}
      if (!context.mounted) return false;
      await openPdfFile(
        context,
        path: path,
        name: name,
        facts: facts,
        kept: kept,
        from: from,
        heroTag: heroTag,
        size: size,
      );
    case FileView.audio:
      final p = SoundPlayer.instance;
      final it = SoundItem(path, name: name, from: from, kept: kept);
      final next = upNext?.call() ?? const <SoundItem>[];
      if (!p.isOn(path)) unawaited(p.play(it, next: next));
      await openSoundPlayer(
        context,
        heroTag: heroTag,
        secure: soundsKept(it, next),
      );
    case null:
      return false;
  }
  return true;
}

/// hands [path] to the app the person picks for its kind: never an app
/// installer, which is saved instead; the share sheet when nothing opens it
Future<void> openFileOutside(
  BuildContext context,
  String path,
  String? name,
) async {
  final opened = await lockState.hold(
    () => openWithAnotherApp(path, name: name),
  );
  if (opened == OpenAnswer.opened || !context.mounted) return;
  if (opened == OpenAnswer.refused) {
    await saveReceivedFile(context, path, name);
    return;
  }
  showHaloToast(context, l10n.videoBubbleNothingHereOpensThat);
  await lockState.hold(() => shareFileOut(path, name: name));
}

/// whether a file of a chat goes on to another chat: not a voice note, not
/// an app installer, and nothing a chat that blocks keeps
bool canForwardFile(String? path, String? name, {required bool kept}) =>
    path != null &&
    name != null &&
    !kept &&
    !isVoiceName(name) &&
    !knownInstaller(path, name);

/// [path] to a chat the person picks, through that chat's own send: asked
/// about first, cleaned and sent as any file is. the file here is read,
/// never moved or shredded
Future<void> forwardFile(
  BuildContext context,
  String path,
  String? name,
) async {
  final id = await pickWordsChat(
    context,
    title: l10n.chatForwardTo,
    empty: l10n.chatNoContactsToForward,
    dev: lockState.inDecoy || session.container.quiet ? null : devForwardTarget,
  );
  if (id == null || !context.mounted || lockState.locked) return;
  if (!await File(path).exists()) return;
  if (!context.mounted) return;
  final facts = await readFileFacts(path, name);
  if (!context.mounted) return;
  await landFiles(context, id, session.container.id, [
    SharedCopy(
      path,
      name: safeFileName(name, facts: facts),
      mime: facts.mime,
    ),
  ]);
}
