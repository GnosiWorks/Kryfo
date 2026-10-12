// SPDX-License-Identifier: GPL-3.0-or-later
// a stranger's first messages, both ways: what keeps one that did not file
// here, when its sender puts it out again, and why the last ones failed
import 'dart:math';

import 'stranger_gate.dart' show kShelfBytes, kShelfPlaces;

/// a first contact that can never open here: not a message, or one that
/// names someone it is not
class FirstRefused implements Exception {
  const FirstRefused(this.why);
  final String why;
  @override
  String toString() => 'first contact refused ($why)';
}

// openers that did not file, kept on disk and tried again: how many in all,
// how many of one sender's, how many bytes, for how long and how many times.
// as long as the relays keep their copy, inside a stranger shelf's limits
const kFirstKeptMost = 64;
const kFirstKeptPerSender = kShelfPlaces;
// those whose sender is not named on the everyday side, together: a hidden
// chat's, few enough that they never crowd out anyone named
const kFirstKeptUnnamed = 8;
const kFirstKeptBytes = kShelfBytes;
const kFirstKeptFor = Duration(days: 14);
const kFirstKeptTries = 12;

/// the wait before a kept opener is tried again, after [tries] that failed
Duration firstRetryGap(int tries) =>
    Duration(minutes: min(360, 1 << min(tries, 9)));

/// whether a kept opener of [size] bytes fits beside [rows] kept ones that
/// take [bytes], [mine] of them its sender's, or of the unnamed ones when
/// its sender is not [named]
bool firstKeepFits({
  required int rows,
  required int mine,
  required int bytes,
  required int size,
  bool named = true,
}) =>
    rows < kFirstKeptMost &&
    mine < (named ? kFirstKeptPerSender : kFirstKeptUnnamed) &&
    bytes + size <= kFirstKeptBytes;

/// a sent opener with no receipt goes again this long after it last went,
/// at most this many times, and only while the relays keep the first copy
const kOpenerAgain = [
  Duration(minutes: 10),
  Duration(hours: 1),
  Duration(hours: 6),
  Duration(hours: 24),
];
const kOpenerAgainFor = Duration(days: 14);

/// when the opener written at [sentAt], last put out again at [lastAt]
/// after [tries] times, goes again. null for never
int? openerAgainAt({required int sentAt, int? lastAt, required int tries}) {
  if (tries < 0 || tries >= kOpenerAgain.length) return null;
  final at = (lastAt ?? sentAt) + kOpenerAgain[tries].inMilliseconds;
  if (at >= sentAt + kOpenerAgainFor.inMilliseconds) return null;
  return at;
}

/// the wait before listening on the first-contact address again, after
/// [n] tries that failed
Duration fcListenGap(int n) => const [
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(minutes: 1),
  Duration(minutes: 5),
][min(n, 3)];

/// the wait before the invite's counter is read again
Duration fcCounterGap(int n) => const [
  Duration(seconds: 2),
  Duration(seconds: 10),
  Duration(minutes: 1),
  Duration(minutes: 5),
][min(n, 3)];

/// why the last first contacts failed, in this process only: a short code
/// and when, never who or what
class FirstFails {
  FirstFails({this.most = 12});
  final int most;
  final _last = <(String, int)>[];

  void note(String code, {int? at}) {
    _last.add((code, at ?? DateTime.now().millisecondsSinceEpoch));
    if (_last.length > most) _last.removeAt(0);
  }

  List<String> get codes => [for (final (c, _) in _last) c];

  /// newest first, each with how long ago in whole minutes
  String summary({int? now}) {
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    return [
      for (final (c, at) in _last.reversed) '$c ${max(0, t - at) ~/ 60000}m',
    ].join(', ');
  }

  void clear() => _last.clear();
}

final firstFails = FirstFails();

/// a sent text that has not come back delivered, to someone who has not
/// added us back: shown as sent, not delivered yet
bool waitsForReceipt({
  required bool out,
  required bool sent,
  required bool delivered,
  required bool backPaired,
}) => out && sent && !delivered && !backPaired;

/// a 1:1 text's way out. before they add us back the onion goes first, so
/// their drain runs the back-pair, and their first-contact address is the
/// relay route that reaches them. an onion ack is only their engine
/// holding it in memory: the relay copy goes as well, behind the ok, and
/// [bothWent] hears when it did. [copied] is that copy, for whoever waits.
/// [pairRoute]: with no first-contact address, they came on a friend's card
/// and the copy goes to the pair address, which they read if they took ours.
/// [pairRead]: they showed they do, so a copy there is delivered
Future<String> routeText({
  required bool backPaired,
  required String onion,
  required Future<String> Function() viaOnion,
  required Future<String?> Function() xPub,
  required String? fc,
  required Future<String> Function(String xPub, String fc) viaFirst,
  required Future<String> Function(String xPub) viaRelay,
  void Function(String line)? log,
  void Function()? bothWent,
  void Function(Future<void> copy)? copied,
  bool pairRoute = false,
  bool pairRead = false,
}) async {
  final first = !backPaired && fc != null && fc.isNotEmpty;
  final pair = !backPaired && !first && (pairRoute || pairRead);
  final pairSeen = pair && pairRead;
  String? tor;
  if (!backPaired && onion.isNotEmpty) {
    tor = await viaOnion();
    if (tor == 'ok') {
      if (first || pair) {
        final copy = () async {
          try {
            final x = await xPub();
            final f = x == null
                ? 'error: no key'
                : first
                ? await viaFirst(x, fc)
                : await viaRelay(x);
            if (f == 'ok') {
              if (first || pairSeen) bothWent?.call();
              return;
            }
            firstFails.note('copy');
            log?.call('first-contact copy did not go ($f)');
          } catch (e) {
            firstFails.note('copy');
            log?.call('first-contact copy did not go ($e)');
          }
        }();
        copied?.call(copy);
      }
      return 'ok';
    }
    log?.call('tor direct failed ($tor), trying nostr');
  }
  final x = await xPub();
  if (x == null) return tor ?? 'error: no transport';
  if (first) {
    final f = await viaFirst(x, fc);
    if (f == 'ok') return 'ok';
    log?.call('first-contact failed ($f)');
    // never the pair address beside it, or a relay sees the two together.
    // the outbox puts it out again
    return f;
  }
  final r = await viaRelay(x);
  // the pair address is a drop box they read only once they add us back.
  // stored there is not delivered
  if (r == 'ok' && !backPaired && !pairSeen) return 'parked';
  return r;
}
