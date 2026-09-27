// SPDX-License-Identifier: GPL-3.0-or-later
// the vault session: the hidden chats PIN opens the everyday app with its
// hidden chats under the lock, at the same moment as any other outcome, and
// the lock shuts it again at once. the databases, the list, signal and the
// engine are stand-ins that keep their rows in memory; the wipe runs on real
// files in a scratch folder
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        AppState,
        HaloDb,
        searchFill,
        session,
        sessionQuiet,
        useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/polls.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';
import 'package:kryfo/vault_life.dart';
import 'package:kryfo/widgets/hidden_mark.dart';
import 'package:kryfo/wipe.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart'
    show
        MemEngine,
        NoBio,
        StillClock,
        appPin,
        decoyPin,
        vaultKey,
        vaultPin,
        wipePin;

const _h = 'hidden-wreck-tone';
const _m = 'member-only-one';
const _v = 'visible-plain-row';
const _r = 'request-from-afar';
const _g1 = 'g1visible001';
const _g2 = 'g2hidden0001';
const _n = 'newcomer-in-g2';

// ---- the list, as the router keeps it in the everyday database ----

class _Store implements RouterStore {
  final rows = <String, Map<String, Object?>>{};
  final metas = <String, String>{};
  final inbox = <Map<String, Object?>>[];
  var _next = 1;

  @override
  Future<List<Map<String, Object?>>> hidden() async => [
    for (final r in rows.values) {...r},
  ];
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
    v == null ? metas.remove(k) : metas[k] = v;
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
  Future<int> inboxParts(String uid) async => 0;
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

// a stand-in for age: sealed under the pair's name, opened by its other half
class _Seal implements VaultSeal {
  @override
  String? seal(String pub, String b64) => pub.startsWith('pub-')
      ? base64Encode(utf8.encode('${pub.substring(4)}.$b64'))
      : null;
  @override
  List<String?> openMany(String priv, List<String> b64s) => [
    for (final s in b64s)
      if (utf8.decode(base64Decode(s)) case final x
          when x.startsWith('${priv.substring(5)}.'))
        x.substring(x.indexOf('.') + 1)
      else
        null,
  ];
}

// ---- signal, the engine and android ----

class _Io implements AppIo {
  final opens = <String, (String, String)>{};
  final sent = <(String, String)>[];
  final rang = <String>[];
  final unrang = <String>[];

  @override
  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) async {
    final o = opens[cipher];
    return o != null && o.$1 == peer ? o.$2 : null;
  }

  // everyone signal holds a session with
  List<String> sessions = const [];
  @override
  Future<List<String>> sessionAddresses() async => sessions;
  @override
  Future<({String haloId, String plain, UnwrappedMessage env})?>
  openFirstContact(String cipher) async => null;
  @override
  Future<bool> hasSession(String peer) async => true;
  @override
  Future<String> encrypt(String peer, String plain) async => 'to $peer $plain';
  @override
  void listen(String xPub) {}
  @override
  String edPub() => 'ed-me';
  @override
  String xPub() => 'x-me';
  @override
  Future<String> relaySend(String xPub, String cipher) async {
    sent.add((xPub, cipher));
    return 'ok';
  }

  @override
  Future<String> onionSend(String onion, String cipher) async {
    sent.add((onion, cipher));
    return 'ok';
  }

  @override
  Future<String> firstContactSend(String xPub, String fc, String cipher) async {
    sent.add((xPub, cipher));
    return 'ok';
  }

  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
  }) async => rang.add(payload ?? title);

  @override
  Future<void> unnotify(String payload) async => unrang.add(payload);

  // what was sent to someone, by their key or their onion
  List<String> to(String id) => [
    for (final (k, c) in sent)
      if (k == 'x-$id' || k == 'o-$id') c,
  ];
}

// ---- one container's rows, and a handle on them ----

class _Rows {
  final people = <String, Map<String, Object?>>{};
  final groupRows = <String, Map<String, Object?>>{};
  final members = <String, List<String>>{};
  final msgs = <Map<String, Object?>>[];
  final seen = <String>{};
  final meta = <String, String>{};
  var _id = 0;
  // called as each message is kept
  void Function()? onSave;
  // the first fill of its search index, part way along
  ({int at, int to})? fill;
  // a read of which chats it holds waits for this, and says it began
  Completer<void>? holdHeld;
  Completer<void>? heldAsked;

  void person(
    String id, {
    int accepted = 1,
    int unread = 0,
    int backPaired = 1,
  }) => people[id] = {
    'halo_id': id,
    'onion': 'o-$id',
    'xpub': 'x-$id',
    'accepted': accepted,
    'blocked': 0,
    'archived': 0,
    'back_paired': backPaired,
    'unread': unread,
    'muted': 0,
    'verified': 0,
    'pinned': 0,
    'last_seen': 1,
    'first_seen': 1,
  };

  void group(String id, List<String> who, {int unread = 0}) {
    groupRows[id] = {
      'group_id': id,
      'name': id,
      'created_at': 1,
      'is_admin': 0,
      'admin_id': null,
      'unread': unread,
      'mentioned': 0,
      'room_pub': null,
    };
    members[id] = [...who];
  }

  Map<String, Object?> say(
    String uid,
    String peer,
    String text, {
    String? group,
    bool out = false,
    String? media,
    int? burnAt,
    int sent = 1,
    int saved = 0,
    int pinned = 0,
    int? at,
  }) {
    final row = <String, Object?>{
      'id': ++_id,
      'peer_id': peer,
      'direction': out ? 'out' : 'in',
      'plaintext': text,
      'sent_at': at ?? 1000 + _id,
      'msg_uid': uid,
      'group_id': group,
      'media_path': media,
      'file_path': null,
      'file_name': null,
      'burn_at': burnAt,
      'burn_secs': null,
      'sent': sent,
      'saved': saved,
      'pinned': pinned,
      'poll': null,
      'sticker': null,
      'edited': 0,
    };
    msgs.add(row);
    return row;
  }

  Map<String, Object?>? msg(String uid) {
    for (final m in msgs) {
      if (m['msg_uid'] == uid) return m;
    }
    return null;
  }

  Set<String> get uids => {for (final m in msgs) m['msg_uid'] as String};
}

// a database as the app reaches it. a closed handle answers nothing, as a
// closed wrapped one does: its key went with it
class _Db implements HaloDb {
  _Db(this._container, this.r);

  final HaloContainer _container;
  final _Rows r;
  bool closed = false;
  final calls = <String>[];
  // what a read of the home list waits for, when a test holds it
  Completer<void>? holdContacts;

  T _hit<T>(String name, Object? arg, T answer) {
    if (closed) throw StateError('${_container.dbFile} has no key here');
    calls.add(arg == null ? name : '$name:$arg');
    return answer;
  }

  @override
  HaloContainer get container => _container;

  @override
  Future<void> close() async {
    calls.add('close');
    closed = true;
  }

  // ---- lists ----
  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async {
    final hold = r.holdHeld;
    if (hold != null) {
      r.heldAsked?.complete();
      await hold.future;
    }
    return _hit('heldChats', null, (
      people: {
        for (final p in r.people.values)
          p['halo_id'] as String: p['accepted'] == 1,
      },
      groups: r.groupRows.keys.toSet(),
    ));
  }

  @override
  Future<List<Map<String, Object?>>> contacts() async {
    final held = holdContacts;
    if (held != null) await held.future;
    return _hit('contacts', null, [
      for (final p in r.people.values)
        if (p['accepted'] == 1) {...p},
    ]);
  }

  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async =>
      _hit('lastMessages', null, {
        for (final m in r.msgs)
          if (m['group_id'] == null) m['peer_id'] as String: m,
      });
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async =>
      _hit('pendingRequests', null, [
        for (final p in r.people.values)
          if (p['accepted'] == 0 && p['archived'] == 0 && p['blocked'] == 0) p,
      ]);
  @override
  Future<List<Map<String, Object?>>> parkedRequests() async =>
      _hit('parkedRequests', null, [
        for (final p in r.people.values)
          if (p['accepted'] == 0 && p['archived'] == 1) p,
      ]);
  @override
  Future<List<Map<String, Object?>>> vouchedPending() async =>
      _hit('vouchedPending', null, const []);
  @override
  Future<int> pendingRequestCount() async => (await pendingRequests()).length;
  @override
  Future<List<Map<String, Object?>>> loadGroups() async =>
      _hit('loadGroups', null, r.groupRows.values.toList());
  @override
  Future<List<String>> getGroupMembers(String groupId) async =>
      _hit('getGroupMembers', groupId, [...?r.members[groupId]]);
  @override
  Future<Set<String>> blockedIds() async => _hit('blockedIds', null, {
    for (final p in r.people.values)
      if (p['blocked'] == 1) p['halo_id'] as String,
  });

  List<Map<String, Object?>> _newest(Iterable<Map<String, Object?>> rows) =>
      [...rows]
        ..sort((a, b) => (b['sent_at'] as int).compareTo(a['sent_at'] as int));

  @override
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async => _hit(
    'searchMessages',
    match,
    _newest([
      for (final m in r.msgs)
        if ((match == null ||
                (m['plaintext'] as String).toLowerCase().contains(
                  match.toLowerCase(),
                )) &&
            (kind != SearchKind.photos || m['media_path'] != null))
          m,
    ]).take(limit).toList(),
  );
  @override
  Future<List<Map<String, Object?>>> savedMessages() async => _hit(
    'savedMessages',
    null,
    _newest([
      for (final m in r.msgs)
        if (m['saved'] == 1) m,
    ]),
  );
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => _hit('pinnedIn', groupId ?? peerId, [
    for (final m in r.msgs)
      if (m['pinned'] == 1 &&
          (groupId != null
              ? m['group_id'] == groupId
              : m['peer_id'] == peerId && m['group_id'] == null))
        m,
  ]);
  @override
  Future<List<Map<String, Object?>>> mediaFor(String peerId) async =>
      _hit('mediaFor', peerId, [
        for (final m in r.msgs)
          if (m['peer_id'] == peerId &&
              m['group_id'] == null &&
              m['media_path'] != null)
            {'media_path': m['media_path'], 'secure': 0},
      ]);

  // ---- what runs on a timer ----
  @override
  Future<int> purgeExpired() async {
    _hit('purgeExpired', null, null);
    final now = DateTime.now().millisecondsSinceEpoch;
    final before = r.msgs.length;
    r.msgs.removeWhere((m) {
      final at = m['burn_at'] as int?;
      return at != null && at < now;
    });
    return before - r.msgs.length;
  }

  @override
  Future<void> purgeStrayVotes({
    Duration after = const Duration(days: 1),
  }) async => _hit('purgeStrayVotes', null, null);
  @override
  Future<({int at, int to})> fillSearchIndex({int batch = 300}) async {
    final f = r.fill ?? (at: 0, to: 0);
    r.fill = (at: f.to, to: f.to);
    return _hit('fillSearchIndex', null, f);
  }

  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async =>
      _hit('unsentOutbox', null, [
        for (final m in r.msgs)
          if (m['direction'] == 'out' && m['sent'] == 0) {...m},
      ]);
  @override
  Future<List<Map<String, Object?>>> unsentEdits() async =>
      _hit('unsentEdits', null, const []);
  @override
  Future<List<Map<String, Object?>>> unsentPins() async =>
      _hit('unsentPins', null, const []);
  @override
  Future<List<Map<String, Object?>>> mediaWants() async =>
      _hit('mediaWants', null, const []);
  @override
  Future<void> markSent(String msgUid) async {
    _hit('markSent', msgUid, null);
    r.msg(msgUid)?['sent'] = 1;
  }

  @override
  Future<void> setMsgBurnAt(String msgUid, int burnAt) async {
    _hit('setMsgBurnAt', msgUid, null);
    r.msg(msgUid)?['burn_at'] = burnAt;
  }

  // ---- people ----
  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _hit('getContact', haloId, r.people[haloId]);
  @override
  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
  }) async {
    _hit('upsertContact', haloId, null);
    r.people[haloId] ??= {
      ...(_Rows()..person(haloId, accepted: accepted)).people[haloId]!,
    };
  }

  @override
  Future<bool> isAccepted(String haloId) async =>
      _hit('isAccepted', haloId, r.people[haloId]?['accepted'] == 1);
  @override
  Future<bool> isVouched(String haloId) async => _hit('isVouched', null, false);
  @override
  Future<bool> isBlocked(String haloId) async =>
      _hit('isBlocked', haloId, r.people[haloId]?['blocked'] == 1);
  @override
  Future<bool> isMuted(String haloId) async =>
      _hit('isMuted', haloId, r.people[haloId]?['muted'] == 1);
  @override
  Future<bool> isBackPaired(String peerId) async =>
      _hit('isBackPaired', peerId, r.people[peerId]?['back_paired'] == 1);
  @override
  Future<void> markBackPaired(String peerId) async =>
      _hit('markBackPaired', peerId, null);
  @override
  Future<void> setContactBadge(String haloId, String? tier) async =>
      _hit('setContactBadge', haloId, null);
  @override
  Future<void> setContactAvatar(String haloId, int? av) async =>
      _hit('setContactAvatar', haloId, null);
  @override
  Future<void> unparkIfArchived(String haloId) async =>
      _hit('unparkIfArchived', haloId, null);
  @override
  Future<void> bumpUnread(String peerId) async {
    _hit('bumpUnread', peerId, null);
    final p = r.people[peerId];
    if (p != null) p['unread'] = (p['unread'] as int) + 1;
  }

  @override
  Future<void> clearUnread(String peerId) async =>
      _hit('clearUnread', peerId, null);
  @override
  Future<String?> contactXPub(String haloId) async =>
      _hit('contactXPub', haloId, r.people[haloId]?['xpub'] as String?);
  @override
  Future<void> setContactXPub(String haloId, String xpub) async =>
      _hit('setContactXPub', haloId, null);
  @override
  Future<int> countMessagesFrom(String peerId) async => _hit(
    'countMessagesFrom',
    peerId,
    r.msgs
        .where((m) => m['peer_id'] == peerId && m['direction'] == 'in')
        .length,
  );
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async =>
      _hit('shieldFor', haloId, null);

  // ---- the receive side's own marks ----
  @override
  Future<bool> alreadySeen(String hash) async =>
      _hit('alreadySeen', null, r.seen.contains(hash));
  @override
  Future<void> markSeen(String hash) async {
    _hit('markSeen', null, null);
    r.seen.add(hash);
  }

  @override
  Future<void> markSeenLong(String hash) async {
    _hit('markSeenLong', null, null);
    r.seen.add(hash);
  }

  @override
  Future<void> markDelivered(String msgUid) async =>
      _hit('markDelivered', msgUid, null);

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
  }) async {
    _hit('saveMessage', msgUid ?? peerId, null);
    r.say(
      msgUid ?? 'x${r._id}',
      peerId,
      plaintext,
      group: groupId,
      out: direction == 'out',
      media: mediaPath,
      burnAt: burnAt,
      sent: sent,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    r.onSave?.call();
  }

  @override
  Future<bool> messageExists(String msgUid) async =>
      _hit('messageExists', msgUid, r.msg(msgUid) != null);

  // ---- groups ----
  @override
  Future<bool> groupExists(String groupId) async =>
      _hit('groupExists', groupId, r.groupRows.containsKey(groupId));
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async =>
      _hit('getGroup', groupId, r.groupRows[groupId]);
  @override
  Future<String?> groupAdminId(String groupId) async => _hit(
    'groupAdminId',
    groupId,
    r.groupRows[groupId]?['admin_id'] as String?,
  );
  @override
  Future<void> bumpGroupUnread(String groupId) async {
    _hit('bumpGroupUnread', groupId, null);
    final g = r.groupRows[groupId];
    if (g != null) g['unread'] = (g['unread'] as int) + 1;
  }

  @override
  Future<void> setGroupMentioned(String groupId) async =>
      _hit('setGroupMentioned', groupId, null);
  @override
  Future<void> clearGroupUnread(String groupId) async =>
      _hit('clearGroupUnread', groupId, null);
  @override
  Future<({PollSpec spec, String? groupId, bool mine})?> pollRow(
    String uid,
  ) async => _hit('pollRow', uid, null);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

// ---- the vault's life, as the session reaches it ----

class _Host implements VaultHost {
  _Host(this.w);
  final _World w;
  // a vault that will not open
  bool broken = false;

  @override
  bool get lockOn => true;
  @override
  Future<bool> putEntry(String pin, String keyHex) async => true;
  @override
  Future<void> clearEntry() async {}
  @override
  Future<String> makeVault(String keyHex) async => 'pub-A';

  @override
  Future<HaloDb> openVault(String keyHex) async {
    if (broken || keyHex != vaultKey) throw StateError('will not open');
    final d = _Db(HaloContainer.vault, w.vaultRows);
    w.handles.add(d);
    w.log.add('open');
    return d;
  }

  @override
  ChatMover mover(HaloDb live, HaloDb? vault) => _Mover(w);
  @override
  Future<void> clearShade(Iterable<String> payloads) async {}
  @override
  Future<void> moveFile(String from, String to) async {}
  @override
  Future<void> shred(String path) async {}
  @override
  Future<void> wipeVault() async {}
}

// rows of chats between the two containers, a chat whole at a time
class _Mover implements ChatMover {
  _Mover(this.w);
  final _World w;

  _Rows get _l => w.liveRows;
  _Rows get _v => w.vaultRows;

  bool _named(_Rows s, String id) =>
      s.members.values.any((m) => m.contains(id));

  void _copy(ChatRef c, _Rows s, _Rows d) {
    if (c.group) {
      d.groupRows[c.id] = {...s.groupRows[c.id]!};
      d.members[c.id] = [...?s.members[c.id]];
      for (final id in s.members[c.id] ?? const <String>[]) {
        final p = s.people[id];
        if (p == null || d.people.containsKey(id)) continue;
        d.people[id] = {...p, 'accepted': 0, 'unread': 0};
      }
    } else {
      d.people[c.id] = {...s.people[c.id]!};
    }
    for (final m in s.msgs) {
      final mine = c.group
          ? m['group_id'] == c.id
          : m['peer_id'] == c.id && m['group_id'] == null;
      if (mine && d.msg(m['msg_uid'] as String) == null) d.msgs.add({...m});
    }
  }

  void _drop(_Rows s, ChatRef c) {
    if (c.group) {
      final who = s.members.remove(c.id) ?? const <String>[];
      s.groupRows.remove(c.id);
      s.msgs.removeWhere((m) => m['group_id'] == c.id);
      for (final id in who) {
        if (s.people[id]?['accepted'] != 0 || _named(s, id)) continue;
        if (s.msgs.any((m) => m['peer_id'] == id)) continue;
        s.people.remove(id);
      }
      return;
    }
    s.msgs.removeWhere((m) => m['peer_id'] == c.id && m['group_id'] == null);
    final row = s.people.remove(c.id);
    if (row != null && _named(s, c.id)) {
      s.people[c.id] = {...row, 'accepted': 0, 'unread': 0};
    }
  }

  RouterCard _cardOf(Map<String, Object?> p) => RouterCard(
    p['halo_id'] as String,
    p['onion'] as String,
    p['xpub'] as String,
    backPaired: p['back_paired'] == 1,
    blocked: p['blocked'] == 1,
  );

  String _card(ChatRef c) => c.group
      ? groupCard([
          for (final id in _v.members[c.id] ?? const <String>[])
            if (!_l.people.containsKey(id) && _v.people[id] != null)
              _cardOf(_v.people[id]!),
        ])
      : peerCard(_cardOf(_v.people[c.id]!));

  @override
  Future<void> attach() async => w.log.add('attach');
  @override
  Future<void> detach() async => w.log.add('detach');
  @override
  Future<MoveMarks> marks() async => MoveMarks.decode(_v.meta['moves']);
  @override
  Future<void> putMarks(MoveMarks m) async {
    final s = m.encode();
    s == null ? _v.meta.remove('moves') : _v.meta['moves'] = s;
  }

  @override
  Future<bool> hideable(ChatRef c) async =>
      (c.group
          ? _l.groupRows.containsKey(c.id)
          : _l.people[c.id]?['accepted'] == 1) &&
      !await held(c);
  @override
  Future<bool> held(ChatRef c) async => c.group
      ? _v.groupRows.containsKey(c.id)
      : _v.people[c.id]?['accepted'] == 1;
  @override
  Future<Set<String>> peopleIn(ChatRef c, {required bool inVault}) async =>
      c.group ? {...?(inVault ? _v : _l).members[c.id]} : {c.id};
  @override
  Future<void> copyIn(ChatRef c, MoveMarks marks) async {
    final held = w.holdMove;
    if (held != null) await held.future;
    _copy(c, _l, _v);
    await putMarks(marks);
  }

  @override
  Future<List<String>> commitIn(ChatRef c, int at) async {
    _drop(_l, c);
    w.store.rows[c.id] = {
      'chat_id': c.id,
      'kind': c.group ? kHiddenGroup : kHiddenPeer,
      'card': hidingCard(_card(c), const []),
      'at': at,
    };
    return const [];
  }

  @override
  Future<List<String>> vaultFiles(ChatRef c) async => const [];
  @override
  Future<void> commitOut(ChatRef c) async {
    _copy(c, _v, _l);
    w.store.rows.remove(c.id);
  }

  @override
  Future<void> dropVault(ChatRef c, MoveMarks marks) async {
    _drop(_v, c);
    await putMarks(marks);
  }

  @override
  Future<void> dropLive(ChatRef c) async => _drop(_l, c);
  @override
  Future<Map<String, (String, String)>> vaultCards() async {
    w.log.add('cards');
    return {
      for (final p in _v.people.values)
        if (p['accepted'] == 1)
          p['halo_id'] as String: (
            kHiddenPeer,
            _card(ChatRef(p['halo_id'] as String)),
          ),
      for (final g in _v.groupRows.keys)
        g: (kHiddenGroup, _card(ChatRef(g, group: true))),
    };
  }
}

SenderInfo _as(String id) =>
    SenderInfo(haloId: id, edPub: 'ed-$id', onion: 'o-$id', xPub: 'x-$id');

// a phone with a vault: V a visible contact, R a request, G1 a visible
// group. the vault holds H with its words, a photo, a saved and pinned
// message, one unsent and one whose timer ran out while it was shut, and
// the group G2 with M, whom only the vault knows
class _World {
  final liveRows = _Rows();
  final vaultRows = _Rows();
  late final live = _Db(HaloContainer.everyday, liveRows);
  final handles = <_Db>[];
  final store = _Store();
  final io = _Io();
  final log = <String>[];
  late final host = _Host(this);
  late VaultRouter router;
  late AppState app;
  Completer<void>? holdMove;
  var _n = 0;

  _Db get handle => handles.last;

  static Future<_World> make() async {
    final w = _World();
    final l = w.liveRows;
    l.person(_v, unread: 1);
    l.person(_r, accepted: 0, backPaired: 0);
    l.group(_g1, ['me', _v]);
    l.say('v0', _v, 'the visible one');
    l.say('r0', _r, 'hello stranger');
    l.say('g1v', _v, 'in the open group', group: _g1);
    final v = w.vaultRows;
    v.person(_h, unread: 3);
    v.person(_m, accepted: 0);
    v.group(_g2, ['me', _h, _m], unread: 2);
    v.say('h0', _h, 'meet at the bridge', saved: 1, pinned: 1);
    v.say('h1', _h, '', media: '/m/h1.jpg');
    v.say('h2', _h, 'still to go', out: true, sent: 0, at: 1);
    v.say('h3', _h, 'gone by now', burnAt: 5);
    v.say('g2m', _m, 'from m', group: _g2);
    v.meta['priv'] = 'priv-A';
    w.store.metas['pub'] = 'pub-A';
    w.store.rows[_h] = {
      'chat_id': _h,
      'kind': kHiddenPeer,
      'card': peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
      'at': 1,
    };
    w.store.rows[_g2] = {
      'chat_id': _g2,
      'kind': kHiddenGroup,
      'card': groupCard(const [RouterCard(_m, 'o-$_m', 'x-$_m')]),
      'at': 1,
    };
    w.router = VaultRouter(w.store, _Seal());
    await w.router.load();
    w.app = AppState(io: w.io, router: w.router, host: w.host)
      ..myId = 'me'
      ..revealGap = Duration.zero;
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  // the hidden chats PIN, as the lock hands its key on
  Future<void> open() async {
    await app.sessionFor(PinResult.vault, vaultKey: vaultKey);
    await _settle();
  }

  // the lock going up, as the lock layer tells the app
  Future<void> lockUp() async {
    app.lockingUp();
    await _settle();
  }

  Future<void> everyday() async {
    await app.sessionFor(PinResult.normal);
    await _settle();
  }

  // a message arriving on the onion lane, opened under [from]
  Future<void> onion(String from, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (from, plain);
    await app.receiveOnion([c]);
    await _settle();
  }

  Set<String> get homeIds => {
    for (final c in app.contacts) c.haloId,
    for (final g in app.groups) g.groupId,
  };

  int get badges =>
      app.contacts.fold<int>(0, (n, c) => n + c.unread) +
      app.groups.fold<int>(0, (n, g) => n + g.unread);
}

// what was sent without being waited for gets there
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

// the lock with an app, wipe, decoy and hidden chats PIN
({LockState lock, _CountingStore store, _CountingEngine engine}) _lock({
  Duration reveal = Duration.zero,
}) {
  final store = _CountingStore();
  Map<String, Object> entry(String pin, int kind, HaloContainer c) => {
    'p': pin,
    'k': kind,
    'c': c.id,
    'w': kind == PinKind.vault ? vaultKey : '',
  };
  store.m['halo.lock.enabled'] = 'true';
  store.m['halo.lock.table'] = jsonEncode({
    'v': 2,
    'n': 15,
    'e': {
      '${PinSlot.app}': entry(appPin, PinKind.everyday, HaloContainer.everyday),
      '${PinSlot.wipe}': entry(wipePin, PinKind.wipe, HaloContainer.everyday),
      '${PinSlot.decoy}': entry(decoyPin, PinKind.decoy, HaloContainer.decoy),
      '${PinSlot.vault}': entry(vaultPin, PinKind.vault, HaloContainer.vault),
    },
  });
  final engine = _CountingEngine();
  return (
    lock: LockState(
      store: store,
      engine: engine,
      clock: StillClock(),
      bio: NoBio(),
      revealAfter: reveal,
    ),
    store: store,
    engine: engine,
  );
}

// storage that counts what a check reads and writes
class _CountingStore implements LockStore {
  final m = <String, String>{};
  var reads = 0;
  var writes = 0;
  @override
  Future<String?> read(String key) async {
    reads++;
    return m[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    m[key] = value;
  }

  @override
  Future<void> delete(String key) async => m.remove(key);
}

class _CountingEngine extends MemEngine {
  var checks = 0;
  @override
  Future<Map<String, dynamic>> check(String pin, String table, String legacy) {
    checks++;
    return super.check(pin, table, legacy);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('vault_session');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => switch (call.method) {
            'getApplicationSupportDirectory' => p.join(docs.path, 'support'),
            'getTemporaryDirectory' => p.join(docs.path, 'tmp'),
            _ => p.join(docs.path, 'docs'),
          },
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    lockState.inVault = false;
    lockState.inDecoy = false;
    decoyReady = true;
  });

  tearDown(() {
    haloWiping = false;
    docs.deleteSync(recursive: true);
  });

  group('opening', () {
    test(
      'every outcome shows at the one deadline, the vault included',
      () async {
        final w = await _World.make();
        const reveal = Duration(milliseconds: 600);
        w.app.revealGap = reveal + const Duration(milliseconds: 100);
        final (:lock, :store, :engine) = _lock(reveal: reveal);
        await lock.load();
        final built = <PinResult, bool>{};
        lock.onOutcome = (r, {vaultKey}) async {
          await w.app.sessionFor(r, vaultKey: vaultKey);
          // built while the lock is still up
          built[r] = lock.locked;
        };
        final shown = <String, int>{};
        for (final pin in [appPin, vaultPin, decoyPin, '0000', wipePin]) {
          store.writes = 0;
          store.reads = 0;
          engine.checks = 0;
          final t = Stopwatch()..start();
          final r = await lock.verifyPin(pin);
          shown[pin] = t.elapsedMilliseconds;
          // one check, one write, nothing read, whatever the pin
          expect(engine.checks, 1, reason: pin);
          expect(store.writes, 1, reason: pin);
          expect(store.reads, 0, reason: pin);
          if (pin == vaultPin) {
            expect(r, PinResult.vault);
            expect(session.isHidden(_h), isTrue);
            expect(w.homeIds, containsAll([_h, _g2]));
          }
          lock.lock();
          w.app.lockingUp();
          await _settle();
        }
        expect(built.values, everyElement(isTrue));
        for (final e in shown.entries) {
          expect(e.value, greaterThanOrEqualTo(reveal.inMilliseconds - 2));
        }
        final ms = shown.values.toList()..sort();
        // the vault is opened and its lists read inside the same wait
        expect(ms.last - ms.first, lessThan(120), reason: '$shown');
      },
    );

    test('a vault unlock builds its session under the lock', () async {
      final w = await _World.make();
      final rev = w.app.sessionRev;
      await w.open();
      expect(lockState.inVault, isTrue);
      // not quiet: what waited for the lock happens after it, as after an
      // everyday unlock
      expect(sessionQuiet, isFalse);
      expect(w.app.sessionRev, rev + 1);
      expect(session.isHidden(_h), isTrue);
      expect(session.isHidden(_g2), isTrue);
      expect(session.isHidden(_v), isFalse);
      expect(w.homeIds, containsAll([_v, _g1, _h, _g2]));
      expect(w.app.contacts.firstWhere((c) => c.haloId == _h).hidden, isTrue);
      expect(w.app.contacts.firstWhere((c) => c.haloId == _v).hidden, isFalse);
      expect(w.app.groups.firstWhere((g) => g.groupId == _g2).hidden, isTrue);
      // the vault's request is a request here, with the everyday one
      expect(w.app.pendingCount, 2);
      // its timer that ran out while it was shut went at the open
      expect(w.vaultRows.msg('h3'), isNull);
      // the list was read again from it, with the handle attached
      expect(w.log, containsAllInOrder(['open', 'attach', 'cards']));
    });

    test('a vault that will not open gives the everyday app', () async {
      final w = await _World.make();
      w.host.broken = true;
      final lock = _lock().lock;
      await lock.load();
      lock.onOutcome = w.app.sessionFor;
      expect(await lock.verifyPin(vaultPin), PinResult.normal);
      expect(lock.locked, isFalse);
      expect(lockState.inVault, isFalse);
      expect(session.vault, isNull);
      expect(w.homeIds, isNot(contains(_h)));
    });
  });

  group('the lock', () {
    test(
      'shuts the vault at once, and the next unlock shows nothing of it',
      () async {
        final w = await _World.make();
        w.app.sendModeForTest = 'private';
        await w.open();
        await w.app.drainOutbox();
        expect(w.app.queuedFor(_h), 1);
        expect(w.badges, 1 + 3 + 2);
        final opened = w.handle;
        w.app.lockingUp();
        // at once, before anything else runs: the everyday session, and
        // nothing of the vault left on home
        expect(session.vault, isNull);
        expect(lockState.inVault, isFalse);
        expect(w.homeIds, isNot(anyOf(contains(_h), contains(_g2))));
        expect(w.app.queuedFor(_h), 0);
        expect(w.app.queued, 0);
        await _settle();
        // the list was read from the vault first, then its handle went, and
        // its key with it
        expect(w.log.lastIndexOf('cards'), greaterThan(-1));
        expect(opened.calls.last, 'close');
        expect(opened.closed, isTrue);
        expect(() => opened.contacts(), throwsStateError);
        // the next everyday unlock lands on home with the everyday app only
        await w.everyday();
        expect(w.homeIds, {_v, _g1});
        expect(w.app.pendingCount, 1);
        expect(w.badges, 1);
        expect(await session.searchMessages('bridge', SearchKind.all), isEmpty);
        expect(await session.searchMessages(null, SearchKind.photos), isEmpty);
        expect([
          for (final m in await session.savedMessages()) m['msg_uid'],
        ], isNot(contains('h0')));
        expect(await session.pinnedIn(peerId: _h), isEmpty);
        expect(await session.mediaFor(_h), isEmpty);
        expect(await session.getContact(_h), isNull);
        expect(await session.getGroup(_g2), isNull);
        expect(await session.pendingRequestCount(), 1);
        expect(w.app.queuedFor(_h), 0);
        // and the vault's rows are all still there for the next open
        expect(w.vaultRows.uids, containsAll(['h0', 'h1', 'h2', 'g2m']));
      },
    );

    test('a read begun in the vault does not bring it back', () async {
      final w = await _World.make();
      await w.open();
      final hold = Completer<void>();
      w.live.holdContacts = hold;
      final reading = w.app.refreshContacts();
      w.app.lockingUp();
      hold.complete();
      w.live.holdContacts = null;
      await reading;
      await _settle();
      expect(w.homeIds, isNot(contains(_h)));
      await w.everyday();
      expect(w.homeIds, {_v, _g1});
    });

    test('a lock during a move keeps the vault shut', () async {
      final w = await _World.make();
      await w.open();
      final hold = Completer<void>();
      w.holdMove = hold;
      final hiding = w.app.hideChats(people: [_v]);
      await _settle();
      final opened = w.handle;
      w.app.lockingUp();
      hold.complete();
      expect(await hiding, 1);
      await _settle();
      expect(session.vault, isNull);
      expect(opened.closed, isTrue);
      await w.everyday();
      expect(w.homeIds, {_g1});
      expect(w.router.hides(_v), isTrue);
    });

    test('a lock while the session is read again after a move', () async {
      final w = await _World.make();
      await w.open();
      final hold = Completer<void>();
      final asked = Completer<void>();
      w.vaultRows
        ..holdHeld = hold
        ..heldAsked = asked;
      final hiding = w.app.hideChats(people: [_v]);
      await asked.future;
      w.app.lockingUp();
      w.vaultRows.holdHeld = null;
      hold.complete();
      expect(await hiding, 1);
      await _settle();
      // the rebuilt session is not put back over the everyday one
      expect(session.vault, isNull);
      expect(lockState.inVault, isFalse);
      await w.everyday();
      expect(w.homeIds, {_g1});
    });

    test(
      'the list names who the vault took in before anything arrives',
      () async {
        final w = await _World.make();
        await w.open();
        // someone joins the hidden group while it is open
        w.vaultRows
          ..person(_n, accepted: 0)
          ..members[_g2]!.add(_n);
        w.io.sessions = [_n, _v];
        expect(w.router.keeps(_n), isFalse);
        w.app.lockingUp();
        // at once, before the vault has been given back
        await w.onion(
          _n,
          await wrapMessage('hello from n', msgUid: 'nn', sender: _as(_n)),
        );
        expect(w.router.keeps(_n), isTrue);
        expect(w.store.inbox, hasLength(1));
        expect(w.liveRows.people[_n], isNull);
        expect(w.liveRows.uids, isNot(contains('nn')));
        expect(w.io.rang, isEmpty);
        await w.everyday();
        expect(w.app.pendingCount, 1);
      },
    );

    test('a vault shut by an unlock that finds it open', () async {
      final w = await _World.make();
      await w.open();
      final opened = w.handle;
      // no lock-up reached the app: the next outcome shuts it first
      await w.everyday();
      expect(session.vault, isNull);
      expect(opened.closed, isTrue);
      expect(w.homeIds, {_v, _g1});
    });
  });

  group('notifications', () {
    test('shut: a hidden chat shows nothing of any kind', () async {
      final w = await _World.make();
      await w.open();
      await w.lockUp();
      await w.onion(
        _h,
        await wrapMessage('are you there', msgUid: 'n1', sender: _as(_h)),
      );
      await w.onion(
        _m,
        await wrapMessage('in the group', msgUid: 'n2', groupId: _g2),
      );
      expect(w.io.rang, isEmpty);
      expect(w.store.inbox, hasLength(2));
      expect(w.liveRows.uids, isNot(anyOf(contains('n1'), contains('n2'))));
      expect(w.homeIds, isNot(anyOf(contains(_h), contains(_g2))));
      expect(w.app.pendingCount, 1);
      // and a visible one rings as always
      await w.onion(_v, await wrapMessage('yo', msgUid: 'n3', sender: _as(_v)));
      expect(w.io.rang, [_v]);
    });

    test(
      'open: a hidden chat rings like any other, and goes at the lock',
      () async {
        final w = await _World.make();
        await w.open();
        await w.onion(
          _h,
          await wrapMessage('hi', msgUid: 'o1', sender: _as(_h)),
        );
        await w.onion(_m, await wrapMessage('all', msgUid: 'o2', groupId: _g2));
        await w.onion(
          _v,
          await wrapMessage('yo', msgUid: 'o3', sender: _as(_v)),
        );
        expect(w.io.rang, [_h, 'group:$_g2', _v]);
        expect(w.vaultRows.uids, containsAll(['o1', 'o2']));
        expect(w.liveRows.uids, contains('o3'));
        // a muted hidden chat is quiet, as a muted everyday one is
        w.vaultRows.people[_h]!['muted'] = 1;
        await w.onion(
          _h,
          await wrapMessage('sh', msgUid: 'o4', sender: _as(_h)),
        );
        expect(w.io.rang, hasLength(3));
        await w.lockUp();
        expect(w.io.unrang, unorderedEquals([_h, 'group:$_g2']));
        expect(w.io.unrang, isNot(contains(_v)));
      },
    );

    test('one arriving as the lock goes up is kept and never rings', () async {
      final w = await _World.make();
      await w.open();
      final opened = w.handle;
      w.vaultRows.onSave = () {
        w.vaultRows.onSave = null;
        w.app.lockingUp();
      };
      await w.onion(
        _h,
        await wrapMessage('late', msgUid: 'l1', sender: _as(_h)),
      );
      await _settle();
      expect(w.vaultRows.msg('l1'), isNotNull);
      expect(w.io.rang, isEmpty);
      expect(opened.closed, isTrue);
      expect(w.store.inbox, isEmpty);
    });
  });

  group('inside the vault', () {
    test('hiding a chat moves it and rebuilds the session', () async {
      final w = await _World.make();
      await w.open();
      expect(session.isHidden(_v), isFalse);
      expect(await w.app.hideChats(people: [_v]), 1);
      expect(session.isHidden(_v), isTrue);
      expect(w.app.contacts.firstWhere((c) => c.haloId == _v).hidden, isTrue);
      expect(w.router.hides(_v), isTrue);
      expect(w.vaultRows.uids, contains('v0'));
      expect(w.liveRows.uids, isNot(contains('v0')));
      // what V sends now goes into the vault, and rings while it is open
      await w.onion(
        _v,
        await wrapMessage('hey', msgUid: 'x1', sender: _as(_v)),
      );
      expect(w.vaultRows.uids, contains('x1'));
      expect(w.io.rang, [_v]);
      await w.lockUp();
      await w.everyday();
      expect(w.homeIds, {_g1});
      await w.onion(
        _v,
        await wrapMessage('hey', msgUid: 'x2', sender: _as(_v)),
      );
      expect(w.io.rang, [_v]);
      expect(w.store.inbox, hasLength(1));
    });

    test('Show in chat list brings a chat back', () async {
      final w = await _World.make();
      await w.open();
      expect(await w.app.unhideChats(people: [_h]), 1);
      expect(session.isHidden(_h), isFalse);
      expect(w.app.contacts.firstWhere((c) => c.haloId == _h).hidden, isFalse);
      expect(w.router.hides(_h), isFalse);
      await w.lockUp();
      await w.everyday();
      expect(w.homeIds, containsAll([_v, _g1, _h]));
      expect(w.homeIds, isNot(contains(_g2)));
      expect(w.liveRows.uids, containsAll(['h0', 'h1', 'h2']));
      await w.onion(
        _h,
        await wrapMessage('back', msgUid: 'b1', sender: _as(_h)),
      );
      expect(w.io.rang, [_h]);
      expect(w.liveRows.uids, contains('b1'));
    });

    test('the outbox, burns and search cover it; shut, they wait', () async {
      final w = await _World.make();
      w.app.sendModeForTest = 'fast';
      // shut: its unsent message waits in it, and so does its timer
      await w.app.drainOutbox();
      await _settle();
      expect(w.io.to(_h), isEmpty);
      expect(w.vaultRows.msg('h2')!['sent'], 0);
      expect(w.vaultRows.msg('h3'), isNotNull);
      // open: its timer goes, its message goes out, its index fills
      w.vaultRows.fill = (at: 4, to: 10);
      await w.open();
      await _settle();
      expect(w.vaultRows.msg('h3'), isNull);
      expect(w.vaultRows.msg('h2')!['sent'], 1);
      expect(w.io.to(_h), hasLength(1));
      expect(w.handle.calls, contains('fillSearchIndex'));
      expect(searchFill.value.to, 10);
      // shut, the search screen's line knows nothing of it
      await w.lockUp();
      expect(searchFill.value, (at: 0, to: 0));
    });
  });

  group('the mark on a hidden row', () {
    Widget row(bool on, {bool rtl = false, bool still = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Hanna'),
              HiddenMark(on: on),
            ],
          ),
        ),
      ),
    );

    testWidgets('comes in with a spring and reads Hidden', (tester) async {
      final sem = tester.ensureSemantics();
      await tester.pumpWidget(row(false));
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
      await tester.pumpWidget(row(true));
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byIcon(Icons.visibility_off_outlined),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(mid.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hidden'), findsOneWidget);
      // after the name, whichever way the language reads
      final name = tester.getCenter(find.text('Hanna')).dx;
      expect(
        tester.getCenter(find.byIcon(Icons.visibility_off_outlined)).dx,
        greaterThan(name),
      );
      await tester.pumpWidget(row(true, rtl: true));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byIcon(Icons.visibility_off_outlined)).dx,
        lessThan(tester.getCenter(find.text('Hanna')).dx),
      );
      sem.dispose();
    });

    testWidgets('with reduced motion it is simply there', (tester) async {
      await tester.pumpWidget(row(false, still: true));
      await tester.pumpWidget(row(true, still: true));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(row(false, still: true));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });
  });

  group('the wipe PIN', () {
    // every container's files, keys and settings, as a phone with all of
    // them holds them
    Future<void> fill() async {
      final d = Directory(p.join(docs.path, 'docs'))..createSync();
      for (final f in [
        'halo.db',
        'halo.db-wal',
        'halo_d.db',
        'halo_v.db',
        'halo_v.db-shm',
        'halo_dv.db',
        'onion.key',
      ]) {
        File(p.join(d.path, f)).writeAsStringSync(f);
      }
      for (final f in [
        'media/a.jpg',
        'media_d/b.jpg',
        'media_v/c.jpg',
        'media_dv/d.jpg',
        'wallpapers_v/w.jpg',
      ]) {
        File(p.join(d.path, f))
          ..createSync(recursive: true)
          ..writeAsStringSync(f);
      }
      File(p.join(docs.path, 'support', 'cache'))
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
      File(p.join(docs.path, 'tmp', 'part'))
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
      FlutterSecureStorage.setMockInitialValues({
        'halo.db.passphrase': 'k',
        'halo.d.key': "x'00'",
        'halo.containers': HaloContainer.decoy.id,
        'halo.lock.table': '{}',
      });
      SharedPreferences.setMockInitialValues({'d.notif_hide_content': true});
    }

    Future<void> expectAllGone(int? exited) async {
      expect(exited, 0);
      for (final sub in ['docs', 'support', 'tmp']) {
        final left = Directory(
          p.join(docs.path, sub),
        ).listSync(recursive: true).map((e) => p.basename(e.path));
        expect(left, isEmpty, reason: sub);
      }
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    }

    late int? exited;
    setUp(() {
      exited = null;
      wipeExit = (code) => exited = code;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('halo/platform'),
            (call) async => call.method == 'wipe' ? false : null,
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    });

    // typed on the lock screen, as it acts on it
    Future<void> typeWipe(LockState lock) async {
      expect(await lock.verifyPin(wipePin), PinResult.panic);
      await wipeHalo();
    }

    for (final from in ['the pin screen', 'everyday', 'decoy', 'vault']) {
      test('wipes every container from $from', () async {
        await fill();
        final w = await _World.make();
        final lock = _lock().lock;
        await lock.load();
        lock.onOutcome = w.app.sessionFor;
        switch (from) {
          case 'everyday':
            expect(await lock.verifyPin(appPin), PinResult.normal);
          case 'decoy':
            expect(await lock.verifyPin(decoyPin), PinResult.decoy);
            useDatabasesForTest(
              w.live,
              Session(_Db(HaloContainer.decoy, _Rows())),
            );
            lock.inDecoy = true;
          case 'vault':
            expect(await lock.verifyPin(vaultPin), PinResult.vault);
            expect(session.isHidden(_h), isTrue);
        }
        if (from != 'the pin screen') {
          lock.lock();
          w.app.lockingUp();
        }
        await typeWipe(lock);
        await expectAllGone(exited);
      });
    }

    test('wipes every container from inside the open vault', () async {
      await fill();
      final w = await _World.make();
      final lock = _lock().lock;
      await lock.load();
      lock.onOutcome = w.app.sessionFor;
      expect(await lock.verifyPin(vaultPin), PinResult.vault);
      lock.inVault = true;
      // the Enter your PIN step of a flow takes it as the lock screen does
      expect(await lock.confirmPin(wipePin), PinResult.panic);
      await wipeHalo();
      await expectAllGone(exited);
    });
  });
}
