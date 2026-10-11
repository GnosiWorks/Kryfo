// SPDX-License-Identifier: GPL-3.0-or-later
// what the relays delivered, as the engine hands it over: {k, m}, k the
// batch's token and m a list with one {t, c, a, f, u} per event, t the
// lane it came in on, c what it carried and a when the sender wrapped it
// by their clock, in seconds, where the lane knows. every send wraps anew,
// so a retry carries the time of the retry. f and u: when it reached the
// relay, in ms by this phone's clock, no earlier than f and no later than
// u, where the engine knows. an entry of any other shape is passed over on
// its own; the rest still count. the app confirms the batch with k once it
// has kept it, naming the places in m it could not keep.

import 'dart:convert';

import 'dlog.dart';

// when a copy reached the relay, or this phone, by this clock: no earlier
// than from, 0 when that is not known, and no later than until
typedef Reached = ({int from, int until});

typedef RelayBatch = ({
  String token,
  List<({String peer, String cipher})> msgs,
  // where each of msgs stood in m
  List<int> places,
  // when each of msgs was wrapped, in ms by the sender's clock, or null
  List<int?> written,
  // when each of msgs reached the relay, or null where the engine says not
  List<Reached?> reached,
});

const RelayBatch _none = (
  token: '',
  msgs: [],
  places: [],
  written: [],
  reached: [],
);

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
  final reached = <Reached?>[];
  for (var i = 0; i < m.length; i++) {
    final e = m[i];
    if (e is Map && e['t'] is String && e['c'] is String) {
      msgs.add((peer: e['t'] as String, cipher: e['c'] as String));
      places.add(i);
      final a = e['a'];
      written.add(a is int && a > 0 ? a * 1000 : null);
      final f = e['f'];
      final u = e['u'];
      reached.add(
        u is int && u > 0
            ? (from: f is int && f > 0 && f <= u ? f : 0, until: u)
            : null,
      );
    }
  }
  return (
    token: all['k'] as String,
    msgs: msgs,
    places: places,
    written: written,
    reached: reached,
  );
}

/// the places in the engine's batch of the messages at [failed] in msgs
List<int> failedPlaces(RelayBatch b, Iterable<int> failed) => [
  for (final i in failed)
    if (i >= 0 && i < b.places.length) b.places[i],
]..sort();
