// SPDX-License-Identifier: GPL-3.0-or-later
// debug and profile builds only: the reliability harness's sender. adb
// reaches it through BenchReceiver, which only those builds carry
// (android/app/src/bench). a release build answers nothing here and logs
// nothing. the log lines hold times and counts only, never words or ids

part of '../main.dart';

const kBenchChannel = 'kryfo/bench';

void benchLog(String line) {
  if (!kReleaseMode) debugPrint(line);
}

void benchListen() {
  if (kReleaseMode) return;
  const MethodChannel(kBenchChannel).setMethodCallHandler((call) async {
    if (call.method != 'send') return false;
    final a = call.arguments;
    if (a is! Map || a['to'] is! String || a['n'] is! int) return false;
    return appState.benchSend(a['to'] as String, a['n'] as int);
  });
}

extension BenchSend on AppState {
  // one numbered text to the contact with this name, on the everyday side,
  // straight onto the wire as the outbox sends a row
  Future<bool> benchSend(String to, int n) async {
    if (kReleaseMode) return false;
    final rows = await live.contacts();
    final peer = rows
        .where((r) => r['nickname'] == to)
        .map((r) => r['halo_id'] as String)
        .firstOrNull;
    if (peer == null) {
      benchLog('bench: no contact by that name n=$n');
      return false;
    }
    final uid = newMsgUid();
    if (!_outboxInflight.add(uid)) return false;
    try {
      await live.saveMessage(peer, 'out', 'bench $n', msgUid: uid, sent: 0);
      final db = await live.open();
      final r = await db.query(
        'messages',
        where: 'msg_uid = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (r.isEmpty) return false;
      final wrote = (r.first['sent_at'] as num?)?.toInt() ?? 0;
      await _drainOne(r.first, live);
      final ok = await live.isSent(uid);
      benchLog(
        'bench: sent n=$n wrote=$wrote at=${DateTime.now().millisecondsSinceEpoch} ok=$ok',
      );
      return ok;
    } finally {
      _outboxInflight.remove(uid);
    }
  }
}

// the receiving side: when a 1:1 message was written and when it was kept here
void benchGot(int? wrote) {
  if (kReleaseMode) return;
  benchLog(
    'bench: got wrote=${wrote ?? 0} at=${DateTime.now().millisecondsSinceEpoch}',
  );
}
