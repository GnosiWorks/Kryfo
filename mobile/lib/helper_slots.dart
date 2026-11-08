// SPDX-License-Identifier: GPL-3.0-or-later
// how the addresses kryfo listens on are spread over the helper's
// endpoints. one endpoint for all would let the relay tie them together,
// one per address would let the helper's server count contacts. so always
// sixteen.
//
// the engine names each address by an id, a keyed hash, never the address
// itself, and names its group: the addresses that already reach the relay
// over one socket and tor circuit (a batch of up to eight contacts, a room,
// one first-contact address). a group has one slot and a slot only ever
// serves one group, so an endpoint never ties together what the relay sees
// apart. a slot whose group is gone gets a new endpoint before it serves
// another. a slot with no address registers a key that belongs to nothing,
// so the helper's server sees sixteen alike; the relay can tell a stand-in
// in time, as no wrap ever comes for it. groups past the free slots are not
// registered at all: they come with the check-ins.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

// the cap: how many endpoints a phone registers, whatever it listens on.
// a batch takes one, the first-contact address one, a room one. with
// sixteen, a phone of up to 120 contacts in one identity (15 batches) has a
// slot for each; past that the newest batches and the rooms wait for the
// check-ins (helper_slots_test.dart measures it)
const kHelperSlots = 16;

class KnockAddress {
  // the engine's id for the address
  final String address;
  final String group;
  const KnockAddress(this.address, this.group);
}

/// the engine's list, [{"i":id,"g":group}]
List<KnockAddress> knockAddressesOf(String raw) {
  try {
    final j = jsonDecode(raw);
    if (j is! List) return const [];
    return [
      for (final r in j)
        if (r is Map && r['i'] is String && r['g'] is String)
          KnockAddress(r['i'] as String, r['g'] as String),
    ];
  } catch (_) {
    return const [];
  }
}

// a batch of contacts ("everyday:<identity>:<n>", engine/batches.go) never
// changes and never goes away. a room or a first-contact address does, and
// so did the four hashed lanes before batches ("everyday:<n>"): their slots
// are let go once and serve batches after
final _kBatchGroup = RegExp(r'^everyday:\d+:\d+$');
bool lastingGroup(String g) => _kBatchGroup.hasMatch(g);

// a hidden chat's address is read but never registered. so that this alone
// does not mark it, each contact's address rests too, one month in five or
// so, in a month of its own: unregistered, its registration left to lapse
// as a hidden one's does. its messages come with the next knock or
// check-in
const kRestWindowMs = 30 * 24 * 60 * 60 * 1000;
const kRestOneIn = 5;

bool restsNow(String id, int nowMs) {
  final phase = sha256.convert(utf8.encode('phase:$id')).bytes;
  final offset =
      ((phase[0] << 24 | phase[1] << 16 | phase[2] << 8 | phase[3]) &
          0x7fffffff) %
      kRestWindowMs;
  final window = (nowMs + offset) ~/ kRestWindowMs;
  return sha256.convert(utf8.encode('rest:$id:$window')).bytes[0] %
          kRestOneIn ==
      0;
}

bool _mainGroup(String g) => lastingGroup(g) || g.startsWith('firstcontact:');

// the first-contact address first, then the batches oldest first
int _batchOrder(String g) => lastingGroup(g)
    ? int.parse(g.substring(g.lastIndexOf(':') + 1))
    : g.startsWith('firstcontact:')
    ? -1
    : 0;

class SlotBook {
  // address -> slot
  final Map<String, int> byAddress;
  // slot -> the group it serves. a slot never serves two
  final Map<int, String> owner;
  // slot -> its endpoint's generation, one up each time it is let go
  final Map<int, int> gen;
  // slot -> the key registered for it while it carries no address
  final Map<int, String> standIn;

  const SlotBook({
    this.byAddress = const {},
    this.owner = const {},
    this.gen = const {},
    this.standIn = const {},
  });

  static Map<int, V> _slots<V>(Object? m, bool Function(Object?) ok) {
    final out = <int, V>{};
    if (m is! Map) return out;
    for (final e in m.entries) {
      final s = int.tryParse('${e.key}');
      if (s != null && s >= 0 && s < kHelperSlots && ok(e.value)) {
        out[s] = e.value as V;
      }
    }
    return out;
  }

  static SlotBook read(String? raw) {
    if (raw == null || raw.isEmpty) return const SlotBook();
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return const SlotBook();
      final a = j['a'];
      final byAddress = <String, int>{};
      if (a is Map) {
        for (final e in a.entries) {
          final v = e.value;
          if (e.key is String && v is int && v >= 0 && v < kHelperSlots) {
            byAddress[e.key as String] = v;
          }
        }
      }
      return SlotBook(
        byAddress: byAddress,
        owner: _slots<String>(j['o'], (v) => v is String),
        gen: _slots<int>(j['g'], (v) => v is int && v >= 0),
        standIn: _slots<String>(j['k'], (v) => v is String && v.length == 64),
      );
    } catch (_) {
      return const SlotBook();
    }
  }

  String write() => jsonEncode({
    'a': byAddress,
    'o': {for (final e in owner.entries) '${e.key}': e.value},
    'g': {for (final e in gen.entries) '${e.key}': e.value},
    'k': {for (final e in standIn.entries) '${e.key}': e.value},
  });

  int? slotOf(String address) => byAddress[address];

  /// the distributor's name for a slot's registration now
  String instance(int slot) => slotInstance(slot, gen[slot] ?? 0);

  /// slots that carry a real address
  Set<int> get carrying => byAddress.values.toSet();

  SlotBook copyWith({
    Map<String, int>? byAddress,
    Map<int, String>? owner,
    Map<int, int>? gen,
    Map<int, String>? standIn,
  }) => SlotBook(
    byAddress: byAddress ?? this.byAddress,
    owner: owner ?? this.owner,
    gen: gen ?? this.gen,
    standIn: standIn ?? this.standIn,
  );
}

class SlotPlan {
  final SlotBook book;
  // slots that need a new endpoint before anything is registered on them
  final Set<int> renew;
  const SlotPlan(this.book, this.renew);
}

/// a secret key for a slot with no address, 64 hex
String standInKey(Random rnd) => [
  for (var i = 0; i < 32; i++)
    rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

/// the book for the addresses listened on now. kept slots stay, slots of
/// groups that are gone are let go, new addresses take a free slot while
/// that leaves one for every main group still without one, or else share
/// one of their own group's
SlotPlan planSlots(SlotBook book, List<KnockAddress> live, Random rnd) {
  final groupOf = {for (final a in live) a.address: a.group};
  final groups = groupOf.values.toSet();
  final byAddress = Map<String, int>.from(book.byAddress);
  final owner = Map<int, String>.from(book.owner);
  final gen = Map<int, int>.from(book.gen);
  final standIn = Map<int, String>.from(book.standIn);
  final renew = <int>{};

  for (final e in book.owner.entries) {
    if (lastingGroup(e.value) || groups.contains(e.value)) continue;
    owner.remove(e.key);
    gen[e.key] = (gen[e.key] ?? 0) + 1;
    standIn[e.key] = standInKey(rnd);
    renew.add(e.key);
  }
  byAddress.removeWhere((a, s) => groupOf[a] == null || owner[s] != groupOf[a]);

  List<int> ownedBy(String g) => [
    for (var s = 0; s < kHelperSlots; s++)
      if (owner[s] == g) s,
  ];
  // a free slot kept back from the rooms for each main group that has none
  // yet: the batches listened on now and one first-contact address. the
  // main groups take theirs in order and keep nothing back from each other
  int reserveFor(String g) {
    if (_mainGroup(g)) return 0;
    var n = 0;
    for (final x in groups) {
      if (lastingGroup(x) && !owner.containsValue(x)) n++;
    }
    if (!owner.values.any((x) => x.startsWith('firstcontact:'))) n++;
    return n;
  }

  // the main groups first, the oldest batches first: rooms get what they
  // leave
  final waiting =
      [
        for (final a in live)
          if (!byAddress.containsKey(a.address)) a,
      ]..sort((x, y) {
        final mx = _mainGroup(x.group) ? 0 : 1;
        final my = _mainGroup(y.group) ? 0 : 1;
        if (mx != my) return mx - my;
        final bx = _batchOrder(x.group), by = _batchOrder(y.group);
        if (bx != by) return bx.compareTo(by);
        final g = x.group.compareTo(y.group);
        return g != 0 ? g : x.address.compareTo(y.address);
      });
  for (final a in waiting) {
    final own = ownedBy(a.group);
    final free = [
      for (var s = 0; s < kHelperSlots; s++)
        if (!owner.containsKey(s) && !renew.contains(s)) s,
    ];
    int? slot;
    if (own.isNotEmpty) {
      slot = own.first;
    } else if (free.length > reserveFor(a.group)) {
      slot = free.first;
      owner[slot] = a.group;
    }
    if (slot != null) byAddress[a.address] = slot;
  }

  final carrying = byAddress.values.toSet();
  for (var s = 0; s < kHelperSlots; s++) {
    if (!carrying.contains(s)) standIn[s] ??= standInKey(rnd);
  }
  return SlotPlan(
    SlotBook(byAddress: byAddress, owner: owner, gen: gen, standIn: standIn),
    renew,
  );
}

/// one registration per slot, so one endpoint comes back per slot. a new
/// generation is a new registration, so a new endpoint
String slotInstance(int slot, [int gen = 0]) => 'kryfo-$slot.$gen';

/// the slot and generation of an instance name, or null for another's
(int, int)? instanceSlot(String instance) {
  final m = RegExp(r'^kryfo-(\d+)\.(\d+)$').firstMatch(instance);
  if (m == null) return null;
  final s = int.parse(m.group(1)!);
  if (s >= kHelperSlots) return null;
  return (s, int.parse(m.group(2)!));
}

/// what the helper app may show for a registration: the slot, never the
/// generation or anything about who it serves, so all sixteen read alike
/// and a renewed slot keeps its name
String slotLabel(String instance) {
  final sg = instanceSlot(instance);
  return sg == null ? 'Kryfo' : 'Kryfo ${sg.$1 + 1}/$kHelperSlots';
}

/// slot -> endpoint, for the registrations of the book's generations
Map<int, String> slotEndpoints(SlotBook book, Map<String, String> byInstance) {
  final out = <int, String>{};
  for (final e in byInstance.entries) {
    final sg = instanceSlot(e.key);
    if (sg == null || (book.gen[sg.$1] ?? 0) != sg.$2) continue;
    out[sg.$1] = e.value;
  }
  return out;
}

/// one registration for the engine: an address, or a slot's stand-in key
class KnockItem {
  final String? address;
  final String? key;
  final int slot;
  final String endpoint;
  const KnockItem.address(this.address, this.slot, this.endpoint) : key = null;
  const KnockItem.standIn(this.key, this.slot, this.endpoint) : address = null;

  /// how the engine names it in its answer
  String get name => address ?? 's$slot';

  Map<String, Object> toJson() => address != null
      ? {'i': address!, 'e': endpoint}
      : {'k': key!, 's': slot, 'e': endpoint};
}

/// what should be registered now: every address on its slot's endpoint, and
/// each slot with no address on its stand-in key. a slot that has an
/// address now and still a stand-in gets the stand-in forgotten
List<KnockItem> wantedItems(SlotBook book, Map<int, String> endpoints) {
  final out = <KnockItem>[];
  final carrying = book.carrying;
  for (final e in book.byAddress.entries) {
    final ep = endpoints[e.value];
    if (ep != null) out.add(KnockItem.address(e.key, e.value, ep));
  }
  for (var s = 0; s < kHelperSlots; s++) {
    final k = book.standIn[s];
    final ep = endpoints[s];
    if (k == null || ep == null) continue;
    out.add(KnockItem.standIn(k, s, carrying.contains(s) ? '' : ep));
  }
  return out;
}
