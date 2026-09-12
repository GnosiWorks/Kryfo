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
import 'main.dart' show appState, engine, signalEncrypt;
import 'media_progress.dart';
import 'message_envelope.dart';
import 'signal_session.dart';

// msgUid -> slices the peer has. dropped when the file is across, or when
// the record is old enough that the peer may have restarted without it
final Map<String, Set<int>> chunkDone = {};
final Map<String, int> chunkDoneAt = {};

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
  for (var i = 0; i < total; i++) {
    if (done.contains(i)) continue;
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
      cipher = await signalEncrypt(peerId, wrapped);
    } catch (e) {
      return 'error: encrypt';
    }
    var sent = false;
    String lastErr = 'error: no transport';
    for (var attempt = 0; attempt < 3 && !sent; attempt++) {
      if (!backPaired && peerOnion.isNotEmpty) {
        final tor = await Future(() => engine.sendTo(peerOnion, cipher));
        if (tor == 'ok') {
          sent = true;
          break;
        }
        lastErr = tor;
      }
      xpub ??= await signalSession.peerXPubHex(peerId);
      if (xpub != null) {
        if (!backPaired) {
          // their first-contact address is the one relay route that
          // reaches them before they add us back
          final fc = appState.peerFcFor(peerId);
          if (fc != null && fc.isNotEmpty) {
            final fr = await engine.sendFirstContact(xpub, fc, cipher);
            if (fr == 'ok') {
              sent = true;
              break;
            }
            lastErr = fr;
          }
        }
        final x = xpub;
        final r = await Future(() => engine.nostrSend(x, cipher));
        if (r == 'ok') {
          if (!backPaired) {
            // stored where nobody reads yet. the drainer brings the whole
            // file again once a route that reaches them is up.
            dlog('MEDIA CHUNK $i/$total parked at the pair address');
            return 'parked';
          }
          sent = true;
          break;
        }
        lastErr = r;
      }
      if (!sent) await Future.delayed(const Duration(milliseconds: 600));
    }
    if (!sent) {
      dlog('MEDIA CHUNK $i/$total failed: $lastErr');
      // keep what landed so the next go resumes from here
      return lastErr;
    }
    done.add(i);
    chunkDoneAt[msgUid] = DateTime.now().millisecondsSinceEpoch;
    if (showProgress) mediaProgressUpdate(msgUid, done.length / total);
  }
  chunkDone.remove(msgUid);
  chunkDoneAt.remove(msgUid);
  return 'ok';
}
