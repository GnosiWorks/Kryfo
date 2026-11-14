// SPDX-License-Identifier: GPL-3.0-or-later
// the scanner's corners: the reader's points land on the code as the
// preview shows it, the corners breathe, glide, follow and lock, and with
// reduced motion they only tick at the lock.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/scan_corners.dart';

void near(List<Offset> got, List<Offset> want, [double by = 0.01]) {
  expect(got, hasLength(want.length));
  for (var i = 0; i < want.length; i++) {
    expect((got[i] - want[i]).distance, lessThan(by), reason: 'corner $i');
  }
}

const view = Size(360, 780);
const box = 252.0;

// a square code of side [side] around [c], turned by quarter turns of its
// own corners only: what a reader hands for a code held straight
List<Offset> square(Offset c, double side) => [
  c + Offset(-side / 2, -side / 2),
  c + Offset(side / 2, -side / 2),
  c + Offset(side / 2, side / 2),
  c + Offset(-side / 2, side / 2),
];

void main() {
  group('points to the screen', () {
    test('the crop is the reader\'s', () {
      // ReaderWidget: side = round(min * pct), centred
      final c = readerCrop(1280, 720, 0.9);
      expect(c.side, 648);
      expect(c.left, (1280 - 648) ~/ 2);
      expect(c.top, (720 - 648) ~/ 2);
    });

    test('an upright image fills the view like cover', () {
      // 720 x 1560 has the view's own shape: scale 0.5, nothing cut off
      final got = codeCornersInView(
        corners: square(const Offset(360, 780), 200),
        image: const Size(720, 1560),
        view: view,
      )!;
      near(got, square(const Offset(180, 390), 100));
    });

    test('crop offset is added before the fit', () {
      final crop = readerCrop(720, 1560, 0.9);
      final got = codeCornersInView(
        corners: square(Offset(360.0 - crop.left, 780.0 - crop.top), 200),
        image: const Size(720, 1560),
        view: view,
        cropLeft: crop.left,
        cropTop: crop.top,
      )!;
      near(got, square(const Offset(180, 390), 100));
    });

    test('a sensor image turned a quarter lands upright', () {
      // the sensor's landscape 1600 x 720: its top left is the screen's
      // top right once turned clockwise
      final got = codeCornersInView(
        corners: const [
          Offset(0, 0),
          Offset(1600, 0),
          Offset(1600, 720),
          Offset(0, 720),
        ],
        image: const Size(1600, 720),
        view: view,
        turns: 1,
      )!;
      // upright 720 x 1600 covers 360 x 780: scale max(0.5, 0.4875) = 0.5,
      // 800 tall, 10 cut off at top and bottom
      near(got, const [
        Offset(360, -10),
        Offset(360, 790),
        Offset(0, 790),
        Offset(0, -10),
      ]);
    });

    test('tilt and size survive the trip', () {
      // a code turned 30 degrees: its edges keep their angle on screen
      final c = const Offset(400, 900);
      final pts = [
        for (final a in [0.0, 1.0, 2.0, 3.0])
          c + Offset.fromDirection(0.5236 + a * 1.5708 - 2.356, 141.4),
      ];
      final got = codeCornersInView(
        corners: pts,
        image: const Size(720, 1560),
        view: view,
      )!;
      final e0 = pts[1] - pts[0], g0 = got[1] - got[0];
      expect(g0.direction, closeTo(e0.direction, 1e-6));
      expect(g0.distance, closeTo(e0.distance * 0.5, 1e-6));
    });

    test('a read without a position says nothing', () {
      expect(
        codeCornersInView(
          corners: List.filled(4, Offset.zero),
          image: const Size(720, 1560),
          view: view,
        ),
        isNull,
      );
    });

    test('quarter turns for the back and the front camera', () {
      expect(uprightTurns(sensor: 90, device: 0), 1);
      expect(uprightTurns(sensor: 270, device: 0), 3);
      expect(uprightTurns(sensor: 270, device: 0, front: true), 3);
      expect(uprightTurns(sensor: 0, device: 0), 0);
    });
  });

  group('motion', () {
    ScanCorners made({bool reduced = false, void Function()? onLock}) =>
        ScanCorners(reduced: reduced, onLock: onLock)..layout(view, box);

    void run(ScanCorners c, double seconds, {List<Offset>? feed}) {
      // 60 frames a second, a read every 4th frame (15 a second)
      final frames = (seconds * 60).round();
      for (var i = 0; i < frames; i++) {
        if (feed != null && i % 4 == 0) c.read(feed);
        c.advance(1 / 60);
      }
    }

    test('searching: the window breathes around the centre', () {
      final c = made();
      run(c, 1.2);
      // half way through the loop: at its widest, 1.035
      final w = c.shown;
      expect((w[1] - w[0]).distance, greaterThan(box * 1.02));
      run(c, 1.2);
      near(c.shown, windowQuad(view, box), 0.5);
    });

    test('found: the corners glide onto the code, then lock once', () {
      var locks = 0;
      final c = made(onLock: () => locks++);
      final code = square(const Offset(250, 560), 120);
      run(c, 0.25, feed: code);
      expect(c.mode, CornersMode.tracking);
      run(c, 0.35, feed: code);
      // 300 ms glide: on the code, 3 px in
      near(c.shown, insetQuad(code, ScanCorners.inset), 2);
      run(c, 0.4, feed: code);
      expect(c.mode, CornersMode.locked);
      expect(locks, 1);
      run(c, 0.5, feed: code);
      expect(locks, 1);
    });

    test('lost: the corners go back to the window', () {
      final c = made();
      run(c, 0.4, feed: square(const Offset(250, 560), 120));
      expect(c.mode, CornersMode.tracking);
      run(c, 1.2);
      expect(c.mode, CornersMode.searching);
      expect(c.reads, 0);
    });

    test('the lock pulses out and back in 180 ms', () {
      final c = made();
      final code = square(const Offset(180, 390), 160);
      for (var i = 0; i < 120 && c.mode != CornersMode.locked; i++) {
        if (i % 4 == 0) c.read(code);
        c.advance(1 / 60);
      }
      expect(c.mode, CornersMode.locked);
      expect(c.moving, isTrue);
      c.advance(0.09);
      // half way: 8% out of the 154 px the inset leaves
      final s = c.shown;
      expect((s[1] - s[0]).distance, greaterThan(154 * 1.07));
      run(c, 0.6);
      expect(c.moving, isFalse);
    });

    test('reduced motion: no breathing, no glide, a tick at the lock', () {
      final c = made(reduced: true);
      expect(c.moving, isFalse);
      run(c, 1.2);
      near(c.shown, windowQuad(view, box));
      final code = square(const Offset(250, 560), 120);
      run(c, 0.5, feed: code);
      // the code is followed, but the corners stay on the window
      expect(c.mode, CornersMode.tracking);
      near(c.shown, windowQuad(view, box));
      expect(c.stroke, 3);
      for (var i = 0; i < 120 && c.mode != CornersMode.locked; i++) {
        if (i % 4 == 0) c.read(code);
        c.advance(1 / 60);
      }
      expect(c.mode, CornersMode.locked);
      // straight onto the code at the lock
      near(c.shown, insetQuad(code, ScanCorners.inset), 3);
      // the stroke ticks up and back down, nothing scales
      c.advance(0.06);
      expect(c.stroke, greaterThan(4));
      c.advance(0.1);
      expect(c.stroke, 3);
      expect(c.moving, isFalse);
    });

    test('a read with no position locks on the window at once', () {
      var locks = 0;
      final c = made(onLock: () => locks++);
      c.read(null);
      expect(c.mode, CornersMode.locked);
      expect(locks, 1);
      near(c.shown, windowQuad(view, box));
    });
  });
}
