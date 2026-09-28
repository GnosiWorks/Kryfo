// SPDX-License-Identifier: GPL-3.0-or-later
// a big photo travels as many slices, each on its own, and a relay's 'ok'
// does not mean it arrived. the receiver works out which slices it lacks and
// asks; the sender sends those again and nothing else.
// only asked of a sender whose slices say it can answer, so an older kryfo
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

// what unfinished files may hold on this phone at once, all senders
// together. a slice's row weighs its text and a little more, so many small
// slices count as well as a few big ones
const kUnfinishedBytes = 200 << 20;
const kUnfinishedFiles = 500;
const kSliceRowBytes = 256;

int sliceWeight(int chars) => chars + kSliceRowBytes;

/// the unfinished files that go so the rest fit in [bytes] and [files]:
/// whole files, one past [bytes] on its own before any other, then the one
/// whose last slice came longest ago. [held] is each file's weight and the
/// time of its last slice. a file in [keep] is being put together and stays
List<String> unfinishedPastCap(
  Map<String, ({int bytes, int at})> held, {
  int bytes = kUnfinishedBytes,
  int files = kUnfinishedFiles,
  Set<String> keep = const {},
}) {
  var weight = 0;
  for (final f in held.values) {
    weight += f.bytes;
  }
  var count = held.length;
  if (weight <= bytes && count <= files) return const [];
  bool alone(String id) => held[id]!.bytes > bytes;
  final order =
      [
        for (final id in held.keys)
          if (!keep.contains(id)) id,
      ]..sort((a, b) {
        if (alone(a) != alone(b)) return alone(a) ? -1 : 1;
        final c = held[a]!.at.compareTo(held[b]!.at);
        return c != 0 ? c : a.compareTo(b);
      });
  final out = <String>[];
  for (final id in order) {
    if (weight <= bytes && count <= files) break;
    out.add(id);
    weight -= held[id]!.bytes;
    count--;
  }
  return out;
}
