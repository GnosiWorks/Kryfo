// SPDX-License-Identifier: GPL-3.0-or-later
// what sending shares: queued frames and message ids

part of '../main.dart';

// tries a queued reaction gets before it is let go: about a day at the
// longest wait
const kFrameTries = 150;

// the wait after [tries] tries of a queued row or frame: doubling from
// 45 s up to ten minutes, so a peer out of reach gets few copies
int queueGap(int tries) {
  final g = 45000 << (tries < 4 ? tries : 4);
  return g < 600000 ? g : 600000;
}

const kFrameUnsend = 'unsend';
const kFrameReaction = 'reaction';
// a receipt that could not be sealed while a session waits on their card
const kFrameReceipt = 'receipt';
// a chat's screenshot block: the frame carries the state as it is when it
// goes (shotsOnWire), so one per chat
const kFrameShots = 'shots';
String shotsUid(String peer) => 'shots:$peer';
// the old switch for the whole app, kept until home asks about it
const kOldShotsKey = 'block_screenshots';
// and how long it waits at most
const kReceiptKeptFor = Duration(days: 7);

int _outboxGrind(String seed) => grindPow(seed, powBits);

final _msgUidRandom = Random.secure();
const _msgUidChars = '0123456789abcdefghijklmnopqrstuvwxyz';

// stable cross-device message id, also a group's and a room's id. used by
// reactions, replies and group fan-out so every recipient sees the same
// uid. 14 base36 characters from the platform csprng: over 72 bits, with
// nothing of the clock in it
String newMsgUid() => String.fromCharCodes([
  for (var i = 0; i < 14; i++)
    _msgUidChars.codeUnitAt(_msgUidRandom.nextInt(_msgUidChars.length)),
]);

// one container's unsent rows: how many, how many wait on someone who has
// not added us back, how many for each person, and who has
class _Queue {
  const _Queue(this.n, this.parked, this.perPeer, this.paired);
  static const none = _Queue(0, 0, {}, {});

  final int n;
  final int parked;
  final Map<String, int> perPeer;
  final Map<String, bool> paired;

  bool same(_Queue o) {
    if (n != o.n || parked != o.parked) return false;
    if (perPeer.length != o.perPeer.length) return false;
    for (final e in perPeer.entries) {
      if (o.perPeer[e.key] != e.value) return false;
    }
    return true;
  }
}

// a dev chat delete's take-backs, sealed before its wipe
typedef _TakeBacks = ({
  String xPub,
  String? fc,
  bool backPaired,
  List<String> ciphers,
  int failed,
});

// how to reach someone, and the container their chat is in: null for a
// hidden chat while its vault is shut
typedef _Reach = ({
  String onion,
  String xpub,
  String? bundle,
  bool backPaired,
  HaloDb? on,
});

/// where an ask to start afresh puts undelivered texts out again from: the
/// last [window], or since the asker's backup was made ([since]) when that
/// is further back, never past [most]
int resendFrom(
  int now,
  int? since, {
  required Duration window,
  required Duration most,
}) {
  final last = now - window.inMilliseconds;
  if (since == null) return last;
  return min(last, max(since, now - most.inMilliseconds));
}

/// the start of the UTC day [ms] falls in
int utcDayOf(int ms) => ms - ms % Duration.millisecondsPerDay;
