// SPDX-License-Identifier: GPL-3.0-or-later
// what receiving asks of signal and the engine, and what it holds

part of '../main.dart';

// the json stored for a shipped preview, or null when there is none or
// the sender is not someone accepted. only the url and a one-line title
// survive; anything else the sender put in the map is dropped here
String? shippedPreview(Map<String, String>? pv, {required bool accepted}) {
  if (pv == null || !accepted) return null;
  final url = pv['url'];
  final title = pv['title'];
  if (url == null || title == null || title.trim().isEmpty) return null;
  final clean = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  return jsonEncode({
    'url': url,
    'title': clean.length > 120 ? clean.substring(0, 120) : clean,
    'by': 'sender',
  });
}

/// what a notification says for a message with no text: what kind of
/// file it is, never the name a voice note or a camera clip was saved under
String notifMediaLine(String? fileName, String? mediaPath) {
  if (fileName == 'voice.wav') return l10n.appVoiceMessage;
  if (nameSaysVideo(fileName)) return l10n.chatVideo;
  return fileName ?? (mediaPath != null ? l10n.appPhoto : '');
}

// what receiving and reaching someone ask of signal, the engine and
// android, in one place so the paths through them can run on stand-ins
class AppIo {
  const AppIo();

  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) => signalDecrypt(peer, cipher, flagKeyChange: flagKeyChange);

  // as decrypt, but an open [keep] turns down throws ShelfFull and spends
  // no key: the same cipher opens again later
  Future<String?> decryptIf(
    String peer,
    String cipher,
    bool Function(String plain) keep, {
    bool flagKeyChange = false,
  }) => signalDecrypt(peer, cipher, flagKeyChange: flagKeyChange, keep: keep);

  // what a full shelf left on the relay for [xPub]: "mark", "free" or
  // "drop" (HaloNostrLetHeld)
  Future<String> letHeld(String xPub, String how) =>
      engine.nostrLetHeld(xPub, how);

  // "mark" for each of [xPubs] where anything is held: nothing restarts
  Future<String> markHeld(List<String> xPubs) => engine.nostrMarkHeld(xPubs);

  Future<List<String>> sessionAddresses() =>
      signalSession.sessionStore.allSessionAddresses();

  Future<void> dropSession(String peer) =>
      signalSession.sessionStore.deleteSession(SignalProtocolAddress(peer, 1));

  // a first message from someone with no session yet: opened under a
  // placeholder, the sender's claim checked against their key, and the
  // session moved to them. a name bound here to another key keeps it: the
  // sender then gets an id of their own (unboundIdOf). null when any of it
  // fails in a way that may pass later, FirstRefused when it never opens
  Future<({String haloId, String plain, UnwrappedMessage env})?>
  openFirstContact(String cipher) async {
    const tempPeer = '_pending_back_pair_';
    final tempAddr = SignalProtocolAddress(tempPeer, 1);
    try {
      // always start clean: a leftover temp session or parked identity from
      // a prior pairing would poison this prekey decrypt.
      await signalSession.sessionStore.deleteSession(tempAddr);
      await signalSession.identityStore.removePeerIdentity(tempAddr);
      final plain = await signalDecrypt(tempPeer, cipher);
      if (plain == null) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        firstFails.note('decrypt');
        return null;
      }
      final env = unwrapMessage(plain);
      final h = env.senderHaloId;
      final e = env.senderEdPub;
      if (h == null || e == null) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        dlog('back-pair: envelope missing identity fields');
        throw const FirstRefused('shape');
      }
      final derived = engine.idFromEdPub(e);
      if (derived != h) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        dlog('back-pair: HaloID mismatch');
        throw const FirstRefused('id');
      }
      // nobody starts a chat as the developer: his three words are only 33
      // bits and his keys are pinned. no session is kept under them
      if (devCardClaim(id: h, xPub: env.senderXPub)) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        dlog('back-pair: claims the developer, dropped');
        throw const FirstRefused('claim');
      }
      final record = await signalSession.sessionStore.loadSession(tempAddr);
      final key = record.sessionState.getRemoteIdentityKey()?.serialize();
      // the x key it gives for itself is the one its session runs on
      final x = env.senderXPub;
      if (key == null ||
          (x != null &&
              x.isNotEmpty &&
              !_eqBytes(_xIdentity(x.toLowerCase()) ?? const [], key))) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        dlog('back-pair: key mismatch');
        firstFails.note('key');
        return null;
      }
      // a key "this isn't them" blocked opens nothing, under any name
      final kx = _keyHex(key);
      if (await _receiving._keyBlockedHere(kx)) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        dlog('back-pair: dropped');
        // what the debug list says names no block the screen does not show
        throw FirstRefused(await live.keyBlocked(kx) ? 'blocked' : 'decrypt');
      }
      // a name stays with the key first seen for it
      var at = h;
      final bound = await _boundIdentity(
        h,
        ss: signalSession,
        row: live.getContact,
      );
      // unless the name came with a request, an introduction or a group,
      // nobody checked it and its chat was deleted: then it is free
      if (bound != null &&
          !_eqBytes(bound, key) &&
          _firstWouldPass(env) &&
          await appState._nameFree(h, await live.getContact(h))) {
        await appState.releaseName(h);
        dlog('back-pair: a deleted name let go');
      } else if ((bound != null && !_eqBytes(bound, key)) ||
          (bound == null && await _receiving._tombedArriving(h))) {
        // bound to another key, or let go by "this isn't them": the words
        // go to no one who writes first
        at = unboundIdOf(key);
        final held = await _boundIdentity(
          at,
          ss: signalSession,
          row: live.getContact,
        );
        if (held != null && !_eqBytes(held, key)) {
          await signalSession.sessionStore.deleteSession(tempAddr);
          firstFails.note('bound');
          return null;
        }
        dlog('back-pair: a name bound to another key, filed on its own');
      }
      // move session from temp to where it is filed
      await keepOpenedSession(SignalProtocolAddress(at, 1), record);
      await signalSession.sessionStore.deleteSession(tempAddr);
      return (haloId: at, plain: plain, env: env);
    } on FirstRefused {
      rethrow;
    } catch (e) {
      dlog('back-pair error: $e');
      firstFails.note('open');
      try {
        await signalSession.sessionStore.deleteSession(tempAddr);
      } catch (_) {
        // the next first contact clears the placeholder before it starts
      }
      return null;
    }
  }

  Future<bool> hasSession(String peer) => hasSessionWith(peer);

  Future<String> encrypt(String peer, String plain) =>
      signalEncrypt(peer, plain);

  void listen(String xPub, {bool fresh = false}) =>
      engine.nostrSubscribeBg(xPub, fresh: fresh);

  void unlisten(String xPub) => engine.nostrUnsubscribeBg(xPub);

  String edPub() => engine.myEdPubkey();

  String xPub() => engine.myXPubkey();

  Future<String> relaySend(String xPub, String cipher) =>
      engine.nostrSend(xPub, cipher);

  Future<String> onionSend(String onion, String cipher) =>
      engine.sendTo(onion, cipher);

  Future<String> firstContactSend(String xPub, String fc, String cipher) =>
      engine.sendFirstContact(xPub, fc, cipher);

  // [payload] names the chat here only: android gets the tag [on] keeps
  // for it
  Future<void> notify({
    required String title,
    required String body,
    required String payload,
    required HaloDb on,
    String? msgUid,
    int? burnAt,
  }) async {
    if (await quietNow()) return;
    final id = await showMessageNotification(
      title: title,
      body: body,
      chat: payload,
      tag: await on.notifTag(payload),
      msgUid: msgUid,
      burnAt: burnAt,
    );
    if (id == null || msgUid == null) return;
    try {
      await on.noteRing(id, payload, msgUid);
    } catch (e) {
      dlog('ring: not kept (${e.runtimeType})');
    }
  }

  // what this process showed for a chat leaves the shade
  Future<void> unnotify(String payload) => clearNotificationsFor(payload);

  // the same for a chat whose rows went, by the tags read before
  Future<void> unnotifyGone(String payload, Set<String> tags) =>
      clearNotificationsFor(payload, tags: tags);

  // one message's notification leaves the shade
  Future<void> unnotifyMessage(String msgUid) =>
      clearMessageNotification(msgUid);
}

// the engine's sealing for the router
class EngineSeal implements VaultSeal {
  const EngineSeal();

  // a failure is one arrival not kept, never the rest of the batch
  @override
  String? seal(String pub, String b64) {
    try {
      final r = engine.vaultSeal(pub, b64);
      return r.isEmpty || r.startsWith('error') ? null : r;
    } catch (e) {
      dlog('seal: $e');
      return null;
    }
  }

  // a call that fails as a whole throws, so no row goes unopened
  @override
  List<String?> openMany(String priv, List<String> b64s) =>
      engine.vaultOpenMany(priv, b64s);
}

// a message the stranger cap held, kept as it opened: signal has spent the
// keys for it, so it is let in from here once they are accepted. a held
// cipher from before this was kept as it came
const _kHeldWire = 'wire:';
String heldWire(String wire) => '$_kHeldWire$wire';
String? heldWireOf(String held) =>
    held.startsWith(_kHeldWire) ? held.substring(_kHeldWire.length) : null;

// what was opened and not filed yet, by its hash, the oldest going first
// past [max] chars
class _Kept<V> {
  _Kept(this.max, this.size);
  final int max;
  final int Function(V) size;
  final _m = <String, V>{};
  var _chars = 0;

  V? operator [](String k) => _m[k];

  V? take(String k) {
    final v = _m.remove(k);
    if (v != null) _chars -= size(v);
    return v;
  }

  void put(String k, V v) {
    take(k);
    _m[k] = v;
    _chars += size(v);
    while (_chars > max && _m.length > 1) {
      take(_m.keys.first);
    }
  }

  void clear() {
    _m.clear();
    _chars = 0;
  }
}

// a first contact signal opened, and how far its filing got: a try after
// one that failed goes on from there
class _FirstOpen {
  _FirstOpen(this.haloId, this.plain, this.env);
  String haloId;
  final String plain;
  final UnwrappedMessage env;
  // moved off a hidden chat's name already
  bool refiled = false;
  // whether its row was new on the first try
  bool? fresh;
  // who its address was heard as before it, once read
  bool heard = false;
  String? heardAs;
}

// a frame that came before the message it names, as it came
typedef _Early = ({
  String uid,
  HaloDb db,
  HaloDb? into,
  String sender,
  String wire,
  int? arrivedAt,
  int? wrappedAt,
  Reached? reached,
  int at,
});

// a stranger's cap held a message back, in the container it was going to
class _HeldIn extends CapHeld {
  const _HeldIn(this.into);
  final HaloDb into;
}

// a first contact without its proof of work: nothing of it is kept
class _NoProof implements Exception {
  const _NoProof();
}
