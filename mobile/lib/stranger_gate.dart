// SPDX-License-Identifier: GPL-3.0-or-later
import 'devchat/dev_key.dart' show isDevChat;
import 'message_envelope.dart';

// the stranger gate as plain decisions, no db or engine, so the rules can be
// tested in one place. a stranger wrote to us before we accepted them: they
// get two messages into requests, and we keep listening for them across
// restarts or the second waits on the relay until we accept.

// who to listen for at boot. accepted contacts, people a friend vouched for,
// and plain strangers sitting in requests: all three can write to us on a
// pair address, so all three need a subscription. so does everyone
// [blocked]: what they send while the block holds comes in to be dropped,
// or the relay keeps it for an unblock. never the dev chat: its lane is its
// own, and an anonymous one must never be listened for as the everyday
// identity
List<Map<String, Object?>> bootSubscribeRows({
  required List<Map<String, Object?>> accepted,
  required List<Map<String, Object?>> vouchedPending,
  required List<Map<String, Object?>> pendingRequests,
  List<Map<String, Object?>> blocked = const [],
}) {
  final seen = <String>{};
  final out = <Map<String, Object?>>[];
  for (final r in [
    ...accepted,
    ...vouchedPending,
    ...pendingRequests,
    ...blocked,
  ]) {
    final id = r['halo_id'] as String?;
    if (id == null || !seen.add(id)) continue;
    if (isDevChat(id)) continue;
    out.add(r);
  }
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
