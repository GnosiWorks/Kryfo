// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/wipe_word.dart';

void main() {
  test('matches the wipe word however it is typed', () {
    expect(isWipeWord('xóa', 'xóa'), isTrue);
    expect(isWipeWord('xoa', 'xóa'), isTrue);
    expect(isWipeWord('xoá', 'xóa'), isTrue); // a + combining acute
    expect(isWipeWord(' XÓA ', 'xoa'), isTrue);
    expect(isWipeWord('löschen', 'löschen'), isTrue);
    expect(isWipeWord('SIL', 'sil'), isTrue);
    expect(isWipeWord('стереть', 'стереть'), isTrue);
    expect(isWipeWord('抹除', '抹除'), isTrue);
    expect(isWipeWord('wipe', 'стереть'), isTrue);
    expect(isWipeWord('پاك', 'پاک'), isTrue); // arabic kaf for persian
    expect(isWipeWord('اِمسَح', 'امسح'), isTrue); // with vowel marks
    expect(isWipeWord('إمسح', 'امسح'), isTrue); // hamza under the alef
  });

  test('the hindi word, with or without its dot and moon', () {
    expect(isWipeWord('मिटाएँ', 'मिटाएँ'), isTrue);
    expect(isWipeWord('मिटाएं', 'मिटाएँ'), isTrue); // anusvara for chandrabindu
    expect(isWipeWord('फोटो', '\u095Eोटो'), isTrue); // no dot
    expect(isWipeWord('फ़ोटो', '\u095Eोटो'), isTrue); // dot as a mark
    expect(isWipeWord('मिटा', 'मिटाएँ'), isFalse);
  });

  test('rejects anything else', () {
    expect(isWipeWord('xo', 'xóa'), isFalse);
    expect(isWipeWord('', 'xóa'), isFalse);
    expect(isWipeWord(null, 'xóa'), isFalse);
    expect(isWipeWord('стерти', 'стереть'), isFalse);
    expect(isWipeWord('wip', 'wipe'), isFalse);
  });
}
