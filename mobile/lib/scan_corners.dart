// SPDX-License-Identifier: GPL-3.0-or-later
// the scanner's four corners: they breathe on the window while it looks,
// glide onto a kryfo code's own corners, follow it, then lock. all four
// points chase a target on one critically damped spring: the window, the
// smoothed code corners, then the frozen code corners
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

/// the reader's crop, as flutter_zxing's ReaderWidget makes it: a square of
/// [percent] of the short side in the middle of the camera image
({int left, int top, int side}) readerCrop(int w, int h, double percent) {
  final side = (math.min(w, h) * percent).round();
  return (left: (w - side) ~/ 2, top: (h - side) ~/ 2, side: side);
}

/// quarter turns that bring a camera image upright on the screen.
/// [sensor] is the camera's sensor orientation in degrees, [device] how far
/// the phone is turned (0 portrait up, 90 landscape left, ...)
int uprightTurns({
  required int sensor,
  required int device,
  bool front = false,
}) {
  final deg = front ? (sensor + device) % 360 : (sensor - device + 360) % 360;
  return (deg ~/ 90) % 4;
}

/// a code's corners from the reader, clockwise from its top left, in the
/// view the camera fills like BoxFit.cover. [corners] are camera image
/// pixels relative to the crop at ([cropLeft], [cropTop]); [image] is the
/// whole image as the reader got it. [preview] is the aspect the preview is
/// drawn at, in the sensor's frame (null: the image's own). null when the
/// points say nothing (a reader without positions gives all zeros)
List<Offset>? codeCornersInView({
  required List<Offset> corners,
  required Size image,
  required Size view,
  int cropLeft = 0,
  int cropTop = 0,
  int turns = 0,
  bool mirror = false,
  double? preview,
}) {
  if (corners.length != 4 || image.isEmpty || view.isEmpty) return null;
  if (corners.every((p) => p == Offset.zero)) return null;
  // into 0..1 of the image, then turned upright
  final up = <Offset>[];
  for (final p in corners) {
    var u = (p.dx + cropLeft) / image.width;
    var v = (p.dy + cropTop) / image.height;
    for (var i = 0; i < turns % 4; i++) {
      // a quarter turn clockwise: (u, v) -> (1 - v, u)
      final nu = 1 - v;
      v = u;
      u = nu;
    }
    if (mirror) u = 1 - u;
    up.add(Offset(u, v));
  }
  // the upright picture's size, at the preview's aspect
  final aspect = preview ?? image.width / image.height;
  final rw = turns.isOdd ? 1.0 : aspect;
  final rh = turns.isOdd ? aspect : 1.0;
  final s = math.max(view.width / rw, view.height / rh);
  final dx = (view.width - rw * s) / 2;
  final dy = (view.height - rh * s) / 2;
  return [for (final p in up) Offset(dx + p.dx * rw * s, dy + p.dy * rh * s)];
}

/// the four corners of a centred square window, clockwise from top left
List<Offset> windowQuad(Size view, double box, [double scale = 1]) {
  final c = view.center(Offset.zero);
  final h = box / 2 * scale;
  return [
    c + Offset(-h, -h),
    c + Offset(h, -h),
    c + Offset(h, h),
    c + Offset(-h, h),
  ];
}

Offset centroid(List<Offset> q) =>
    q.fold<Offset>(Offset.zero, (a, p) => a + p) / q.length.toDouble();

/// each corner pulled [by] px towards the middle, along its diagonal
List<Offset> insetQuad(List<Offset> q, double by) {
  final c = centroid(q);
  return [
    for (final p in q)
      () {
        final d = p - c;
        final l = d.distance == 0 ? 1.0 : d.distance;
        return p - d / l * by * math.sqrt2;
      }(),
  ];
}

/// one-euro filter: still hands get heavy smoothing, fast moves almost none
class OneEuro {
  final double minCut, beta, dCut;
  double? _x;
  double _dx = 0;
  OneEuro({this.minCut = 1.5, this.beta = 0.02, this.dCut = 1.0});

  static double _a(double cut, double dt) {
    final tau = 1 / (2 * math.pi * cut);
    return 1 / (1 + tau / dt);
  }

  double filter(double x, double dt) {
    final last = _x;
    if (last == null || dt <= 0) return _x = x;
    final d = (x - last) / dt;
    _dx += (d - _dx) * _a(dCut, dt);
    final cut = minCut + beta * _dx.abs();
    return _x = last + (x - last) * _a(cut, dt);
  }
}

enum CornersMode { searching, tracking, locked }

/// the corners' state and motion. the screen feeds it reads and frame
/// times; a CustomPainter repaints from it
class ScanCorners extends ChangeNotifier {
  ScanCorners({this.reduced = false, this.onLock});

  // the approved mockup's numbers
  static const breathePeriod = 2.4;
  static const breatheDepth = 0.0175;
  static const glide = 0.300;
  static const needReads = 3;
  // the mockup's 250 ms at 15 reads a second; phones read slower
  static const grace = 0.35;
  static const lockAfter = 0.700;
  // a code that keeps moving still locks in the end
  static const lockAtMost = 2.0;
  static const lockSpeed = 400.0;
  static const pulse = 0.180;
  static const tick = 0.120;
  static const inset = 3.0;

  /// no breathing and no glide: the corners stay on the window and jump to
  /// the code at the lock with a tick of the stroke
  bool reduced;

  /// the screen's haptic, words and hand-off
  void Function()? onLock;

  Size _view = Size.zero;
  double _box = 0;
  bool failed = false;

  CornersMode mode = CornersMode.searching;
  double t = 0;
  int _reads = 0;
  double _lastRead = -9;
  double _trackT = 0;
  double _since = 0;
  double _lockT = 0;
  double _speed = 0;
  Offset? _prevC;
  List<Offset>? _target;
  List<Offset>? _lockQuad;
  List<OneEuro> _filters = [];
  List<Offset>? _pts;
  List<Offset> _vel = List.filled(4, Offset.zero);

  void layout(Size view, double box) {
    if (view == _view && box == _box) return;
    _view = view;
    _box = box;
    if (mode == CornersMode.searching) _pts = null;
  }

  double get breathe => reduced || failed
      ? 1
      : 1 + breatheDepth * (1 - math.cos(2 * math.pi * t / breathePeriod));

  List<Offset> get window => windowQuad(_view, _box, breathe);

  /// time to keep frames coming: breathing, a glide, a track or a pulse
  bool get moving {
    if (failed) return false;
    switch (mode) {
      case CornersMode.searching:
        return !reduced || _reads > 0;
      case CornersMode.tracking:
        return true;
      case CornersMode.locked:
        return t - _lockT < (reduced ? tick : pulse) || _settling;
    }
  }

  bool get _settling =>
      !reduced && _vel.any((v) => v.distance > 0.5) && _pts != null;

  /// a kryfo code read at [quad] in view pixels. null: a read with no
  /// position, which locks on the window at once
  void read(List<Offset>? quad) {
    if (mode == CornersMode.locked || failed) return;
    if (quad == null) {
      _lockOn(window);
      return;
    }
    final dt = t - _lastRead;
    _reads = dt <= grace ? _reads + 1 : 1;
    _lastRead = t;
    if (mode == CornersMode.searching && _reads >= needReads) {
      mode = CornersMode.tracking;
      _trackT = 0;
      _since = 0;
      _speed = 0;
      _prevC = null;
      _filters = List.generate(8, (_) => OneEuro());
    }
    if (mode == CornersMode.tracking) {
      final step = dt > 0 && dt <= grace ? dt : 1 / 15;
      _target = [
        for (var i = 0; i < 4; i++)
          Offset(
            _filters[i * 2].filter(quad[i].dx, step),
            _filters[i * 2 + 1].filter(quad[i].dy, step),
          ),
      ];
      final c = centroid(_target!);
      final prev = _prevC;
      if (prev != null) _speed += ((c - prev).distance / step - _speed) * 0.5;
      _prevC = c;
    }
    notifyListeners();
  }

  /// a different code came into frame: start counting again
  void restart() {
    if (mode == CornersMode.locked) return;
    mode = CornersMode.searching;
    _reads = 0;
    _target = null;
    notifyListeners();
  }

  void _lockOn(List<Offset> q) {
    mode = CornersMode.locked;
    _lockT = t;
    _lockQuad = q;
    if (reduced) {
      _pts = List.of(q);
      _vel = List.filled(4, Offset.zero);
    }
    notifyListeners();
    onLock?.call();
  }

  /// one frame of [dt] seconds
  void advance(double dt) {
    if (dt <= 0) return;
    t += dt;
    if (mode == CornersMode.tracking) {
      if (t - _lastRead > grace) {
        mode = CornersMode.searching;
        _reads = 0;
        _target = null;
      } else {
        if (_speed < lockSpeed) _trackT += dt;
        _since += dt;
        if (_trackT >= lockAfter || _since >= lockAtMost) {
          _lockOn(insetQuad(_target!, inset));
          return;
        }
      }
    } else if (mode == CornersMode.searching && t - _lastRead > grace) {
      _reads = 0;
    }
    _stepSprings(dt);
    notifyListeners();
  }

  void _stepSprings(double dt) {
    var omega = 6.64 / glide;
    final List<Offset> target;
    if (mode == CornersMode.locked) {
      target = _lockQuad!;
    } else if (mode == CornersMode.tracking && !reduced) {
      target = insetQuad(_target!, inset);
    } else {
      target = window;
      omega *= 0.75;
    }
    final pts = _pts;
    if (pts == null || reduced) {
      if (reduced && mode == CornersMode.locked) return;
      _pts = List.of(target);
      _vel = List.filled(4, Offset.zero);
      return;
    }
    // critically damped: a = w^2 (x* - x) - 2 w v
    final w2 = omega * omega, c2 = 2 * omega;
    var r = dt;
    while (r > 0) {
      final h = math.min(r, 1 / 480);
      for (var i = 0; i < 4; i++) {
        _vel[i] += ((target[i] - pts[i]) * w2 - _vel[i] * c2) * h;
        pts[i] += _vel[i] * h;
      }
      r -= h;
    }
  }

  /// where the corners are drawn now, with the lock pulse
  List<Offset> get shown {
    final pts = _pts ?? window;
    if (mode != CornersMode.locked || reduced) return pts;
    final k = t - _lockT;
    if (k >= pulse) return pts;
    final s = 1 + 0.08 * math.sin(math.pi * k / pulse);
    final c = centroid(pts);
    return [for (final p in pts) c + (p - c) * s];
  }

  /// the stroke, with the reduced-motion lock tick
  double get stroke {
    if (mode != CornersMode.locked || !reduced) return 3;
    final k = t - _lockT;
    return k < tick ? 3 + 1.5 * math.sin(math.pi * k / tick) : 3;
  }

  @visibleForTesting
  int get reads => _reads;
}
