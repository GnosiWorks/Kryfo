// SPDX-License-Identifier: GPL-3.0-or-later
// what a person's app can do rides every envelope as 'cp' and is kept with
// the time of the envelope that said it. the newest word wins: a message
// without the bits, written after one with them, takes them away, and an
// older copy changes nothing
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/caps.dart';
import 'package:kryfo/message_envelope.dart';

void main() {
  test('the bits parse from the wire, and nothing else does', () {
    expect(capsOf(kCapsMine), kCapsMine);
    expect(capsOf(0), 0);
    expect(capsOf(-1), isNull);
    expect(capsOf('1'), isNull);
    expect(capsOf(1.5), isNull);
    expect(capsOf(null), isNull);
    expect(capsOf(1 << 40), isNull);
  });

  test('this version blocks screenshots in groups', () {
    expect(capsHave(kCapsMine, kCapGroupShots), isTrue);
    expect(capsHave(0, kCapGroupShots), isFalse);
    expect(capsHave(2, kCapGroupShots), isFalse);
  });

  test('every envelope carries the bits, 1:1 and group alike', () async {
    final one = unwrapMessage(await wrapMessage('hi', msgUid: 'u1'));
    expect(one.caps, kCapsMine);
    final group = unwrapMessage(
      await wrapMessage('hi', msgUid: 'u2', groupId: 'g1'),
    );
    expect(group.caps, kCapsMine);
    // an older version's says nothing
    expect(unwrapMessage('halo/1:{"m":"hi","w":5}').caps, isNull);
    expect(unwrapMessage('plain words').caps, isNull);
  });

  group('the newest word wins', () {
    test('bits with a time are taken', () {
      expect(capsAfter(0, 0, carried: kCapsMine, counts: true, written: 100), (
        caps: kCapsMine,
        at: 100,
      ));
    });

    test('an older copy changes nothing', () {
      expect(
        capsAfter(kCapsMine, 200, carried: 0, counts: true, written: 100),
        isNull,
      );
      expect(
        capsAfter(kCapsMine, 200, carried: null, counts: true, written: 100),
        isNull,
      );
    });

    test('a message without the bits after one with them takes them away', () {
      expect(
        capsAfter(kCapsMine, 100, carried: null, counts: true, written: 200),
        (caps: 0, at: 200),
      );
    });

    test('a frame that is no message of theirs says nothing without bits', () {
      expect(
        capsAfter(kCapsMine, 100, carried: null, counts: false, written: 200),
        isNull,
      );
    });

    test('the same word again is no change', () {
      expect(
        capsAfter(
          kCapsMine,
          100,
          carried: kCapsMine,
          counts: true,
          written: 100,
        ),
        isNull,
      );
    });

    test('on a tie the one that carried bits stands', () {
      expect(
        capsAfter(kCapsMine, 100, carried: null, counts: true, written: 100),
        isNull,
      );
      expect(
        capsAfter(0, 100, carried: kCapsMine, counts: true, written: 100),
        (caps: kCapsMine, at: 100),
      );
    });

    test('with no time, bits are taken only where none were heard', () {
      expect(capsAfter(0, 0, carried: kCapsMine, counts: true), (
        caps: kCapsMine,
        at: 0,
      ));
      expect(capsAfter(0, 100, carried: kCapsMine, counts: true), isNull);
      expect(capsAfter(kCapsMine, 0, carried: null, counts: true), isNull);
    });
  });
}
