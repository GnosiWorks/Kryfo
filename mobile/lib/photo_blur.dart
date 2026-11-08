// SPDX-License-Identifier: GPL-3.0-or-later
// the blur a photo or a video's first frame shows while it decodes: its
// size and a few dozen colour waves, at most 115 bytes. it is kept in a file
// next to the media, sealed under the same container's key, so it opens
// only where the media opens. made at send and arrival, or at the first
// look while unlocked; read again after every unlock, never kept behind it
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'desktop/sealed_io.dart' show SealedIO, SealedLocked;
import 'dlog.dart';
import 'image_strip.dart' show PictureKind, pictureKind;
import 'desktop/desktop_trace.dart' show tracing;
import 'media_trace.dart' show mediaKindOf, mediaTraceOnce;
import 'open_file.dart' show nameSaysVideo, videoInfoFor;
import 'picture_lock.dart' show picturesShut;
import 'shred.dart' show kBlurLeaf;

const _version = 1;
// the most waves along the long side; the short side gets its share
const _waves = 6;
// pixels along the long side the waves are read from
const _readSide = 32;
// every blur is kept at the size of the largest, so its file's length says
// nothing of the photo's shape
const _stored = 10 + (_waves * _waves - 1) * 3;

class PhotoBlur {
  PhotoBlur._(this.width, this.height, this.nx, this.ny, this._waveRgb);

  /// the media's own size in pixels, for its shape
  final int width, height;
  final int nx, ny;
  // linear rgb per wave, the first one the mean colour
  final Float32List _waveRgb;
  Int32List? _colors;

  double get aspect => width / height;

  /// from straight rgba pixels of a small copy of the picture
  factory PhotoBlur.fromPixels(
    Uint8List rgba,
    int w,
    int h, {
    required int width,
    required int height,
  }) {
    final long = math.max(width, height);
    final short = math.min(width, height);
    final along = _waves;
    final across = (along * short / long).round().clamp(3, _waves);
    final nx = width >= height ? along : across;
    final ny = width >= height ? across : along;
    final lin = Float32List(w * h * 3);
    for (var i = 0; i < w * h; i++) {
      final a = rgba[i * 4 + 3] / 255;
      for (var c = 0; c < 3; c++) {
        // what shows through is drawn over a middle grey
        final v = rgba[i * 4 + c] * a + 128 * (1 - a);
        lin[i * 3 + c] = _toLinear(v);
      }
    }
    final waves = Float32List(nx * ny * 3);
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        var r = 0.0, g = 0.0, b = 0.0;
        for (var y = 0; y < h; y++) {
          final cy = math.cos(math.pi * j * y / h);
          for (var x = 0; x < w; x++) {
            final basis = math.cos(math.pi * i * x / w) * cy;
            final at = (y * w + x) * 3;
            r += basis * lin[at];
            g += basis * lin[at + 1];
            b += basis * lin[at + 2];
          }
        }
        final scale = (i == 0 && j == 0 ? 1 : 2) / (w * h);
        final k = (j * nx + i) * 3;
        waves[k] = r * scale;
        waves[k + 1] = g * scale;
        waves[k + 2] = b * scale;
      }
    }
    lin.fillRange(0, lin.length, 0);
    return PhotoBlur._(
      width.clamp(1, 65535),
      height.clamp(1, 65535),
      nx,
      ny,
      waves,
    )._quantized();
  }

  // as it reads back from its bytes, so a fresh one draws the same
  PhotoBlur _quantized() => PhotoBlur.decode(encode())!;

  Uint8List encode() {
    final n = nx * ny;
    final out = Uint8List(_stored);
    out[0] = _version;
    out[1] = width >> 8;
    out[2] = width & 0xff;
    out[3] = height >> 8;
    out[4] = height & 0xff;
    out[5] = nx | (ny << 4);
    for (var c = 0; c < 3; c++) {
      out[6 + c] = _toSrgb(_waveRgb[c]);
    }
    var most = 0.0;
    for (var k = 3; k < n * 3; k++) {
      most = math.max(most, _waveRgb[k].abs());
    }
    final q = (most * 128 - 1).round().clamp(0, 255);
    out[9] = q;
    final top = (q + 1) / 128;
    for (var k = 3; k < n * 3; k++) {
      final v = _signPow(_waveRgb[k] / top, 0.5);
      out[10 + k - 3] = (v * 127).round().clamp(-127, 127) & 0xff;
    }
    return out;
  }

  /// null for bytes that are no blur of this version
  static PhotoBlur? decode(Uint8List b) {
    if (b.length != _stored || b[0] != _version) return null;
    final width = (b[1] << 8) | b[2];
    final height = (b[3] << 8) | b[4];
    final nx = b[5] & 0x0f, ny = b[5] >> 4;
    if (width == 0 || height == 0 || nx == 0 || ny == 0) return null;
    if (nx > _waves || ny > _waves) return null;
    final n = nx * ny;
    final waves = Float32List(n * 3);
    for (var c = 0; c < 3; c++) {
      waves[c] = _toLinear(b[6 + c].toDouble());
    }
    final top = (b[9] + 1) / 128;
    for (var k = 3; k < n * 3; k++) {
      final s = b[10 + k - 3].toSigned(8) / 127;
      waves[k] = _signPow(s, 2) * top;
    }
    return PhotoBlur._(width, height, nx, ny, waves);
  }

  // a grid fine enough that its corners, blended, read as the waves
  int get cols => nx * 4;
  int get rows => ny * 4;

  /// the colour at each corner of the grid, row by row, as argb
  Int32List get colors => _colors ??= _corners();

  Int32List _corners() {
    final out = Int32List((cols + 1) * (rows + 1));
    final cx = [
      for (var x = 0; x <= cols; x++)
        [for (var i = 0; i < nx; i++) math.cos(math.pi * i * x / cols)],
    ];
    final cy = [
      for (var y = 0; y <= rows; y++)
        [for (var j = 0; j < ny; j++) math.cos(math.pi * j * y / rows)],
    ];
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= cols; x++) {
        var r = 0.0, g = 0.0, b = 0.0;
        for (var j = 0; j < ny; j++) {
          for (var i = 0; i < nx; i++) {
            final basis = cx[x][i] * cy[y][j];
            final k = (j * nx + i) * 3;
            r += _waveRgb[k] * basis;
            g += _waveRgb[k + 1] * basis;
            b += _waveRgb[k + 2] * basis;
          }
        }
        out[y * (cols + 1) + x] =
            0xff000000 | (_toSrgb(r) << 16) | (_toSrgb(g) << 8) | _toSrgb(b);
      }
    }
    return out;
  }

  /// zeros over what it holds: the lock is going up
  void wipe() {
    _waveRgb.fillRange(0, _waveRgb.length, 0);
    _colors?.fillRange(0, _colors!.length, 0);
    _colors = null;
  }
}

double _toLinear(double v) {
  final x = v / 255;
  return x <= 0.04045 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4) * 1.0;
}

int _toSrgb(double v) {
  final x = v.clamp(0.0, 1.0);
  final s = x <= 0.0031308 ? x * 12.92 : 1.055 * math.pow(x, 1 / 2.4) - 0.055;
  return (s * 255 + 0.5).floor().clamp(0, 255);
}

double _signPow(double v, double e) =>
    v.isNegative ? -math.pow(-v, e).toDouble() : math.pow(v, e).toDouble();

/// where the blur of [media] is kept
String blurPathOf(String media) => '$media$kBlurLeaf';

/// whether [path] is a blur's file
bool isBlurFile(String path) => path.endsWith(kBlurLeaf);

/// a blur is kept only where the seal covers the media: never in the clear
bool blurSealedAt(String media) {
  final io = IOOverrides.current;
  return io is SealedIO && io.areas.sealedPlace(media);
}

// the blurs read since the last unlock, and the files that have none
final _blurs = <String, PhotoBlur?>{};

/// the blur of [media] as it stands now: read from its sealed file the
/// first time after an unlock, synchronously, so it is there for the first
/// frame. null under the lock, where the seal does not cover it, or when
/// none was made
PhotoBlur? blurNow(String media) {
  if (picturesShut.value) return null;
  if (_blurs.containsKey(media)) return _blurs[media];
  final (b, keep) = _read(media);
  if (!keep) return null;
  if (_blurs.length >= 600) _blurs.remove(_blurs.keys.first);
  return _blurs[media] = b;
}

// the blur, and whether the answer holds until the next lock: one whose
// key is not here yet is asked again
(PhotoBlur?, bool) _read(String media) {
  if (!blurSealedAt(media)) return (null, true);
  try {
    final f = File(blurPathOf(media));
    if (!f.existsSync()) return (null, true);
    final bytes = f.readAsBytesSync();
    final b = PhotoBlur.decode(bytes);
    bytes.fillRange(0, bytes.length, 0);
    return (b, true);
  } on SealedLocked {
    return (null, false);
  } catch (e) {
    // damaged, or under another key: drawn without one
    return (null, true);
  }
}

/// the lock is going up: what was read goes, zeroed
void forgetBlurs() {
  for (final b in _blurs.values) {
    b?.wipe();
  }
  _blurs.clear();
}

/// [media] is going: its blur is not read again
void forgetBlurOf(String media) => _blurs.remove(media)?.wipe();

// ---- making them ----

final _queue = <String, Uint8List?>{};
bool _running = false;
int _gen = 0;

/// the lock is going up: what waits to be made is dropped
void stopBlurs() {
  _gen++;
  // the bytes handed in are the sender's own: let go, never zeroed here
  _queue.clear();
}

/// a blur made for [media] soon, one at a time, while unlocked. [bytes]:
/// the picture as it was just written, so it is not read again
void makeBlurSoon(String media, {Uint8List? bytes}) {
  if (picturesShut.value || !blurSealedAt(media)) return;
  if (_blurs[media] != null || _queue.containsKey(media)) return;
  _queue[media] = bytes;
  if (!_running) unawaited(_drain());
}

Future<void> _drain() async {
  _running = true;
  try {
    while (_queue.isNotEmpty && !picturesShut.value) {
      final media = _queue.keys.first;
      final bytes = _queue.remove(media);
      final gen = _gen;
      try {
        await makeBlur(media, bytes: bytes, gen: gen);
      } catch (e) {
        dlog('blur: not made (${e.runtimeType})');
      }
    }
  } finally {
    _running = false;
  }
}

/// the blur of [media] made and sealed next to it, unless it has one. a
/// video's from its first frame. nothing is kept when the lock went up on
/// the way
@visibleForTesting
Future<PhotoBlur?> makeBlur(String media, {Uint8List? bytes, int? gen}) async {
  gen ??= _gen;
  bool stale() => gen != _gen || picturesShut.value;
  if (stale() || !blurSealedAt(media)) return null;
  final known = blurNow(media);
  if (known != null) return known;
  Uint8List? picture = bytes;
  var ours = false;
  if (picture == null) {
    if (nameSaysVideo(media)) {
      picture = (await videoInfoFor(media))?.jpeg;
    } else {
      if (!await _looksLikePicture(media)) {
        _blurMissing(media, 'not a picture');
        return null;
      }
      // read as the bubble reads it: the keys stay on this isolate
      picture = await File(media).readAsBytes();
      ours = true;
    }
  }
  if (picture == null || stale()) return null;
  PhotoBlur? blur;
  try {
    blur = await blurOfPicture(picture);
  } finally {
    if (ours) picture.fillRange(0, picture.length, 0);
  }
  if (blur == null || stale()) {
    if (blur == null) _blurMissing(media, 'no decode');
    blur?.wipe();
    return null;
  }
  // the file went while its blur was made: nothing is left behind it
  if (!File(media).existsSync()) return null;
  final out = blur.encode();
  try {
    File(blurPathOf(media)).writeAsBytesSync(out, flush: true);
  } finally {
    out.fillRange(0, out.length, 0);
  }
  if (stale()) return null;
  _blurs[media] = blur;
  mediaTraceOnce(media, 'blur', 'blur made');
  return blur;
}

// the trace's line for a picture left without a blur: why, and its kind
void _blurMissing(String media, String why) {
  if (!tracing) return;
  mediaKindOf(
    media,
  ).then((kind) => mediaTraceOnce(media, 'blur', 'blur missing: $why $kind'));
}

Future<bool> _looksLikePicture(String media) async {
  try {
    final f = await File(media).open();
    try {
      return pictureKind(await f.read(32)) != PictureKind.other;
    } finally {
      await f.close();
    }
  } catch (_) {
    return false;
  }
}

/// the blur of an encoded picture: decoded small, its waves read, the
/// pixels zeroed. null when it does not decode
Future<PhotoBlur?> blurOfPicture(Uint8List picture) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? d;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(picture);
    d = await ui.ImageDescriptor.encoded(buffer);
    final w = d.width, h = d.height;
    if (w <= 0 || h <= 0) return null;
    final long = math.max(w, h);
    final side = math.min(_readSide, long);
    final tw = math.max(1, (side * w / long).round());
    final th = math.max(1, (side * h / long).round());
    codec = await d.instantiateCodec(targetWidth: tw, targetHeight: th);
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) return null;
    final px = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    try {
      return PhotoBlur.fromPixels(
        px,
        image.width,
        image.height,
        width: w,
        height: h,
      );
    } finally {
      px.fillRange(0, px.length, 0);
    }
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    d?.dispose();
    buffer?.dispose();
  }
}

/// how many blurs are read and held now
@visibleForTesting
int get blursHeld => _blurs.length;

@visibleForTesting
void resetBlursForTest() {
  stopBlurs();
  forgetBlurs();
}
