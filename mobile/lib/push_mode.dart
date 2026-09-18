// SPDX-License-Identifier: GPL-3.0-or-later
// push_mode.dart - what is left of the old wake-up modes: the broom.
// an ntfy mode used to sit here. it held a websocket to a public server
// from dart, outside the engine and outside tor, so that server saw the
// phone's address for as long as the app ran, and the ping it waited for
// did nothing. it also had every message carry a url for the other side to
// ping, which meant a contact could make this phone call any address they
// liked. it is gone, and so is the picker that offered it next to a google
// mode that never existed. how messages arrive is delivery_mode.dart now.

import 'package:shared_preferences/shared_preferences.dart';

/// what the old modes left in the prefs: the ntfy topic and server, a url
/// for every contact who ever sent one, and the mode key itself. run once
/// at boot, and again after a restore, since old backups carry the key.
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
