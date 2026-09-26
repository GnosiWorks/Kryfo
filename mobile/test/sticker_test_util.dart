// SPDX-License-Identifier: GPL-3.0-or-later
// what the sticker tests share: the pack read from disk, a frame rendered to
// rgba, and a png reader for the reference renders (rgba8, what they are).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_player.dart';

const packFile = 'assets/stickers/fokia.kst';
const artDir = 'tool/stickers/fokia';
// rendered by tool/pack_stickers.py --png, not committed
const pngDir = 'build/stickers/png';

StickerPack loadPack() =>
    StickerPack.parse(ByteData.sublistView(File(packFile).readAsBytesSync()));

/// the reference png of a sticker, named after its svg
File pngFor(int id) {
  final nn = id.toString().padLeft(2, '0');
  final svg = Directory('$artDir/svg').listSync().whereType<File>().firstWhere(
    (f) => f.uri.pathSegments.last.startsWith('fokia-$nn-'),
  );
  final name = svg.uri.pathSegments.last.replaceFirst(
    RegExp(r'\.svg$'),
    '.png',
  );
  return File('$pngDir/$name');
}

/// a frame at [side] px, premultiplied rgba. t null: the still picture;
/// otherwise the animated painter at t ms.
Future<Uint8List> renderSticker(Sticker s, {double? t, int side = 512}) async {
  final r = ui.PictureRecorder();
  final c = ui.Canvas(r);
  c.scale(side / kStickerBox);
  c.clipRect(const ui.Rect.fromLTWH(0, 0, kStickerBox, kStickerBox));
  if (t == null) {
    c.drawPicture(s.still);
  } else {
    paintSticker(c, s, evaluateSticker(s, t));
  }
  final img = await r.endRecording().toImage(side, side);
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  return data!.buffer.asUint8List();
}

class Rgba {
  final int width, height;
  // straight (not premultiplied) rgba, row by row
  final Uint8List px;
  Rgba(this.width, this.height, this.px);

  Uint8List premultiplied() {
    final out = Uint8List(px.length);
    for (var i = 0; i < px.length; i += 4) {
      final a = px[i + 3];
      out[i] = (px[i] * a / 255).round();
      out[i + 1] = (px[i + 1] * a / 255).round();
      out[i + 2] = (px[i + 2] * a / 255).round();
      out[i + 3] = a;
    }
    return out;
  }
}

Rgba decodePng(Uint8List b) {
  const sig = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < 8; i++) {
    if (b[i] != sig[i]) throw const FormatException('not a png');
  }
  final d = ByteData.sublistView(b);
  var w = 0, h = 0;
  final idat = BytesBuilder(copy: false);
  var i = 8;
  while (i + 8 <= b.length) {
    final n = d.getUint32(i);
    final type = String.fromCharCodes(b.sublist(i + 4, i + 8));
    final body = Uint8List.sublistView(b, i + 8, i + 8 + n);
    if (type == 'IHDR') {
      w = d.getUint32(i + 8);
      h = d.getUint32(i + 12);
      // 8-bit rgba, deflate, adaptive filters, no interlace
      if (body[8] != 8 || body[9] != 6 || body[12] != 0) {
        throw const FormatException('only rgba8, not interlaced');
      }
    } else if (type == 'IDAT') {
      idat.add(body);
    } else if (type == 'IEND') {
      break;
    }
    i += 12 + n;
  }
  final raw = Uint8List.fromList(ZLibDecoder().convert(idat.takeBytes()));
  final stride = w * 4;
  final out = Uint8List(stride * h);
  for (var y = 0; y < h; y++) {
    final f = raw[y * (stride + 1)];
    final src = y * (stride + 1) + 1;
    final row = y * stride;
    for (var x = 0; x < stride; x++) {
      final a = x >= 4 ? out[row + x - 4] : 0;
      final up = y > 0 ? out[row - stride + x] : 0;
      final c = (x >= 4 && y > 0) ? out[row - stride + x - 4] : 0;
      final v = raw[src + x];
      out[row + x] =
          switch (f) {
            0 => v,
            1 => v + a,
            2 => v + up,
            3 => v + ((a + up) >> 1),
            4 => v + _paeth(a, up, c),
            _ => throw FormatException('filter $f'),
          } &
          0xFF;
    }
  }
  return Rgba(w, h, out);
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

/// an rgba image as a png file, for looking at a failure
Future<void> writePng(String path, Uint8List rgba, int w, int h) async {
  final buf = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(
    buf,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await desc.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}
