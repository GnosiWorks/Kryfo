// SPDX-License-Identifier: GPL-3.0-or-later
// the chunked sender for a group: every slice goes to each other member in
// an envelope of its own. a slice is landed per member, not per group, so a
// member one slice missed is sent that slice again and the rest are not.
// one send per row at a time, through the same in-flight set as the 1:1
// sender, and the progress strip ends with the send however it ends.

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;

import 'dlog.dart';
import 'image_strip.dart' show cleanSavedPhoto;
import 'media_progress.dart';
import 'media_send.dart'
    show
        mediaCancelled,
        mediaInflight,
        mediaSlice,
        mediaSliceCount,
        releaseMedia;

// msgUid -> member -> slices that member has, while the row has not gone
// yet: a retry of it resumes from there. dropped once a send went, when
// what a member still lacks is on disk, or when old enough that a member
// may have restarted without it
final Map<String, Map<String, Set<int>>> groupSliceDone = {};
final Map<String, int> groupSliceDoneAt = {};

// sends to every member that still lacks it while nobody has it yet
const kGroupSliceTries = 3;
// rounds at the end for the members a slice missed while others got it,
// one that took nothing included: a session that was still being set up
// may be there by now
const kGroupCatchUpPasses = 2;
// a member that fails this many in a row is left for the next round
const kGroupMemberMisses = 3;

// the row reads sent once every slice has reached someone, so a member
// still short then is owed the rest. what each holds is kept on disk and
// the outbox sends the missing slices on its tick: a session that needs
// the far side's answer first takes minutes or days, not seconds
const kGroupOwedGap = 45000;
const kGroupOwedGapMost = 1800000;
// about three days of trying at the longest wait. only a pass that runs
// counts, so days with no route or no phone online cost no member a try
const kGroupOwedTries = 150;

/// the wait after [tries] tries, doubling up to the longest
int groupOwedGap(int tries) {
  final g = kGroupOwedGap << (tries < 6 ? tries : 6);
  return g < kGroupOwedGapMost ? g : kGroupOwedGapMost;
}

/// slices as runs, "0-41,43": short for a member that has most or none
String packSlices(Iterable<int> slices) {
  final s = slices.toSet().toList()..sort();
  final out = <String>[];
  var i = 0;
  while (i < s.length) {
    var j = i;
    while (j + 1 < s.length && s[j + 1] == s[j] + 1) {
      j++;
    }
    out.add(i == j ? '${s[i]}' : '${s[i]}-${s[j]}');
    i = j + 1;
  }
  return out.join(',');
}

/// the other way. a part it cannot read, or past [total], is left out
Set<int> unpackSlices(String? packed, int total) {
  final out = <int>{};
  for (final part in (packed ?? '').split(',')) {
    final ends = part.split('-');
    final a = int.tryParse(ends.first);
    final b = ends.length == 2 ? int.tryParse(ends.last) : a;
    if (a == null || b == null || ends.length > 2 || a < 0 || b < a) continue;
    for (var k = a; k <= b && k < total; k++) {
      out.add(k);
    }
  }
  return out;
}

/// one member still short of one file
class GroupOwed {
  const GroupOwed({
    required this.msgUid,
    required this.groupId,
    required this.member,
    required this.total,
    required this.have,
    required this.since,
    required this.tries,
  });

  GroupOwed.fromRow(Map<String, Object?> r)
    : msgUid = r['msg_uid'] as String,
      groupId = r['group_id'] as String,
      member = r['member'] as String,
      total = r['total'] as int,
      have = unpackSlices(r['have'] as String?, r['total'] as int),
      since = r['since'] as int,
      tries = r['tries'] as int? ?? 0;

  final String msgUid;
  final String groupId;
  final String member;
  final int total;
  final Set<int> have;
  final int since;
  final int tries;
}

/// where what is owed is kept: a container's database
abstract interface class GroupOwedStore {
  /// every member whose wait is up at [now]
  Future<List<GroupOwed>> dueGroupOwed(int now);

  /// a try is starting: its count goes up and the next wait is set
  Future<void> triedGroupOwed(String msgUid, Iterable<String> members, int now);

  /// let go of a file
  Future<void> dropGroupOwed(String msgUid);
}

/// bumped when what some member is owed changes, so an open chat redraws
final groupOwedTick = ValueNotifier<int>(0);

/// sends again what [store] holds owed and due, one file at a time. [send]
/// gets one file's members with the slices each has, and answers as a send
/// does: 'gone' when the row, its file, its chat or its members are
Future<void> resendGroupOwed(
  GroupOwedStore store, {
  required int now,
  required Future<String> Function(
    String msgUid,
    String groupId,
    Map<String, Set<int>> have,
    int total,
  )
  send,
}) async {
  final byFile = <String, List<GroupOwed>>{};
  for (final o in await store.dueGroupOwed(now)) {
    byFile.putIfAbsent(o.msgUid, () => []).add(o);
  }
  for (final MapEntry(key: uid, value: owed) in byFile.entries) {
    // another send has the row: the next tick sees what it left
    if (mediaInflight.contains(uid)) continue;
    // a member past its tries is tried no more. its row stays, so the line
    // under the bubble still counts it as not having the file
    final go = [
      for (final o in owed)
        if (o.tries < kGroupOwedTries) o,
    ];
    if (go.isEmpty) continue;
    // stamped before it goes: a send takes a while, and the tick it ends
    // on must not start the same one again
    await store.triedGroupOwed(uid, [for (final o in go) o.member], now);
    String r;
    try {
      r = await send(uid, go.first.groupId, {
        for (final o in go) o.member: o.have,
      }, go.first.total);
    } catch (e) {
      r = 'error: ${e.runtimeType}';
    }
    if (r == 'gone') {
      await store.dropGroupOwed(uid);
      groupOwedTick.value++;
    } else if (r == 'error: quiet') {
      return;
    } else if (r != 'ok') {
      dlog('GRP MEDIA $uid: still owed ($r)');
      if (go.any((o) => o.tries + 1 >= kGroupOwedTries)) {
        dlog('GRP MEDIA $uid: no more tries for some members');
      }
    }
  }
}

/// the envelope for slice [i] of [total]
typedef GroupSliceWrap =
    Future<String> Function(String slice, int i, int total);

/// true when [member] took the envelope
typedef GroupDeliver = Future<bool> Function(String member, String wrapped);

/// 'ok', 'busy' when another send has the row, 'cancelled', or an error.
/// [members] are the ones to send to, this phone left out.
Future<String> sendGroupSlices({
  required String path,
  required String msgUid,
  required List<String> members,
  required GroupSliceWrap wrap,
  required GroupDeliver deliver,
  // the chat's key for the progress strip
  String? progressKey,
  // a photo, cleaned before it goes
  bool photo = false,
  // sequential on purpose: parallel waves drop slices on the circuit
  Duration gap = const Duration(milliseconds: 150),
  Duration retryPause = const Duration(seconds: 1),
  // the members still short and what each has, when a send that went ends
  // or a send to the owed stops on a slice
  Future<void> Function(Map<String, Set<int>> short, int total)? onShort,
  // a send to members owed the file: the slices each has already
  Map<String, Set<int>>? owed,
}) async {
  if (!mediaInflight.add(msgUid)) return 'busy';
  try {
    return await _send(
      path: path,
      msgUid: msgUid,
      members: members,
      wrap: wrap,
      deliver: deliver,
      progressKey: progressKey,
      photo: photo,
      gap: gap,
      retryPause: retryPause,
      onShort: onShort,
      owed: owed,
    );
  } finally {
    mediaCancelled.remove(msgUid);
    mediaProgressEnd(msgUid);
    releaseMedia(msgUid);
  }
}

Future<String> _send({
  required String path,
  required String msgUid,
  required List<String> members,
  required GroupSliceWrap wrap,
  required GroupDeliver deliver,
  required String? progressKey,
  required bool photo,
  required Duration gap,
  required Duration retryPause,
  required Future<void> Function(Map<String, Set<int>> short, int total)?
  onShort,
  required Map<String, Set<int>>? owed,
}) async {
  // nobody to send to is not a send that went
  if (members.isEmpty) return 'error: no members';
  // a photo is cleaned on every send, retries and the outbox included
  var fresh = false;
  if (photo) {
    final cleaned = await cleanSavedPhoto(path);
    if (cleaned == null) return 'error: not clean';
    // the slices out so far were of other bytes
    if (cleaned) groupSliceDone.remove(msgUid);
    fresh = cleaned;
  }
  final int total;
  try {
    total = await mediaSliceCount(path);
  } catch (e) {
    return 'error: read';
  }
  final showProgress = total > 1 && progressKey != null;
  if (showProgress) mediaProgressStart(msgUid, chatKey: progressKey);
  final Map<String, Set<int>> done;
  if (owed != null) {
    // what the owed hold is on disk, not here
    done = {
      for (final m in members)
        m: fresh ? <int>{} : {...?owed[m]?.where((i) => i < total)},
    };
  } else {
    final now = DateTime.now().millisecondsSinceEpoch;
    // rows whose send stopped and never came back
    groupSliceDoneAt.removeWhere((k, at) {
      final old = now - at > 240000 && !mediaInflight.contains(k);
      if (old) groupSliceDone.remove(k);
      return old;
    });
    if (now - (groupSliceDoneAt[msgUid] ?? now) > 240000) {
      groupSliceDone.remove(msgUid);
    }
    groupSliceDoneAt[msgUid] = now;
    done = groupSliceDone.putIfAbsent(msgUid, () => {});
  }
  Set<int> has(String m) => done.putIfAbsent(m, () => <int>{});
  bool anyHas(int i) => members.any((m) => has(m).contains(i));
  int landed() {
    var n = 0;
    for (var i = 0; i < total; i++) {
      if (anyHas(i)) n++;
    }
    return n;
  }

  bool cancelled() => mediaCancelled.contains(msgUid);
  Map<String, Set<int>> shortNow() => {
    for (final m in members)
      if (has(m).length < total) m: {...has(m)},
  };

  // the members of [to] that did not take it
  Future<List<String>> push(int i, String wrapped, List<String> to) async {
    final ok = await Future.wait([
      for (final m in to)
        deliver(m, wrapped).catchError((Object e) {
          dlog('GRP MEDIA chunk $i: ${e.runtimeType}');
          return false;
        }),
    ]);
    final left = <String>[];
    for (var k = 0; k < to.length; k++) {
      if (ok[k]) {
        has(to[k]).add(i);
      } else {
        left.add(to[k]);
      }
    }
    if (owed == null) {
      groupSliceDoneAt[msgUid] = DateTime.now().millisecondsSinceEpoch;
    }
    return left;
  }

  Future<String?> envelope(int i) async {
    try {
      return await wrap(await mediaSlice(path, i), i, total);
    } catch (e) {
      dlog('GRP MEDIA chunk $i/$total unreadable: ${e.runtimeType}');
      return null;
    }
  }

  final before = landed();
  if (before > 0 && showProgress) {
    dlog('GRP MEDIA resume $msgUid: $before/$total already out');
    mediaProgressUpdate(msgUid, before / total);
  }
  for (var i = 0; i < total; i++) {
    if (cancelled()) return 'cancelled';
    var left = [
      for (final m in members)
        if (!has(m).contains(i)) m,
    ];
    if (left.isEmpty) continue;
    final wrapped = await envelope(i);
    if (wrapped == null) return 'error: read';
    // tried again only while nobody has it: a member it missed while
    // others got it waits for the rounds at the end, not every slice
    for (var tryN = 0; tryN < kGroupSliceTries; tryN++) {
      if (tryN > 0) {
        await Future.delayed(retryPause);
        if (cancelled()) return 'cancelled';
      }
      left = await push(i, wrapped, left);
      if (left.isEmpty || anyHas(i)) break;
      dlog('GRP MEDIA chunk $i/$total try ${tryN + 1} failed');
    }
    if (!anyHas(i)) {
      dlog('GRP MEDIA chunk $i/$total gave up');
      // the owed keep what they took on the way
      if (owed != null) await onShort?.call(shortNow(), total);
      return 'error: chunk $i undeliverable';
    }
    if (showProgress) mediaProgressUpdate(msgUid, landed() / total);
    if (total > 1 && i < total - 1) await Future.delayed(gap);
  }

  // every slice has reached someone: the strip is done, the rounds below
  // are for the few that missed one
  if (showProgress) mediaProgressEnd(msgUid);
  Future<void> catchUp(String m) async {
    var misses = 0;
    for (var i = 0; i < total && misses < kGroupMemberMisses; i++) {
      if (has(m).contains(i) || cancelled()) continue;
      final wrapped = await envelope(i);
      if (wrapped == null) return;
      final left = await push(i, wrapped, [m]);
      misses = left.isEmpty ? 0 : misses + 1;
      await Future.delayed(gap);
    }
  }

  for (var pass = 0; pass < kGroupCatchUpPasses; pass++) {
    final short = [
      for (final m in members)
        if (has(m).length < total) m,
    ];
    if (short.isEmpty) break;
    await Future.delayed(retryPause * (2 * (pass + 1)));
    if (cancelled()) return 'cancelled';
    // one member at a time would make everyone wait on the slowest
    await Future.wait([for (final m in short) catchUp(m)]);
    if (cancelled()) return 'cancelled';
  }
  final short = shortNow();
  if (short.isNotEmpty) {
    dlog('GRP MEDIA $msgUid: ${short.length} member(s) owed the file');
  }
  await onShort?.call(short, total);
  // the row reads sent now, and what the short still lack is on disk
  if (owed == null) {
    groupSliceDone.remove(msgUid);
    groupSliceDoneAt.remove(msgUid);
  }
  return 'ok';
}
