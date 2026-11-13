// SPDX-License-Identifier: GPL-3.0-or-later
// what of someone else's picture may reach a decoder: a jpeg, a png or a
// gif, told by the first bytes, never by a name. our phones send no other
// kind (photoLaneBytes draws the rest again as a jpeg), so no webp, bmp,
// ico, wbmp, heif, avif or tiff of theirs is ever handed to a codec, and so
// none of android's own decoders either. theirs is what arrived here, under
// a name receivedFileFor gave it. ours and what we pick are drawn as they are
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'image_strip.dart' show PictureKind, pictureKind;

/// whose picture it is
enum PictureFrom { ours, theirs }

/// a file that arrived from someone: what receivedFileFor names it
bool arrivedHere(String path) {
  final i = path.lastIndexOf(Platform.pathSeparator);
  final j = path.lastIndexOf('/');
  final leaf = path.substring((i > j ? i : j) + 1);
  return leaf.startsWith('in_');
}

/// whose the media file at [path] is, by its name on disk
PictureFrom pictureFromPath(String path) =>
    arrivedHere(path) ? PictureFrom.theirs : PictureFrom.ours;

/// a picture of theirs that is not a kind we decode
class PictureRefused implements Exception {
  const PictureRefused();
  @override
  String toString() => 'PictureRefused';
}

/// the kinds of theirs a decoder may see
bool kindMayDecode(PictureKind k) =>
    k == PictureKind.jpeg || k == PictureKind.png || k == PictureKind.gif;

/// whether a picture whose bytes start with [head] may be decoded
bool pictureMayDecode(Uint8List head, PictureFrom from) =>
    from == PictureFrom.ours || kindMayDecode(pictureKind(head));

/// the first bytes of [path], enough to tell a jpeg, a png or a gif
Future<Uint8List> pictureHeadOf(String path) async {
  final f = await File(path).open();
  try {
    return await f.read(16);
  } finally {
    await f.close();
  }
}

/// whether the file at [path] may be decoded. one that cannot be read may not
Future<bool> fileMayDecode(String path, [PictureFrom? from]) async {
  final whose = from ?? pictureFromPath(path);
  if (whose == PictureFrom.ours) return true;
  try {
    return pictureMayDecode(await pictureHeadOf(path), whose);
  } catch (_) {
    return false;
  }
}

/// a file's picture through the gate: what may not be decoded never reaches
/// the decoder and fails as a broken picture does, so the bubble shows its
/// own "unavailable" tile
class GatedFileImage extends ImageProvider<GatedFileImage> {
  const GatedFileImage(this.path, this.from);

  final String path;
  final PictureFrom from;

  @override
  Future<GatedFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<GatedFileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    GatedFileImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: gatedCodec(key, decode),
    scale: 1.0,
    debugLabel: path,
  );

  /// the codec for [key], or a [PictureRefused] before any decoder is asked
  @visibleForTesting
  static Future<ui.Codec> gatedCodec(
    GatedFileImage key,
    ImageDecoderCallback decode,
  ) async {
    final file = File(key.path);
    if (await file.length() == 0) {
      // it may come later, as a file image's does
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('empty picture');
    }
    // read as a file image reads it: through the seal where there is one,
    // and then the very bytes told are the ones decoded
    if (file.runtimeType != File) {
      final bytes = await file.readAsBytes();
      if (!pictureMayDecode(bytes, key.from)) {
        bytes.fillRange(0, bytes.length, 0);
        throw const PictureRefused();
      }
      return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    }
    if (!pictureMayDecode(await pictureHeadOf(key.path), key.from)) {
      throw const PictureRefused();
    }
    return decode(await ui.ImmutableBuffer.fromFilePath(key.path));
  }

  @override
  bool operator ==(Object other) =>
      other is GatedFileImage && other.path == path && other.from == from;

  @override
  int get hashCode => Object.hash(path, from);

  @override
  String toString() => 'GatedFileImage(${from.name})';
}

/// the provider a media file is drawn through: a plain file image for ours,
/// the gate for theirs
ImageProvider pictureOf(String path, [PictureFrom? from]) =>
    (from ?? pictureFromPath(path)) == PictureFrom.ours
    ? FileImage(File(path))
    : GatedFileImage(path, from ?? PictureFrom.theirs);
