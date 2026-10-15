// SPDX-License-Identifier: GPL-3.0-or-later
import 'devchat/dev_key.dart' show isDevChat;
import 'message_envelope.dart';

// the stranger gate as plain decisions, no db or engine, so the rules can be
// tested in one place. a stranger wrote to us before we accepted them: they
// get two messages into requests, and we keep listening for them across
// restarts or the second waits on the relay until we accept.

// who to listen for at boot. accepted contacts, people a friend vouched for,
// and plain strangers sitting in requests: all three can write to us on a
// pair address, so all three need a subscription. someone blocked only
// from [blocked], the blocks young enough to listen on, and after everyone
// else, so a key they share stays the other's. never the dev chat: its
// lane is its own, and an anonymous one must never be listened for as the
// everyday identity
List<Map<String, Object?>> bootSubscribeRows({
  required List<Map<String, Object?>> accepted,
  required List<Map<String, Object?>> vouchedPending,
  required List<Map<String, Object?>> pendingRequests,
  List<Map<String, Object?>> blocked = const [],
}) {
  final seen = <String>{};
  final out = <Map<String, Object?>>[];
  void take(Map<String, Object?> r) {
    final id = r['halo_id'] as String?;
    if (id == null || isDevChat(id) || !seen.add(id)) return;
    out.add(r);
  }

  for (final r in [...accepted, ...vouchedPending, ...pendingRequests]) {
    if ((r['blocked'] as int? ?? 0) != 1) take(r);
  }
  blocked.forEach(take);
  return out;
}

// does this frame prove the peer is talking to us? a delivery receipt is
// our own words coming back. counting it would flip back-paired and lift the
// sender's cap while the far gate drops everything past two. only something
// they wrote counts.
bool proofOfEngagement(UnwrappedMessage env) =>
    env.deliveredUid == null && env.need == null;

// the receiver's side of the cap: an unaccepted, unvouched sender already has
// two messages in requests, so this one is not stored. a chat with the
// developer gets [cap] instead, the same on both sides
bool strangerCapHolds({
  required bool accepted,
  required bool vouched,
  required int have,
  int cap = 2,
}) => !accepted && !vouched && have >= cap;

// thrown when the cap holds a message back. the receiver keeps it as it
// opened, on a small shelf, and lets it in on accept.
class CapHeld implements Exception {
  const CapHeld();
}

// places on a stranger's shelf. a file takes one however many slices it
// came in, and its slices fit once it is on it, up to kShelfFileSlices
const kShelfPlaces = 20;

// slices of one file a shelf keeps: a stranger's big file is not worth it
const kShelfFileSlices = 512;

// what one stranger's shelf may take on disk, whatever it holds
const kShelfBytes = 20 << 20;

// what the shelf does with a row: keeps it, has no place for it (it waits
// on the relay), or drops it for good
enum Shelved { kept, full, dropped }

// [files] are the slices of each file on the shelf by their place in it,
// [bytes] what the shelf takes now and [size] the row. an [overflow] row
// is a copy as it came, from a lane with nothing to wait on: no place, only
// its bytes
Shelved shelfVerdict({
  required int places,
  required Map<String, Set<int?>> files,
  required int bytes,
  required int size,
  String? mediaId,
  int? chunk,
  int? total,
  bool overflow = false,
}) {
  if (bytes + size > kShelfBytes) return Shelved.dropped;
  if (overflow) return Shelved.kept;
  if (mediaId != null &&
      chunk != null &&
      (chunk < 0 || (total != null && chunk >= total))) {
    return Shelved.dropped;
  }
  final have = mediaId == null ? null : files[mediaId];
  if (have != null) {
    return have.length >= kShelfFileSlices ? Shelved.dropped : Shelved.kept;
  }
  return places < kShelfPlaces ? Shelved.kept : Shelved.full;
}

// thrown as a full shelf turns a message down before signal keeps anything
// of it: it stays on the relay and opens again once there is room. [peer]
// sent it, and [group] is the file it is a slice of, or empty
class ShelfFull implements Exception {
  const ShelfFull({this.peer, this.group = ''});
  final String? peer;
  final String group;
}
