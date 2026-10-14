// SPDX-License-Identifier: GPL-3.0-or-later
// the app stays portrait. the camera reads which way up the phone is held
// from the accelerometer instead, to turn its icons and its captures
import 'package:flutter/services.dart';

const appOrientations = [DeviceOrientation.portraitUp];

const _tilt = EventChannel('kryfo/tilt');

// degrees past the halfway mark before a new side is taken, so a phone held
// near 45 degrees does not flip back and forth
const tiltSlack = 15;

// where each side sits on the sensor's clock: clockwise from upright, as
// android's orientation listener counts
int _centre(DeviceOrientation o) => switch (o) {
  DeviceOrientation.portraitUp => 0,
  DeviceOrientation.landscapeRight => 90,
  DeviceOrientation.portraitDown => 180,
  DeviceOrientation.landscapeLeft => 270,
};

int _apart(int a, int b) {
  final d = (a - b) % 360;
  return d > 180 ? 360 - d : d;
}

// the side [angle] reads as, given the side it was on. -1 is flat, which
// keeps whatever was there
DeviceOrientation? tiltSide(int angle, DeviceOrientation? now) {
  if (angle < 0) return now;
  if (now != null && _apart(angle, _centre(now)) <= 45 + tiltSlack) {
    return now;
  }
  DeviceOrientation? best;
  for (final o in DeviceOrientation.values) {
    if (best == null ||
        _apart(angle, _centre(o)) < _apart(angle, _centre(best))) {
      best = o;
    }
  }
  return best;
}

// turns, clockwise, that keep an icon upright on a portrait screen
double tiltTurns(DeviceOrientation o) => switch (o) {
  DeviceOrientation.portraitUp => 0,
  DeviceOrientation.landscapeLeft => 0.25,
  DeviceOrientation.portraitDown => 0.5,
  DeviceOrientation.landscapeRight => -0.25,
};

// [target] plus whole turns, the one closest to [from]: an icon never spins
// the long way round
double nearestTurns(double from, double target) =>
    target + (from - target).round();

// the side the phone is held on, each time it changes. nothing until the
// sensor has a reading
Stream<DeviceOrientation> tilts([Stream<int>? angles]) {
  DeviceOrientation? side;
  return (angles ?? _tilt.receiveBroadcastStream().cast<int>())
      .map((a) => side = tiltSide(a, side))
      .where((o) => o != null)
      .cast<DeviceOrientation>()
      .distinct();
}
