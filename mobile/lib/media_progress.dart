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

final ValueNotifier<int> mediaProgressTick = ValueNotifier(0);
Timer? _sweeper;

void _bump() => mediaProgressTick.value++;

// a sender dying mid-transfer would leave the banner up forever; sweep
// entries that haven't seen a chunk in 2 minutes.
void _ensureSweeper() {
  _sweeper ??= Timer.periodic(const Duration(seconds: 15), (_) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stale = _incomingTouch.entries
        .where((e) => now - e.value > 75000)
        .map((e) => e.key)
        .toList();
    if (stale.isEmpty) return;
    for (final k in stale) {
      incomingMediaProgress.remove(k);
      _incomingTouch.remove(k);
    }
    _bump();
  });
}

void mediaProgressStart(String msgUid) {
  mediaSendProgress.putIfAbsent(msgUid, () => 0);
  _bump();
}

void mediaProgressUpdate(String msgUid, double v) {
  mediaSendProgress[msgUid] = v;
  _bump();
}

void mediaProgressEnd(String msgUid) {
  if (mediaSendProgress.remove(msgUid) != null) _bump();
}

void incomingMediaUpdate(String chatKey, int received, int total) {
  if (total <= 0) return;
  incomingMediaProgress[chatKey] = received / total;
  _incomingTouch[chatKey] = DateTime.now().millisecondsSinceEpoch;
  _ensureSweeper();
  _bump();
}

void incomingMediaDone(String chatKey) {
  _incomingTouch.remove(chatKey);
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
      builder: (_, __, ___) {
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
      builder: (_, __, ___) {
        final v = incomingMediaProgress[chatKey];
        if (v == null) return const SizedBox.shrink();
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
                Text(
                  'receiving media \u00b7 ${(v * 100).round()}%',
                  style: HaloType.mono(size: 10.5, color: HaloColors.amber),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
