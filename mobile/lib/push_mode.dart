// SPDX-License-Identifier: GPL-3.0-or-later
// clears what the removed ntfy wake-up mode left in the prefs. delivery is
// in delivery_mode.dart.

import 'package:shared_preferences/shared_preferences.dart';

/// the ntfy topic and server, per-contact urls and the mode key. runs at
/// boot and after a restore, since old backups still carry them.
Future<void> forgetNtfy() async {
  final prefs = await SharedPreferences.getInstance();
  for (final k in prefs.getKeys().toList()) {
    if (k == 'ntfy_topic' ||
        k == 'ntfy_server' ||
        k == 'push_mode' ||
        k.startsWith('ntfy_peer_endpoint_')) {
      await prefs.remove(k);
    }
  }
}
