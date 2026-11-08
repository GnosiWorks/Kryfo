// SPDX-License-Identifier: GPL-3.0-or-later
// own-device sync in the app (own_sync.dart): what I send or do on one
// device of mine lands on the others. a copy of mine is filed in its chat
// as mine; a contact's frame my phone passes on is filed as theirs; a
// state op moves what the person did there. only the everyday side sends
// or takes any of it: never a hidden chat, never a chat with screenshots
// blocked, never a burner room, and nothing leaves while the decoy is
// open. nothing here runs with the switch off

part of '../main.dart';

OwnSync? _ownSync;

/// the own sync, once the device state loaded; null with the switch off
OwnSync? get ownSync => _ownSync;

@visibleForTesting
void ownSyncForTest(OwnSync? s) => _ownSync = s;

// own frames go out from the everyday side alone, never while the decoy or
// any quiet session is open
bool get _ownSends =>
    linkedDevicesOn &&
    !sessionQuiet &&
    !lockState.inDecoy &&
    live.container == HaloContainer.everyday;

void _bootOwnSync(DeviceState ds, DeviceSend send, DeviceReceive recv) {
  final own = OwnSync(
    state: ds,
    db: live.open,
    send: send,
    me: _devMeOf,
    apply: const _AppOwn(),
  );
  _ownSync = own;
  recv.ownSync = own;
  recv.ownAdded = _ownAddedHere;
  ownNoted = _ownNote;
  // the badge moved on my phone: my devices hear it at the next pass
  supporterMoved = () => _madeApp?._ownPassSoon();
  lockGuard.onLifted = () => unawaited(_ownBeat());
  unawaited(() async {
    try {
      final r = await (await live.open()).query(
        'signal_meta',
        columns: ['v'],
        where: 'k = ?',
        whereArgs: [kOwnPhoneIdMeta],
        limit: 1,
      );
      if (r.isNotEmpty) _ownPhoneId = r.first['v'] as String?;
      // whether the vault keeps what went too, before its first delete
      await _ownGoneOn(await live.open(), live.container);
      await _madeApp?._ownPass();
    } catch (e) {
      dlog('own: not started (${e.runtimeType})');
    }
  }());
}

/// the kryfo id my phone goes by, as a linked device learnt it from its
/// phone ('profile'): the same person as this device in every group
const kOwnPhoneIdMeta = 'own_phone_id';

/// on a linked device, signal_meta 'own_pb:' and a contact's kryfo id: the
/// block my phone last told for them (1 or 0)
const kOwnPhoneBlockMeta = 'own_pb:';

Future<int?> _ownPhoneBlockOf(Database d, String id) async {
  final r = await d.query(
    'signal_meta',
    columns: ['v'],
    where: 'k = ?',
    whereArgs: ['$kOwnPhoneBlockMeta$id'],
    limit: 1,
  );
  return r.isEmpty ? null : int.tryParse('${r.first['v']}');
}

Future<void> _ownPhoneBlockPut(Database d, String id, int b) => d.insert(
  'signal_meta',
  {'k': '$kOwnPhoneBlockMeta$id', 'v': '$b'},
  conflictAlgorithm: ConflictAlgorithm.replace,
);

String? _ownPhoneId;

/// the kryfo id to show as mine: a linked device's is its phone's, never
/// the one its own container made before the link
String get ownShownId =>
    linkedRole && !sessionQuiet ? (_ownPhoneId ?? '') : appState.sessionId;

// a person unlocked this device: its phone hears it is in use
Future<void> _ownBeat() async {
  final own = _ownSync;
  if (own == null || !_ownSends || !linkedRole) return;
  try {
    await own.beat(kMainIdent);
  } catch (e) {
    dlog('own: no beat (${e.runtimeType})');
  }
}

// what the session tells of the person's own doing (session.dart)
void _ownNote(String kind, OwnChat chat, Map<String, Object?> a) {
  final own = _ownSync;
  if (own == null || !_ownSends) return;
  // a linked device's clear of a whole chat stays on it (kOwnChatEndsBothWays)
  if (linkedRole && !kOwnOpsFromDevice.contains(kind)) return;
  // note to self tells only a delete and a clear
  if (isOwnNotes(chat) && !kOwnNoteOps.contains(kind)) return;
  unawaited(() async {
    try {
      if (!await _ownChatShared(chat)) return;
      await own.op(_ownIdentOf(chat), kind, chat, a);
    } catch (e) {
      dlog('own: an op not sent (${e.runtimeType})');
    }
  }());
}

int _ownIdentOf(OwnChat chat) =>
    chat.group || isOwnNotes(chat) ? kMainIdent : identOfPeer(chat.id);

// whether [chat] is one my devices share messages of: on the everyday
// side, not hidden, not a burner room, no screenshot block
Future<bool> _ownChatShared(OwnChat chat) =>
    _ownChatKnown(chat, messages: true);

// whether my devices hold [chat]'s rows: as above, a chat with screenshots
// blocked too (its row and its block, never its messages)
Future<bool> _ownChatKnown(OwnChat chat, {bool messages = false}) async {
  final app = _madeApp;
  if (app == null) return false;
  final db = await live.open();
  if (chat.group) {
    if (app._routeOf('', chat.id) != RouteTo.everyday) return false;
    final g = await db.query(
      'groups',
      columns: ['shots_on'],
      where: 'group_id = ?',
      whereArgs: [chat.id],
      limit: 1,
    );
    if (g.isEmpty || (messages && g.first['shots_on'] == 1)) return false;
    return await app._roomOf(chat.id, live) == null;
  }
  // note to self: its items are my devices', it has no row to hold
  if (isOwnNotes(chat)) return messages;
  if (isDevId(chat.id)) return false;
  if (app._routeOf(chat.id, null) != RouteTo.everyday) return false;
  // a chat deleted or forgotten here (accepted 0) shares nothing more
  final c = await db.query(
    'contacts',
    columns: ['shots_on'],
    where: 'halo_id = ? AND accepted = 1',
    whereArgs: [chat.id],
    limit: 1,
  );
  return c.isNotEmpty && !(messages && c.first['shots_on'] == 1);
}

@visibleForTesting
Future<void> ownAddedForTest(
  int ident,
  List<({int id, String key, int reg})> added,
) => _ownAddedHere(ident, added);

// my own devices my list names that have no row here: each comes with its
// notice, as on the phone that linked it
Future<void> _ownAddedHere(
  int ident,
  List<({int id, String key, int reg})> added,
) async {
  if (added.isEmpty) return;
  final db = await live.open();
  var any = false;
  for (final e in added) {
    final had = await db.rawQuery(
      'SELECT 1 FROM own_device_keys k JOIN own_devices d ON d.uid = k.uid '
      'WHERE k.ident = ? AND k.key = ? AND d.removed_at IS NULL LIMIT 1',
      [ident, e.key],
    );
    if (had.isNotEmpty) continue;
    try {
      await db.transaction(
        (t) => addOwnDevice(
          t,
          uid: newDeviceUid(),
          name: _ownDeviceName,
          kind: DeviceKind.computer,
          linkedAt: DateTime.now(),
          keys: [(ident: ident, dev: e.id, key: e.key, reg: e.reg)],
        ),
      );
      any = true;
    } catch (e) {
      dlog('own: a device not added (${e.runtimeType})');
    }
  }
  if (any) await readLinkNotices(db);
}

/// the rows a contact's state op carries: what a person sets on a chat. a
/// linked device sends only these, its phone the whole row. a block goes
/// from the phone alone unless kOwnChatEndsBothWays
const kOwnContactSet = [
  'nickname',
  'note',
  'muted',
  'archived',
  'pinned',
  if (kOwnChatEndsBothWays) 'blocked',
];

/// on a linked device, a whole chat deleted or cleared goes from this
/// device alone (kOwnChatEndsBothWays off): what its confirm says
bool get ownChatEndsHere => linkedRole && !kOwnChatEndsBothWays;

/// a clear's confirm line in a chat or a group: this device's own words on
/// a linked device, as the desk words are a computer's (desk_words.dart)
String ownClearLine({required bool group}) => ownChatEndsHere
    ? l10n.linkedClearHereOnly
    : group
    ? l10n.groupInfoEveryMessageHereIsShown
    : l10n.chatEveryMessageHereIsShown;

/// a block's confirm line in a chat or on a contact's page: on a linked
/// device the block is this device's own, and its phone keeps theirs
String ownBlockLine({required bool chat}) => ownChatEndsHere
    ? l10n.linkedBlockHereOnly
    : chat
    ? l10n.chatTheirMessagesStopArriving
    : l10n.contactTheirMessagesStopArriving;

/// a delete's confirm line on a contact's page, the same way
String get ownDeleteLine => ownChatEndsHere
    ? l10n.linkedDeleteHereOnly
    : l10n.contactEveryMessageAndTheShown;

/// what the app does with own frames, for the tests
@visibleForTesting
OwnApply get ownApplyForTest => const _AppOwn();

/// whether a contact's phone session is post-quantum, for the tests
@visibleForTesting
Future<bool> Function(String peer)? phonePqForTest;

/// the pass that tells my devices what moved, run now, for the tests
@visibleForTesting
Future<void> ownPassForTest() async => _madeApp?._ownPass();

/// a device just linked: my profile to my devices, for the tests
@visibleForTesting
Future<void> ownTellMeForTest() async => _madeApp?._ownTellMe();

/// what the session tells of the person's doing, as the app takes it, for
/// the tests
@visibleForTesting
void Function(String kind, OwnChat chat, Map<String, Object?> a)
get ownNoteForTest => _ownNote;

/// what waited while the decoy was open, sent now, for the tests
@visibleForTesting
Future<void> ownHeldGoForTest() async => _madeApp?._ownHeldGo();

/// a hide's own part around [move], for the tests
@visibleForTesting
Future<void> ownAroundHideForTest(
  List<String> people,
  Future<void> Function() move,
) async {
  final app = _madeApp!;
  final chats = [for (final p in people) ChatRef(p)];
  final told = await app._ownBeforeHide(chats);
  try {
    await move();
  } finally {
    await app._ownAfterHide(told, chats);
  }
}

class _AppOwn implements OwnApply {
  const _AppOwn();

  @override
  Future<bool> copy(
    int ident,
    OwnChat chat,
    String frame, {
    List<String> notReached = const [],
  }) async {
    final app = _madeApp;
    if (app == null) return false;
    // note to self is the everyday identity's alone
    if (isOwnNotes(chat) && ident != kMainIdent) return false;
    return app._fileOwnCopy(chat, frame, notReached: notReached);
  }

  @override
  Future<bool> forward(int ident, String sender, String frame, int came) async {
    final app = _madeApp;
    if (app == null) return false;
    return app._fileOwnForward(sender, frame, came);
  }

  @override
  Future<bool> op(
    int ident,
    OwnChat? chat,
    String kind,
    Map<String, dynamic> a,
  ) async {
    final app = _madeApp;
    if (app == null) return false;
    return app._applyOwnOp(chat, kind, a);
  }

  @override
  Future<void> heard(int ident, int device, String key, int at) async {
    await ownDeviceHeard(
      await live.open(),
      ident: ident,
      dev: device,
      key: key,
      at: at,
    );
  }
}

/// a linked device's seal went: its copies are on their way from here
class DeviceSent implements Exception {
  const DeviceSent();
}

/// a linked device cannot reach [peer] itself (no list of theirs, an
/// older Kryfo, a hidden chat): what goes to them goes from my phone
class DeviceCannotReach implements Exception {
  const DeviceCannotReach(this.peer);
  final String peer;
}

enum _DeviceSend { sent, cannot, failed }

/// a send this linked device could not make: its phone answers that chat
const kNotFromDevice = 'error: not from this device';

/// what a send makes of a seal that threw on a linked device: 'ok' when its
/// copies went from here (DeviceSent), [kNotFromDevice] when no device of
/// theirs holds a session with this one, null for any other failure
String? deviceSealOutcome(Object e) => e is DeviceSent
    ? 'ok'
    : e is DeviceCannotReach
    ? kNotFromDevice
    : null;

/// how long a linked device gathers a group frame's members before its own
/// copy goes, naming the ones it could not reach
const kOwnGroupWait = Duration(seconds: 3);

final _ownGroupWait = <String, Set<String>>{};
final _ownGroupTold = <String>{};
final _ownGroupTimers = <String, Timer>{};

/// a group frame of mine to [member], handed on as a send hands it
@visibleForTesting
void ownGroupCopyForTest(
  String groupId,
  String member,
  String wrapped, {
  required bool reached,
}) => _madeApp?._ownGroupCopy(groupId, member, wrapped, reached: reached);

/// every own copy of a group frame still gathering, sent now
@visibleForTesting
Future<void> ownGroupFlushForTest() async {
  final due = Map.of(_ownGroupTimers);
  _ownGroupTimers.clear();
  for (final e in due.entries) {
    e.value.cancel();
    await _ownGroupGo(e.key);
  }
}

Future<void> _ownGroupGo(String k) async {
  _ownGroupTimers.remove(k);
  final missed = _ownGroupWait.remove(k);
  final own = _ownSync;
  if (missed == null || own == null) return;
  final at = k.indexOf('\n');
  final groupId = k.substring(0, at);
  final frame = k.substring(at + 1);
  try {
    if (!await _ownChatShared((id: groupId, group: true))) return;
    // deleted here while it gathered: a copy only my devices would take
    // goes no more
    if (missed.isEmpty && !await _ownFrameStill(groupId, frame)) return;
    await own.copy(
      kMainIdent,
      (id: groupId, group: true),
      frame,
      notReached: [...missed],
    );
  } catch (e) {
    dlog('own: a group copy not sent (${e.runtimeType})');
  }
}

// whether a message group [groupId]'s [frame] carries or speaks of is
// still here; true for a frame that names none
Future<bool> _ownFrameStill(String groupId, String frame) async {
  final ids = frameMessageUids(frame);
  if (ids.isEmpty) return true;
  for (final u in ids) {
    if ((await live.chatOf(u))?.$2 == groupId) return true;
  }
  return false;
}

// whether [uid] in [sender]'s chat, or in [group], went here or on another
// device of mine before it came: a contact's frame of it shows no more
Future<bool> _ownGoneFrom(
  HaloDb db,
  String sender,
  String? group,
  String uid,
) async {
  if (!linkedDevicesOn) return false;
  try {
    final chat = group != null
        ? (id: group, group: true)
        : (id: sender, group: false);
    return (await ownGoneOf(await db.open(), ownChatName(chat), [
      uid,
    ], now: DateTime.now().millisecondsSinceEpoch)).gone;
  } catch (_) {
    return false;
  }
}

extension AppStateOwn on AppState {
  // a frame of mine to [peer] from a linked device: on its device sessions
  // or not at all
  Future<_DeviceSend> _sendFromDevice(String peer, String wrapped) async {
    try {
      await _io.seal(peer, wrapped);
    } on DeviceSent {
      return _DeviceSend.sent;
    } on DeviceCannotReach {
      return _DeviceSend.cannot;
    } catch (e) {
      dlog('devices: a send from this device failed (${e.runtimeType})');
      return _DeviceSend.failed;
    }
    return _DeviceSend.failed;
  }

  // one own copy of a group frame for my other devices, whichever members
  // it went to: the phone's at once, a linked device's once every member's
  // send was tried, naming the ones it could not reach
  void _ownGroupCopy(
    String groupId,
    String member,
    String wrapped, {
    required bool reached,
  }) {
    if (_ownSync == null || !_ownSends) return;
    final k = '$groupId\n$wrapped';
    final held = _ownGroupWait[k];
    if (held != null) {
      if (!reached) held.add(member);
      return;
    }
    if (!linkedRole && _ownGroupTold.contains(k)) return;
    _ownGroupWait[k] = {if (!reached) member};
    if (!linkedRole) {
      _ownGroupTold.add(k);
      while (_ownGroupTold.length > 256) {
        _ownGroupTold.remove(_ownGroupTold.first);
      }
      unawaited(_ownGroupGo(k));
      return;
    }
    _ownGroupTimers[k] = Timer(kOwnGroupWait, () => unawaited(_ownGroupGo(k)));
  }

  // ---- copies of mine ----

  // a frame I sent from another device, filed in [chat] as mine. a group's
  // goes on from the phone to the members that device could not reach
  Future<bool> _fileOwnCopy(
    OwnChat chat,
    String frame, {
    List<String> notReached = const [],
  }) async {
    if (!linkedDevicesOn) return false;
    if (isOwnNotes(chat)) return _fileOwnNote(frame);
    if (!await _ownChatShared(chat)) return false;
    final env = unwrapMessage(frame);
    if (env.typing || env.deliveredUid != null || env.groupControl != null) {
      return false;
    }
    // a group frame names its group, a 1:1 one none
    if (chat.group != (env.groupId != null)) return false;
    if (chat.group && env.groupId != chat.id) return false;
    // one that went here comes back no more; the members it is owed still
    // get it from the phone
    final gone = await _ownGoneOf(chat, frame, written: env.writtenAt);
    final took = !gone.gone && await _fileOwnFrame(chat, env, gone.burnAt);
    if (chat.group && notReached.isNotEmpty && !linkedRole) {
      await _passGroupOn(chat.id, frame, notReached);
    }
    if (took) {
      _bumpChatRev(chat.group ? 'group:${chat.id}' : chat.id);
      if (chat.group) {
        await refreshGroups();
      } else {
        await refreshContacts();
      }
      notifyListeners();
    }
    return took;
  }

  Future<bool> _fileOwnFrame(
    OwnChat chat,
    UnwrappedMessage env,
    int? burnAt,
  ) async {
    final db = live;
    final group = chat.group ? chat.id : null;
    // whether uid is a row of mine in this chat
    Future<bool> mine(String uid) async {
      final d = await db.open();
      final r = await d.query(
        'messages',
        columns: ['id'],
        where: group == null
            ? "msg_uid = ? AND direction = 'out' AND peer_id = ? AND "
                  "(group_id IS NULL OR group_id = '')"
            : "msg_uid = ? AND direction = 'out' AND group_id = ?",
        whereArgs: [uid, group ?? chat.id],
        limit: 1,
      );
      return r.isNotEmpty;
    }

    Future<bool> here(String uid) async {
      final at = await db.chatOf(uid);
      if (at == null) return false;
      return group == null ? at.$1 == chat.id && at.$2 == null : at.$2 == group;
    }

    final ed = env.edit;
    if (ed != null) {
      if (!await mine(ed.targetUid)) return false;
      if (!await _inOrder(db, ed.targetUid, '', 'edit', env)) return false;
      final d = await db.open();
      await d.update(
        'messages',
        {'plaintext': unmarked(ed.newText), 'edited': 1},
        where: "msg_uid = ? AND direction = 'out' AND sticker IS NULL",
        whereArgs: [ed.targetUid],
      );
      return true;
    }
    final un = env.unsend;
    if (un != null) {
      // one not here yet stays out when its copy comes
      await _ownGoneUid(chat, un);
      if (!await mine(un)) return false;
      await db.deleteMessage(un);
      unawaited(_io.unnotifyMessage(un));
      return true;
    }
    final r = env.reaction;
    if (r != null) {
      if (!await here(r.targetUid) || r.emoji.length > 32) return false;
      if (!await _inOrder(db, r.targetUid, '', 'reaction', env)) return false;
      if (r.emoji.isEmpty) {
        await db.removeReaction(r.targetUid, '');
      } else {
        await db.addReaction(r.targetUid, '', r.emoji);
      }
      return true;
    }
    final pn = env.pin;
    if (pn != null) {
      if (!await here(pn.targetUid)) return false;
      await db.setPinned(pn.targetUid, pn.pinned);
      return true;
    }
    final vt = env.vote;
    if (vt != null) {
      if (group == null) return false;
      final row = await db.pollRow(vt.pollUid);
      if (row == null || row.groupId != group || row.spec.closed) return false;
      await db.putPollVote(
        vt.pollUid,
        await meIn(group),
        group,
        cleanChoices(vt.choices, row.spec),
        vt.seq,
      );
      return true;
    }
    final pc = env.pollClose;
    if (pc != null) {
      if (group == null) return false;
      final row = await db.pollRow(pc.pollUid);
      if (row == null || row.groupId != group || row.spec.closed) return false;
      if (!await mine(pc.pollUid)) return false;
      await db.closePollRow(
        pc.pollUid,
        row.spec,
        cleanFinal(pc.finalVotes, row.spec),
        group,
      );
      return true;
    }
    return _fileOwnMessage(chat, env, burnAt);
  }

  // a message of mine: text, a sticker, a poll, a picture or a file whole
  // or in slices. one already here is not filed again, nor one whose time
  // ran out. [burnAt]: when my other device burns it
  Future<bool> _fileOwnMessage(
    OwnChat chat,
    UnwrappedMessage env,
    int? burnAt,
  ) async {
    final db = live;
    final group = chat.group ? chat.id : null;
    final sliced = AppState._sliced(env);
    final uid = sliced ? env.mediaId : env.msgUid;
    if (uid == null) return false;
    if (await db.messageExists(uid)) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final written = env.writtenAt != null && env.writtenAt! <= now
        ? env.writtenAt!
        : now;
    final secs = (env.burnSeconds ?? 0) > 0 ? env.burnSeconds : null;
    var burns = secs == null ? null : written + secs * 1000;
    if (burns != null && burnAt != null && burnAt < burns) burns = burnAt;
    // its time ran out on my other devices as well
    if (burns != null && burns <= now) {
      if (sliced) await db.dropMediaChunks(uid);
      return false;
    }
    final got = await _ownMediaIn(env, uid, group: group);
    if (got == null) return false;
    final (:mediaPath, :filePath, :unsaved) = got;
    final text = unsaved
        ? [
            env.message,
            l10n.appAnAttachmentCouldNotShown,
          ].where((s) => s.trim().isNotEmpty).join('\n')
        : env.message;
    final bare =
        env.imageB64 == null &&
        env.fileB64 == null &&
        env.drop == null &&
        env.fileName == null &&
        env.mediaId == null &&
        env.poll == null;
    final sticker = bare ? StickerWire.parse(env.sticker) : null;
    final shown = sticker == null
        ? text
        : stickerText(sticker, env.message, await _stickers());
    if (shown.trim().isEmpty &&
        sticker == null &&
        mediaPath == null &&
        filePath == null &&
        env.poll == null) {
      return false;
    }
    await db.saveMessage(
      group == null ? chat.id : sessionId,
      'out',
      shown,
      album: env.album,
      burnSecs: secs,
      // a timed one of mine counts from when it went, as on the device
      // that sent it
      burnAt: burns,
      msgUid: uid,
      replyTo: env.replyTo,
      groupId: group,
      voiceDisguised: env.voiceDisguised,
      mediaPath: mediaPath,
      filePath: filePath,
      fileName: env.fileName,
      preview: env.preview == null ? null : jsonEncode(env.preview),
      secure: env.secure,
      poll: group == null ? null : _arrivingPoll(env.poll),
      sticker: sticker?.value,
      sentAt: now,
      writtenAt: written,
    );
    if (sliced) await db.dropMediaChunks(uid);
    return true;
  }

  // the picture or file a frame of mine carries, whole or in slices, put
  // in this container's media. null while slices are still to come, or
  // for slices that cannot be (too many, out of place, another's); unsaved
  // when what came would not save, or waits on the files service
  Future<({String? mediaPath, String? filePath, bool unsaved})?> _ownMediaIn(
    UnwrappedMessage env,
    String uid, {
    String? group,
  }) async {
    final db = live;
    String? mediaPath;
    String? filePath;
    var unsaved = false;
    if (AppState._sliced(env)) {
      final total = env.chunkTotal!;
      final index = env.chunkIndex ?? 0;
      if (total > kMaxSlices || index < 0 || index >= total) return null;
      if (env.msgUid != null && env.msgUid != uid) return null;
      final owner = await db.mediaChunkSender(uid);
      if (owner != null && owner != _kOwnChunks) return null;
      final have = await db.putMediaChunk(
        uid,
        index,
        (env.imageB64 ?? env.fileB64) ?? '',
        total,
        env.burnSeconds,
        from: _kOwnChunks,
        group: group,
      );
      if (have < total) return null;
      if (env.pvImg) {
        await db.dropMediaChunks(uid);
        return null;
      }
      try {
        final out = env.fileName != null
            ? await receivedFileFor(env.fileName!, db.container)
            : await receivedImageFor(db.container);
        final path = await saveSlices(
          out,
          total,
          (i) => db.mediaChunkSlice(uid, i),
        );
        if (env.fileName != null) {
          filePath = path;
        } else {
          mediaPath = path;
        }
      } catch (e) {
        dlog('own: slices not saved (${e.runtimeType})');
        unsaved = true;
      }
    } else {
      final img = env.imageB64;
      final file = env.fileB64;
      try {
        if (img != null && img.isNotEmpty) {
          mediaPath = await saveMediaBytes(base64Decode(img), db.container);
        }
        if (file != null && file.isNotEmpty) {
          filePath = await saveFileBytes(
            base64Decode(file),
            env.fileName ?? 'file',
            db.container,
          );
        }
      } catch (e) {
        dlog('own: a file not saved (${e.runtimeType})');
        unsaved = true;
      }
      // a file on the files service: fetched where it was sent from only
      if (env.drop != null) unsaved = true;
    }
    return (mediaPath: mediaPath, filePath: filePath, unsaved: unsaved);
  }

  // a group frame of mine a linked device could not send to [members]:
  // this phone sends it to each, as its own, and keeps what fails owed
  Future<void> _passGroupOn(
    String groupId,
    String frame,
    List<String> members,
  ) async {
    final d = _ownerOf(groupId);
    final inGroup = (await d.getGroupMembers(groupId)).toSet();
    final to = [
      for (final m in members)
        if (inGroup.contains(m) && m != myId) m,
    ];
    if (to.isEmpty) return;
    final wrapped = _ownRewrapped(frame);
    if (wrapped == null) return;
    final held = <String>[];
    for (final m in to) {
      if (!await _sendGroupEnvelope(groupId, m, wrapped)) held.add(m);
    }
    if (held.isEmpty) return;
    try {
      await d.queueGroupWrapped(
        groupId,
        held,
        wrapped,
        now: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      dlog('own: a group frame not kept (${e.runtimeType})');
    }
  }

  // a frame of my device's as this phone sends it: only what a message
  // says (kOwnPassOnKeys), never a photo, a pq restart, an introduction or
  // anything else a device may not do as me; this phone's id and onion in
  String? _ownRewrapped(String frame) {
    try {
      final body =
          jsonDecode(frame.substring(kEnvelopePrefix.length))
              as Map<String, dynamic>;
      if (!ownCopyFits(body)) return null;
      final j = {
        for (final e in body.entries)
          if (kOwnPassOnKeys.contains(e.key)) e.key: e.value,
      };
      final s = _mySender();
      j['h'] = s.haloId;
      if (s.onion.isNotEmpty) j['o'] = s.onion;
      return '$kEnvelopePrefix${jsonEncode(j)}';
    } catch (_) {
      return null;
    }
  }

  // ---- what my phone passes on ----

  // a contact's frame my phone took, that could not reach this device: filed
  // as theirs, its tick already went from the phone
  Future<bool> _fileOwnForward(String sender, String frame, int came) async {
    if (!linkedDevicesOn || !linkedRole) return false;
    final env = unwrapMessage(frame);
    if (env.typing) return false;
    // what a chat with screenshots blocked says stays on the phone
    if (env.groupId != null) {
      if (!await _ownChatShared((id: env.groupId!, group: true))) return false;
    } else if (!await _ownChatShared((id: sender, group: false)) ||
        !await live.isAccepted(sender)) {
      // a chat forgotten here (a hide on the phone) takes nothing
      return false;
    }
    // what went here or on my phone before this came stays out
    final chat = env.groupId != null
        ? (id: env.groupId!, group: true)
        : (id: sender, group: false);
    final gone = await _ownGoneOf(chat, frame, written: came);
    if (gone.gone) return false;
    final to = await _applyIncomingPayload(
      sender,
      env,
      wire: frame,
      fromDevice: true,
      arrivedAt: came,
    );
    final burnAt = gone.burnAt;
    final uid = AppState._sliced(env) ? env.mediaId : env.msgUid;
    if (burnAt != null && uid != null) {
      // its clock started on my phone: it burns here no later
      await (await live.open()).rawUpdate(
        'UPDATE messages SET burn_at = ? WHERE msg_uid = ? AND '
        'burn_secs IS NOT NULL AND (burn_at IS NULL OR burn_at > ?)',
        [burnAt, uid, burnAt],
      );
    }
    if (AppState._shown(to)) notifyListeners();
    return AppState._shown(to);
  }

  // a contact's frame this phone just filed: it goes on to my devices when
  // that contact cannot reach them (an older Kryfo, a classic session, my
  // list not with them yet, not a contact at all), never a hidden chat's
  // or one with screenshots blocked
  Future<void> _ownPassOn(
    String sender,
    UnwrappedMessage env,
    String wire,
    RouteTo to,
  ) async {
    final own = _ownSync;
    if (own == null || !linkedDevicesOn || linkedRole) return;
    if (to != RouteTo.everyday) return;
    // in the decoy or a quiet session it waits on the everyday side (M3)
    final hold = !_ownSends;
    if (hold && live.container != HaloContainer.everyday) return;
    if (env.typing || env.pqRestart != null || env.photo != null) return;
    if (env.need != null || env.intro != null) return;
    if (deviceWordsOnly(wire)) return;
    final plain = withoutDeviceWords(wire);
    if (await live.isBlocked(sender)) return;
    // a request stays on the phone until it is accepted there
    if (env.groupId == null && !await live.isAccepted(sender)) return;
    final chat = env.groupId != null
        ? (id: env.groupId!, group: true)
        : (id: sender, group: false);
    try {
      if ((await own.others(identOfPeer(sender))).isEmpty) return;
      if (!await _ownChatShared(chat)) return;
      if (await _reachesMyDevices(sender)) return;
      if (hold) {
        await _ownHold(chat, sender, plain);
        return;
      }
      await own.forward(identOfPeer(sender), sender, plain, _clockMs());
    } catch (e) {
      dlog('own: a frame not passed on (${e.runtimeType})');
    }
  }

  // a frame to pass on, kept in the everyday database while the decoy is
  // open: no time of its own, so my devices learn nothing of when the
  // phone took it
  Future<void> _ownHold(OwnChat chat, String sender, String frame) async {
    if (frame.length > kOwnFrameMost) return;
    final d = await live.open();
    final n =
        Sqflite.firstIntValue(
          await d.rawQuery('SELECT COUNT(*) FROM own_held'),
        ) ??
        0;
    if (n >= kOwnHeldMost) return;
    await d.insert('own_held', {
      'uid': ownHash('$sender\n$frame'),
      'chat': ownChatName(chat),
      'sender': sender,
      'frame': frame,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // what waited while the decoy was open goes on, stamped now, once the
  // everyday side sends again; a chat hidden or gone since takes nothing
  Future<void> _ownHeldGo() async {
    final own = _ownSync;
    if (own == null || !_ownSends || linkedRole || _ownHeldGoing) return;
    _ownHeldGoing = true;
    try {
      final d = await live.open();
      final rows = await d.query('own_held', limit: 64);
      for (final r in rows) {
        final uid = r['uid'] as String;
        final sender = r['sender'] as String;
        final chat = ownChatOf(r['chat']);
        try {
          if (chat != null &&
              !await live.isBlocked(sender) &&
              (chat.group || await live.isAccepted(sender)) &&
              await _ownChatShared(chat)) {
            await own.forward(
              identOfPeer(sender),
              sender,
              r['frame'] as String,
              _clockMs(),
            );
          }
        } catch (e) {
          dlog('own: a held frame not passed on (${e.runtimeType})');
        }
        await d.delete('own_held', where: 'uid = ?', whereArgs: [uid]);
        if (!_ownSends) return;
      }
    } catch (e) {
      dlog('own: held frames not read (${e.runtimeType})');
    } finally {
      _ownHeldGoing = false;
    }
  }

  int _clockMs() => DateTime.now().millisecondsSinceEpoch;

  // whether [sender] sends to my devices themselves: a contact of mine who
  // reads lists, on a post-quantum session, who holds my list now
  Future<bool> _reachesMyDevices(String sender) async {
    final db = await live.open();
    final r = await db.query(
      'contacts',
      columns: ['ident', 'ikey', 'caps', 'accepted'],
      where: 'halo_id = ?',
      whereArgs: [sender],
      limit: 1,
    );
    if (r.isEmpty || r.first['accepted'] != 1) return false;
    final ikey = r.first['ikey'] as String?;
    if (ikey == null) return false;
    if (!capsOfText(r.first['caps'] as String?).contains(kCapDevices)) {
      return false;
    }
    final ident = r.first['ident'] as int? ?? kMainIdent;
    // a list of mine on its way to them: they cannot reach a new device yet
    final owed = await db.query(
      'dev_pushes',
      columns: ['kind'],
      where: "ident = ? AND peer = ? AND kind = 'add'",
      whereArgs: [ident, ikey],
      limit: 1,
    );
    if (owed.isNotEmpty) return false;
    final pq = phonePqForTest;
    if (pq != null) return pq(sender);
    final info = await (await signalOfIdent(ident)).sessionInfo(sender);
    return info != null && info.version >= 4 && info.pq;
  }

  // ---- state ops ----

  Future<bool> _applyOwnOp(
    OwnChat? chat,
    String kind,
    Map<String, dynamic> a,
  ) async {
    if (!linkedDevicesOn) return false;
    if (kind == 'profile') return _ownProfile(a);
    if (chat == null) return false;
    // note to self takes a delete and a clear, nothing a chat's rows carry
    if (isOwnNotes(chat) && !kOwnNoteOps.contains(kind)) return false;
    // a contact or a group new here comes only from my phone
    final shared = await _ownChatShared(chat);
    final known = await _ownChatKnown(chat);
    switch (kind) {
      case 'read':
        if (!shared) return false;
        if (chat.group) {
          await live.clearGroupUnread(chat.id);
        } else {
          await live.clearUnread(chat.id);
        }
        await _io.unnotify(chat.group ? 'group:${chat.id}' : chat.id);
        await _ownMarkPass(chat);
        return true;
      case 'lit':
        if (!shared) return false;
        final b = a['b'];
        if (b is! Map) return false;
        final d = await live.open();
        for (final e in b.entries.take(kOwnUidsMost)) {
          if (e.key is! String || e.value is! int) continue;
          if (!await _ownInChat(chat, e.key as String)) {
            // one not here yet burns when it would have, once it comes
            final k = e.key as String;
            if (k.isNotEmpty && k.length <= 128) {
              await ownGoneBurns(
                d,
                ownChatName(chat),
                k,
                e.value as int,
                now: _clockMs(),
              );
            }
            continue;
          }
          await d.rawUpdate(
            'UPDATE messages SET burn_at = ? WHERE msg_uid = ? AND '
            'burn_secs IS NOT NULL AND (burn_at IS NULL OR burn_at > ?)',
            [e.value, e.key, e.value],
          );
        }
        return true;
      case 'del':
        if (!shared && !_ownGoneKept(chat, known)) return false;
        final u = a['u'];
        if (u is! List) return false;
        var any = false;
        for (final x in u.take(kOwnUidsMost)) {
          if (x is! String || x.isEmpty || x.length > 128) continue;
          // one not here yet stays out when its copy comes
          await _ownGoneUid(chat, x);
          // a note whose file is still on its way: it stops and stays out
          if (isOwnNotes(chat) && await _noteFetchGone(x)) {
            any = true;
            continue;
          }
          if (!shared || !await _ownInChat(chat, x)) continue;
          await live.deleteMessage(x);
          // nothing of a note gone here waits for my other devices
          if (isOwnNotes(chat)) await ownNoteGone(x);
          unawaited(_io.unnotifyMessage(x));
          any = true;
        }
        if (any && isOwnNotes(chat)) notesMoved.value++;
        if (any) {
          _bumpChatRev(chat.group ? 'group:${chat.id}' : chat.id);
          notifyListeners();
        }
        return any;
      case 'clear':
        final t = a['t'];
        if (t is! int) return false;
        if (!shared && !_ownGoneKept(chat, known)) return false;
        await ownGoneMadeAt(t, () async {
          if (shared) await _ownClear(chat, t);
          // what was written before it stays out when it comes late
          await _ownGoneAllOf(chat);
        });
        return true;
      case 'contact':
        if (chat.group) return false;
        return _ownContact(chat.id, a['r'], shared: known);
      case 'gone':
        if (chat.group) return false;
        return ownGoneMadeAt(_ownMadeAt(a), () => _ownGone(chat.id));
      case 'group':
        if (!chat.group || !linkedRole) return false;
        return _ownGroup(chat.id, a);
      case 'ungroup':
        if (!chat.group || !linkedRole) return false;
        if (await live.getGroup(chat.id) == null) return false;
        // its notifications leave the shade with it (_dropGroup)
        await ownGoneMadeAt(_ownMadeAt(a), () => _dropGroup(chat.id, live));
        await _ownMarkPass(chat);
        await refreshGroups();
        return true;
    }
    return false;
  }

  Future<bool> _ownInChat(OwnChat chat, String uid) async {
    final at = await live.chatOf(uid);
    if (at == null) return false;
    return chat.group ? at.$2 == chat.id : at.$1 == chat.id && at.$2 == null;
  }

  // a clear made at [t]: what came after it stays
  Future<void> _ownClear(OwnChat chat, int t) async {
    if (isOwnNotes(chat)) return _ownClearNotes(t);
    final d = await live.open();
    final newer = await d.query(
      'messages',
      columns: ['id'],
      where: chat.group
          ? 'group_id = ? AND sent_at > ?'
          : "peer_id = ? AND (group_id IS NULL OR group_id = '') AND "
                'sent_at > ?',
      whereArgs: [chat.id, t],
      limit: 1,
    );
    if (newer.isEmpty) {
      if (chat.group) {
        await live.clearGroupConversation(chat.id);
      } else {
        await live.clearConversation(chat.id);
      }
    } else {
      for (final r in await d.query(
        'messages',
        columns: ['msg_uid'],
        where: chat.group
            ? 'group_id = ? AND sent_at <= ? AND msg_uid IS NOT NULL'
            : "peer_id = ? AND (group_id IS NULL OR group_id = '') AND "
                  'sent_at <= ? AND msg_uid IS NOT NULL',
        whereArgs: [chat.id, t],
      )) {
        await live.deleteMessage(r['msg_uid'] as String);
      }
    }
    _bumpChatRev(chat.group ? 'group:${chat.id}' : chat.id);
    notifyListeners();
  }

  // a contact's rows: my phone's whole row, or what a linked device set
  Future<bool> _ownContact(String id, Object? r, {required bool shared}) async {
    if (r is! Map) return false;
    final row = r.cast<String, dynamic>();
    final d = await live.open();
    final cols = {
      for (final c in await d.rawQuery("PRAGMA table_info('contacts')"))
        c['name'] as String,
    };
    if (!linkedRole) {
      // the phone takes what a person sets, on a chat of the everyday side
      if (!shared) return false;
      final set = {
        for (final k in kOwnContactSet)
          if (k != 'blocked' && row.containsKey(k) && cols.contains(k))
            k: row[k],
      };
      if (set.isNotEmpty) {
        await d.update('contacts', set, where: 'halo_id = ?', whereArgs: [id]);
      }
      // a block goes the way a block here goes
      final b = kOwnChatEndsBothWays ? row['blocked'] : null;
      if ((b == 0 || b == 1) && (b == 1) != await live.isBlocked(id)) {
        await live.setBlocked(id, b == 1);
      }
      await refreshContacts();
      return true;
    }
    // a linked device takes its phone's: a row new here, or the one held
    final put = {
      for (final k in kHistoryContactCols)
        if (row.containsKey(k) && cols.contains(k)) k: row[k],
    }..['halo_id'] = id;
    final had = await d.query(
      'contacts',
      columns: ['halo_id'],
      where: 'halo_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (had.isEmpty) {
      put['onion'] ??= '';
      put['xpub'] ??= '';
      put['first_seen'] ??= 0;
      put['last_seen'] ??= 0;
      await d.insert('contacts', put);
      final b = put['blocked'];
      if (b == 0 || b == 1) await _ownPhoneBlockPut(d, id, b as int);
    } else {
      // a block goes as a block here goes, and only when my phone's moved
      final b = put.remove('blocked');
      await d.update('contacts', put, where: 'halo_id = ?', whereArgs: [id]);
      await _ownPhoneBlock(id, b);
    }
    await _ownMarkPass((id: id, group: false));
    await refreshContacts();
    // the device state learns a contact new here
    final ds = _deviceState;
    if (had.isEmpty && put['ikey'] is String && ds != null) {
      try {
        await ds.call(d, 'add', {
          'ident': put['ident'] ?? kMainIdent,
          'identity': put['ikey'],
        });
      } on DevRefused catch (e) {
        dlog('own: a contact not held (${e.why})');
      }
    }
    return true;
  }

  // my phone's block of [id] on a linked device: taken only when it moved
  // since the phone last told it, so a block or unblock made here stays
  Future<void> _ownPhoneBlock(String id, Object? b) async {
    if (b != 0 && b != 1) return;
    final d = await live.open();
    final here = await live.isBlocked(id);
    final prev = await _ownPhoneBlockOf(d, id) ?? (here ? 1 : 0);
    await _ownPhoneBlockPut(d, id, b as int);
    if (b == prev || (b == 1) == here) return;
    if (b == 1) {
      await block(id);
    } else {
      await unblock(id);
    }
  }

  // a block or unblock made on a linked device: what my phone last told is
  // kept first, so its next contact op leaves this one as it is
  Future<void> _ownBlockHere(String id) async {
    if (!linkedDevicesOn || !linkedRole) return;
    try {
      final d = await live.open();
      if (await _ownPhoneBlockOf(d, id) != null) return;
      await _ownPhoneBlockPut(d, id, await live.isBlocked(id) ? 1 : 0);
    } catch (e) {
      dlog('own: a block here not noted (${e.runtimeType})');
    }
  }

  // a chat gone on another device of mine (deleted there, or hidden on my
  // phone): forgotten here, their devices' copies dropped as anyone's
  Future<bool> _ownGone(String id) async {
    final row = await live.getContact(id);
    if (row == null || (row['accepted'] as num?)?.toInt() != 1) return false;
    // a hidden chat on this phone is never touched from a device
    if (!linkedRole && _routeOf(id, null) != RouteTo.everyday) return false;
    // the shade lets go of them too (a hide on the phone clears its own)
    final tags = {?await live.notifTagOf(id)};
    await _devForget(id, sessions: true);
    await live.deleteConversation(id);
    // a linked device keeps no more of them than the phone's everyday side
    // keeps after a hide: a key-only row while a group names them
    if (linkedRole) await _ownDropPerson(id);
    await _io.unnotifyGone(id, tags);
    await _ownMarkPass((id: id, group: false));
    _bumpChatRev(id);
    await refreshContacts();
    notifyListeners();
    return true;
  }

  // a group as my phone holds it: its row, its members, their keys
  Future<bool> _ownGroup(String id, Map<String, dynamic> a) async {
    final r = a['r'];
    final m = a['m'];
    if (r is! Map || m is! List) return false;
    final d = await live.open();
    final gcols = {
      for (final c in await d.rawQuery("PRAGMA table_info('groups')"))
        c['name'] as String,
    };
    final put = {
      for (final k in kHistoryGroupCols)
        if (r.containsKey(k) && gcols.contains(k)) k: r[k],
    }..['group_id'] = id;
    put['name'] ??= '';
    put['created_at'] ??= 0;
    final had = await live.getGroup(id);
    if (had == null) {
      await d.insert('groups', put);
    } else {
      await d.update('groups', put, where: 'group_id = ?', whereArgs: [id]);
    }
    for (final p in (a['p'] as List? ?? const []).take(1024)) {
      if (p is! Map) continue;
      final h = p['h'], o = p['o'], x = p['x'];
      if (h is! String || o is! String || x is! String) continue;
      if (await live.getContact(h) != null) continue;
      await live.upsertContactStub(h, o, x);
    }
    // as my phone holds them, its own id among them: this device is that
    // member here too (_othersIn)
    await live.syncGroupMembers(id, [
      for (final x in m.take(1024))
        if (x is String && x.length <= 128) x,
    ]);
    await _ownMarkPass((id: id, group: true));
    await refreshGroups();
    return true;
  }

  Future<bool> _ownProfile(Map<String, dynamic> a) async {
    if (!linkedRole) return false;
    final h = a['h'];
    final d = await live.open();
    if (h is String && h.isNotEmpty && h.length <= 128) {
      _ownPhoneId = h;
      await d.insert('signal_meta', {
        'k': kOwnPhoneIdMeta,
        'v': h,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    // the avatar's set tells the home and the profile, my phone's name too
    final av = a['a'];
    if (av is int || av == null) await setMyAvatar(av as int?);
    final bg = a['bg'];
    if (bg is Map) await _ownBadgeTake(bg);
    await _ownMarkPass(null);
    return true;
  }

  // my phone's supporter badge as it wears and shares it. a linked device
  // carries the same on what it sends: a message from it without one
  // clears the badge at every contact (state_arrivals). only the tier and
  // the two choices come over, never a receipt
  Future<void> _ownBadgeTake(Map<dynamic, dynamic> bg) async {
    const c = HaloContainer.everyday;
    final t = bg['t'];
    await saveSupporterTier(tierOf(t is String ? t : null), c);
    final show = bg['s'], share = bg['c'];
    if (show is bool) await saveShowBadgeSelf(show, c);
    if (share is bool) await saveShareBadge(share, c);
  }

  // the badge as my profile op carries it to my devices
  Future<Map<String, Object?>> _ownBadge() async {
    const c = HaloContainer.everyday;
    return {
      't': tierKey(await loadSupporterTier(c)),
      's': await loadShowBadgeSelf(c),
      'c': await loadShareBadge(c),
    };
  }

  /// a device just linked: my profile goes to my devices now, the badge
  /// with it, whatever the passes told before (the first pass tells
  /// nothing, and a new device was never told)
  Future<void> _ownTellMe() async {
    final own = _ownSync;
    if (own == null || !_ownSends || linkedRole) return;
    try {
      final me = <String, Object?>{
        'h': myId,
        'a': _myAvatar,
        'bg': await _ownBadge(),
      };
      await own.op(kMainIdent, 'profile', null, me);
      await _ownKept('me', ownDigest(me));
    } catch (e) {
      dlog('own: my profile not sent (${e.runtimeType})');
    }
  }

  // ---- what moved, told ----

  /// the state of every chat my devices share, against what was told last:
  /// a row that moved goes as an op, one gone as its end. the first pass
  /// keeps what is there and tells nothing (the history copy carried it)
  Future<void> _ownPass() async {
    final own = _ownSync;
    if (own == null || !_ownSends || _ownPaused) return;
    final run = _ownPassing;
    if (run != null) {
      _ownPassAgain = true;
      return run;
    }
    final next = _ownPassOnce().whenComplete(() => _ownPassing = null);
    _ownPassing = next;
    await next;
    if (_ownPassAgain) {
      _ownPassAgain = false;
      await _ownPass();
    }
  }

  Future<void> _ownPassOnce() async {
    final own = _ownSync;
    if (own == null) return;
    try {
      final now = await _ownState();
      final d = await live.open();
      final told = {
        for (final r in await d.query('own_told'))
          r['chat'] as String: r['digest'] as String,
      };
      if (told.isEmpty) {
        await _ownKeep(now);
        return;
      }
      for (final e in now.entries) {
        if (told[e.key] == e.value.digest) continue;
        // a chat new on a linked device came from the phone or the copy
        if (linkedRole && !told.containsKey(e.key)) {
          await _ownKept(e.key, e.value.digest);
          continue;
        }
        final chat = ownChatOf(e.key);
        if (e.key == 'me') {
          await own.op(kMainIdent, 'profile', null, e.value.op);
        } else if (chat != null) {
          await own.op(
            _ownIdentOf(chat),
            chat.group ? 'group' : 'contact',
            chat,
            e.value.op,
          );
        }
        await _ownKept(e.key, e.value.digest);
      }
      for (final k in told.keys) {
        if (now.containsKey(k) || k == 'me') continue;
        final chat = ownChatOf(k);
        if (chat != null) {
          // only the phone ends a chat on my other devices; a linked
          // device's delete stays on it unless kOwnChatEndsBothWays
          if (!linkedRole || (!chat.group && kOwnChatEndsBothWays)) {
            // when it went, so a late copy of what it held stays out
            await own.op(
              _ownIdentOf(chat),
              chat.group ? 'ungroup' : 'gone',
              chat,
              {'t': _clockMs()},
            );
          }
        }
        await d.delete('own_told', where: 'chat = ?', whereArgs: [k]);
      }
    } catch (e) {
      dlog('own: a pass not run (${e.runtimeType})');
    }
  }

  // a hide is about to move [chats]: no pass runs until it is done, and
  // the ones my devices were told of are noted, with their identity, for
  // the gone that follows. the move drops what own sync kept of them
  Future<List<(OwnChat, int)>> _ownBeforeHide(List<ChatRef> chats) async {
    if (_ownSync == null || !_ownSends) return const [];
    _ownPaused = true;
    try {
      await _ownPassing;
      final d = await live.open();
      final told = {
        for (final r in await d.query('own_told', columns: ['chat']))
          r['chat'] as String,
      };
      return [
        for (final c in chats)
          if (told.contains(ownChatName((id: c.id, group: c.group))))
            (
              (id: c.id, group: c.group),
              c.group ? kMainIdent : identOfPeer(c.id),
            ),
      ];
    } catch (e) {
      _ownPaused = false;
      dlog('own: a hide not noted (${e.runtimeType})');
      return const [];
    }
  }

  // the hide is done: each chat of [told] that went leaves my devices now
  // (P1), and the passes run again
  Future<void> _ownAfterHide(
    List<(OwnChat, int)> told,
    Iterable<ChatRef> went,
  ) async {
    _ownPaused = false;
    final own = _ownSync;
    if (own == null || told.isEmpty) return;
    final gone = {
      for (final c in went) ownChatName((id: c.id, group: c.group)),
    };
    for (final (chat, ident) in told) {
      if (!gone.contains(ownChatName(chat))) continue;
      try {
        await own.op(ident, chat.group ? 'ungroup' : 'gone', chat, {
          't': _clockMs(),
        });
      } catch (e) {
        dlog('own: a gone not sent (${e.runtimeType})');
      }
    }
  }

  // a pass a little after the lists were read again: many reads, one pass
  void _ownPassSoon() {
    if (_ownSync == null || !_ownSends) return;
    _ownPassTimer ??= Timer(kOwnPassAfter, () {
      _ownPassTimer = null;
      unawaited(_ownPass());
    });
  }

  // every chat my devices share, as an op would carry it
  Future<Map<String, ({String digest, Map<String, Object?> op})>>
  _ownState() async {
    final d = await live.open();
    final out = <String, ({String digest, Map<String, Object?> op})>{};
    final ccols = {
      for (final c in await d.rawQuery("PRAGMA table_info('contacts')"))
        c['name'] as String,
    };
    final cols = linkedRole
        ? [
            for (final c in kOwnContactSet)
              if (ccols.contains(c)) c,
          ]
        : [
            for (final c in kHistoryContactCols)
              if (ccols.contains(c) && !_kOwnNotTold.contains(c)) c,
          ];
    for (final r in await d.query(
      'contacts',
      columns: {'halo_id', ...cols}.toList(),
      where: 'accepted = 1',
    )) {
      final id = r['halo_id'] as String;
      final chat = (id: id, group: false);
      if (!await _ownChatKnown(chat)) continue;
      final row = {
        for (final c in cols)
          c: r[c] is List<int> ? base64Encode(r[c] as List<int>) : r[c],
      };
      out[ownChatName(chat)] = (digest: ownDigest(row), op: {'r': row});
    }
    if (!linkedRole) {
      final gcols = {
        for (final c in await d.rawQuery("PRAGMA table_info('groups')"))
          c['name'] as String,
      };
      final cols = [
        for (final c in kHistoryGroupCols)
          if (gcols.contains(c)) c,
      ];
      for (final g in await d.query('groups', columns: cols)) {
        final id = g['group_id'] as String;
        final chat = (id: id, group: true);
        if (!await _ownChatKnown(chat)) continue;
        final members = await live.getGroupMembers(id);
        final people = <Map<String, Object?>>[];
        for (final m in members) {
          if (m == myId) continue;
          final c = await live.getContact(m);
          if (c == null) continue;
          people.add({'h': m, 'o': c['onion'] ?? '', 'x': c['xpub'] ?? ''});
        }
        final row = {
          for (final c in cols)
            c: g[c] is List<int> ? base64Encode(g[c] as List<int>) : g[c],
        };
        final op = <String, Object?>{'r': row, 'm': members, 'p': people};
        out[ownChatName(chat)] = (digest: ownDigest(op), op: op);
      }
      final me = <String, Object?>{
        'h': myId,
        'a': _myAvatar,
        'bg': await _ownBadge(),
      };
      out['me'] = (digest: ownDigest(me), op: me);
    }
    return out;
  }

  Future<void> _ownKeep(
    Map<String, ({String digest, Map<String, Object?> op})> now,
  ) async {
    final d = await live.open();
    await d.transaction((t) async {
      for (final e in now.entries) {
        await t.insert('own_told', {
          'chat': e.key,
          'digest': e.value.digest,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // an empty side still counts as one kept
      await t.insert('own_told', {
        'chat': '-',
        'digest': '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> _ownKept(String chat, String digest) async {
    final d = await live.open();
    await d.insert('own_told', {
      'chat': chat,
      'digest': digest,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // an op taken here: what it moved is what is told from here, so it does
  // not go back. on the phone a device's op is told on to the others
  Future<void> _ownMarkPass(OwnChat? chat) async {
    if (!linkedRole) {
      unawaited(_ownPass());
      return;
    }
    final now = await _ownState();
    final k = chat == null ? 'me' : ownChatName(chat);
    final v = now[k];
    final d = await live.open();
    if (v == null) {
      await d.delete('own_told', where: 'chat = ?', whereArgs: [k]);
    } else {
      await _ownKept(k, v.digest);
    }
  }

  // ---- what went here ----

  Future<void> _ownGoneUid(OwnChat chat, String uid) async =>
      ownGoneNote(await live.open(), ownChatName(chat), [uid], now: _clockMs());

  // everything of [chat] written up to now, or ownGoneMadeAt's time
  Future<void> _ownGoneAllOf(OwnChat chat) async =>
      _ownGoneUpTo(await live.open(), live.container, chat);

  // a delete or a clear of a chat this linked device does not hold yet:
  // kept, so its copies stay out once the chat comes. never on the phone,
  // where a chat it does not share may be hidden
  bool _ownGoneKept(OwnChat chat, bool known) =>
      linkedRole && !known && !isOwnNotes(chat);

  // when another device of mine says it made a chat's end: no later than
  // now here
  int _ownMadeAt(Map<String, dynamic> a) {
    final t = a['t'];
    final now = _clockMs();
    return t is int && t > 0 && t < now ? t : now;
  }

  // a person a gone chat names no more here: their row and what went of
  // theirs, a key-only row kept while a group names them (vault_life _drop)
  Future<void> _ownDropPerson(String id) async {
    final d = await live.open();
    await d.transaction((t) async {
      final row = await t.query(
        'contacts',
        columns: [
          'onion',
          'xpub',
          'first_seen',
          'back_paired',
          'blocked',
          'ident',
          'ikey',
        ],
        where: 'halo_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      await t.delete('gone_in', where: 'peer_id = ?', whereArgs: [id]);
      await t.delete(
        'signal_meta',
        where: 'k = ?',
        whereArgs: ['$kOwnPhoneBlockMeta$id'],
      );
      // the order of my phone's ops on the chat goes with it
      await t.delete(
        'frame_order',
        where: 'msg_uid = ?',
        whereArgs: ['os:${ownChatName((id: id, group: false))}'],
      );
      await t.delete('contacts', where: 'halo_id = ?', whereArgs: [id]);
      final named = await t.rawQuery(
        'SELECT 1 FROM group_members WHERE halo_id = ?1 UNION ALL '
        'SELECT 1 FROM messages WHERE peer_id = ?1 AND group_id IS NOT NULL '
        "AND group_id != '' LIMIT 1",
        [id],
      );
      if (row.isEmpty || named.isEmpty) return;
      final r = row.first;
      await t.insert('contacts', {
        'halo_id': id,
        'onion': r['onion'] ?? '',
        'xpub': r['xpub'] ?? '',
        'first_seen': r['first_seen'] ?? 0,
        'last_seen': r['first_seen'] ?? 0,
        'back_paired': r['back_paired'] ?? 0,
        'blocked': r['blocked'] ?? 0,
        'accepted': 0,
        'ident': r['ident'] ?? kMainIdent,
        'ikey': r['ikey'],
      });
    });
  }

  // whether what [frame] carries or speaks of in [chat] went here, and
  // when my other device burns it. [written]: when it was written (a copy
  // of mine) or my phone took it (a contact's frame passed on)
  Future<({bool gone, int? burnAt})> _ownGoneOf(
    OwnChat chat,
    String frame, {
    int? written,
  }) async => ownGoneOf(
    await live.open(),
    ownChatName(chat),
    frameMessageUids(frame),
    written: written,
    now: _clockMs(),
  );
}

// what moves with every message, never told as a change
const _kOwnNotTold = {'first_seen', 'last_seen', 'back_paired', 'caps_at'};

// the sender a linked device's own slices are kept under
const _kOwnChunks = 'own:';

Future<void>? _ownPassing;
bool _ownPassAgain = false;
bool _ownHeldGoing = false;
// no pass while a hide moves chats: it would tell what the hide drops
bool _ownPaused = false;

/// the most frames kept to pass on while the decoy is open
const kOwnHeldMost = 2048;
Timer? _ownPassTimer;

/// how long after the lists moved the chats' state is told
const kOwnPassAfter = Duration(seconds: 3);
