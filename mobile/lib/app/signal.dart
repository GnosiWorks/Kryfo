// SPDX-License-Identifier: GPL-3.0-or-later
// signal sessions and the keys they are bound to

part of '../main.dart';

Future<String> makePreKeyBundleB64([SignalSession? of]) async {
  final ss = of ?? signalSession;
  final spk = await ss.signedPreKeyStore.loadSignedPreKey(1);
  // the kept invite prekey, never the lowest one-time key: a handle's
  // published invite is static, and a one-time key is gone after the first
  // person uses it
  final pk = await ss.preKeyStore.loadPreKey(invitePreKeyId);
  final bundle = {
    'registrationId': ss.registrationId,
    'deviceId': 1,
    'preKeyId': pk.id,
    'preKeyPublic': base64Encode(pk.getKeyPair().publicKey.serialize()),
    'signedPreKeyId': spk.id,
    'signedPreKeyPublic': base64Encode(spk.getKeyPair().publicKey.serialize()),
    'signedPreKeySignature': base64Encode(spk.signature),
    'identityKey': base64Encode(ss.identityKeyPair.getPublicKey().serialize()),
  };
  return base64Encode(utf8.encode(jsonEncode(bundle)));
}

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
Future<SignalSession?> signalFor(String peer) async =>
    isDevId(peer) ? (await devLane.seat(peer))?.store : signalSession;

// a session with [haloId] built from their card, in [into] or the store
// signalFor names
Future<void> processPeerBundle(
  String haloId,
  String bundleB64, {
  SignalSession? into,
}) async {
  final ss = into ?? await signalFor(haloId);
  if (ss == null) throw StateError('no signal store for this chat');
  final preKeyBundle = preKeyBundleOf(bundleB64);
  final addr = SignalProtocolAddress(haloId, 1);
  final builder = SessionBuilder(
    ss.sessionStore,
    ss.preKeyStore,
    ss.signedPreKeyStore,
    ss.identityStore,
    addr,
  );
  await ss.serial(haloId, () => builder.processPreKeyBundle(preKeyBundle));
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
  return ss != null &&
      await ss.sessionStore.containsSession(SignalProtocolAddress(peerId, 1));
}

// the one place a frame is sealed for a peer. every frame for the dev chat
// goes through its own seal instead: the allowlist, its store, the token
// the wire asks for. either store seals one frame at a time per peer
Future<String> signalEncrypt(String peerId, String plaintext) async {
  if (isDevId(peerId)) return devLane.encrypt(peerId, plaintext);
  plaintext = await appState.shotsOnWire(peerId, plaintext);
  final from = _afreshFrom;
  return signalSession.encryptTo(
    peerId,
    plaintext,
    afresh: from == null ? null : () => from(peerId),
    // a read that fails seals nothing
    held: () => appState.keyHeld(peerId, strict: true),
    // a card naming another key: flagged as on an open, once out of the lane
    keyMoved: () => unawaited(_keyMoved?.call(peerId)),
  );
}

// where a seal finds a peer's card to start a session afresh from, after a
// restore: the app state's rows. set as it is made
Future<PreKeyBundle?> Function(String peer)? _afreshFrom;

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
    return w.isNotEmpty && w[0] == CiphertextMessage.prekeyType;
  } catch (_) {
    return false;
  }
}

// the identity a store holds for an address: the one it trusts, else the
// one its session was built with
Future<List<int>?> _storedIdentity(
  SignalSession ss,
  SignalProtocolAddress addr,
) async {
  final known = await ss.identityStore.getIdentity(addr);
  if (known != null) return known.serialize();
  if (!await ss.sessionStore.containsSession(addr)) return null;
  final record = await ss.sessionStore.loadSession(addr);
  return record.sessionState.getRemoteIdentityKey()?.serialize();
}

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
      final k = await _storedIdentity(ss, SignalProtocolAddress(id, 1));
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
// down throws ShelfFull, and the keys it took stay unspent
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
    final addr = SignalProtocolAddress(peerId, 1);
    final cipher = SessionCipher(
      ss.sessionStore,
      ss.preKeyStore,
      ss.signedPreKeyStore,
      ss.identityStore,
      addr,
    );
    // a prekey open checks and saves their key before its mac: what it
    // changed goes back unless the open goes through, and a new key is
    // flagged only once it has
    final guard =
        type == CiphertextMessage.prekeyType &&
        !isDevId(peerId) &&
        peerId != '_pending_back_pair_';
    var moved = false;
    // opens share the per-peer queue with seals: both step the same record
    final plain = await ss.serial<Uint8List?>(peerId, () async {
      if (!guard) {
        return _open(ss, cipher, peerId, type, body, check, flagKeyChange);
      }
      final before = await ss.marksOf(peerId);
      final was = await _sessionIdentity(ss, addr);
      try {
        final out = await _open(
          ss,
          cipher,
          peerId,
          type,
          body,
          check,
          flagKeyChange,
        );
        if (out == null) {
          await ss.restoreMarks(peerId, before);
        } else {
          moved = before.movedTo(await ss.marksOf(peerId));
        }
        return out;
      } catch (_) {
        // a session stored on the new key before a later step threw is
        // theirs: the key stays with it
        final now = await _sessionIdentity(ss, addr);
        if (now != null && (was == null || !_eqBytes(was, now))) {
          moved = before.movedTo(await ss.marksOf(peerId));
        } else {
          await ss.restoreMarks(peerId, before);
        }
        rethrow;
      }
    });
    if (moved) await _keyMoved?.call(peerId);
    if (plain == null) return null;
    final text = unpad(utf8.decode(plain));
    _zeroBytes(plain); // cleartext decoded out, wipe the raw buffer
    return text;
  } on ShelfFull {
    rethrow;
  } on DuplicateMessageException catch (_) {
    dlog('signalDecrypt: duplicate from $peerId, dropped');
    // store-and-forward re-delivers, so a duplicate is expected. the
    // original already decrypted.
    _noteOpenedBefore(wireB64);
    return null;
  } on UntrustedIdentityException catch (_) {
    // nothing opened, so nothing is flagged. the dev chat drops a key that
    // is not the pinned one here
    return null;
  } on InvalidKeyIdException catch (_) {
    // one-time prekey already used. with a session, an earlier copy set it
    // up and this is a duplicate; without one it cannot be read.
    final addr = SignalProtocolAddress(peerId, 1);
    if (await ss.sessionStore.containsSession(addr)) {
      return null;
    }
    return null;
  } catch (e) {
    dlog('signalDecrypt: $e');
    return null;
  }
}

// the identity the session held for [addr] was built with, null with none
Future<List<int>?> _sessionIdentity(
  SignalSession ss,
  SignalProtocolAddress addr,
) async {
  if (!await ss.sessionStore.containsSession(addr)) return null;
  final record = await ss.sessionStore.loadSession(addr);
  return record.sessionState.getRemoteIdentityKey()?.serialize();
}

// where a key that moved after an open is flagged: the app state, as it is
// made
Future<void> Function(String peer)? _keyMoved;

// one open in the peer's lane
Future<Uint8List?> _open(
  SignalSession ss,
  SessionCipher cipher,
  String peerId,
  int type,
  Uint8List body,
  void Function(Uint8List) check,
  bool flagKeyChange,
) async {
  final addr = SignalProtocolAddress(peerId, 1);
  if (type != CiphertextMessage.prekeyType) {
    return cipher.decryptFromSignalWithCallback(
      SignalMessage.fromSerialized(body),
      check,
    );
  }
  final pkm = PreKeySignalMessage(body);
  // trial decrypt: a prekey opens only under the name its identity is
  // bound to. another identity, or a name with none yet, arrives as a
  // first contact and is checked there. targeted decrypts
  // (flagKeyChange) skip this and keep deliver-and-warn for mitm.
  if (!flagKeyChange && peerId != '_pending_back_pair_') {
    final known = await _storedIdentity(ss, addr);
    if (known == null || !_eqBytes(known, pkm.getIdentityKey().serialize())) {
      return null;
    }
  }
  if (await ss.sessionStore.containsSession(addr)) {
    // session exists: use it. rebuilding from the prekey record bad-macs
    // when the slot was refilled with a fresh key.
    try {
      return await cipher.decryptFromSignalWithCallback(
        pkm.getWhisperMessage(),
        check,
      );
    } on ShelfFull {
      rethrow;
    } catch (e) {
      dlog('signalDecrypt: session path failed ($e), prekey fallback');
      return cipher.decryptWithCallback(pkm, check);
    }
  }
  final pkId = pkm.getPreKeyId();
  final havePk =
      !pkId.isPresent || await ss.preKeyStore.containsPreKey(pkId.value);
  if (!havePk) {
    dlog('signalDecrypt: prekey gone, no session for $peerId');
    return null;
  }
  return cipher.decryptWithCallback(pkm, check);
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

// an opener's session filed at [addr]. a record already there is kept: an
// opener it took before (a copy off a relay's backlog after a restore, or
// a second one sent before they heard back) leaves it as it runs, its text
// still handed on for the uid checks to know. a new one goes in front of it
// as a fresh start does, the states before it kept behind
Future<void> keepOpenedSession(
  SignalProtocolAddress addr,
  SessionRecord record,
) async {
  final store = signalSession.sessionStore;
  await signalSession.serial<void>(addr.getName(), () async {
    if (!await store.containsSession(addr)) {
      await store.storeSession(addr, record);
      return;
    }
    final held = await store.loadSession(addr);
    final st = record.sessionState;
    if (held.hasSessionState(st.getSessionVersion(), st.aliceBaseKey)) {
      dlog('back-pair: an opener held already, the session kept');
      return;
    }
    held.promoteState(st);
    await store.storeSession(addr, held);
  });
}

// a first contact's session moved off a name a hidden chat binds to
// another key, onto the sender's own id. a name with a trusted key was
// settled when it opened, and stays. null when it cannot be moved
Future<String?> _refileFirstContact(String h) async {
  final addr = SignalProtocolAddress(h, 1);
  try {
    if (await signalSession.identityStore.getIdentity(addr) != null) return h;
    final record = await signalSession.sessionStore.loadSession(addr);
    final key = record.sessionState.getRemoteIdentityKey()?.serialize();
    await signalSession.sessionStore.deleteSession(addr);
    if (key == null) return null;
    final at = unboundIdOf(key);
    final held = await _boundIdentity(
      at,
      ss: signalSession,
      row: live.getContact,
    );
    if (held != null && !_eqBytes(held, key)) return null;
    // kept as any opener's is: one held there already is not run over
    await keepOpenedSession(SignalProtocolAddress(at, 1), record);
    return at;
  } catch (e) {
    dlog('back-pair: not refiled ($e)');
    return null;
  }
}
