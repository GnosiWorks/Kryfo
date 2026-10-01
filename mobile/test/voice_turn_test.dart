// SPDX-License-Identifier: GPL-3.0-or-later
// one voice note plays at a time: starting one stops the one that was
// playing, which carries on from where it was on its next tap
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/voice_parts.dart';

import 'source_body.dart';

void main() {
  final a = Object();
  final b = Object();
  tearDown(() {
    VoiceTurn.letGo(a);
    VoiceTurn.letGo(b);
  });

  test('a second note stops the first', () {
    var aStopped = 0;
    var bStopped = 0;
    VoiceTurn.take(a, () => aStopped++);
    VoiceTurn.take(b, () => bStopped++);
    expect(aStopped, 1);
    expect(bStopped, 0);
    expect(VoiceTurn.playing, same(b));
  });

  test('the same note again stops nothing', () {
    var stopped = 0;
    VoiceTurn.take(a, () => stopped++);
    VoiceTurn.take(a, () => stopped++);
    expect(stopped, 0);
  });

  test('a note that ended is not stopped again', () {
    var stopped = 0;
    VoiceTurn.take(a, () => stopped++);
    VoiceTurn.letGo(a);
    VoiceTurn.take(b, () {});
    expect(stopped, 0);
    // and one that is not playing cannot let go of another's turn
    VoiceTurn.letGo(a);
    expect(VoiceTurn.playing, same(b));
  });

  test('the bubble takes the turn to play and gives it back', () {
    final src = sourceOf('lib/widgets/media_bubbles.dart');
    final toggle = bodyOf(src, 'void _toggle(');
    final take = toggle.indexOf('VoiceTurn.take(this, _pause)');
    expect(take, greaterThan(0));
    expect(toggle.indexOf('_player.play()'), greaterThan(take));
    expect(
      'VoiceTurn.letGo(this)'.allMatches(src).length,
      // paused, finished, stopped by the lock, gone
      4,
    );
  });
}
