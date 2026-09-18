// SPDX-License-Identifier: GPL-3.0-or-later
// a big photo is a hundred slices and each travels on its own. when one or
// two never arrive the receiver sat at 99% for good: nothing told the sender
// which pieces were missing, and the sender had heard 'ok' from a relay for
// every one. here the receiver works out what it lacks and asks, and the
// sender sends those slices again and nothing else.
//
// only asked of a sender whose slices said it can answer, so an older kryfo
// never gets a frame it would not understand.

const kNeedMaxIndices = 200;
const kNeedMaxAsks = 6;
const kNeedQuietMs = 120 * 1000;
const kResendMinGapMs = 60 * 1000;
const kResendMaxRounds = 8;
const kMaxSlices = 100000;

class NeedFrame {
  final String mediaId;
  final List<int> indices;
  const NeedFrame(this.mediaId, this.indices);

  Map<String, dynamic> toJson() => {'u': mediaId, 'i': indices};

  // null for anything that is not exactly the shape expected: this comes
  // from the other side and decides what gets read off disk and sent
  static NeedFrame? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final u = raw['u'];
    final i = raw['i'];
    if (u is! String || u.isEmpty || u.length > 128) return null;
    if (i is! List || i.isEmpty || i.length > kNeedMaxIndices) return null;
    final out = <int>{};
    for (final v in i) {
      if (v is! int || v < 0 || v >= kMaxSlices) return null;
      out.add(v);
    }
    return NeedFrame(u, out.toList()..sort());
  }
}

/// the slice numbers not held yet, lowest first, at most [cap] of them.
List<int> missingSlices(Set<int> have, int total, {int cap = kNeedMaxIndices}) {
  final out = <int>[];
  if (total <= 0 || total > kMaxSlices) return out;
  for (var i = 0; i < total && out.length < cap; i++) {
    if (!have.contains(i)) out.add(i);
  }
  return out;
}

// 2, 5, 15, 30, 60, 60 minutes between asks
int needBackoffMs(int asks) {
  const minutes = [2, 5, 15, 30, 60, 60];
  final i = asks.clamp(0, minutes.length - 1);
  return minutes[i] * 60 * 1000;
}

/// whether to ask now. quiet means no slice of this file for two minutes:
/// while slices are still coming in, from a catch-up say, nothing is missing
/// yet, only late.
bool shouldAskNow({
  required int now,
  required int lastSliceAt,
  required int askedAt,
  required int asks,
  required bool canResend,
  required int have,
  required int total,
}) {
  if (!canResend || total <= 1 || have <= 0 || have >= total) return false;
  if (asks >= kNeedMaxAsks) return false;
  if (now - lastSliceAt < kNeedQuietMs) return false;
  if (askedAt > 0 && now - askedAt < needBackoffMs(asks - 1)) return false;
  return true;
}

/// the sender's side: whether a request may be answered at all.
bool resendAllowed({
  required String? rowPeer,
  required String? rowGroup,
  required String? rowDirection,
  required String requester,
  required int now,
  required int lastAnsweredAt,
  required int rounds,
}) {
  if (rowDirection != 'out') return false;
  if (rowGroup != null && rowGroup.isNotEmpty) return false;
  if (rowPeer == null || rowPeer != requester) return false;
  if (rounds >= kResendMaxRounds) return false;
  if (lastAnsweredAt > 0 && now - lastAnsweredAt < kResendMinGapMs) {
    return false;
  }
  return true;
}

/// which of the asked-for slices exist in a file of [total] slices.
Set<int> answerable(List<int> asked, int total) => {
  for (final i in asked)
    if (i >= 0 && i < total) i,
};
