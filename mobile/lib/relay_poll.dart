// SPDX-License-Identifier: GPL-3.0-or-later
// what the relays delivered, as the engine hands it over: a json array with
// one {t, c} per event, t the lane it came in on and c what it carried. an
// entry of any other shape is passed over on its own; the rest still count.

import 'dart:convert';

import 'dlog.dart';

List<({String peer, String cipher})> parseRelayPoll(String raw) {
  if (raw.isEmpty) return const [];
  final Object? all;
  try {
    all = jsonDecode(raw);
  } on FormatException {
    dlog('relay poll: not json');
    return const [];
  }
  if (all is! List) {
    dlog('relay poll: not a list');
    return const [];
  }
  return [
    for (final e in all)
      if (e is Map && e['t'] is String && e['c'] is String)
        (peer: e['t'] as String, cipher: e['c'] as String),
  ];
}
