// SPDX-License-Identifier: GPL-3.0-or-later
// the player's maths: easing, keys, the loop and a node's transform.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_player.dart';

import 'sticker_test_util.dart';

StickerTrack _track(List<(double, double, int)> keys, {int prop = propRot}) =>
    StickerTrack(
      0,
      prop,
      Float64List.fromList([for (final k in keys) k.$1]),
      Float64List.fromList([for (final k in keys) k.$2]),
      Uint8List.fromList([for (final k in keys) k.$3]),
    );

(double, double) _apply(Float64List m, double x, double y) =>
    (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]);

void main() {
  final pack = loadPack();

  test('every ease starts at 0 and ends at 1', () {
    for (var e = easeLinear; e <= easeSineIn; e++) {
      expect(stickerEase(e, 0), 0, reason: 'ease $e');
      expect(stickerEase(e, 1), 1, reason: 'ease $e');
    }
    // hold keeps the old value until the key
    expect(stickerEase(easeHold, 0.999), 0);
    // back overshoots, the rest stay inside
    expect(stickerEase(easeBack, 0.7), greaterThan(1));
    expect(stickerEase(easeSine, 0.5), closeTo(0.5, 1e-12));
    expect(stickerEase(easeInOut, 0.5), closeTo(0.5, 1e-12));
  });

  test('a track is exactly its value at each key', () {
    final k = _track([
      (0, 0, easeLinear),
      (240, 7, easeSine),
      (520, -5, easeBack),
      (800, -5, easeSine),
      (1000, 0, easeHold),
    ]);
    expect(trackValue(k, 0), 0);
    expect(trackValue(k, 240), 7);
    expect(trackValue(k, 520), -5);
    expect(trackValue(k, 800), -5);
    expect(trackValue(k, 1000), 0);
    // between two equal keys it stays put
    expect(trackValue(k, 650), -5);
    // a hold jumps at its key, not before
    expect(trackValue(k, 999), -5);
    // after the last key: the last value
    expect(trackValue(k, 1800), 0);
    // sine is halfway at half time
    expect(trackValue(k, 120), closeTo(3.5, 1e-9));
  });

  test('the loop closes on itself, and a delay starts it at rest', () {
    for (final id in pack.playable) {
      final s = pack.sticker(id)!;
      final a = evaluateSticker(s, 0);
      final b = evaluateSticker(s, s.loopMs.toDouble());
      expect(b, a, reason: 'sticker $id');
      expect(loopTime(s, s.loopMs.toDouble(), 0), 0);
      expect(loopTime(s, 100, 0), 100);
      expect(loopTime(s, s.loopMs + 100.0, 0), closeTo(100, 1e-9));
      // waiting: at rest, then the loop from its start
      expect(loopTime(s, 300, 500), 0);
      expect(loopTime(s, 600, 500), closeTo(100, 1e-9));
      expect(loopTime(s, 500.0 + s.loopMs * 3 + 40, 500), closeTo(40, 1e-9));
    }
  });

  test('every node is at rest at 0 ms', () {
    for (final id in pack.playable) {
      final s = pack.sticker(id)!;
      final v = evaluateSticker(s, 0);
      for (var n = 0; n < s.nodeCount; n++) {
        expect(nodeAtRest(v, n), true, reason: 'sticker $id node $n');
      }
      // and something moves during the loop
      var moved = false;
      for (var t = 0.0; t < s.loopMs && !moved; t += 50) {
        final w = evaluateSticker(s, t);
        for (var n = 0; n < s.nodeCount; n++) {
          if (!nodeAtRest(w, n)) moved = true;
        }
      }
      expect(moved, true, reason: 'sticker $id');
    }
  });

  test('a node turns and scales about its pivot', () {
    final s = pack.sticker(1)!;
    final m = Float64List(6);
    for (var n = 0; n < s.nodeCount; n++) {
      final v = evaluateSticker(s, 0);
      v[n * 6 + propRot] = 9;
      v[n * 6 + propSx] = 1.2;
      v[n * 6 + propSy] = 0.8;
      nodeMatrix(s, v, n, m);
      final (x, y) = _apply(m, s.pivotX[n], s.pivotY[n]);
      expect(x, closeTo(s.pivotX[n], 1e-9));
      expect(y, closeTo(s.pivotY[n], 1e-9));
    }
  });

  test('a move runs along the art\'s own axes inside a turned group', () {
    // lol: the laughing seal sits in a group turned -58 degrees
    final s = pack.sticker(2)!;
    final m = Float64List(6);
    var found = false;
    for (var n = 0; n < s.nodeCount; n++) {
      final angle = math.atan2(s.frameSin[n], s.frameCos[n]) * 180 / math.pi;
      if ((angle + 58).abs() > 0.01) continue;
      found = true;
      final v = evaluateSticker(s, 0);
      v[n * 6 + propX] = 10;
      nodeMatrix(s, v, n, m);
      final (x, y) = _apply(m, s.pivotX[n], s.pivotY[n]);
      final k = s.frameScale[n];
      final a = -58 * math.pi / 180;
      expect(x - s.pivotX[n], closeTo(10 * k * math.cos(a), 1e-9));
      expect(y - s.pivotY[n], closeTo(10 * k * math.sin(a), 1e-9));
      // a squash along its own length leaves the pivot where it was
      v[n * 6 + propX] = 0;
      v[n * 6 + propSy] = 0.97;
      nodeMatrix(s, v, n, m);
      final (px, py) = _apply(m, s.pivotX[n], s.pivotY[n]);
      expect(px, closeTo(s.pivotX[n], 1e-9));
      expect(py, closeTo(s.pivotY[n], 1e-9));
    }
    expect(found, true);
  });

  test('the still frame walks no transform', () {
    for (final id in pack.ids) {
      final s = pack.sticker(id)!;
      final m = Float64List(6);
      final v = evaluateSticker(s, 0);
      for (var n = 0; n < s.nodeCount; n++) {
        nodeMatrix(s, v, n, m);
        expect(m, [1, 0, 0, 1, 0, 0].map((e) => closeTo(e, 1e-12)).toList());
      }
    }
  });
}
