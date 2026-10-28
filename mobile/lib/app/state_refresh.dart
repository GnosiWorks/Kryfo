// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the contact and group lists home shows

part of '../main.dart';

extension AppStateRefresh on AppState {
  Future<void> refreshContacts() async {
    final s = session;
    final (list, pending, dev) = await _contactsOf(s);
    final waiting = _devModeIn(s) ? await s.support.waiting() : null;
    // a session swapped while this read keeps what it was given
    if (!identical(s, _session)) return;
    contacts = list;
    pendingCount = pending;
    devRow = dev;
    if (waiting != null) supportWaiting = waiting;
    notifyListeners();
  }

  // developer mode as a session has it: his own phone, never its decoy
  bool _devModeIn(Session s) => _devIdentity && !s.container.quiet;

  // how a row says its last message, and when it was sent
  (String?, DateTime?) _lastLine(Map<String, Object?>? last) {
    if (last == null) return (null, null);
    final dir = last['direction'] as String?;
    final text = (last['plaintext'] as String?) ?? '';
    final media = last['media_path'] as String?;
    final fileName = last['file_name'] as String?;
    String body;
    // a timed message not read yet says only that it is one: its words show
    // in the chat, where reading them starts its clock
    if (burnWaitsRow(last)) {
      body = l10n.timedMessageLabel;
    } else if (last['sticker'] != null) {
      // a sticker's text is its emoji; the row says what it is
      body = l10n.stickerLabel;
    } else if (text.isNotEmpty) {
      body = text;
    } else if (fileName == 'voice.wav') {
      body = l10n.appVoiceMessage2;
    } else if (fileName != null) {
      body = fileName;
    } else if (media != null) {
      body = l10n.appPhoto;
    } else {
      body = '';
    }
    final at = last['written_at'] ?? last['sent_at'];
    return (
      body.isEmpty ? null : (dir == 'out' ? l10n.appYou(body) : body),
      at is! num ? null : DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }

  Future<(List<ContactPreview>, int, DevRow?)> _contactsOf(Session s) async {
    final rows = await s.contacts();
    final lasts = await s.lastMessages();
    // an answered support chat stays in support: out of this list, the
    // pickers and the introductions
    final apart = _devModeIn(s) ? await s.support.ids() : const <String>{};
    final list = <ContactPreview>[];
    final devRows = <String, Map<String, Object?>>{};
    for (final r in rows) {
      final haloId = r['halo_id'] as String;
      if (apart.contains(haloId)) continue;
      // the developer chat has a row of its own: kept out of this list, it
      // stays out of every picker, count and loop that reads it
      if (isDevChat(haloId)) {
        devRows[haloId] = r;
        continue;
      }
      final shots = ChatShots.ofRow(r, quiet: s.container.quiet).blocking;
      final (line, sent) = _lastLine(lasts[haloId]);
      // a chat that blocks screenshots shows none of itself in the list
      final preview = shots && line != null
          ? l10n.notificationsNewMessage
          : line;
      // default to the contact's last_seen; a real message overrides it.
      final when =
          sent ?? DateTime.fromMillisecondsSinceEpoch(r['last_seen'] as int);
      list.add(
        ContactPreview(
          haloId: haloId,
          nickname: r['nickname'] as String?,
          avatarSeed: haloId,
          avatar: (r['avatar'] as num?)?.toInt(),
          preview: preview,
          when: when,
          blocked: (r['blocked'] as int? ?? 0) == 1,
          archived: (r['archived'] as int? ?? 0) == 1,
          muted: (r['muted'] as int? ?? 0) == 1,
          verified: (r['verified'] as int? ?? 0) == 1,
          unread: (r['unread'] as int? ?? 0),
          pinned: (r['pinned'] as int? ?? 0) == 1,
          supporterBadge: r['supporter_badge'] as String?,
          hidden: s.isHidden(haloId),
          shotsBlocking: shots,
        ),
      );
    }
    // most-recent conversation floats to the top
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return (b.when ?? DateTime(0)).compareTo(a.when ?? DateTime(0));
    });
    return (
      list,
      await s.pendingRequestCount(),
      await _devRowOf(s, devRows, lasts),
    );
  }

  // the session's own row, never a vault's. a row that will not read is no
  // row: home still shows everything else
  Future<DevRow?> _devRowOf(
    Session s,
    Map<String, Map<String, Object?>> rows,
    Map<String, Map<String, Object?>> lasts,
  ) async {
    // going: off home now, though its rows go only once the take-back ends
    if (devGoing != null && !s.container.quiet) return null;
    try {
      final r = await s.devChat.load();
      final id = r?.chatId;
      final (preview, sent) = _lastLine(id == null ? null : lasts[id]);
      return devRowOf(
        r,
        contact: id == null ? null : rows[id],
        preview: preview,
        when: sent,
        // the developer's own phone has none. its decoy does
        devMode: _devModeIn(s),
      );
    } catch (e) {
      dlog('dev row: $e');
      return null;
    }
  }

  // ---- groups ----

  Future<void> refreshGroups() async {
    final s = session;
    final list = await _groupsOf(s);
    if (!identical(s, _session)) return;
    groups = list;
    notifyListeners();
  }

  Future<List<GroupPreview>> _groupsOf(Session s) async {
    final rows = await s.loadGroups();
    final list = <GroupPreview>[];
    for (final r in rows) {
      final gid = r['group_id'] as String;
      if (_leavingRooms.contains(gid)) continue;
      // an ended group counts no one: its members are kept for its end
      final members = groupEndOf(r) != null
          ? const <String>[]
          : await s.getGroupMembers(gid);
      final shots = GroupShots.ofRow(r, quiet: s.container.quiet);
      list.add(
        GroupPreview(
          groupId: gid,
          name: r['name'] as String,
          memberCount: members.length,
          isAdmin: (r['is_admin'] as int? ?? 0) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            r['created_at'] as int,
          ),
          unread: (r['unread'] as int? ?? 0),
          mentioned: (r['mentioned'] as int? ?? 0) == 1,
          expiresAt: r['expires_at'] as int?,
          joiningAt: r['joining_at'] as int?,
          hidden: s.isHidden(gid),
          endedBy: groupEndOf(r)?.by,
          shotsBlocking: shots.blocking,
          shotsForAll: shots.forAll,
        ),
      );
    }
    return list;
  }

  // the tier to advertise to contacts, or null when sharing is off.
  Future<String?> sharedBadge() async {
    if (!await loadShareBadge()) return null;
    final t = await loadSupporterTier();
    if (t == SupporterTier.none) return null;
    return t.name;
  }
}
