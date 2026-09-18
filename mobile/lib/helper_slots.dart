// SPDX-License-Identifier: GPL-3.0-or-later
// how kryfo's addresses are spread over the helper's endpoints.
//
// kryfo does not listen on one address, it listens on a pairwise address per
// contact. handing the relay one endpoint for all of them would let the relay
// tie those addresses together, which today it cannot. handing it one endpoint
// per address would let the helper's server count the topics and learn how
// many people write to you.
//
// so: always exactly sixteen endpoints, no matter how many contacts there
// are. the empty ones are registered too, with a random address that nothing
// will ever be sent to, so the relay cannot tell a real one from a dummy and
// the helper's server sees the same sixteen topics on every phone.
//
// a slot, once given to an address, is kept. reshuffling would show the relay
// the old and the new endpoint for the same address, which is the linking
// this exists to avoid.
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

/// the slot for [address], keeping whatever it already had. a new address
/// takes the lowest empty slot; once all sixteen carry something, it takes
/// the one carrying the fewest, so the relay sees buckets rather than a list.
///
/// returns the book to save and the slot to use.
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

/// an address that is not one of ours, for a slot with nothing real in it.
/// the relay stores it and knocks it on the same decoy timer as the rest.
String dummyAddress(Random rnd) => [
  for (var i = 0; i < 32; i++)
    rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

/// the name kryfo gives the distributor for slot [i]. one registration per
/// slot, so one endpoint comes back per slot.
String slotInstance(int i) => 'kryfo-$i';
