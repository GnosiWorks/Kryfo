// SPDX-License-Identifier: GPL-3.0-or-later
// a big photo travels as many slices, each on its own, and a relay's 'ok'
// does not mean it arrived. the receiver works out which slices it lacks and
// asks; the sender sends those again and nothing else.
// only asked of a sender whose slices say it can answer, so an older kryfo
// never gets a frame it would not understand.

// an older sender's parser turns down a longer list
const kNeedMaxIndices = 200;
const kNeedMaxAsks = 6;
// before an ask: no slice of the file for this long, and as long since a
// [CatchupHold] last held asks back
const kNeedQuietMs = 45 * 1000;
// a route up this long with no catch-up begun on it: no relay got going
const kNeedRouteWaitMs = 90 * 1000;
// how often the receiver looks for files that stopped part way
const kNeedTickMs = 15 * 1000;
const kResendMinGapMs = 60 * 1000;
// an answered ask is followed no sooner than this, with room for the ask's
// own trip, so the sender does not turn the next one away
const kNeedMinGapMs = kResendMinGapMs + 30 * 1000;
// a tick can run a moment early against the one that stamped the ask
const kNeedSlackMs = 5 * 1000;
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

// 2, 5, 15, 30, 60, 60 minutes between asks that brought nothing
int needBackoffMs(int asks) {
  const minutes = [2, 5, 15, 30, 60, 60];
  final i = asks.clamp(0, minutes.length - 1);
  return minutes[i] * 60 * 1000;
}

/// whether a slice came in after the last ask, or none was made yet.
bool askAnswered({required int lastSliceAt, required int askedAt}) =>
    askedAt <= 0 || lastSliceAt > askedAt;

/// the asks in a row that brought nothing, the one made now counted. one
/// that brought slices starts the count again.
int asksAfterAsk({
  required int lastSliceAt,
  required int askedAt,
  required int asks,
}) => askAnswered(lastSliceAt: lastSliceAt, askedAt: askedAt) ? 1 : asks + 1;

/// what the ask timer knows of the engine's catch-up, the walk that brings
/// what a relay held while this phone was away. asks wait while one runs,
/// and after a route comes up until the catch-up it starts has ended, or
/// none has begun in [kNeedRouteWaitMs]. [heldAt] is the last time it held
/// asks back.
class CatchupHold {
  int heldAt = 0;
  // the engine's count of catch-ups begun, as last seen
  int _begun = -1;
  bool _active = false;
  // when a route came up whose catch-up is still to end, 0 for none
  int _routeAt = 0;
  // the count then: one more is the route's own catch-up
  int _routeBegun = 0;

  /// a route came up, or every relay is about to be asked again. [begun]
  /// is the engine's count of catch-ups begun, read before.
  void routeUp(int now, int begun) {
    heldAt = now;
    _routeAt = now;
    _routeBegun = begun;
    _begun = begun;
  }

  /// there is no route. the engine is not asked, so the count last seen
  /// stands in for the one before the route comes back.
  void down(int now) {
    heldAt = now;
    _routeAt = now;
    _routeBegun = _begun;
    _active = false;
  }

  /// whether asks wait now. [active] and [begun] are the engine's two
  /// numbers.
  bool look({required int now, required int active, required int begun}) {
    // never counted before the route: one running is taken for its own
    if (_routeAt > 0 && _routeBegun < 0) {
      _routeBegun = active > 0 ? begun - 1 : begun;
    }
    if (_begun < 0) _begun = begun;
    // running, just ended, or begun and ended between two looks
    if (active > 0 || _active || begun != _begun) heldAt = now;
    _begun = begun;
    _active = active > 0;
    if (_active) return true;
    if (_routeAt > 0) {
      if (begun <= _routeBegun && now - _routeAt < kNeedRouteWaitMs) {
        return true;
      }
      _routeAt = 0;
    }
    return false;
  }
}

/// the timing half of [shouldAskNow], from the want's row alone, so a tick
/// reads no slices of a file that is not due. quiet means no slice of this
/// file for [kNeedQuietMs], and as long since [heldAt], when a
/// [CatchupHold] last held asks back: while slices may still be coming in,
/// nothing is missing yet, only late.
bool askDue({
  required int now,
  required int lastSliceAt,
  required int askedAt,
  required int asks,
  int heldAt = 0,
}) {
  if (now - lastSliceAt < kNeedQuietMs) return false;
  if (now - heldAt < kNeedQuietMs) return false;
  if (askedAt <= 0) return true;
  final since = now - askedAt + kNeedSlackMs;
  if (askAnswered(lastSliceAt: lastSliceAt, askedAt: askedAt)) {
    return since >= kNeedMinGapMs;
  }
  if (asks >= kNeedMaxAsks) return false;
  return since >= needBackoffMs(asks - 1);
}

/// whether to ask now.
bool shouldAskNow({
  required int now,
  required int lastSliceAt,
  required int askedAt,
  required int asks,
  required bool canResend,
  required int have,
  required int total,
  int heldAt = 0,
}) {
  if (!canResend || total <= 1 || have <= 0 || have >= total) return false;
  return askDue(
    now: now,
    lastSliceAt: lastSliceAt,
    askedAt: askedAt,
    asks: asks,
    heldAt: heldAt,
  );
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
