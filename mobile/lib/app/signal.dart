// SPDX-License-Identifier: GPL-3.0-or-later
// signal sessions and the keys they are bound to

part of '../main.dart';

// the card [of] hands out (the everyday store when null). it carries the
// kept invite prekeys, never the lowest one-time key: a handle's published
// invite is static, and a one-time key is gone after the first person uses
// it
Future<String> makePreKeyBundleB64([SignalSession? of]) =>
    (of ?? signalSession).makeBundleB64();

/// opens the everyday signal store. the first start after a restore marks
/// the sessions the file brought back as it opens, before anything can seal
/// on one, and the restore's pref goes once they are written down
Future<void> openSignalStore(
  SignalSession ss, {
  required Database database,
  required Uint8List xPubBytes,
  required Uint8List xPrivBytes,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final restored = prefs.getBool(kSessionsRestoredPref) == true;
  await ss.bootstrap(
    database: database,
    xPubBytes: xPubBytes,
    xPrivBytes: xPrivBytes,
    restored: restored,
    restoredFrom: prefs.getInt(kRestoredFromPref),
  );
  if (restored) {
    await prefs.remove(kSessionsRestoredPref);
    await prefs.remove(kRestoredFromPref);
  }
}

// the store a peer's messages go through: the everyday one, and for the
// dev chat the one it was started with. null for a dev chat that has none
// (not started, deleted, restored without its made name) and for any other
// id shaped like one: nothing falls back to the everyday store for it
// any other contact's is the store of the identity they know (door.dart)
Future<SignalSession?> signalFor(String peer) async => isDevId(peer)
    ? (await devLane.seat(peer))?.store
    : await signalOfIdent(identOfPeer(peer));

/// the x key [peer]'s store holds for them, on the identity they know
Future<String?> peerXPubOf(String peer) async =>
    (await signalFor(peer))?.peerXPubHex(peer);

// a session with [haloId] built from their card, in [into] or the store
// signalFor names
Future<void> processPeerBundle(
  String haloId,
  String bundleB64, {
  SignalSession? into,
}) async {
  final ss = into ?? await signalFor(haloId);
  if (ss == null) throw StateError('no signal store for this chat');
  await ss.processBundle(haloId, lsBundleOf(ss.lib, bundleB64));
}

// best-effort wipe of key or plaintext bytes from ram. dart strings are
// immutable and cannot be wiped, only lists.
void _zeroBytes(List<int> b) {
  for (var i = 0; i < b.length; i++) {
    b[i] = 0;
  }
}

// no session yet with this peer: the next message is an opener
Future<bool> hasSessionWith(String peerId) async {
  final ss = await signalFor(peerId);
  return ss != null && await ss.hasSession(peerId);
}

// the one place a frame is sealed for a peer: through the door, on the
// store of the identity they know. every frame for the dev chat goes
// through its own seal instead: the allowlist, its store, the token the
// wire asks for. either store seals one frame at a time per peer
// [onlySettled]: a frame that must never open a session (a typing frame)
Future<String> signalEncrypt(
  String peerId,
  String plaintext, {
  bool onlySettled = false,
}) async =>
    (await signalSeal(peerId, plaintext, onlySettled: onlySettled)).cipher;

/// as signalEncrypt, with the identity the door sealed on: every relay call
/// that carries the cipher takes this one, never a second lookup
Future<({int ident, String cipher})> signalSeal(
  String peerId,
  String plaintext, {
  bool onlySettled = false,
}) async {
  if (isDevId(peerId)) {
    if (onlySettled) throw NotSettled(peerId);
    return (
      ident: kMainIdent,
      cipher: await devLane.encrypt(peerId, plaintext),
    );
  }
  plaintext = await appState.shotsOnWire(peerId, plaintext);
  // a v4 first contact's frames carry the pair's seed until they answer
  plaintext = await appState.v4OpenerFields(peerId, plaintext);
  final (ident, framed) = await appState.doorFor(peerId, plaintext);
  final ss = await signalOfIdent(ident);
  final from = _afreshFrom;
  Future<String> seal(String frame, int? size) => ss.encryptTo(
    peerId,
    frame,
    onlySettled: onlySettled,
    afresh: from == null ? null : () => from(peerId),
    // a read that fails seals nothing
    held: () => appState.keyHeld(peerId, strict: true),
    // a card naming another key: flagged as on an open, once out of the lane
    keyMoved: () => unawaited(_keyMoved?.call(peerId)),
    size: size,
  );
  // linked devices: a copy to every device, the phone's back here. a typing
  // frame is the phone's alone
  if (linkedDevicesOn && !onlySettled) {
    final phone = await _deviceSeal(ident, ss, peerId, framed, (
      measure: (f) => ss.sealSize(peerId, f),
      seal: seal,
    ));
    if (phone != null) return (ident: ident, cipher: phone);
  }
  return (ident: ident, cipher: await seal(framed, null));
}

// where a seal finds a peer's card to start a session afresh from, after a
// restore: the app state's rows. set as it is made
Future<LsBundle?> Function(String peer)? _afreshFrom;

bool _eqBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _isPreKeyWire(String wireB64) {
  try {
    final w = base64Decode(wireB64);
    return w.isNotEmpty && w[0] == kLsPreKey;
  } catch (_) {
    return false;
  }
}

// the identity a store holds for an address: the one it trusts, else the
// one its session was built with
Future<List<int>?> _storedIdentity(SignalSession ss, String peer) async =>
    await ss.identityStore.getIdentity(peer) ?? await ss.sessionIdentity(peer);

// the identity key a card's prekey bundle carries, null when it does not
// read
List<int>? _bundleIdentity(String bundleB64) {
  try {
    final j = jsonDecode(utf8.decode(base64Decode(bundleB64))) as Map;
    return base64Decode(j['identityKey'] as String);
  } catch (_) {
    return null;
  }
}

// an x key as signal writes it, null when it is not one
List<int>? _xIdentity(String xHex) {
  if (xHex.length != 64) return null;
  final out = <int>[0x05];
  for (var i = 0; i < 64; i += 2) {
    final b = int.tryParse(xHex.substring(i, i + 2), radix: 16);
    if (b == null) return null;
    out.add(b);
  }
  return out;
}

// the key a row holds for someone. a key that does not read still binds
// the row: it matches nothing
List<int>? _rowIdentity(Map<String, Object?>? row) {
  if (row == null) return null;
  final x = row['xpub'] as String?;
  if (x != null && x.isNotEmpty) {
    return _xIdentity(x.toLowerCase()) ?? utf8.encode('x $x');
  }
  final bundle = row['peer_bundle'] as String?;
  if (bundle != null && bundle.isNotEmpty) {
    return _bundleIdentity(bundle) ?? utf8.encode('b $bundle');
  }
  return null;
}

// the identity a name is bound to here: the key it was first seen with,
// from the signal store [ss] and then from the row [row] reads. null for a
// name with no key yet
Future<List<int>?> _boundIdentity(
  String id, {
  SignalSession? ss,
  Future<Map<String, Object?>?> Function(String id)? row,
}) async {
  if (ss != null) {
    try {
      final k = await _storedIdentity(ss, id);
      if (k != null) return k;
    } catch (e) {
      dlog('bound identity: store not read ($e)');
    }
  }
  return row == null ? null : _rowIdentity(await row(id));
}

/// whether [h], from the wire, has the shape of an id that stands for
/// someone: three words, or the id of one filed on their own key
/// ([unboundIdOf]). in a room, a room key
bool wireIdShaped(String h, {required bool room}) => room
    ? _roomKeyShape.hasMatch(h)
    : _wordsShape.hasMatch(h) || _ownIdShape.hasMatch(h);

final _wordsShape = RegExp(r'^[a-z]{1,16}-[a-z]{1,16}-[a-z]{1,16}$');
final _ownIdShape = RegExp(r'^[0-9a-f]{16}$');
final _roomKeyShape = RegExp(r'^[0-9a-f]{1,64}$');

/// where someone lands who writes under a name bound here to another key:
/// an id of their own, from their key, that is never three words
String unboundIdOf(List<int> identityKey) =>
    sha256.convert(identityKey).toString().substring(0, 16);

// [keep] sees what it opened to before signal stores anything: one it turns
// down throws ShelfFull, and the keys it took stay unspent. nothing about
// the peer is written before the message has opened
Future<String?> signalDecrypt(
  String peerId,
  String wireB64, {
  bool flagKeyChange = false,
  bool Function(String plain)? keep,
}) async {
  final ss = await signalFor(peerId);
  if (ss == null) return null;
  void check(Uint8List p) {
    if (keep != null && !keep(unpad(utf8.decode(p)))) throw const ShelfFull();
  }

  try {
    final wire = base64Decode(wireB64);
    if (wire.isEmpty) return null;
    final type = wire[0];
    final body = Uint8List.fromList(wire.sublist(1));
    var moved = false;
    Uint8List? remote, record;
    final Uint8List? plain;
    try {
      plain = await _open(
        ss,
        peerId,
        type,
        body,
        check,
        flagKeyChange,
        () => moved = true,
        (r, rec) => (remote, record) = (r, rec),
      );
    } finally {
      // a new key is saved only with a session that opened on it: flagged
      // then, even when a later step threw
      if (moved && !isDevId(peerId) && peerId != '_pending_back_pair_') {
        await _keyMoved?.call(peerId);
      }
    }
    if (plain == null) return null;
    final (r, rec) = (remote, record);
    if (r != null && rec != null && linkedDevicesOn) {
      await _devOpened(ss, peerId, r, rec);
    }
    final text = unpad(utf8.decode(plain));
    _zeroBytes(plain); // cleartext decoded out, wipe the raw buffer
    return text;
  } on ShelfFull {
    rethrow;
  } on LsError catch (e) {
    switch (e.code) {
      case LsError.duplicate:
        dlog('signalDecrypt: duplicate from $peerId, dropped');
        // store-and-forward re-delivers, so a duplicate is expected. the
        // original already decrypted.
        _noteOpenedBefore(wireB64);
      case LsError.untrusted:
        // nothing opened, so nothing is flagged. the dev chat drops a key
        // that is not the pinned one here
        break;
      case LsError.noPreKey:
        // a one-time prekey already used: an earlier copy set the session
        // up and this is a duplicate, or without one it cannot be read
        dlog('signalDecrypt: prekey gone for $peerId');
      case LsError.classic:
        // a pre-pq opener for a session not held: their app is too old
        dlog('signalDecrypt: a classic opener from $peerId, refused');
      default:
        dlog('signalDecrypt: $e');
    }
    return null;
  } catch (e) {
    dlog('signalDecrypt: $e');
    return null;
  }
}

// where a key that moved after an open is flagged: the app state, as it is
// made
Future<void> Function(String peer)? _keyMoved;

// one open in the peer's lane
Future<Uint8List?> _open(
  SignalSession ss,
  String peerId,
  int type,
  Uint8List body,
  void Function(Uint8List) check,
  bool flagKeyChange,
  void Function() moved,
  void Function(Uint8List remote, Uint8List record) opened,
) async {
  if (type == kLsPreKey) {
    // trial decrypt: a prekey opens only under the name its identity is
    // bound to. another identity, or a name with none yet, arrives as a
    // first contact and is checked there. targeted decrypts
    // (flagKeyChange) skip this and keep deliver-and-warn for mitm.
    if (!flagKeyChange && peerId != '_pending_back_pair_') {
      final known = await _storedIdentity(ss, peerId);
      final theirs = ss.lib.preKeyMessageInfo(body).identityKey;
      if (known == null || !_eqBytes(known, theirs)) return null;
    }
  } else if (type != kLsWhisper) {
    return null;
  }
  // an opener on a session held opens on it; a new one builds the session
  // in front of it, the states before it kept behind
  return ss.open(
    peerId,
    type,
    body,
    check: check,
    moved: moved,
    opened: opened,
  );
}

/// a message from [peer]'s phone opened on a session whose remote was
/// [remote], as ks_decrypt_* returned it: the engine admits it and notes a
/// post-quantum session for good. never stops the message
Future<void> _devOpened(
  SignalSession ss,
  String peer,
  Uint8List remote,
  Uint8List record,
) async {
  final ds = _deviceState;
  if (ds == null || isDevId(peer)) return;
  try {
    final db = await live.open();
    final row = await db.query(
      'contacts',
      columns: ['ident', 'ikey'],
      where: 'halo_id = ?',
      whereArgs: [peer],
      limit: 1,
    );
    final ikey = row.isEmpty ? null : row.first['ikey'] as String?;
    if (ikey == null) return;
    final info = ss.lib.sessionInfo(record);
    final ident = row.first['ident'] as int? ?? kMainIdent;
    await ds.session(db, 'opened', {
      'ident': ident,
      'identity': ikey,
      'device': 1,
      'pq': info.version >= 4 && info.pq,
    }, SessionRemote.opened(remote));
    // they answered: a list that went to them before is taken
    await _deviceSend?.heard(
      ident,
      ikey,
      DateTime.now().millisecondsSinceEpoch,
    );
  } on DevRefused catch (e) {
    dlog('devices: an open not admitted (${e.why})');
  } catch (e) {
    dlog('devices: an open not noted (${e.runtimeType})');
  }
}

// wires a decrypt found opened before: a copy is no sign the sessions went
// apart, and nobody is asked to start afresh over one
final _openedBefore = <String>{};

void _noteOpenedBefore(String wireB64) {
  _openedBefore.add(sha256.convert(utf8.encode(wireB64)).toString());
  while (_openedBefore.length > 64) {
    _openedBefore.remove(_openedBefore.first);
  }
}

bool _takeOpenedBefore(String wireB64) =>
    _openedBefore.remove(sha256.convert(utf8.encode(wireB64)).toString());

// an opener's session filed for [peer]. a record already there is kept: an
// opener it took before (a copy off a relay's backlog after a restore, or
// a second one sent before they heard back) leaves it as it runs, its text
// still handed on for the uid checks to know. a new one goes in front of it
// as a fresh start does, the states before it kept behind
Future<void> keepOpenedSession(
  String peer,
  Uint8List record, {
  Future<void> Function(Transaction t)? also,
}) => signalSession.keepOpenedSession(peer, record, also: also);

// a first contact's session moved off a name a hidden chat binds to
// another key, onto the sender's own id. a name with a trusted key was
// settled when it opened, and stays. null when it cannot be moved
Future<String?> _refileFirstContact(String h) async {
  try {
    if (await signalSession.identityStore.getIdentity(h) != null) return h;
    final record = await signalSession.sessionStore.load(h);
    if (record == null) return null;
    final key = signalSession.lib.sessionInfo(record).remoteIdentity;
    await signalSession.sessionStore.delete(h);
    if (key == null) return null;
    final at = unboundIdOf(key);
    final held = await _boundIdentity(
      at,
      ss: signalSession,
      row: live.getContact,
    );
    if (held != null && !_eqBytes(held, key)) return null;
    // kept as any opener's is: one held there already is not run over
    await keepOpenedSession(at, record);
    return at;
  } catch (e) {
    dlog('back-pair: not refiled ($e)');
    return null;
  }
}
