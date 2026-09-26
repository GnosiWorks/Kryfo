import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/helper_slots.dart';

void main() {
  test('a fresh address takes the lowest empty slot', () {
    var book = const SlotBook({});
    for (var i = 0; i < kHelperSlots; i++) {
      final (next, slot) = slotFor(book, 'addr$i');
      expect(slot, i);
      book = next;
    }
    expect(book.used, kHelperSlots);
  });

  test('an address keeps the slot it was given', () {
    var book = const SlotBook({});
    final (b1, first) = slotFor(book, 'a');
    book = b1;
    final (b2, again) = slotFor(book, 'a');
    expect(again, first);
    expect(b2.byAddress.length, 1);
  });

  test('past sixteen slots are shared evenly', () {
    var book = const SlotBook({});
    final given = <String, int>{};
    for (var i = 0; i < 40; i++) {
      final (next, slot) = slotFor(book, 'addr$i');
      book = next;
      given['addr$i'] = slot;
    }
    // everything ever given keeps its slot
    for (final e in given.entries) {
      expect(book.slotOf(e.key), e.value);
    }
    final counts = List.filled(kHelperSlots, 0);
    for (final s in book.byAddress.values) {
      counts[s]++;
    }
    expect(counts.reduce(max) - counts.reduce(min) <= 1, true);
  });

  test('the book round trips and refuses nonsense', () {
    var book = const SlotBook({});
    for (final a in ['x', 'y', 'z']) {
      book = slotFor(book, a).$1;
    }
    final back = SlotBook.read(book.write());
    expect(back.byAddress, book.byAddress);
    expect(SlotBook.read(null).byAddress, isEmpty);
    expect(SlotBook.read('not json').byAddress, isEmpty);
    expect(SlotBook.read('{"a": 99}').byAddress, isEmpty);
    expect(SlotBook.read('{"a": "3"}').byAddress, isEmpty);
    expect(SlotBook.read('[1,2]').byAddress, isEmpty);
  });

  test('a dummy address looks like a real one', () {
    final d = dummyAddress(Random(7));
    expect(d.length, 64);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(d), true);
    expect(d == dummyAddress(Random(8)), false);
  });

  test('gives sixteen distinct instance names', () {
    final names = {for (var i = 0; i < kHelperSlots; i++) slotInstance(i)};
    expect(names.length, kHelperSlots);
    expect(slotInstance(0), 'kryfo-0');
  });
}
