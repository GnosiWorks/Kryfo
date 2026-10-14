// SPDX-License-Identifier: GPL-3.0-or-later
// what a chat shows behind it: a built-in drawn in code (atmosphere.dart),
// a photo of the person's own, or, when the chat has no choice of its own,
// the default set under appearance. a photo is re-encoded by the picker at
// the screen's size and stripped by the photo lane's own cleaner, then kept
// as bytes in the encrypted database of the container that holds the chat
// (HaloDb.setChatPhoto): never a file, never shared storage, gone with the
// chat. never sent: the other person sees their own.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'atmosphere.dart';
import 'dlog.dart';
import 'image_strip.dart' show photoToSendOffUi;
import 'lock_guard.dart' show LockDropped;
import 'lock_state.dart';
import 'main.dart' show kPhotoWall, session;
import 'picked.dart';

class ChatWall {
  final Atmo atmo;
  final Uint8List? photo;
  const ChatWall(this.atmo, [this.photo]);
  static const none = ChatWall(Atmo.none);

  bool get isNone => atmo == Atmo.none && photo == null;

  // the same picture, read again: a reload that finds it unchanged leaves
  // the chat as it is, with no fade
  bool sameAs(ChatWall o) =>
      atmo == o.atmo &&
      (identical(photo, o.photo) ||
          (photo != null && o.photo != null && listEquals(photo, o.photo)));

  @override
  bool operator ==(Object other) =>
      other is ChatWall && other.atmo == atmo && identical(other.photo, photo);
  @override
  int get hashCode =>
      Object.hash(atmo, photo == null ? 0 : identityHashCode(photo));
}

/// bumped when a wallpaper is set anywhere: the default under appearance,
/// or a group's from its info page, so an open chat shows it at once
final wallpaperRevision = ValueNotifier<int>(0);

ChatWall _wallOf(({String atmo, Uint8List? photo})? row) {
  if (row == null) return ChatWall.none;
  final photo = row.photo;
  if (row.atmo == kPhotoWall) {
    return photo == null ? ChatWall.none : ChatWall(Atmo.none, photo);
  }
  return ChatWall(atmoFromName(row.atmo));
}

/// the default every chat without a choice of its own shows
Future<ChatWall> defaultWall() async {
  try {
    return _wallOf(await session.defaultWallpaper());
  } catch (e) {
    dlog('wallpaper: no default read (${e.runtimeType})');
    return ChatWall.none;
  }
}

/// a chat's own choice, or the default when it has made none. a read that
/// fails shows the plain page: a wallpaper is never worth an error
Future<ChatWall> chatWall(String chatId, {bool group = false}) async {
  try {
    return await _chatWall(chatId, group);
  } catch (e) {
    dlog('wallpaper: not read (${e.runtimeType})');
    return ChatWall.none;
  }
}

Future<ChatWall> _chatWall(String chatId, bool group) async {
  final own = group
      ? await session.getGroupAtmosphere(chatId)
      : await session.getAtmosphere(chatId);
  if (own == null) return defaultWall();
  if (own == kPhotoWall) {
    final photo = await session.chatPhotoOf(chatId, group: group);
    return photo == null ? ChatWall.none : ChatWall(Atmo.none, photo);
  }
  return ChatWall(atmoFromName(own));
}

/// whether a chat follows the default
Future<bool> followsDefault(String chatId, {bool group = false}) async =>
    (group
        ? await session.getGroupAtmosphere(chatId)
        : await session.getAtmosphere(chatId)) ==
    null;

/// a picked photo as it may sit behind a chat: cleaned by the photo lane's
/// stripper, refused when a tag survives. null: dropped
Future<Uint8List?> wallpaperBytes(Uint8List picked) => photoToSendOffUi(picked);

/// a photo from the gallery, re-encoded by the picker no larger than the
/// screen's longest side, cleaned, and the picker's copy shredded. null
/// when nothing was picked, the lock dropped it, or it could not be cleaned
/// ([failed] then says why the person gets no wallpaper)
Future<Uint8List?> pickWallpaperPhoto(
  BuildContext context, {
  VoidCallback? failed,
}) async {
  final mq = MediaQuery.of(context);
  final side = (mq.size.longestSide * mq.devicePixelRatio).ceilToDouble();
  final XFile? x;
  try {
    x = await lockState.hold(
      () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: side,
        maxHeight: side,
        imageQuality: 82,
        requestFullMetadata: false,
      ),
    );
  } on LockDropped {
    return null;
  }
  if (x == null) return null;
  Uint8List? out;
  try {
    out = await wallpaperBytes(await x.readAsBytes());
  } catch (e) {
    dlog('wallpaper: the pick did not read (${e.runtimeType})');
  } finally {
    await shredPickedImages([x]);
  }
  if (out == null) failed?.call();
  return out;
}

/// a photo's mean luminance, from a few pixels of it. null when it does
/// not decode
Future<double?> photoLuminance(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 8,
      targetHeight: 8,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    if (data == null) return null;
    var sum = 0.0;
    final n = data.lengthInBytes ~/ 4;
    for (var i = 0; i < n; i++) {
      sum += Color.fromARGB(
        255,
        data.getUint8(i * 4),
        data.getUint8(i * 4 + 1),
        data.getUint8(i * 4 + 2),
      ).computeLuminance();
    }
    return n == 0 ? null : sum / n;
  } catch (_) {
    return null;
  }
}

/// how strongly the page's ground lies over a photo of mean luminance
/// [lum], [ground] being that ground's: in the dark theme a bright photo is
/// pulled down to a dark one, in the light theme a dark one is lifted to a
/// pale one, so dates, names and lines read on it as on the plain page.
/// never less than a veil, never all of it
double veilFor(double? lum, double ground, {required bool light}) {
  // where the page under the bubbles should land
  final target = light ? 0.55 : 0.06;
  final l = lum ?? (light ? 0.2 : 0.5);
  final a = light ? (target - l) / (ground - l) : (l - target) / (l - ground);
  if (a.isNaN) return 0.4;
  return a.clamp(0.4, 0.86);
}
