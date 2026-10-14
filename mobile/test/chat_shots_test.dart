// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's screenshot block on the wire: one 'ss' key on every 1:1
// envelope, its state and the stamp it was set at. the newer stamp wins and
// a tie keeps the block on. a phone that never sent the key does not know
// the block, and one whose newest message lacks it no longer does. 0.5.0
// and 0.5.1 read a stamped envelope as they read it without the key, and
// the frame that carries only the block as a word with nothing in it
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/message_envelope.dart';

import 'old_wire/envelope_050.dart' as v050;
import 'old_wire/envelope_051.dart' as v051;

const _me = SenderInfo(haloId: 'amy', edPub: 'ed', onion: 'o', xPub: 'x');

void main() {
  group('the word', () {
    test('reads what it wrote and nothing it did not', () {
      const w = ShotsWord(on: true, at: 1700000000000);
      final back = ShotsWord.fromWire(w.toWire())!;
      expect((back.on, back.at), (true, 1700000000000));
      for (final bad in <Object?>[
        null,
        'on',
        {'o': 2, 'a': 1},
        {'o': 1},
        {'o': 1, 'a': -1},
        {'o': 1, 'a': 1.5},
        {'o': 'on', 'a': 1},
        {'o': 1, 'a': 1 << 53},
      ]) {
        expect(ShotsWord.fromWire(bad), isNull, reason: '$bad');
      }
    });

    test('the newer stamp wins, a tie keeps the block on', () {
      bool wins(bool on, int at, {required bool was, required int wasAt}) =>
          shotsWins(
            ShotsWord(on: on, at: at),
            on: was,
            at: wasAt,
          );
      expect(wins(true, 5, was: false, wasAt: 4), isTrue);
      expect(wins(false, 5, was: true, wasAt: 4), isTrue);
      expect(wins(false, 3, was: true, wasAt: 4), isFalse);
      expect(wins(true, 4, was: false, wasAt: 4), isTrue);
      expect(wins(false, 4, was: true, wasAt: 4), isFalse);
      expect(wins(true, 4, was: true, wasAt: 4), isFalse);
      // a phone that never changed it says so with no stamp
      expect(wins(true, 0, was: false, wasAt: 0), isFalse);
    });

    test('a change goes past every stamp seen, whatever the clock', () {
      expect(shotsNextStamp(10, 500), 500);
      expect(shotsNextStamp(900, 500), 901);
    });
  });

  group('whether their phone knows the block', () {
    test('a key from them says it does, a message without it that it '
        'no longer does', () {
      expect(shotsCanAfter(0, carried: true, counts: false, written: 50), 50);
      expect(shotsCanAfter(50, carried: false, counts: true, written: 60), -60);
      expect(shotsCanAfter(-60, carried: true, counts: true, written: 70), 70);
    });

    test('a copy written before the newest changes nothing', () {
      expect(
        shotsCanAfter(70, carried: false, counts: true, written: 40),
        null,
      );
      expect(
        shotsCanAfter(-70, carried: true, counts: true, written: 40),
        null,
      );
    });

    test('a receipt or a frame without the key says nothing', () {
      expect(
        shotsCanAfter(70, carried: false, counts: false, written: 90),
        null,
      );
    });

    test('an envelope with no time from a phone that knows it still '
        'counts once', () {
      expect(shotsCanAfter(0, carried: true, counts: true), 1);
      expect(shotsCanAfter(80, carried: true, counts: true), null);
      expect(shotsCanAfter(80, carried: false, counts: true), null);
    });
  });

  group('the stamp', () {
    test('a 1:1 envelope carries it, and reads back', () async {
      final w = await wrapMessage('hi', msgUid: 'u1', sender: _me);
      final out = shotsStamped(w, const ShotsWord(on: true, at: 42));
      final env = unwrapMessage(out);
      expect(env.message, 'hi');
      expect(env.msgUid, 'u1');
      expect((env.shots!.on, env.shots!.at), (true, 42));
      // stamped again as the state is now, never twice
      final again = shotsStamped(out, const ShotsWord(on: false, at: 43));
      expect(RegExp('"ss"').allMatches(again), hasLength(1));
      expect(unwrapMessage(again).shots!.on, isFalse);
    });

    test('a group\'s frame and plain text go as they are', () async {
      final g = await wrapMessage('hi', groupId: 'g1', sender: _me);
      expect(shotsStamped(g, const ShotsWord(on: true, at: 1)), g);
      expect(shotsStamped('plain', const ShotsWord(on: true, at: 1)), 'plain');
      expect(
        shotsStamped('halo/1:{bad', const ShotsWord(on: true, at: 1)),
        'halo/1:{bad',
      );
    });

    test('an envelope without it has none', () async {
      final w = await wrapMessage('hi', sender: _me);
      expect(unwrapMessage(w).shots, isNull);
    });
  });

  group('an older phone', () {
    // what each version's receive path reads off an envelope
    Map<String, Object?> v050Reads(String w) {
      final e = v050.unwrapMessage(w);
      return _fields(
        e.message,
        e.msgUid,
        e.replyTo,
        e.burnSeconds,
        e.senderHaloId,
        e.senderXPub,
        e.deliveredUid,
        e.imageB64,
        e.fileB64,
        e.mediaId,
        e.poll,
        e.sticker,
        e.preview,
      );
    }

    Map<String, Object?> v051Reads(String w) {
      final e = v051.unwrapMessage(w);
      return _fields(
        e.message,
        e.msgUid,
        e.replyTo,
        e.burnSeconds,
        e.senderHaloId,
        e.senderXPub,
        e.deliveredUid,
        e.imageB64,
        e.fileB64,
        e.mediaId,
        e.poll,
        e.sticker,
        e.preview,
      );
    }

    for (final (name, read) in [('0.5.0', v050Reads), ('0.5.1', v051Reads)]) {
      test('$name reads a stamped message as it reads it without', () async {
        final w = await wrapMessage(
          'hello there',
          msgUid: 'u7',
          replyTo: 'u6',
          burnSeconds: 30,
          sender: _me,
        );
        final plain = read(w);
        expect(plain['message'], 'hello there');
        expect(read(shotsStamped(w, const ShotsWord(on: true, at: 9))), plain);
      });

      test('$name reads a stamped receipt as a receipt', () async {
        final w = await wrapMessage('', deliveredUid: 'u3', sender: _me);
        final r = read(shotsStamped(w, const ShotsWord(on: false, at: 0)));
        expect(r, read(w));
        expect(r['delivered'], 'u3');
      });

      test('$name reads the block\'s own frame as a word with nothing in '
          'it, which its receive path drops', () async {
        final w = await wrapMessage('', sender: _me);
        final r = read(shotsStamped(w, const ShotsWord(on: true, at: 9)));
        // no uid and nothing to draw
        expect(r, {
          'message': '',
          'uid': null,
          'reply': null,
          'burn': null,
          'sender': 'amy',
          'x': 'x',
          'delivered': null,
          'image': null,
          'file': null,
          'media': null,
          'poll': null,
          'sticker': null,
          'preview': null,
        });
      });
    }
  });
}

Map<String, Object?> _fields(
  String message,
  String? uid,
  String? reply,
  int? burn,
  String? sender,
  String? x,
  String? delivered,
  String? image,
  String? file,
  String? media,
  Object? poll,
  String? sticker,
  Map<String, String>? preview,
) => {
  'message': message,
  'uid': uid,
  'reply': reply,
  'burn': burn,
  'sender': sender,
  'x': x,
  'delivered': delivered,
  'image': image,
  'file': file,
  'media': media,
  'poll': poll,
  'sticker': sticker,
  'preview': preview,
};
