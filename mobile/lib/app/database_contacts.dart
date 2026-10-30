// SPDX-License-Identifier: GPL-3.0-or-later
// the people here: contacts, their keys, vouches and requests

part of '../main.dart';

mixin _ContactRows {
  // what these rows take from the rest of HaloDb
  HaloContainer get container;
  Future<Database> open();
  Future<void> _scrubMedia(List<Map<String, Object?>> rows);
  Future<void> _dropPhotos(Iterable<Object?> atmospheres);
  Future<void> _dropFilesComingFrom(DatabaseExecutor t, String peerId);

  Future<Map<String, String>?> loadIdentity() async {
    final db = await open();
    final rows = await db.query('identity', limit: 1);
    if (rows.isEmpty) return null;
    return {
      'id': rows.first['id'] as String,
      'ed_priv': rows.first['ed_priv'] as String,
      'x_priv': rows.first['x_priv'] as String,
    };
  }

  // the main identity's row goes with it, in one write: its key, and the
  // registration id the store has given out so far
  Future<void> saveIdentity(String id, String edPriv, String xPriv) async {
    final db = await open();
    await db.transaction((t) async {
      await t.delete('identity');
      await t.insert('identity', {
        'id': id,
        'ed_priv': edPriv,
        'x_priv': xPriv,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      final reg = await t.query(
        'signal_meta',
        columns: ['v'],
        where: 'k = ?',
        whereArgs: ['regId'],
        limit: 1,
      );
      final had = await identityRow(t, kMainIdent);
      await putMainIdentity(
        t,
        _hexBytes(xPriv),
        regId: reg.isEmpty
            ? had?.regId
            : int.tryParse(reg.first['v'] as String) ?? had?.regId,
      );
    });
  }

  static Uint8List _hexBytes(String h) => Uint8List.fromList([
    for (var i = 0; i + 1 < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ]);

  Future<void> setNote(String haloId, String note) async {
    final db = await open();
    await db.update(
      'contacts',
      {'note': note},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setContactPinned(String haloId, bool pinned) async {
    final db = await open();
    await db.update(
      'contacts',
      {'pinned': pinned ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setPeerBundle(String haloId, String bundleB64) async {
    // the dev chat's bundle is the pinned one, and his is no one else's
    if (isDevId(haloId) || devKeyByBundle(bundleB64) != null) return;
    final db = await open();
    await db.update(
      'contacts',
      {'peer_bundle': bundleB64},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<Map<String, Object?>?> getContact(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    return rows.isEmpty ? null : (await _verifiedNow(db, rows)).first;
  }

  Future<List<Map<String, Object?>>> _verifiedNow(
    DatabaseExecutor db,
    List<Map<String, Object?>> rows, {
    String idColumn = 'halo_id',
  }) => verifiedNow(db, rows, idColumn: idColumn, identity: _keySource);

  // where a key held for someone is read when this database keeps no signal
  // tables of its own (keySourceFor)
  Future<String?> Function(String haloId)? get _keySource =>
      keySourceFor(container);

  // a contact stub from group invite info. a peer we already know is left
  // as is.
  Future<void> upsertContactStub(
    String haloId,
    String onion,
    String xpub,
  ) async {
    // only the dev chat's own code writes its row, and no one else gets
    // the developer's words or key
    if (devCardClaim(id: haloId, xPub: xpub)) return;
    final db = await open();
    final existing = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('contacts', {
      'halo_id': haloId,
      'onion': onion,
      'xpub': xpub,
      'first_seen': now,
      'last_seen': now,
      'back_paired': 0,
      // being in a group with someone is not knowing them. the key is kept
      // so their messages decrypt; the row stays out of the contact list
      // until you add them yourself.
      'accepted': 0,
      // and the name is whatever the card said
      'name_check': kNameAsk | kNameSays,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await claimContactKeys(db, only: haloId);
  }

  Future<bool> keyChanged(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['key_changed'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['key_changed'] as int? ?? 0) == 1;
  }

  // flag that a known peer's identity key changed (reinstall or mitm).
  // the chat surfaces this so the user verifies before trusting.
  Future<void> setKeyChanged(String haloId, bool changed) async {
    // the dev chat never warns: a key that is not the pinned one is dropped
    if (isDevId(haloId)) return;
    final db = await open();
    await _inLane(
      haloId,
      () => db.update(
        'contacts',
        {'key_changed': changed ? 1 : 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      ),
    );
  }

  Future<void> clearKeyChanged(String haloId) async {
    final db = await open();
    await _inLane(
      haloId,
      () => db.update(
        'contacts',
        {'key_changed': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      ),
    );
  }

  // in their signal lane: an open that fails puts back only what was there
  // before it, never a write made since
  static Future<T> _inLane<T>(String haloId, Future<T> Function() work) =>
      isDevId(haloId) ? work() : signalSession.serial(haloId, work);

  Future<String?> contactXPub(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['xpub'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['xpub'] as String?;
  }

  Future<void> setContactBadge(String haloId, String? tier) async {
    final d = await open();
    await d.update(
      'contacts',
      {'supporter_badge': tier},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // who vouched for whom. a row only ever lands when the voucher is a
  // contact we accepted, which is what makes the count mean anything.
  Future<void> addVouch(
    String haloId,
    String voucherId,
    String? note, {
    int? at,
  }) async {
    final db = await open();
    final v = await db.query(
      'contacts',
      columns: ['accepted'],
      where: 'halo_id = ?',
      whereArgs: [voucherId],
      limit: 1,
    );
    if (v.isEmpty || (v.first['accepted'] as int? ?? 0) != 1) {
      dlog('vouch: $voucherId is not an accepted contact, dropped');
      return;
    }
    final n = (note ?? '').trim();
    await db.insert('vouches', {
      'halo_id': haloId,
      'voucher_id': voucherId,
      'note': n.isEmpty ? null : (n.length > 40 ? n.substring(0, 40) : n),
      'created_at': at ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // every vouch for one person, joined to what we know about the voucher.
  // only vouchers we still hold as accepted contacts count: a deleted or
  // blocked one drops out here rather than lingering as a name.
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async {
    final db = await open();
    return _verifiedNow(
      db,
      await db.rawQuery(
        '''
      SELECT v.voucher_id, v.note, v.created_at,
             c.nickname, c.avatar, c.verified, c.verified_key, c.xpub
      FROM vouches v JOIN contacts c ON c.halo_id = v.voucher_id
      WHERE v.halo_id = ? AND c.accepted = 1 AND c.blocked = 0
      ORDER BY v.created_at ASC
      ''',
        [haloId],
      ),
      idColumn: 'voucher_id',
    );
  }

  Future<bool> isVouched(String haloId) async {
    final db = await open();
    final r = await db.rawQuery(
      '''
      SELECT 1 FROM vouches v JOIN contacts c ON c.halo_id = v.voucher_id
      WHERE v.halo_id = ? AND c.accepted = 1 AND c.blocked = 0 LIMIT 1
      ''',
      [haloId],
    );
    return r.isNotEmpty;
  }

  // introduced people we have not accepted yet. they need a relay
  // subscription like a real contact or their first message never lands.
  Future<List<Map<String, Object?>>> vouchedPending() async {
    final db = await open();
    return db.rawQuery('''
      SELECT DISTINCT c.* FROM contacts c
      JOIN vouches v ON v.halo_id = c.halo_id
      WHERE c.accepted = 0 AND c.blocked = 0
    ''');
  }

  // headline and lines are stored as shield codes (ShieldHit.toJson), and
  // worded when shown. a flag or a dismissal stays; only a clean check an
  // older build stored gives way
  Future<void> setShield(
    String haloId,
    String headline,
    List<Map<String, String>> lines,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      final had = await t.query(
        'shield',
        where: 'halo_id = ?',
        whereArgs: [haloId],
        limit: 1,
      );
      if (had.isNotEmpty && !shieldRowOpen(had.first)) return;
      await t.insert('shield', {
        'halo_id': haloId,
        'headline': headline,
        'lines': jsonEncode(lines),
        'dismissed': 0,
        'at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Map<String, Object?>?> shieldFor(String haloId) async {
    final db = await open();
    final r = await db.query(
      'shield',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  // ignore = for good. the row stays so the check never re-runs on them.
  Future<void> dismissShield(String haloId) async {
    final db = await open();
    await db.update(
      'shield',
      {'dismissed': 1},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<int?> powNonceOf(String msgUid) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['pow_nonce'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['pow_nonce'] as num?)?.toInt();
  }

  Future<void> setPowNonce(String msgUid, int nonce) async {
    final db = await open();
    await db.update(
      'messages',
      {'pow_nonce': nonce},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> setContactAvatar(String haloId, int? av) async {
    final db = await open();
    await db.update(
      'contacts',
      {'avatar': av},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setContactXPub(String haloId, String xpub) async {
    // the dev chat's row keeps the key it was made with, and no one else
    // gets his
    if (devCardClaim(id: haloId, xPub: xpub)) return;
    final db = await open();
    await db.update(
      'contacts',
      {'xpub': xpub},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
    await claimContactKeys(db, only: haloId);
  }

  Future<List<Map<String, Object?>>> contacts() async {
    final db = await open();
    return _verifiedNow(
      db,
      await db.query(
        'contacts',
        where: 'accepted = 1',
        orderBy: 'last_seen DESC',
      ),
    );
  }

  // every person held, true for a contact and false for a key only, and
  // every group: what a session reads to know whose a chat is
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async {
    final db = await open();
    final people = await db.query('contacts', columns: ['halo_id', 'accepted']);
    final groups = await db.query('groups', columns: ['group_id']);
    return (
      people: {
        for (final r in people)
          r['halo_id'] as String: (r['accepted'] as int? ?? 0) == 1,
      },
      groups: {for (final r in groups) r['group_id'] as String},
    );
  }

  // the developer chat's row: its flags, its start and its delete
  DevChat get devChat => DevChat(open, shred: shredFile);

  // the developer's own phone: the chats people start from the Marios row
  SupportChats get support => SupportChats(open);

  // a 1:1 chat with a message that came through the developer chat
  Future<bool> hasViaDev(String haloId) async {
    try {
      final d = await open();
      final r = await d.query(
        'messages',
        columns: ['id'],
        where: 'peer_id = ? AND group_id IS NULL AND via_dev = ?',
        whereArgs: [haloId, 1],
        limit: 1,
      );
      return r.isNotEmpty;
    } catch (e) {
      dlog('via dev: ${e.runtimeType}');
      return false;
    }
  }

  Future<void> deleteConversation(String haloId) async {
    final d = await open();
    String? atmo;
    final files = await d.transaction((t) async {
      atmo = await _atmosphereOf(t, haloId);
      final rows = await t.query(
        'messages',
        columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
        where: _kOneToOne,
        whereArgs: [haloId],
      );
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      await _noteGone(t, rows);
      await t.delete('messages', where: _kOneToOne, whereArgs: [haloId]);
      await _dropFilesComingFrom(t, haloId);
      // the row stays: it carries the xpub our nostr subscription is built
      // from. archived + unaccepted = invisible everywhere until they write.
      // what was set for the chat goes with it, so they come back as a new
      // person. the block, the verified mark on its key and the vouches for
      // them stay
      await t.update(
        'contacts',
        {
          'accepted': 0,
          'archived': 1,
          'unread': 0,
          'nickname': null,
          'note': null,
          'atmosphere': null,
          'voice_disguise': null,
          'muted': 0,
          'pinned': 0,
          'ack_owed': 0,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      // a first message after this is checked afresh, and rings under a
      // new tag the shade never ties to the old chat
      await t.delete('shield', where: 'halo_id = ?', whereArgs: [haloId]);
      await t.delete('notif_tags', where: 'chat = ?', whereArgs: [haloId]);
      await t.delete('notif_rings', where: 'chat = ?', whereArgs: [haloId]);
      // nothing queued for the old chat goes after it. a take-back still
      // goes, it only withdraws
      await _dropQueuedTo(t, haloId);
      if (rows.isNotEmpty) await oweTidy(t);
      return rows;
    });
    await _scrubMedia(files);
    await _dropPhotos([atmo]);
  }

  // a request that never became one: its row, its shield line and what
  // of theirs waited to be tried again
  Future<void> forgetRequest(String haloId) async {
    final db = await open();
    final gone = await db.transaction((t) async {
      final gone = await t.query(
        'contacts',
        columns: ['atmosphere'],
        where: 'halo_id = ? AND accepted = ?',
        whereArgs: [haloId, 0],
      );
      await t.delete(
        'contacts',
        where: 'halo_id = ? AND accepted = ?',
        whereArgs: [haloId, 0],
      );
      await t.delete('shield', where: 'halo_id = ?', whereArgs: [haloId]);
      await t.delete('first_kept', where: 'peer = ?', whereArgs: [haloId]);
      await t.delete('notif_tags', where: 'chat = ?', whereArgs: [haloId]);
      return gone;
    });
    await _dropPhotos([for (final r in gone) r['atmosphere']]);
  }

  // they wrote after we deleted them: bring the row back as a request.
  Future<void> unparkIfArchived(String haloId) async {
    final d = await open();
    final r = await d.query(
      'contacts',
      columns: ['archived', 'accepted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (r.isEmpty) return;
    final arch = (r.first['archived'] as int?) ?? 0;
    final acc = (r.first['accepted'] as int?) ?? 0;
    if (arch == 1 && acc == 0) {
      await d.update(
        'contacts',
        {'archived': 0},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    }
  }

  Future<void> setArchived(String haloId, bool archived) async {
    final db = await open();
    await db.update(
      'contacts',
      {'archived': archived ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setMuted(String haloId, bool muted) async {
    final db = await open();
    await db.update(
      'contacts',
      {'muted': muted ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isMuted(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['muted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['muted'] as int? ?? 0) == 1;
  }

  // in their signal lane: an open that saves a new key for them lands
  // wholly before the mark or after it
  Future<bool> setVerified(String haloId, bool verified, {String? key}) async {
    final db = await open();
    return _inLane(
      haloId,
      () => markVerified(db, haloId, verified, key: key, identity: _keySource),
    );
  }

  Future<bool> isVerified(String haloId) async {
    final c = await getContact(haloId);
    return (c?['verified'] as int? ?? 0) == 1;
  }

  // a name let go (AppState.releaseName): the key the row held and what
  // came with it go. what is left is a name nobody checked
  Future<void> forgetName(String haloId) async {
    final db = await open();
    final atmo = await db.transaction((t) async {
      final atmo = await _atmosphereOf(t, haloId);
      await t.update(
        'contacts',
        {
          'xpub': '',
          'peer_bundle': null,
          'key_changed': 0,
          'verified': 0,
          'verified_key': null,
          'back_paired': 0,
          'avatar': null,
          'supporter_badge': null,
          'vouched_by': null,
          'vouched_at': null,
          'nickname': null,
          'note': null,
          'atmosphere': null,
          'pinned': 0,
          'muted': 0,
          'voice_disguise': null,
          'name_check': kNameAsk | kNameSays,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      // vouches for them, and the ones they gave
      await t.delete('vouches', where: 'halo_id = ?', whereArgs: [haloId]);
      await t.delete('vouches', where: 'voucher_id = ?', whereArgs: [haloId]);
      await t.delete('shield', where: 'halo_id = ?', whereArgs: [haloId]);
      // the key it held is free for whoever holds it next
      await claimContactKeys(t, only: haloId);
      return atmo;
    });
    await _dropPhotos([atmo]);
  }

  // a member of a group or a room here
  Future<bool> inAnyGroup(String haloId) async {
    final db = await open();
    for (final (t, c, w) in const [
      // an ended group's members are kept for its end alone
      ('group_members', 'halo_id', _kRunningGroup),
      ('room_keys', 'member', ''),
    ]) {
      final r = await db.query(
        t,
        columns: [c],
        where: '$c = ?$w',
        whereArgs: [haloId],
        limit: 1,
      );
      if (r.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> setNameCheck(String haloId, int flags) async {
    final db = await open();
    await db.update(
      'contacts',
      {'name_check': flags},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // no key when it could not be read: no number shows
  Future<String?> heldKey(String haloId) async {
    final k = await heldKeyHex(await open(), haloId, identity: _keySource);
    return k == kKeyUnread ? null : k;
  }

  Future<bool> keyHeld(String haloId) async =>
      keyHeldIn(await open(), haloId, identity: _keySource);

  /// the heal line that holds [haloId] (kHealLineRestored or Repair), null
  /// when no heal holds them, or when their key moved too: the key's card
  /// says what is true then, and its ways out come first
  Future<int?> healHold(String haloId) async {
    if (!kHealHold) return null;
    final db = await open();
    if (await keyHeldIn(db, haloId, identity: _keySource, heal: false)) {
      return null;
    }
    return healHoldOf(db, haloId);
  }

  /// the person looked: [haloId] goes on, verified as before
  Future<void> releaseHealHold(String haloId) async =>
      dropHealHold(await open(), haloId);

  /// where heals rebuilt [haloId]'s session, oldest first
  Future<List<({int at, int kind})>> healLines(String haloId) async =>
      healLinesOf(await open(), haloId);

  Future<void> acceptNewKey(String haloId) async {
    final db = await open();
    await _inLane(haloId, () => acceptNewKeyIn(db, haloId));
  }

  // true only when we've accepted this sender. unknown senders read false.
  Future<bool> isAccepted(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['accepted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['accepted'] as int? ?? 0) == 1;
  }

  // how many messages we already hold from a sender in their own chat:
  // caps strangers. [inGroups] counts what they wrote in groups as well
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async {
    final db = await open();
    final r = await db.rawQuery(
      inGroups
          ? 'SELECT COUNT(*) c FROM messages WHERE peer_id = ? AND direction = ?'
          : 'SELECT COUNT(*) c FROM messages WHERE $_kOneToOne AND direction = ?',
      [peerId, 'in'],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // how many messages we've sent a peer: caps our own request messages
  Future<int> countMessagesTo(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM messages WHERE $_kOneToOne AND direction = ?',
      [peerId, 'out'],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> setNickname(String haloId, String? name) async {
    final db = await open();
    final v = (name == null || name.trim().isEmpty) ? null : name.trim();
    await db.update(
      'contacts',
      {'nickname': v},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // unknown senders waiting for accept/block. blocked ones stay hidden.
  // the receive side tries and listens for all of these, a group member
  // known only by key included
  Future<List<Map<String, Object?>>> pendingRequests() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 0',
      orderBy: 'last_seen DESC',
    );
  }

  // of those, the ones who asked: what the requests inbox shows
  Future<List<Map<String, Object?>>> askedRequests() async {
    final db = await open();
    return db.query('contacts', where: kRequestRows, orderBy: 'last_seen DESC');
  }

  // declined and parked: out of the inbox, but a second message still has
  // to reach us so the row can resurface
  Future<List<Map<String, Object?>>> parkedRequests() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 1',
    );
  }

  // the requests inbox: support chats wait in their own, though the
  // receive side still tries them as requests
  Future<List<Map<String, Object?>>> requestsInbox() async {
    final rows = await askedRequests();
    if (rows.isEmpty) return rows;
    return withoutSupport(rows, await support.ids());
  }

  Future<int> pendingRequestCount() async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM contacts WHERE $kRequestRows',
    );
    final n = (r.first['c'] as int?) ?? 0;
    if (n == 0 || (await support.ids()).isEmpty) return n;
    return (await requestsInbox()).length;
  }

  /// [onion] for a contact accepted here who has none yet; a held one
  /// stays
  Future<void> fillOnion(String haloId, String onion) async {
    final db = await open();
    // contacts.onion is NOT NULL: none is ''
    await db.update(
      'contacts',
      {'onion': onion},
      where: "halo_id = ? AND accepted = 1 AND onion = ''",
      whereArgs: [haloId],
    );
  }

  /// a hello owed to the identity [ownerHex] (0x05 and its x key),
  /// answering its invite [answersHex] (all zero: a v3 link) at the
  /// first-contact key [fc]: kept until it went
  Future<void> oweHello(String ownerHex, String answersHex, String fc) async {
    final db = await open();
    await db.insert('hellos', {
      'ident': kMainIdent,
      'way': kHelloWant,
      'peer': ownerHex,
      'invite_id': answersHex,
      'fc': fc,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // someone who asked, or asked and was let go: adding them by their card
  // is the accept they were waiting for
  Future<bool> askedBefore(String haloId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM contacts WHERE halo_id = ? AND ($kAskedRows)',
      [haloId],
    );
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  // the accept and the word it owes them in one write: a death before the
  // word goes leaves it owed
  Future<void> acceptRequest(String haloId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'accepted': 1, 'ack_owed': 1},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // quietly dismiss a request: drop the stranger's row and pending messages.
  // not a block: they can reach us again later.
  Future<void> declineRequest(String haloId) async {
    final d = await open();
    String? atmo;
    final files = await d.transaction((t) async {
      atmo = await _atmosphereOf(t, haloId);
      final rows = await t.query(
        'messages',
        columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
        where: _kOneToOne,
        whereArgs: [haloId],
      );
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      // turned away, they stay away: a resend or the relays bring none
      // back, the ones the cap held either
      final held = await t.query(
        'held_onion',
        columns: ['cipher', 'at'],
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      await _noteGone(t, [
        ...rows,
        for (final h in held)
          if (heldWireOf(h['cipher'] as String) case final w?)
            if (unwrapMessage(w).msgUid case final uid?)
              {
                'msg_uid': uid,
                'peer_id': haloId,
                'direction': 'in',
                'sent_at': h['at'],
              },
      ]);
      await t.delete('messages', where: _kOneToOne, whereArgs: [haloId]);
      await t.delete('held_onion', where: 'peer_id = ?', whereArgs: [haloId]);
      await t.delete('first_kept', where: 'peer = ?', whereArgs: [haloId]);
      await _dropFilesComingFrom(t, haloId);
      // park, don't delete: the row carries the xpub the relay subscription
      // is built from. if they write again, unparkIfArchived surfaces them as
      // a new request. a wallpaper set for the request goes with it
      await t.update(
        'contacts',
        {
          'accepted': 0,
          'archived': 1,
          'unread': 0,
          'ack_owed': 0,
          'atmosphere': null,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      return rows;
    });
    await _scrubMedia(files);
    await _dropPhotos([atmo]);
  }

  // [owe]: an add that takes in someone who asked, which owes them word
  // that they are in, kept in the same write
  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
    bool owe = false,
  }) async {
    // only the dev chat's own code writes its row, and no one else gets
    // the developer's words or key
    if (devCardClaim(id: haloId, xPub: xpub)) return;
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('contacts', {
        'halo_id': haloId,
        'onion': onion,
        'xpub': xpub,
        'first_seen': now,
        'last_seen': now,
        'accepted': accepted,
        // someone who wrote first gave their name themselves
        if (accepted == 0) 'name_check': kNameAsk | kNameSays,
        if (owe && accepted == 1) 'ack_owed': 1,
      });
    } else {
      // xpub changed on someone we already know = they reinstalled, or its a
      // mitm. dont just swap the key silently, flag it so the chat warns
      final priorX = existing.first['xpub'] as String?;
      final changed =
          priorX != null &&
          priorX.isNotEmpty &&
          xpub.isNotEmpty &&
          priorX != xpub;
      // someone blocked stays as the block left them. a new key is still
      // flagged, so their chat warns once the block ends
      if ((existing.first['blocked'] as int? ?? 0) == 1) {
        if (changed) {
          await db.update(
            'contacts',
            {'key_changed': 1, 'verified': 0},
            where: 'halo_id = ?',
            whereArgs: [haloId],
          );
        }
        return;
      }
      // only ever raise accepted (0->1 on an explicit re-pair), never lower
      // it: a back-pair passing accepted:0 must not demote a real contact.
      final priorAccepted = (existing.first['accepted'] as int?) ?? 0;
      final nextAccepted = accepted == 1 ? 1 : priorAccepted;
      // parked = deleted (archived and unaccepted). a real archived chat is
      // still accepted, so this can't un-archive one the user archived on
      // purpose. any touch on a parked row brings it back as a request.
      final wasParked =
          ((existing.first['archived'] as int?) ?? 0) == 1 &&
          priorAccepted == 0;
      await db.update(
        'contacts',
        {
          'onion': onion,
          // v2 links pass '' here: never wipe a key we already learned
          if (xpub.isNotEmpty) 'xpub': xpub,
          'last_seen': now,
          'accepted': nextAccepted,
          if (owe && nextAccepted == 1) 'ack_owed': 1,
          if (wasParked) 'archived': 0,
          if (changed) 'key_changed': 1,
          if (changed) 'verified': 0,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    }
    // one contact per identity key (identities.dart)
    await claimContactKeys(db, only: haloId);
  }

  Future<void> markBackPaired(String peerId) async {
    final d = await open();
    await d.update(
      'contacts',
      {'back_paired': 1},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  Future<bool> isBackPaired(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['back_paired'],
      where: 'halo_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['back_paired'] as int? ?? 0) == 1;
  }

  // an accept's word to them, kept on their row until a send of it is
  // taken: a dead route or a restart must not leave them locked out
  // set only on someone accepted and not blocked: a block that lands
  // between an accept and this write keeps its row clear
  Future<void> setAckOwed(String haloId, bool owed) async {
    final d = await open();
    await d.update(
      'contacts',
      {'ack_owed': owed ? 1 : 0},
      where: owed
          ? 'halo_id = ? AND accepted = 1 AND blocked = 0'
          : 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isAckOwed(String haloId) async {
    final d = await open();
    final rows = await d.query(
      'contacts',
      columns: ['ack_owed'],
      where: 'halo_id = ? AND accepted = 1 AND blocked = 0',
      whereArgs: [haloId],
      limit: 1,
    );
    return rows.isNotEmpty && (rows.first['ack_owed'] as int? ?? 0) == 1;
  }

  // the ack went untried for good: 2 on the row, and a line in their chat
  // says they may not know until a word goes either way or it is tried
  // again
  Future<void> loseAck(String haloId) async {
    final d = await open();
    await d.update(
      'contacts',
      {'ack_owed': 2},
      where: 'halo_id = ? AND ack_owed = 1',
      whereArgs: [haloId],
    );
  }

  Future<bool> ackLost(String haloId) async {
    final d = await open();
    final rows = await d.query(
      'contacts',
      columns: ['halo_id'],
      where: 'halo_id = ? AND ack_owed = 2 AND accepted = 1 AND blocked = 0',
      whereArgs: [haloId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // owed again, from the line's button. true when it was lost here
  Future<bool> retryAck(String haloId) async {
    final d = await open();
    final n = await d.update(
      'contacts',
      {'ack_owed': 1},
      where: 'halo_id = ? AND ack_owed = 2 AND accepted = 1 AND blocked = 0',
      whereArgs: [haloId],
    );
    return n > 0;
  }

  // everyone here still owed it, and not blocked since
  Future<List<String>> ackOwed() async {
    final d = await open();
    final rows = await d.query(
      'contacts',
      columns: ['halo_id'],
      where: 'ack_owed = 1 AND accepted = 1 AND blocked = 0',
    );
    return [for (final r in rows) r['halo_id'] as String];
  }
}

// a chat's atmosphere as its row has it
Future<String?> _atmosphereOf(DatabaseExecutor t, String haloId) async {
  final r = await t.query(
    'contacts',
    columns: ['atmosphere'],
    where: 'halo_id = ?',
    whereArgs: [haloId],
    limit: 1,
  );
  return r.isEmpty ? null : r.first['atmosphere'] as String?;
}

// the key someone is known by here, as lowercase hex: the one their sessions
// are built on (asked of [identity], the identity's own signal store, else
// read from this database's), else the one their card brought, else the one
// inside their bundle. the dev chat's is pinned on its row. null when there
// is none. a hidden chat's database keeps no signal tables: [identity] is
// what reads its key
Future<String?> heldKeyHex(
  DatabaseExecutor db,
  String haloId, {
  String? xpub,
  Future<String?> Function(String haloId)? identity,
}) async {
  if (!isDevId(haloId)) {
    final asked = await identity?.call(haloId);
    if (asked != null && asked.isNotEmpty) return asked.toLowerCase();
    final own = await peerIdentityHex(db, haloId);
    if (own != null) return own;
  }
  final rows = await db.query(
    'contacts',
    columns: ['xpub', 'peer_bundle'],
    where: 'halo_id = ?',
    whereArgs: [haloId],
    limit: 1,
  );
  final x = (xpub ?? (rows.isEmpty ? null : rows.first['xpub'] as String?))
      ?.trim()
      .toLowerCase();
  if (x != null && x.isNotEmpty) return x;
  final bundle = rows.isEmpty ? null : rows.first['peer_bundle'] as String?;
  if (isDevId(haloId) || bundle == null || bundle.isEmpty) return null;
  final b = _bundleIdentity(bundle);
  return b == null ? null : _keyHex(b);
}

// a signal identity key as hex, without its one-byte type
String _keyHex(List<int> b) {
  final pub = b.length == 33 ? b.sublist(1) : b;
  return pub.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

// the hidden chats' database keeps no signal tables: the keys of their people
// sit in the everyday database's, read straight from its file, with no wait
// on the signal store. the decoy and its hidden chats never read the everyday
// identity's keys: the decoy goes nowhere, and their cards are all it knows.
// the everyday and the decoy database read their own tables
Future<String?> Function(String haloId)? keySourceFor(HaloContainer c) =>
    identical(c, HaloContainer.vault) ? _everydayKeyOf : null;

// what a key reads as when the everyday database cannot be read, a restore
// putting another file in its place say. it is no key, so it matches no mark
const kKeyUnread = 'unread';

Future<String?> _everydayKeyOf(String haloId) async {
  try {
    final rows = await (await live.open()).query(
      'peer_identities',
      columns: ['identity_key'],
      where: 'address = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _keyHex(rows.first['identity_key'] as List<int>);
  } catch (e) {
    dlog('held key: everyday not read (${e.runtimeType})');
    return kKeyUnread;
  }
}

// the key a database's signal tables hold for someone, null when none
Future<String?> peerIdentityHex(DatabaseExecutor db, String haloId) async {
  try {
    final rows = await db.query(
      'peer_identities',
      columns: ['identity_key'],
      where: 'address = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _keyHex(rows.first['identity_key'] as List<int>);
  } catch (e) {
    // a database with no signal tables knows no key but the card's
    dlog('held key: ${e.runtimeType}');
    return null;
  }
}

// verified counts only while the key it was given for is still theirs: a
// row whose mark names another key reads as not verified
Future<List<Map<String, Object?>>> verifiedNow(
  DatabaseExecutor db,
  List<Map<String, Object?>> rows, {
  String idColumn = 'halo_id',
  Future<String?> Function(String haloId)? identity,
}) async {
  List<Map<String, Object?>>? out;
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    if ((r['verified'] as int? ?? 0) != 1) continue;
    final id = r[idColumn] as String;
    final key = await heldKeyHex(
      db,
      id,
      xpub: r['xpub'] as String?,
      identity: identity,
    );
    final mark = (r['verified_key'] as String?)?.toLowerCase();
    if (key != null && mark == key) continue;
    out ??= List.of(rows);
    out[i] = {...r, 'verified': 0};
  }
  return out ?? rows;
}

// a mark for the key that was on screen, and only while it is still the one
// held for them. false when it has moved on since: the number shown was for
// another key. the mark and the end of the "changed" banner are one write
Future<bool> markVerified(
  DatabaseExecutor db,
  String haloId,
  bool verified, {
  String? key,
  Future<String?> Function(String haloId)? identity,
}) async {
  if (!verified) {
    await db.update(
      'contacts',
      {'verified': 0, 'verified_key': null},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
    return true;
  }
  final held = await heldKeyHex(db, haloId, identity: identity);
  if (held == null || key == null || key.trim().toLowerCase() != held) {
    return false;
  }
  final was = await db.query(
    'contacts',
    columns: ['verified', 'verified_key', 'key_changed'],
    where: 'halo_id = ?',
    whereArgs: [haloId],
    limit: 1,
  );
  await db.update(
    'contacts',
    {'verified': 1, 'verified_key': held, 'key_changed': 0},
    where: 'halo_id = ?',
    whereArgs: [haloId],
  );
  // read again: a key that moved during the write keeps its banner, and the
  // mark stays on the old key, so the hold stands
  final now = await heldKeyHex(db, haloId, identity: identity);
  if (now == held) return true;
  if (now == kKeyUnread) {
    // a key not read is not a key changed: the row goes back as it was
    if (was.isNotEmpty) {
      await db.update(
        'contacts',
        was.first,
        where: 'halo_id = ? AND verified_key = ?',
        whereArgs: [haloId, held],
      );
    }
    return false;
  }
  await db.update(
    'contacts',
    {'verified': 0, 'key_changed': 1},
    where: 'halo_id = ? AND verified_key = ?',
    whereArgs: [haloId, held],
  );
  return false;
}

// verified under one key, holding another now: the mark stays on the old key
// until the new number is checked (a new mark) or the new key accepted
Future<bool> keyHeldIn(
  DatabaseExecutor db,
  String haloId, {
  Future<String?> Function(String haloId)? identity,
  // a heal's hold counts too (Q22); false asks for a moved key alone
  bool heal = true,
}) async {
  if (isDevId(haloId)) return false;
  if (await _keyMovedIn(db, haloId, identity: identity)) return true;
  // a heal rebuilt a verified contact's session: held until the person
  // looks, whatever key they hold
  return heal && kHealHold && await healHoldOf(db, haloId) != null;
}

// verified under one key, holding another now
Future<bool> _keyMovedIn(
  DatabaseExecutor db,
  String haloId, {
  Future<String?> Function(String haloId)? identity,
}) async {
  final rows = await db.query(
    'contacts',
    columns: ['verified_key', 'xpub'],
    where: 'halo_id = ?',
    whereArgs: [haloId],
    limit: 1,
  );
  if (rows.isEmpty) return false;
  final mark = (rows.first['verified_key'] as String?)?.toLowerCase();
  if (mark == null || mark.isEmpty) return false;
  final held = await heldKeyHex(
    db,
    haloId,
    xpub: rows.first['xpub'] as String?,
    identity: identity,
  );
  return held != null && held != mark;
}

// the new key taken as it is: no mark, no banner, and sending goes on
Future<void> acceptNewKeyIn(DatabaseExecutor db, String haloId) => db.update(
  'contacts',
  {'verified': 0, 'verified_key': null, 'key_changed': 0},
  where: 'halo_id = ?',
  whereArgs: [haloId],
);

/// a name's flags (contacts.name_check). ask: their chat asks for the
/// safety number. says: the name came with a request, an introduction or
/// a group, and shows as not checked. later: the ask is put off, a quiet
/// line in place of the card. a verified key outranks them all, and an add
/// from a qr read with the camera clears them
const kNameAsk = 1;

const kNameSays = 2;

const kNameLater = 4;

int nameCheckOf(Map<String, Object?>? row) =>
    (row?['name_check'] as num?)?.toInt() ?? 0;

/// the name on [row] was given, not checked: a request, an introduction or
/// a group named them, and no qr or safety number has settled it since
bool nameUnchecked(Map<String, Object?>? row) =>
    row != null &&
    (nameCheckOf(row) & kNameSays) != 0 &&
    (row['verified'] as num?)?.toInt() != 1 &&
    !isDevId(row['halo_id'] as String? ?? '');

/// [row]'s chat asks for the safety number: added by a code or a link, or
/// taken in from a request, and not verified yet
bool nameAsks(Map<String, Object?>? row) =>
    row != null &&
    (nameCheckOf(row) & kNameAsk) != 0 &&
    (row['verified'] as num?)?.toInt() != 1 &&
    (row['accepted'] as num?)?.toInt() == 1 &&
    !isDevId(row['halo_id'] as String? ?? '');

/// the contacts rows the requests inbox holds: someone not accepted who
/// wrote one to one, waits sealed, or was introduced. a group member's
/// key-only row is none of these and asked for nothing
@visibleForTesting
const kRequestRows =
    'accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 0 AND ('
    'EXISTS (SELECT 1 FROM messages m WHERE m.peer_id = contacts.halo_id '
    'AND m.group_id IS NULL) OR '
    'EXISTS (SELECT 1 FROM held_onion h WHERE h.peer_id = contacts.halo_id) OR '
    'EXISTS (SELECT 1 FROM vouches v WHERE v.halo_id = contacts.halo_id) OR '
    "EXISTS (SELECT 1 FROM hellos hl WHERE hl.way = 'in' "
    'AND hl.peer = contacts.ikey AND hl.ident = contacts.ident))';

/// a request as the inbox shows it, or one declined and parked since
@visibleForTesting
const kAskedRows =
    '($kRequestRows) OR '
    '(accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 1)';
