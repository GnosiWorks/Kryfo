// SPDX-License-Identifier: GPL-3.0-or-later
// a sticker's tracks at a point in its loop, and its display list painted.
// the maths is tool/pack_stickers.py's, which lints the tracks with it: keep
// the two the same.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'sticker_pack.dart';

// the curve into a key
const easeLinear = 0,
    easeHold = 1,
    easeSine = 2,
    easeOut = 3,
    easeIn = 4,
    easeBack = 5,
    easeInOut = 6,
    easeSineOut = 7,
    easeSineIn = 8;

double stickerEase(int code, double u) {
  if (u <= 0) return 0;
  if (u >= 1) return 1;
  switch (code) {
    case easeLinear:
      return u;
    case easeHold:
      return 0;
    case easeSine:
      return -(math.cos(math.pi * u) - 1) / 2;
    case easeOut:
      final v = 1 - u;
      return 1 - v * v * v;
    case easeIn:
      return u * u * u;
    case easeBack:
      const c1 = 1.70158;
      final v = u - 1;
      return 1 + (c1 + 1) * v * v * v + c1 * v * v;
    case easeInOut:
      if (u < 0.5) return 4 * u * u * u;
      final v = -2 * u + 2;
      return 1 - v * v * v / 2;
    case easeSineOut:
      return math.sin(u * math.pi / 2);
    case easeSineIn:
      return 1 - math.cos(u * math.pi / 2);
  }
  return u;
}

/// one track's value at t ms
double trackValue(StickerTrack k, double t) {
  final ts = k.times;
  final vs = k.values;
  final n = ts.length;
  if (t <= ts[0]) return vs[0];
  for (var i = 0; i < n - 1; i++) {
    final t0 = ts[i];
    final t1 = ts[i + 1];
    if (t >= t0 && t < t1) {
      if (t == t0) return vs[i];
      final e = stickerEase(k.eases[i + 1], (t - t0) / (t1 - t0));
      return vs[i] + (vs[i + 1] - vs[i]) * e;
    }
  }
  return vs[n - 1];
}

/// where in its loop a view is. a view waits [delayMs] at rest first:
/// every loop starts at rest, so copies fall out of step with no jump
double loopTime(Sticker s, double elapsedMs, int delayMs) {
  if (s.loopMs <= 0) return 0;
  final t = elapsedMs - delayMs;
  if (t <= 0) return 0;
  return t % s.loopMs;
}

/// every node's x y rot sx sy alpha at t ms, six values a node
Float64List evaluateSticker(Sticker s, double t, [Float64List? out]) {
  final v = out ?? Float64List(s.nodeCount * 6);
  for (var i = 0; i < s.nodeCount; i++) {
    final o = i * 6;
    v[o] = 0;
    v[o + 1] = 0;
    v[o + 2] = 0;
    v[o + 3] = 1;
    v[o + 4] = 1;
    v[o + 5] = 1;
  }
  for (final k in s.tracks) {
    v[k.node * 6 + k.prop] = trackValue(k, t);
  }
  return v;
}

/// a node's transform at rest: nothing to walk. alpha is left out, as a
/// part the svg hides rests at 0
bool nodeAtRest(Float64List v, int n) {
  final o = n * 6;
  return v[o] == 0 &&
      v[o + 1] == 0 &&
      v[o + 2] == 0 &&
      v[o + 3] == 1 &&
      v[o + 4] == 1;
}

/// a node's transform in sticker space, (a b c d e f) into out:
/// T(pivot) R(frame) T(k dx, k dy) R(rot) S(sx, sy) R(-frame) T(-pivot)
void nodeMatrix(Sticker s, Float64List v, int n, Float64List out) {
  final o = n * 6;
  final fc = s.frameCos[n], fs = s.frameSin[n], k = s.frameScale[n];
  final r = v[o + 2] * math.pi / 180;
  final cr = math.cos(r), sr = math.sin(r);
  final sx = v[o + 3], sy = v[o + 4];
  // rot and scale: (a b c d), columns (a, b) and (c, d)
  final a0 = cr * sx, b0 = sr * sx, c0 = -sr * sy, d0 = cr * sy;
  // times R(-frame): columns (fc, -fs), (fs, fc)
  final a1 = a0 * fc - c0 * fs, b1 = b0 * fc - d0 * fs;
  final c1 = a0 * fs + c0 * fc, d1 = b0 * fs + d0 * fc;
  // R(frame) times that: R(frame) is columns (fc, fs), (-fs, fc)
  final a = fc * a1 - fs * b1, b = fs * a1 + fc * b1;
  final c = fc * c1 - fs * d1, d = fs * c1 + fc * d1;
  final px = s.pivotX[n], py = s.pivotY[n];
  final mx = k * v[o], my = k * v[o + 1];
  out[0] = a;
  out[1] = b;
  out[2] = c;
  out[3] = d;
  out[4] = px + fc * mx - fs * my - (a * px + c * py);
  out[5] = py + fs * mx + fc * my - (b * px + d * py);
}

final _affine = Float64List(6);
final _m4 = Float64List(16)
  ..[10] = 1
  ..[15] = 1;
final _layer = ui.Paint();
var _restores = Int32List(32);
var _alphas = Float64List(32);

/// paints the display list in sticker units (0..512). v null: the still
/// frame, every node at rest and nothing hidden drawn.
void paintSticker(ui.Canvas c, Sticker s, Float64List? v) {
  final ops = s.ops;
  if (_restores.length <= s.depth) {
    _restores = Int32List(s.depth + 1);
    _alphas = Float64List(s.depth + 1);
  }
  var sp = 0;
  var alpha = 1.0;
  for (var i = 0; i < ops.length; i++) {
    final w = ops[i];
    final arg = w & 0x1FFF;
    switch (w >> 13) {
      case opSave:
        c.save();
        _restores[sp] = 1;
        _alphas[sp++] = alpha;
      case opLayer:
        _layer.color = ui.Color.fromARGB(arg & 0xFF, 0, 0, 0);
        c.saveLayer(null, _layer);
        _restores[sp] = 1;
        _alphas[sp++] = alpha;
      case opPush:
        final n = arg & 0xFFF;
        final rest = v == null || nodeAtRest(v, n);
        final a = v == null ? s.restAlpha[n] : v[n * 6 + 5];
        if ((rest && s.hiddenAtRest(n)) || a <= 0) {
          i = s.jump[i];
          continue;
        }
        c.save();
        var count = 1;
        if (!rest) {
          nodeMatrix(s, v, n, _affine);
          _m4[0] = _affine[0];
          _m4[1] = _affine[1];
          _m4[4] = _affine[2];
          _m4[5] = _affine[3];
          _m4[12] = _affine[4];
          _m4[13] = _affine[5];
          c.transform(_m4);
        }
        _alphas[sp] = alpha;
        if (a < 1) {
          if (arg & pushLayer != 0) {
            // parts that overlap fade as one, like svg's group opacity
            _layer.color = ui.Color.fromARGB((a * 255).round(), 0, 0, 0);
            c.saveLayer(null, _layer);
            count = 2;
          } else {
            alpha *= a;
          }
        }
        _restores[sp++] = count;
      case opPop:
        sp--;
        for (var r = _restores[sp]; r > 0; r--) {
          c.restore();
        }
        alpha = _alphas[sp];
      case opClip:
        c.clipPath(s.paths[arg]);
      case opDraw:
        final pi = ops[++i];
        final p = s.paints[pi];
        if (alpha < 1) {
          final base = s.paintAlpha[pi];
          p.color = p.color.withAlpha((base * alpha).round());
          c.drawPath(s.paths[arg], p);
          p.color = p.color.withAlpha(base);
        } else {
          c.drawPath(s.paths[arg], p);
        }
    }
  }
}
