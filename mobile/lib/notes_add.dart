// SPDX-License-Identifier: GPL-3.0-or-later
// what goes into note to self besides words: a photo, a gif, a file or a
// voice note, made ready the way a chat makes one ready to send. the same
// cleaner on our own copy, the same limits, the copy kept in the media
// folder of the container that holds the notes, so it is sealed there like
// any chat's media and wiped and backed up with it. the decoy's notes are
// the decoy's, and a note is never the hidden side's. once its row is in,
// my other devices are owed it (notes_own_app.dart)
import 'dart:io';
import 'dart:typed_data';

import 'clean_media.dart';
import 'dlog.dart';
import 'file_drop.dart' show kFreeFileBytes;
import 'file_kind.dart' show fileFits, readFileFactsFresh;
import 'image_strip.dart' show pictureExt, pictureKind, stripPictureBytes;
import 'l10n/l10n.dart';
import 'main.dart'
    show
        session,
        notesApp,
        newMsgUid,
        ownSync,
        typeLeaf,
        AppStateFiles,
        AppStateNotes;
import 'devices/own_sync.dart' show kOwnNotes;
import 'photo_blur.dart' show makeBlurSoon;
import 'picked.dart' show placeVoice;
import 'picture_convert.dart' show photoLaneBytes, photoLaneKeeps;
import 'sent_name.dart' show sentFileName;
import 'shred.dart' show shredFile;
import 'stickers/sticker_wire.dart' show StickerWire;
import 'voice_format.dart' show kVoiceWav;
import 'voice_length.dart' show voiceFileMs;
import 'voice_opus.dart' show voiceForWire;
import 'widgets/media_bubbles.dart' show fileTooBigLine, voiceLengthKnown;
import 'widgets/voice_parts.dart' show voiceFileFree, voicePeaksSame;

/// the most a file in note to self may be: a chat's own limit, as my
/// devices fetch it from the files service
const kNoteFileMost = kFreeFileBytes;

/// the most a gif may be, as in a chat: it is kept as it is, never made
/// smaller
const kNoteGifMost = 8 * 1024 * 1024;

/// an item made ready: its uid, where it is kept, and its file's name (none
/// for a photo or a gif)
typedef NoteItem = ({String uid, String path, String? fileName});

/// what came of making an item ready: the item, or the line that says why
/// there is none
typedef NoteReady = ({NoteItem? item, String? line});

NoteReady _say(String line) => (item: null, line: line);

Future<Directory> _folder() => session.mediaDirOf(kOwnNotes.id);

/// a file at [src] (a pick, a drop, a paste) made ready under the name it
/// was [picked] by: copied in and cleaned there. a picture the cleaner
/// cannot clean is drawn again as a clean jpeg, or kept as it is, never
/// asked about (copyForSend)
Future<NoteReady> readyNoteFile(String src, String picked) async {
  final name = sentFileName(picked);
  final int size;
  try {
    size = await File(src).length();
  } catch (_) {
    return _say(l10n.chatCouldNotReadThat);
  }
  if (size == 0) return _say(l10n.chatCouldNotReadThat);
  if (!fileFits(size, kNoteFileMost)) {
    return _say(fileTooBigLine(size, kNoteFileMost));
  }
  final raw = (await readFileFactsFresh(src, name))?.raw ?? false;
  final uid = newMsgUid();
  final dest = File('${(await _folder()).path}/f_$uid${typeLeaf(name)}');
  final done = await copyForSend(src, dest.path, name: name, raw: raw);
  final at = done.path;
  if (at == null) {
    return _say(
      done.video ? l10n.chatCouldNotCleanThat : l10n.chatCouldNotReadThat,
    );
  }
  makeBlurSoon(at);
  return (item: (uid: uid, path: at, fileName: done.name), line: null);
}

/// a photo's bytes made ready: cleaned of what rode along, kept as its kind
/// when a jpeg, png or gif, else drawn again as a jpeg
Future<NoteReady> readyNotePhoto(Uint8List raw) async {
  final bytes = await photoLaneBytes(raw);
  if (bytes == null) return _say(l10n.cameraCouldNotStripThat);
  return _keepPicture(bytes);
}

/// a gif's bytes made ready: its frames and loop kept, its comments gone
Future<NoteReady> readyNoteGif(Uint8List data) async {
  if (data.length > kNoteGifMost) return _say(l10n.chatGifTooBig8);
  // picked as a gif and is not one: a photo like any other
  if (!photoLaneKeeps(pictureKind(data))) return readyNotePhoto(data);
  final clean = stripPictureBytes(data);
  if (clean == null) return _say(l10n.chatCouldNotCleanThatGif);
  return _keepPicture(clean);
}

Future<NoteReady> _keepPicture(Uint8List bytes) async {
  final uid = newMsgUid();
  final f = File('${(await _folder()).path}/$uid.${pictureExt(bytes)}');
  await f.writeAsBytes(bytes);
  makeBlurSoon(f.path);
  return (item: (uid: uid, path: f.path, fileName: null), line: null);
}

/// a voice note's take made ready: never disguised (it is for me), kept as
/// opus once that is made, the recorder's file gone either way
Future<NoteReady> readyNoteVoice(String take, {String? masked}) async {
  final uid = newMsgUid();
  final wav = '${(await _folder()).path}/vn_$uid.wav';
  if (!await placeVoice(take, wav, disguise: false, masked: masked)) {
    return _say(l10n.notesVoiceNotKept);
  }
  final (path, name) = await voiceForWire(wav, opus: true);
  if (path != wav) {
    voicePeaksSame(wav, path);
    final ms = await voiceFileMs(path);
    if (ms != null) voiceLengthKnown(path, ms);
    await voiceFileFree(wav);
    await shredFile(wav);
  }
  return (
    item: (
      uid: uid,
      path: path,
      fileName: name == kVoiceWav ? kVoiceWav : name,
    ),
    line: null,
  );
}

/// [item] kept in note to self with [caption], and owed to my devices
Future<void> keepNoteItem(NoteItem item, {String caption = ''}) async {
  final file = item.fileName != null;
  try {
    await session.saveMessage(
      kOwnNotes.id,
      'in',
      caption.trim(),
      msgUid: item.uid,
      mediaPath: file ? null : item.path,
      filePath: file ? item.path : null,
      fileName: item.fileName,
    );
  } catch (e) {
    dlog('notes: an item not kept (${e.runtimeType})');
    await shredFile(item.path);
    rethrow;
  }
  await _owed(item.uid);
}

// owed to my devices, once own sync runs at all
Future<void> _owed(String uid) async {
  if (ownSync != null) await notesApp.ownNoteKept(uid);
}

/// a sticker kept in note to self under its [emoji], owed to my devices
Future<void> keepNoteSticker(StickerWire sticker, String emoji) async {
  final uid = newMsgUid();
  await session.saveMessage(
    kOwnNotes.id,
    'in',
    emoji,
    msgUid: uid,
    sticker: sticker.value,
  );
  await _owed(uid);
}

/// words kept in note to self, owed to my devices
Future<void> keepNoteWords(String text) async {
  final uid = newMsgUid();
  await session.saveMessage(kOwnNotes.id, 'in', text, msgUid: uid);
  await _owed(uid);
}

/// a note gone here and on my devices: nothing of it is owed any more, and
/// a file of it on the files service is taken back first, while it is
/// still on disk to read
Future<void> deleteNote(String uid) async {
  if (ownSync != null) {
    await notesApp.ownNoteGone(uid);
    if (await notesApp.ownNotesShared()) await notesApp.takeDropBackOf(uid);
  }
  await session.deleteMessage(uid);
}

/// every note gone here, and on my devices when this is my phone: nothing
/// of them is owed or waits for my devices any more
Future<void> deleteAllNotes() async {
  // the everyday side's alone: a decoy's delete all leaves them be
  if (ownSync != null && await notesApp.ownNotesShared()) {
    await notesApp.ownNotesAllGone();
  }
  await session.deleteAllNotes();
}
