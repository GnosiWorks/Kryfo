// SPDX-License-Identifier: GPL-3.0-or-later
// what the relays delivered, as the engine hands it over: {k, m}, k the
// batch's token and m a list with one {t, c, a} per event, t the lane it
// came in on, c what it carried and a when the sender wrote it by their
// clock, in seconds, where the lane knows. an entry of any other shape is
// passed over on its own; the rest still count. the app confirms the batch
// with k once it has kept it, naming the places in m it could not keep.

import 'dart:convert';

import 'dlog.dart';

typedef RelayBatch = ({
  String token,
  List<({String peer, String cipher})> msgs,
  // where each of msgs stood in m
  List<int> places,
  // when each of msgs was written, in ms by the sender's clock, or null
  List<int?> written,
});

const RelayBatch _none = (token: '', msgs: [], places: [], written: []);

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
  final written = <int?>[];
  for (var i = 0; i < m.length; i++) {
    final e = m[i];
    if (e is Map && e['t'] is String && e['c'] is String) {
      msgs.add((peer: e['t'] as String, cipher: e['c'] as String));
      places.add(i);
      final a = e['a'];
      written.add(a is int && a > 0 ? a * 1000 : null);
    }
  }
  return (
    token: all['k'] as String,
    msgs: msgs,
    places: places,
    written: written,
  );
}

/// the places in the engine's batch of the messages at [failed] in msgs
List<int> failedPlaces(RelayBatch b, Iterable<int> failed) => [
  for (final i in failed)
    if (i >= 0 && i < b.places.length) b.places[i],
]..sort();
