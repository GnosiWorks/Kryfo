// SPDX-License-Identifier: GPL-3.0-or-later
// the envelope a queued 1:1 text goes out in when the outbox retries it.
// pure, so a test can hold it against the receiver's gate: a stranger's
// first message has to carry the same proof-of-work on the retry as on the
// send, or the far side drops the retry without a word.
import 'dart:convert';

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
  // the preview the sender attached rides the retry too, or a message that
  // needed a second attempt arrived with its card silently gone
  Map<String, String>? preview;
  final pvRaw = row['preview'];
  if (pvRaw is String && pvRaw.isNotEmpty) {
    try {
      preview = (jsonDecode(pvRaw) as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    } catch (_) {
      preview = null;
    }
  }
  return wrapMessage(
    row['plaintext'] as String,
    msgUid: row['msg_uid'] as String?,
    replyTo: row['reply_to'] as String?,
    preview: preview,
    groupId: groupId == null || groupId.isEmpty ? null : groupId,
    supporterBadge: badge,
    // the timer rides the retry too, or a disappearing message the outbox
    // carried stayed forever on both phones
    burnSeconds: (row['burn_secs'] as num?)?.toInt(),
    powNonce: nonce,
    powBitsUsed: nonce == null ? null : powBits,
    sender: sender,
  );
}
