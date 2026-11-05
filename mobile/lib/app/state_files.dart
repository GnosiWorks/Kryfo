// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: files through the files service (file_drop.dart). a file goes
// up once and its frame goes out like a message; a frame that comes in is
// kept until its file is fetched, then filed as if the file had come with
// it, and the service is told it can let the file go

part of '../main.dart';

// one fetch pass at a time: a big file on tor takes minutes, and two
// passes would fetch it twice
bool _dropFetchRunning = false;

// this phone's day of big files, a container's own, in memory
final Map<String, String> _dropDays = {};
bool _dropFetchAgain = false;

// the fetch under way: its database, its engine key and its chat, so a
// vault that closes stops its own
({HaloDb d, String key, String chat})? _fetching;

extension AppStateFiles on AppState {
  // ---- which phones fetch from the files service ----

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

  /// the most a file to this 1:1 chat may be. off the private route tor
  /// may not be there to carry the files service: then the relay's
  /// slices are all there is
  Future<int> fileLimitFor(String peer) async =>
      fileLimit(drops: _dropsRoute && await dropsFor(peer));

  Future<int> fileLimitForGroup(String groupId) async =>
      fileLimit(drops: _dropsRoute && await dropsForGroup(groupId));

  bool get _dropsRoute => sendMode == 'private' || servicesReady;

  // ---- sending ----

  /// [path] sealed and sent up for [members], the strip of [uid] following
  /// it when [progress]. the frame and each member's token, or the
  /// engine's word for why not. past this container's day of big files it
  /// is 'error: limit', and a stop asked once it was up takes it back
  Future<(DropSent?, String)> sendDrop({
    required String path,
    required String uid,
    required List<String> members,
    bool progress = true,
  }) async {
    // in memory only: a count on disk would say what this container sent,
    // and a restart that starts the day over binds an honest app as well
    final dayKey = session.container.id;
    final day = dropDayOf(_dropDays[dayKey], DateTime.now());
    final int size;
    try {
      size = await File(path).length();
    } catch (_) {
      return (null, 'error: read');
    }
    if (!dropDayFits(day, size)) return (null, 'error: limit');
    final key = 's:$uid';
    final watch = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mediaCancelled.contains(uid)) engine.fileCancel(key);
      final p = engine.fileProgressOf(key);
      if (p == null || !progress) return;
      mediaPreparingSet(uid, p.preparing);
      // the last few percent are the frame's own send
      mediaProgressUpdate(uid, 0.97 * p.done / p.total);
    });
    try {
      // the engine reads the file by path: a sealed one goes in as memory
      final r = await withNativeFiles(
        [path],
        const [],
        (i, _) => engine.fileSend(
          dropSendJob(path: i[0], uid: uid, members: members),
        ),
      );
      final sent = dropSentOf(r);
      if (sent != null && sent.sent) _dropDays[dayKey] = dropDayAdd(day, size);
      // stopped in the last of it, after the file was up: it comes down
      // again, as one stopped part way does in the engine
      if (sent != null && mediaCancelled.contains(uid)) {
        unawaited(takeDropBack(path, uid));
        return (null, 'error: cancelled');
      }
      return (sent, sent == null ? r : 'ok');
    } finally {
      watch.cancel();
      mediaPreparingSet(uid, false);
    }
  }

  @visibleForTesting
  String? get dropDayForTest => _dropDays[session.container.id];
  @visibleForTesting
  set dropDayForTest(String? kept) => kept == null
      ? _dropDays.remove(session.container.id)
      : _dropDays[session.container.id] = kept;

  /// a file sent through the service taken back from it: an unsend. the
  /// service lets it go on its own a week on, so a miss here costs nothing
  /// but that week
  Future<void> takeDropBack(String path, String uid) async {
    try {
      final r = await withNativeFiles(
        [path],
        const [],
        (i, _) => engine.fileTakeBack(
          dropSendJob(path: i[0], uid: uid, members: const ['-']),
        ),
      );
      if (r != 'ok') dlog('files: not taken back ($r)');
    } catch (e) {
      dlog('files: not taken back (${e.runtimeType})');
    }
  }

  /// a file this phone sent through the service, taken back from it before
  /// its row and its file go here: an unsend, or a stop after it was up.
  /// its values are read from the file now, while it is on disk; the take
  /// back itself goes after. one that went as slices is not on the service
  /// and the take back finds nothing
  Future<void> takeDropBackOf(String uid) async {
    try {
      // the hidden chats' rows first while they are open, as the delete
      // finds them
      Map<String, Object?>? r;
      for (final d in [?_openVault, live]) {
        r ??= await d.sentMediaRow(uid);
      }
      // mine: one I sent, or a note to self kept here
      if (r == null ||
          (r['direction'] != 'out' && r['peer_id'] != kOwnNotes.id)) {
        return;
      }
      final path = (r['file_path'] ?? r['media_path']) as String?;
      if (path == null || !dropFits(await File(path).length())) return;
      final v = jsonDecode(
        await withNativeFiles(
          [path],
          const [],
          (i, _) => engine.fileValues(
            dropSendJob(path: i[0], uid: uid, members: const ['-']),
          ),
        ),
      );
      if (v is! Map) return;
      unawaited(
        engine
            .fileTakeBack(
              jsonEncode({'host': kDropHost, 'id': v['id'], 'own': v['own']}),
            )
            .then((r) {
              if (r != 'ok') dlog('files: not taken back ($r)');
            }),
      );
    } catch (e) {
      dlog('files: not taken back (${e.runtimeType})');
    }
  }

  // ---- a frame coming in ----

  /// what the chat files for a frame whose file is on the service: its
  /// path once it is in, '' when it will not come, null while it is still
  /// coming (the frame is kept and fetched, and filed again once it is in).
  /// [waits]: the message is filed now and its file comes later, on a tap
  /// or on wi-fi, at the path given
  Future<(String?, {bool waits})> _dropArrived(
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
      // a file is fetched once, and what comes in at once has a ceiling
      // never in silence: a frame not kept shows as its message with the
      // line that its file could not be saved, in a group as in a 1:1
      final why = await fetchRefused(d, sender: sender, fileId: frame.id);
      if (why != null) {
        dlog('files: a frame not kept ($why)');
        return ('', waits: false);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final media = await db.container.mediaDir();
      final path = await fetchPathIn(media);
      // the sealed bytes fetched while hidden chats were closed: the fetch
      // goes on from them
      final held = await takeHeld(media, frame.token!, path);
      // what comes on its own comes now; the rest is filed and waits
      final kind = getKindOf(env.fileName);
      final gets = held || await _getsNow(kind);
      await noteSeen(d, frame.id, now);
      await noteFetch(
        d,
        uid: uid,
        sender: sender,
        groupId: env.groupId,
        wire: wire,
        backPair: fromBackPair,
        size: frame.size,
        path: path,
        now: now,
        state: gets ? kFetchWaiting : kFetchAsks,
      );
      if (!gets) {
        return (await _waitingPath(env, db, uid, kFetchAsks), waits: true);
      }
      // a gif shows no share: it just appears
      if (!env.gif) {
        incomingMediaUpdate(
          db.container.chatKey(env.groupId ?? sender),
          0,
          frame.chunks,
          uid: uid,
          bytes: frame.size,
        );
      }
      unawaited(fetchDrops());
      return (null, waits: false);
    }
    if (f.state == kFetchWaiting) return (null, waits: false);
    // paused before it was filed: filed now, the rest on a tap
    if (fetchFiledFirst(f.state)) {
      return (await _waitingPath(env, db, uid, f.state), waits: true);
    }
    if (f.state != kFetchHave) return ('', waits: false);
    // the file moves into the media folder under a name of the chat's own
    final out = await _namedPath(env, db);
    try {
      await File(f.path).rename(out);
      makeBlurSoon(out);
      return (out, waits: false);
    } catch (e) {
      dlog('files: fetched file not moved (${e.runtimeType})');
      return ('', waits: false);
    }
  }

  // where a file from [env] lives in the chat's media, under a name of the
  // chat's own
  Future<String> _namedPath(UnwrappedMessage env, HaloDb db) async =>
      (env.fileName != null
              ? await receivedFileFor(env.fileName!, db.container)
              : await receivedImageFor(db.container))
          .path;

  // the path a waiting file will have, its bubble told what it waits for
  Future<String> _waitingPath(
    UnwrappedMessage env,
    HaloDb db,
    String uid,
    int state,
  ) async {
    final rules = await loadAutoGet(session.container);
    final kind = getKindOf(env.fileName);
    setFileWait(
      uid,
      FileWait(
        size: env.drop!.size,
        state: _waitStateOf(state),
        rule: kind == null ? AutoGet.always : rules[kind]!,
      ),
    );
    return _namedPath(env, db);
  }

  static WaitState _waitStateOf(int state) => switch (state) {
    kFetchComing => WaitState.coming,
    kFetchPaused => WaitState.paused,
    _ => WaitState.asks,
  };

  // ---- automatic download ----

  /// a file of [kind] comes on its own on the network the phone is on now
  Future<bool> _getsNow(GetKind? kind) async {
    if (kind == null) return true;
    return autoGets(
      await loadAutoGet(session.container),
      kind,
      await unmeteredNow(),
    );
  }

  /// the person asked for a waiting file, or to go on with a paused one
  Future<void> downloadNow(String uid) async {
    for (final d in [live, ?_openVault]) {
      final db = await d.open();
      final f = await fetchOf(db, uid);
      if (f == null || !fetchFiledFirst(f.state)) continue;
      await fetchState(db, uid, kFetchComing);
      final w = fileWaitOf(uid);
      if (w != null) setFileWait(uid, w.copyWith(state: WaitState.coming));
      unawaited(fetchDrops());
      return;
    }
  }

  /// the person paused a file on its way in. one not filed yet is filed
  /// now, and waits for a tap to go on; its bytes so far are kept
  Future<void> pauseDownload(String uid) async {
    for (final d in [live, ?_openVault]) {
      final db = await d.open();
      final f = await fetchOf(db, uid);
      if (f == null) continue;
      if (f.state != kFetchWaiting && f.state != kFetchComing) return;
      await fetchState(db, uid, kFetchPaused);
      final w = fileWaitOf(uid);
      if (w != null) setFileWait(uid, w.copyWith(state: WaitState.paused));
      final frame = unwrapMessage(f.wire).drop;
      if (frame != null) engine.fileCancel('f:${frame.id}');
      return;
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

  /// a frame for hidden chats while they are closed: its file is fetched
  /// now and kept sealed, with no key to open it, in the hidden chats' own
  /// folder. it opens when they do, with no download then (takeHeld)
  Future<void> _holdDrop(DropFrame frame) async {
    final c = session.container == HaloContainer.decoy
        ? HaloContainer.decoyVault
        : HaloContainer.vault;
    try {
      final t = frame.token;
      if (t == null) return;
      final path = await heldPathIn(await c.mediaDir(), t);
      for (var t = 0; t < 3 && !haloWiping; t++) {
        if (t > 0) await Future<void>.delayed(const Duration(seconds: 30));
        final r = await engine.fileFetch(frame.fetchJob(path, blind: true));
        if (r == 'held' || r == 'error: gone' || r == 'error: denied') return;
      }
    } catch (e) {
      dlog('files: a hidden file not held (${e.runtimeType})');
    }
  }

  // ---- fetching ----

  /// fetches what is due, the open vault's too, one file at a time
  Future<void> fetchDrops() async {
    // the bubbles of filed files know what they wait for before any link
    await _loadFileWaits();
    if (_dropFetchRunning) {
      _dropFetchAgain = true;
      return;
    }
    _dropFetchRunning = true;
    try {
      do {
        _dropFetchAgain = false;
        for (final d in [live, ?_openVault]) {
          if (everydayHeld || haloWiping || !linkUp) {
            _waitsHalted();
            return;
          }
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

  // the waits as the databases hold them: new rows join, rows gone (a chat
  // cleared, a take back, a vault closed) leave. one on its way that no
  // fetch runs for waits until one does
  Future<void> _loadFileWaits() async {
    // a decoy never reads the everyday side
    if (sessionQuiet) return;
    try {
      final before = fileWaits.value.keys.toSet();
      final rules = await loadAutoGet(session.container);
      final seen = <String>{};
      for (final d in [live, ?_openVault]) {
        for (final f in await filedFetches(await d.open())) {
          seen.add(f.uid);
          if (fileWaitOf(f.uid) != null) continue;
          final env = unwrapMessage(f.wire);
          final kind = getKindOf(env.fileName);
          final state = _waitStateOf(f.state);
          setFileWait(
            f.uid,
            FileWait(
              size: f.size,
              state: state == WaitState.coming && !fileWaitMoves(f.uid)
                  ? WaitState.asks
                  : state,
              rule: kind == null ? AutoGet.always : rules[kind]!,
            ),
          );
        }
      }
      keepOnlyWaits(seen, before);
    } catch (e) {
      dlog('files: waits not read (${e.runtimeType})');
    }
  }

  @visibleForTesting
  Future<void> loadFileWaitsForTest() => _loadFileWaits();

  // no link, or held: what was on its way waits for the next pass
  void _waitsHalted() {
    for (final MapEntry(key: uid, value: w) in fileWaits.value.entries) {
      if (w.state == WaitState.coming && !fileWaitMoves(uid)) {
        setFileWait(uid, w.copyWith(state: WaitState.asks));
      }
    }
  }

  /// hidden chats closed: their fetch stops where it is (its .part stays
  /// for the next open) and their waits leave the registry
  void _vaultFetchStops(HaloDb v) {
    final f = _fetching;
    if (f != null && identical(f.d, v)) {
      engine.fileCancel(f.key);
      incomingMediaDone(f.chat);
    }
    unawaited(_loadFileWaits());
  }

  @visibleForTesting
  void vaultClosedForTest(HaloDb v) => _vaultFetchStops(v);

  @visibleForTesting
  Future<void> fetchDropsInForTest(HaloDb d) =>
      _fetchDropsIn(d, stop: () => false);

  Future<void> _fetchDropsIn(HaloDb d, {bool Function()? stop}) async {
    final db = await d.open();
    final halt = stop ?? () => everydayHeld || haloWiping || !linkUp;
    // a vault shut part way keeps what it holds for its next open
    bool shut() => !identical(d, live) && !identical(d, _openVault);
    for (var f in await dueFetches(db, DateTime.now().millisecondsSinceEpoch)) {
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
      if (fetchFiledFirst(f.state)) {
        await _fetchFiled(d, db, f, env, frame, chat);
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
          // a blind fetch may have finished since the frame was kept
          await takeHeld(await d.container.mediaDir(), frame.token!, f.path);
          final r = await _fetchOne(d, f, frame, chat, quiet: env.gif);
          // the chat was cleared or put away while it came: nothing of it
          // is filed, and the service hears this phone is done with it
          final after = await fetchOf(db, f.uid);
          if (after == null) {
            await _letFetchGo(db, f, frame, chat);
            continue;
          }
          // paused part way: its message is filed now and waits for a tap.
          // one whose last byte was in before the pause is simply in
          if (r != 'ok' && after.state == kFetchPaused) {
            incomingMediaDone(chat);
            await _fileNow(d, f, env);
            continue;
          }
          if (r == 'ok') {
            await fetchState(db, f.uid, kFetchHave);
          } else if (r == 'error: gone' ||
              r == 'error: bad' ||
              r == 'error: denied') {
            dlog('files: a file did not come ($r)');
            await fetchState(db, f.uid, kFetchGone);
          } else {
            dlog('files: fetch to try again ($r)');
            await fetchTried(db, f.uid, f.tries + 1, now);
            continue;
          }
        }
      }
      // what came is sealed now, before a shut vault leaves it for later
      if ((await fetchOf(db, f.uid))?.state == kFetchHave) {
        final sealed = await _sealFetched(db, f);
        if (sealed == null) continue;
        f = sealed;
      }
      incomingMediaDone(chat);
      if (shut()) return;
      if (await fetchOf(db, f.uid) == null) {
        await _letFetchGo(db, f, frame, chat);
        continue;
      }
      // filed as if it had just come, the file with it
      await _fileNow(d, f, env);
      if (shut()) return;
      await _letFetchGo(db, f, frame, chat);
    }
  }

  // the engine's plain file in the fetch folder moved through the seal
  // into got/, its row after. a stop between leaves the row on the fetch
  // path: the next pass finds the sealed copy and points the row at it.
  // one whose plain file could not be sealed (its hidden chats shut that
  // moment) is shredded and fetched again: null, and it waits
  Future<DropFetch?> _sealFetched(Database db, DropFetch f) async {
    if (!inFetchFolder(f.path)) return f;
    if (!await File(f.path).exists()) {
      final got = gotPathFor(f.path);
      if (await File(got).exists()) {
        await db.update(
          'file_fetches',
          {'path': got},
          where: 'msg_uid = ?',
          whereArgs: [f.uid],
        );
        return f.withPath(got);
      }
      // shredded unsealed before: in again from the service
      await fetchState(db, f.uid, kFetchWaiting);
      return null;
    }
    final to = gotPathFor(f.path);
    try {
      await Directory(p.dirname(to)).create(recursive: true);
      await File(f.path).rename(to);
    } catch (e) {
      dlog('files: a fetched file not sealed (${e.runtimeType})');
      desk_trace.trace('media seal failed: ${e.runtimeType}');
      await shredFile(f.path);
      try {
        await fetchState(db, f.uid, kFetchWaiting);
      } catch (_) {
        // its database shut too: the next open finds it gone and asks again
      }
      return null;
    }
    await db.update(
      'file_fetches',
      {'path': to},
      where: 'msg_uid = ?',
      whereArgs: [f.uid],
    );
    // the engine's parts of it go with it
    for (final s in const ['.part', '.open']) {
      await shredFile('${f.path}$s');
    }
    desk_trace.trace('media seal ok');
    return f.withPath(to);
  }

  // the kept envelope filed as if it had just come
  Future<void> _fileNow(HaloDb d, DropFetch f, UnwrappedMessage env) async {
    // a note of mine from another device of mine: into note to self
    if (f.sender == kOwnNotes.id) {
      try {
        await _fileNoteFetched(d, f, env);
      } catch (e) {
        dlog('notes: fetched file not filed (${e.runtimeType})');
      }
      return;
    }
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
  }

  // a file whose message is filed already: it waits for a tap or for
  // wi-fi, or comes now and takes the place its message names
  Future<void> _fetchFiled(
    HaloDb d,
    Database db,
    DropFetch f,
    UnwrappedMessage env,
    DropFrame frame,
    String chat,
  ) async {
    // its message is being filed this moment
    if (_inflightUids.contains(f.uid)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    var target = await d.incomingFilePath(f.uid);
    if (target == null &&
        f.state == kFetchPaused &&
        !await d.messageExists(f.uid)) {
      // paused before it was filed: filed now. one the gates turn away, or
      // the person deleted, is let go below
      await _fileNow(d, f, env);
      target = await d.incomingFilePath(f.uid);
    }
    if (target == null) {
      setFileWait(f.uid, null);
      await _letFetchGo(db, f, frame, chat);
      return;
    }
    // a week on the service and it is gone from there
    if (now - f.at > kFetchKeptFor.inMilliseconds ||
        await d.isBlocked(f.sender)) {
      await _neverCame(d, db, f, frame);
      return;
    }
    var state = f.state;
    final rules = await loadAutoGet(session.container);
    final kind = getKindOf(env.fileName);
    // one that waits for wi-fi comes once it is on wi-fi
    if (state == kFetchAsks && autoGets(rules, kind, await unmeteredNow())) {
      state = kFetchComing;
      await fetchState(db, f.uid, state);
    }
    final w = fileWaitOf(f.uid);
    setFileWait(
      f.uid,
      FileWait(
        size: frame.size,
        state: _waitStateOf(state),
        rule: kind == null ? AutoGet.always : rules[kind]!,
        share: w?.share ?? 0,
      ),
    );
    if (state != kFetchComing) return;
    final r = await _fetchOne(d, f, frame, chat, waiting: true, quiet: env.gif);
    final after = await fetchOf(db, f.uid);
    if (after == null || await d.incomingFilePath(f.uid) == null) {
      setFileWait(f.uid, null);
      await _letFetchGo(db, f, frame, chat);
      return;
    }
    // a pause that came after the last byte pauses nothing
    if (r != 'ok' && after.state == kFetchPaused) {
      final w = fileWaitOf(f.uid);
      if (w != null) setFileWait(f.uid, w.copyWith(state: WaitState.paused));
      return;
    }
    if (r == 'ok') {
      try {
        await File(f.path).rename(target);
      } catch (e) {
        dlog('files: fetched file not moved (${e.runtimeType})');
        await _neverCame(d, db, f, frame);
        return;
      }
      makeBlurSoon(target);
      setFileWait(f.uid, null);
      await _letFetchGo(db, f, frame, chat);
      chatChanged(f.groupId == null ? f.sender : 'group:${f.groupId}');
    } else if (r == 'error: gone' ||
        r == 'error: bad' ||
        r == 'error: denied') {
      dlog('files: a file did not come ($r)');
      await _neverCame(d, db, f, frame);
    } else {
      dlog('files: fetch to try again ($r)');
      await fetchTried(db, f.uid, f.tries + 1, now);
      // it waits for its next try, or a tap
      final w = fileWaitOf(f.uid);
      if (w != null) setFileWait(f.uid, w.copyWith(state: WaitState.asks));
    }
  }

  // a filed file that will not come: its message says so, the rest goes
  Future<void> _neverCame(
    HaloDb d,
    Database db,
    DropFetch f,
    DropFrame frame,
  ) async {
    setFileWait(f.uid, null);
    await d.fileNeverCame(f.uid, l10n.appAnAttachmentCouldNotShown);
    await _letFetchGo(db, f, frame, d.container.chatKey(f.groupId ?? f.sender));
    chatChanged(f.groupId == null ? f.sender : 'group:${f.groupId}');
  }

  // one fetch, its progress on the chat's strip, or on its own bubble for
  // a file whose message is filed already
  Future<String> _fetchOne(
    HaloDb d,
    DropFetch f,
    DropFrame frame,
    String chat, {
    bool waiting = false,
    // a gif: no share shows
    bool quiet = false,
  }) async {
    final key = 'f:${frame.id}';
    final mine = (d: d, key: key, chat: chat);
    _fetching = mine;
    if (waiting) fileWaitFetching(f.uid, true);
    final watch = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final p = engine.fileProgress(key);
      if (p == null || quiet) return;
      if (waiting) {
        fileWaitShare(f.uid, p.$1 / p.$2);
      } else {
        incomingMediaUpdate(
          chat,
          p.$1 * frame.chunks ~/ p.$2,
          frame.chunks,
          uid: f.uid,
          bytes: frame.size,
        );
      }
    });
    final t0 = DateTime.now();
    desk_trace.trace('media fetch start');
    var r = '';
    try {
      return r = await engine.fileFetch(frame.fetchJob(f.path));
    } catch (e) {
      return r = 'error: ${e.runtimeType}';
    } finally {
      final took = DateTime.now().difference(t0).inMilliseconds / 1000;
      desk_trace.trace(
        r == 'ok'
            ? 'media fetch ok +${took.toStringAsFixed(1)}s'
            : 'media fetch failed: ${traceCode(r)} '
                  '+${took.toStringAsFixed(1)}s',
      );
      watch.cancel();
      if (waiting) fileWaitFetching(f.uid, false);
      if (identical(_fetching, mine)) _fetching = null;
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
      // denied: this phone's token is not one the file names (a member
      // added after it went up). nothing to say then, now or later
      if (r != 'ok' && r != 'error: denied') {
        dlog('files: got not said ($r)');
        await fetchState(db, f.uid, kFetchFiled);
        await fetchTried(db, f.uid, f.tries + 1, now);
        return;
      }
    }
    await dropFetchRow(db, f.uid);
  }
}
