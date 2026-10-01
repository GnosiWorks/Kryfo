// SPDX-License-Identifier: GPL-3.0-or-later
// the guards around the developer chat, before any screen shows it: the
// signal store takes his pinned key and no other for a dev: address, and
// writes nothing when another comes; no id, card, member or sender from
// the wire becomes him or a dev chat, whatever it claims; the trial loops,
// the boot and the mode switch never reach the dev chat on the everyday
// lane; a link with his words opens his chat only with his key; what comes
// from him lands only while his chat runs, only as his chat may carry it,
// and only said by his pinned key. everyone else is received, filed and
// listened for as before. the databases,
// signal and the engine are stand-ins, as in the router's tests; the store
// runs real libsignal over a database kept in maps
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_gate.dart' show devGate;
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloDb,
        handleHaloUriAdded,
        haloUriV3,
        makePreKeyBundleB64,
        openDevChatLater,
        signalDecrypt,
        useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/polls.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

const _dev = 'dev:m1';
const _words = 'calm-mild-stone';
const _v = 'visible-plain-row';
const _w = 'woven-quiet-lamp';
const _me = 'my-own-words';

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

String _rnd64() {
  final r = Random.secure();
  return _hex([for (var i = 0; i < 32; i++) r.nextInt(256)]);
}

// a phone's signal store, bootstrapped the way the app does it, over a
// database kept in maps
Future<({SignalSession ss, MemDb db, String xPub})> _phone() async {
  final pair = Curve.generateKeyPair();
  final xPub = pair.publicKey.serialize().sublist(1);
  final db = MemDb();
  final ss = SignalSession();
  await ss.bootstrap(
    database: db,
    xPubBytes: xPub,
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (ss: ss, db: db, xPub: _hex(xPub));
}

// the developer: his phone and the key the app pins from its card
late ({SignalSession ss, MemDb db, String xPub}) _marios;
late DevKey _m1;
// someone with his words and a key of their own
late ({SignalSession ss, MemDb db, String xPub}) _grinder;

SenderInfo _as(String id, {String? x}) =>
    SenderInfo(haloId: id, edPub: 'ed-$id', onion: 'o-$id', xPub: x ?? 'x-$id');

PreKeyBundle _bundleOf(String b64) {
  final j = jsonDecode(utf8.decode(base64Decode(b64))) as Map<String, dynamic>;
  Uint8List b(String k) => base64Decode(j[k] as String);
  return PreKeyBundle(
    j['registrationId'] as int,
    j['deviceId'] as int,
    j['preKeyId'] as int,
    Curve.decodePoint(b('preKeyPublic'), 0),
    j['signedPreKeyId'] as int,
    Curve.decodePoint(b('signedPreKeyPublic'), 0),
    b('signedPreKeySignature'),
    IdentityKey(Curve.decodePoint(b('identityKey'), 0)),
  );
}

SessionBuilder _builder(SignalSession ss, String to) => SessionBuilder(
  ss.sessionStore,
  ss.preKeyStore,
  ss.signedPreKeyStore,
  ss.identityStore,
  SignalProtocolAddress(to, 1),
);

SessionCipher _cipher(SignalSession ss, String to) => SessionCipher(
  ss.sessionStore,
  ss.preKeyStore,
  ss.signedPreKeyStore,
  ss.identityStore,
  SignalProtocolAddress(to, 1),
);

// what a store kept for an address, or wrote anywhere about it
List<Map<String, Object?>> _kept(MemDb db, String table, String address) => [
  for (final r in db.rows(table))
    if (r['address'] == address) r,
];

// signal and the engine as the receive side reaches them: what a cipher
// opens to, and a note of every call
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
  // whether a session is held with whoever is asked about
  bool held = true;
  @override
  Future<bool> hasSession(String peer) async => held;
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
  }) async => rang.add(payload ?? title);

  @override
  Future<void> unnotifyMessage(String msgUid) async {}

  @override
  Future<void> unnotify(String payload) async {}
}

// a database in memory: the rows the receive side reads and writes, and a
// note of every call. anything else it is asked fails the test

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
    'setKeyChanged',
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

  // the dev chat's own row, in a table of its own
  final dev = MemDb();
  @override
  DevChat get devChat => DevChat(() async => dev, shred: (_) async {});

  final roomRows = <String, Map<String, Object?>>{};
  @override
  Future<Map<String, Object?>?> roomByPub(String pub) async =>
      _hit('roomByPub', pub, roomRows[pub]);

  @override
  Future<void> setKeyChanged(String haloId, bool changed) async =>
      _hit('setKeyChanged', haloId, null);

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

// the router with nothing hidden
class _NoStore implements RouterStore {
  @override
  Future<List<Map<String, Object?>>> hidden() async => const [];
  @override
  Future<String?> meta(String k) async => null;
  @override
  Future<int> inboxCount() async => 0;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the router was asked for ${i.memberName}');
}

class _NoSeal implements VaultSeal {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the seal was asked for ${i.memberName}');
}

// a database of the contact rows the app's own code writes, kept in maps
class _Rows extends HaloDb {
  _Rows(this.mem);

  final MemDb mem;

  @override
  Future<Database> open() async => mem;
}

// a phone with two everyday contacts, V and W, and the dev chat's row
// fresh, as a new install has it
class _World {
  final live = _Mem(HaloContainer.everyday);
  final io = _Io();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    await devChatTables(w.live.dev);
    w.live.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    w.live.person(_w, onion: 'o-$_w', xpub: 'x-$_w');
    final router = VaultRouter(_NoStore(), _NoSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = _me;
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  // the chat after its first send: a contact row of its own, his key on it
  void started() => live.person(_dev, xpub: _m1.xPub);

  // a message on the onion lane, opened under [from]
  Future<void> onion(String from, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (from, plain);
    await app.receiveOnion([c]);
    await _settle();
  }

  // a first message from someone with no session yet, as [id]
  Future<void> firstContact(String id, {String? x}) async {
    final plain = await wrapMessage(
      'hello',
      msgUid: 'fc${_n++}',
      sender: _as(id, x: x),
    );
    io.firstContact = (haloId: id, plain: plain, env: unwrapMessage(plain));
    await app.receiveOnion([
      base64Encode([CiphertextMessage.prekeyType, _n++, 7, 7]),
    ]);
    await _settle();
  }

  // the calls of these names the everyday database was asked for
  List<String> wrote(Set<String> names) => [
    for (final c in live.calls)
      if (names.contains(c.split(':').first)) c,
  ];
}

// what was sent without being waited for gets there
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

const _cards = {'upsertContact', 'upsertContactStub', 'addVouch'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() async {
    docs = Directory.systemTemp.createTempSync('dev_guard_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    _marios = await _phone();
    _grinder = await _phone();
    _m1 = DevKey(
      keyId: 'm1',
      threeWords: _words,
      xPub: _marios.xPub,
      bundle: await makePreKeyBundleB64(_marios.ss),
      fc: _rnd64(),
    );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    useDevKeysForTest([_m1]);
  });

  tearDown(() => useDevKeysForTest(null));

  group('the signal store', () {
    final dev = SignalProtocolAddress(_dev, 1);

    // the app's own store, for the paths that reach it by name
    setUpAll(() async {
      final pair = Curve.generateKeyPair();
      await signalSession.bootstrap(
        database: MemDb(),
        xPubBytes: pair.publicKey.serialize().sublist(1),
        xPrivBytes: pair.privateKey.serialize(),
      );
    });

    test(
      'a dev: address takes the pinned key alone, and writes nothing',
      () async {
        final me = await _phone();
        final store = me.ss.identityStore;
        final his = IdentityKey(Curve.decodePoint(pinnedIdentity(_m1), 0));
        final theirs = _grinder.ss.identityKeyPair.getPublicKey();
        final log = me.db.log.length;
        for (final d in Direction.values) {
          expect(await store.isTrustedIdentity(dev, theirs, d), isFalse);
          expect(await store.isTrustedIdentity(dev, his, d), isTrue);
        }
        expect(await store.saveIdentity(dev, theirs), isFalse);
        expect(_kept(me.db, 'peer_identities', _dev), isEmpty);
        // no first use to trust, no warning, nothing written at all
        expect(me.db.log.skip(log), isEmpty);
        // a key already on file changes nothing either
        await me.db.insert('peer_identities', {
          'address': _dev,
          'identity_key': theirs.serialize(),
        });
        expect(
          await store.isTrustedIdentity(dev, theirs, Direction.receiving),
          isFalse,
        );
        expect(
          await store.isTrustedIdentity(dev, his, Direction.sending),
          isTrue,
        );
        // a retired key, or one gone from the list, is trusted for nothing
        useDevKeysForTest([
          DevKey(
            keyId: 'm1',
            threeWords: _words,
            xPub: _m1.xPub,
            bundle: _m1.bundle,
            fc: _m1.fc,
            status: DevKeyStatus.retired,
          ),
        ]);
        expect(
          await store.isTrustedIdentity(dev, his, Direction.sending),
          isFalse,
        );
        useDevKeysForTest(const []);
        expect(
          await store.isTrustedIdentity(dev, his, Direction.sending),
          isFalse,
        );
      },
    );

    test('the dev chat opens with his card and his key only', () async {
      final me = await _phone();
      final log = me.db.log.length;
      // someone else's card under the dev chat's address
      await expectLater(
        _builder(me.ss, _dev).processPreKeyBundle(
          _bundleOf(await makePreKeyBundleB64(_grinder.ss)),
        ),
        throwsA(isA<UntrustedIdentityException>()),
      );
      expect(_kept(me.db, 'sessions', _dev), isEmpty);
      expect(_kept(me.db, 'peer_identities', _dev), isEmpty);
      expect(me.db.log.skip(log).where((l) => l.contains('contacts')), isEmpty);
      // his own card builds it, and he reads and answers
      await _builder(me.ss, _dev).processPreKeyBundle(_bundleOf(_m1.bundle));
      final out = await _cipher(me.ss, _dev).encrypt(utf8.encode('hi'));
      final got = await _cipher(
        _marios.ss,
        'someone',
      ).decrypt(out as PreKeySignalMessage);
      expect(utf8.decode(got), 'hi');
      final back = await _cipher(
        _marios.ss,
        'someone',
      ).encrypt(utf8.encode('hello'));
      expect(
        utf8.decode(
          await _cipher(me.ss, _dev).decryptFromSignal(back as SignalMessage),
        ),
        'hello',
      );
      // a stranger writing as the dev chat is refused, and nothing written
      await _builder(
        _grinder.ss,
        'someone',
      ).processPreKeyBundle(_bundleOf(await makePreKeyBundleB64(me.ss)));
      final forged = await _cipher(
        _grinder.ss,
        'someone',
      ).encrypt(utf8.encode('it is me, marios'));
      final before = me.db.log.length;
      await expectLater(
        _cipher(me.ss, _dev).decrypt(forged as PreKeySignalMessage),
        throwsA(isA<UntrustedIdentityException>()),
      );
      expect(
        me.db.log.skip(before).where((l) => l.contains('contacts')),
        isEmpty,
      );
      expect(
        _kept(me.db, 'peer_identities', _dev).single['identity_key'],
        pinnedIdentity(_m1),
      );
    });

    test('everyone else: trust on first use, and the warning', () async {
      final me = await _phone();
      final store = me.ss.identityStore;
      final a = SignalProtocolAddress('amber-fox-run', 1);
      await me.db.insert('contacts', {
        'halo_id': 'amber-fox-run',
        'onion': '',
        'xpub': '',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
      });
      final first = _grinder.ss.identityKeyPair.getPublicKey();
      expect(
        await store.isTrustedIdentity(a, first, Direction.sending),
        isTrue,
      );
      await store.saveIdentity(a, first);
      final next = _marios.ss.identityKeyPair.getPublicKey();
      expect(
        await store.isTrustedIdentity(a, next, Direction.receiving),
        isTrue,
      );
      final row = me.db.rows('contacts').single;
      expect(row['key_changed'], 1);
      expect(row['verified'], 0);
    });

    test('a key that is not his never flags the dev chat', () async {
      final w = await _World.make();
      await _builder(
        _grinder.ss,
        'phone',
      ).processPreKeyBundle(_bundleOf(await makePreKeyBundleB64()));
      final forged = await _cipher(
        _grinder.ss,
        'phone',
      ).encrypt(utf8.encode('marios here'));
      final wire = base64Encode([forged.getType(), ...forged.serialize()]);
      expect(await signalDecrypt(_dev, wire, flagKeyChange: true), isNull);
      expect(w.live.calls.where((c) => c.startsWith('setKeyChanged')), isEmpty);
    });

    test('nothing is asked of him in the clear', () async {
      final w = await _World.make();
      // a bundle is at hand: without the guard the ask would go out
      expect(signalSession.ready, isTrue);
      w.io.held = false;
      w.started();
      w.live.vouches[_dev] = {_v};
      w.live.person('vouched-new-one', accepted: 0, xpub: 'x-vouched');
      w.live.vouches['vouched-new-one'] = {_v};
      await w.app.sendAcceptAck(_dev);
      await _settle();
      expect(w.io.sent, isEmpty);
      // anyone else's bundle swap still goes
      await w.app.sendAcceptAck('vouched-new-one');
      await _settle();
      expect(w.io.sent.single.$1, 'relay x-vouched');
      expect(w.io.sent.single.$2, contains('"halo_ctl":"bundle"'));
    });
  });

  group('the wire never makes him', () {
    test('a first contact with his words or key is dropped whole', () async {
      final w = await _World.make();
      await w.firstContact(_words);
      await w.firstContact('amber-fox-run', x: _m1.xPub);
      await w.firstContact(_dev);
      expect(w.live.rowWrites, isEmpty);
      expect(w.io.listened, isEmpty);
      // anyone else back-pairs as before
      await w.firstContact('amber-fox-run');
      expect(w.live.calls, contains('upsertContact:amber-fox-run'));
      expect(w.io.listened, ['x-amber-fox-run']);
    });

    test('the trial loops never try the dev chat', () async {
      final w = await _World.make();
      w.started();
      final plain = await wrapMessage(
        'as him',
        msgUid: 'd1',
        sender: _as(_dev),
      );
      await w.onion(_dev, plain);
      w.io.opens['r1'] = (_dev, plain);
      w.io.opens['r2'] = (_dev, plain);
      await w.app.receiveRelay([
        (peer: 'firstcontact', cipher: 'r1'),
        // his key, where no one is listening for it
        (peer: _m1.xPub, cipher: 'r2'),
      ]);
      await _settle();
      expect(w.io.triesOf(_dev), 0);
      expect(w.live.msgs, isEmpty);
      // everyone else is tried and lands as before
      await w.onion(_v, await wrapMessage('hi', msgUid: 'v1', sender: _as(_v)));
      expect(w.live.msg('v1'), isNotNull);
    });

    test(
      'a deleted dev chat stays deleted, whatever session is left',
      () async {
        final w = await _World.make();
        w.io.sessions = [_dev, 'parked-old-friend'];
        await w.onion(_dev, await wrapMessage('back', sender: _as(_dev)));
        expect(w.io.triesOf(_dev), 0);
        expect(w.live.rowWrites, isEmpty);
        // and a peer let go does not come back claiming his key
        await w.onion(
          'parked-old-friend',
          await wrapMessage(
            'me again',
            sender: _as('parked-old-friend', x: _m1.xPub),
          ),
        );
        expect(w.live.rowWrites, isEmpty);
        await w.onion(
          'parked-old-friend',
          await wrapMessage('me again', sender: _as('parked-old-friend')),
        );
        expect(w.live.calls, contains('upsertContact:parked-old-friend'));
      },
    );

    test(
      'a bundle control for the dev chat or from his words is dropped',
      () async {
        final w = await _World.make();
        w.started();
        String ctl(String from) => jsonEncode({
          'halo_ctl': 'bundle',
          'from': from,
          'bundle': _m1.bundle,
          'want': true,
        });
        await w.app.receiveRelay([
          (peer: _m1.xPub, cipher: ctl(_dev)),
          (peer: _m1.xPub, cipher: ctl(_words)),
          (peer: _m1.xPub, cipher: ctl('DEV:m1')),
        ]);
        await _settle();
        expect(w.live.calls.where((c) => c.startsWith('getContact')), isEmpty);
        expect(w.live.seen, hasLength(3));
        // anyone else's is looked at as before
        await w.app.receiveRelay([(peer: 'x-$_v', cipher: ctl(_v))]);
        expect(w.live.calls, contains('getContact:$_v'));
      },
    );

    test('an introduction naming him files nothing', () async {
      final w = await _World.make();
      for (final card in [
        const IntroFrame(haloId: _words, onion: '', xPub: 'x-new'),
        const IntroFrame(haloId: _dev, onion: '', xPub: 'x-new'),
        const IntroFrame(haloId: 'DEV:m2', onion: '', xPub: 'x-new'),
        IntroFrame(haloId: 'amber-fox-run', onion: '', xPub: _m1.xPub),
        IntroFrame(haloId: 'amber-fox-run', onion: '', xPub: 'x-a', fc: _m1.fc),
      ]) {
        await w.onion(_v, await wrapMessage('', intro: card, sender: _as(_v)));
      }
      expect(w.wrote(_cards), isEmpty);
      expect(w.io.listened, isEmpty);
      expect(w.app.peerFcFor('amber-fox-run'), isNull);
      // someone else is introduced as always
      await w.onion(
        _v,
        await wrapMessage(
          '',
          intro: const IntroFrame(
            haloId: 'new-friend-here',
            onion: '',
            xPub: 'x-nf',
          ),
          sender: _as(_v),
        ),
      );
      expect(w.wrote(_cards), [
        'upsertContactStub:new-friend-here',
        'addVouch:new-friend-here',
      ]);
    });

    test('a group names him nowhere', () async {
      final w = await _World.make();
      Map<String, String> p(String h, String x) => {'h': h, 'o': '', 'x': x};
      await w.onion(
        _v,
        await wrapMessage(
          '',
          groupId: 'g1',
          groupControl: GroupControl(
            type: 'create',
            name: 'friends',
            members: [_me, _v, _dev, _words, 'amber-fox-run', _m1.xPub],
            participants: [
              p(_dev, 'x-1'),
              p(_words, 'x-2'),
              p('amber-fox-run', _m1.xPub),
              p('river-soft-one', 'x-river'),
            ],
          ),
          sender: _as(_v),
        ),
      );
      expect(w.live.members['g1'], [_me, _v, 'amber-fox-run']);
      expect(w.wrote(_cards), ['upsertContactStub:river-soft-one']);
      await w.onion(
        _v,
        await wrapMessage(
          '',
          groupId: 'g1',
          groupControl: GroupControl(
            type: 'add',
            members: [_dev, _words, 'new-one-here'],
            participants: [p(_words, 'x-3'), p('new-one-here', 'x-new')],
          ),
          sender: _as(_v),
        ),
      );
      expect(w.live.members['g1'], [_me, _v, 'amber-fox-run', 'new-one-here']);
      // the admin's roster on a message heals everything but him
      await w.onion(
        _v,
        await wrapMessage(
          'all here?',
          msgUid: 'g1-1',
          groupId: 'g1',
          roster: [_me, _v, _dev, _words, 'late-comer-one'],
          rosterParticipants: [p(_words, 'x-4'), p('late-comer-one', 'x-late')],
          sender: _as(_v),
        ),
      );
      expect(w.live.members['g1'], [_me, _v, 'late-comer-one']);
      expect(w.wrote(_cards), [
        'upsertContactStub:river-soft-one',
        'upsertContactStub:new-one-here',
        'upsertContactStub:late-comer-one',
      ]);
      expect(w.live.msg('g1-1'), isNotNull);
      // a create for a group we are in reconciles, him left out
      await w.onion(
        _v,
        await wrapMessage(
          '',
          groupId: 'g1',
          groupControl: GroupControl(
            type: 'create',
            name: 'friends again',
            members: [_me, _v, _words, 'DEV:m1'],
          ),
          sender: _as(_v),
        ),
      );
      expect(w.live.members['g1'], [_me, _v]);
    });

    test('a room key that is his joins no room', () async {
      final w = await _World.make();
      final roomPub = 'ab' * 32;
      w.live.roomRows[roomPub] = {
        'group_id': 'room1',
        'is_admin': 1,
        'expires_at': DateTime.now().millisecondsSinceEpoch + 3600000,
        'member_cap': null,
        'name': 'room',
      };
      Future<void> join(String who) async {
        final frame = await wrapMessage(
          '',
          groupId: 'room1',
          groupControl: const GroupControl(type: 'join'),
          sender: SenderInfo(haloId: who, edPub: '', onion: '', xPub: who),
        );
        await w.app.receiveRelay([(peer: 'roomfc:$roomPub', cipher: frame)]);
        await _settle();
      }

      await join(_m1.xPub);
      expect(
        w.live.calls.where((c) => c.startsWith('addGroupMember')),
        isEmpty,
      );
      await join('cd' * 32);
      expect(w.live.calls, contains('addGroupMember:room1'));
    });

    test('the boot and a mode switch never listen for the dev chat', () async {
      final w = await _World.make();
      w.started();
      await w.app.subscribeKnown();
      expect(w.io.listened, unorderedEquals(['x-$_v', 'x-$_w']));
      w.io.listened.clear();
      await w.app.resubscribe();
      expect(w.io.listened, unorderedEquals(['x-$_v', 'x-$_w']));
      // his key maps to no chat: what comes on it is not tried as the dev
      // chat's on the everyday lane
      w.io.opens['k1'] = (_dev, await wrapMessage('x', sender: _as(_dev)));
      await w.app.receiveRelay([(peer: _m1.xPub, cipher: 'k1')]);
      expect(w.io.triesOf(_dev), 0);
    });

    test('his first-contact address is remembered for no one', () async {
      final w = await _World.make();
      final other = _rnd64();
      await w.app.rememberPeerFc(_dev, other);
      await w.app.rememberPeerFc('amber-fox-run', _m1.fc);
      await w.app.rememberPeerFc(_words, other);
      // the dev chat's is his pinned one, never one remembered for it
      expect(w.app.peerFcFor(_dev), _m1.fc);
      expect(w.app.peerFcFor('dev:m9'), isNull);
      expect(w.app.peerFcFor('amber-fox-run'), isNull);
      expect(w.app.peerFcFor(_words), isNull);
      await w.app.rememberPeerFc('amber-fox-run', other);
      expect(w.app.peerFcFor('amber-fox-run'), other);
    });

    test('the gate reads the everyday dev chat, whatever is open', () async {
      final w = await _World.make();
      expect((await devGate.chat!())!.state, DevState.fresh);
      expect(await w.live.devChat.begin(_m1), isTrue);
      expect((await devGate.chat!())!.state, DevState.everyday);
      // a decoy open on screen changes nothing on the wire
      final decoy = _Mem(HaloContainer.decoy);
      await devChatTables(decoy.dev);
      useDatabasesForTest(w.live, Session(decoy));
      expect((await devGate.chat!())!.state, DevState.everyday);
    });

    test('the dev chat is never handed on in an introduction', () async {
      final w = await _World.make();
      w.started();
      expect(await w.app.introduce(_dev, _v), (
        toFirst: false,
        toSecond: false,
      ));
      expect(w.io.sent, isEmpty);
      expect(await w.app.introduce(_w, _v), (toFirst: true, toSecond: true));
      expect(w.io.sent, hasLength(2));
    });
  });

  group('links', () {
    final opened = <String>[];
    setUp(() {
      opened.clear();
      openDevChatLater = opened.add;
    });

    test('his words with another key are refused, with the line', () async {
      final w = await _World.make();
      final theirs = await makePreKeyBundleB64(_grinder.ss);
      final said = [
        await handleHaloUriAdded(haloUriV3(_words, '', theirs, _rnd64())),
        await handleHaloUriAdded(
          'kryfo://share?id=${_words.toUpperCase()}&onion=&v=2&bundle=$theirs',
        ),
        await handleHaloUriAdded(
          'kryfo://share?id=$_words&onion=&xpub=${_grinder.xPub}',
        ),
      ];
      expect(said, everyElement((l10n.devLinkMismatch, false)));
      expect(await handleHaloUriAdded(haloUriV3(_dev, '', theirs, _rnd64())), (
        l10n.appInvalidUri,
        false,
      ));
      expect(w.live.calls, isEmpty);
      expect(opened, isEmpty);
    });

    test('his own card opens his chat and adds nothing', () async {
      final w = await _World.make();
      expect(
        await handleHaloUriAdded(haloUriV3(_words, '', _m1.bundle, _m1.fc)),
        ('', true),
      );
      // his key under other words is his too
      expect(
        await handleHaloUriAdded(
          haloUriV3('amber-fox-run', '', _m1.bundle, _rnd64()),
        ),
        ('', true),
      );
      expect(opened, [_dev, _dev]);
      expect(w.live.calls, isEmpty);
    });

    test('his card after his chat was deleted says where a new one '
        'starts, and opens nothing', () async {
      final w = await _World.make();
      await w.live.devChat.delete();
      expect(
        await handleHaloUriAdded(haloUriV3(_words, '', _m1.bundle, _m1.fc)),
        (l10n.devLinkGone, false),
      );
      expect(opened, isEmpty);
      expect((await w.live.devChat.load())?.state, DevState.gone);
    });

    test('the line is in every language, with his name as it is', () {
      final files = Directory(
        'lib/l10n',
      ).listSync().map((f) => f.path).where((f) => f.endsWith('.arb')).toList();
      expect(files, hasLength(15));
      for (final f in files) {
        final arb = jsonDecode(File(f).readAsStringSync()) as Map;
        expect(arb['devLinkMismatch'], contains('Marios'), reason: f);
        expect(arb['devLinkMismatch'], isNot(contains('\u2014')), reason: f);
      }
    });
  });

  // read off the source: the store's own first-contact opener drops a claim
  // of him before it keeps any session under it
  test('back-pair keeps no session under his words', () {
    final src = File('lib/main.dart').readAsStringSync();
    final at = src.indexOf('openFirstContact(String cipher) async {');
    expect(at, isNonNegative);
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    final claim = body.indexOf(
      'if (devCardClaim(id: h, xPub: env.senderXPub)) {',
    );
    expect(claim, isNonNegative);
    expect(claim, lessThan(body.indexOf('storeSession(realAddr')));
    expect(
      body.substring(claim, body.indexOf('return null;', claim)),
      contains('deleteSession(tempAddr)'),
    );
  });

  group('the contact rows', () {
    test('only the dev chat writes its row, and no one gets his key', () async {
      final mem = MemDb();
      await devChatTables(mem);
      final rows = _Rows(mem);
      Map<String, Object?>? row(String id) {
        for (final r in mem.rows('contacts')) {
          if (r['halo_id'] == id) return r;
        }
        return null;
      }

      await rows.upsertContact(_dev, 'o', 'x');
      await rows.upsertContact(_words, 'o', 'x');
      await rows.upsertContact('amber-fox-run', 'o', _m1.xPub);
      await rows.upsertContactStub(_dev, 'o', 'x');
      await rows.upsertContactStub('Dev:m2', 'o', 'x');
      await rows.upsertContactStub(_words, 'o', 'x');
      await rows.upsertContactStub('amber-fox-run', 'o', _m1.xPub);
      expect(mem.rows('contacts'), isEmpty);
      // everyone else as before
      await rows.upsertContact('amber-fox-run', 'o-a', 'x-a');
      await rows.setContactXPub('amber-fox-run', _m1.xPub);
      await rows.setPeerBundle('amber-fox-run', _m1.bundle);
      expect(row('amber-fox-run')!['xpub'], 'x-a');
      expect(row('amber-fox-run')!['peer_bundle'], isNull);
      await rows.setPeerBundle('amber-fox-run', 'their-bundle');
      await rows.setContactXPub('amber-fox-run', 'x-a2');
      expect(row('amber-fox-run')!['peer_bundle'], 'their-bundle');
      expect(row('amber-fox-run')!['xpub'], 'x-a2');
      // the dev chat's own row, as its first send makes it, stays as made
      expect(await rows.devChat.begin(_m1), isTrue);
      final made = {...row(_dev)!};
      await rows.upsertContact(_dev, 'some.onion', 'x-other', accepted: 1);
      await rows.setContactXPub(_dev, 'x-other');
      await rows.setPeerBundle(_dev, 'other-bundle');
      await rows.setKeyChanged(_dev, true);
      expect(row(_dev), made);
    });
  });

  group('what the dev chat takes from him', () {
    // an everyday dev chat opens in the app's own store
    setUpAll(() async {
      if (signalSession.ready) return;
      final pair = Curve.generateKeyPair();
      await signalSession.bootstrap(
        database: MemDb(),
        xPubBytes: pair.publicKey.serialize().sublist(1),
        xPrivBytes: pair.privateKey.serialize(),
      );
    });

    // his chat started with three words, his key mapped to it
    Future<_World> running({bool begin = true}) async {
      final w = await _World.make();
      w.started();
      if (begin) expect(await w.live.devChat.begin(_m1), isTrue);
      await w.app.subscribePeer(_dev);
      return w;
    }

    Future<void> his(_World w, String plain) async {
      final c = 'his${w._n++}';
      w.io.opens[c] = (_dev, plain);
      await w.app.receiveRelay([(peer: _m1.xPub, cipher: c)]);
      await _settle();
    }

    SenderInfo marios({String? h, String? x}) => SenderInfo(
      haloId: h ?? _words,
      edPub: 'ed-his',
      onion: 'his.onion',
      xPub: x ?? _m1.xPub,
      avatar: 9,
    );

    test('his message lands, without his face or his tier', () async {
      final w = await running();
      await his(
        w,
        await wrapMessage(
          'hi, marios here',
          msgUid: 'mm1',
          sender: marios(),
          supporterBadge: 'gold',
        ),
      );
      expect(w.live.msg('mm1')!['plaintext'], 'hi, marios here');
      expect(
        w.live.calls.where(
          (c) =>
              c.startsWith('setContactAvatar') ||
              c.startsWith('setContactBadge'),
        ),
        isEmpty,
      );
      // his reaction names nobody and still lands
      await his(
        w,
        await wrapMessage(
          '',
          reaction: const ReactionFrame(targetUid: 'mm1', emoji: 'y'),
        ),
      );
      expect(w.live.calls, contains('addReaction:mm1'));
    });

    test('a group, an introduction or a poll from him is dropped '
        'unseen', () async {
      final w = await running();
      Map<String, String> p(String h) => {'h': h, 'o': '', 'x': 'x-$h'};
      final frames = [
        await wrapMessage(
          '',
          groupId: 'g1',
          groupControl: GroupControl(
            type: 'create',
            name: 'his group',
            members: [_words, _me],
            participants: [p(_words)],
          ),
          sender: marios(),
        ),
        await wrapMessage(
          'in the group',
          msgUid: 'gm1',
          groupId: 'g1',
          roster: [_words, _me, 'river-soft-one'],
          rosterParticipants: [p('river-soft-one')],
          sender: marios(),
        ),
        await wrapMessage(
          '',
          intro: const IntroFrame(
            haloId: 'new-friend-here',
            onion: '',
            xPub: 'x-nf',
          ),
          sender: marios(),
        ),
        await wrapMessage(
          'lunch?',
          msgUid: 'pl1',
          poll: const PollSpec(options: ['yes', 'no']).toWire(),
          sender: marios(),
        ),
        await wrapMessage(
          '',
          vote: const VoteFrame(pollUid: 'pl0', choices: [0], seq: 1),
          sender: marios(),
        ),
        await wrapMessage(
          '',
          pollClose: const PollCloseFrame(pollUid: 'pl0'),
          sender: marios(),
        ),
      ];
      for (final f in frames) {
        await his(w, f);
      }
      expect(w.live.rowWrites, isEmpty);
      expect(w.live.msgs, isEmpty);
      // taken off the relay all the same, and never tried again
      expect(w.live.seen, hasLength(frames.length));
      expect(w.io.sent, isEmpty);
    });

    test('a frame that says it is someone else is dropped', () async {
      final w = await running();
      for (final s in [
        marios(h: 'amber-fox-run'),
        marios(h: _me),
        marios(x: 'x-$_v'),
      ]) {
        await his(
          w,
          await wrapMessage('it is me', msgUid: 'f${w._n}', sender: s),
        );
      }
      expect(w.live.rowWrites, isEmpty);
      expect(w.live.seen, hasLength(3));
    });

    test('before his chat starts and after a delete nothing lands', () async {
      final fresh = await running(begin: false);
      await his(
        fresh,
        await wrapMessage('early', msgUid: 'e1', sender: marios()),
      );
      expect(fresh.live.rowWrites, isEmpty);
      final w = await running();
      await w.live.devChat.delete();
      await his(w, await wrapMessage('late', msgUid: 'l1', sender: marios()));
      expect(w.live.rowWrites, isEmpty);
      expect(w.io.sent, isEmpty);
    });
  });
}
