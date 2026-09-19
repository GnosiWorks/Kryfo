// SPDX-License-Identifier: GPL-3.0-or-later

import 'delivery_mode.dart';

/// how long tor has been unable to carry traffic while kryfo is meant to be
/// connected, or null when that question does not apply.
///
/// pulled out of AppState so it can be tested without one. the case it exists
/// for cannot be staged on a phone: it needs tor's control port to wedge, and
/// dropping wifi does not do it - tor keeps its bootstrap state and goes on
/// reporting "reachable" with no network at all.
///
/// null, meaning "not a question", when:
///  - check-ins are the mode. tor is off between checks on purpose.
///  - the app is holding tor off itself, or wiping.
///  - tor can carry traffic.
///  - nothing has started trying yet, so there is no clock to read.
Duration? offlineDurationFor({
  required DeliveryMode mode,
  required bool torHeld,
  required bool torReady,
  required DateTime? tryingSince,
  required DateTime now,
}) {
  if (mode != DeliveryMode.always) return null;
  if (torHeld) return null;
  if (torReady) return null;
  if (tryingSince == null) return null;
  final d = now.difference(tryingSince);
  return d.isNegative ? Duration.zero : d;
}
