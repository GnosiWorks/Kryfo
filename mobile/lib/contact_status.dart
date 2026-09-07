// SPDX-License-Identifier: GPL-3.0-or-later
// the one line under a person's name on their page. pure, so the order of
// precedence is pinned: verified beats vouched beats anything else.
import 'vouch_text.dart';

String contactStatusLine({
  required bool verified,
  required List<String> voucherNames,
  required bool blocked,
  required bool accepted,
}) {
  if (blocked) return 'blocked';
  if (verified) return 'keys verified in person';
  if (voucherNames.isNotEmpty) return vouchedByLine(voucherNames);
  if (!accepted) return 'waiting in requests';
  return 'added by hand';
}
