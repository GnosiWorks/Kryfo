// SPDX-License-Identifier: GPL-3.0-or-later
// stand-ins for what the receive side reaches: the router's store and seal,
// signal and the engine as the app calls them, and a database kept in maps
// that notes every call. anything else they are asked fails the test
import 'dart:convert';
import 'dart:typed_data';

import 'package:kryfo/container.dart';
import 'package:kryfo/group_media_send.dart' show groupOwedGap;
import 'package:kryfo/main.dart'
    show AppIo, HaloDb, groupUnsendOf, groupUnsendRow;
import 'package:kryfo/media_resend.dart';
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
  // no route reaches anyone: every send says so
  var down = false;

  @override
  Future<String> relaySend(String xPub, String cipher) async {
    if (down) return 'error: down';
    sent.add(('relay $xPub', cipher));
    return 'ok';
  }

  @override
  Future<String> onionSend(String onion, String cipher) async {
    if (down) return 'error: down';
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
  }) async {
    rang.add(payload ?? title);
    shown.add((title, body));
    burns.add(burnAt);
  }

  // when each notification is to burn, null for one that does not
  final burns = <int?>[];

  // what each notification said
  final shown = <(String, String)>[];

  // messages whose notification was taken down
  final unrangMessages = <String>[];
  @override
  Future<void> unnotifyMessage(String msgUid) async =>
      unrangMessages.add(msgUid);

  // what was taken out of the shade, by payload
  final unrang = <String>[];
  @override
  Future<void> unnotify(String payload) async => unrang.add(payload);
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
  // who sent each file's slices, and when its last one came
  final chunkFrom = <String, String>{};
  final chunkAt = <String, int>{};
  var _clock = 0;
  final seen = <String>{};
  final held = <String>[];
  // what was held, row by row, as heldOf hands it back
  final heldRows = <String, List<({int id, String cipher})>>{};
  var _heldId = 0;
  Map<String, List<String>> get heldCiphers => {
    for (final e in heldRows.entries)
      if (e.value.isNotEmpty) e.key: [for (final r in e.value) r.cipher],
  };
  final vouches = <String, Set<String>>{};
  // when each vouch and reaction was stamped
  final vouchedAt = <String, int?>{};
  final reactedAt = <String, int?>{};
  final delivered = <String>{};
  final shields = <String, Map<String, Object?>>{};
  // called after each message is kept
  void Function()? onSave;
  // called as a message is about to be kept
  void Function()? beforeSave;

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
    // a parked row comes back on any touch, as the real one does
    if (p['archived'] == 1 && p['accepted'] == 0) p['archived'] = 0;
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
  // the rule kAskedRows writes in sql
  @override
  Future<bool> askedBefore(String haloId) async {
    final p = people[haloId];
    final asked =
        p != null &&
        p['accepted'] == 0 &&
        p['blocked'] != 1 &&
        (p['archived'] == 1 ||
            held.contains(haloId) ||
            vouches.containsKey(haloId) ||
            msgs.any((m) => m['peer_id'] == haloId && m['group_id'] == null));
    return _hit('askedBefore', haloId, asked);
  }

  @override
  Future<bool> isAccepted(String haloId) async =>
      _hit('isAccepted', haloId, people[haloId]?['accepted'] == 1);
  @override
  Future<bool> isVouched(String haloId) async =>
      _hit('isVouched', haloId, vouches.containsKey(haloId));
  @override
  Future<bool> isBlocked(String haloId) async =>
      _hit('isBlocked', haloId, people[haloId]?['blocked'] == 1);
  // each block's span, and the uids of what came while one held, as the
  // real tables keep them
  final blockSpans = <String, List<(int, int?)>>{};
  final blockedDrops = <String, Set<String>>{};
  @override
  Future<void> setBlocked(String haloId, bool blocked) async {
    _hit('setBlocked', haloId, null);
    people[haloId]?['blocked'] = blocked ? 1 : 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final spans = blockSpans[haloId] ??= [];
    final open = spans.indexWhere((s) => s.$2 == null);
    if (blocked && open < 0) spans.add((now, null));
    if (!blocked && open >= 0) spans[open] = (spans[open].$1, now);
  }

  @override
  Future<bool> blockedAt(String haloId, int at) async => [
    ...?blockSpans[haloId],
  ].any((s) => s.$1 <= at && (s.$2 == null || s.$2! > at));
  @override
  Future<void> noteBlockedDrop(String haloId, String uid) async =>
      (blockedDrops[haloId] ??= {}).add(uid);
  @override
  Future<bool> droppedWhileBlocked(String haloId, String uid) async =>
      blockedDrops[haloId]?.contains(uid) ?? false;
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
    (heldRows[peerId] ??= []).add((id: ++_heldId, cipher: cipher));
  }

  @override
  Future<List<({int id, String cipher})>> heldOf(String peerId) async =>
      _hit('heldOf', peerId, [...?heldRows[peerId]]);

  @override
  Future<List<String>> heldOfAccepted() async => _hit('heldOfAccepted', null, [
    for (final e in heldRows.entries)
      if (e.value.isNotEmpty &&
          people[e.key]?['accepted'] == 1 &&
          people[e.key]?['blocked'] != 1)
        e.key,
  ]);

  @override
  Future<void> forgetHeld(int id) async {
    _hit('forgetHeld', id, null);
    for (final e in heldRows.entries) {
      if (e.value.any((r) => r.id == id)) {
        e.value.removeWhere((r) => r.id == id);
        held.remove(e.key);
      }
    }
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
  Future<void> markSent(String msgUid) async => _hit('markSent', msgUid, null);

  // as the real one: an own timed row starts burning once, others are left
  @override
  Future<int?> lightBurn(String msgUid) async {
    _hit('lightBurn', msgUid, null);
    for (final m in msgs) {
      if (m['msg_uid'] != msgUid || m['direction'] != 'out') continue;
      final lit = (m['burn_at'] as num?)?.toInt();
      final secs = (m['burn_secs'] as num?)?.toInt();
      if (lit != null || secs == null) return lit;
      final at = DateTime.now().millisecondsSinceEpoch + secs * 1000;
      m['burn_at'] = at;
      return at;
    }
    return null;
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
    beforeSave?.call();
    _hit('saveMessage', msgUid ?? peerId, null);
    msgs.add({
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
      'burn_at': burnAt,
      'burn_secs': burnSecs,
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
    // a room's take-backs go with it, any other group's stay
    final room = groupRows.remove(groupId)?['room_pub'] != null;
    members.remove(groupId);
    ctlOut.removeWhere(
      (r) =>
          r['group_id'] == groupId && (room || groupUnsendOf(r['ctl']) == null),
    );
    rosterStamps.remove(groupId);
    rosterGoneKeys.remove(groupId);
    roomSeqs.remove(groupId);
  }

  // ---- group controls on their way to each member ----
  final ctlOut = <Map<String, Object?>>[];
  var _ctlId = 0;

  // what [member] is still to get, as the controls' types
  List<String> ctlTo(String member, {String? groupId}) => [
    for (final r in ctlOut)
      if (r['member'] == member &&
          (groupId == null || r['group_id'] == groupId))
        groupUnsendOf(r['ctl']) != null
            ? 'unsend'
            : GroupControl.fromWire(jsonDecode(r['ctl'] as String))!.type,
  ];

  @override
  Future<void> queueGroupCtl(
    String groupId,
    Iterable<String> who,
    GroupControl ctl, {
    required int now,
  }) async {
    _hit('queueGroupCtl', groupId, null);
    for (final m in who) {
      ctlOut.add({
        'id': ++_ctlId,
        'group_id': groupId,
        'member': m,
        'ctl': jsonEncode(ctl.toWire()),
        'since': now,
        'tries': 0,
        'next_at': now,
      });
    }
  }

  @override
  Future<void> queueGroupUnsend(
    String groupId,
    Iterable<String> who,
    String uid, {
    required int now,
  }) async {
    _hit('queueGroupUnsend', groupId, null);
    final body = jsonEncode(groupUnsendRow(uid));
    for (final m in who) {
      if (ctlOut.any(
        (r) => r['group_id'] == groupId && r['member'] == m && r['ctl'] == body,
      )) {
        continue;
      }
      ctlOut.add({
        'id': ++_ctlId,
        'group_id': groupId,
        'member': m,
        'ctl': body,
        'since': now,
        'tries': 0,
        'next_at': now,
      });
    }
  }

  @override
  Future<List<Map<String, Object?>>> groupCtlOut() async => [
    for (final r in ctlOut) {...r},
  ];
  @override
  Future<List<Map<String, Object?>>> groupCtlFor(
    String groupId,
    String member,
  ) async => [
    for (final r in ctlOut)
      if (r['group_id'] == groupId && r['member'] == member) {...r},
  ];
  @override
  Future<void> triedGroupCtl(int id, int now) async {
    for (final r in ctlOut.where((r) => r['id'] == id)) {
      final tries = (r['tries'] as int) + 1;
      r['tries'] = tries;
      r['next_at'] = now + groupOwedGap(tries);
    }
  }

  @override
  Future<void> dropGroupCtl(int id) async =>
      ctlOut.removeWhere((r) => r['id'] == id);
  @override
  Future<Set<String>> groupCtlWaiting(String groupId) async => {
    for (final r in ctlOut)
      if (r['group_id'] == groupId) r['member'] as String,
  };
  @override
  Future<int> groupCtlDueNow(String member) async {
    var n = 0;
    for (final r in ctlOut.where((r) => r['member'] == member)) {
      r['next_at'] = 0;
      n++;
    }
    return n;
  }

  @override
  Future<int> groupOwedDueNow(String member) async => 0;

  // ---- the newest roster each group took ----
  final rosterStamps = <String, int>{};
  final rosterGoneKeys = <String, Set<String>>{};
  final roomSeqs = <String, int>{};

  @override
  Future<int> nextRoomSeq(String groupId) async =>
      roomSeqs[groupId] = (roomSeqs[groupId] ?? 0) + 1;

  @override
  Future<int> nextRosterStamp(String groupId, int now) async {
    final held = rosterStamps[groupId] ?? 0;
    return rosterStamps[groupId] = held + 1 > now ? held + 1 : now;
  }

  @override
  Future<bool> takeRosterStamp(String groupId, int stamp) async {
    if (stamp <= (rosterStamps[groupId] ?? 0)) return false;
    rosterStamps[groupId] = stamp;
    return true;
  }

  @override
  Future<Set<String>> rosterGone(String groupId) async => {
    ...?rosterGoneKeys[groupId],
  };
  @override
  Future<void> noteRosterGone(String groupId, Iterable<String> keys) async =>
      rosterGoneKeys.putIfAbsent(groupId, () => {}).addAll(keys);

  @override
  Future<List<Map<String, Object?>>> rooms() async => _hit('rooms', null, [
    for (final g in groupRows.values)
      if (g['room_pub'] != null) g,
  ]);
  // a file open, as a decoy is but while its files are swapped or wiped
  bool shut = false;
  @override
  bool get isOpen => !shut;
  @override
  Future<List<Map<String, Object?>>> expiredRooms(int now) async =>
      _hit('expiredRooms', null, [
        for (final g in groupRows.values)
          if (g['room_pub'] != null && (g['expires_at'] as int) <= now) g,
      ]);
  // the files a group's rows name
  final groupFiles = <String, List<String>>{};
  @override
  Future<List<String>> groupFilePaths(String groupId) async =>
      _hit('groupFilePaths', groupId, [...?groupFiles[groupId]]);
  @override
  Future<void> deleteGroupMessages(String groupId) async {
    _hit('deleteGroupMessages', groupId, null);
    _dropGroupRows(groupId);
  }

  @override
  Future<void> clearGroupConversation(String groupId) async {
    _hit('clearGroupConversation', groupId, null);
    _dropGroupRows(groupId);
  }

  void _dropGroupRows(String groupId) {
    for (final m in msgs.where((m) => m['group_id'] == groupId)) {
      reactions.remove(m['msg_uid']);
    }
    msgs.removeWhere((m) => m['group_id'] == groupId);
    groupFiles.remove(groupId);
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
    chunkAt[mediaId] = ++_clock;
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
    chunkAt.remove(mediaId);
    return _hit(
      'dropMediaChunks',
      mediaId,
      chunks.remove(mediaId)?.length ?? 0,
    );
  }

  @override
  Future<String?> mediaChunkSender(String mediaId) async =>
      _hit('mediaChunkSender', mediaId, chunkFrom[mediaId]);

  // the app's cap, unless a test sets a smaller one
  int unfinishedBytes = kUnfinishedBytes;
  int unfinishedFiles = kUnfinishedFiles;

  @override
  Future<Set<String>> trimUnfinishedMedia({
    Set<String> keep = const {},
    int bytes = kUnfinishedBytes,
    int files = kUnfinishedFiles,
  }) async {
    final drop = unfinishedPastCap(
      {
        for (final MapEntry(key: id, value: slices) in chunks.entries)
          id: (
            bytes: slices.values.fold(0, (n, s) => n + sliceWeight(s.length)),
            at: chunkAt[id] ?? 0,
          ),
      },
      bytes: unfinishedBytes,
      files: unfinishedFiles,
      keep: keep,
    );
    for (final id in drop) {
      chunks.remove(id);
      chunkBurn.remove(id);
      chunkFrom.remove(id);
      chunkAt.remove(id);
    }
    return _hit('trimUnfinishedMedia', drop.isEmpty ? null : drop.join(','), {
      ...drop,
    });
  }

  @override
  Future<int> filesInFlightFrom(String from, {String? except}) async => _hit(
    'filesInFlightFrom',
    from,
    chunkFrom.entries
        .where(
          (e) => e.value == from && e.key != except && wants[e.key] == from,
        )
        .length,
  );

  // a file's want row, by media id: who it is asked of
  final wants = <String, String>{};
  @override
  Future<void> noteMediaWant(
    String mediaId,
    String peerId,
    int total,
    bool canResend,
  ) async {
    _hit('noteMediaWant', mediaId, null);
    wants[mediaId] = peerId;
  }

  @override
  Future<void> dropMediaWant(String mediaId) async {
    _hit('dropMediaWant', mediaId, null);
    wants.remove(mediaId);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

SenderInfo asSender(String id) =>
    SenderInfo(haloId: id, edPub: 'ed-$id', onion: 'o-$id', xPub: 'x-$id');
