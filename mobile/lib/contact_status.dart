// SPDX-License-Identifier: GPL-3.0-or-later
// the one line under a person's name on their page. pure, so the order of
// precedence is pinned: verified beats vouched beats anything else.
import 'vouch_text.dart';
import 'l10n/l10n.dart';

String contactStatusLine({
  required bool verified,
  required List<String> voucherNames,
  required bool blocked,
  required bool accepted,
}) {
  if (blocked) return l10n.contactStatusBlocked;
  if (verified) return l10n.contactStatusKeysVerifiedInPerson;
  if (voucherNames.isNotEmpty) return vouchedByLine(voucherNames);
  if (!accepted) return l10n.contactStatusWaitingInRequests;
  return l10n.contactStatusAddedByHand;
}
