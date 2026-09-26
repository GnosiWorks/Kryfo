// SPDX-License-Identifier: GPL-3.0-or-later

import 'delivery_mode.dart';

/// how long tor has been unable to carry traffic while kryfo is meant to be
/// connected. null in check-in mode (tor is off between checks on purpose),
/// while the app holds tor off, when tor is ready, or before any try started.
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
