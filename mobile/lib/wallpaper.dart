// SPDX-License-Identifier: GPL-3.0-or-later
// what a chat shows behind it: a built-in drawn in code (atmosphere.dart),
// a photo of the person's own, or, when the chat has no choice of its own,
// the default set under appearance. a photo is re-encoded by the picker at
// the screen's size and stripped by the photo lane's own cleaner, then kept
// as bytes in the encrypted database of the container that holds the chat
// (HaloDb.setChatPhoto): never a file, never shared storage, gone with the
// chat. never sent: the other person sees their own.
import 'dart:math' as math;
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
import 'session.dart' show Session;

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

/// the largest side a kept photo has: a screen's worth, never more
const kWallSide = 2048.0;

/// what became of a picked photo
// kept; nothing picked or the lock took it; it would not clean; or its
// chat was not there to take it
enum Picked { kept, none, unclean, missed }

/// a photo from the gallery, re-encoded by the picker no larger than the
/// screen's longest side (kWallSide at most), cleaned, and handed to [save]
/// with the session it was picked in, as that session reads now; [save]
/// says whether the chat took it. the picker's copy is shredded whatever
/// happens. [failed] says why a photo was not kept
Future<Picked> pickWallpaperPhoto(
  BuildContext context, {
  required Future<bool> Function(Session at, Uint8List photo) save,
  ValueChanged<Picked>? failed,
}) async {
  final at = session;
  final mq = MediaQuery.of(context);
  final side = math.min(
    (mq.size.longestSide * mq.devicePixelRatio).ceilToDouble(),
    kWallSide,
  );
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
    return Picked.none;
  }
  if (x == null) return Picked.none;
  Uint8List? raw;
  try {
    raw = await x.readAsBytes();
  } catch (e) {
    dlog('wallpaper: the pick did not read (${e.runtimeType})');
  } finally {
    await shredPickedImages([x]);
  }
  final r = raw == null ? Picked.unclean : await keepPicked(at, raw, save);
  if (r == Picked.unclean || r == Picked.missed) failed?.call(r);
  return r;
}

/// a picked photo cleaned, then saved only if the containers it was picked
/// in are still the ones open: a lock that closed the vault, or another pin,
/// while it was cleaned would route a hidden chat's photo elsewhere, so it
/// goes nowhere. a session rebuilt over the same containers (a chat moved
/// into the vault meanwhile) is the same place, and the save goes through
/// it as it reads now
@visibleForTesting
Future<Picked> keepPicked(
  Session at,
  Uint8List raw,
  Future<bool> Function(Session at, Uint8List photo) save,
) async {
  final out = await wallpaperBytes(raw);
  if (out == null) return Picked.unclean;
  final now = session;
  if (!identical(now.primary, at.primary) || !identical(now.vault, at.vault)) {
    dlog('wallpaper: the session changed while it was cleaned, dropped');
    return Picked.none;
  }
  return await save(now, out) ? Picked.kept : Picked.missed;
}

/// a photo read at 8 by 8: what its corners and middle are made of, enough
/// to size its veil. null when it does not decode
Future<List<Color>?> photoSamples(Uint8List bytes) async {
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
    final n = data.lengthInBytes ~/ 4;
    if (n == 0) return null;
    return [
      for (var i = 0; i < n; i++)
        Color.fromARGB(
          255,
          data.getUint8(i * 4),
          data.getUint8(i * 4 + 1),
          data.getUint8(i * 4 + 2),
        ),
    ];
  } catch (_) {
    return null;
  }
}

/// how strongly the page's [ground] lies over a photo, from its [samples]:
/// enough that its brightest tenth (dark theme) or darkest tenth (light
/// theme) lands where the plain page's lines read, so a bright patch
/// behind a date or a name is covered too, not only the average. the veil
/// is mixed as the screen mixes it and the result judged in linear light.
/// never less than a veil, never all of it
double veilFor(List<Color>? samples, Color ground, {required bool light}) {
  const least = 0.4, most = 0.86;
  if (samples == null || samples.isEmpty) return 0.6;
  final byLum = [...samples]
    ..sort((a, b) => a.computeLuminance().compareTo(b.computeLuminance()));
  final at = light
      ? byLum[(byLum.length * 0.1).floor()]
      : byLum[math.min(byLum.length - 1, (byLum.length * 0.9).floor())];
  // where the page under the bubbles should land
  bool reads(double a) {
    final l = Color.lerp(at, ground, a)!.computeLuminance();
    return light ? l >= 0.55 : l <= 0.06;
  }

  if (reads(least)) return least;
  if (!reads(most)) return most;
  var lo = least, hi = most;
  for (var i = 0; i < 20; i++) {
    final mid = (lo + hi) / 2;
    if (reads(mid)) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}
