// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/media_send.dart';
import 'package:kryfo/message_envelope.dart' show powBits, verifyPow;

void main() {
  test('a caption is ground once, every later photo takes the kept nonce',
      () async {
    var ground = 0;
    Future<int> grind(String s) async {
      ground++;
      return 7;
    }

    final seed = 'kept-${DateTime.now().microsecondsSinceEpoch}';
    expect(await mediaPow(seed, grind: grind), 7);
    expect(await mediaPow(seed, grind: grind), 7);
    expect(await mediaPow(seed, grind: grind), 7);
    expect(ground, 1);
    // another caption is its own grind
    expect(await mediaPow('$seed-other', grind: grind), 7);
    expect(ground, 2);
  });

  test('the kept nonce is a real one for its seed', () async {
    final n = await mediaPow('a photo');
    expect(verifyPow('a photo', n, powBits), isTrue);
    expect(await mediaPow('a photo'), n);
  });

  test('the memo stays small', () async {
    var ground = 0;
    Future<int> grind(String s) async => ++ground;
    final base = 'many-${DateTime.now().microsecondsSinceEpoch}';
    for (var i = 0; i < 40; i++) {
      await mediaPow('$base-$i', grind: grind);
    }
    expect(ground, 40);
    // the first went to make room, the last is still kept
    await mediaPow('$base-39', grind: grind);
    expect(ground, 40);
    await mediaPow('$base-0', grind: grind);
    expect(ground, 41);
  });
}
