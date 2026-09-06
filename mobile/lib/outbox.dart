// SPDX-License-Identifier: GPL-3.0-or-later
// the envelope a queued 1:1 text goes out in when the outbox retries it.
// pure, so a test can hold it against the receiver's gate: a stranger's
// first message has to carry the same proof-of-work on the retry as on the
// send, or the far side drops the retry without a word.
import 'message_envelope.dart';

// does this row still owe a nonce before it can leave. a peer who has
// answered us (back-paired) has no gate for us any more.
bool redeliveryNeedsPow(Map<String, Object?> row, {required bool backPaired}) {
  if (backPaired) return false;
  if ((row['group_id'] as String?)?.isNotEmpty == true) return false;
  return row['pow_nonce'] == null;
}

Future<String> wrapRedelivery(
  Map<String, Object?> row, {
  required SenderInfo sender,
  String? badge,
}) {
  final nonce = (row['pow_nonce'] as num?)?.toInt();
  final groupId = row['group_id'] as String?;
  return wrapMessage(
    row['plaintext'] as String,
    msgUid: row['msg_uid'] as String?,
    replyTo: row['reply_to'] as String?,
    groupId: groupId == null || groupId.isEmpty ? null : groupId,
    supporterBadge: badge,
    powNonce: nonce,
    powBitsUsed: nonce == null ? null : powBits,
    sender: sender,
  );
}
