// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's keys on the wire. every 1:1 call the engine makes asks
// the gate when it names a pinned xpub, fc or onion, and such a call goes
// out only for the dev chat, the way it was started: nothing before the
// first send, nothing after a delete, nothing for any other chat. below it,
// how an id or a card from the wire is told apart from him: by his keys,
// never by his three words

import 'dart:convert';

import '../dlog.dart';
import 'dev_chat.dart';
import 'dev_key.dart';

// what a refused call answers, in the engine's own error form
const kDevRefused = 'error: not sent';

// what the gate says to a call: out as asked, refused, or out through the
// room exports as the name made for an anonymous chat
class DevWay {
  const DevWay._(this.go, this.asRoom);

  const DevWay.room(String priv) : this._(true, priv);

  static const pass = DevWay._(true, null);
  static const refused = DevWay._(false, null);

  final bool go;
  final String? asRoom;

  @override
  bool operator ==(Object other) =>
      other is DevWay && other.go == go && other.asRoom == asRoom;

  @override
  int get hashCode => Object.hash(go, asRoom);

  @override
  String toString() => !go ? 'refused' : (asRoom == null ? 'pass' : 'room');
}

class DevGate {
  DevGate({this.chat, bool Function(String cipher)? minted})
    : minted = minted ?? _none;

  // the dev chat as the everyday container keeps it, read only when a call
  // names a pinned key. no reader, or a read that fails, refuses
  Future<DevChatRow?> Function()? chat;

  // a cipher the dev chat's own encrypt made. only those take the
  // anonymous lane
  bool Function(String cipher) minted;

  static bool _none(String _) => false;

  Future<DevChatRow?> _row() async {
    final read = chat;
    if (read == null) return null;
    try {
      return await read();
    } catch (e) {
      dlog('dev gate: the chat did not read ($e)');
      return null;
    }
  }

  // the chat's state when it was started and talks to [k], else null. a
  // retired key takes nothing more
  static DevState? _on(DevChatRow? r, DevKey k) {
    if (r == null || !r.started || k.status == DevKeyStatus.retired) {
      return null;
    }
    return r.keyId == k.keyId ? r.state : null;
  }

  static DevWay _asAnon(DevChatRow r, bool ok) {
    final p = r.anonXPriv;
    return ok && p != null && p.isNotEmpty ? DevWay.room(p) : DevWay.refused;
  }

  // ---- the table, one call at a time ----

  // the pair lane (nostrSend)
  static DevWay relayWay(
    DevChatRow? r,
    DevKey k,
    String cipher,
    bool Function(String) minted,
  ) => switch (_on(r, k)) {
    DevState.everyday => DevWay.pass,
    DevState.anon => _asAnon(r!, minted(cipher)),
    _ => DevWay.refused,
  };

  // a first contact: the xpub and the fc must both be the one key's
  static DevWay firstContactWay(
    DevChatRow? r,
    DevKey? byXPub,
    DevKey? byFc,
    String cipher,
    bool Function(String) minted,
  ) {
    if (byXPub == null || byFc == null || byXPub.keyId != byFc.keyId) {
      return DevWay.refused;
    }
    return relayWay(r, byXPub, cipher, minted);
  }

  // a subscription to the pair lane (nostrSubscribeBg)
  static DevWay listenWay(DevChatRow? r, DevKey k) => switch (_on(r, k)) {
    DevState.everyday => DevWay.pass,
    DevState.anon => _asAnon(r!, true),
    _ => DevWay.refused,
  };

  // the onion lane: only an everyday chat, and only when an onion is pinned
  static DevWay onionWay(DevChatRow? r, DevKey k) =>
      k.onion.isNotEmpty && _on(r, k) == DevState.everyday
      ? DevWay.pass
      : DevWay.refused;

  // a room export naming a pinned key: only as the anonymous chat's own name
  static bool roomOk(DevChatRow? r, DevKey k, String priv, {bool ok = true}) {
    if (_on(r, k) != DevState.anon) return false;
    final p = r!.anonXPriv;
    return ok && p != null && p.isNotEmpty && p == priv;
  }

  // ---- the doors. out is the call as asked, room the reroute ----

  Future<String> nostrSend(
    String xPub,
    String cipher, {
    required Future<String> Function() out,
    required Future<String> Function(String priv) room,
  }) async {
    final k = devKeyByXPub(xPub);
    if (k == null) return out();
    return _go('relay', relayWay(await _row(), k, cipher, minted), out, room);
  }

  Future<String> sendFirstContact(
    String xPub,
    String fc,
    String cipher, {
    required Future<String> Function() out,
    required Future<String> Function(String priv) room,
  }) async {
    final byX = devKeyByXPub(xPub);
    final byFc = devKeyByFc(fc);
    if (byX == null && byFc == null) return out();
    final way = firstContactWay(await _row(), byX, byFc, cipher, minted);
    return _go('first contact', way, out, room);
  }

  Future<String> sendTo(
    String onion, {
    required Future<String> Function() out,
  }) async {
    final k = devKeyByOnion(onion);
    if (k == null) return out();
    return _go('onion', onionWay(await _row(), k), out, null);
  }

  Future<String> listen(
    String xPub, {
    required Future<String> Function() out,
    required Future<String> Function(String priv) room,
  }) async {
    final k = devKeyByXPub(xPub);
    if (k == null) return out();
    return _go('listen', listenWay(await _row(), k), out, room);
  }

  Future<String> roomSend(
    String priv,
    String pub,
    String cipher, {
    required Future<String> Function() out,
  }) async {
    final k = devKeyByXPub(pub);
    if (k == null) return out();
    final ok = roomOk(await _row(), k, priv, ok: minted(cipher));
    return _go('room', ok ? DevWay.pass : DevWay.refused, out, null);
  }

  Future<String> roomSendFirstContact(
    String priv,
    String pub,
    String fc,
    String cipher, {
    required Future<String> Function() out,
  }) async {
    final byX = devKeyByXPub(pub);
    final byFc = devKeyByFc(fc);
    if (byX == null && byFc == null) return out();
    final ok =
        byX != null &&
        byFc != null &&
        byX.keyId == byFc.keyId &&
        roomOk(await _row(), byX, priv, ok: minted(cipher));
    return _go(
      'room first contact',
      ok ? DevWay.pass : DevWay.refused,
      out,
      null,
    );
  }

  Future<String> roomListen(
    String priv,
    String pub, {
    required Future<String> Function() out,
  }) async {
    final k = devKeyByXPub(pub);
    if (k == null) return out();
    final ok = roomOk(await _row(), k, priv);
    return _go('room listen', ok ? DevWay.pass : DevWay.refused, out, null);
  }

  // for a call that cannot wait on the chat: does it name a pinned key
  bool names({String? xPub, String? fc, String? onion}) =>
      (xPub != null && devKeyByXPub(xPub) != null) ||
      (fc != null && devKeyByFc(fc) != null) ||
      (onion != null && devKeyByOnion(onion) != null);

  static Future<String> _go(
    String door,
    DevWay way,
    Future<String> Function() out,
    Future<String> Function(String priv)? room,
  ) {
    if (!way.go) {
      dlog('dev gate: $door refused');
      return Future.value(kDevRefused);
    }
    final p = way.asRoom;
    if (p == null) return out();
    if (room == null) return Future.value(kDevRefused);
    return room(p);
  }
}

// the one gate. the app points it at the everyday container's dev chat
final devGate = DevGate();

// ---- who the wire says is him ----

String _onionHost(String onion) {
  var s = onion.trim().toLowerCase();
  final scheme = s.indexOf('://');
  if (scheme >= 0) s = s.substring(scheme + 3);
  for (final cut in const ['/', ':']) {
    final i = s.indexOf(cut);
    if (i >= 0) s = s.substring(0, i);
  }
  return s.endsWith('.onion') ? s.substring(0, s.length - 6) : s;
}

DevKey? devKeyByOnion(String onion) {
  final h = _onionHost(onion);
  if (h.isEmpty) return null;
  for (final k in devKeys) {
    if (k.onion.isNotEmpty && _onionHost(k.onion) == h) return k;
  }
  return null;
}

// retired keys too: a claim of their words is as false as of the current
DevKey? devKeyByWords(String id) {
  final w = id.trim().toLowerCase();
  if (w.isEmpty) return null;
  for (final k in devKeys) {
    if (k.threeWords.toLowerCase() == w) return k;
  }
  return null;
}

// the key a bundle's identity is, when it is a pinned one
DevKey? devKeyByBundle(String bundle) {
  try {
    final j = jsonDecode(utf8.decode(base64Decode(bundle)));
    if (j is! Map) return null;
    final ik = j['identityKey'];
    if (ik is! String) return null;
    final b = base64Decode(ik);
    if (b.length != 33 || b[0] != 0x05) return null;
    return devKeyByXPub(
      [for (final x in b.skip(1)) x.toRadixString(16).padLeft(2, '0')].join(),
    );
  } catch (_) {
    return null;
  }
}

// an id only this phone's own code makes. sqlite's LIKE ignores case, so
// neither may the check
bool isDevId(String id) => id.trim().toLowerCase().startsWith('dev:');

// an id from the wire that would stand for the developer: a dev chat's
// id, his three words, or his xpub (a room member's id is its key)
bool devIdClaim(String id) =>
    isDevId(id) || devKeyByWords(id) != null || devKeyByXPub(id) != null;

// a card, member or sender from the wire naming him anywhere: its id, its
// x key or its first-contact address
bool devCardClaim({required String id, String? xPub, String? fc}) =>
    devIdClaim(id) ||
    (xPub != null && xPub.isNotEmpty && devKeyByXPub(xPub) != null) ||
    (fc != null && fc.isNotEmpty && devKeyByFc(fc) != null);

// what a pasted or scanned card is to the dev chat
enum DevCard {
  // names no pinned key and not his words: an ordinary card
  none,
  // his own key: the dev chat opens and nothing is added
  dev,
  // says it is him with another key
  mismatch,
  // an id only this phone makes
  refused,
}

// a v2 or v3 card carries a bundle, a v1 card an xpub
DevCard devCardOf({required String id, String? bundle, String? xPub}) {
  if (isDevId(id)) return DevCard.refused;
  final byWords = devKeyByWords(id);
  final byKey = xPub != null
      ? devKeyByXPub(xPub)
      : bundle != null
      ? devKeyByBundle(bundle)
      : null;
  if (byKey != null) {
    return byWords == null || byWords.keyId == byKey.keyId
        ? DevCard.dev
        : DevCard.mismatch;
  }
  return byWords == null ? DevCard.none : DevCard.mismatch;
}
