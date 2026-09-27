// SPDX-License-Identifier: GPL-3.0-or-later
// every sticker's still frame in each pack, drawn by the app's own painter,
// against the png tool/pack_stickers.py --png paints from the svgs. no golden
// files: the pngs are built, not committed. skia's anti-aliasing is not
// exact area coverage, so the share within 24 is taken after a 3x3 box
// filter on both; the mean and the eroded mask stay raw.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/stickers/sticker_pack.dart';

import 'sticker_test_util.dart';

class Diff {
  final double mean;
  final double rawWithin24;
  final double within24;
  final int eroded;
  final int rimPixels;
  final double rimMean;
  final Uint8List map;
  Diff(
    this.mean,
    this.rawWithin24,
    this.within24,
    this.eroded,
    this.rimPixels,
    this.rimMean,
    this.map,
  );
}

Diff compare(Uint8List ours, Uint8List ref, Uint8List refStraight) {
  const w = 512;
  var sum = 0;
  var within = 0;
  var rim = 0, rimSum = 0;
  final big = Uint8List(w * w);
  final map = Uint8List(w * w * 4);
  for (var p = 0; p < w * w; p++) {
    var worst = 0;
    for (var ch = 0; ch < 4; ch++) {
      final d = (ours[p * 4 + ch] - ref[p * 4 + ch]).abs();
      sum += d;
      if (d > worst) worst = d;
    }
    if (worst <= 24) within++;
    if (worst > 96) big[p] = 1;
    final a = refStraight[p * 4 + 3];
    if (a > 0 && a < 255) {
      rim++;
      rimSum += worst;
    }
    map[p * 4] = worst;
    map[p * 4 + 1] = worst > 24 ? 0 : worst;
    map[p * 4 + 2] = worst > 96 ? 255 : 0;
    map[p * 4 + 3] = 255;
  }
  final sa = _box3(ours), sb = _box3(ref);
  var smooth = 0;
  for (var p = 0; p < w * w; p++) {
    var worst = 0;
    for (var ch = 0; ch < 4; ch++) {
      final d = (sa[p * 4 + ch] - sb[p * 4 + ch]).abs();
      if (d > worst) worst = d;
    }
    if (worst <= 24) smooth++;
  }
  // a pixel off at an edge erodes away; a missing or moved shape does not
  var eroded = 0;
  for (var y = 1; y < w - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      var all = true;
      for (var dy = -1; dy <= 1 && all; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (big[(y + dy) * w + x + dx] == 0) {
            all = false;
            break;
          }
        }
      }
      if (all) eroded++;
    }
  }
  return Diff(
    sum / (w * w * 4),
    within / (w * w),
    smooth / (w * w),
    eroded,
    rim,
    rim == 0 ? 0 : rimSum / rim,
    map,
  );
}

Int32List _box3(Uint8List px) {
  const w = 512;
  final out = Int32List(px.length);
  for (var y = 0; y < w; y++) {
    for (var x = 0; x < w; x++) {
      for (var ch = 0; ch < 4; ch++) {
        var s = 0, n = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= w) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= w) continue;
            s += px[(yy * w + xx) * 4 + ch];
            n++;
          }
        }
        out[(y * w + x) * 4 + ch] = (s / n).round();
      }
    }
  }
  return out;
}

void main() {
  group('fokia', () {
    _pixelTests(fokiaFiles);
    test('the picker offers every sticker', () {
      expect(loadPack().playable, [for (var i = 1; i <= 29; i++) i]);
      expect(kStickerBox, 512);
    });
  });
  group('fokia remix', () {
    _pixelTests(remixFiles);
    test('the picker offers every sticker', () {
      final pack = loadPack(remixFiles);
      expect(pack.playable, [for (var i = 30; i <= 47; i++) i]);
      expect(pack.offered, pack.playable);
    });

    testWidgets('faint and hidden groups draw as the svg has them', (
      tester,
    ) async {
      final pack = loadPack(remixFiles);
      Future<Uint8List> frame(int id, [double? t]) async => (await tester
          .runAsync(() => renderSticker(pack.sticker(id)!, t: t)))!;
      // the art's black outline at full strength, in [_ink]'s units
      const black = 244;
      // tiny violin: the middle note at 0.37, the top one at 0.03
      var f = await frame(36);
      expect(_ink(f, 136, 148, 149, 168), closeTo(0.37 * black, 16));
      expect(_ink(f, 122, 71, 159, 118), lessThan(20));
      // vibing: the left note at 0.5
      f = await frame(37);
      expect(_ink(f, 79, 103, 120, 154), closeTo(0.5 * black, 16));
      // power up: the top right bolt is hidden at rest, where only the
      // outer glow's faint edge is, and its track brings it in
      final s = pack.sticker(44)!;
      for (final t in [null, 0.0, s.loopMs.toDouble()]) {
        expect(_ink(await frame(44, t), 371, 134, 394, 194), lessThan(120));
      }
      expect(_ink(await frame(44, 100), 371, 134, 394, 194), greaterThan(200));
    });

    testWidgets('notes fade as they rise and keep the svg\'s outline', (
      tester,
    ) async {
      final pack = loadPack(remixFiles);
      Future<Uint8List> frame(int id, [double? t]) async => (await tester
          .runAsync(() => renderSticker(pack.sticker(id)!, t: t)))!;
      const black = 244;
      // tiny violin halfway: the note coming up is strong, the one near the
      // top faint
      final f = await frame(36, 1500);
      expect(_ink(f, 114, 170, 144, 202), closeTo(0.535 * black, 16));
      expect(_ink(f, 100, 118, 132, 152), closeTo(0.2 * black, 16));
      // vibing: the right note near the bottom, then near the top
      expect(
        _ink(await frame(37, 100), 385, 165, 418, 198),
        closeTo(0.9 * black, 16),
      );
      expect(
        _ink(await frame(37, 700), 425, 95, 458, 132),
        closeTo(0.3 * black, 16),
      );
      // the left note at rest is half ink over an opaque white outline, as
      // the svg's die-cut draws it, not an outline faded with the note
      expect(_white(await frame(37), 79, 103, 120, 154), greaterThan(300));
    });
  });
}

// opaque white pixels in a box: the outline showing in full
int _white(Uint8List px, int x0, int y0, int x1, int y1) {
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * 512 + x) * 4;
      if (px[i + 3] == 255 && px[i + 1] >= 250) n++;
    }
  }
  return n;
}

// the darkest a box gets: alpha less green in premultiplied rgba, so a faint
// part reads faint over the white outline and over nothing alike
int _ink(Uint8List px, int x0, int y0, int x1, int y1) {
  var most = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * 512 + x) * 4;
      final v = px[i + 3] - px[i + 1];
      if (v > most) most = v;
    }
  }
  return most;
}

void _pixelTests(PackFiles f) {
  final pack = loadPack(f);

  testWidgets('every still matches its png', (tester) async {
    if (!Directory(f.png).existsSync()) {
      markTestSkipped('render the reference pngs first: ${f.tool} --png');
      return;
    }
    final lines = <String>[];
    final bad = <String>[];
    for (final id in pack.ids) {
      final s = pack.sticker(id)!;
      final ref = decodePng(pngFor(id, f).readAsBytesSync());
      expect(ref.width, 512);
      final ours = (await tester.runAsync(() => renderSticker(s)))!;
      final d = compare(ours, ref.premultiplied(), ref.px);
      final nn = id.toString().padLeft(2, '0');
      lines.add(
        '$nn mean ${(d.mean).toStringAsFixed(3)}/255'
        '  within 24: ${(d.within24 * 100).toStringAsFixed(2)}%'
        ' (raw ${(d.rawWithin24 * 100).toStringAsFixed(2)}%)'
        '  eroded: ${d.eroded}'
        '  rim ${d.rimPixels} px at ${d.rimMean.toStringAsFixed(1)}',
      );
      if (d.mean > 1.0 || d.within24 < 0.999 || d.eroded > 0) {
        bad.add(nn);
        await tester.runAsync(
          () => writePng('build/sticker-diff/$nn.png', d.map, 512, 512),
        );
      }
    }
    // ignore: avoid_print
    print(lines.join('\n'));
    expect(bad, isEmpty, reason: 'see build/sticker-diff/');
  });

  testWidgets('the animated painter at rest draws the still', (tester) async {
    for (final id in pack.playable) {
      final s = pack.sticker(id)!;
      final still = (await tester.runAsync(() => renderSticker(s)))!;
      final zero = (await tester.runAsync(() => renderSticker(s, t: 0)))!;
      final end = (await tester.runAsync(
        () => renderSticker(s, t: s.loopMs.toDouble()),
      ))!;
      expect(zero, still, reason: 'sticker $id at 0 ms');
      expect(end, still, reason: 'sticker $id at the end of its loop');
    }
  });
}
