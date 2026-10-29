// SPDX-License-Identifier: GPL-3.0-or-later
// the one chunked sender for photos, files and voice notes to a single peer.
// the chat screen calls it live; the outbox drainer calls it for a media row
// that never finished. a slice that landed is remembered, so a retry sends
// only what is missing.
// the pair address is a drop box the peer only reads once they add us back,
// so publishing there comes back as 'parked', not 'ok', and the row stays
// queued.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'album.dart' show AlbumTag;
import 'devchat/dev_start.dart' show devKeyFailed, kDevKeyFailed;
import 'dlog.dart';
import 'image_strip.dart' show cleanSavedPhoto;
import 'main.dart'
    show
        appState,
        engine,
        signalEncrypt,
        peerXPubOf,
        AppStateDoor,
        AppStateOutbox,
        AppStateRoute,
        AppStateProfile,
        AppStateContacts,
        AppStateFiles,
        AppStateRefresh;
import 'file_drop.dart' show DropFrame, dropFits, dropFallsBack, kOldFileBytes;
import 'media_progress.dart';
import 'media_resend.dart' show kMaxFileSlices;
import 'message_envelope.dart';
import 'signal_session.dart';
import 'text_send.dart' show kSendBlocked;

// msgUid -> slices the peer has. dropped when the file is across, or when
// the record is old enough that the peer may have restarted without it
final Map<String, Set<int>> chunkDone = {};
final Map<String, int> chunkDoneAt = {};
// one send per media at a time: the chat's retry and the outbox can pick
// the same row, and the second to finish would overwrite the bubble
final Set<String> mediaInflight = {};
// bumped as a send takes or lets go of a row, so a chat drawing that row
// follows a send it did not start: the outbox's, or a screen's left since
final ValueNotifier<int> mediaSendsTick = ValueNotifier(0);
// a send the person stopped. the workers see it between slices and end
// there; the chat has already pulled the row and told the other side.
// the mark stays, so no later pass sends a row that is being taken back
final Set<String> mediaCancelled = {};
void cancelMediaSend(String msgUid) {
  mediaCancelled.add(msgUid);
  if (mediaCancelled.length > 500) mediaCancelled.remove(mediaCancelled.first);
}

// a send with no slice taken for this long has stopped moving. a 16k slice
// is about 2 s a round over tor and up to 20 s on a slow bridge, and five
// are in flight, so a moving send is heard from many times inside it. one
// slice's own three tries, the onion's 15 s and three relay timeouts of
// 60 s, come to about 197 s, and five slices on one dying circuit fail
// together, so the bound sits above that. past it the send ends as
// stalled, lets go of the row, and the outbox goes on from what landed
// the group sender shares it. tests shorten it
Duration mediaStallAfter = const Duration(minutes: 4);
const kMediaStalled = 'error: stalled';
// the watch looks this many times inside the bound. a phone asleep runs no
// looks, so a frozen process is not read as a stalled send
const kMediaStallLooks = 24;

final Map<String, List<Completer<void>>> _freeWaiters = {};

// a send lets go of its row, and whoever waits on that row hears it
void releaseMedia(String msgUid) {
  if (mediaInflight.remove(msgUid)) mediaSendsTick.value++;
  final waiting = _freeWaiters.remove(msgUid);
  if (waiting == null) return;
  for (final c in waiting) {
    c.complete();
  }
}

/// done once no send holds [msgUid]; at once when none does
Future<void> whenMediaFree(String msgUid) {
  if (!mediaInflight.contains(msgUid)) return Future.value();
  final c = Completer<void>();
  _freeWaiters.putIfAbsent(msgUid, () => []).add(c);
  return c.future;
}

int _mediaGrind(String seed) => grindPow(seed, powBits);

// base64 characters per slice on the wire. 12288 bytes of file make
// exactly 16384 characters, so slicing the file and slicing its base64
// give the same pieces. a slice is read from disk when its turn comes, so
// a big file is never held whole in memory.
const mediaChunkSize = 16 * 1024;
const _sliceBytes = mediaChunkSize ~/ 4 * 3;

Future<int> mediaSliceCount(String path) async {
  final n = await File(path).length();
  return (n + _sliceBytes - 1) ~/ _sliceBytes;
}

Future<String> mediaSlice(String path, int i) async {
  final start = i * _sliceBytes;
  final b = BytesBuilder(copy: false);
  await for (final part in File(path).openRead(start, start + _sliceBytes)) {
    b.add(part);
  }
  return base64Encode(b.takeBytes());
}

// the progress entry ends with the send whatever way it ends, so a banner
// never outlives a transfer the drainer gave up on
Future<String> sendChunkedMediaTo({
  required String peerId,
  required String peerOnion,
  String? peerXPub,
  required bool backPaired,
  required bool needPow,
  // the file as saved in the app's media folder. read slice by slice.
  required String path,
  required String msgUid,
  String caption = '',
  String? fileName,
  bool voice = false,
  bool voiceDisguised = false,
  int? burnSeconds,
  bool secure = false,
  // the message this one answers, on every slice like the name
  String? replyTo,
  // its place in an album, on every slice too
  AlbumTag? album,
  // when its row was written, on every slice too. now when not given
  int? writtenAt,
  required SenderInfo sender,
  // the receiver named the slices it lacks: send those and no others
  Set<int>? only,
  // the chat's key for the progress strip, its container's and its own
  required String progressKey,
  // the sending container blocks them: a block in the other one only
  // holds the file back
  Future<bool> Function()? blockedHere,
}) async {
  if (mediaCancelled.contains(msgUid)) return 'cancelled';
  if (!mediaInflight.add(msgUid)) return 'busy';
  mediaSendsTick.value++;
  var res = '';
  try {
    return res = await _sendChunkedMediaInner(
      peerId: peerId,
      peerOnion: peerOnion,
      peerXPub: peerXPub,
      backPaired: backPaired,
      needPow: needPow,
      path: path,
      msgUid: msgUid,
      caption: caption,
      fileName: fileName,
      voice: voice,
      voiceDisguised: voiceDisguised,
      burnSeconds: burnSeconds,
      secure: secure,
      replyTo: replyTo,
      album: album,
      writtenAt: writtenAt,
      sender: sender,
      only: only,
      progressKey: progressKey,
      blockedHere: blockedHere,
    );
  } finally {
    mediaProgressEnd(msgUid);
    releaseMedia(msgUid);
    // the outbox has the row now, and goes on from what landed
    if (res == kMediaStalled) unawaited(appState.drainOutbox());
  }
}

Future<String> _sendChunkedMediaInner({
  required String peerId,
  required String peerOnion,
  String? peerXPub,
  required bool backPaired,
  // a stranger's gate wants pow on every envelope until they answer
  required bool needPow,
  required String path,
  required String msgUid,
  String caption = '',
  String? fileName,
  bool voice = false,
  bool voiceDisguised = false,
  int? burnSeconds,
  bool secure = false,
  String? replyTo,
  AlbumTag? album,
  int? writtenAt,
  required SenderInfo sender,
  Set<int>? only,
  required String progressKey,
  Future<bool> Function()? blockedHere,
}) async {
  var torWait = 0;
  while (!appState.torReady && torWait < 300000) {
    // a stop while tor is down lets go of the row at once
    if (mediaCancelled.contains(msgUid)) return 'cancelled';
    await Future.delayed(const Duration(milliseconds: 400));
    torWait += 400;
  }
  if (mediaCancelled.contains(msgUid)) return 'cancelled';
  if (!appState.torReady) return 'error: tor not ready';
  // a photo is cleaned on every send, retries and the outbox included
  if (fileName == null && !voice) {
    final cleaned = await cleanSavedPhoto(path);
    if (cleaned == null) return 'error: not clean';
    if (cleaned) {
      // the slices out so far were of other bytes
      chunkDone.remove(msgUid);
      if (only != null) return 'error: changed';
    }
  }
  int total;
  try {
    total = await mediaSliceCount(path);
  } catch (e) {
    return 'error: read';
  }
  // an empty file has nothing to send, and is not a send that went
  if (total == 0) return 'error: empty';
  // more than a slice to a phone that fetches from the files service: the
  // file goes up there once and one frame goes in place of the slices.
  // one the service has no room for goes as slices while the relay takes it
  DropFrame? drop;
  if (total > 1 && only == null && await appState.dropsFor(peerId)) {
    final bytes = await File(path).length();
    if (dropFits(bytes)) {
      mediaProgressStart(msgUid, chatKey: progressKey, bytes: bytes);
      final (sent, r) = await appState.sendDrop(
        path: path,
        uid: msgUid,
        members: [peerId],
      );
      if (mediaCancelled.contains(msgUid) || r == 'error: cancelled') {
        return 'cancelled';
      }
      if (sent != null) {
        drop = sent.frameFor(peerId);
        total = 1;
      } else if (dropFallsBack(r) && bytes <= kOldFileBytes) {
        dlog('media $msgUid: the files service said $r, going as slices');
      } else {
        return 'error: drop ${r.replaceFirst('error: ', '')}';
      }
    }
  }
  // a phone that takes slices only takes so many of a file: past that it
  // would drop every one
  if (drop == null && fileName != null && !voice && total > kMaxFileSlices) {
    return 'error: big';
  }
  // a voice note as well: a long one is a megabyte and more of wav
  final showProgress = total > 1 && only == null;
  if (showProgress) {
    mediaProgressStart(
      msgUid,
      chatKey: progressKey,
      bytes: drop?.size ?? total * _sliceBytes,
    );
  }
  int? pow;
  if (needPow) {
    pow = await compute(_mediaGrind, caption);
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  final written = writtenAt ?? now;
  final Set<int> done;
  if (only != null) {
    // its own record: everything counts as landed but what was asked for,
    // and none of it is kept for a later full send to trust
    done = {
      for (var i = 0; i < total; i++)
        if (!only.contains(i)) i,
    };
  } else {
    final since = now - (chunkDoneAt[msgUid] ?? now);
    if (since > 240000) chunkDone.remove(msgUid);
    chunkDoneAt[msgUid] = now;
    done = chunkDone.putIfAbsent(msgUid, () => <int>{});
  }
  if (done.isNotEmpty && total > 1 && only == null) {
    dlog('media resume $msgUid: ${done.length}/$total already landed');
    if (showProgress) mediaProgressUpdate(msgUid, done.length / total);
  }
  var xpub = peerXPub == null || peerXPub.isEmpty ? null : peerXPub;
  // five slices in flight. tor is latency-bound here, so the gain is close
  // to linear up to about this many streams; past it public relays start
  // refusing. encryption stays serial per peer inside signalEncrypt.
  const parallel = 5;
  // once the onion fails to answer it stays skipped for the rest of this
  // send, or every slice pays the full dial timeout before the relay
  var onionDead = false;
  // they read our pair address before adding us back, asked once
  bool? pairWay;
  String? failure;
  var parked = false;
  // parked by a decoy opening, not by a route
  var held = false;
  var blocked = false;
  var next = 0;
  // the watch ended it: a worker still waiting on its slice touches nothing
  // of the next send's
  var ended = false;
  var quiet = 0;

  // a chunk that will not go through costs that chunk, not the transfer: it
  // goes back in the queue for another pass, with a pause between passes
  // since a wedged circuit needs longer than the gap between dials. the send
  // gives up only when one slice has burned every pass. cancelled, parked
  // and a file gone from disk still stop everything at once.
  const chunkPasses = 4;
  final attempts = <int, int>{};
  final retryQueue = <int>[];

  int? takeChunk() {
    if (retryQueue.isNotEmpty) return retryQueue.removeAt(0);
    while (next < total && done.contains(next)) {
      next++;
    }
    if (next >= total) return null;
    return next++;
  }

  Future<void> worker() async {
    while (failure == null && !parked && !blocked) {
      if (mediaCancelled.contains(msgUid)) {
        failure = 'cancelled';
        return;
      }
      // a decoy opened part way: the rest waits with the row
      if (appState.everydayHeld) {
        parked = true;
        held = true;
        return;
      }
      // blocked part way, here: the rest is not sent, and waits for a tap.
      // blocked in the other container: it waits with the row
      if (await appState.blockedAnywhere(peerId)) {
        if (blockedHere != null && await blockedHere()) {
          blocked = true;
        } else {
          parked = true;
        }
        return;
      }
      final i = takeChunk();
      if (i == null) return;
      final t0 = DateTime.now();
      final String slice;
      try {
        slice = drop != null ? '' : await mediaSlice(path, i);
      } catch (e) {
        // the file went: a wipe, a burn, a full phone that lost it
        failure = 'error: read';
        return;
      }
      final String cipher;
      try {
        // name + voice flags ride every slice: the receiver rebuilds off
        // whichever chunk lands last, and that one decides file vs image.
        // the burn too, or a ghost photo would never expire on their side.
        final wrapped = await wrapMessage(
          caption,
          msgUid: msgUid,
          imageB64: drop == null && fileName == null ? slice : null,
          fileB64: drop == null && fileName != null ? slice : null,
          drop: drop,
          fileName: fileName,
          voice: voice,
          voiceDisguised: voiceDisguised,
          mediaId: total > 1 ? msgUid : null,
          chunkIndex: total > 1 ? i : null,
          chunkTotal: total > 1 ? total : null,
          burnSeconds: burnSeconds,
          secure: secure,
          replyTo: replyTo,
          album: album,
          powNonce: pow,
          powBitsUsed: pow == null ? null : powBits,
          supporterBadge: await appState.sharedBadge(),
          sender: sender,
          canResend: total > 1,
          writtenAt: written,
        );
        cipher = await signalEncrypt(peerId, wrapped);
      } on KeyHeld {
        // waits on a check of their new number: going, not failed
        parked = true;
        return;
      } on StartingAfresh {
        parked = true;
        return;
      } catch (e) {
        failure = devKeyFailed(e) ? kDevKeyFailed : 'error: encrypt';
        return;
      }
      var sent = false;
      var route = '';
      String lastErr = 'error: no transport';
      // once the watch ended the send, a slice that failed is not tried
      // again: the next send has the row
      for (var attempt = 0; attempt < 3 && !sent && !ended; attempt++) {
        if (!backPaired && peerOnion.isNotEmpty && !onionDead) {
          final tor = await engine.sendTo(peerOnion, cipher);
          if (tor == 'ok') {
            sent = true;
            route = 'onion';
            // their door holds it in memory only: the first-contact copy
            // goes too until they add us back, behind the slice's ok
            final fc = appState.peerFcFor(peerId);
            xpub ??= await peerXPubOf(peerId);
            if (fc != null && fc.isNotEmpty && xpub != null) {
              unawaited(
                engine
                    .sendFirstContact(
                      appState.identOf(peerId),
                      xpub!,
                      fc,
                      cipher,
                    )
                    .then(
                      (f) {
                        if (f != 'ok') {
                          dlog('media first-contact copy did not go: $f');
                        }
                      },
                      onError: (Object e) =>
                          dlog('media first-contact copy did not go: $e'),
                    ),
              );
            }
            break;
          }
          lastErr = tor;
          onionDead = true;
          dlog('media onion gave up for this send: $tor');
        }
        xpub ??= await peerXPubOf(peerId);
        // their first-contact address is the one relay route that reaches
        // them before they add us back, and the pair address is not
        // written beside it
        final fc = backPaired ? null : appState.peerFcFor(peerId);
        if (xpub != null && fc != null && fc.isNotEmpty) {
          final fr = await engine.sendFirstContact(
            appState.identOf(peerId),
            xpub!,
            fc,
            cipher,
          );
          if (fr == 'ok') {
            sent = true;
            route = 'first-contact';
            break;
          }
          lastErr = fr;
        } else if (xpub != null) {
          final r = await engine.nostrSend(
            appState.identOf(peerId),
            xpub!,
            cipher,
          );
          if (r == 'ok') {
            pairWay ??= await appState.pairRead(peerId, backPaired: backPaired);
            if (!backPaired && !pairWay!) {
              // stored where nobody reads yet. the drainer brings the whole
              // file again once a route that reaches them is up.
              dlog('media chunk $i/$total parked at the pair address');
              parked = true;
              return;
            }
            sent = true;
            route = 'relay';
            break;
          }
          lastErr = r;
        }
        if (!sent) await Future.delayed(const Duration(milliseconds: 600));
      }
      final ms = DateTime.now().difference(t0).inMilliseconds;
      if (!sent && ended) return;
      if (!sent) {
        final pass = (attempts[i] ?? 0) + 1;
        attempts[i] = pass;
        dlog(
          'media chunk $i/$total failed after ${ms}ms, pass $pass: $lastErr',
        );
        if (pass >= chunkPasses) {
          // this one is not going through. keep what landed so the next
          // go resumes from here rather than starting over.
          failure = lastErr;
          return;
        }
        retryQueue.add(i);
        await Future.delayed(Duration(seconds: 2 * pass));
        continue;
      }
      // a slice that landed is kept even after the watch, for the next go
      done.add(i);
      if (ended) return;
      quiet = 0;
      if (only == null) {
        chunkDoneAt[msgUid] = DateTime.now().millisecondsSinceEpoch;
      }
      // the line to read before touching the pool size or the chunk size
      dlog('media chunk $i/$total via $route in ${ms}ms');
      if (showProgress) mediaProgressUpdate(msgUid, done.length / total);
    }
  }

  final stop = Completer<void>();
  final watch = Timer.periodic(mediaStallAfter ~/ kMediaStallLooks, (_) {
    // a stop asked while a slice hangs ends it now, not at the next slice
    if (mediaCancelled.contains(msgUid)) {
      failure ??= 'cancelled';
    } else if (++quiet >= kMediaStallLooks) {
      dlog('media $msgUid: no slice taken in ${mediaStallAfter.inSeconds}s');
      failure ??= kMediaStalled;
    } else {
      return;
    }
    if (!stop.isCompleted) stop.complete();
  });
  try {
    await Future.any([
      Future.wait([
        for (var w = 0; w < math.min(parallel, total); w++) worker(),
      ]),
      stop.future,
    ]);
  } finally {
    watch.cancel();
    ended = true;
  }
  if (failure == 'cancelled') {
    chunkDone.remove(msgUid);
    chunkDoneAt.remove(msgUid);
    return 'cancelled';
  }
  if (blocked) return kSendBlocked;
  // what landed before a hold is kept however long it lasts: unstamped,
  // the next send resumes from it
  if ((held || failure == kMediaStalled) && only == null) {
    chunkDoneAt.remove(msgUid);
  }
  if (parked) return 'parked';
  if (failure != null) return failure!;
  if (only == null) {
    chunkDone.remove(msgUid);
    chunkDoneAt.remove(msgUid);
  }
  return 'ok';
}
