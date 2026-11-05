// SPDX-License-Identifier: GPL-3.0-or-later
// note to self on my own devices (own_sync.dart): an item kept on one
// device of mine, words, a photo, a file or a voice note, lands in the
// notes of my others, and one deleted on any of them goes from all. it
// rides the own device sessions as an own copy named kOwnNotes, as it was
// kept: a small one inside its frame, a bigger one through the files
// service with a token for each device, or in slices where the service
// cannot take it, as a chat's file goes. what waits is kept in
// own_notes_out until it is handed to the sessions, which keep it until
// each device answers. only the everyday side sends or takes any of it:
// the decoy's notes and the hidden chats' side never see one

part of '../main.dart';

/// bumped when my other devices moved note to self here: a note filed,
/// deleted or cleared. the notes page reads itself again
final notesMoved = ValueNotifier<int>(0);

/// how long a note waits for its way to my devices before it is let go,
/// as an own copy is (device_send.dart)
const kOwnNoteKept = Duration(days: 7);

/// the files service's name for my device [id] in a note's tokens
String ownNoteMember(int id) => 'own:$id';

/// the app state note to self works through: the one made last
AppState get notesApp => _madeApp ?? appState;

bool _ownNotesRunning = false;
bool _ownNotesAgain = false;

/// the notes owed to my devices sent now, for the tests
@visibleForTesting
Future<void> ownNotesGoForTest() async {
  Future<void> settled() async {
    while (_ownNotesRunning) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  await settled();
  await _madeApp?._ownNotesGo();
  await settled();
}

extension AppStateNotes on AppState {
  /// whether note to self here reaches other devices of mine: the everyday
  /// side with a device linked. never the decoy's or a quiet session's
  Future<bool> ownNotesShared() async {
    final own = _ownSync;
    if (own == null || !_ownSends) return false;
    try {
      return (await own.others(kMainIdent)).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// [uid], a note just kept here, owed to my other devices. nothing is
  /// kept with no device of mine, in the decoy or on the hidden side
  Future<void> ownNoteKept(String uid) async {
    final own = _ownSync;
    if (own == null || !_ownSends) return;
    try {
      if ((await own.others(kMainIdent)).isEmpty) return;
      final d = await live.open();
      await d.insert('own_notes_out', {
        'uid': uid,
        'at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      dlog('notes: not kept for my devices (${e.runtimeType})');
      return;
    }
    unawaited(_ownNotesGo());
  }

  /// a note deleted here: what of it was still to go stays, and its file
  /// on the files service is taken back. read before its file goes
  Future<void> ownNoteGone(String uid) async {
    try {
      await (await live.open()).delete(
        'own_notes_out',
        where: 'uid = ?',
        whereArgs: [uid],
      );
    } catch (e) {
      dlog('notes: a gone note stayed owed (${e.runtimeType})');
    }
  }

  // what is owed, handed to the own sessions. one that cannot go now waits
  // its turn; one a week old, or whose note is gone, is let go
  Future<void> _ownNotesGo() async {
    final own = _ownSync;
    if (own == null || !_ownSends) return;
    if (_ownNotesRunning) {
      _ownNotesAgain = true;
      return;
    }
    _ownNotesRunning = true;
    try {
      do {
        _ownNotesAgain = false;
        await _ownNotesOnce(own);
      } while (_ownNotesAgain && _ownSends);
    } catch (e) {
      dlog('notes: owed notes not sent (${e.runtimeType})');
    } finally {
      _ownNotesRunning = false;
    }
  }

  Future<void> _ownNotesOnce(OwnSync own) async {
    final d = await live.open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = await d.query(
      'own_notes_out',
      where: 'next_at <= ?',
      whereArgs: [now],
      orderBy: 'at',
      limit: 32,
    );
    if (due.isEmpty) return;
    final to = await own.others(kMainIdent);
    for (final r in due) {
      if (!_ownSends) return;
      final uid = r['uid'] as String;
      final row = await live.messageIn(kOwnNotes.id, uid);
      final at = (r['at'] as num).toInt();
      if (to.isEmpty || row == null || now - at > kOwnNoteKept.inMilliseconds) {
        await d.delete('own_notes_out', where: 'uid = ?', whereArgs: [uid]);
        continue;
      }
      final word = await _ownNoteSend(own, row, to);
      if (word == 'later') {
        final tries = (r['tries'] as num).toInt() + 1;
        await d.update(
          'own_notes_out',
          {'tries': tries, 'next_at': now + fetchGap(tries)},
          where: 'uid = ?',
          whereArgs: [uid],
        );
      } else {
        await d.delete('own_notes_out', where: 'uid = ?', whereArgs: [uid]);
      }
    }
  }

  // one note to each of [to]: 'ok' once it is on their sessions, 'later'
  // when it waits, 'never' for one that cannot go
  Future<String> _ownNoteSend(
    OwnSync own,
    Map<String, Object?> row,
    List<OwnPeer> to,
  ) async {
    final uid = row['msg_uid'] as String;
    final text = row['plaintext'] as String? ?? '';
    final written = rowWrittenAt(row);
    final path = (row['media_path'] ?? row['file_path']) as String?;
    final name = row['file_name'] as String?;
    Future<bool> go(String frame, {OwnPeer? only}) =>
        own.copy(kMainIdent, kOwnNotes, frame, only: only);
    if (path == null) {
      final f = await wrapMessage(text, msgUid: uid, writtenAt: written);
      return await go(f) ? 'ok' : 'later';
    }
    final voice = isVoiceName(name);
    final int total;
    final int size;
    try {
      total = await mediaSliceCount(path);
      size = await File(path).length();
    } catch (_) {
      return 'never';
    }
    if (total == 0) return 'never';
    Future<String> frame({String? b64, int? i, DropFrame? drop}) => wrapMessage(
      text,
      msgUid: uid,
      writtenAt: written,
      imageB64: drop == null && name == null ? b64 : null,
      fileB64: drop == null && name != null ? b64 : null,
      drop: drop,
      fileName: name,
      voice: voice,
      mediaId: total > 1 && drop == null ? uid : null,
      chunkIndex: total > 1 && drop == null ? i : null,
      chunkTotal: total > 1 && drop == null ? total : null,
    );
    if (total == 1) {
      return await go(await frame(b64: await mediaSlice(path, 0)))
          ? 'ok'
          : 'later';
    }
    // more than a slice: up to the files service once, a token for each
    // device of mine, as a chat's file goes to its members
    if (dropFits(size) && _dropsRoute) {
      if (!mediaInflight.add(uid)) return 'later';
      mediaSendsTick.value++;
      try {
        final (sent, r) = await sendDrop(
          path: path,
          uid: uid,
          members: [for (final p in to) ownNoteMember(p.id)],
          progress: false,
        );
        if (mediaCancelled.contains(uid) || r == 'error: cancelled') {
          return 'never';
        }
        if (sent != null) {
          for (final p in to) {
            await go(
              await frame(drop: sent.frameFor(ownNoteMember(p.id))),
              only: p,
            );
          }
          return 'ok';
        }
        dlog('notes: the files service said $r');
        // one too big for the relay's slices waits for the service
        if (size > kOldFileBytes) return 'later';
      } finally {
        releaseMedia(uid);
      }
    }
    if (total > kMaxFileSlices) return 'later';
    for (var i = 0; i < total; i++) {
      if (!_ownSends || mediaCancelled.contains(uid)) return 'later';
      if (!await go(await frame(b64: await mediaSlice(path, i), i: i))) {
        return 'later';
      }
    }
    return 'ok';
  }

  // ---- what my devices kept ----

  // a note one of my devices kept: filed in note to self here, once. never
  // a chat's frame, a timed one, an answer, a group's or anything but
  // words and what a note may hold
  Future<bool> _fileOwnNote(String frame) async {
    // the everyday side's notes alone: never the decoy's, never hidden
    if (live.container != HaloContainer.everyday) return false;
    final env = unwrapMessage(frame);
    if (env.typing ||
        env.deliveredUid != null ||
        env.groupControl != null ||
        env.groupId != null ||
        env.edit != null ||
        env.unsend != null ||
        env.reaction != null ||
        env.pin != null ||
        env.vote != null ||
        env.pollClose != null ||
        env.poll != null ||
        env.sticker != null ||
        env.intro != null ||
        env.need != null ||
        env.replyTo != null ||
        env.album != null ||
        env.preview != null ||
        (env.burnSeconds ?? 0) > 0) {
      return false;
    }
    final sliced = AppState._sliced(env);
    final uid = sliced ? env.mediaId : env.msgUid;
    if (uid == null || uid.isEmpty || uid.length > 128) return false;
    if (await live.messageExists(uid) || await _ownGoneHas(uid)) return false;
    if (env.drop != null) return _ownNoteDrop(env, frame, uid);
    final got = await _ownMediaIn(env, uid);
    if (got == null) return false;
    final kept = await _keepOwnNote(
      env,
      uid,
      mediaPath: got.mediaPath,
      filePath: got.filePath,
      unsaved: got.unsaved,
    );
    if (sliced) await live.dropMediaChunks(uid);
    return kept;
  }

  Future<bool> _keepOwnNote(
    UnwrappedMessage env,
    String uid, {
    String? mediaPath,
    String? filePath,
    bool unsaved = false,
  }) async {
    final text = unsaved
        ? [
            env.message,
            l10n.appAnAttachmentCouldNotShown,
          ].where((s) => s.trim().isNotEmpty).join('\n')
        : env.message;
    if (text.trim().isEmpty && mediaPath == null && filePath == null) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final written = env.writtenAt != null && env.writtenAt! <= now
        ? env.writtenAt!
        : now;
    await live.saveMessage(
      kOwnNotes.id,
      'in',
      text,
      msgUid: uid,
      mediaPath: mediaPath,
      filePath: filePath,
      fileName: filePath == null ? null : env.fileName,
      sentAt: now,
      writtenAt: written,
    );
    final shown = mediaPath ?? filePath;
    if (shown != null) makeBlurSoon(shown);
    notesMoved.value++;
    return true;
  }

  // a note whose file is on the files service: kept to fetch, and filed
  // once it is in (_fileNoteFetched). one the service already gave this
  // device, or past the bound on what comes, keeps its words
  Future<bool> _ownNoteDrop(
    UnwrappedMessage env,
    String frame,
    String uid,
  ) async {
    final drop = env.drop!;
    final d = await live.open();
    if (await fetchOf(d, uid) != null) return false;
    final why = await fetchRefused(d, sender: kOwnNotes.id, fileId: drop.id);
    if (why != null) {
      dlog('notes: a frame not kept ($why)');
      return _keepOwnNote(env, uid, unsaved: true);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final path = await fetchPathIn(await live.container.mediaDir());
    await noteSeen(d, drop.id, now);
    await noteFetch(
      d,
      uid: uid,
      sender: kOwnNotes.id,
      groupId: null,
      wire: frame,
      backPair: false,
      size: drop.size,
      path: path,
      now: now,
    );
    unawaited(fetchDrops());
    return true;
  }

  // a note's file fetched, or gone from the service: the note filed with
  // it, or with the line that it could not be shown
  Future<void> _fileNoteFetched(
    HaloDb d,
    DropFetch f,
    UnwrappedMessage env,
  ) async {
    // the everyday side's alone
    if (!identical(d, live)) return;
    if (await live.messageExists(f.uid) || await _ownGoneHas(f.uid)) return;
    final now = await fetchOf(await live.open(), f.uid);
    if (now?.state != kFetchHave) {
      await _keepOwnNote(env, f.uid, unsaved: true);
      return;
    }
    final out = env.fileName != null
        ? await receivedFileFor(env.fileName!, live.container)
        : await receivedImageFor(live.container);
    try {
      await File(f.path).rename(out.path);
    } catch (e) {
      dlog('notes: a fetched file not moved (${e.runtimeType})');
      await _keepOwnNote(env, f.uid, unsaved: true);
      return;
    }
    await _keepOwnNote(
      env,
      f.uid,
      mediaPath: env.fileName == null ? out.path : null,
      filePath: env.fileName == null ? null : out.path,
    );
  }

  // a note deleted on another device of mine while its file was still on
  // its way here: the fetch stops, what came goes, the service hears it
  Future<bool> _noteFetchGone(String uid) async {
    final db = await live.open();
    final f = await fetchOf(db, uid);
    final frame = f == null ? null : unwrapMessage(f.wire).drop;
    if (f == null || f.sender != kOwnNotes.id || frame == null) return false;
    engine.fileCancel('f:${frame.id}');
    await _letFetchGo(db, f, frame, live.container.chatKey(kOwnNotes.id));
    return true;
  }

  // every note cleared on my phone at [t]: what came here after it stays
  Future<void> _ownClearNotes(int t) async {
    final d = await live.open();
    final newer = await d.query(
      'messages',
      columns: ['id'],
      where: 'peer_id = ? AND group_id IS NULL AND sent_at > ?',
      whereArgs: [kOwnNotes.id, t],
      limit: 1,
    );
    if (newer.isEmpty) {
      await live.deleteAllOf(kOwnNotes.id);
    } else {
      for (final r in await d.query(
        'messages',
        columns: ['msg_uid'],
        where:
            'peer_id = ? AND group_id IS NULL AND sent_at <= ? AND '
            'msg_uid IS NOT NULL',
        whereArgs: [kOwnNotes.id, t],
      )) {
        await live.deleteMessage(r['msg_uid'] as String);
      }
    }
    notesMoved.value++;
  }
}
