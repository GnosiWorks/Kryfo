// SPDX-License-Identifier: GPL-3.0-or-later
// android's words on the capture channel: a screenshot and the start of a
// recording reach the newest screen that listens, the end of a recording
// and anything else reach none, and a screen that let go hears nothing
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/capture_watch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the words map to what was seen, and the rest is nothing', () {
    final heard = <Capture>[];
    final off = captureWatch.watch(heard.add);
    addTearDown(off);
    for (final m in ['shot', 'rec:1', 'rec:0', 'shot!', '', null]) {
      captureWatch.take(m);
    }
    expect(heard, [Capture.shot, Capture.recording]);
  });

  test('the newest screen hears it, and one that let go does not', () {
    final under = <Capture>[];
    final top = <Capture>[];
    final offUnder = captureWatch.watch(under.add);
    addTearDown(offUnder);
    final offTop = captureWatch.watch(top.add);
    captureWatch.take('shot');
    expect(top, [Capture.shot]);
    expect(under, isEmpty);
    offTop();
    captureWatch.take('shot');
    expect(under, [Capture.shot]);
    expect(top, [Capture.shot]);
  });

  test('nobody listening: nothing happens', () {
    expect(() => captureWatch.take('shot'), returnsNormally);
  });

  test('a word from android on the channel lands the same way', () async {
    final heard = <Capture>[];
    final off = captureWatch.watch(heard.add);
    addTearDown(off);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'kryfo/capture',
          const StringCodec().encodeMessage('rec:1'),
          (_) {},
        );
    expect(heard, [Capture.recording]);
  });
}
