// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/wipe_word.dart';

void main() {
  test('the wipe word, however the keyboard typed it', () {
    expect(isWipeWord('xóa', 'xóa'), isTrue);
    expect(isWipeWord('xoa', 'xóa'), isTrue);
    expect(isWipeWord('xoá', 'xóa'), isTrue); // a + combining acute
    expect(isWipeWord(' XÓA ', 'xoa'), isTrue);
    expect(isWipeWord('löschen', 'löschen'), isTrue);
    expect(isWipeWord('SIL', 'sil'), isTrue);
    expect(isWipeWord('стереть', 'стереть'), isTrue);
    expect(isWipeWord('抹掉', '抹掉'), isTrue);
    expect(isWipeWord('wipe', 'стереть'), isTrue);
  });

  test('anything else is not', () {
    expect(isWipeWord('xo', 'xóa'), isFalse);
    expect(isWipeWord('', 'xóa'), isFalse);
    expect(isWipeWord(null, 'xóa'), isFalse);
    expect(isWipeWord('стерти', 'стереть'), isFalse);
    expect(isWipeWord('wip', 'wipe'), isFalse);
  });
}
