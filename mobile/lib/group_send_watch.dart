// SPDX-License-Identifier: GPL-3.0-or-later
// which of a group chat's rows reading sending have a send behind them.
// the screen settles its own sends when they end. a row someone else is
// sending (the outbox, or this chat before it was closed and opened again)
// is watched, and its verdict read off the database once nothing holds it.
// the full reload waits while anything reads sending, so nothing else would.

/// what a row reading sending should show now
enum SendSeen {
  /// leave it as it is
  keep,

  /// the database says it went
  sent,

  /// nobody is sending it and it did not go
  failed,
}

class GroupSendWatch {
  // sends of this screen, by uid, counted
  final Map<String, int> _own = {};
  // sends seen running elsewhere
  final Set<String> _elsewhere = {};

  bool isOwn(String uid) => _own.containsKey(uid);
  bool watched(String uid) => _elsewhere.contains(uid);

  /// runs a send of this screen's; its row is the screen's to settle
  Future<T> owning<T>(String uid, Future<T> Function() run) async {
    _own[uid] = (_own[uid] ?? 0) + 1;
    _elsewhere.remove(uid);
    try {
      return await run();
    } finally {
      final n = (_own[uid] ?? 1) - 1;
      if (n > 0) {
        _own[uid] = n;
      } else {
        _own.remove(uid);
      }
    }
  }

  /// a send of this screen's found another one already running
  void busy(String uid) => _elsewhere.add(uid);

  /// a row as loaded. [dead] when it is old enough, with the network up,
  /// that a send would have ended; [inflight] when a send holds it now
  SendSeen loaded(
    String uid, {
    required bool sending,
    required bool dead,
    required bool inflight,
  }) {
    if (isOwn(uid)) return SendSeen.keep;
    if (!sending) {
      _elsewhere.remove(uid);
      return SendSeen.keep;
    }
    if (inflight) {
      _elsewhere.add(uid);
      return SendSeen.keep;
    }
    return _elsewhere.contains(uid) || dead ? SendSeen.failed : SendSeen.keep;
  }

  /// true when the row's state should be read from the database. a failed
  /// one stays watched: its sender may mark it sent a beat after letting go
  bool needsCheck(
    String uid, {
    required bool sending,
    required bool failed,
    required bool inflight,
  }) {
    if (isOwn(uid)) return false;
    if (!sending && !(failed && _elsewhere.contains(uid))) return false;
    if (inflight) {
      if (sending) _elsewhere.add(uid);
      return false;
    }
    return true;
  }

  /// the row once its state is read
  SendSeen verdict(
    String uid, {
    required bool sending,
    required bool sent,
    required bool dead,
    required bool inflight,
  }) {
    if (isOwn(uid) || inflight) return SendSeen.keep;
    if (sent) {
      _elsewhere.remove(uid);
      return SendSeen.sent;
    }
    if (sending && (_elsewhere.contains(uid) || dead)) return SendSeen.failed;
    return SendSeen.keep;
  }
}
