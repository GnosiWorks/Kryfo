// SPDX-License-Identifier: GPL-3.0-or-later
// live progress for chunked media, both directions.
//
// an 8mb file is ~680 sequential 16k chunks over tor - 20+ minutes. without
// feedback that reads as "broken" on BOTH ends: the sender's bubble now
// shows a percentage, and the receiver gets a slim banner above the
// composer while chunks stream in.
//
// design: plain maps + ONE global tick notifier. widgets sit in the tree
// permanently, listen to the tick, and show/hide themselves - so it does
// not matter whether the widget or the progress entry is created first
// (that ordering race is exactly why v1's labels never appeared).
import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// outgoing: msgUid -> 0..1
final Map<String, double> mediaSendProgress = {};

/// incoming: chat key (groupId or peer haloId) -> 0..1
final Map<String, double> incomingMediaProgress = {};
final Map<String, int> _incomingTouch = {};
// chat key -> (have, total), and the transfers that went quiet. the slices
// stay on disk for a week, so a quiet transfer is paused, not lost: the
// banner says so instead of vanishing at 98%.
final Map<String, (int, int)> _incomingCount = {};
final Set<String> incomingMediaStalled = {};

/// which chat an outgoing send belongs to (msgUid -> chatKey), so the
/// banner can show sender-side progress too.
final Map<String, String> _sendChat = {};

final ValueNotifier<int> mediaProgressTick = ValueNotifier(0);
Timer? _sweeper;

void _bump() => mediaProgressTick.value++;

// a transfer quiet for 75s is shown as paused; one quiet for a day is
// dropped from the banner (its slices are swept from the db separately).
void _ensureSweeper() {
  _sweeper ??= Timer.periodic(const Duration(seconds: 15), (_) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final e in _incomingTouch.entries.toList()) {
      final quiet = now - e.value;
      if (quiet > 86400000) {
        incomingMediaProgress.remove(e.key);
        _incomingTouch.remove(e.key);
        _incomingCount.remove(e.key);
        incomingMediaStalled.remove(e.key);
        changed = true;
      } else if (quiet > 75000 && incomingMediaStalled.add(e.key)) {
        changed = true;
      }
    }
    if (changed) _bump();
  });
}

void mediaProgressStart(String msgUid, {String? chatKey}) {
  mediaSendProgress.putIfAbsent(msgUid, () => 0);
  if (chatKey != null) _sendChat[msgUid] = chatKey;
  _bump();
}

void mediaProgressUpdate(String msgUid, double v) {
  mediaSendProgress[msgUid] = v;
  _bump();
}

void mediaProgressEnd(String msgUid) {
  _sendChat.remove(msgUid);
  if (mediaSendProgress.remove(msgUid) != null) _bump();
}

void incomingMediaUpdate(String chatKey, int received, int total) {
  if (total <= 0) return;
  incomingMediaProgress[chatKey] = received / total;
  _incomingCount[chatKey] = (received, total);
  incomingMediaStalled.remove(chatKey);
  _incomingTouch[chatKey] = DateTime.now().millisecondsSinceEpoch;
  _ensureSweeper();
  _bump();
}

void incomingMediaDone(String chatKey) {
  _incomingTouch.remove(chatKey);
  _incomingCount.remove(chatKey);
  incomingMediaStalled.remove(chatKey);
  if (incomingMediaProgress.remove(chatKey) != null) _bump();
}

/// "42%" beside the send pill. always mounted for media bubbles; renders
/// nothing until its msgUid has a live entry.
class SendProgressLabel extends StatelessWidget {
  final String msgUid;
  const SendProgressLabel({super.key, required this.msgUid});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mediaProgressTick,
      builder: (_, _, _) {
        final v = mediaSendProgress[msgUid];
        if (v == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            '${(v * 100).round()}%',
            style: HaloType.mono(
              size: 10.5,
              weight: FontWeight.w700,
              color: HaloColors.amber,
            ),
          ),
        );
      },
    );
  }
}

/// slim "receiving media" pill above the composer. self-hiding.
class IncomingMediaBanner extends StatelessWidget {
  final String chatKey;
  const IncomingMediaBanner({super.key, required this.chatKey});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mediaProgressTick,
      builder: (_, _, _) {
        // an outgoing send for this chat takes precedence: that's the
        // one where the user can still ruin it by leaving.
        double? outV;
        for (final e in _sendChat.entries) {
          if (e.value == chatKey) {
            outV = mediaSendProgress[e.key];
            if (outV != null) break;
          }
        }
        final v = outV ?? incomingMediaProgress[chatKey];
        if (v == null) return const SizedBox.shrink();
        final sending = outV != null;
        final stalled = !sending && incomingMediaStalled.contains(chatKey);
        final count = _incomingCount[chatKey];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: HaloColors.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: HaloColors.amber.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    value: v.clamp(0.05, 1.0),
                    color: HaloColors.amber,
                    backgroundColor: HaloColors.line,
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    sending
                        ? 'Sending \u00b7 ${(v * 100).round()}% \u00b7 keep the app open'
                        : stalled && count != null
                        ? 'Paused \u00b7 ${count.$1} of ${count.$2} \u00b7 waiting for the rest'
                        : 'Receiving media \u00b7 ${(v * 100).round()}%',
                    style: HaloType.mono(
                      size: 10.5,
                      color: stalled ? HaloColors.text2 : HaloColors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
