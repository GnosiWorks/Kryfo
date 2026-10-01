// SPDX-License-Identifier: GPL-3.0-or-later
// relays hand a catch-up back in the order of their own back-dated stamps,
// which says nothing of when each was sent. signal numbers each message on
// its sender's chain, so one sender's messages on one chain are put back in
// the order they were sent before they are opened. different senders and
// different chains keep the places they came in
import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

// the chain a cipher was sent on and its number there, null when it is not
// a signal message
(String, int)? _place(String wireB64) {
  try {
    final w = base64Decode(wireB64);
    if (w.length < 2) return null;
    final body = Uint8List.fromList(w.sublist(1));
    final SignalMessage m;
    if (w[0] == CiphertextMessage.prekeyType) {
      m = PreKeySignalMessage(body).getWhisperMessage();
    } else if (w[0] == CiphertextMessage.whisperType) {
      m = SignalMessage.fromSerialized(body);
    } else {
      return null;
    }
    return (base64Encode(m.getSenderRatchetKey().serialize()), m.getCounter());
  } catch (_) {
    return null;
  }
}

// [lane] is a lane many senders share: it names no one, so nothing on it
// is reordered
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
