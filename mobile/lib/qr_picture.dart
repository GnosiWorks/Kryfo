// SPDX-License-Identifier: GPL-3.0-or-later
// a qr code read from a picture the person picks. all of it happens on the
// device: the picture is drawn by dart's own decoders (memory-safe) in a
// throwaway isolate with caps on bytes and pixels, and zxing-cpp only ever
// sees plain grey pixels, never the file. readQrPicture is the one door, so
// the decode can move into the isolated parse helper later
import 'dart:async';
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

/// a picture still not read after this reads as none, and its isolate goes
const kQrPictureTime = Duration(seconds: 20);

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
      return await readAtMost(path, kQrPictureBytesMost);
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

/// a file's bytes, read no further than [most]: past it, none. a file that
/// grows, or a link to an endless one, never fills the memory
@visibleForTesting
Future<Uint8List> readAtMost(String path, int most) async {
  final f = await File(path).open();
  try {
    final b = await f.read(most + 1);
    return b.length > most ? Uint8List(0) : b;
  } finally {
    await f.close();
  }
}

/// the text of the first qr code in [bytes], or null when there is none
/// or the picture does not draw
Future<String?> readQrPicture(Uint8List bytes) async {
  final seam = qrPictureReadForTest;
  if (seam != null) return seam(bytes);
  if (bytes.isEmpty || bytes.length > kQrPictureBytesMost) return null;
  try {
    final r = await inIsolateAtMost(() => _read(bytes), kQrPictureTime);
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
    final again = await inIsolateAtMost(() => _read(jpeg), kQrPictureTime);
    return again == _notDrawn ? null : again;
  } catch (e) {
    dlog('qr picture: not read (${e.runtimeType})');
    return null;
  }
}

/// [work] in its own isolate, killed if it runs past [most]: then null.
/// an error in it is null too
Future<T?> inIsolateAtMost<T>(T Function() work, Duration most) async {
  final port = ReceivePort();
  Isolate? iso;
  try {
    iso = await Isolate.spawn<(SendPort, T Function())>(
      _sendBack<T>,
      (port.sendPort, work),
      onExit: port.sendPort,
      onError: port.sendPort,
      errorsAreFatal: true,
    );
    // its answer comes as [result]; an exit comes as null, an error as
    // [error, stack]
    final m = await port.first.timeout(most);
    return m is List && m.length == 1 ? m.first as T? : null;
  } on TimeoutException {
    dlog('qr picture: out of time');
    return null;
  } finally {
    iso?.kill(priority: Isolate.immediate);
    port.close();
  }
}

void _sendBack<T>((SendPort, T Function()) m) => m.$1.send([m.$2()]);

/// what [readQrPictureHere] says for a picture dart does not draw
@visibleForTesting
const qrNotDrawn = '\u0000';
const _notDrawn = qrNotDrawn;

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
String? _read(Uint8List bytes) => readQrPictureHere(bytes);

/// [readQrPicture] without the isolate: the text, null, or [qrNotDrawn]
@visibleForTesting
String? readQrPictureHere(Uint8List bytes) {
  final dec = qrPictureDecoder(bytes);
  if (dec == null) return _notDrawn;
  final info = dec.startDecode(bytes);
  if (info == null) return _notDrawn;
  // an animated webp's frames carry their own size, not the canvas checked
  // below: the phone's decoder takes its first frame
  if (info is img.WebPInfo && info.hasAnimation) return _notDrawn;
  if (info.width <= 0 || info.height <= 0) return null;
  if (info.width * info.height > kQrPicturePixelsMost) return null;
  if (dec is img.PngDecoder && !pngDataFits(bytes)) return null;
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

class _TooBig implements Exception {
  const _TooBig();
}

// counts what zlib gives back and stops it past [most]
class _Counted implements Sink<List<int>> {
  final int most;
  var n = 0;
  _Counted(this.most);
  @override
  void add(List<int> chunk) {
    n += chunk.length;
    if (n > most) throw const _TooBig();
  }

  @override
  void close() {}
}

/// a png's pixel data inflates to no more than its header allows. the
/// image package inflates it whole with no limit, so a few kB of zeros
/// behind a small width and height would grow to gigabytes
@visibleForTesting
bool pngDataFits(Uint8List bytes) {
  final b = ByteData.sublistView(bytes);
  int? w, h, depth, type, interlace;
  final idat = <Uint8List>[];
  var o = 8;
  while (o + 8 <= bytes.length) {
    final len = b.getUint32(o);
    final kind = String.fromCharCodes(bytes, o + 4, o + 8);
    final at = o + 8;
    if (len > bytes.length - at) break;
    if (kind == 'IHDR' && len >= 13) {
      w = b.getUint32(at);
      h = b.getUint32(at + 4);
      depth = bytes[at + 8];
      type = bytes[at + 9];
      interlace = bytes[at + 12];
    } else if (kind == 'IDAT') {
      idat.add(Uint8List.sublistView(bytes, at, at + len));
    } else if (kind == 'IEND') {
      break;
    }
    o = at + len + 4;
  }
  if (w == null || h == null || depth == null) return false;
  final channels = switch (type) {
    0 || 3 => 1,
    4 => 2,
    2 => 3,
    6 => 4,
    _ => 0,
  };
  if (channels == 0) return false;
  final bits = channels * depth;
  int rows(int pw, int ph) =>
      pw <= 0 || ph <= 0 ? 0 : ph * (1 + (pw * bits + 7) ~/ 8);
  var most = 0;
  if (interlace == 1) {
    // adam7: seven passes, each row with its own filter byte
    for (final (x0, y0, dx, dy) in const [
      (0, 0, 8, 8),
      (4, 0, 8, 8),
      (0, 4, 4, 8),
      (2, 0, 4, 4),
      (0, 2, 2, 4),
      (1, 0, 2, 2),
      (0, 1, 1, 2),
    ]) {
      most += rows((w - x0 + dx - 1) ~/ dx, (h - y0 + dy - 1) ~/ dy);
    }
  } else {
    most = rows(w, h);
  }
  try {
    final z = ZLibDecoder().startChunkedConversion(_Counted(most));
    for (final d in idat) {
      z.add(d);
    }
    z.close();
    return true;
  } catch (_) {
    // past the size, or data zlib will not take
    return false;
  }
}
