// SPDX-License-Identifier: GPL-3.0-or-later
// how the pairwise addresses are spread over the helper's endpoints. one
// endpoint for all would let the relay link them, one per address would let
// the helper's server count contacts. so always sixteen, the empty ones on a
// random address nothing is sent to. a slot, once given, is kept: moving an
// address would show the relay its old and new endpoint together.
import 'dart:convert';
import 'dart:math';

const kHelperSlots = 16;

class SlotBook {
  final Map<String, int> byAddress;
  const SlotBook(this.byAddress);

  static SlotBook read(String? raw) {
    if (raw == null || raw.isEmpty) return const SlotBook({});
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return const SlotBook({});
      final out = <String, int>{};
      for (final e in j.entries) {
        final k = e.key, v = e.value;
        if (k is String && v is int && v >= 0 && v < kHelperSlots) out[k] = v;
      }
      return SlotBook(out);
    } catch (_) {
      return const SlotBook({});
    }
  }

  String write() => jsonEncode(byAddress);

  int? slotOf(String address) => byAddress[address];

  /// how many of the sixteen carry a real address
  int get used => byAddress.values.toSet().length;
}

/// a new address takes the slot carrying the fewest, lowest first. returns
/// the book to save and the slot to use.
(SlotBook, int) slotFor(SlotBook book, String address) {
  final had = book.slotOf(address);
  if (had != null) return (book, had);
  final counts = List.filled(kHelperSlots, 0);
  for (final s in book.byAddress.values) {
    counts[s]++;
  }
  var best = 0;
  for (var i = 1; i < kHelperSlots; i++) {
    if (counts[i] < counts[best]) best = i;
  }
  final next = Map<String, int>.from(book.byAddress)..[address] = best;
  return (SlotBook(next), best);
}

/// for a slot with nothing real in it. the relay knocks it on the same decoy
/// timer as the rest.
String dummyAddress(Random rnd) => [
  for (var i = 0; i < 32; i++)
    rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

/// one registration per slot, so one endpoint comes back per slot
String slotInstance(int i) => 'kryfo-$i';
