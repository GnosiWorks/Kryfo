// SPDX-License-Identifier: GPL-3.0-or-later
// a forward carries words only, so a photo, a file, a voice note or a
// sticker offers none. it opens the other chat with what was already
// written there kept, the forward under it
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/forward.dart';

void main() {
  group('what can be forwarded', () {
    test('words', () {
      expect(canForward(text: 'see you at 6'), isTrue);
    });

    test('a photo, with a caption or without', () {
      expect(canForward(text: '', mediaPath: '/m/p.jpg'), isFalse);
      expect(canForward(text: 'look', mediaPath: '/m/p.jpg'), isFalse);
    });

    test('a file or a voice note', () {
      expect(canForward(text: '', filePath: '/m/vn.wav'), isFalse);
      expect(canForward(text: '', filePath: '/m/notes.txt'), isFalse);
    });

    test('a sticker, or nothing at all', () {
      expect(canForward(text: '😂', sticker: true), isFalse);
      expect(canForward(text: ''), isFalse);
    });
  });

  group('the composer it opens on', () {
    test('an empty one takes the forward', () {
      expect(composerWith('', 'see you at 6'), 'see you at 6');
      expect(composerWith('  ', 'see you at 6'), 'see you at 6');
    });

    test('a draft stays, the forward under it', () {
      expect(
        composerWith('half a thought', 'see you at 6'),
        'half a thought\nsee you at 6',
      );
    });

    test('no forward, or one already there, leaves the draft as it is', () {
      expect(composerWith('half a thought', null), 'half a thought');
      expect(composerWith('half a thought', ''), 'half a thought');
      expect(
        composerWith('half a thought\nsee you at 6', 'see you at 6'),
        'half a thought\nsee you at 6',
      );
      expect(composerWith('ok', 'ok'), 'ok');
    });

    test('a draft whose words hold the forward still gets it', () {
      expect(composerWith('ok then', 'ok'), 'ok then\nok');
      expect(composerWith('at 6pm', '6'), 'at 6pm\n6');
      expect(
        composerWith('see you at 6 sharp', 'see you at 6'),
        'see you at 6 sharp\nsee you at 6',
      );
      expect(composerWith('the 6\nat 6', '6'), 'the 6\nat 6\n6');
    });
  });
}
