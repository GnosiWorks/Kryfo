// SPDX-License-Identifier: GPL-3.0-or-later
// stand-ins for what the receive side reaches: the router's store and seal,
// signal and the engine as the app calls them, and a database kept in maps
// that notes every call. anything else they are asked fails the test
import 'dart:convert';
import 'dart:typed_data';

import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppIo, HaloDb;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/polls.dart';
import 'package:kryfo/router.dart';

class ArrivalStore implements RouterStore {
  final rows = <String, Map<String, Object?>>{};
  final metas = <String, String>{};
  final inbox = <Map<String, Object?>>[];
  var _next = 1;

  @override
  Future<List<Map<String, Object?>>> hidden() async => rows.values.toList();
  @override
  Future<void> putHidden(
    String chatId,
    String kind,
    String card,
    int at,
  ) async {
    rows[chatId] = {'chat_id': chatId, 'kind': kind, 'card': card, 'at': at};
  }

  @override
  Future<void> deleteHidden(String chatId) async {
    rows.remove(chatId);
  }

  @override
  Future<String?> meta(String k) async => metas[k];
  @override
  Future<void> putMeta(String k, String? v) async {
    if (v == null) {
      metas.remove(k);
    } else {
      metas[k] = v;
    }
  }

  @override
  Future<void> inboxAdd(
    String? uid,
    int? part,
    Uint8List sealed,
    int at,
  ) async {
    inbox.add({
      'id': _next++,
      'uid': uid,
      'part': part,
      'sealed': sealed,
      'at': at,
    });
  }

  @override
  Future<bool> inboxHas(String uid, int? part) async =>
      inbox.any((r) => r['uid'] == uid && r['part'] == part);
  @override
  Future<int> inboxParts(String uid) async => {
    for (final r in inbox)
      if (r['uid'] == uid && r['part'] != null) r['part'],
  }.length;
  @override
  Future<int> inboxCount() async => inbox.length;
  @override
  Future<List<Map<String, Object?>>> inboxOldest(int limit) async =>
      inbox.take(limit).toList();
  @override
  Future<void> inboxDelete(int id) async {
    inbox.removeWhere((r) => r['id'] == id);
  }

  @override
  Future<void> inboxClear() async => inbox.clear();
}

// a stand-in for age: the bytes turned over under the pair's name, so
// nothing sealed reads as it came, and only the pair's other half opens it
class ArrivalSeal implements VaultSeal {
  // the engine failing as a whole, a stale library say
  bool broken = false;

  static List<int> _turn(List<int> b) => [for (final x in b) x ^ 0x5a];

  @override
  String? seal(String pub, String b64) {
    if (!pub.startsWith('pub-')) return null;
    return base64Encode([
      ...utf8.encode(pub.substring(4)),
      0,
      ..._turn(base64Decode(b64)),
    ]);
  }

  @override
  List<String?> openMany(String priv, List<String> b64s) {
    if (broken) throw StateError('no engine');
    return [for (final s in b64s) _open(priv, s)];
  }

  String? _open(String priv, String s) {
    final b = base64Decode(s);
    final cut = b.indexOf(0);
    if (cut < 0 || 'priv-${utf8.decode(b.sublist(0, cut))}' != priv) {
      return null;
    }
    return base64Encode(_turn(b.sublist(cut + 1)));
  }
}

class ArrivalIo implements AppIo {
  // what a cipher opens to, and under whom
  final opens = <String, (String, String)>{};
  final tries = <String>[];
  List<String> sessions = [];
  ({String haloId, String plain, UnwrappedMessage env})? firstContact;
  final listened = <String>[];
  final sent = <(String, String)>[];
  final rang = <String>[];

  List<String> ticksFor(String uid) => [
    for (final (to, c) in sent)
      if (c.contains('"dr":"$uid"')) to,
  ];

  int triesOf(String peer) => tries.where((t) => t.startsWith('$peer ')).length;

  @override
  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) async {
    tries.add('$peer $cipher');
    final o = opens[cipher];
    return o != null && o.$1 == peer ? o.$2 : null;
  }

  @override
  Future<List<String>> sessionAddresses() async => sessions;
  // sessions let go of
  final dropped = <String>[];
  @override
  Future<void> dropSession(String peer) async {
    dropped.add(peer);
    sessions.remove(peer);
  }

  @override
  Future<({String haloId, String plain, UnwrappedMessage env})?>
  openFirstContact(String cipher) async => firstContact;
  @override
  Future<bool> hasSession(String peer) async => true;
  @override
  Future<String> encrypt(String peer, String plain) async => 'to $peer $plain';
  @override
  void listen(String xPub) => listened.add(xPub);
  final unheard = <String>[];
  @override
  void unlisten(String xPub) => unheard.add(xPub);
  @override
  String edPub() => 'ed-me';
  @override
  String xPub() => 'x-me';
  @override
  Future<String> relaySend(String xPub, String cipher) async {
    sent.add(('relay $xPub', cipher));
    return 'ok';
  }

  @override
  Future<String> onionSend(String onion, String cipher) async {
    sent.add(('onion $onion', cipher));
    return 'ok';
  }

  @override
  Future<String> firstContactSend(String xPub, String fc, String cipher) async {
    sent.add(('fc $xPub', cipher));
    return 'ok';
  }

  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
  }) async => rang.add(payload ?? title);

  @override
  Future<void> unnotify(String payload) async {}
}

// a database in memory: the rows the receive side reads and writes, and a
// note of every call. anything else it is asked fails the test
class ArrivalRows implements HaloDb {
  ArrivalRows(this._container);

  final HaloContainer _container;
  final calls = <String>[];
  final people = <String, Map<String, Object?>>{};
  final msgs = <Map<String, Object?>>[];
  final reactions = <String, Map<String, String>>{};
  final groupRows = <String, Map<String, Object?>>{};
  final members = <String, List<String>>{};
  final votes = <String, Map<String, (List<int>, int)>>{};
  final chunks = <String, Map<int, String>>{};
  final chunkBurn = <String, int>{};
  // who sent each file's slices
  final chunkFrom = <String, String>{};
  final seen = <String>{};
  final held = <String>[];
  final vouches = <String, Set<String>>{};
  // when each vouch and reaction was stamped
  final vouchedAt = <String, int?>{};
  final reactedAt = <String, int?>{};
  final delivered = <String>{};
  final shields = <String, Map<String, Object?>>{};
  // called after each message is kept
  void Function()? onSave;

  // calls that leave a row behind. the seen marks are the receive side's
  // own bookkeeping and say nothing of anyone
  static const _rowCalls = {
    'upsertContact',
    'upsertContactStub',
    'saveMessage',
    'addVouch',
    'holdCipher',
    'putMediaChunk',
    'noteMediaWant',
    'bumpUnread',
    'bumpGroupUnread',
    'setGroupMentioned',
    'markBackPaired',
    'markDelivered',
    'setContactBadge',
    'setContactAvatar',
    'addReaction',
    'editMessage',
    'setPinned',
    'putPollVote',
    'closePollRow',
    'createGroup',
    'renameGroup',
    'addGroupMember',
    'syncGroupMembers',
    'setShield',
    'setPeerBundle',
    'setContactXPub',
  };

  List<String> get rowWrites => [
    for (final c in calls)
      if (_rowCalls.contains(c.split(':').first)) c,
  ];

  T _hit<T>(String name, Object? arg, T answer) {
    calls.add(arg == null ? name : '$name:$arg');
    return answer;
  }

  void person(
    String id, {
    int accepted = 1,
    String onion = '',
    String xpub = '',
    int backPaired = 1,
    int archived = 0,
  }) => people[id] = {
    'halo_id': id,
    'onion': onion,
    'xpub': xpub,
    'accepted': accepted,
    'blocked': 0,
    'archived': archived,
    'back_paired': backPaired,
    'unread': 0,
    'muted': 0,
    'verified': 0,
    'pinned': 0,
    'last_seen': 1,
  };

  void group(String id, List<String> who, {String? admin}) {
    groupRows[id] = {
      'group_id': id,
      'name': id,
      'created_at': 1,
      'is_admin': 0,
      'admin_id': admin,
      'unread': 0,
      'mentioned': 0,
    };
    members[id] = [...who];
  }

  Map<String, Object?>? msg(String uid) {
    for (final m in msgs) {
      if (m['msg_uid'] == uid) return m;
    }
    return null;
  }

  @override
  HaloContainer get container => _container;

  // ---- people ----
  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _hit('getContact', haloId, people[haloId]);
  @override
  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
  }) async {
    _hit('upsertContact', haloId, null);
    final p = people[haloId];
    if (p == null) {
      person(
        haloId,
        accepted: accepted,
        onion: onion,
        xpub: xpub,
        backPaired: 0,
      );
      return;
    }
    p['onion'] = onion;
    if (xpub.isNotEmpty) p['xpub'] = xpub;
    if (accepted == 1) p['accepted'] = 1;
  }

  @override
  Future<void> upsertContactStub(
    String haloId,
    String onion,
    String xpub,
  ) async {
    _hit('upsertContactStub', haloId, null);
    if (people.containsKey(haloId)) return;
    person(haloId, accepted: 0, onion: onion, xpub: xpub, backPaired: 0);
  }

  @override
  Future<List<Map<String, Object?>>> contacts() async =>
      _hit('contacts', null, [
        for (final p in people.values)
          if (p['accepted'] == 1) p,
      ]);
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async =>
      _hit('pendingRequests', null, [
        for (final p in people.values)
          if (p['accepted'] == 0 && p['archived'] == 0 && p['blocked'] == 0) p,
      ]);
  @override
  Future<List<Map<String, Object?>>> parkedRequests() async =>
      _hit('parkedRequests', null, [
        for (final p in people.values)
          if (p['accepted'] == 0 && p['archived'] == 1) p,
      ]);
  @override
  Future<List<Map<String, Object?>>> vouchedPending() async =>
      _hit('vouchedPending', null, [
        for (final p in people.values)
          if (p['accepted'] == 0 && vouches.containsKey(p['halo_id'])) p,
      ]);
  @override
  Future<int> pendingRequestCount() async => (await pendingRequests()).length;
  @override
  Future<List<Map<String, Object?>>> requestsInbox() => pendingRequests();
  @override
  Future<bool> isAccepted(String haloId) async =>
      _hit('isAccepted', haloId, people[haloId]?['accepted'] == 1);
  @override
  Future<bool> isVouched(String haloId) async =>
      _hit('isVouched', haloId, vouches.containsKey(haloId));
  @override
  Future<bool> isBlocked(String haloId) async =>
      _hit('isBlocked', haloId, people[haloId]?['blocked'] == 1);
  @override
  Future<bool> isMuted(String haloId) async =>
      _hit('isMuted', haloId, people[haloId]?['muted'] == 1);
  @override
  Future<bool> isBackPaired(String peerId) async =>
      _hit('isBackPaired', peerId, people[peerId]?['back_paired'] == 1);
  @override
  Future<void> markBackPaired(String peerId) async {
    _hit('markBackPaired', peerId, null);
    people[peerId]?['back_paired'] = 1;
  }

  @override
  Future<void> setContactBadge(String haloId, String? tier) async =>
      _hit('setContactBadge', haloId, null);
  @override
  Future<void> setContactAvatar(String haloId, int? av) async =>
      _hit('setContactAvatar', haloId, null);
  @override
  Future<void> forgetRequest(String haloId) async {
    _hit('forgetRequest', haloId, null);
    if (people[haloId]?['accepted'] == 0) people.remove(haloId);
    shields.remove(haloId);
  }

  @override
  Future<void> unparkIfArchived(String haloId) async {
    _hit('unparkIfArchived', haloId, null);
    final p = people[haloId];
    if (p != null && p['archived'] == 1 && p['accepted'] == 0) {
      p['archived'] = 0;
    }
  }

  @override
  Future<void> bumpUnread(String peerId) async {
    _hit('bumpUnread', peerId, null);
    final p = people[peerId];
    if (p != null) p['unread'] = (p['unread'] as int) + 1;
  }

  @override
  Future<void> clearUnread(String peerId) async =>
      _hit('clearUnread', peerId, null);
  @override
  Future<void> addVouch(
    String haloId,
    String voucherId,
    String? note, {
    int? at,
  }) async {
    _hit('addVouch', haloId, null);
    vouches.putIfAbsent(haloId, () => {}).add(voucherId);
    vouchedAt['$haloId $voucherId'] = at;
  }

  @override
  Future<String?> contactXPub(String haloId) async =>
      _hit('contactXPub', haloId, people[haloId]?['xpub'] as String?);
  @override
  Future<void> setContactXPub(String haloId, String xpub) async =>
      _hit('setContactXPub', haloId, null);
  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      _hit('heldChats', null, (
        people: {
          for (final p in people.values)
            p['halo_id'] as String: p['accepted'] == 1,
        },
        groups: groupRows.keys.toSet(),
      ));
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async =>
      _hit('lastMessages', null, {
        for (final m in msgs)
          if (m['group_id'] == null) m['peer_id'] as String: m,
      });
  @override
  Future<int> countMessagesFrom(String peerId) async => _hit(
    'countMessagesFrom',
    peerId,
    msgs.where((m) => m['peer_id'] == peerId && m['direction'] == 'in').length,
  );
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async =>
      _hit('shieldFor', haloId, shields[haloId]);
  // the first one kept, as the table keeps it
  @override
  Future<void> setShield(
    String haloId,
    String headline,
    List<Map<String, String>> lines,
  ) async {
    _hit('setShield', haloId, null);
    shields.putIfAbsent(
      haloId,
      () => {
        'halo_id': haloId,
        'headline': headline,
        'lines': jsonEncode(lines),
        'dismissed': 0,
      },
    );
  }

  @override
  Future<void> holdCipher(String peerId, String cipher) async {
    _hit('holdCipher', peerId, null);
    held.add(peerId);
  }

  @override
  Future<void> setPeerBundle(String haloId, String bundleB64) async =>
      _hit('setPeerBundle', haloId, null);

  // ---- the receive side's own marks ----
  @override
  Future<bool> alreadySeen(String hash) async =>
      _hit('alreadySeen', null, seen.contains(hash));
  @override
  Future<void> markSeen(String hash) async {
    _hit('markSeen', null, null);
    seen.add(hash);
  }

  @override
  Future<void> markSeenLong(String hash) async {
    _hit('markSeenLong', null, null);
    seen.add(hash);
  }

  @override
  Future<void> markDelivered(String msgUid, {required String from}) async {
    _hit('markDelivered', msgUid, null);
    delivered.add('$msgUid from $from');
  }

  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async =>
      _hit('unsentOutbox', null, const []);

  // ---- messages ----
  @override
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
    int? sentAt,
  }) async {
    _hit('saveMessage', msgUid ?? peerId, null);
    msgs.add({
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
      'burn_at': burnAt,
      'msg_uid': msgUid,
      'group_id': groupId,
      'media_path': mediaPath,
      'file_path': filePath,
      'poll': poll,
      'sticker': sticker,
      'pinned': 0,
      'pinned_at': null,
      'edited': 0,
    });
    onSave?.call();
  }

  @override
  Future<bool> messageExists(String msgUid) async =>
      _hit('messageExists', msgUid, msg(msgUid) != null);
  @override
  Future<(String, String?)?> chatOf(String msgUid) async {
    final m = msg(msgUid);
    return _hit(
      'chatOf',
      msgUid,
      m == null ? null : (m['peer_id'] as String, m['group_id'] as String?),
    );
  }

  @override
  Future<bool> isTheirs(String msgUid, String sender) async {
    final m = msg(msgUid);
    return _hit(
      'isTheirs',
      msgUid,
      m != null && m['direction'] == 'in' && m['peer_id'] == sender,
    );
  }

  @override
  Future<void> editMessage(String msgUid, String newText) async {
    _hit('editMessage', msgUid, null);
    final m = msg(msgUid);
    if (m == null) return;
    m['plaintext'] = newText;
    m['edited'] = 1;
  }

  @override
  Future<void> deleteMessage(String msgUid) async {
    _hit('deleteMessage', msgUid, null);
    msgs.removeWhere((m) => m['msg_uid'] == msgUid);
    reactions.remove(msgUid);
  }

  @override
  Future<void> addReaction(
    String msgUid,
    String reactor,
    String emoji, {
    int? at,
  }) async {
    _hit('addReaction', msgUid, null);
    reactions.putIfAbsent(msgUid, () => {})[reactor] = emoji;
    reactedAt['$msgUid $reactor'] = at;
  }

  @override
  Future<void> removeReaction(String msgUid, String reactor) async {
    _hit('removeReaction', msgUid, null);
    reactions[msgUid]?.remove(reactor);
  }

  @override
  Future<void> setPinned(String msgUid, bool pinned, {int? at}) async {
    _hit('setPinned', msgUid, null);
    final m = msg(msgUid);
    if (m == null) return;
    m['pinned'] = pinned ? 1 : 0;
    m['pinned_at'] = pinned
        ? at ?? DateTime.now().millisecondsSinceEpoch
        : null;
  }

  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => _hit('pinnedIn', groupId ?? peerId, [
    for (final m in msgs)
      if (m['pinned'] == 1 &&
          (groupId != null
              ? m['group_id'] == groupId
              : m['peer_id'] == peerId && m['group_id'] == null))
        m,
  ]);

  @override
  Future<({PollSpec spec, String? groupId, bool mine})?> pollRow(
    String uid,
  ) async {
    final m = msg(uid);
    final spec = m == null ? null : PollSpec.parse(m['poll']);
    return _hit(
      'pollRow',
      uid,
      spec == null
          ? null
          : (
              spec: spec,
              groupId: m!['group_id'] as String?,
              mine: m['direction'] == 'out',
            ),
    );
  }

  @override
  Future<bool> pollGone(String uid) async => _hit('pollGone', uid, false);
  @override
  Future<bool> putPollVote(
    String pollUid,
    String voter,
    String? groupId,
    List<int> choices,
    int seq,
  ) async {
    _hit('putPollVote', pollUid, null);
    final held = votes[pollUid]?[voter];
    if (!voteIsNewer(held?.$2, seq)) return false;
    votes.putIfAbsent(pollUid, () => {})[voter] = (choices, seq);
    return true;
  }

  @override
  Future<void> closePollRow(
    String uid,
    PollSpec spec,
    Map<String, List<int>> finals,
    String? groupId,
  ) async {
    _hit('closePollRow', uid, null);
    msg(uid)?['poll'] = spec.closedNow().toRow();
    votes[uid] = {
      for (final e in finals.entries) e.key: (e.value, kPollFinalSeq),
    };
  }

  @override
  Future<Map<String, Object?>?> sentMediaRow(String msgUid) async =>
      _hit('sentMediaRow', msgUid, null);

  // ---- groups ----
  @override
  Future<bool> groupExists(String groupId) async =>
      _hit('groupExists', groupId, groupRows.containsKey(groupId));
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async =>
      _hit('getGroup', groupId, groupRows[groupId]);
  @override
  Future<String?> groupAdminId(String groupId) async =>
      _hit('groupAdminId', groupId, groupRows[groupId]?['admin_id'] as String?);
  @override
  Future<List<String>> getGroupMembers(String groupId) async =>
      _hit('getGroupMembers', groupId, [...?members[groupId]]);
  @override
  Future<void> syncGroupMembers(String groupId, List<String> who) async {
    _hit('syncGroupMembers', groupId, null);
    members[groupId] = [...who];
  }

  @override
  Future<void> createGroup(
    String groupId,
    String name,
    List<String> who, {
    required bool isAdmin,
    String? adminId,
  }) async {
    _hit('createGroup', groupId, null);
    group(groupId, who, admin: adminId);
    groupRows[groupId]!['name'] = name;
  }

  @override
  Future<void> renameGroup(String groupId, String name) async {
    _hit('renameGroup', groupId, null);
    groupRows[groupId]?['name'] = name;
  }

  @override
  Future<void> addGroupMember(String groupId, String haloId) async {
    _hit('addGroupMember', groupId, null);
    members.putIfAbsent(groupId, () => []).add(haloId);
  }

  @override
  Future<void> removeGroupMember(String groupId, String haloId) async {
    _hit('removeGroupMember', groupId, null);
    members[groupId]?.remove(haloId);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    _hit('deleteGroup', groupId, null);
    groupRows.remove(groupId);
    members.remove(groupId);
  }

  @override
  Future<Map<String, Object?>?> roomByPub(String pub) async {
    for (final g in groupRows.values) {
      if (g['room_pub'] == pub) return g;
    }
    return null;
  }

  @override
  Future<void> bumpGroupUnread(String groupId) async {
    _hit('bumpGroupUnread', groupId, null);
    final g = groupRows[groupId];
    if (g != null) g['unread'] = (g['unread'] as int) + 1;
  }

  @override
  Future<void> setGroupMentioned(String groupId) async =>
      _hit('setGroupMentioned', groupId, null);
  @override
  Future<void> clearGroupUnread(String groupId) async =>
      _hit('clearGroupUnread', groupId, null);
  @override
  Future<List<Map<String, Object?>>> loadGroups() async =>
      _hit('loadGroups', null, groupRows.values.toList());

  // ---- a file in slices ----
  @override
  Future<int> putMediaChunk(
    String mediaId,
    int idx,
    String slice,
    int total,
    int? burn, {
    required String from,
  }) async {
    _hit('putMediaChunk', mediaId, null);
    chunkFrom[mediaId] = from;
    (chunks[mediaId] ??= {})[idx] = slice;
    if (burn != null) chunkBurn[mediaId] = burn;
    return chunks[mediaId]!.length;
  }

  @override
  Future<int?> mediaChunkBurn(String mediaId) async =>
      _hit('mediaChunkBurn', mediaId, chunkBurn[mediaId]);
  @override
  Future<String?> mediaChunkSlice(String mediaId, int idx) async =>
      _hit('mediaChunkSlice', mediaId, chunks[mediaId]?[idx]);
  @override
  Future<int> dropMediaChunks(String mediaId, {String? from}) async {
    if (from != null && chunkFrom[mediaId] != from) {
      return _hit('dropMediaChunks', mediaId, 0);
    }
    chunkBurn.remove(mediaId);
    chunkFrom.remove(mediaId);
    return _hit(
      'dropMediaChunks',
      mediaId,
      chunks.remove(mediaId)?.length ?? 0,
    );
  }

  @override
  Future<String?> mediaChunkSender(String mediaId) async =>
      _hit('mediaChunkSender', mediaId, chunkFrom[mediaId]);

  @override
  Future<int> filesInFlightFrom(String from, {String? except}) async => _hit(
    'filesInFlightFrom',
    from,
    chunkFrom.entries.where((e) => e.value == from && e.key != except).length,
  );

  @override
  Future<void> noteMediaWant(
    String mediaId,
    String peerId,
    int total,
    bool canResend,
  ) async => _hit('noteMediaWant', mediaId, null);
  @override
  Future<void> dropMediaWant(String mediaId) async =>
      _hit('dropMediaWant', mediaId, null);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

SenderInfo asSender(String id) =>
    SenderInfo(haloId: id, edPub: 'ed-$id', onion: 'o-$id', xPub: 'x-$id');
