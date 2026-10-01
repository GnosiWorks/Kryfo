// SPDX-License-Identifier: GPL-3.0-or-later
// a text sealed while there was no route waits for one, and goes only if
// its message is still there: one taken back meanwhile never leaves
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/text_send.dart';

void main() {
  const step = Duration(milliseconds: 1);

  test('taken back while it waited, it never leaves', () async {
    var up = false;
    var kept = true;
    final sent = <String>[];
    final out = wireWhenReady(
      ready: () => up,
      kept: () async => kept,
      send: () async {
        sent.add('cipher');
        return 'ok';
      },
      step: step,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    kept = false;
    up = true;
    expect(await out, kTextTakenBack);
    expect(sent, isEmpty);
  });

  test('still there once a route is up, it goes', () async {
    var up = false;
    final out = wireWhenReady(
      ready: () => up,
      kept: () async => true,
      send: () async => 'ok',
      step: step,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    up = true;
    expect(await out, 'ok');
  });

  test('no route in time says so and sends nothing', () async {
    var asked = false;
    final out = await wireWhenReady(
      ready: () => false,
      kept: () async {
        asked = true;
        return true;
      },
      send: () async => 'ok',
      step: step,
      patience: const Duration(milliseconds: 5),
    );
    expect(out, startsWith('error'));
    expect(asked, isFalse);
  });
}
