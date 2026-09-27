// SPDX-License-Identifier: GPL-3.0-or-later
import 'devchat/dev_key.dart' show isDevChat;
import 'message_envelope.dart';

// the stranger gate as plain decisions, no db or engine, so the rules can be
// tested in one place. a stranger wrote to us before we accepted them: they
// get two messages into requests, and we keep listening for them across
// restarts or the second waits on the relay until we accept.

// who to listen for at boot. accepted contacts, people a friend vouched for,
// and plain strangers sitting in requests: all three can write to us on a
// pair address, so all three need a subscription. blocked rows never do,
// and neither does the dev chat: its lane is its own, and an anonymous
// one must never be listened for as the everyday identity
List<Map<String, Object?>> bootSubscribeRows({
  required List<Map<String, Object?>> accepted,
  required List<Map<String, Object?>> vouchedPending,
  required List<Map<String, Object?>> pendingRequests,
}) {
  final seen = <String>{};
  final out = <Map<String, Object?>>[];
  for (final r in [...accepted, ...vouchedPending, ...pendingRequests]) {
    final id = r['halo_id'] as String?;
    if (id == null || !seen.add(id)) continue;
    if ((r['blocked'] as int? ?? 0) == 1 || isDevChat(id)) continue;
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
// two messages in requests, so this one is not stored.
bool strangerCapHolds({
  required bool accepted,
  required bool vouched,
  required int have,
}) => !accepted && !vouched && have >= 2;

// thrown when the cap holds a message back. the poll loop must not mark the
// event seen then: it stays on the relay, and the replay after accept brings
// it in.
class CapHeld implements Exception {
  const CapHeld();
}
