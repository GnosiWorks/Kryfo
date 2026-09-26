// SPDX-License-Identifier: GPL-3.0-or-later
// the open session, as the screens and AppState reach it. they never name a
// database, so which container holds a chat is decided in this one place.
// every call goes to the primary

import 'container.dart';
import 'main.dart' show HaloDb;
import 'polls.dart' show PollSpec, PollVote;
import 'search.dart' show SearchKind;

class Session {
  Session(this.primary, [this.vault]);

  // the everyday or the decoy database, with the identity and settings
  final HaloDb primary;
  // the hidden chats of that identity, while their pin has them open
  final HaloDb? vault;

  // settings and media folders are the primary's
  HaloContainer get container => primary.container;

  // ---- one contact's chat ----
  Future<void> acceptRequest(String haloId) => primary.acceptRequest(haloId);
  Future<void> assignUidIfMissing(String peerId, int sentAtMs, String uid) =>
      primary.assignUidIfMissing(peerId, sentAtMs, uid);
  Future<void> clearConversation(String peerId) =>
      primary.clearConversation(peerId);
  Future<void> clearKeyChanged(String haloId) =>
      primary.clearKeyChanged(haloId);
  Future<void> clearUnread(String peerId) => primary.clearUnread(peerId);
  Future<int> countMessagesFrom(String peerId) =>
      primary.countMessagesFrom(peerId);
  Future<int> countMessagesTo(String peerId) => primary.countMessagesTo(peerId);
  Future<void> declineRequest(String haloId) => primary.declineRequest(haloId);
  Future<void> deleteConversation(String haloId) =>
      primary.deleteConversation(haloId);
  Future<void> dismissShield(String haloId) => primary.dismissShield(haloId);
  Future<void> dropHeld(String peerId) => primary.dropHeld(peerId);
  Future<int?> firstMessageAt(String peerId) => primary.firstMessageAt(peerId);
  Future<String?> getAtmosphere(String peerId) => primary.getAtmosphere(peerId);
  Future<Map<String, Object?>?> getContact(String haloId) =>
      primary.getContact(haloId);
  Future<bool> isAccepted(String haloId) => primary.isAccepted(haloId);
  Future<bool> isBackPaired(String peerId) => primary.isBackPaired(peerId);
  Future<bool> isBlocked(String haloId) => primary.isBlocked(haloId);
  Future<bool> isMuted(String haloId) => primary.isMuted(haloId);
  Future<bool> isVerified(String haloId) => primary.isVerified(haloId);
  Future<bool> keyChanged(String haloId) => primary.keyChanged(haloId);
  Future<List<Map<String, Object?>>> mediaFor(String peerId) =>
      primary.mediaFor(peerId);
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) => primary.messagesAfter(peerId, afterRowid);
  Future<List<Map<String, Object?>>> messagesFor(String peerId) =>
      primary.messagesFor(peerId);
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int limit = 60,
  }) => primary.messagesPage(peerId, beforeRowid: beforeRowid, limit: limit);
  Future<void> setArchived(String haloId, bool archived) =>
      primary.setArchived(haloId, archived);
  Future<void> setAtmosphere(String peerId, String atmosphere) =>
      primary.setAtmosphere(peerId, atmosphere);
  Future<void> setBlocked(String haloId, bool blocked) =>
      primary.setBlocked(haloId, blocked);
  Future<void> setContactPinned(String haloId, bool pinned) =>
      primary.setContactPinned(haloId, pinned);
  Future<void> setKeyChanged(String haloId, bool changed) =>
      primary.setKeyChanged(haloId, changed);
  Future<void> setMuted(String haloId, bool muted) =>
      primary.setMuted(haloId, muted);
  Future<void> setNickname(String haloId, String? name) =>
      primary.setNickname(haloId, name);
  Future<void> setNote(String haloId, String note) =>
      primary.setNote(haloId, note);
  Future<void> setPeerBundle(String haloId, String bundleB64) =>
      primary.setPeerBundle(haloId, bundleB64);
  Future<void> setVerified(String haloId, bool verified) =>
      primary.setVerified(haloId, verified);
  Future<Map<String, Object?>?> shieldFor(String haloId) =>
      primary.shieldFor(haloId);
  Future<List<String>> takeHeld(String peerId) => primary.takeHeld(peerId);
  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
  }) => primary.upsertContact(haloId, onion, xpub, accepted: accepted);
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) =>
      primary.vouchesFor(haloId);

  // ---- one group ----
  Future<void> addGroupMember(String groupId, String haloId) =>
      primary.addGroupMember(groupId, haloId);
  Future<void> clearGroupConversation(String groupId) =>
      primary.clearGroupConversation(groupId);
  Future<void> clearGroupUnread(String groupId) =>
      primary.clearGroupUnread(groupId);
  Future<void> deleteGroup(String groupId) => primary.deleteGroup(groupId);
  Future<Map<String, Object?>?> getGroup(String groupId) =>
      primary.getGroup(groupId);
  Future<String?> getGroupAtmosphere(String groupId) =>
      primary.getGroupAtmosphere(groupId);
  Future<List<String>> getGroupMembers(String groupId) =>
      primary.getGroupMembers(groupId);
  Future<String?> groupAdminId(String groupId) => primary.groupAdminId(groupId);
  Future<bool> groupExists(String groupId) => primary.groupExists(groupId);
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) => primary.groupMessagesAfter(groupId, afterRowid);
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int limit = 60,
  }) => primary.groupMessagesPage(
    groupId,
    beforeRowid: beforeRowid,
    limit: limit,
  );
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) =>
      primary.loadGroupMessages(groupId);
  Future<void> markRoomSeen(String groupId) => primary.markRoomSeen(groupId);
  Future<void> removeGroupMember(String groupId, String haloId) =>
      primary.removeGroupMember(groupId, haloId);
  Future<void> renameGroup(String groupId, String name) =>
      primary.renameGroup(groupId, name);
  Future<void> setGroupAtmosphere(String groupId, String atmosphere) =>
      primary.setGroupAtmosphere(groupId, atmosphere);

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
  }) => primary.saveMessage(
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
  }) => primary.pinnedIn(peerId: peerId, groupId: groupId);

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
  Future<void> addReaction(String msgUid, String reactor, String emoji) =>
      primary.addReaction(msgUid, reactor, emoji);
  Future<void> closePollRow(
    String uid,
    PollSpec spec,
    Map<String, List<int>> finals,
    String? groupId,
  ) => primary.closePollRow(uid, spec, finals, groupId);
  Future<void> deleteMessage(String msgUid) => primary.deleteMessage(msgUid);
  Future<void> editMessage(String msgUid, String newText) =>
      primary.editMessage(msgUid, newText);
  Future<bool> isSent(String msgUid) => primary.isSent(msgUid);
  Future<void> markSent(String msgUid) => primary.markSent(msgUid);
  Future<bool> messageExists(String msgUid) => primary.messageExists(msgUid);
  Future<({PollSpec spec, String? groupId, bool mine})?> pollRow(String uid) =>
      primary.pollRow(uid);
  Future<int?> pollVoteSeq(String pollUid, String voter) =>
      primary.pollVoteSeq(pollUid, voter);
  Future<int?> powNonceOf(String msgUid) => primary.powNonceOf(msgUid);
  Future<bool> putPollVote(
    String pollUid,
    String voter,
    String? groupId,
    List<int> choices,
    int seq,
  ) => primary.putPollVote(pollUid, voter, groupId, choices, seq);
  Future<void> queueEdit(String msgUid, String peerId, String newText) =>
      primary.queueEdit(msgUid, peerId, newText);
  Future<void> queuePin(String msgUid, String peerId, bool pinned) =>
      primary.queuePin(msgUid, peerId, pinned);
  Future<void> removeReaction(String msgUid, String reactor) =>
      primary.removeReaction(msgUid, reactor);
  Future<({bool sent, bool delivered})> sendState(String msgUid) =>
      primary.sendState(msgUid);
  Future<void> setMsgBurnAt(String msgUid, int burnAt) =>
      primary.setMsgBurnAt(msgUid, burnAt);
  Future<void> setPinned(String msgUid, bool pinned) =>
      primary.setPinned(msgUid, pinned);
  Future<void> setPowNonce(String msgUid, int nonce) =>
      primary.setPowNonce(msgUid, nonce);
  Future<void> setSaved(String msgUid, bool saved) =>
      primary.setSaved(msgUid, saved);
  Future<String?> stickerOf(String uid) => primary.stickerOf(uid);

  // ---- every chat ----
  Future<Set<String>> blockedIds() => primary.blockedIds();
  Future<List<Map<String, Object?>>> contacts() => primary.contacts();
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) => primary.loadReactionsFor(msgUids);
  Future<List<Map<String, Object?>>> pendingRequests() =>
      primary.pendingRequests();
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(List<String> uids) =>
      primary.pollVotesFor(uids);
  Future<void> purgeExpiredBurns() => primary.purgeExpiredBurns();
  Future<List<Map<String, Object?>>> savedMessages() => primary.savedMessages();
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) => primary.searchMessages(match, kind, limit: limit);
}
