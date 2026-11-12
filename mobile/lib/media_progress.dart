// SPDX-License-Identifier: GPL-3.0-or-later
// live progress for chunked media, both directions: a big file over tor
// takes minutes, so the sender's bubble shows a percentage and the receiver
// gets a slim banner above the composer. a gif and a voice note show none:
// they just appear.
// plain maps and one global tick. the widgets stay mounted and hide
// themselves, so it does not matter whether the widget or the entry comes
// first.
import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'l10n/l10n.dart';
import 'l10n/numbers.dart';
import 'transfers.dart';
import 'widgets/motion.dart' show motionStill;

/// outgoing: msgUid -> 0..1
final Map<String, double> mediaSendProgress = {};

/// outgoing sends still doing the work the files service asks, before any
/// byte goes: the strip says preparing, not 0%
final Set<String> mediaPreparing = {};

// sends that show no share: a gif's and a voice note's
final Set<String> _quiet = {};

/// a voice note, or a gif going as a picture (in slices or through the
/// files service, told by the name its bytes gave it): no share shows
bool quietMedia(String path, {String? fileName, bool voice = false}) =>
    voice || (fileName == null && path.toLowerCase().endsWith('.gif'));

/// whether [msgUid]'s send shows no share
bool mediaQuiet(String msgUid) => _quiet.contains(msgUid);

void mediaPreparingSet(String msgUid, bool on) {
  if (on ? mediaPreparing.add(msgUid) : mediaPreparing.remove(msgUid)) _bump();
}

/// incoming: chat key (groupId or peer haloId) -> 0..1
final Map<String, double> incomingMediaProgress = {};
final Map<String, int> _incomingTouch = {};
// chat key -> (have, total), and the transfers that went quiet. the slices
// stay on disk for a week, so a quiet transfer is paused, not lost, and the
// banner says so.
final Map<String, (int, int)> _incomingCount = {};
final Set<String> incomingMediaStalled = {};

/// which chat an outgoing send belongs to (msgUid -> chatKey), so the
/// banner can show sender-side progress too.
final Map<String, String> _sendChat = {};

// a transfer's size in bytes and its pace, by msgUid for a send and by
// chat key for what comes in. the file a chat's strip fetches now, so the
// strip can pause it
final Map<String, int> _bytes = {};
// a chat's send that has moved a byte, and its bytes in all, for the strip
final Set<String> _outBegun = {};
final Map<String, int> _outTotal = {};
final Map<String, TransferPace> _pace = {};
final Map<String, String> _fetchUid = {};

void _paceAdd(String key, double share) => (_pace[key] ??= TransferPace()).add(
  DateTime.now().millisecondsSinceEpoch,
  share,
);

/// what a strip or the transfer notification says of one transfer:
/// "12.4 MB of 40.0 MB · about 2 min left", or null with no size known
String? transferDetail(String key, double share) {
  final b = _bytes[key];
  if (b == null) return null;
  final left = _pace[key]?.secondsLeft();
  final done = doneOfText(share, b);
  return left == null ? done : l10n.transferDoneLeft(done, leftText(left));
}

/// every transfer under way now, for the notification: sends by msgUid,
/// what comes in by chat. (sending, receiving, bytes done, bytes in all)
({int sending, int receiving, int done, int total}) transfersNow() {
  var sending = 0, receiving = 0, done = 0, total = 0;
  for (final e in mediaSendProgress.entries) {
    if (_quiet.contains(e.key)) continue;
    sending++;
    final b = _bytes[e.key] ?? 0;
    total += b;
    done += (b * e.value).round();
  }
  for (final e in incomingMediaProgress.entries) {
    if (incomingMediaStalled.contains(e.key)) continue;
    receiving++;
    final b = _bytes[e.key] ?? 0;
    total += b;
    done += (b * e.value).round();
  }
  // a waiting file counts only while its fetch runs and bytes come
  final at = DateTime.now().millisecondsSinceEpoch;
  for (final MapEntry(key: uid, value: e) in fileWaits.value.entries) {
    if (e.state != WaitState.coming || !fileWaitMoves(uid, at)) continue;
    receiving++;
    total += e.size;
    done += (e.size * e.share).round();
  }
  return (sending: sending, receiving: receiving, done: done, total: total);
}

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
        _bytes.remove(e.key);
        _pace.remove(e.key);
        _fetchUid.remove(e.key);
        incomingMediaStalled.remove(e.key);
        changed = true;
      } else if (quiet > 75000 && incomingMediaStalled.add(e.key)) {
        changed = true;
      }
    }
    if (changed) _bump();
  });
}

/// [bytes]: the file's size, for the strip's "of" and its time left
@visibleForTesting
void stopMediaSweeper() {
  _sweeper?.cancel();
  _sweeper = null;
}

/// [quiet]: a gif's or a voice note's, which shows no share anywhere
void mediaProgressStart(
  String msgUid, {
  String? chatKey,
  int? bytes,
  bool quiet = false,
}) {
  if (quiet) _quiet.add(msgUid);
  mediaSendProgress.putIfAbsent(msgUid, () => 0);
  if (chatKey != null) _sendChat[msgUid] = chatKey;
  if (bytes != null && bytes > 0) _bytes[msgUid] = bytes;
  _bump();
}

void mediaProgressUpdate(String msgUid, double v) {
  mediaSendProgress[msgUid] = v;
  _paceAdd(msgUid, v);
  _bump();
}

void mediaProgressEnd(String msgUid) {
  _sendChat.remove(msgUid);
  _quiet.remove(msgUid);
  mediaPreparing.remove(msgUid);
  _bytes.remove(msgUid);
  _pace.remove(msgUid);
  if (mediaSendProgress.remove(msgUid) != null) _bump();
}

/// [uid]: the message a fetch from the files service is for, which the
/// strip can pause. [bytes]: the file's size
void incomingMediaUpdate(
  String chatKey,
  int received,
  int total, {
  String? uid,
  int? bytes,
}) {
  if (total <= 0) return;
  incomingMediaProgress[chatKey] = received / total;
  _incomingCount[chatKey] = (received, total);
  incomingMediaStalled.remove(chatKey);
  _incomingTouch[chatKey] = DateTime.now().millisecondsSinceEpoch;
  // slices are 12288 bytes of the file, the last one short
  _bytes[chatKey] = bytes ?? total * 12288;
  if (uid != null) {
    _fetchUid[chatKey] = uid;
  } else {
    _fetchUid.remove(chatKey);
  }
  _paceAdd(chatKey, received / total);
  _ensureSweeper();
  _bump();
}

void incomingMediaDone(String chatKey) {
  _incomingTouch.remove(chatKey);
  _incomingCount.remove(chatKey);
  incomingMediaStalled.remove(chatKey);
  _bytes.remove(chatKey);
  _pace.remove(chatKey);
  _fetchUid.remove(chatKey);
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
        if (v == null || _quiet.contains(msgUid)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: Text(
            percent(v),
            style: HaloType.mono(
              size: 10.5,
              weight: FontWeight.w700,
              color: HaloColors.amberText,
            ),
          ),
        );
      },
    );
  }
}

/// slim "receiving media" pill above the composer. self-hiding: it grows
/// in and out, its ring and its words follow the transfer
class IncomingMediaBanner extends StatelessWidget {
  final String chatKey;

  /// stops an outgoing send from the strip itself
  final void Function(String msgUid)? onCancel;

  /// pauses a file coming in from the files service. its message is
  /// filed then, and goes on with a tap on its bubble
  final void Function(String msgUid)? onPause;
  const IncomingMediaBanner({
    super.key,
    required this.chatKey,
    this.onCancel,
    this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    // two lines of the strip's words fit at any text size
    final tap = stripTapOf(MediaQuery.textScalerOf(context));
    return ValueListenableBuilder<int>(
      valueListenable: mediaProgressTick,
      builder: (_, _, _) {
        // an outgoing send for this chat comes first: leaving the app can
        // still break that one
        // several going at once read as one send: their bytes summed, one
        // line that never steps back from sending to preparing
        double? outV;
        String? outUid;
        var sum = 0.0, all = 0;
        for (final e in _sendChat.entries) {
          if (e.value == chatKey && !_quiet.contains(e.key)) {
            final v = mediaSendProgress[e.key];
            if (v != null) {
              outUid ??= e.key;
              final b = _bytes[e.key] ?? 1;
              sum += v.clamp(0.0, 1.0) * b;
              all += b;
            }
          }
        }
        if (outUid != null) {
          outV = all == 0 ? 0 : sum / all;
          _outTotal[chatKey] = all;
          if (outV > 0) _outBegun.add(chatKey);
        } else {
          _outBegun.remove(chatKey);
          _outTotal.remove(chatKey);
        }
        final v = outV ?? incomingMediaProgress[chatKey];
        Widget strip = const SizedBox(width: double.infinity);
        if (v != null) {
          strip = _strip(
            tap: tap,
            v: v,
            outUid: outUid,
            sending: outV != null,
            still: still,
          );
        }
        return AnimatedSize(
          duration: still ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: still ? Duration.zero : const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(
                v == null ? 'none' : (outUid == null ? 'in' : 'out'),
              ),
              child: strip,
            ),
          ),
        );
      },
    );
  }

  Widget _strip({
    required double tap,
    required double v,
    required String? outUid,
    required bool sending,
    required bool still,
  }) {
    // captured as locals so the tap closures keep a non-null pair
    final cancelUid = outUid;
    final cancel = onCancel;
    final pauseUid = sending ? null : _fetchUid[chatKey];
    final pause = onPause;
    final stalled = !sending && incomingMediaStalled.contains(chatKey);
    final count = _incomingCount[chatKey];
    final total = _outTotal[chatKey];
    final detail = sending
        ? (total == null || total <= 1 ? null : doneOfText(v, total))
        : transferDetail(chatKey, v);
    // preparing until the first byte of the send goes, then sending until
    // it is done: never back
    final line = sending && !_outBegun.contains(chatKey)
        ? l10n.mediaProgressPreparing
        : sending
        ? detail == null
              ? l10n.mediaProgressSendingKeepTheApp(percent(v))
              : l10n.transferSending(detail)
        : stalled && count != null
        ? l10n.mediaProgressPausedOfWaitingFor(whole(count.$1), whole(count.$2))
        : detail == null
        ? l10n.mediaProgressReceivingMedia(percent(v))
        : l10n.transferReceiving(detail);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: HaloColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: HaloColors.amber.withValues(alpha: 0.35)),
        ),
        // one line or two, the strip keeps its height and its buttons stay
        // where the finger is going
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tap),
          child: Row(
            children: [
              SizedBox(
                width: 10,
                height: 10,
                // the ring eases to each new share instead of jumping
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: v.clamp(0.05, 1.0)),
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (_, x, _) => CircularProgressIndicator(
                    strokeWidth: 1.6,
                    value: x,
                    color: HaloColors.amber,
                    backgroundColor: HaloColors.line,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.mono(
                    size: 10.5,
                    color: stalled ? HaloColors.text : HaloColors.amberText,
                  ),
                ),
              ),
              if (pauseUid != null && pause != null && !stalled)
                _StripAction(
                  label: l10n.transferPause,
                  hint: l10n.transferPauseDownload,
                  onTap: () => pause(pauseUid),
                  tap: tap,
                ),
              if (sending && cancelUid != null && cancel != null)
                _StripAction(
                  label: l10n.commonCancel,
                  hint: l10n.mediaProgressCancelSending,
                  onTap: () => cancel(cancelUid),
                  tap: tap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// the strip's buttons, and its height with them
const _kStripTap = 32.0;

/// the strip's height and its buttons', grown with the text
double stripTapOf(TextScaler t) => t.scale(_kStripTap);

class _StripAction extends StatelessWidget {
  final String label;
  final String hint;
  final VoidCallback onTap;
  final double tap;
  const _StripAction({
    required this.label,
    required this.hint,
    required this.onTap,
    required this.tap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 10),
      child: Semantics(
        button: true,
        label: hint,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minWidth: 48, minHeight: tap),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            // as big as its words and the minimum, never all the height a
            // parent offers
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: HaloType.mono(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: HaloColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
