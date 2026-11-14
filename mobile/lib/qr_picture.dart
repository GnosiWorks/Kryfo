// SPDX-License-Identifier: GPL-3.0-or-later
// a qr code read from a picture the person picks. all of it happens on the
// device: the picture is drawn by dart's own decoders (memory-safe) in a
// throwaway isolate with caps on bytes and pixels, and zxing-cpp only ever
// sees plain grey pixels, never the file. readQrPicture is the one door, so
// the decode can move into the isolated parse helper later
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'desktop/desktop_mode.dart' show onDesktop;
import 'dlog.dart';
import 'l10n/l10n.dart';
import 'lock_guard.dart' show LockDropped;
import 'lock_state.dart';
import 'picked.dart' show shredPickedImages;

const _platform = MethodChannel('halo/platform');

/// past this a picture is not read
const kQrPictureBytesMost = 40 * 1024 * 1024;
const kQrPicturePixelsMost = 40 * 1000 * 1000;

// the long sides tried, small first: most codes read at the first
const _edges = [1200, 2400];

// what dart draws on every platform; others go through the phone first
const _desktopTypes = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'];

/// windows ships no qr reader library, so it reads no pictures either
bool get qrPictureHere => !Platform.isWindows;

@visibleForTesting
Future<Uint8List?> Function()? qrPicturePickForTest;

@visibleForTesting
Future<String?> Function(Uint8List bytes)? qrPictureReadForTest;

/// a picture from the gallery (a file on a computer), its bytes. null:
/// nothing picked, or the lock came up meanwhile. the picker's copy on a
/// phone is shredded once read; a computer's file is read in place
Future<Uint8List?> pickQrPicture() async {
  final seam = qrPicturePickForTest;
  if (seam != null) return seam();
  try {
    if (onDesktop) {
      final path = await lockState.hold(
        () async => (await FileSelectorPlatform.instance.openFile(
          acceptedTypeGroups: [
            XTypeGroup(label: l10n.photoKnowsPhoto, extensions: _desktopTypes),
          ],
        ))?.path,
      );
      if (path == null) return null;
      final f = File(path);
      if (await f.length() > kQrPictureBytesMost) return Uint8List(0);
      return await f.readAsBytes();
    }
    final x = await lockState.hold(
      () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      ),
    );
    if (x == null) return null;
    try {
      if (await x.length() > kQrPictureBytesMost) return Uint8List(0);
      return await x.readAsBytes();
    } finally {
      await shredPickedImages([x]);
    }
  } on LockDropped {
    return null;
  } catch (e) {
    dlog('qr picture: not picked (${e.runtimeType})');
    return Uint8List(0);
  }
}

/// the text of the first qr code in [bytes], or null when there is none
/// or the picture does not draw
Future<String?> readQrPicture(Uint8List bytes) async {
  final seam = qrPictureReadForTest;
  if (seam != null) return seam(bytes);
  if (bytes.isEmpty || bytes.length > kQrPictureBytesMost) return null;
  try {
    final r = await Isolate.run(() => _read(bytes));
    if (r != _notDrawn) return r;
    // a format dart does not draw (heic on many phones): the phone draws
    // it as a plain jpeg first, as it does for a profile photo
    if (onDesktop || !Platform.isAndroid) return null;
    final jpeg = await _platform.invokeMethod<Uint8List>('shrinkJpeg', {
      'bytes': bytes,
      'maxEdge': _edges.last,
      'quality': 95,
    });
    if (jpeg == null || jpeg.isEmpty) return null;
    final again = await Isolate.run(() => _read(jpeg));
    return again == _notDrawn ? null : again;
  } catch (e) {
    dlog('qr picture: not read (${e.runtimeType})');
    return null;
  }
}

const _notDrawn = '\u0000';

/// the decoder for [bytes] among the formats a gallery holds, or null.
/// the image package knows more (tiff, psd, exr, ico, tga ...): an ico
/// carries a png of any size past the pixel cap, so none of them runs
@visibleForTesting
img.Decoder? qrPictureDecoder(Uint8List bytes) {
  for (final d in <img.Decoder>[
    img.JpegDecoder(),
    img.PngDecoder(),
    img.GifDecoder(),
    img.WebPDecoder(),
    img.BmpDecoder(),
  ]) {
    if (d.isValidFile(bytes)) return d;
  }
  return null;
}

// in the isolate: draw, shrink, grey, read
String? _read(Uint8List bytes) {
  final dec = qrPictureDecoder(bytes);
  if (dec == null) return _notDrawn;
  final info = dec.startDecode(bytes);
  if (info == null) return _notDrawn;
  if (info.width <= 0 || info.height <= 0) return null;
  if (info.width * info.height > kQrPicturePixelsMost) return null;
  final pic = dec.decodeFrame(0);
  if (pic == null) return null;
  final long = math.max(pic.width, pic.height);
  for (final edge in _edges) {
    final s = math.min(1.0, edge / long);
    final it = s < 1
        ? img.copyResize(
            pic,
            width: (pic.width * s).round(),
            height: (pic.height * s).round(),
            interpolation: img.Interpolation.average,
          )
        : pic;
    final text = readGrey(it);
    if (text != null) return text;
    if (s == 1) break;
  }
  return null;
}

/// one picture's grey pixels through zxing
@visibleForTesting
String? readGrey(img.Image pic) {
  final w = pic.width, h = pic.height;
  final grey = Uint8List(w * h);
  var i = 0;
  for (final p in pic) {
    // a see-through pixel reads as white paper
    final a = pic.hasAlpha ? p.aNormalized : 1.0;
    final l = img.getLuminanceRgb(p.r, p.g, p.b) / p.maxChannelValue * 255;
    grey[i++] = (l * a + 255 * (1 - a)).round().clamp(0, 255);
  }
  final code = zx.readBarcode(
    grey,
    DecodeParams(
      imageFormat: ImageFormat.lum,
      format: Format.qrCode,
      width: w,
      height: h,
      tryHarder: true,
      tryRotate: true,
      tryInverted: true,
      tryDownscale: true,
      maxSize: math.max(w, h),
    ),
  );
  final t = code.text;
  return code.isValid && t != null && t.isNotEmpty ? t : null;
}
