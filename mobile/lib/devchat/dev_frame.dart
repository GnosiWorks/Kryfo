// SPDX-License-Identifier: GPL-3.0-or-later
// what a frame to or from the developer may carry. out, every frame for the
// dev chat is rewritten here from an allowlist before it is sealed: the
// person's everyday name, keys, onion, face and tier never ride along, and
// a group, an introduction or a poll is not sent at all, since answering
// one would bring the everyday identity in. in, the same kinds are
// dropped, his face and tier are ignored, and who it says sent it must be
// his pinned key. the ciphers sealed here are the only ones the wire takes
// for an anonymous chat

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;

import '../dlog.dart';
import 'dev_key.dart';

const _prefix = 'halo/1:';

// on every frame to him. one value for both ways of writing: he is not
// told which chats are anonymous
const kDevSupport = 1;

// the message and what hangs off it: kept as they are, both ways
final kDevKept = _set(
  'm u q b r ed un pn dr i f fn vo vd mid ci ct pi cr nd sc st pv w',
);

// out only: the proof of work, over 'm', which stays as it was
final kDevPow = _set('pw pb');

// who sent it. out, rewritten; in, checked against his pinned key
final kDevSender = _set('h e x o');

// the face and the supporter tier: never sent to him, never taken from him
final kDevIgnored = _set('av bg');

// group controls and rosters, introductions and polls: no such frame goes
// to him or is taken from him
final kDevNever = _set('g gc rs rp in pl vt pc');

Set<String> _set(String keys) => Set.unmodifiable(keys.split(' '));

// the support marker
const kDevMarker = 'sp';

// what a frame from him keeps
final kDevInKept = Set<String>.unmodifiable({
  ...kDevKept,
  ...kDevSender,
  kDevMarker,
});

// the name an anonymous dev chat writes under, made for it alone
class DevSelf {
  const DevSelf({required this.id, required this.edPub, required this.xPub});

  // its three words
  final String id;
  // 64 hex each
  final String edPub;
  final String xPub;

  // from the keys the chat keeps: the ed key is the engine's 64 bytes, seed
  // then public half, and the x public key comes from the private one.
  // null when they do not read
  static DevSelf? ofKeys(String? id, String? edPriv, String? xPriv) {
    if (id == null || id.isEmpty || id.trim() != id) return null;
    if (edPriv == null || !_hex128.hasMatch(edPriv)) return null;
    if (xPriv == null || !_hex64.hasMatch(xPriv)) return null;
    try {
      final pair = Curve.generateKeyPairFromPrivate(_bytes(xPriv));
      return DevSelf(
        id: id,
        edPub: edPriv.substring(64).toLowerCase(),
        xPub: _hex(pair.publicKey.serialize().sublist(1)),
      );
    } catch (_) {
      return null;
    }
  }
}

final _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');
final _hex128 = RegExp(r'^[0-9a-fA-F]{128}$');

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

List<int> _bytes(String hex) => [
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

Map<String, dynamic>? _read(String wrapped) {
  if (!wrapped.startsWith(_prefix)) return null;
  try {
    final j = jsonDecode(wrapped.substring(_prefix.length));
    return j is Map<String, dynamic> ? j : null;
  } catch (_) {
    return null;
  }
}

String? _no(String why) {
  dlog('dev frame: $why, not sending it');
  return null;
}

/// [wrapped] as it may go to the developer: the allowlist only, the support
/// marker on, the onion empty, no face and no tier. with [anon] the name
/// made for the chat stands where the everyday one was, and a voice note
/// goes disguised or not at all. null when the frame carries anything else
/// or cannot be rewritten: then nothing is sent
String? devOutFrame(String wrapped, {DevSelf? anon}) {
  final j = _read(wrapped);
  if (j == null) return _no('not a frame');
  final out = <String, dynamic>{};
  var sender = false;
  for (final e in j.entries) {
    final k = e.key;
    if (kDevKept.contains(k) || kDevPow.contains(k)) {
      out[k] = e.value;
    } else if (kDevSender.contains(k)) {
      sender = true;
    } else if (!kDevIgnored.contains(k) && k != kDevMarker) {
      return _no('it carries $k');
    }
  }
  if (sender) {
    if (anon != null) {
      out['h'] = anon.id;
      out['e'] = anon.edPub;
      out['x'] = anon.xPub;
    } else {
      for (final k in const ['h', 'e', 'x']) {
        if (j.containsKey(k)) out[k] = j[k];
      }
    }
    out['o'] = '';
  }
  out[kDevMarker] = kDevSupport;
  if (anon != null && out['vo'] == 1 && out['vd'] != 1) {
    return _no('an anonymous voice note is not disguised');
  }
  final text = '$_prefix${jsonEncode(out)}';
  // read it back: only what is allowed, the message as it was
  final back = _read(text);
  if (back == null || !_outOk(back, j, anon)) {
    return _no('it did not read back');
  }
  return text;
}

bool _outOk(Map<String, dynamic> back, Map<String, dynamic> was, DevSelf? a) {
  for (final e in back.entries) {
    final k = e.key;
    if (kDevKept.contains(k) || kDevPow.contains(k)) {
      if (jsonEncode(e.value) != jsonEncode(was[k])) return false;
    } else if (k == 'o') {
      if (e.value != '') return false;
    } else if (k == 'h' || k == 'e' || k == 'x') {
      final want = a == null
          ? was[k]
          : switch (k) {
              'h' => a.id,
              'e' => a.edPub,
              _ => a.xPub,
            };
      if (e.value != want) return false;
    } else if (k != kDevMarker || e.value != kDevSupport) {
      return false;
    }
  }
  return true;
}

// the pinned key a dev chat id names, while it works
DevKey? _keyOf(String peer) {
  if (!peer.startsWith('dev:')) return null;
  final k = devKeyById(peer.substring(4));
  if (k == null || k.status == DevKeyStatus.retired) return null;
  return k.chatId == peer ? k : null;
}

/// a frame from the developer as the dev chat takes it, or null to drop it
/// unseen. [peer] is the chat it came in for: a pinned key that still
/// works. who it says sent it must be that key: the three words where it
/// names them, the x key where it names one. a frame of a kind he never
/// sends here is dropped whole; his face, his tier and anything unknown are
/// left out
String? devInFrame(String peer, String wrapped) {
  final k = _keyOf(peer);
  if (k == null) return null;
  final j = _read(wrapped);
  if (j == null) return null;
  if (j.keys.any(kDevNever.contains)) return null;
  if (j.containsKey('h') && j['h'] != k.threeWords) return null;
  if (j.containsKey('x')) {
    final x = j['x'];
    if (x is! String || x.toLowerCase() != k.xPub) return null;
  }
  final kept = {
    for (final e in j.entries)
      if (kDevInKept.contains(e.key)) e.key: e.value,
  };
  return '$_prefix${jsonEncode(kept)}';
}

/// the ciphers the dev chat's own seal made, by their sha256, for ten
/// minutes: a media slice goes out up to three times as the same cipher.
/// the wire takes nothing else for an anonymous chat
class DevTokens {
  DevTokens({
    this.ttl = const Duration(minutes: 10),
    this.cap = 512,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration ttl;
  // the oldest go first past it
  final int cap;
  final DateTime Function() _now;
  // hash -> until, oldest first
  final _made = <String, int>{};

  static String _hash(String cipher) =>
      sha256.convert(utf8.encode(cipher)).toString();

  void mint(String cipher) {
    _prune();
    final h = _hash(cipher);
    _made.remove(h);
    _made[h] = _now().add(ttl).millisecondsSinceEpoch;
    while (_made.length > cap) {
      _made.remove(_made.keys.first);
    }
  }

  bool has(String cipher) {
    _prune();
    return _made.containsKey(_hash(cipher));
  }

  int get length {
    _prune();
    return _made.length;
  }

  void clear() => _made.clear();

  void _prune() {
    final at = _now().millisecondsSinceEpoch;
    _made.removeWhere((_, until) => until <= at);
  }
}

// the one set: the seal fills it, the gate reads it
final devTokens = DevTokens();
