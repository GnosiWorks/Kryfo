// SPDX-License-Identifier: GPL-3.0-or-later
// the open session, as the screens and AppState reach it. they never name a
// database, so which container holds a chat is decided in this one place.
// with no vault every call is the primary's. with one, a chat's calls go to
// the container that holds it, the lists are read from both and merged, and
// a new chat always starts in the primary: hiding is always a move of its own

import 'dart:io';

import 'container.dart';
import 'devchat/dev_chat.dart' show DevChat;
import 'devchat/dev_key.dart' show isDevChat;
import 'devchat/support.dart' show SupportChats;
import 'dlog.dart';
import 'main.dart' show HaloDb, kFrameReaction, kFrameUnsend;
import 'media_send.dart' show cancelMediaSend, mediaInflight;
import 'polls.dart' show PollSpec, PollVote;
import 'scam_prefs.dart' show loadScamShieldOn;
import 'search.dart' show SearchKind;

class Session {
  Session(this.primary) : vault = null, _people = const {}, _groups = const {};

  Session._(this.primary, this.vault, this._people, this._groups);

  // which chats are the vault's is read once, here, from its own rows, so
  // nothing on the everyday side has to say
  static Future<Session> withVault(HaloDb primary, HaloDb vault) async {
    final held = await vault.heldChats();
    // someone the vault holds only as a key, a hidden group's member, keeps
    // their own chat where the primary holds them too
    final keysOnly = held.people.entries.any((e) => !e.value);
    final there = keysOnly
        ? (await primary.heldChats()).people.keys.toSet()
        : const <String>{};
    // the developer chat is never the vault's, whatever its rows say
    return Session._(primary, vault, {
      for (final e in held.people.entries)
        if (!isDevChat(e.key) && (e.value || !there.contains(e.key))) e.key,
    }, held.groups);
  }

  // the everyday or the decoy database, with the identity and settings
  final HaloDb primary;
  // the hidden chats of that identity, while their pin has them open
  final HaloDb? vault;
  // the people and groups whose chats the vault holds
  final Set<String> _people;
  final Set<String> _groups;

  // settings are the primary's. a chat's folders are its owner's (folderOf)
  HaloContainer get container => primary.container;

  // the developer chat is the primary's alone: never hidden, and a vault's
  // own row is never read
  DevChat get devChat => primary.devChat;

  // the support inbox is the primary's: only the everyday container of the
  // developer's own phone ever files one
  SupportChats get support => primary.support;

  // a chat only this session shows
  bool isHidden(String chatId) => identical(_ofChat(chatId), vault);

  // what a chat's draft, read mark and progress are kept under: the
  // container that holds it and its id
  String chatKey(String chatId) => _ofChat(chatId).container.chatKey(chatId);

  // the people whose chats the vault holds: receiving tries them too, and
  // never files them as everyday requests
  Set<String> get hiddenPeople => vault == null ? const {} : _people;

  // where a chat's photos, voice notes, files and wallpaper go: beside the
  // rows that point at them
  Future<Directory> folderOf(String chatId, String name) =>
      _ofChat(chatId).container.folder(name);
  Future<Directory> mediaDirOf(String chatId) => folderOf(chatId, 'media');

  HaloDb _ofPeer(String haloId) {
    final v = vault;
    return v != null && _people.contains(haloId) ? v : primary;
  }

  HaloDb _ofGroup(String groupId) {
    final v = vault;
    return v != null && _groups.contains(groupId) ? v : primary;
  }

  HaloDb _ofChat(String chatId) {
    final v = vault;
    if (v == null) return primary;
    return _people.contains(chatId) || _groups.contains(chatId) ? v : primary;
  }

  // a group's row carries its sender as the peer: the group decides
  HaloDb _ofEither(String? peerId, String? groupId) =>
      groupId != null && groupId.isNotEmpty
      ? _ofGroup(groupId)
      : _ofPeer(peerId ?? '');

  HaloDb _ofMessage(Map<String, Object?> r) =>
      _ofEither(r['peer_id'] as String?, r['group_id'] as String?);

  // the vault's when it holds the row, else the chat's when the call names
  // one, so a write for a hidden chat never lands in the primary
  Future<HaloDb> _ofUid(String uid, {String? peer, String? group}) async {
    final v = vault;
    if (v == null) return primary;
    if (await v.messageExists(uid)) return v;
    if (group != null && group.isNotEmpty) return _ofGroup(group);
    if (peer != null) return _ofPeer(peer);
    return primary;
  }

  // the rows of [d] that are its own: a chat both hold for a moment, a
  // hide cut short, shows once, from its owner
  static List<Map<String, Object?>> _own(
    HaloDb d,
    List<Map<String, Object?>> rows,
    HaloDb Function(Map<String, Object?>) owner,
  ) => [
    for (final r in rows)
      if (identical(owner(r), d)) r,
  ];

  HaloDb _personRow(Map<String, Object?> r) => _ofPeer(r['halo_id'] as String);
  HaloDb _groupRow(Map<String, Object?> r) => _ofGroup(r['group_id'] as String);

  // two lists, each already in [key] order, as one. each keeps its own
  // order, so a list sorted by arrival stays so. the limit comes after
  static List<Map<String, Object?>> _merge(
    List<Map<String, Object?>> a,
    List<Map<String, Object?>> b,
    String key, {
    bool newestFirst = true,
    int? limit,
  }) {
    int k(Map<String, Object?> r) => (r[key] as num?)?.toInt() ?? 0;
    final out = <Map<String, Object?>>[];
    var i = 0;
    var j = 0;
    while (i < a.length || j < b.length) {
      if (limit != null && out.length >= limit) break;
      final fromA =
          j >= b.length ||
          (i < a.length &&
              (newestFirst ? k(a[i]) >= k(b[j]) : k(a[i]) <= k(b[j])));
      out.add(fromA ? a[i++] : b[j++]);
    }
    return out;
  }

  // ---- one contact's chat ----
  Future<void> acceptRequest(String haloId) =>
      _ofPeer(haloId).acceptRequest(haloId);
  Future<void> assignUidIfMissing(String peerId, int sentAtMs, String uid) =>
      _ofPeer(peerId).assignUidIfMissing(peerId, sentAtMs, uid);
  Future<void> clearConversation(String peerId) =>
      _ofPeer(peerId).clearConversation(peerId);
  Future<void> clearKeyChanged(String haloId) =>
      _ofPeer(haloId).clearKeyChanged(haloId);
  Future<void> clearUnread(String peerId) =>
      _ofPeer(peerId).clearUnread(peerId);
  Future<int> countMessagesFrom(String peerId) =>
      _ofPeer(peerId).countMessagesFrom(peerId);
  Future<int> countMessagesTo(String peerId) =>
      _ofPeer(peerId).countMessagesTo(peerId);
  Future<void> declineRequest(String haloId) =>
      _ofPeer(haloId).declineRequest(haloId);
  Future<void> deleteConversation(String haloId) =>
      _ofPeer(haloId).deleteConversation(haloId);
  Future<void> dismissShield(String haloId) =>
      _ofPeer(haloId).dismissShield(haloId);
  Future<void> dropHeld(String peerId) => _ofPeer(peerId).dropHeld(peerId);
  Future<int?> firstMessageAt(String peerId) =>
      _ofPeer(peerId).firstMessageAt(peerId);
  Future<String?> getAtmosphere(String peerId) =>
      _ofPeer(peerId).getAtmosphere(peerId);
  Future<Map<String, Object?>?> getContact(String haloId) =>
      _ofPeer(haloId).getContact(haloId);
  Future<bool> askedBefore(String haloId) =>
      _ofPeer(haloId).askedBefore(haloId);
  Future<bool> isAccepted(String haloId) => _ofPeer(haloId).isAccepted(haloId);
  Future<bool> isBackPaired(String peerId) =>
      _ofPeer(peerId).isBackPaired(peerId);
  Future<bool> isBlocked(String haloId) => _ofPeer(haloId).isBlocked(haloId);
  Future<bool> isMuted(String haloId) => _ofPeer(haloId).isMuted(haloId);
  Future<bool> isVerified(String haloId) => _ofPeer(haloId).isVerified(haloId);
  Future<bool> keyChanged(String haloId) => _ofPeer(haloId).keyChanged(haloId);
  Future<List<Map<String, Object?>>> mediaFor(String peerId) =>
      _ofPeer(peerId).mediaFor(peerId);
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) => _ofPeer(peerId).messagesAfter(peerId, afterRowid);
  Future<List<Map<String, Object?>>> messagesFor(String peerId) =>
      _ofPeer(peerId).messagesFor(peerId);
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int limit = 60,
  }) => _ofPeer(
    peerId,
  ).messagesPage(peerId, beforeRowid: beforeRowid, limit: limit);
  Future<void> setArchived(String haloId, bool archived) =>
      _ofPeer(haloId).setArchived(haloId, archived);
  Future<void> setAtmosphere(String peerId, String atmosphere) =>
      _ofPeer(peerId).setAtmosphere(peerId, atmosphere);
  // their timed messages in the other container's groups start counting
  // too, and no receipt queued for them there goes. the block holds
  // whatever happens there: one shut meanwhile starts them a day after
  // they came, or at its next sweep
  Future<void> setBlocked(String haloId, bool blocked) async {
    final own = _ofPeer(haloId);
    await own.setBlocked(haloId, blocked);
    if (!blocked) return;
    for (final d in [primary, ?vault]) {
      if (identical(d, own)) continue;
      try {
        await d.lightBurnsFrom(haloId);
        await d.dropReceiptsTo(haloId);
      } catch (e) {
        dlog('block: other container not lit (${e.runtimeType})');
      }
    }
  }

  Future<void> setContactPinned(String haloId, bool pinned) =>
      _ofPeer(haloId).setContactPinned(haloId, pinned);
  Future<void> setKeyChanged(String haloId, bool changed) =>
      _ofPeer(haloId).setKeyChanged(haloId, changed);
  Future<void> setMuted(String haloId, bool muted) =>
      _ofPeer(haloId).setMuted(haloId, muted);
  Future<void> setNickname(String haloId, String? name) =>
      _ofPeer(haloId).setNickname(haloId, name);
  Future<void> setNote(String haloId, String note) =>
      _ofPeer(haloId).setNote(haloId, note);
  Future<void> setPeerBundle(String haloId, String bundleB64) =>
      _ofPeer(haloId).setPeerBundle(haloId, bundleB64);
  Future<void> setVerified(String haloId, bool verified) =>
      _ofPeer(haloId).setVerified(haloId, verified);
  Future<Map<String, Object?>?> shieldFor(String haloId) =>
      _ofPeer(haloId).shieldFor(haloId);
  // what the shield made of someone, while it is on. off, no verdict shows,
  // safe or not, whatever it said while it ran
  Future<Map<String, Object?>?> shownShieldFor(String haloId) async =>
      await loadScamShieldOn(container) ? shieldFor(haloId) : null;
  Future<List<({int id, String cipher})>> heldOf(String peerId) =>
      _ofPeer(peerId).heldOf(peerId);
  Future<void> forgetHeld(String peerId, int id) =>
      _ofPeer(peerId).forgetHeld(id);
  // someone new is an add, and an add is the primary's
  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
  }) => _ofPeer(haloId).upsertContact(haloId, onion, xpub, accepted: accepted);

  // ---- one group ----
  Future<void> addGroupMember(String groupId, String haloId) =>
      _ofGroup(groupId).addGroupMember(groupId, haloId);
  Future<void> clearGroupConversation(String groupId) =>
      _ofGroup(groupId).clearGroupConversation(groupId);
  Future<void> clearGroupUnread(String groupId) =>
      _ofGroup(groupId).clearGroupUnread(groupId);
  Future<void> deleteGroup(String groupId) =>
      _ofGroup(groupId).deleteGroup(groupId);
  Future<Map<String, Object?>?> getGroup(String groupId) =>
      _ofGroup(groupId).getGroup(groupId);
  Future<String?> getGroupAtmosphere(String groupId) =>
      _ofGroup(groupId).getGroupAtmosphere(groupId);
  Future<List<String>> getGroupMembers(String groupId) =>
      _ofGroup(groupId).getGroupMembers(groupId);
  Future<Map<String, ({int have, int of, int gaveUp})>> groupFileReach(
    String groupId,
  ) => _ofGroup(groupId).groupFileReach(groupId);
  Future<String?> groupAdminId(String groupId) =>
      _ofGroup(groupId).groupAdminId(groupId);
  Future<bool> groupExists(String groupId) =>
      _ofGroup(groupId).groupExists(groupId);
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) => _ofGroup(groupId).groupMessagesAfter(groupId, afterRowid);
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int limit = 60,
  }) => _ofGroup(
    groupId,
  ).groupMessagesPage(groupId, beforeRowid: beforeRowid, limit: limit);
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) =>
      _ofGroup(groupId).loadGroupMessages(groupId);
  Future<void> markRoomSeen(String groupId) =>
      _ofGroup(groupId).markRoomSeen(groupId);
  Future<void> removeGroupMember(String groupId, String haloId) =>
      _ofGroup(groupId).removeGroupMember(groupId, haloId);
  Future<void> renameGroup(String groupId, String name) =>
      _ofGroup(groupId).renameGroup(groupId, name);
  Future<void> setGroupAtmosphere(String groupId, String atmosphere) =>
      _ofGroup(groupId).setGroupAtmosphere(groupId, atmosphere);

  // ---- a chat of either kind ----
  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    int? burnSecs,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
    String? poll,
    String? sticker,
  }) => _ofEither(peerId, groupId).saveMessage(
    peerId,
    direction,
    plaintext,
    burnAt: burnAt,
    burnSecs: burnSecs,
    msgUid: msgUid,
    replyTo: replyTo,
    groupId: groupId,
    mediaPath: mediaPath,
    filePath: filePath,
    fileName: fileName,
    voiceDisguised: voiceDisguised,
    saved: saved,
    sent: sent,
    preview: preview,
    secure: secure,
    poll: poll,
    sticker: sticker,
  );
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) => _ofEither(peerId, groupId).pinnedIn(peerId: peerId, groupId: groupId);

  // ---- new chats ----
  Future<void> createGroup(
    String groupId,
    String name,
    List<String> members, {
    required bool isAdmin,
    String? adminId,
  }) => primary.createGroup(
    groupId,
    name,
    members,
    isAdmin: isAdmin,
    adminId: adminId,
  );
  Future<void> createRoom({
    required String groupId,
    required String name,
    required String priv,
    required String pub,
    required int expiresAt,
    required String creatorPub,
    required String fcPk,
    int? cap,
    required List<String> members,
  }) => primary.createRoom(
    groupId: groupId,
    name: name,
    priv: priv,
    pub: pub,
    expiresAt: expiresAt,
    creatorPub: creatorPub,
    fcPk: fcPk,
    cap: cap,
    members: members,
  );

  // ---- one message, by its uid ----
  Future<void> addReaction(String msgUid, String reactor, String emoji) async =>
      (await _ofUid(msgUid)).addReaction(msgUid, reactor, emoji);
  Future<void> closePollRow(
    String uid,
    PollSpec spec,
    Map<String, List<int>> finals,
    String? groupId,
  ) async => (await _ofUid(
    uid,
    group: groupId,
  )).closePollRow(uid, spec, finals, groupId);
  // a send still reading its file stops before the file is scrubbed
  Future<void> deleteMessage(String msgUid) async {
    if (mediaInflight.contains(msgUid)) cancelMediaSend(msgUid);
    await (await _ofUid(msgUid)).deleteMessage(msgUid);
  }

  Future<void> editMessage(String msgUid, String newText) async =>
      (await _ofUid(msgUid)).editMessage(msgUid, newText);
  Future<bool> isSent(String msgUid) async =>
      (await _ofUid(msgUid)).isSent(msgUid);
  Future<void> markSent(String msgUid) async =>
      (await _ofUid(msgUid)).markSent(msgUid);
  Future<int?> lightBurn(String msgUid) async =>
      (await _ofUid(msgUid)).lightBurn(msgUid);
  Future<bool> messageExists(String msgUid) async {
    final v = vault;
    if (v != null && await v.messageExists(msgUid)) return true;
    return primary.messageExists(msgUid);
  }

  Future<({PollSpec spec, String? groupId, bool mine})?> pollRow(
    String uid,
  ) async => (await _ofUid(uid)).pollRow(uid);
  Future<int?> pollVoteSeq(String pollUid, String voter) async =>
      (await _ofUid(pollUid)).pollVoteSeq(pollUid, voter);
  Future<int?> powNonceOf(String msgUid) async =>
      (await _ofUid(msgUid)).powNonceOf(msgUid);
  Future<bool> putPollVote(
    String pollUid,
    String voter,
    String? groupId,
    List<int> choices,
    int seq,
  ) async => (await _ofUid(
    pollUid,
    group: groupId,
  )).putPollVote(pollUid, voter, groupId, choices, seq);
  Future<void> queueEdit(String msgUid, String peerId, String newText) async =>
      (await _ofUid(msgUid, peer: peerId)).queueEdit(msgUid, peerId, newText);
  // an unsend's message is gone already: its chat's container keeps it
  Future<void> queueUnsend(String msgUid, String peerId) =>
      _ofPeer(peerId).queueFrame(msgUid, kFrameUnsend, peerId, '');
  Future<void> queueReaction(
    String msgUid,
    String peerId,
    String emoji,
  ) async => (await _ofUid(
    msgUid,
    peer: peerId,
  )).queueFrame(msgUid, kFrameReaction, peerId, emoji);
  Future<void> queuePin(String msgUid, String peerId, bool pinned) async =>
      (await _ofUid(msgUid, peer: peerId)).queuePin(msgUid, peerId, pinned);
  Future<void> removeReaction(String msgUid, String reactor) async =>
      (await _ofUid(msgUid)).removeReaction(msgUid, reactor);
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (await _ofUid(msgUid)).sendState(msgUid);
  Future<void> setMsgBurnAt(String msgUid, int burnAt) async =>
      (await _ofUid(msgUid)).setMsgBurnAt(msgUid, burnAt);
  // the rows read in one chat are all its container's
  Future<Map<String, int>> lightReadBurns(
    String chatId,
    List<String> msgUids,
  ) => _ofChat(chatId).lightReadBurns(msgUids);
  Future<void> setPinned(String msgUid, bool pinned) async =>
      (await _ofUid(msgUid)).setPinned(msgUid, pinned);
  Future<void> setPowNonce(String msgUid, int nonce) async =>
      (await _ofUid(msgUid)).setPowNonce(msgUid, nonce);
  Future<void> setSaved(String msgUid, bool saved) async =>
      (await _ofUid(msgUid)).setSaved(msgUid, saved);
  Future<String?> stickerOf(String uid) async =>
      (await _ofUid(uid)).stickerOf(uid);

  // ---- every chat ----
  // blocked anywhere is blocked
  Future<Set<String>> blockedIds() async {
    final v = vault;
    if (v == null) return primary.blockedIds();
    return {...await primary.blockedIds(), ...await v.blockedIds()};
  }

  Future<List<Map<String, Object?>>> contacts() async {
    final v = vault;
    if (v == null) return primary.contacts();
    return _merge(
      _own(primary, await primary.contacts(), _personRow),
      _own(v, await v.contacts(), _personRow),
      'last_seen',
    );
  }

  // the newest 1:1 row per person, from the container that holds the chat
  Future<Map<String, Map<String, Object?>>> lastMessages() async {
    final v = vault;
    if (v == null) return primary.lastMessages();
    return {
      for (final d in [primary, v])
        for (final e in (await d.lastMessages()).entries)
          if (identical(_ofPeer(e.key), d)) e.key: e.value,
    };
  }

  Future<List<Map<String, Object?>>> loadGroups() async {
    final v = vault;
    if (v == null) return primary.loadGroups();
    return _merge(
      _own(primary, await primary.loadGroups(), _groupRow),
      _own(v, await v.loadGroups(), _groupRow),
      'created_at',
    );
  }

  // a uid lives in one container; the vault's word wins if both answer
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async {
    final v = vault;
    if (v == null) return primary.loadReactionsFor(msgUids);
    return {
      ...await primary.loadReactionsFor(msgUids),
      ...await v.loadReactionsFor(msgUids),
    };
  }

  // declined and deleted people, out of every list
  Future<List<Map<String, Object?>>> parkedRequests() async {
    final v = vault;
    if (v == null) return primary.parkedRequests();
    return [
      ..._own(primary, await primary.parkedRequests(), _personRow),
      ..._own(v, await v.parkedRequests(), _personRow),
    ];
  }

  Future<int> pendingRequestCount() async {
    if (vault == null) return primary.pendingRequestCount();
    return (await requestsInbox()).length;
  }

  // the requests as their screen lists them: no support chats
  Future<List<Map<String, Object?>>> requestsInbox() async {
    final v = vault;
    if (v == null) return primary.requestsInbox();
    return _merge(
      _own(primary, await primary.requestsInbox(), _personRow),
      _own(v, await v.requestsInbox(), _personRow),
      'last_seen',
    );
  }

  Future<List<Map<String, Object?>>> pendingRequests() async {
    final v = vault;
    if (v == null) return primary.pendingRequests();
    return _merge(
      _own(primary, await primary.pendingRequests(), _personRow),
      _own(v, await v.pendingRequests(), _personRow),
      'last_seen',
    );
  }

  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async {
    final v = vault;
    if (v == null) return primary.pollVotesFor(uids);
    return {...await primary.pollVotesFor(uids), ...await v.pollVotesFor(uids)};
  }

  // a block in either container starts the other's waiting clocks
  Future<void> purgeExpiredBurns() async {
    await primary.purgeExpiredBurns(blocked: blockedIds);
    await vault?.purgeExpiredBurns(blocked: blockedIds);
  }

  Future<List<Map<String, Object?>>> savedMessages() async {
    final v = vault;
    if (v == null) return primary.savedMessages();
    return _merge(
      _own(primary, await primary.savedMessages(), _ofMessage),
      _own(v, await v.savedMessages(), _ofMessage),
      'sent_at',
      limit: 500,
    );
  }

  // each container searches its own index. newest first across both, and
  // the limit after the merge, so neither side crowds the other out
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async {
    final v = vault;
    if (v == null) return primary.searchMessages(match, kind, limit: limit);
    return _merge(
      _own(
        primary,
        await primary.searchMessages(match, kind, limit: limit),
        _ofMessage,
      ),
      _own(v, await v.searchMessages(match, kind, limit: limit), _ofMessage),
      'sent_at',
      limit: limit,
    );
  }

  // who vouched for someone, from both sides: a hidden contact's vouch
  // counts while the vault is open. oldest first, one row a voucher
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async {
    final v = vault;
    if (v == null) return primary.vouchesFor(haloId);
    final seen = <String>{};
    return [
      for (final r in _merge(
        await primary.vouchesFor(haloId),
        await v.vouchesFor(haloId),
        'created_at',
        newestFirst: false,
      ))
        if (seen.add(r['voucher_id'] as String)) r,
    ];
  }
}
