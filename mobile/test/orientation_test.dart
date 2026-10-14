// SPDX-License-Identifier: GPL-3.0-or-later
// the sensor's angle to a side of the phone, with some slack around the
// halfway marks, and each side to the turn that keeps an icon upright on a
// portrait screen, taken the short way round
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/orientation.dart';
import 'package:kryfo/screens/camera_screen.dart' show previewBox;

void main() {
  const up = DeviceOrientation.portraitUp;
  const down = DeviceOrientation.portraitDown;
  const left = DeviceOrientation.landscapeLeft;
  const right = DeviceOrientation.landscapeRight;

  test('a first reading takes the nearest side', () {
    // clockwise from upright: the left side up is the top to the right
    expect(tiltSide(0, null), up);
    expect(tiltSide(10, null), up);
    expect(tiltSide(350, null), up);
    expect(tiltSide(90, null), right);
    expect(tiltSide(100, null), right);
    expect(tiltSide(180, null), down);
    expect(tiltSide(270, null), left);
    expect(tiltSide(300, null), left);
  });

  test('flat keeps the side, or says nothing yet', () {
    expect(tiltSide(-1, null), isNull);
    expect(tiltSide(-1, left), left);
  });

  test('a side is kept until well past the halfway mark', () {
    expect(tiltSide(45 + tiltSlack, up), up);
    expect(tiltSide(46 + tiltSlack, up), right);
    expect(tiltSide(360 - 45 - tiltSlack, up), up);
    expect(tiltSide(359 - 45 - tiltSlack, up), left);
    expect(tiltSide(30, right), right);
    expect(tiltSide(29, right), up);
    expect(tiltSide(210, left), left);
    expect(tiltSide(150, left), down);
  });

  test('each side turns the icons against the phone', () {
    expect(tiltTurns(up), 0);
    // top to the left: the icons turn a quarter clockwise
    expect(tiltTurns(left), 0.25);
    expect(tiltTurns(right), -0.25);
    expect(tiltTurns(down).abs(), 0.5);
  });

  test('a turn always takes the short way', () {
    expect(nearestTurns(0, tiltTurns(left)), 0.25);
    expect(nearestTurns(0, tiltTurns(right)), -0.25);
    expect(nearestTurns(0.25, tiltTurns(down)), 0.5);
    expect(nearestTurns(-0.25, tiltTurns(down)), -0.5);
    // on round from upside down, never back through upright
    expect(nearestTurns(0.5, tiltTurns(right)), 0.75);
    expect(nearestTurns(-0.5, tiltTurns(left)), -0.75);
    // many turns in, still the nearest
    expect(nearestTurns(3.25, tiltTurns(up)), 3);
    expect(nearestTurns(-2.75, tiltTurns(up)), -3);
    for (var from = -3.0; from <= 3; from += 0.25) {
      for (final o in DeviceOrientation.values) {
        final to = nearestTurns(from, tiltTurns(o));
        expect((to - from).abs(), lessThanOrEqualTo(0.5));
        expect(((to - tiltTurns(o)) % 1).abs(), 0);
      }
    }
  });

  test('the stream says each new side once, after a reading', () async {
    final seen = await tilts(
      Stream.fromIterable([-1, 5, 20, 300, 290, 250, -1, 120, 180]),
    ).toList();
    expect(seen, [up, left, right, down]);
  });

  test('the preview box has the frame\'s shape, as the screen stands', () {
    const frame = Size(1280, 720);
    expect(previewBox(frame, up), const Size(720, 1280));
    expect(previewBox(frame, down), const Size(720, 1280));
    expect(previewBox(frame, left), const Size(1280, 720));
    expect(previewBox(frame, right), const Size(1280, 720));
    // a frame reported upright comes out the same
    expect(previewBox(const Size(720, 1280), up), const Size(720, 1280));
  });
}
