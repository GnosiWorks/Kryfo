// SPDX-License-Identifier: GPL-3.0-or-later
// a picture copied on a computer (a screenshot, a browser's copy image),
// read off the clipboard as bytes and kept in memory. the runner hands over
// the png a copy carries, or else its dib, which is made a png here. nothing
// of it is written anywhere: it waits in the row like a dropped photo and
// goes the photo's way on send, cleaned and sealed
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'desktop_run.dart' show runChannel;

/// a picture's pixels, rgba, rows top down
class DibPixels {
  DibPixels(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final Uint8List rgba;
}

/// past this a pasted picture is not read: 8192 by 4096
const kDibMostPixels = 1 << 25;

const _rgb = 0, _bitfields = 3, _alphaBitfields = 6;

const _pngSig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

bool looksPng(Uint8List b) {
  if (b.length < 8) return false;
  for (var i = 0; i < 8; i++) {
    if (b[i] != _pngSig[i]) return false;
  }
  return true;
}

int _shiftOf(int mask) {
  var s = 0;
  while (s < 32 && (mask >> s) & 1 == 0) {
    s++;
  }
  return s;
}

int _bitsOf(int mask, int shift) {
  var n = 0;
  while (shift + n < 32 && (mask >> (shift + n)) & 1 == 1) {
    n++;
  }
  return n;
}

// a channel by its mask, widened to 8 bits
class _Chan {
  factory _Chan(int mask) {
    final shift = _shiftOf(mask);
    return _Chan._(mask, shift, mask == 0 ? 0 : _bitsOf(mask, shift));
  }
  _Chan._(this.mask, this.shift, this.bits);
  final int mask;
  final int shift;
  final int bits;

  int of(int px) {
    if (bits == 0) return 0;
    final v = (px & mask) >> shift;
    if (bits == 8) return v;
    final most = (1 << bits) - 1;
    return (v * 255 + most ~/ 2) ~/ most;
  }
}

/// a CF_DIB or CF_DIBV5 (a bitmap's info header, its masks and colours,
/// then its rows) as rgba, top down. 1, 4, 8, 16, 24 and 32 bits, plain or
/// with masks. null for anything else or anything short. alpha only where
/// a mask names it and not all of it is zero: a plain 32 bit dib's fourth
/// byte is not alpha
DibPixels? dibToRgba(Uint8List dib) {
  if (dib.length < 40) return null;
  final d = ByteData.sublistView(dib);
  final head = d.getUint32(0, Endian.little);
  if (head < 40 || head > dib.length) return null;
  final w = d.getInt32(4, Endian.little);
  final rawH = d.getInt32(8, Endian.little);
  final bpp = d.getUint16(14, Endian.little);
  final comp = d.getUint32(16, Endian.little);
  final used = d.getUint32(32, Endian.little);
  if (w <= 0 || rawH == 0) return null;
  final h = rawH.abs();
  final topDown = rawH < 0;
  if (w > 1 << 16 || h > 1 << 16 || w * h > kDibMostPixels) return null;
  if (comp != _rgb && comp != _bitfields && comp != _alphaBitfields) {
    return null;
  }
  if (comp != _rgb && bpp != 16 && bpp != 32) return null;
  if (!const {1, 4, 8, 16, 24, 32}.contains(bpp)) return null;

  var at = head;
  int r, g, b, a = 0;
  if (comp == _rgb) {
    (r, g, b) = bpp == 16
        ? (0x7C00, 0x03E0, 0x001F)
        : (0x00FF0000, 0x0000FF00, 0x000000FF);
  } else if (head >= 52) {
    r = d.getUint32(40, Endian.little);
    g = d.getUint32(44, Endian.little);
    b = d.getUint32(48, Endian.little);
    if (head >= 56) a = d.getUint32(52, Endian.little);
  } else {
    final n = comp == _alphaBitfields ? 16 : 12;
    if (dib.length < at + n) return null;
    r = d.getUint32(at, Endian.little);
    g = d.getUint32(at + 4, Endian.little);
    b = d.getUint32(at + 8, Endian.little);
    if (n == 16) a = d.getUint32(at + 12, Endian.little);
    at += n;
  }

  final colours = bpp <= 8 ? (used == 0 ? 1 << bpp : used) : used;
  if (bpp <= 8 && colours > 1 << bpp) return null;
  final stride = ((w * bpp + 31) >> 5) << 2;
  final rows = stride * h;
  // some copies repeat the masks after a v4 or v5 header
  if (comp != _rgb &&
      head >= 52 &&
      dib.length >= at + 12 + colours * 4 + rows &&
      d.getUint32(at, Endian.little) == r &&
      d.getUint32(at + 4, Endian.little) == g &&
      d.getUint32(at + 8, Endian.little) == b) {
    at += 12;
  }
  final table = at;
  at += colours * 4;
  if (dib.length < at + rows) return null;

  final out = Uint8List(w * h * 4);
  final cr = _Chan(r), cg = _Chan(g), cb = _Chan(b), ca = _Chan(a);
  var anyAlpha = false;
  for (var y = 0; y < h; y++) {
    final src = at + (topDown ? y : h - 1 - y) * stride;
    var o = y * w * 4;
    switch (bpp) {
      case 32:
        final plain = comp == _rgb;
        for (var x = 0; x < w; x++) {
          final s = src + x * 4;
          if (plain) {
            out[o] = dib[s + 2];
            out[o + 1] = dib[s + 1];
            out[o + 2] = dib[s];
            out[o + 3] = 255;
          } else {
            final px = d.getUint32(s, Endian.little);
            out[o] = cr.of(px);
            out[o + 1] = cg.of(px);
            out[o + 2] = cb.of(px);
            final al = ca.of(px);
            out[o + 3] = al;
            if (al != 0) anyAlpha = true;
          }
          o += 4;
        }
      case 24:
        for (var x = 0; x < w; x++) {
          final s = src + x * 3;
          out[o] = dib[s + 2];
          out[o + 1] = dib[s + 1];
          out[o + 2] = dib[s];
          out[o + 3] = 255;
          o += 4;
        }
      case 16:
        for (var x = 0; x < w; x++) {
          final px = d.getUint16(src + x * 2, Endian.little);
          out[o] = cr.of(px);
          out[o + 1] = cg.of(px);
          out[o + 2] = cb.of(px);
          final al = ca.of(px);
          out[o + 3] = al;
          if (al != 0) anyAlpha = true;
          o += 4;
        }
      default:
        final per = 8 ~/ bpp;
        final keep = (1 << bpp) - 1;
        for (var x = 0; x < w; x++) {
          final byte = dib[src + x ~/ per];
          final i = (byte >> ((per - 1 - x % per) * bpp)) & keep;
          if (i >= colours) return null;
          final c = table + i * 4;
          out[o] = dib[c + 2];
          out[o + 1] = dib[c + 1];
          out[o + 2] = dib[c];
          out[o + 3] = 255;
          o += 4;
        }
    }
  }
  // masks with no alpha, or alpha all zero: an opaque picture
  if (bpp == 16 || (bpp == 32 && comp != _rgb)) {
    if (a != 0 && anyAlpha) return DibPixels(w, h, out);
    for (var i = 3; i < out.length; i += 4) {
      out[i] = 255;
    }
  }
  return DibPixels(w, h, out);
}

/// [dib] made a png in memory, or null when it is no picture
Future<Uint8List?> dibToPng(Uint8List dib) async {
  final px = await compute(dibToRgba, dib);
  if (px == null) return null;
  final ui.ImmutableBuffer buf;
  try {
    buf = await ui.ImmutableBuffer.fromUint8List(px.rgba);
  } catch (_) {
    return null;
  }
  ui.Image? img;
  try {
    final desc = ui.ImageDescriptor.raw(
      buf,
      width: px.width,
      height: px.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await desc.instantiateCodec();
    try {
      img = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
      desc.dispose();
    }
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    return png?.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  } catch (_) {
    return null;
  } finally {
    img?.dispose();
    buf.dispose();
  }
}

/// the picture on the clipboard as png bytes, or null: none there, words
/// there too (they paste as words, unless only a link), or no runner call
Future<Uint8List?> clipboardPicture() async {
  final Map<Object?, Object?>? got;
  try {
    got = await runChannel.invokeMapMethod<Object?, Object?>('clipPicture');
  } catch (_) {
    return null;
  }
  return pictureOf(got);
}

/// what the runner handed over, as png bytes: a png as it is, a dib made
/// one. anything else is no picture, and so are words beside it that are
/// more than a link
Future<Uint8List?> pictureOf(Map<Object?, Object?>? got) async {
  final bytes = got?['bytes'];
  if (bytes is! Uint8List || bytes.isEmpty) return null;
  final words = got?['text'];
  if (words != null && (words is! String || !loneLink(words))) return null;
  switch (got?['kind']) {
    case 'png':
      return looksPng(bytes) ? bytes : null;
    case 'dib':
      return dibToPng(bytes);
  }
  return null;
}

/// past this many characters words are no link
const kLinkMost = 8192;

/// words that are only a link once trimmed: http or https, no space and
/// no other word. firefox's copy image puts the picture's address beside it
bool loneLink(String words) {
  final t = words.trim();
  if (t.isEmpty || t.length > kLinkMost || RegExp(r'\s').hasMatch(t)) {
    return false;
  }
  final u = Uri.tryParse(t);
  return u != null &&
      (u.scheme == 'http' || u.scheme == 'https') &&
      u.host.isNotEmpty;
}

/// [px] as a CF_DIBV5: a v5 header with masks and alpha, srgb, rows bottom
/// up, then bgra. what windows' paint and office take when they take no png
Uint8List rgbaToDib(DibPixels px) {
  const head = 124;
  final w = px.width, h = px.height;
  final out = Uint8List(head + w * h * 4);
  final d = ByteData.sublistView(out);
  d.setUint32(0, head, Endian.little);
  d.setInt32(4, w, Endian.little);
  d.setInt32(8, h, Endian.little);
  d.setUint16(12, 1, Endian.little);
  d.setUint16(14, 32, Endian.little);
  d.setUint32(16, _bitfields, Endian.little);
  d.setUint32(20, w * h * 4, Endian.little);
  d.setUint32(40, 0x00FF0000, Endian.little);
  d.setUint32(44, 0x0000FF00, Endian.little);
  d.setUint32(48, 0x000000FF, Endian.little);
  d.setUint32(52, 0xFF000000, Endian.little);
  // LCS_sRGB
  d.setUint32(56, 0x73524742, Endian.little);
  // LCS_GM_IMAGES
  d.setUint32(108, 4, Endian.little);
  for (var y = 0; y < h; y++) {
    var o = head + (h - 1 - y) * w * 4;
    var s = y * w * 4;
    for (var x = 0; x < w; x++) {
      out[o] = px.rgba[s + 2];
      out[o + 1] = px.rgba[s + 1];
      out[o + 2] = px.rgba[s];
      out[o + 3] = px.rgba[s + 3];
      o += 4;
      s += 4;
    }
  }
  return out;
}

/// [png] decoded to rgba, or null when it is none or too big
Future<DibPixels?> pngPixels(Uint8List png) async {
  if (!looksPng(png)) return null;
  ui.Codec? codec;
  ui.Image? img;
  try {
    codec = await ui.instantiateImageCodec(png);
    img = (await codec.getNextFrame()).image;
    if (img.width * img.height > kDibMostPixels) return null;
    final raw = await img.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (raw == null) return null;
    return DibPixels(
      img.width,
      img.height,
      raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
    );
  } catch (_) {
    return null;
  } finally {
    img?.dispose();
    codec?.dispose();
  }
}

/// [picture] (a png, a jpeg, a webp) as png bytes, decoded in memory.
/// null when it does not decode here (a heic on a computer)
Future<Uint8List?> pngOf(Uint8List picture) async {
  if (looksPng(picture)) return picture;
  ui.Codec? codec;
  ui.Image? img;
  try {
    codec = await ui.instantiateImageCodec(picture);
    img = (await codec.getNextFrame()).image;
    if (img.width * img.height > kDibMostPixels) return null;
    final b = await img.toByteData(format: ui.ImageByteFormat.png);
    return b?.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
  } catch (_) {
    return null;
  } finally {
    img?.dispose();
    codec?.dispose();
  }
}

/// "Copy picture": [picture] on the computer's clipboard as a png, from
/// memory. windows gets a bitmap beside it for the apps that take no png.
/// false when it would not decode, or the runner would not take it
Future<bool> copyPicture(Uint8List picture) async {
  try {
    final png = await pngOf(picture);
    if (png == null) return false;
    final args = <String, Object?>{'png': png};
    if (Platform.isWindows) {
      final px = await pngPixels(png);
      if (px == null) return false;
      args['dib'] = rgbaToDib(px);
    }
    return await runChannel.invokeMethod<bool>('setClipPicture', args) ?? false;
  } catch (_) {
    return false;
  }
}
