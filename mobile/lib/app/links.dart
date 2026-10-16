// SPDX-License-Identifier: GPL-3.0-or-later
// invite links, and how someone was added

part of '../main.dart';

Future<String> handleHaloUri(String raw, {bool scanned = false}) async =>
    (await handleHaloUriAdded(raw, scanned: scanned)).$1;

/// asked when a link names someone here under a name a request, an
/// introduction or a group gave, never checked, or a deleted chat's, on
/// another key: true lets the link take the name. [chat] says the other one
/// has a chat that goes, [deleted] that its chat was deleted, [tombed] that
/// "this isn't them" let the words go
@visibleForTesting
Future<bool> Function(
  String id, {
  required bool chat,
  bool deleted,
  bool tombed,
})
askTakeName = askTakeNameSheet;

/// what a link may do about the one here its name is bound to on another
/// key
enum NameHold {
  // a verified, blocked or checked name stays theirs
  kept,
  // given by a request, an introduction or a group and never checked, or
  // a deleted chat's when the person adds someone themself: the link takes
  // it if the person says so
  ask,
  // given by a request, an introduction or a group, with its chat deleted:
  // nothing here holds it any more
  free,
}

/// [seated]: they are in a group or a room here. whoever took the words
/// would take that seat as well, so the name stays. [asked]: an add the
/// person makes (a link, a scan, a code, a handle), never something that
/// came to this phone by itself
NameHold nameHoldOf(
  Map<String, Object?>? row, {
  bool seated = false,
  bool asked = false,
}) {
  if (row == null ||
      seated ||
      (row['blocked'] as num?)?.toInt() == 1 ||
      (row['verified'] as num?)?.toInt() == 1 ||
      isDevId(row['halo_id'] as String? ?? '')) {
    return NameHold.kept;
  }
  final parked =
      (row['accepted'] as num?)?.toInt() != 1 &&
      (row['archived'] as num?)?.toInt() == 1;
  if (nameUnchecked(row)) return parked ? NameHold.free : NameHold.ask;
  // added by hand and deleted: only the person can hand the words on
  return parked && asked ? NameHold.ask : NameHold.kept;
}

// an add from a camera scan clears the marks. any other add asks for the
// safety number in their chat; a re-add leaves what was there, and a name
// taken over starts afresh
Future<void> _noteHowAdded(
  String id, {
  required bool scanned,
  required bool already,
  required bool taken,
  bool untombed = false,
}) async {
  try {
    final was = nameCheckOf(await session.getContact(id));
    // words "this isn't them" let go: their chat asks for the number,
    // however the add was made
    final now = untombed
        ? kNameAsk
        : scanned
        ? 0
        : taken
        ? kNameAsk
        : already
        ? was
        : was | kNameAsk;
    if (now != was) await session.setNameCheck(id, now);
  } catch (e) {
    dlog('name check: not kept (${e.runtimeType})');
  }
}

// the result line, and whether the link left the person in the contacts
// (added now, or already there). a caller that acts on that asks this; the
// line is in the app's language and is not compared with anything, and
// empty when a chat opening is the answer.
// [hidden] says who a shut vault holds, the app's state when not given.
// [scanned]: read with the camera, as people add each other side by side.
// it clears the marks, and proves only as much as the screen it was read off
Future<(String, bool)> handleHaloUriAdded(
  String raw, {
  bool Function(String id)? hidden,
  bool Function(String keyHex)? shutKeys,
  bool scanned = false,
  @visibleForTesting AppState? app,
}) async {
  // the one app on a phone; a test hands in the one it built
  final appState = app ?? _app;
  // @wren or the handle page link: ask the registry for the invite behind it
  // and carry on as if that had been pasted
  final h = handleFromInput(raw);
  // a handle's card is the registry's, and a real one: one that will not
  // take says so as a lookup that failed, which any lookup can
  final viaHandle = h != null;
  if (h != null) {
    // a quiet session never reaches the registry
    if (sessionQuiet) return (l10n.handleRegistryFailed, false);
    // tor not up: nothing goes to the registry, nor another way
    if (!appState.servicesReady) return (l10n.handleSearchNeedsTor, false);
    // the invite has to be the claimer's own: its id is the words of the
    // key the handle was claimed with
    final r = await resolveHandle(
      h,
      _torGetJsonOnIsolate,
      idOf: engine.idFromEdPub,
    );
    // the lookup answers in fixed english words; the person reads their own
    if (r.startsWith('error:')) {
      return (
        r.contains('nobody has claimed')
            ? l10n.handleNobodyHasClaimed('@$h')
            : r.contains('not a handle')
            ? l10n.appInvalidUri
            : l10n.handleRegistryFailed,
        false,
      );
    }
    raw = r;
  }
  // the link, out of whatever was pasted around it
  raw = firstKryfoLink(raw) ?? raw;
  final room = RoomLink.parse(raw);
  if (room != null) {
    final r = await appState.joinRoom(room);
    // a join opens the room, waiting to be let in, and says nothing: the
    // room is the answer
    if (r.isEmpty || r == l10n.appYouAreAlreadyIn) openRoomSoon(room.roomId);
    return (r, false);
  }
  final parsed = parseHaloUri(raw);
  if (parsed == null) return (l10n.appInvalidUri, false);
  // one's own invite adds no one: a row and a session with oneself would
  // only put oneself in the chat list
  if (parsed['id'] == appState.sessionId) return (l10n.appYourOwnInvite, false);
  // a card naming the developer is taken on his keys alone: his own opens
  // his chat and adds nothing, one with his words and another key is
  // refused, and a dev chat id is never a card's
  switch (devCardOf(
    id: parsed['id']!,
    bundle: parsed['bundle'],
    xPub: parsed['xpub'],
  )) {
    case DevCard.none:
      break;
    case DevCard.refused:
      return (l10n.appInvalidUri, false);
    case DevCard.mismatch:
      return (l10n.devLinkMismatch, false);
    case DevCard.dev:
      String? chat;
      try {
        final row = await session.devChat.load();
        // a deleted chat comes back only from its settings row
        if (row?.state == DevState.gone) return (l10n.devLinkGone, false);
        chat = row?.chatId;
      } catch (e) {
        dlog('dev link: $e');
      }
      chat ??= currentDevKey?.chatId;
      if (chat == null) return (l10n.appInvalidUri, false);
      openDevChatLater(chat);
      // nothing to say: the chat opening is the answer
      return ('', true);
  }
  // a name stays with the key first seen for it: a card that names someone
  // here with another key changes nothing, and a card has to carry a key
  // that reads to be checked at all
  final cardKey = parsed['bundle'] != null
      ? _bundleIdentity(parsed['bundle']!)
      : _xIdentity(parsed['xpub']!.toLowerCase());
  if (cardKey == null) return (l10n.appInvalidUri, false);
  // a key "this isn't them" blocked here takes no link, whatever words it
  // gives, and says so before anything a shut vault holds is asked
  if (await session.keyBlocked(_keyHex(cardKey))) {
    return (l10n.appKeyBlocked, false);
  }
  // the signal store holds a shut vault's people too: a link of one of
  // theirs reads as any link that does not take, on their key or another.
  // an add would put an everyday row beside the hidden one and a fresh
  // session over theirs. a vault closing hands its people over first. a
  // decoy only keeps rows of its own
  if (!sessionQuiet) {
    await appState._afterClose();
    // a key the shut vault blocked reads as such a link too: the everyday
    // side says nothing of the vault
    if ((hidden ?? appState.hiddenWhileShut)(parsed['id']!) ||
        (shutKeys ?? appState.keyBlockedWhileShut)(_keyHex(cardKey))) {
      return (
        viaHandle ? l10n.handleRegistryFailed : l10n.appInvalidUri,
        false,
      );
    }
  }
  final bound = await _boundIdentity(
    parsed['id']!,
    ss: sessionQuiet ? null : signalSession,
    row: session.getContact,
  );
  // a name a request, an introduction or a group gave, never checked, is
  // no reason to turn the link away: the person keeps the one they choose.
  // a verified one, or one they checked, stays
  var taken = false;
  var untombed = false;
  if (bound != null && !_eqBytes(bound, cardKey)) {
    final id = parsed['id']!;
    (String, bool) refused(Map<String, Object?>? row) => (
      (row?['verified'] as num?)?.toInt() == 1
          ? l10n.appLinkWordsVerified(id)
          : l10n.appLinkWordsTaken(id),
      false,
    );
    final row = await session.getContact(id);
    final hold = await appState._nameHold(id, row);
    if (hold == NameHold.kept) return refused(row);
    // the card has to be one a session can be built on before anything
    // here is let go for it
    final bundle = parsed['bundle'];
    if (bundle != null) {
      final bad = bundleFault(bundle);
      if (bad != null) return (l10n.appBundleError(bad), false);
    }
    if (hold == NameHold.ask &&
        !await askTakeName(
          id,
          chat: (row?['accepted'] as num?)?.toInt() == 1,
          deleted:
              (row?['accepted'] as num?)?.toInt() != 1 &&
              (row?['archived'] as num?)?.toInt() == 1,
        )) {
      return ('', false);
    }
    // the question can stay up a while: what holds the name is read again
    final now = await _boundIdentity(
      id,
      ss: sessionQuiet ? null : signalSession,
      row: session.getContact,
    );
    if (now != null && !_eqBytes(now, cardKey)) {
      final row2 = await session.getContact(id);
      final hold2 = await appState._nameHold(id, row2);
      if (hold2 == NameHold.kept || (hold2 == NameHold.ask && hold != hold2)) {
        return refused(row2);
      }
      await appState.releaseName(id);
      taken = true;
    }
  } else if (bound == null && await appState._tombed(parsed['id']!)) {
    // words "this isn't them" let go: this add, the person's own, takes
    // them once asked, and only once the contact is written
    if (!await askTakeName(parsed['id']!, chat: false, tombed: true)) {
      return ('', false);
    }
    taken = untombed = true;
  }
  // someone blocked stays blocked: an add would say they can be written to
  // while nothing of theirs is kept. the blocked list lets them back
  if (await session.isBlocked(parsed['id']!)) {
    return (l10n.appTheyAreBlocked(parsed['id']!), false);
  }
  if (parsed['v'] == '2' || parsed['v'] == '3') {
    final id = parsed['id']!;
    // saved means accepted. a group member known by key, a request or one
    // let go has a row too, and this add is what takes them in
    final already = await session.isAccepted(id);
    final asked = !already && await session.askedBefore(id);
    // a quiet session keeps the contact on this phone and nothing more: the
    // session with them would live in the everyday identity's store
    if (!sessionQuiet) {
      try {
        await processPeerBundle(parsed['id']!, parsed['bundle']!);
      } catch (e) {
        return (l10n.appBundleError(e), false);
      }
    }
    await session.upsertContact(
      parsed['id']!,
      parsed['onion']!,
      '',
      owe: asked,
    );
    await session.setPeerBundle(parsed['id']!, parsed['bundle']!);
    if (untombed) await appState._untomb(id);
    await appState._untombShut(id);
    await _noteHowAdded(
      id,
      scanned: scanned,
      already: already,
      taken: taken,
      untombed: untombed,
    );
    // nothing reaches them until a first message does: their chat opens,
    // and says so while it is empty
    if (sessionQuiet) {
      await appState.refreshContacts();
      openAddedChatLater(id);
      return (already ? l10n.appAlreadySaved(id) : '', true);
    }
    final fc = parsed['fc'];
    dlog(
      fc == null || fc.isEmpty
          ? 'pair: v${parsed['v']} invite, no first-contact addr'
          : 'pair: v${parsed['v']} invite carries first-contact addr',
    );
    if (fc != null && fc.isNotEmpty) {
      await appState.rememberPeerFc(parsed['id']!, fc);
    }
    await appState.subscribePeer(parsed['id']!, fresh: true);
    // as the accept button would: they hear they are in, and what was
    // held for them opens
    if (asked) await appState.afterAccept(id);
    // home, the pickers and the introductions show them now
    await appState.refreshContacts();
    // asked once, as they are taken in: a re-add asks nothing. the
    // question is the answer then, and their chat stays where it is
    if (!already && await appState.inboxChatOf(id)) {
      askInboxMove(id);
    } else {
      openAddedChatLater(id);
    }
    return (already ? l10n.appAlreadySaved(id) : '', true);
  } else {
    final id = parsed['id']!;
    // an old card is an add all the same, and takes in who asked
    final wasIn = await session.isAccepted(id);
    final asked = !wasIn && await session.askedBefore(id);
    await session.upsertContact(
      id,
      parsed['onion']!,
      parsed['xpub']!,
      owe: asked,
    );
    if (untombed) await appState._untomb(id);
    await appState._untombShut(id);
    await _noteHowAdded(
      id,
      scanned: scanned,
      already: wasIn,
      taken: taken,
      untombed: untombed,
    );
    if (!sessionQuiet) await appState.subscribePeer(id, fresh: true);
    if (asked && !sessionQuiet) await appState.afterAccept(id);
    // home and the pickers show them now, and their chat opens as a v2
    // add's does
    await appState.refreshContacts();
    if (!wasIn && await appState.inboxChatOf(id)) {
      askInboxMove(id);
    } else {
      openAddedChatLater(id);
    }
    return (wasIn ? l10n.appAlreadySaved(id) : '', true);
  }
}

String buildHaloUri(String id, String onion, String xpub) {
  return 'kryfo://share?id=$id&onion=$onion&xpub=$xpub';
}

Future<String> buildHaloUriV2(String id, String onion) async {
  final bundle = await makePreKeyBundleB64();
  return 'kryfo://share?id=$id&onion=$onion&v=2&bundle=$bundle';
}

// v3 carries a first-contact address alongside the bundle, so a one-way scan
// still works when our onion will not publish
Future<String> buildHaloUriV3(String id, String onion, int fcCounter) async {
  final bundle = await makePreKeyBundleB64();
  final fc = engine.firstContactPk(fcCounter);
  if (fc.isEmpty || fc.startsWith('error')) {
    return buildHaloUriV2(id, onion);
  }
  return haloUriV3(id, onion, bundle, fc);
}

String haloUriV3(String id, String onion, String bundle, String fc) =>
    'kryfo://share?id=$id&onion=$onion&v=3&bundle=$bundle&fc=$fc';

/// the decoy's invite. its bundle is encoded for the query, so no byte of
/// it can read as something else; an fc that did not come is left out
String quietInviteUri(String id, String onion, String bundle, String fc) {
  final b = Uri.encodeQueryComponent(bundle);
  return fc.startsWith('error')
      ? 'kryfo://share?id=$id&onion=$onion&v=2&bundle=$b'
      : 'kryfo://share?id=$id&onion=$onion&v=3&bundle=$b&fc=$fc';
}

// an invite's id is three words, as every version has made them: anything
// else would be shown to the person as if it were someone's name
Map<String, String>? parseHaloUri(String raw) {
  raw = raw.trim();
  if (!raw.startsWith('kryfo://share')) return null;
  // one link, each part once: a second copy of a part would be read in one
  // place and not in another
  if (raw.contains(RegExp(r'\s'))) return null;
  try {
    final uri = Uri.parse(raw);
    if (uri.queryParametersAll.values.any((v) => v.length > 1)) return null;
    final id = uri.queryParameters['id'];
    final onion = uri.queryParameters['onion'];
    if (id == null || onion == null) return null;
    if (!_wordsShape.hasMatch(id)) return null;
    final v = uri.queryParameters['v'] ?? '1';
    if (v == '3') {
      final bundle = uri.queryParameters['bundle'];
      if (bundle == null) return null;
      final out = {'id': id, 'onion': onion, 'bundle': bundle, 'v': '3'};
      final fc = uri.queryParameters['fc'];
      // an old build reading a v3 link still pairs, it just falls back to
      // onion-only first contact.
      if (fc != null && fc.length == 64) out['fc'] = fc;
      return out;
    }
    if (v == '2') {
      final bundle = uri.queryParameters['bundle'];
      if (bundle == null) return null;
      return {'id': id, 'onion': onion, 'bundle': bundle, 'v': '2'};
    }
    final xpub = uri.queryParameters['xpub'];
    if (xpub == null) return null;
    return {'id': id, 'onion': onion, 'xpub': xpub, 'v': '1'};
  } catch (_) {
    return null;
  }
}

/// the identity key a session built from [invite] runs on: the one its
/// bundle carries, as processPeerBundle reads it, or an old card's x key.
/// null when the invite does not read
List<int>? inviteSessionKey(String invite) {
  final parsed = parseHaloUri(invite);
  if (parsed == null) return null;
  final bundle = parsed['bundle'];
  if (bundle == null) return _xIdentity((parsed['xpub'] ?? '').toLowerCase());
  try {
    return preKeyBundleOf(bundle).getIdentityKey().serialize();
  } catch (_) {
    return null;
  }
}

/// the key number of [invite]: what the phone that shared it shows
String? inviteKeyNumber(String invite) {
  final k = inviteSessionKey(invite);
  return k == null ? null : keyNumber(k);
}

// an opener the proof-of-work gate and the stranger cap will take, read
// before a deleted chat's words are let go for it. once let go nothing of
// the old one is left, so the cap counts from none and no vouch spares it
// the proof
bool _firstWouldPass(UnwrappedMessage env) =>
    firstPowHolds(env) &&
    !strangerCapHolds(accepted: false, vouched: false, have: 0, cap: 2);

/// a first contact's proof of work: the one check the gate and a deleted
/// chat's words both ask of an opener
bool firstPowHolds(UnwrappedMessage env) =>
    env.powNonce != null &&
    verifyPow(env.powText ?? env.message, env.powNonce!, powBits);

/// what is wrong with a card's prekey bundle, null when a session can be
/// built on it: it reads, and its signed prekey is signed by its identity
Object? bundleFault(String bundleB64) {
  try {
    final b = preKeyBundleOf(bundleB64);
    final spk = b.getSignedPreKey();
    final sig = b.getSignedPreKeySignature();
    if (spk == null ||
        sig == null ||
        !Curve.verifySignature(
          b.getIdentityKey().publicKey,
          spk.serialize(),
          sig,
        )) {
      return const FormatException('signed prekey');
    }
    return null;
  } catch (e) {
    return e;
  }
}

/// what an invite's id is to the people here
enum LinkKin {
  // no one here goes by it
  stranger,
  // a contact on the same key: an add would add no one
  kept,
  // someone here by these words on another key, checked: the link does
  // not take their place
  otherKey,
  // the same, and verified
  verified,
  // someone here by these words on another key that a request, an
  // introduction or a group gave and nobody checked: the person chooses
  claimed,
  // a contact under other words that the person calls by these
  lookalike,
}

/// what [link]'s id is to the people here, and the name the person knows
/// them by. one that cannot be looked up is asked about as a stranger, and
/// the door still checks it. [hidden] says who a shut vault holds, the
/// app's state when not given
Future<(LinkKin, String)> linkKinOf(
  String link, {
  bool Function(String id)? hidden,
  @visibleForTesting AppState? app,
}) async {
  final appState = app ?? _app;
  final parsed = parseHaloUri(link);
  if (parsed == null) return (LinkKin.stranger, '');
  final id = parsed['id']!;
  try {
    // someone a shut vault holds is asked about as anyone else: the signal
    // store, which knows their key, is the vault's as well. a decoy asks
    // about its own rows alone
    if (!sessionQuiet) {
      await appState._afterClose();
      if ((hidden ?? appState.hiddenWhileShut)(id)) {
        return (LinkKin.stranger, id);
      }
    }
    return await _linkKin(parsed, id, appState);
  } catch (e) {
    dlog('link kin: ${e.runtimeType}');
    return (LinkKin.stranger, id);
  }
}

Future<(LinkKin, String)> _linkKin(
  Map<String, String> parsed,
  String id,
  AppState appState,
) async {
  final cardKey = parsed['bundle'] != null
      ? _bundleIdentity(parsed['bundle']!)
      : _xIdentity((parsed['xpub'] ?? '').toLowerCase());
  final row = await session.getContact(id);
  final bound = await _boundIdentity(
    id,
    ss: sessionQuiet ? null : signalSession,
    row: session.getContact,
  );
  final nick = (row?['nickname'] as String?)?.trim();
  final name = nick == null || nick.isEmpty ? id : nick;
  if (bound != null && (cardKey == null || !_eqBytes(bound, cardKey))) {
    return switch (cardKey == null
        ? NameHold.kept
        : await appState._nameHold(id, row)) {
      NameHold.kept =>
        (row?['verified'] as num?)?.toInt() == 1
            ? (LinkKin.verified, name)
            : (LinkKin.otherKey, name),
      NameHold.ask => (LinkKin.claimed, name),
      // their chat was deleted: nobody here goes by it
      NameHold.free => (LinkKin.stranger, id),
    };
  }
  // words "this isn't them" let go: the door asks before it takes them
  if (bound == null && await appState._tombed(id)) {
    return (LinkKin.claimed, id);
  }
  if (row != null && row['accepted'] == 1 && row['blocked'] != 1) {
    return (LinkKin.kept, name);
  }
  for (final c in await session.contacts()) {
    if (c['halo_id'] == id) continue;
    if ((c['nickname'] as String?)?.trim() == id) {
      return (LinkKin.lookalike, id);
    }
  }
  return (LinkKin.stranger, id);
}
