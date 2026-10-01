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

import 'devchat/dev_start.dart' show devKeyFailed, kDevKeyFailed;
import 'dlog.dart';
import 'image_strip.dart' show cleanSavedPhoto;
import 'main.dart' show appState, engine, signalEncrypt;
import 'media_progress.dart';
import 'message_envelope.dart';
import 'signal_session.dart';

// msgUid -> slices the peer has. dropped when the file is across, or when
// the record is old enough that the peer may have restarted without it
final Map<String, Set<int>> chunkDone = {};
final Map<String, int> chunkDoneAt = {};
// one send per media at a time: the chat's retry and the outbox can pick
// the same row, and the second to finish would overwrite the bubble
final Set<String> mediaInflight = {};
// a send the person stopped. the workers see it between slices and end
// there; the chat has already pulled the row and told the other side.
final Set<String> mediaCancelled = {};
void cancelMediaSend(String msgUid) => mediaCancelled.add(msgUid);

final Map<String, List<Completer<void>>> _freeWaiters = {};

// a send lets go of its row, and whoever waits on that row hears it
void releaseMedia(String msgUid) {
  mediaInflight.remove(msgUid);
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
  required SenderInfo sender,
  // the receiver named the slices it lacks: send those and no others
  Set<int>? only,
  // the chat's key for the progress strip, its container's and its own
  required String progressKey,
}) async {
  if (!mediaInflight.add(msgUid)) return 'busy';
  try {
    return await _sendChunkedMediaInner(
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
      sender: sender,
      only: only,
      progressKey: progressKey,
    );
  } finally {
    mediaCancelled.remove(msgUid);
    mediaProgressEnd(msgUid);
    releaseMedia(msgUid);
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
  required SenderInfo sender,
  Set<int>? only,
  required String progressKey,
}) async {
  var torWait = 0;
  while (!appState.torReady && torWait < 300000) {
    await Future.delayed(const Duration(milliseconds: 400));
    torWait += 400;
  }
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
  final int total;
  try {
    total = await mediaSliceCount(path);
  } catch (e) {
    return 'error: read';
  }
  // a voice note is a couple of seconds of audio. the strip is for photos
  // and files, where the wait is long enough to wonder about.
  final showProgress = total > 1 && !voice && only == null;
  if (showProgress) mediaProgressStart(msgUid, chatKey: progressKey);
  int? pow;
  if (needPow) {
    powBusy.value = DateTime.now();
    try {
      pow = await compute(_mediaGrind, caption);
    } finally {
      powBusy.value = null;
    }
  }
  final now = DateTime.now().millisecondsSinceEpoch;
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
    dlog('MEDIA resume $msgUid: ${done.length}/$total already landed');
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
  String? failure;
  var parked = false;
  var next = 0;

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
    while (failure == null && !parked) {
      if (mediaCancelled.contains(msgUid)) {
        failure = 'cancelled';
        return;
      }
      final i = takeChunk();
      if (i == null) return;
      final t0 = DateTime.now();
      final String slice;
      try {
        slice = await mediaSlice(path, i);
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
          imageB64: fileName == null ? slice : null,
          fileB64: fileName != null ? slice : null,
          fileName: fileName,
          voice: voice,
          voiceDisguised: voiceDisguised,
          mediaId: total > 1 ? msgUid : null,
          chunkIndex: total > 1 ? i : null,
          chunkTotal: total > 1 ? total : null,
          burnSeconds: burnSeconds,
          secure: secure,
          replyTo: replyTo,
          powNonce: pow,
          powBitsUsed: pow == null ? null : powBits,
          supporterBadge: await appState.sharedBadge(),
          sender: sender,
          canResend: total > 1,
        );
        cipher = await signalEncrypt(peerId, wrapped);
      } catch (e) {
        failure = devKeyFailed(e) ? kDevKeyFailed : 'error: encrypt';
        return;
      }
      var sent = false;
      var route = '';
      String lastErr = 'error: no transport';
      for (var attempt = 0; attempt < 3 && !sent; attempt++) {
        if (!backPaired && peerOnion.isNotEmpty && !onionDead) {
          final tor = await engine.sendTo(peerOnion, cipher);
          if (tor == 'ok') {
            sent = true;
            route = 'onion';
            break;
          }
          lastErr = tor;
          onionDead = true;
          dlog('MEDIA onion gave up for this send: $tor');
        }
        xpub ??= await signalSession.peerXPubHex(peerId);
        if (xpub != null) {
          if (!backPaired) {
            // their first-contact address is the one relay route that
            // reaches them before they add us back
            final fc = appState.peerFcFor(peerId);
            if (fc != null && fc.isNotEmpty) {
              final fr = await engine.sendFirstContact(xpub!, fc, cipher);
              if (fr == 'ok') {
                sent = true;
                route = 'first-contact';
                break;
              }
              lastErr = fr;
            }
          }
          final r = await engine.nostrSend(xpub!, cipher);
          if (r == 'ok') {
            if (!backPaired) {
              // stored where nobody reads yet. the drainer brings the whole
              // file again once a route that reaches them is up.
              dlog('MEDIA chunk $i/$total parked at the pair address');
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
      if (!sent) {
        final pass = (attempts[i] ?? 0) + 1;
        attempts[i] = pass;
        dlog(
          'MEDIA chunk $i/$total failed after ${ms}ms, pass $pass: $lastErr',
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
      done.add(i);
      if (only == null) {
        chunkDoneAt[msgUid] = DateTime.now().millisecondsSinceEpoch;
      }
      // the line to read before touching the pool size or the chunk size
      dlog('MEDIA chunk $i/$total via $route in ${ms}ms');
      if (showProgress) mediaProgressUpdate(msgUid, done.length / total);
    }
  }

  await Future.wait([
    for (var w = 0; w < math.min(parallel, total); w++) worker(),
  ]);
  if (parked) return 'parked';
  if (failure != null) return failure!;
  if (only == null) {
    chunkDone.remove(msgUid);
    chunkDoneAt.remove(msgUid);
  }
  return 'ok';
}
