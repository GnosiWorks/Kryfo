// SPDX-License-Identifier: GPL-3.0-or-later
// the frame a pq restart's KDB1 goes in, at its largest: the longest id,
// every sender field, the caps and the screenshot word the seal adds. it
// fills to 2767, the seal size of a pq opener and of a long text, so the
// relay sees nothing a restart opener does not show already
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart'
    show ShotsWord, kShotsStampMost, shotsBodyOf, shotsPut;
import 'package:kryfo/main.dart' show phoneRestartBundle, pqRestartFrame;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/typing.dart' show capsPut, kCapsWire;
import 'package:kryfo/wire_pad.dart' show kSealSizes, padSeal, utf8Length;

import 'signal_ls/shim_lib.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the largest rq frame seals at 2767', () async {
    final s = await Phone().openLs();
    final kdb1 = await phoneRestartBundle(s);
    expect(kdb1.length, 1749);
    final words = List.filled(3, 'q' * 16).join('-');
    final frame = await pqRestartFrame(
      SenderInfo(
        haloId: words,
        edPub: 'f' * 64,
        onion: '${'z' * 56}.onion',
        xPub: 'e' * 64,
        avatar: 2147483647,
      ),
      kdb1,
      writtenAt: 9999999999999,
    );
    // as the seal puts them on (shotsOnWire)
    final body = shotsBodyOf(frame)!;
    capsPut(body);
    final sealed = shotsPut(
      body,
      const ShotsWord(on: true, at: kShotsStampMost),
    );
    expect(unwrapMessage(sealed).pqRestart, isNotNull);
    expect(shotsBodyOf(sealed)![kCapsWire], isNotEmpty);
    expect(utf8Length(padSeal(sealed)), kSealSizes[1]);
    expect(kSealSizes[1], 2767);
  }, skip: needsShim);
}
