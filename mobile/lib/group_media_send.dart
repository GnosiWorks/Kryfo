// SPDX-License-Identifier: GPL-3.0-or-later
// the chunked sender for a group: every slice goes to each other member in
// an envelope of its own. a slice is landed per member, not per group, so a
// member one slice missed is sent that slice again and the rest are not.
// one send per row at a time, through the same in-flight set as the 1:1
// sender, and the progress strip ends with the send however it ends.

import 'dart:async';

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

// msgUid -> member -> slices that member has. dropped when the file is
// across, or when old enough that a member may have restarted without it
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

// the row reads sent once the others have it, so a member still short after
// the rounds is owed the file and sent it again on the outbox's tick: a
// session that needs the far side's answer first takes minutes, not seconds
const kGroupOwedGap = 45000;
const kGroupOwedGapMost = 600000;
const kGroupOwedFor = 86400000;

class GroupOwed {
  GroupOwed(this.resend, this.since) : nextAt = since + kGroupOwedGap;
  // sends it again to these members only. 'gone' when the row, its file or
  // its chat is
  Future<String> Function(List<String> to) resend;
  final members = <String>{};
  final int since;
  int tries = 0;
  int nextAt;
}

// msgUid -> what is owed. in memory: a restart forgets it
final Map<String, GroupOwed> groupMediaOwed = {};

/// a send of [msgUid] to [tried] ended with [short] still missing slices
void noteGroupShort(
  String msgUid, {
  required Iterable<String> tried,
  required Iterable<String> short,
  required Future<String> Function(List<String> to) resend,
  int? now,
}) {
  var owed = groupMediaOwed[msgUid];
  if (owed == null) {
    if (short.isEmpty) return;
    owed = GroupOwed(resend, now ?? DateTime.now().millisecondsSinceEpoch);
    groupMediaOwed[msgUid] = owed;
  }
  owed.resend = resend;
  owed.members
    ..removeAll(tried)
    ..addAll(short);
  if (owed.members.isEmpty) groupMediaOwed.remove(msgUid);
}

Future<void>? _owedPass;

/// sends again what is owed and due, one file at a time
Future<void> resendGroupOwed({int? now}) =>
    _owedPass ??= _resendOwed(now).whenComplete(() => _owedPass = null);

Future<void> _resendOwed(int? now) async {
  for (final MapEntry(key: uid, value: owed)
      in groupMediaOwed.entries.toList()) {
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    if (!identical(groupMediaOwed[uid], owed)) continue;
    if (at - owed.since > kGroupOwedFor) {
      groupMediaOwed.remove(uid);
      continue;
    }
    if (at < owed.nextAt) continue;
    owed.tries++;
    final gap = kGroupOwedGap << (owed.tries < 4 ? owed.tries : 4);
    owed.nextAt = at + (gap < kGroupOwedGapMost ? gap : kGroupOwedGapMost);
    String r;
    try {
      r = await owed.resend(owed.members.toList());
    } catch (e) {
      r = 'error: ${e.runtimeType}';
    }
    if (r == 'gone' || r == 'cancelled') {
      if (identical(groupMediaOwed[uid], owed)) groupMediaOwed.remove(uid);
    } else if (r != 'ok') {
      dlog('GRP MEDIA $uid: owed still ($r)');
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
  // told who is still short when a send that went ends
  void Function(List<String> short)? onShort,
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
  required void Function(List<String> short)? onShort,
}) async {
  // nobody to send to is not a send that went
  if (members.isEmpty) return 'error: no members';
  // a photo is cleaned on every send, retries and the outbox included
  if (photo) {
    final cleaned = await cleanSavedPhoto(path);
    if (cleaned == null) return 'error: not clean';
    // the slices out so far were of other bytes
    if (cleaned) groupSliceDone.remove(msgUid);
  }
  final int total;
  try {
    total = await mediaSliceCount(path);
  } catch (e) {
    return 'error: read';
  }
  final showProgress = total > 1 && progressKey != null;
  if (showProgress) mediaProgressStart(msgUid, chatKey: progressKey);
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - (groupSliceDoneAt[msgUid] ?? now) > 240000) {
    groupSliceDone.remove(msgUid);
  }
  groupSliceDoneAt[msgUid] = now;
  final done = groupSliceDone.putIfAbsent(msgUid, () => {});
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
    groupSliceDoneAt[msgUid] = DateTime.now().millisecondsSinceEpoch;
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
  final short = [
    for (final m in members)
      if (has(m).length < total) m,
  ];
  if (short.isNotEmpty) {
    dlog('GRP MEDIA $msgUid: ${short.length} member(s) owed the file');
  }
  onShort?.call(short);
  // what the owed have is kept, so a send to them soon after resumes
  done.removeWhere((m, _) => !short.contains(m));
  if (short.isEmpty) {
    groupSliceDone.remove(msgUid);
    groupSliceDoneAt.remove(msgUid);
  }
  return 'ok';
}
