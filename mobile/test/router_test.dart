// SPDX-License-Identifier: GPL-3.0-or-later
// the router: an arrival for a hidden chat while its vault is shut is sealed
// and nothing else moves, and it goes into the vault in order once the vault
// opens. the databases, signal and the engine are stand-ins that keep what
// they are given and note every call, so nothing here needs sqlite or a phone
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppIo, AppState, HaloDb, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/polls.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _h = 'hidden-wreck-tone';
const _v = 'visible-plain-row';
const _gone = 'former-quiet-one';
const _g2 = 'g2hidden0001';
const _g1 = 'g1visible001';

class _Store implements RouterStore {
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
  Future<List<(int, int)>> inboxSizes() async => [
    for (final r in inbox) (r['id'] as int, (r['sealed'] as List<int>).length),
  ];
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
class _Seal implements VaultSeal {
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

class _Io implements AppIo {
  // sessions let go of, and addresses no longer listened on
  final dropped = <String>[];
  @override
  Future<void> dropSession(String peer) async => dropped.add(peer);
  @override
  void unlisten(String xPub) => dropped.add(xPub);
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
  @override
  Future<({String haloId, String plain, UnwrappedMessage env})?>
  openFirstContact(String cipher) async => firstContact;
  @override
  Future<bool> hasSession(String peer) async => true;
  @override
  Future<String> encrypt(String peer, String plain) async => 'to $peer $plain';
  @override
  void listen(String xPub) => listened.add(xPub);
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
    String? msgUid,
    int? burnAt,
  }) async => rang.add(payload ?? title);

  @override
  Future<void> unnotifyMessage(String msgUid) async {}

  @override
  Future<void> unnotify(String payload) async {}
}

// a database in memory: the rows the receive side reads and writes, and a
// note of every call. anything else it is asked fails the test
class _Mem implements HaloDb {
  _Mem(this._container);

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
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async =>
      _hit(
        'countMessagesFrom',
        peerId,
        msgs
            .where(
              (m) =>
                  m['peer_id'] == peerId &&
                  m['direction'] == 'in' &&
                  (inGroups || m['group_id'] == null),
            )
            .length,
      );
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async =>
      _hit('shieldFor', haloId, null);
  @override
  Future<void> setShield(
    String haloId,
    String headline,
    List<Map<String, String>> lines,
  ) async => _hit('setShield', haloId, null);
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
    delivered.add(msgUid);
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
  Future<Set<String>> trimUnfinishedMedia({
    Set<String> keep = const {},
    int bytes = 0,
    int files = 0,
  }) async => _hit('trimUnfinishedMedia', null, <String>{});

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

SenderInfo _as(String id) =>
    SenderInfo(haloId: id, edPub: 'ed-$id', onion: 'o-$id', xPub: 'x-$id');

// a phone with a vault: the hidden chat with H and the hidden group G2 on
// the router's list, a visible contact V, and a group G1 where H and V are
// both members. the vault holds H and G2
class _World {
  final live = _Mem(HaloContainer.everyday);
  final vault = _Mem(HaloContainer.vault);
  final store = _Store();
  final io = _Io();
  final seal = _Seal();
  late VaultRouter router;
  late AppState app;
  var redrawn = 0;
  var _n = 0;

  static Future<_World> make({bool open = false, bool hidden = true}) async {
    final w = _World();
    w.live.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    w.live.group(_g1, ['me', _v, _h], admin: _v);
    w.vault.person(_h, onion: 'o-$_h', xpub: 'x-$_h');
    w.vault.group(_g2, ['me', _h], admin: _h);
    if (hidden) {
      await w.store.putHidden(
        _h,
        kHiddenPeer,
        peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
        1,
      );
      await w.store.putHidden(_g2, kHiddenGroup, groupCard(const []), 1);
      await w.store.putHidden(_gone, kHiddenGone, '{}', 1);
      await w.store.putMeta('pub', 'pub-A');
    }
    w.router = VaultRouter(w.store, w.seal);
    await w.router.load();
    w.app = AppState(io: w.io, router: w.router)..myId = 'me';
    w.app.addListener(() => w.redrawn++);
    if (open) {
      await w.open();
    } else {
      useDatabasesForTest(w.live, Session(w.live));
    }
    return w;
  }

  Future<void> open() async =>
      useDatabasesForTest(live, await Session.withVault(live, vault));

  void close() => useDatabasesForTest(live, Session(live));

  // a message arriving on the onion lane, opened under [from]
  Future<void> onion(String from, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (from, plain);
    await app.receiveOnion([c]);
    await _settle();
  }

  // everything on the stand-ins, as asserted in the tests below: no row
  // anywhere in the everyday container
  List<String> get everydayRows => live.rowWrites;
}

// what was sent without being waited for gets there
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('router_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('route', () {
    test('1:1 by the sender, a group by the group', () async {
      final w = await _World.make();
      final r = w.router;
      expect(r.route(_h, null), RouteTo.sealed);
      expect(r.route(_v, null), RouteTo.everyday);
      expect(r.route(_v, _g2), RouteTo.sealed);
      // a hidden contact writing in an everyday group lands there
      expect(r.route(_h, _g1), RouteTo.everyday);
      expect(r.route(_h, null, open: true), RouteTo.vault);
      expect(r.route(_v, null, open: true), RouteTo.everyday);
      expect(r.route(_gone, null), RouteTo.dropped);
      expect(r.route(_gone, null, open: true), RouteTo.dropped);
      expect(r.route(_gone, _g1), RouteTo.everyday);
    });

    test('a hidden group\'s members write to the vault', () async {
      final w = await _World.make();
      await w.store.putHidden(
        'g3',
        kHiddenGroup,
        groupCard(const [RouterCard('member-only-one', 'o', 'x-m')]),
        1,
      );
      await w.router.load();
      expect(w.router.route('member-only-one', null), RouteTo.sealed);
      expect(w.router.route('member-only-one', _g1), RouteTo.everyday);
      expect(w.router.ids, containsAll([_h, 'member-only-one', _gone]));
      expect(w.router.listenFor, {'x-$_h': _h, 'x-m': 'member-only-one'});
    });

    test('an open vault takes what it holds before the list says so', () {
      final w = VaultRouter(_Store(), _Seal());
      return w.load().then((_) {
        bool held(String id) => id == 'new-in-vault';
        expect(w.route('new-in-vault', null), RouteTo.everyday);
        expect(
          w.route('new-in-vault', null, open: true, held: held),
          RouteTo.vault,
        );
        expect(
          w.route('someone-else', null, open: true, held: held),
          RouteTo.everyday,
        );
      });
    });

    test('while sealed rows wait, new ones queue behind them', () async {
      final w = await _World.make();
      await w.router.seal(Unsealed(_h, 'x', false, 1), uid: 'q1');
      expect(w.router.route(_h, null, open: true), RouteTo.sealed);
      final got = await w.router.openOldest('priv-A');
      expect(got.single.$2!.wire, 'x');
      await w.router.forgetSealed(got.single.$1);
      expect(await w.router.openOldest('priv-A'), isEmpty);
      expect(w.router.route(_h, null, open: true), RouteTo.vault);
    });

    test('no list, no key: everything is everyday and nothing seals', () async {
      final w = await _World.make(hidden: false);
      expect(w.router.ids, isEmpty);
      expect(w.router.route(_h, null), RouteTo.everyday);
      expect(await w.router.seal(Unsealed(_h, 'x', false, 1)), isFalse);
      expect(w.store.inbox, isEmpty);
    });

    test('a row sealed to another vault does not open', () async {
      final w = await _World.make();
      await w.router.seal(Unsealed(_h, 'x', true, 7));
      final got = await w.router.openOldest('priv-B');
      expect(got.single.$2, isNull);
      final ok = await w.router.openOldest('priv-A');
      expect(ok.single.$2!.backPair, isTrue);
      expect(ok.single.$2!.at, 7);
    });
  });

  group('what waits sealed', () {
    Future<VaultRouter> capped(
      _World w, {
      int n = 3,
      int bytes = 1 << 20,
    }) async {
      final r = VaultRouter(
        w.store,
        w.seal,
        maxSealed: n,
        maxSealedBytes: bytes,
      );
      await r.load();
      return r;
    }

    test('keeps at most the cap, the oldest going first', () async {
      final w = await _World.make();
      final r = await capped(w);
      for (var i = 0; i < 5; i++) {
        expect(await r.seal(Unsealed(_h, 'w$i', false, i), uid: 'u$i'), isTrue);
      }
      expect([for (final x in w.store.inbox) x['uid']], ['u2', 'u3', 'u4']);
    });

    test('keeps at most five thousand as the app has it', () async {
      final w = await _World.make();
      for (var i = 0; i <= kMaxSealed; i++) {
        await w.router.seal(Unsealed(_h, 'x', false, i), uid: 'u$i');
      }
      expect(w.store.inbox.length, kMaxSealed);
      expect(w.store.inbox.first['uid'], 'u1');
      expect(w.store.inbox.last['uid'], 'u$kMaxSealed');
    });

    test('holds the bytes to the cap, the oldest going first', () async {
      final w = await _World.make();
      final r = await capped(w, n: 100, bytes: 1000);
      final big = 'b' * 300;
      for (var i = 0; i < 5; i++) {
        await r.seal(Unsealed(_h, big, false, i), uid: 'u$i');
      }
      final sizes = [
        for (final x in w.store.inbox) (x['sealed'] as List<int>).length,
      ];
      expect(sizes.fold(0, (a, b) => a + b), lessThanOrEqualTo(1000));
      expect(w.store.inbox.last['uid'], 'u4');
      expect(w.store.inbox.first['uid'], isNot('u0'));
    });

    test('one arrival past the cap on its own is not kept, and takes '
        'nothing with it', () async {
      final w = await _World.make();
      final r = await capped(w, bytes: 100);
      expect(await r.seal(Unsealed(_h, 'x', false, 1), uid: 'u0'), isTrue);
      expect(await r.seal(Unsealed(_h, 'b' * 300, false, 2)), isFalse);
      expect([for (final x in w.store.inbox) x['uid']], ['u0']);
    });

    test('opens in order after a trim', () async {
      final w = await _World.make();
      final r = await capped(w, n: 2);
      for (var i = 0; i < 4; i++) {
        await r.seal(Unsealed(_h, 'w$i', false, i), uid: 'u$i');
      }
      final got = await r.openOldest('priv-A');
      expect([for (final (_, u) in got) u!.wire], ['w2', 'w3']);
    });
  });

  test('no one the vault blocked is listened for', () async {
    final w = await _World.make();
    await w.store.putHidden(
      'blocked-hidden-one',
      kHiddenPeer,
      peerCard(
        const RouterCard('blocked-hidden-one', 'o-b', 'x-b', blocked: true),
      ),
      1,
    );
    await w.router.load();
    expect(w.router.listenFor, {'x-$_h': _h});
    expect(w.router.keeps('blocked-hidden-one'), isTrue);
  });

  group('while the vault is shut', () {
    test('a message changes nothing and is sealed once', () async {
      final w = await _World.make();
      await w.onion(
        _h,
        await wrapMessage('meet at the bridge', msgUid: 'a', sender: _as(_h)),
      );
      // no notification, no redraw, no badge, no list, no search, no row
      expect(w.io.rang, isEmpty);
      expect(w.redrawn, 0);
      expect(w.app.chatRevOf(_h), 0);
      expect(w.app.contacts, isEmpty);
      expect(w.app.pendingCount, 0);
      expect(w.everydayRows, isEmpty);
      expect(w.live.msgs, isEmpty);
      expect(w.live.people.keys, [_v]);
      expect(w.live.calls.where((c) => c.startsWith('saveMessage')), isEmpty);
      expect(w.vault.calls, isEmpty);
      // one sealed row, with only the uid readable
      expect(w.store.inbox, hasLength(1));
      final row = w.store.inbox.single;
      expect(row['uid'], 'a');
      final raw = latin1.decode(row['sealed'] as List<int>);
      expect(raw, isNot(contains('bridge')));
      expect(raw, isNot(contains(_h)));
      // the cipher is spent, so it is marked seen
      expect(w.live.seen, hasLength(1));
    });

    test('the tick goes as for a visible message, to the card', () async {
      final w = await _World.make();
      await w.onion(_h, await wrapMessage('hi', msgUid: 'a', sender: _as(_h)));
      expect(w.io.ticksFor('a'), ['relay x-$_h']);
      // no tick for a group message, a reaction or a tick
      await w.onion(
        _h,
        await wrapMessage('all', msgUid: 'g', groupId: _g2, sender: _as(_h)),
      );
      await w.onion(
        _h,
        await wrapMessage(
          '',
          reaction: const ReactionFrame(targetUid: 'a', emoji: 'x'),
          sender: _as(_h),
        ),
      );
      await w.onion(_h, await wrapMessage('', deliveredUid: 'mine'));
      expect(w.io.ticksFor('g'), isEmpty);
      expect(w.io.sent, hasLength(1));
      expect(w.store.inbox, hasLength(4));
    });

    test('a file in slices ticks once every slice is in', () async {
      final w = await _World.make();
      final b64 = base64Encode(List<int>.generate(20, (i) => i));
      final parts = [
        b64.substring(0, 12),
        b64.substring(12, 24),
        b64.substring(24),
      ];
      for (final i in [0, 2]) {
        await w.onion(
          _h,
          await wrapMessage(
            '',
            msgUid: 'p',
            mediaId: 'p',
            chunkIndex: i,
            chunkTotal: 3,
            imageB64: parts[i],
            sender: _as(_h),
          ),
        );
      }
      expect(w.io.ticksFor('p'), isEmpty);
      // a slice sent twice is kept once
      await w.onion(
        _h,
        await wrapMessage(
          '',
          msgUid: 'p',
          mediaId: 'p',
          chunkIndex: 2,
          chunkTotal: 3,
          imageB64: parts[2],
          sender: _as(_h),
        ),
      );
      expect(w.store.inbox, hasLength(2));
      await w.onion(
        _h,
        await wrapMessage(
          '',
          msgUid: 'p',
          mediaId: 'p',
          chunkIndex: 1,
          chunkTotal: 3,
          imageB64: parts[1],
          sender: _as(_h),
        ),
      );
      expect(w.io.ticksFor('p'), ['relay x-$_h']);
      expect(w.store.inbox, hasLength(3));
      expect(w.everydayRows, isEmpty);
      expect(w.live.chunks, isEmpty);
    });

    test('a copy by uid is sealed once and ticked again', () async {
      final w = await _World.make();
      final plain = await wrapMessage('once', msgUid: 'd', sender: _as(_h));
      await w.onion(_h, plain);
      await w.onion(_h, plain);
      expect(w.store.inbox, hasLength(1));
      // the second tick is held back by the per-uid throttle, as for any
      // copy
      expect(w.io.ticksFor('d'), hasLength(1));
    });

    test('someone a vault that went held is dropped without a word', () async {
      final w = await _World.make();
      await w.onion(
        _gone,
        await wrapMessage('are you there', msgUid: 'z', sender: _as(_gone)),
      );
      expect(w.store.inbox, isEmpty);
      expect(w.everydayRows, isEmpty);
      expect(w.io.sent, isEmpty);
      expect(w.io.rang, isEmpty);
      expect(w.redrawn, 0);
      expect(w.live.seen, hasLength(1));
    });
  });

  group('every way in', () {
    test('the onion lane tries the router after the everyday rows', () async {
      final w = await _World.make();
      await w.onion(_h, await wrapMessage('hi', msgUid: 'a', sender: _as(_h)));
      final order = [for (final t in w.io.tries) t.split(' ').first];
      expect(order.indexOf(_v), lessThan(order.indexOf(_h)));
      expect(w.store.inbox, hasLength(1));
      expect(w.everydayRows, isEmpty);
    });

    test('the relay lane, on the key and on the first-contact lane', () async {
      final w = await _World.make();
      await w.app.subscribeKnown();
      expect(w.io.listened, containsAll(['x-$_v', 'x-$_h']));
      w.io.opens['r1'] = (
        _h,
        await wrapMessage('by key', msgUid: 'k', sender: _as(_h)),
      );
      w.io.opens['r2'] = (
        _h,
        await wrapMessage('by lane', msgUid: 'l', sender: _as(_h)),
      );
      await w.app.receiveRelay([
        (peer: 'x-$_h', cipher: 'r1'),
        (peer: 'firstcontact', cipher: 'r2'),
      ]);
      await _settle();
      expect(w.io.tries.first, '$_h r1');
      expect(w.store.inbox.map((r) => r['uid']), ['k', 'l']);
      expect(w.everydayRows, isEmpty);
      expect(w.redrawn, 0);
      expect(w.live.seen, hasLength(2));
    });

    test(
      'a first contact from a hidden sender files nothing everyday',
      () async {
        final w = await _World.make();
        final plain = await wrapMessage(
          'new phone, same me',
          msgUid: 'f',
          sender: _as(_h),
        );
        w.io.firstContact = (
          haloId: _h,
          plain: plain,
          env: unwrapMessage(plain),
        );
        final prekey = base64Encode([3, 1, 2, 3]);
        await w.app.receiveOnion([prekey]);
        await _settle();
        expect(w.everydayRows, isEmpty);
        expect(w.live.people.containsKey(_h), isFalse);
        expect(w.store.inbox, hasLength(1));
        expect(w.live.seen, hasLength(1));
        expect(w.redrawn, 0);
        // and once the vault opens, it files them there, as everyday would
        await w.open();
        await w.app.drainSealed(w.vault, 'priv-A');
        expect(w.vault.calls, contains('upsertContact:$_h'));
        expect(w.vault.msg('f'), isNotNull);
        expect(w.everydayRows, isEmpty);
      },
    );

    test('the deleted-peer fallback skips the router', () async {
      final w = await _World.make();
      w.io.sessions = [_v, _h, _gone, 'parked-old-friend'];
      // nothing opens this one: every kept id is tried once, never again
      await w.app.receiveOnion(['junk']);
      await _settle();
      expect(w.io.triesOf(_h), 1);
      expect(w.io.triesOf(_gone), 1);
      expect(w.io.triesOf('parked-old-friend'), 1);
      expect(w.everydayRows, isEmpty);
      // someone the everyday side let go still comes back as a request
      w.io.opens['back'] = (
        'parked-old-friend',
        await wrapMessage('hello again', sender: _as('parked-old-friend')),
      );
      await w.app.receiveOnion(['back']);
      expect(w.live.calls, contains('upsertContact:parked-old-friend'));
      expect(w.live.people['parked-old-friend']!['accepted'], 0);
    });

    test('an introduction naming a hidden contact files nothing', () async {
      final w = await _World.make();
      await w.onion(
        _v,
        await wrapMessage(
          '',
          intro: IntroFrame(haloId: _h, onion: 'o-$_h', xPub: 'x-$_h'),
          sender: _as(_v),
        ),
      );
      expect(w.live.people.containsKey(_h), isFalse);
      expect(w.live.vouches, isEmpty);
      expect(w.store.inbox, isEmpty);
      // someone new is introduced as always
      await w.onion(
        _v,
        await wrapMessage(
          '',
          intro: const IntroFrame(
            haloId: 'someone-new-here',
            onion: 'o-n',
            xPub: 'x-n',
          ),
          sender: _as(_v),
        ),
      );
      expect(w.live.people['someone-new-here']!['accepted'], 0);
      expect(w.live.vouches['someone-new-here'], {_v});
    });

    test('a hidden contact in an everyday group lands there', () async {
      final w = await _World.make();
      await w.onion(
        _h,
        await wrapMessage('in the open', msgUid: 'o1', groupId: _g1),
      );
      expect(w.live.msg('o1'), isNotNull);
      expect(w.store.inbox, isEmpty);
      expect(w.io.rang, ['group:$_g1']);
    });
  });

  group('when the vault opens', () {
    test('every kind sealed while shut goes in, in order', () async {
      final w = await _World.make();
      final h = _as(_h);
      final b64 = base64Encode(List<int>.generate(20, (i) => 200 - i));
      final parts = [
        b64.substring(0, 12),
        b64.substring(12, 24),
        b64.substring(24),
      ];
      final frames = [
        await wrapMessage('first', msgUid: 'a', sender: h),
        for (final i in [0, 1, 2])
          await wrapMessage(
            '',
            msgUid: 'p',
            mediaId: 'p',
            chunkIndex: i,
            chunkTotal: 3,
            imageB64: parts[i],
            sender: h,
          ),
        await wrapMessage(
          '',
          reaction: const ReactionFrame(targetUid: 'a', emoji: 'ok'),
          sender: h,
        ),
        await wrapMessage(
          '',
          edit: const EditFrame(targetUid: 'a', newText: 'first, edited'),
          sender: h,
        ),
        await wrapMessage('second', msgUid: 'b', sender: h),
        await wrapMessage('', unsend: 'b', sender: h),
        await wrapMessage(
          'lunch?',
          msgUid: 'q',
          groupId: _g2,
          poll: const PollSpec(options: ['yes', 'no']).toWire(),
          sender: h,
        ),
        await wrapMessage(
          '',
          groupId: _g2,
          vote: const VoteFrame(pollUid: 'q', choices: [0], seq: 5),
          sender: h,
        ),
        await wrapMessage(
          '',
          groupId: _g2,
          pollClose: const PollCloseFrame(
            pollUid: 'q',
            finalVotes: {
              _h: [0],
              'me': [1],
            },
          ),
          sender: h,
        ),
        await wrapMessage(
          '',
          pin: const PinFrame(targetUid: 'a', pinned: true),
          sender: h,
        ),
        await wrapMessage(
          '',
          groupId: _g2,
          groupControl: const GroupControl(type: 'rename', name: 'G2 now'),
          sender: h,
        ),
      ];
      for (final f in frames) {
        await w.onion(_h, f);
      }
      expect(w.store.inbox, hasLength(frames.length));
      expect(w.everydayRows, isEmpty);
      expect(w.io.rang, isEmpty);
      final ticksWhileShut = w.io.sent.length;
      expect(w.io.ticksFor('a'), hasLength(1));
      expect(w.io.ticksFor('p'), hasLength(1));
      expect(w.io.ticksFor('b'), hasLength(1));

      await w.open();
      await w.app.drainSealed(w.vault, 'priv-A');
      expect(w.store.inbox, isEmpty);
      final a = w.vault.msg('a')!;
      expect(a['plaintext'], 'first, edited');
      expect(a['pinned'], 1);
      expect(w.vault.reactions['a'], {_h: 'ok'});
      expect(w.vault.msg('b'), isNull);
      final p = w.vault.msg('p')!;
      final path = p['media_path'] as String;
      expect(path, contains('media_v'));
      expect(
        File(path).readAsBytesSync(),
        List<int>.generate(20, (i) => 200 - i),
      );
      expect(w.vault.chunks, isEmpty);
      expect(PollSpec.parse(w.vault.msg('q')!['poll'])!.closed, isTrue);
      expect(w.vault.votes['q']!.map((k, v) => MapEntry(k, v.$1)), {
        _h: [0],
        'me': [1],
      });
      expect(w.vault.groupRows[_g2]!['name'], 'G2 now');
      expect(w.vault.people[_h]!['unread'], greaterThan(0));
      // what came while shut does not ring now, and is not ticked twice
      expect(w.io.rang, isEmpty);
      expect(w.io.sent, hasLength(ticksWhileShut));
      expect(w.everydayRows, isEmpty);
      // the home lists were read again
      expect(w.app.contacts.map((c) => c.haloId), contains(_h));
    });

    test('a timer that ran out while shut is dropped', () async {
      final w = await _World.make();
      final h = _as(_h);
      final at = DateTime.now().millisecondsSinceEpoch - 60000;
      await w.router.seal(
        Unsealed(
          _h,
          await wrapMessage(
            'gone soon',
            msgUid: 't',
            burnSeconds: 5,
            sender: h,
          ),
          false,
          at,
        ),
        uid: 't',
      );
      await w.router.seal(
        Unsealed(
          _h,
          await wrapMessage(
            'here a while',
            msgUid: 'u',
            burnSeconds: 3600,
            sender: h,
          ),
          false,
          at,
        ),
        uid: 'u',
      );
      await w.open();
      await w.app.drainSealed(w.vault, 'priv-A');
      expect(w.vault.msg('t'), isNull);
      // the clock ran from when it came, not from now
      expect(w.vault.msg('u')!['burn_at'], at + 3600 * 1000);
      expect(w.store.inbox, isEmpty);
    });

    test('every kind opened from the seal keeps the time it came', () async {
      final w = await _World.make();
      final h = _as(_h);
      // sealed five minutes before the vault opens, a second apart
      final t0 = DateTime.now().millisecondsSinceEpoch - 5 * 60000;
      int at(int i) => t0 + i * 1000;
      final b64 = base64Encode(List<int>.generate(20, (i) => i));
      final parts = [
        b64.substring(0, 12),
        b64.substring(12, 24),
        b64.substring(24),
      ];
      final frames = [
        await wrapMessage('first', msgUid: 'a', sender: h),
        for (final i in [0, 1, 2])
          await wrapMessage(
            '',
            msgUid: 'p',
            mediaId: 'p',
            chunkIndex: i,
            chunkTotal: 3,
            imageB64: parts[i],
            sender: h,
          ),
        await wrapMessage(
          '',
          reaction: const ReactionFrame(targetUid: 'a', emoji: 'ok'),
          sender: h,
        ),
        await wrapMessage(
          '',
          edit: const EditFrame(targetUid: 'a', newText: 'first, edited'),
          sender: h,
        ),
        await wrapMessage(
          '',
          pin: const PinFrame(targetUid: 'a', pinned: true),
          sender: h,
        ),
        await wrapMessage('x', msgUid: 's', sticker: 'fokia:17:1', sender: h),
        await wrapMessage('all of us', msgUid: 'g', groupId: _g2, sender: h),
        await wrapMessage(
          'lunch?',
          msgUid: 'q',
          groupId: _g2,
          poll: const PollSpec(options: ['yes', 'no']).toWire(),
          sender: h,
        ),
        await wrapMessage(
          '',
          groupId: _g2,
          vote: const VoteFrame(pollUid: 'q', choices: [0], seq: 5),
          sender: h,
        ),
        await wrapMessage(
          '',
          groupId: _g2,
          groupControl: const GroupControl(type: 'rename', name: 'G2 now'),
          sender: h,
        ),
        await wrapMessage(
          '',
          intro: const IntroFrame(
            haloId: 'someone-new-here',
            onion: 'o-n',
            xPub: 'x-n',
          ),
          sender: h,
        ),
      ];
      for (var i = 0; i < frames.length; i++) {
        await w.router.seal(Unsealed(_h, frames[i], false, at(i)));
      }
      // an everyday arrival meanwhile is stamped as it comes
      final before = DateTime.now().millisecondsSinceEpoch;
      await w.onion(
        _v,
        await wrapMessage('meanwhile', msgUid: 'v', sender: _as(_v)),
      );
      expect(
        w.live.msg('v')!['sent_at'],
        inInclusiveRange(before, DateTime.now().millisecondsSinceEpoch),
      );

      await w.open();
      await w.app.drainSealed(w.vault, 'priv-A');
      expect(w.store.inbox, isEmpty);
      // in order, each at its frame's time, a file at its last slice's
      expect(w.vault.msgs.map((m) => m['msg_uid']), ['a', 'p', 's', 'g', 'q']);
      expect(w.vault.msgs.map((m) => m['sent_at']), [
        at(0),
        at(3),
        at(7),
        at(8),
        at(9),
      ]);
      final a = w.vault.msg('a')!;
      expect(a['plaintext'], 'first, edited');
      expect(a['pinned_at'], at(6));
      expect(w.vault.reactedAt['a $_h'], at(4));
      expect(w.vault.msg('s')!['sticker'], isNotNull);
      expect(w.vault.groupRows[_g2]!['name'], 'G2 now');
      expect(w.vault.vouchedAt['someone-new-here $_h'], at(12));
      // home: the hidden chat at its last message, under the everyday one
      // that came after it
      expect(w.app.contacts.map((c) => c.haloId), [_v, _h]);
      final row = w.app.contacts.last;
      expect(row.when!.millisecondsSinceEpoch, at(7));
      // with the vault open, an arrival is stamped as it comes
      final open = DateTime.now().millisecondsSinceEpoch;
      await w.onion(_h, await wrapMessage('now', msgUid: 'n', sender: h));
      expect(
        w.vault.msg('n')!['sent_at'],
        inInclusiveRange(open, DateTime.now().millisecondsSinceEpoch),
      );
      expect(w.store.inbox, isEmpty);
    });

    test('nothing opened from the seal is ticked again', () async {
      final w = await _World.make();
      final h = _as(_h);
      // a tick already went for each of these when they came
      await w.router.seal(
        Unsealed(
          _h,
          await wrapMessage('one', msgUid: 'm1', sender: h),
          false,
          1,
        ),
        uid: 'm1',
      );
      final b64 = base64Encode(const [1, 2, 3, 4, 5, 6]);
      for (final i in [0, 1]) {
        await w.router.seal(
          Unsealed(
            _h,
            await wrapMessage(
              '',
              msgUid: 'm2',
              mediaId: 'm2',
              chunkIndex: i,
              chunkTotal: 2,
              imageB64: i == 0 ? b64.substring(0, 4) : b64.substring(4),
              sender: h,
            ),
            false,
            1,
          ),
          uid: 'm2',
          part: i,
        );
      }
      await w.open();
      await w.app.drainSealed(w.vault, 'priv-A');
      expect(w.vault.msg('m1'), isNotNull);
      expect(w.vault.msg('m2'), isNotNull);
      expect(w.io.sent, isEmpty);
      expect(w.io.rang, isEmpty);
    });

    test('one the vault already has is not kept twice', () async {
      final w = await _World.make();
      final plain = await wrapMessage('once', msgUid: 'd', sender: _as(_h));
      await w.onion(_h, plain);
      await w.open();
      await w.app.drainSealed(w.vault, 'priv-A');
      // the sender went round again after the vault closed
      w.close();
      await w.router.seal(Unsealed(_h, plain, false, 1), uid: 'd');
      await w.open();
      await w.app.drainSealed(w.vault, 'priv-A');
      expect(w.vault.msgs.where((m) => m['msg_uid'] == 'd'), hasLength(1));
      expect(w.store.inbox, isEmpty);
    });

    test('an engine that fails keeps every row sealed', () async {
      final w = await _World.make();
      await w.onion(
        _h,
        await wrapMessage('kept', msgUid: 'k', sender: _as(_h)),
      );
      await w.open();
      w.seal.broken = true;
      await expectLater(
        w.app.drainSealed(w.vault, 'priv-A'),
        throwsA(isA<StateError>()),
      );
      expect(w.store.inbox, hasLength(1));
      w.seal.broken = false;
      await w.app.drainSealed(w.vault, 'priv-A');
      expect(w.vault.msg('k'), isNotNull);
      expect(w.store.inbox, isEmpty);
    });

    test('a vault that closes part way keeps the rest sealed', () async {
      final w = await _World.make();
      for (final u in ['a', 'b', 'c']) {
        await w.router.seal(
          Unsealed(
            _h,
            await wrapMessage(u, msgUid: u, sender: _as(_h)),
            false,
            1,
          ),
          uid: u,
        );
      }
      await w.open();
      // the vault goes as the first one lands
      w.vault.onSave = w.close;
      await w.app.drainSealed(w.vault, 'priv-A');
      expect(w.vault.msgs.map((m) => m['msg_uid']), ['a']);
      expect(w.store.inbox.map((r) => r['uid']), ['b', 'c']);
    });
  });

  group('while the vault is open', () {
    test('a hidden chat rings like any other', () async {
      final w = await _World.make(open: true);
      await w.onion(_h, await wrapMessage('hi', msgUid: 'o', sender: _as(_h)));
      expect(w.store.inbox, isEmpty);
      expect(w.vault.msg('o'), isNotNull);
      expect(w.vault.people[_h]!['unread'], 1);
      expect(w.io.rang, [_h]);
      expect(w.io.ticksFor('o'), ['relay x-$_h']);
      expect(w.redrawn, greaterThan(0));
      expect(w.everydayRows, isEmpty);
      // and a hidden group
      await w.onion(
        _h,
        await wrapMessage('all of us', msgUid: 'og', groupId: _g2),
      );
      expect(w.vault.msg('og'), isNotNull);
      expect(w.io.rang, [_h, 'group:$_g2']);
      // an everyday contact as always
      await w.onion(_v, await wrapMessage('yo', msgUid: 'v', sender: _as(_v)));
      expect(w.live.msg('v'), isNotNull);
      expect(w.io.rang, [_h, 'group:$_g2', _v]);
      expect(w.io.ticksFor('v'), ['relay x-$_v']);
    });
  });

  group('with no vault', () {
    test('everything lands in the everyday container as before', () async {
      final w = await _World.make(hidden: false);
      await w.onion(_h, await wrapMessage('hi', msgUid: 'h1', sender: _as(_h)));
      await w.onion(_v, await wrapMessage('yo', msgUid: 'v1', sender: _as(_v)));
      expect(w.store.inbox, isEmpty);
      expect(w.live.msg('v1'), isNotNull);
      expect(w.io.rang, contains(_v));
      expect(w.io.ticksFor('v1'), ['relay x-$_v']);
      expect(w.vault.calls, isEmpty);
    });
  });
}
