// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: profile photos. yours, the ones you set for contacts, theirs,
// and what goes to whom (profile_photo.dart)

part of '../main.dart';

// what the photo sends keep in memory, per app
class _PhotoPace {
  Timer? run;
  // a photo that came whole inside the gap is looked at again after it
  Timer? waits;
  Future<void>? going;
  // the session the book was last read for
  Session? shown;
  final rnd = Random.secure();
}

final _photoPaces = Expando<_PhotoPace>();

extension AppStatePhotos on AppState {
  _PhotoPace get _photoPace => _photoPaces[this] ??= _PhotoPace();

  /// the session's own photo, as its profile shows it: the decoy's in a
  /// decoy, never the everyday one there
  Future<Uint8List?> myPhotoNow() async =>
      (await session.primary.myPhoto())?.photo;

  /// the book read again for the session on screen
  Future<void> reloadPhotos() async {
    final s = session;
    final id = sessionId;
    _photoPace.shown = s;
    final book = await _photoBookOf(s, id);
    if (book == null || !identical(s, _session)) return;
    photoBook.put(book);
  }

  // what [s] shows: its contacts', the open vault's, and its own photo
  // under [me]. the dev chat keeps its mark. null when its rows will not
  // read
  Future<Map<String, Uint8List>?> _photoBookOf(Session s, String me) async {
    final book = <String, Uint8List>{};
    try {
      for (final d in [s.primary, ?s.vault]) {
        book.addAll(await d.contactPhotos());
      }
      book.removeWhere((id, _) => isDevId(id));
      final mine = (await s.primary.myPhoto())?.photo;
      if (mine != null && me.isNotEmpty) book[me] = mine;
    } catch (e) {
      dlog('photo: book not read (${e.runtimeType})');
      return null;
    }
    return book;
  }

  // a chat's screenshot block moved: blocking, its photo goes before the
  // next frame and the face shows; lifted, the book is read again
  void _photoShotsMoved(String peer, {required bool blocking}) {
    if (blocking && photoBook.has(peer)) {
      photoBook.put({
        for (final MapEntry(:key, :value) in photoBook.all.entries)
          if (key != peer) key: value,
      });
    }
    unawaited(
      reloadPhotos().catchError((Object e) {
        dlog('photo: book not read (${e.runtimeType})');
      }),
    );
  }

  // the list was read for another session than the book was
  // a vault opened or a decoy left: what its contacts are owed is looked at
  void _photosFollow(Session s) {
    if (identical(s, _photoPace.shown)) return;
    unawaited(
      reloadPhotos().catchError((Object e) {
        dlog('photo: book not read (${e.runtimeType})');
      }),
    );
    unawaited(photoSweep());
  }

  /// [picked] as your photo: kept only when it reads clean. in a decoy it
  /// stays in the decoy's own rows and never leaves
  Future<bool> setMyPhoto(Uint8List picked) async {
    if (sessionQuiet && !decoyOwnPhoto) return false;
    final fit = await Isolate.run(() => photoFit(picked));
    if (fit == null) return false;
    await session.primary.putMyPhoto(
      DateTime.now().millisecondsSinceEpoch,
      fit,
    );
    await reloadPhotos();
    unawaited(photoSweep());
    return true;
  }

  /// your face again: every contact that holds the photo gets a take-back
  Future<void> removeMyPhoto() async {
    await session.primary.putMyPhoto(
      DateTime.now().millisecondsSinceEpoch,
      null,
    );
    await reloadPhotos();
    unawaited(photoSweep());
  }

  /// the photo you set for [id], on this phone only, in the container that
  /// holds their chat. null takes it off. true when it was kept
  Future<bool> setContactPhoto(String id, Uint8List? picked) async {
    if (isDevId(id)) return false;
    Uint8List? fit;
    if (picked != null) {
      fit = await Isolate.run(() => photoFit(picked));
      if (fit == null) return false;
    }
    final kept = await session.draftsOf(id).setMinePhoto(id, fit);
    await reloadPhotos();
    return kept;
  }

  /// what is kept for [id] where their chat is. rows that will not read
  /// cost only the photos: none, and the page goes on
  Future<({Uint8List? mine, Uint8List? theirs, int theirVer})> photosOfContact(
    String id,
  ) async {
    try {
      return await session.draftsOf(id).photosOf(id);
    } catch (e) {
      dlog('photo: not read (${e.runtimeType})');
      return (mine: null, theirs: null, theirVer: 0);
    }
  }

  // ---- in ----

  // a photo frame from [sender]: a slice or a take-back, 1:1 only, from an
  // accepted contact. a decoy takes none in, and the dev chat none at all
  Future<void> _takePhoto(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    final f = env.photo;
    if (f == null || env.groupId != null || isDevId(sender)) return;
    if (db.container.quiet) return;
    try {
      if (!await db.isAccepted(sender)) return;
      final moved = f.drop
          ? await db.takePhotoDrop(sender, f.version)
          : await db.takePhotoSlice(sender, f);
      if (!moved) {
        if (!f.drop) _photoWaitArm();
        return;
      }
      // only the book of a session that shows this container
      final s = session;
      if (identical(s.primary, db) || identical(s.vault, db)) {
        await reloadPhotos();
      }
    } catch (e) {
      dlog('photo: not taken (${e.runtimeType})');
    }
  }

  // ---- out ----

  // the containers whose contacts get the everyday photo: the everyday one
  // and the open vault. a decoy's never
  List<HaloDb> get _photoHomes => [
    if (!live.container.quiet) live,
    if (_openVault?.container.quiet == false) _openVault!,
  ];

  bool get _photoHeld => everydayHeld || haloWiping;

  // a photo held back by the gap goes in once it has passed
  void _photoWaitArm() {
    final p = _photoPace;
    if (p.waits != null) return;
    p.waits = Timer(kPhotoTakeGap + const Duration(seconds: 5), () {
      p.waits = null;
      unawaited(photoTakeWaiting());
    });
  }

  /// photos held back by the gap, taken in where it has passed
  @visibleForTesting
  Future<void> photoTakeWaiting() async {
    if (_photoHeld) return;
    var moved = false;
    for (final d in _photoHomes) {
      try {
        if (await d.takeWaitingPhotos()) moved = true;
      } catch (e) {
        dlog('photo: waiting not taken (${e.runtimeType})');
      }
    }
    if (moved) await reloadPhotos();
  }

  /// what each contact should hold of ours worked out again, and owed
  /// where it is not what they hold. a new owe goes at a random time a
  /// few minutes out, so a change is no burst
  Future<void> photoSweep() async {
    if (_photoHeld) return;
    try {
      final me = await live.myPhoto();
      final mine = me?.photo == null ? 0 : me!.ver;
      final now = DateTime.now().millisecondsSinceEpoch;
      unawaited(photoTakeWaiting());
      for (final d in _photoHomes) {
        await d.dropStalePhotoParts(now: now);
        for (final (:facts, :peer) in await d.photoPeople()) {
          final want = photoTarget(
            sent: peer.held,
            mine: mine,
            owed: photoOwedTo(facts),
          );
          if (want == peer.want) continue;
          await d.owePhoto(
            peer.id,
            want,
            at: want == null ? 0 : photoFirstAt(now, _photoPace.rnd),
          );
        }
      }
    } catch (e) {
      dlog('photo: not swept (${e.runtimeType})');
    }
    await _photoArm();
  }

  // the next send armed for the soonest one due
  Future<void> _photoArm() async {
    final p = _photoPace;
    p.run?.cancel();
    p.run = null;
    if (_photoHeld) return;
    int? soonest;
    for (final d in _photoHomes) {
      try {
        final at = await d.nextPhotoDue();
        if (at != null && (soonest == null || at < soonest)) soonest = at;
      } catch (e) {
        dlog('photo: next not read (${e.runtimeType})');
      }
    }
    if (soonest == null) return;
    final wait = max(0, soonest - DateTime.now().millisecondsSinceEpoch);
    p.run = Timer(Duration(milliseconds: wait), () {
      p.run = null;
      unawaited(photoSendDue());
    });
  }

  /// what is due goes now, one contact at a time
  @visibleForTesting
  Future<void> photoSendDue() async {
    final p = _photoPace;
    final before = p.going;
    if (before != null) return before;
    final run = p.going = _photoSendDueNow();
    try {
      await run;
    } finally {
      if (identical(p.going, run)) p.going = null;
    }
    await _photoArm();
  }

  Future<void> _photoSendDueNow() async {
    for (final d in _photoHomes) {
      final List<PhotoPeer> due;
      try {
        due = await d.duePhotoPeers(DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        dlog('photo: due not read (${e.runtimeType})');
        continue;
      }
      for (final peer in due) {
        if (_photoHeld) return;
        final want = peer.want;
        if (want == null) continue;
        bool ok;
        try {
          ok = await _sendPhotoTo(peer.id, want, peer.stamp);
        } catch (e) {
          dlog('photo: not sent (${e.runtimeType})');
          ok = false;
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        if (ok) {
          await d.photoSent(peer.id, want, peer.stamp);
        } else {
          await d.photoLater(
            peer.id,
            peer.stamp,
            photoRetryAt(now, peer.tries, _photoPace.rnd),
          );
        }
      }
    }
  }

  // our photo, or its take-back when [want] is 0, to [peer] under [stamp].
  // true when every slice went
  Future<bool> _sendPhotoTo(String peer, int want, int stamp) async {
    if (isDevId(peer) || _photoHeld) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final List<PhotoFrame> frames;
    if (want == 0) {
      frames = [PhotoFrame.drop(stamp)];
    } else {
      final me = await live.myPhoto();
      final photo = me?.photo;
      // changed since it was owed: the sweep owes the new one
      if (photo == null || me!.ver != want) {
        unawaited(photoSweep());
        return false;
      }
      frames = photoSlices(photo, stamp);
      if (frames.isEmpty) return false;
    }
    for (final f in frames) {
      // a wipe or a decoy begun meanwhile: not one more slice
      if (_photoHeld) return false;
      final wire = await shotsOnWire(peer, wrapPhotoFrame(f, writtenAt: now));
      final ok = await _sendOneEnvelope(peer, wire, takeBack: want == 0);
      if (!ok) return false;
    }
    return true;
  }

  /// the wipe began, or the app is going: nothing more goes
  void stopPhotos() {
    _photoPace.run?.cancel();
    _photoPace.run = null;
    _photoPace.waits?.cancel();
    _photoPace.waits = null;
    photoBook.clear();
  }
}
