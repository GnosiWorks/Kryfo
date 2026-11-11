// SPDX-License-Identifier: GPL-3.0-or-later
// a picture drawn again as a jpeg by the platform: decoded pixels carry no
// metadata, and the result still goes through the photo cleaner and is
// read again. the one way every lane turns a heic, an avif or a picture
// the cleaner cannot clean into a clean one: the gallery's shrink, a file
// sent or kept, the tools cleaner. a computer draws it in dart
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:flutter/services.dart' show MethodChannel;

import 'desktop/desk_draw.dart' show deskDrawJpeg;
import 'desktop/desktop_mode.dart' show onDesktop;
import 'dlog.dart';
import 'image_strip.dart' show PictureKind, photoToSendOffUi, pictureKind;

const _platform = MethodChannel('halo/platform');

/// the long edge a picture drawn again for a file keeps: big enough to be
/// the picture, small enough to decode on a phone
const kConvertEdge = 4096;

/// the most a picture may be to be drawn again
const kConvertMost = 64 << 20;

/// the same on a computer, where a camera's raw file is often bigger
const kDeskConvertMost = 256 << 20;

/// [b] drawn again as a jpeg, upright, [maxEdge] on the long edge at most.
/// null where the platform cannot draw it (a computer has no such call)
Future<Uint8List?> drawAsJpeg(
  Uint8List b, {
  int maxEdge = 1280,
  int quality = 70,
}) async {
  if (b.isEmpty || b.length > kConvertMost) return null;
  try {
    final r = await _platform.invokeMethod<Uint8List>('shrinkJpeg', {
      'bytes': b,
      'maxEdge': maxEdge,
      'quality': quality,
    });
    if (r != null && r.isNotEmpty && pictureKind(r) == PictureKind.jpeg) {
      return r;
    }
  } catch (e) {
    dlog('convert: ${e.runtimeType}');
  }
  return null;
}

/// a clean jpeg of [b]: drawn again, through the photo cleaner and read
/// again. null when it cannot be drawn or does not read clean after. a
/// computer draws it itself (desk_draw.dart)
Future<Uint8List?> cleanJpegOf(
  Uint8List b, {
  int maxEdge = kConvertEdge,
  int quality = 90,
}) async {
  final j = onDesktop
      ? await deskJpeg(b, maxEdge: maxEdge, quality: quality)
      : await drawAsJpeg(b, maxEdge: maxEdge, quality: quality);
  if (j == null) return null;
  return photoToSendOffUi(j);
}

/// the computer's drawing, off the ui thread. a raw file may be bigger
/// than a phone would draw: only its own jpeg is decoded
Future<Uint8List?> deskJpeg(
  Uint8List b, {
  int maxEdge = kConvertEdge,
  int quality = 90,
}) async {
  if (b.isEmpty || b.length > kDeskConvertMost) return null;
  final r = await deskDrawKilled(b, maxEdge: maxEdge, quality: quality);
  if (r != null && pictureKind(r) == PictureKind.jpeg) return r;
  return null;
}

/// how long a computer may draw one picture before its isolate is killed
@visibleForTesting
Duration deskDrawLimit = const Duration(seconds: 30);

/// [deskDrawJpeg] in an isolate of its own, killed once [deskDrawLimit]
/// passes: a stranger's file cannot hold the app. null when it is
Future<Uint8List?> deskDrawKilled(
  Uint8List b, {
  int maxEdge = kConvertEdge,
  int quality = 90,
  @visibleForTesting Uint8List? Function(Uint8List)? draw,
}) async {
  final back = ReceivePort();
  final done = Completer<Uint8List?>();
  Isolate? iso;
  final timer = Timer(deskDrawLimit, () {
    iso?.kill(priority: Isolate.immediate);
    dlog('convert: stopped after ${deskDrawLimit.inSeconds} s');
    if (!done.isCompleted) done.complete(null);
  });
  back.listen((m) {
    if (!done.isCompleted) {
      done.complete(
        m is TransferableTypedData ? m.materialize().asUint8List() : null,
      );
    }
  });
  try {
    iso = await Isolate.spawn(
      _drawThere,
      (
        back.sendPort,
        TransferableTypedData.fromList([b]),
        maxEdge,
        quality,
        draw,
      ),
      onExit: back.sendPort,
      onError: back.sendPort,
    );
    if (done.isCompleted) iso.kill(priority: Isolate.immediate);
    return await done.future;
  } catch (e) {
    dlog('convert: ${e.runtimeType}');
    return null;
  } finally {
    timer.cancel();
    back.close();
  }
}

void _drawThere(
  (SendPort, TransferableTypedData, int, int, Uint8List? Function(Uint8List)?)
  m,
) {
  final (to, bytes, maxEdge, quality, draw) = m;
  final b = bytes.materialize().asUint8List();
  final r = draw != null
      ? draw(b)
      : deskDrawJpeg(b, maxEdge: maxEdge, quality: quality);
  to.send(r == null ? null : TransferableTypedData.fromList([r]));
}
