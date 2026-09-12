// SPDX-License-Identifier: GPL-3.0-or-later
// media_send.dart - the one chunked sender for photos, files and voice
// notes to a single peer. the chat screen calls it live; the outbox drainer
// calls it for a media row that never finished, so a photo left at 98% goes
// out when the route is back, chat open or not.
//
// a slice that landed is remembered here, so a retry sends only what is
// missing. photos had their own copy of this loop with no memory, and a
// retry started the whole file over.
//
// the pair address is a drop box the peer only reads once they have added
// us back. publishing there before that is not delivery, so it comes back
// as 'parked' rather than 'ok', and the row stays queued.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'dlog.dart';
import 'main.dart' show appState, engine, signalEncryptSerial;
import 'media_progress.dart';
import 'message_envelope.dart';
import 'signal_session.dart';

// msgUid -> slices the peer has. dropped when the file is across, or when
// the record is old enough that the peer may have restarted without it
final Map<String, Set<int>> chunkDone = {};
final Map<String, int> chunkDoneAt = {};
// one send per media at a time. the chat's retry and the outbox could
// both pick the same row, and whichever finished second overwrote the
// bubble with its own verdict.
final Set<String> mediaInflight = {};

int _mediaGrind(String seed) => grindPow(seed, powBits);

const mediaChunkSize = 16 * 1024;

// the progress entry ends with the send whatever way it ends, so a banner
// never outlives a transfer the drainer gave up on
Future<String> sendChunkedMediaTo({
  required String peerId,
  required String peerOnion,
  String? peerXPub,
  required bool backPaired,
  required bool needPow,
  required String b64,
  required String msgUid,
  String caption = '',
  String? fileName,
  bool voice = false,
  bool voiceDisguised = false,
  int? burnSeconds,
  bool secure = false,
  required SenderInfo sender,
}) async {
  if (!mediaInflight.add(msgUid)) return 'busy';
  try {
    return await _sendChunkedMediaInner(
      peerId: peerId,
      peerOnion: peerOnion,
      peerXPub: peerXPub,
      backPaired: backPaired,
      needPow: needPow,
      b64: b64,
      msgUid: msgUid,
      caption: caption,
      fileName: fileName,
      voice: voice,
      voiceDisguised: voiceDisguised,
      burnSeconds: burnSeconds,
      secure: secure,
      sender: sender,
    );
  } finally {
    mediaInflight.remove(msgUid);
    mediaProgressEnd(msgUid);
  }
}

Future<String> _sendChunkedMediaInner({
  required String peerId,
  required String peerOnion,
  String? peerXPub,
  required bool backPaired,
  // a stranger's gate wants pow on every envelope until they answer
  required bool needPow,
  required String b64,
  required String msgUid,
  String caption = '',
  String? fileName,
  bool voice = false,
  bool voiceDisguised = false,
  int? burnSeconds,
  bool secure = false,
  required SenderInfo sender,
}) async {
  var torWait = 0;
  while (!appState.torReady && torWait < 300000) {
    await Future.delayed(const Duration(milliseconds: 400));
    torWait += 400;
  }
  if (!appState.torReady) return 'error: tor not ready';
  final chunks = <String>[];
  for (var i = 0; i < b64.length; i += mediaChunkSize) {
    chunks.add(b64.substring(i, math.min(i + mediaChunkSize, b64.length)));
  }
  final total = chunks.length;
  // a voice note is a couple of seconds of audio. the strip is for photos
  // and files, where the wait is long enough to wonder about.
  final showProgress = total > 1 && !voice;
  if (showProgress) mediaProgressStart(msgUid, chatKey: peerId);
  int? pow;
  if (needPow) pow = await compute(_mediaGrind, caption);
  final now = DateTime.now().millisecondsSinceEpoch;
  final since = now - (chunkDoneAt[msgUid] ?? now);
  if (since > 240000) chunkDone.remove(msgUid);
  chunkDoneAt[msgUid] = now;
  final done = chunkDone.putIfAbsent(msgUid, () => <int>{});
  if (done.isNotEmpty && total > 1) {
    dlog('MEDIA resume $msgUid: ${done.length}/$total already landed');
    if (showProgress) mediaProgressUpdate(msgUid, done.length / total);
  }
  var xpub = peerXPub == null || peerXPub.isEmpty ? null : peerXPub;
  // five slices in flight. tor is latency-bound here, so the gain is close
  // to linear up to about this many streams; past it public relays start
  // refusing. encryption stays serial per peer behind signalEncryptSerial.
  const parallel = 5;
  // once the onion fails to answer it stays skipped for the rest of this
  // send. every slice paying the full dial timeout before the relay was
  // twelve minutes on a fifty-slice photo.
  var onionDead = false;
  String? failure;
  var parked = false;
  var next = 0;

  Future<void> worker() async {
    while (failure == null && !parked) {
      while (next < total && done.contains(next)) {
        next++;
      }
      if (next >= total) return;
      final i = next++;
      final t0 = DateTime.now();
      final String cipher;
      try {
        // name + voice flags ride every slice: the receiver rebuilds off
        // whichever chunk lands last, and that one decides file vs image.
        // the burn too, or a ghost photo never expired on their side.
        final wrapped = await wrapMessage(
          caption,
          msgUid: msgUid,
          imageB64: fileName == null ? chunks[i] : null,
          fileB64: fileName != null ? chunks[i] : null,
          fileName: fileName,
          voice: voice,
          voiceDisguised: voiceDisguised,
          mediaId: total > 1 ? msgUid : null,
          chunkIndex: total > 1 ? i : null,
          chunkTotal: total > 1 ? total : null,
          burnSeconds: burnSeconds,
          secure: secure,
          powNonce: pow,
          powBitsUsed: pow == null ? null : powBits,
          supporterBadge: await appState.sharedBadge(),
          sender: sender,
        );
        cipher = await signalEncryptSerial(peerId, wrapped);
      } catch (e) {
        failure = 'error: encrypt';
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
        dlog('MEDIA chunk $i/$total failed after ${ms}ms: $lastErr');
        // keep what landed so the next go resumes from here
        failure = lastErr;
        return;
      }
      done.add(i);
      chunkDoneAt[msgUid] = DateTime.now().millisecondsSinceEpoch;
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
  chunkDone.remove(msgUid);
  chunkDoneAt.remove(msgUid);
  return 'ok';
}
