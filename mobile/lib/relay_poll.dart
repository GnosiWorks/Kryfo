// SPDX-License-Identifier: GPL-3.0-or-later
// what the relays delivered, as the engine hands it over: {k, m}, k the
// batch's token and m a list with one {t, c} per event, t the lane it came
// in on and c what it carried. an entry of any other shape is passed over
// on its own; the rest still count. the app confirms the batch with k once
// it has kept it, naming the places in m it could not keep.

import 'dart:convert';

import 'dlog.dart';

typedef RelayBatch = ({
  String token,
  List<({String peer, String cipher})> msgs,
  // where each of msgs stood in m
  List<int> places,
});

const RelayBatch _none = (token: '', msgs: [], places: []);

RelayBatch parseRelayPoll(String raw) {
  if (raw.isEmpty) return _none;
  final Object? all;
  try {
    all = jsonDecode(raw);
  } on FormatException {
    dlog('relay poll: not json');
    return _none;
  }
  if (all is! Map || all['k'] is! String || all['m'] is! List) {
    dlog('relay poll: not a batch');
    return _none;
  }
  final m = all['m'] as List;
  final msgs = <({String peer, String cipher})>[];
  final places = <int>[];
  for (var i = 0; i < m.length; i++) {
    final e = m[i];
    if (e is Map && e['t'] is String && e['c'] is String) {
      msgs.add((peer: e['t'] as String, cipher: e['c'] as String));
      places.add(i);
    }
  }
  return (token: all['k'] as String, msgs: msgs, places: places);
}

/// the places in the engine's batch of the messages at [failed] in msgs
List<int> failedPlaces(RelayBatch b, Iterable<int> failed) => [
  for (final i in failed)
    if (i >= 0 && i < b.places.length) b.places[i],
]..sort();
