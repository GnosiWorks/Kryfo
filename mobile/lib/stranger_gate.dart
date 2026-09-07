// SPDX-License-Identifier: GPL-3.0-or-later
//
import 'message_envelope.dart';

// the stranger gate, as plain decisions with no db or engine behind them, so
// the rules can be tested and read in one place. a stranger is someone who
// wrote to us before we accepted them: they get two messages into requests,
// and the app must keep listening for them across restarts or the second
// message quietly waits on the relay until we accept.

// who to listen for at boot. accepted contacts, people a friend vouched for,
// and plain strangers sitting in requests: all three can write to us on a
// pair address, so all three need a subscription. blocked rows never do.
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
    if ((r['blocked'] as int? ?? 0) == 1) continue;
    out.add(r);
  }
  return out;
}

// does this frame prove the peer is talking to us? a delivery receipt does
// not: it means their phone stored our message, which is our own words
// coming back. counting it flipped back-paired on the sender, and with it the
// sender's own two-message cap, so a stranger could keep writing into a gate
// that drops everything past two. only something they wrote counts.
bool proofOfEngagement(UnwrappedMessage env) => env.deliveredUid == null;
