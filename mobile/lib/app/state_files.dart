// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: files through the files service (file_drop.dart). a file goes
// up once and its frame goes out like a message; a frame that comes in is
// kept until its file is fetched, then filed as if the file had come with
// it, and the service is told it can let the file go

part of '../main.dart';

// one fetch pass at a time: a big file on tor takes minutes, and two
// passes would fetch it twice
bool _dropFetchRunning = false;
bool _dropFetchAgain = false;

extension AppStateFiles on AppState {
  // ---- which phones fetch from the files service ----

  Future<void> _takeDrops(String peer, UnwrappedMessage env, HaloDb db) async {
    if (isDevId(peer)) return;
    try {
      final d = await db.open();
      final counts = AppState._dataFrame(env) && env.msgUid != null;
      final g = env.groupId;
      if (g != null) {
        await takeMemberDrops(
          d,
          g,
          peer,
          carried: env.takesDrops,
          counts: counts,
          written: env.writtenAt,
        );
      } else {
        await takePeerDrops(
          d,
          peer,
          carried: env.takesDrops,
          counts: counts,
          written: env.writtenAt,
        );
      }
    } catch (e) {
      dlog('files: word not taken (${e.runtimeType})');
    }
  }

  /// a file to [peer] may go through the files service
  Future<bool> dropsFor(String peer) async {
    if (isDevId(peer)) return false;
    try {
      return await peerTakesDrops(await session.chatDb(peer), peer);
    } catch (e) {
      dlog('files: word not read (${e.runtimeType})');
      return false;
    }
  }

  /// a file to group [groupId] may go through the files service: every
  /// other member's phone fetches from it
  Future<bool> dropsForGroup(String groupId) async {
    try {
      return await groupTakesDrops(
        await session.chatDb(groupId),
        groupId,
        sessionId,
      );
    } catch (e) {
      dlog('files: group word not read (${e.runtimeType})');
      return false;
    }
  }

  /// the most a file to this 1:1 chat may be
  Future<int> fileLimitFor(String peer) async =>
      fileLimit(drops: await dropsFor(peer));

  Future<int> fileLimitForGroup(String groupId) async =>
      fileLimit(drops: await dropsForGroup(groupId));

  // ---- sending ----

  /// [path] sealed and sent up for [members], the strip of [uid] following
  /// it when [progress]. the frame and each member's token, or the
  /// engine's word for why not
  Future<(DropSent?, String)> sendDrop({
    required String path,
    required String uid,
    required List<String> members,
    bool progress = true,
  }) async {
    final key = 's:$uid';
    final watch = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mediaCancelled.contains(uid)) engine.fileCancel(key);
      final p = engine.fileProgress(key);
      // the last few percent are the frame's own send
      if (p != null && progress) mediaProgressUpdate(uid, 0.97 * p.$1 / p.$2);
    });
    try {
      final r = await engine.fileSend(
        dropSendJob(
          path: path,
          uid: uid,
          members: members,
          lane: 'files:${session.container.id}',
        ),
      );
      final sent = dropSentOf(r);
      return (sent, sent == null ? r : 'ok');
    } finally {
      watch.cancel();
    }
  }

  /// a file sent through the service taken back from it: an unsend. the
  /// service lets it go on its own a week on, so a miss here costs nothing
  /// but that week
  Future<void> takeDropBack(String path, String uid) async {
    try {
      final r = await engine.fileTakeBack(
        dropSendJob(path: path, uid: uid, members: const ['-'], lane: ''),
      );
      if (r != 'ok') dlog('files: not taken back ($r)');
    } catch (e) {
      dlog('files: not taken back (${e.runtimeType})');
    }
  }

  // ---- a frame coming in ----

  /// what the chat files for a frame whose file is on the service: its
  /// path once it is in, '' when it will not come, null while it is still
  /// coming (the frame is kept and fetched, and filed again once it is in)
  Future<String?> _dropArrived(
    String sender,
    UnwrappedMessage env,
    HaloDb db, {
    required String wire,
    required bool fromBackPair,
  }) async {
    final uid = env.msgUid!;
    final frame = env.drop!;
    final d = await db.open();
    final f = await fetchOf(d, uid);
    if (f == null) {
      await noteFetch(
        d,
        uid: uid,
        sender: sender,
        groupId: env.groupId,
        wire: wire,
        backPair: fromBackPair,
        size: frame.size,
        path: await fetchPathIn(await db.container.mediaDir()),
        now: DateTime.now().millisecondsSinceEpoch,
      );
      incomingMediaUpdate(
        db.container.chatKey(env.groupId ?? sender),
        0,
        frame.chunks,
      );
      unawaited(fetchDrops());
      return null;
    }
    if (f.state == kFetchWaiting) return null;
    if (f.state != kFetchHave) return '';
    // the file moves into the media folder under a name of the chat's own
    final out = env.fileName != null
        ? await receivedFileFor(env.fileName!, db.container)
        : await receivedImageFor(db.container);
    try {
      await File(f.path).rename(out.path);
      return out.path;
    } catch (e) {
      dlog('files: fetched file not moved (${e.runtimeType})');
      return '';
    }
  }

  /// [uid] taken back by [sender] while its file was still coming: the
  /// fetch stops, what came of it goes, and the service hears this phone
  /// is done with it
  Future<void> _dropFetchTakenBack(String sender, String uid, HaloDb db) async {
    try {
      final d = await db.open();
      final f = await fetchOf(d, uid);
      final frame = f == null ? null : unwrapMessage(f.wire).drop;
      if (f == null || f.sender != sender || frame == null) return;
      engine.fileCancel('f:${frame.id}');
      await _letFetchGo(d, f, frame, db.container.chatKey(f.groupId ?? sender));
    } catch (e) {
      dlog('files: a fetch taken back stayed (${e.runtimeType})');
    }
  }

  // ---- fetching ----

  /// fetches what is due, the open vault's too, one file at a time
  Future<void> fetchDrops() async {
    if (_dropFetchRunning) {
      _dropFetchAgain = true;
      return;
    }
    _dropFetchRunning = true;
    try {
      do {
        _dropFetchAgain = false;
        for (final d in [live, ?_openVault]) {
          if (everydayHeld || haloWiping || !linkUp) return;
          try {
            await _fetchDropsIn(d);
          } catch (e) {
            dlog('files: fetch pass stopped (${e.runtimeType})');
          }
        }
      } while (_dropFetchAgain);
    } finally {
      _dropFetchRunning = false;
    }
  }

  @visibleForTesting
  Future<void> fetchDropsInForTest(HaloDb d) =>
      _fetchDropsIn(d, stop: () => false);

  Future<void> _fetchDropsIn(HaloDb d, {bool Function()? stop}) async {
    final db = await d.open();
    final halt = stop ?? () => everydayHeld || haloWiping || !linkUp;
    // a vault shut part way keeps what it holds for its next open
    bool shut() => !identical(d, live) && !identical(d, _openVault);
    for (final f in await dueFetches(
      db,
      DateTime.now().millisecondsSinceEpoch,
    )) {
      if (halt() || shut()) return;
      final env = unwrapMessage(f.wire);
      final frame = env.drop;
      final chat = d.container.chatKey(f.groupId ?? f.sender);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (frame == null) {
        await dropFetchRow(db, f.uid);
        continue;
      }
      if (f.state == kFetchFiled) {
        await _sayGot(db, f, frame);
        continue;
      }
      if (f.state == kFetchWaiting) {
        if (await d.isBlocked(f.sender)) {
          await _letFetchGo(db, f, frame, chat);
          continue;
        }
        if (now - f.at > kFetchKeptFor.inMilliseconds) {
          await fetchState(db, f.uid, kFetchGone);
        } else {
          final r = await _fetchOne(f, frame, chat);
          if (r == 'ok') {
            await fetchState(db, f.uid, kFetchHave);
          } else if (r == 'error: gone' || r == 'error: bad') {
            dlog('files: a file did not come ($r)');
            await fetchState(db, f.uid, kFetchGone);
          } else {
            dlog('files: fetch to try again ($r)');
            await fetchTried(db, f.uid, f.tries + 1, now);
            continue;
          }
        }
      }
      incomingMediaDone(chat);
      if (shut()) return;
      // filed as if it had just come, the file with it
      try {
        await _applyIncomingPayload(
          f.sender,
          env,
          wire: f.wire,
          fromBackPair: f.backPair,
          into: identical(d, live) ? null : d,
        );
      } catch (e) {
        // a stranger past their two, a sender blocked since: not filed
        dlog('files: fetched file not filed (${e.runtimeType})');
      }
      if (shut()) return;
      await _letFetchGo(db, f, frame, chat);
    }
  }

  // one fetch, its progress on the chat's strip
  Future<String> _fetchOne(DropFetch f, DropFrame frame, String chat) async {
    final key = 'f:${frame.id}';
    final watch = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final p = engine.fileProgress(key);
      if (p != null) {
        incomingMediaUpdate(chat, p.$1 * frame.chunks ~/ p.$2, frame.chunks);
      }
    });
    try {
      return await engine.fileFetch(frame.fetchJob(f.path));
    } catch (e) {
      return 'error: ${e.runtimeType}';
    } finally {
      watch.cancel();
    }
  }

  // the fetch is done with, filed or not: what is left of it on this phone
  // goes, and the service hears this phone has it
  Future<void> _letFetchGo(
    Database db,
    DropFetch f,
    DropFrame frame,
    String chat,
  ) async {
    incomingMediaDone(chat);
    for (final p in [f.path, '${f.path}.part', '${f.path}.open']) {
      try {
        await shredFile(p);
      } catch (_) {
        // shredFile logs its own failure
      }
    }
    await _sayGot(db, f, frame);
  }

  // a got that does not land waits for the next pass, the row kept for it
  // alone. the service lets the file go in a week whatever happens
  Future<void> _sayGot(Database db, DropFetch f, DropFrame frame) async {
    final t = frame.token;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (t != null && now - f.at < kFetchKeptFor.inMilliseconds) {
      final r = await engine.fileGot(frame.host, frame.id, t);
      if (r != 'ok') {
        dlog('files: got not said ($r)');
        await fetchState(db, f.uid, kFetchFiled);
        await fetchTried(db, f.uid, f.tries + 1, now);
        return;
      }
    }
    await dropFetchRow(db, f.uid);
  }
}
