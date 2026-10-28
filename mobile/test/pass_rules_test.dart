// SPDX-License-Identifier: GPL-3.0-or-later
// a passphrase as the engine reads it: every keyboard's digits as ascii,
// every space as a plain one, nothing trimmed, no control characters, at
// most 256 bytes, and a strength that grows with length and kinds
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/pass_rules.dart';

void main() {
  test('digits from any keyboard read as ascii, spaces as plain ones', () {
    const same = {
      '۱۲۳۴': '1234', // a persian keyboard
      '١٢٣٤': '1234', // arabic-indic
      '१२३४': '1234', // devanagari
      '１２３４': '1234', // fullwidth
      'long\u00A0phrase': 'long phrase',
      'ideo\u3000space': 'ideo space',
      ' keeps its spaces ': ' keeps its spaces ',
      'Ünïcödé': 'Ünïcödé',
    };
    same.forEach((typed, read) => expect(passFold(typed), read));
    // the last digit run unicode has, and one past it
    expect(passFold(String.fromCharCode(0x1FBF9)), '9');
    expect(passFold('²'), '²');
  });

  test('a nul, a control character or too many bytes is refused', () {
    for (final bad in ['', 'a\u0000b', 'tab\there', 'new\nline', '\u007F']) {
      expect(passUsable(bad), isFalse, reason: bad);
    }
    expect(passUsable('a' * kPassMaxBytes), isTrue);
    expect(passUsable('a' * (kPassMaxBytes + 1)), isFalse);
    // bytes, not characters: two bytes each
    expect(passUsable('é' * (kPassMaxBytes ~/ 2)), isTrue);
    expect(passUsable('é' * (kPassMaxBytes ~/ 2 + 1)), isFalse);
    expect(passTyped('a\u0000b\nc'), 'abc');
  });

  test('strength grows with length and kinds, not with repeats', () {
    expect(passStrength('aaaaaaaaaaaaaaaaaaaa'), 0);
    expect(passStrength('123456789012'), 0);
    expect(passStrength('correcthorse'), 1);
    expect(passStrength('correct horse battery'), 2);
    expect(passStrength('Tr0ub4dor&3x'), 2);
    expect(passStrength('abcabcabcabc'), 0);
    expect(passStrength('بطاقة زرقاء في الشمال'), 2);
    expect(passLength('ab\u{1F600}'), 3);
  });
}
