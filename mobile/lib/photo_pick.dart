// SPDX-License-Identifier: GPL-3.0-or-later
// a profile photo from the camera or the gallery: drawn upright by the
// phone with no tags, cropped round by the person, then drawn again at
// kPhotoSide and written as a fresh jpeg. nothing of the file it came from
// survives: no exif, no gps, no camera, no name, no colour profile. the
// picker's copy is shredded whatever happens
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'dlog.dart';
import 'lock_guard.dart' show LockDropped;
import 'lock_state.dart';
import 'picked.dart' show shredPickedImages;
import 'profile_photo.dart';
import 'screens/camera_screen.dart' show CameraScreen, CaptureResult;
import 'screens/photo_crop_screen.dart';
import 'widgets/motion.dart' show haloRoute;

const _platform = MethodChannel('halo/platform');

/// the long side a picture is drawn at for the crop
const kCropSourceEdge = 1600;

/// what became of a pick: a photo, nothing (cancelled, or the lock took
/// it), or one that could not be made clean
enum PhotoPicked { photo, none, unclean }

/// the square of [upright] at kPhotoSide, as the phone writes it, and read
/// clean. null: dropped. [encode] stands in for the phone in tests
Future<Uint8List?> squarePhoto(
  Uint8List upright,
  PhotoSquare sq, {
  @visibleForTesting
  Future<Uint8List?> Function(Uint8List b, PhotoSquare sq)? encode,
}) async {
  Uint8List? out;
  try {
    out = await (encode ?? _squareJpeg)(upright, sq);
  } catch (e) {
    dlog('photo: not drawn (${e.runtimeType})');
    return null;
  }
  if (out == null || out.isEmpty) return null;
  return photoFit(out);
}

Future<Uint8List?> _squareJpeg(Uint8List b, PhotoSquare sq) =>
    _platform.invokeMethod<Uint8List>('squareJpeg', {
      'bytes': b,
      'left': sq.left,
      'top': sq.top,
      'side': sq.side,
      'edge': kPhotoSide,
      'most': kPhotoBytesMost,
    });

// the pick drawn upright as a jpeg with no tags, any format the phone
// reads. null when it does not decode
Future<Uint8List?> _upright(Uint8List raw) async {
  try {
    final r = await _platform.invokeMethod<Uint8List>('shrinkJpeg', {
      'bytes': raw,
      'maxEdge': kCropSourceEdge,
      'quality': 92,
    });
    return r == null || r.isEmpty ? null : r;
  } catch (e) {
    dlog('photo: not drawn upright (${e.runtimeType})');
    return null;
  }
}

/// a photo from the camera or the gallery, cropped and made clean. [got]
/// has it when the result is PhotoPicked.photo
Future<PhotoPicked> pickProfilePhoto(
  BuildContext context, {
  required bool camera,
  required void Function(Uint8List photo) got,
}) async {
  final nav = Navigator.of(context);
  Uint8List? raw;
  if (camera) {
    final r = await nav.push<CaptureResult>(
      haloRoute<CaptureResult>(const CameraScreen(photoOnly: true)),
    );
    raw = r?.photo;
  } else {
    final XFile? x;
    try {
      x = await lockState.hold(
        () => ImagePicker().pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        ),
      );
    } on LockDropped {
      return PhotoPicked.none;
    }
    if (x == null) return PhotoPicked.none;
    try {
      raw = await x.readAsBytes();
    } catch (e) {
      dlog('photo: the pick did not read (${e.runtimeType})');
      return PhotoPicked.unclean;
    } finally {
      await shredPickedImages([x]);
    }
  }
  if (raw == null) return PhotoPicked.none;
  final upright = await _upright(raw);
  if (upright == null) return PhotoPicked.unclean;
  if (!nav.mounted) return PhotoPicked.none;
  final sq = await nav.push<PhotoSquare>(
    haloRoute<PhotoSquare>(PhotoCropScreen(bytes: upright)),
  );
  if (sq == null) return PhotoPicked.none;
  final out = await squarePhoto(upright, sq);
  if (out == null) return PhotoPicked.unclean;
  got(out);
  return PhotoPicked.photo;
}
