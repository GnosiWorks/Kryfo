// SPDX-License-Identifier: GPL-3.0-or-later
// relays hand a catch-up back in the order of their own back-dated stamps,
// which says nothing of when each was sent. signal numbers each message on
// its sender's chain, so one sender's messages on one chain are put back in
// the order they were sent before they are opened. different senders and
// different chains keep the places they came in. the engine hands a walk
// over whole, so the batch is the catch-up and not one page of it
import 'dart:convert';
import 'dart:typed_data';

// the chain a cipher was sent on and its number there, null when it is not
// a signal message. read off the message's own fields: a whisper message is
// its version byte, the protobuf, then an 8 byte mac; an opener carries one
// whole in its field 4
(String, int)? _place(String wireB64) {
  try {
    final w = base64Decode(wireB64);
    if (w.length < 2) return null;
    var m = Uint8List.sublistView(w, 1);
    if (w[0] == 3) {
      final inner = _fields(Uint8List.sublistView(m, 1))?[4];
      if (inner is! Uint8List) return null;
      m = inner;
    } else if (w[0] != 2) {
      return null;
    }
    if (m.length < 1 + 8) return null;
    final f = _fields(Uint8List.sublistView(m, 1, m.length - 8));
    final key = f?[1];
    if (key is! Uint8List || key.isEmpty) return null;
    final n = f?[2];
    return (base64Encode(key), n is int ? n : 0);
  } catch (_) {
    return null;
  }
}

// a protobuf message's fields by number, the last of each: varints as ints,
// length-delimited ones as bytes. null when it does not read
Map<int, Object>? _fields(Uint8List b) {
  final out = <int, Object>{};
  var at = 0;
  int? varint() {
    var v = 0;
    for (var shift = 0; shift < 64; shift += 7) {
      if (at >= b.length) return null;
      final x = b[at++];
      v |= (x & 0x7f) << shift;
      if (x < 0x80) return v;
    }
    return null;
  }

  while (at < b.length) {
    final tag = varint();
    if (tag == null) return null;
    switch (tag & 7) {
      case 0:
        final v = varint();
        if (v == null) return null;
        out[tag >> 3] = v;
      case 2:
        final n = varint();
        if (n == null || n < 0 || n > b.length - at) return null;
        out[tag >> 3] = Uint8List.sublistView(b, at, at + n);
        at += n;
      default:
        return null;
    }
  }
  return out;
}

// room frames are not signal: roomsInSendOrder puts them in order by the
// number their sender gave them. the first-contact lane is shared by every
// stranger, but its chains are keyed by the sender's ratchet key as well,
// so two strangers never mix
bool keepsArrivalOrder(String peer) =>
    peer.startsWith('room:') || peer.startsWith('roomfc:');

// [lane] is a lane whose frames are left as they came
List<T> inSendOrder<T>(
  List<T> batch, {
  required String Function(T) peer,
  required String Function(T) cipher,
  bool Function(String peer)? lane,
}) {
  // each chain's places in the batch, and its messages with their numbers
  final chains = <String, List<int>>{};
  final numbers = <int, int>{};
  for (var i = 0; i < batch.length; i++) {
    final from = peer(batch[i]);
    if (lane?.call(from) ?? false) continue;
    final at = _place(cipher(batch[i]));
    if (at == null) continue;
    (chains['$from ${at.$1}'] ??= []).add(i);
    numbers[i] = at.$2;
  }
  final out = List<T>.of(batch);
  for (final places in chains.values) {
    if (places.length < 2) continue;
    final sorted = [...places]
      ..sort((a, b) {
        final c = numbers[a]!.compareTo(numbers[b]!);
        return c != 0 ? c : a.compareTo(b);
      });
    for (var k = 0; k < places.length; k++) {
      out[places[k]] = batch[sorted[k]];
    }
  }
  return out;
}

/// a catch-up's room frames back in the order they were sent. on each
/// member's lane the numbered frames are sorted by their number, in the
/// places numbered frames held. a leave or a removal goes after every
/// other frame of the batch, so a member's last words, sent before they
/// left or were taken out, still find them in the roster
List<T> roomsInSendOrder<T>(
  List<T> batch, {
  required String Function(T) peer,
  required ({int? number, bool shrinks}) Function(T) place,
}) {
  final lanes = <String, List<int>>{};
  final at = <int, ({int? number, bool shrinks})>{};
  for (var i = 0; i < batch.length; i++) {
    final from = peer(batch[i]);
    if (!from.startsWith('room:')) continue;
    final p = place(batch[i]);
    at[i] = p;
    if (p.number != null) (lanes[from] ??= []).add(i);
  }
  final sorted = List<T>.of(batch);
  final shrinks = List<bool>.filled(batch.length, false);
  for (final e in at.entries) {
    if (e.value.number == null) shrinks[e.key] = e.value.shrinks;
  }
  for (final places in lanes.values) {
    final byNumber = [...places]
      ..sort((a, b) {
        final c = at[a]!.number!.compareTo(at[b]!.number!);
        return c != 0 ? c : a.compareTo(b);
      });
    for (var k = 0; k < places.length; k++) {
      sorted[places[k]] = batch[byNumber[k]];
      shrinks[places[k]] = at[byNumber[k]]!.shrinks;
    }
  }
  return [
    for (var i = 0; i < sorted.length; i++)
      if (!shrinks[i]) sorted[i],
    for (var i = 0; i < sorted.length; i++)
      if (shrinks[i]) sorted[i],
  ];
}
