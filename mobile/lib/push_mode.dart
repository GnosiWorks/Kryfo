// SPDX-License-Identifier: GPL-3.0-or-later
// push_mode.dart - how kryfo gets woken up to receive messages.
// there is one way: the app polls over tor. an ntfy mode used to sit here.
// it held a websocket to a public server from dart, outside the engine and
// outside tor, so that server saw the phone's address for as long as the
// app ran, and the ping it waited for did nothing. it also had every
// message carry a url for the other side to ping, which meant a contact
// could make this phone call any address they liked. it is gone. if push
// comes back it goes through the engine, over tor, or not at all.
// fcm is deferred until a play-store variant and cannot be picked.

import 'package:shared_preferences/shared_preferences.dart';

enum PushMode { tor, fcm }

const _modeKey = 'push_mode';

Future<PushMode> loadPushMode() async {
  final prefs = await SharedPreferences.getInstance();
  // 'ntfy' and the older 'unifiedPush' both land on tor now
  return prefs.getString(_modeKey) == 'fcm' ? PushMode.fcm : PushMode.tor;
}

Future<void> savePushMode(PushMode m) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_modeKey, m.name);
}

/// what the ntfy mode left in the prefs: its topic, its server, and a url
/// for every contact who ever sent one. run once at boot.
Future<void> forgetNtfy() async {
  final prefs = await SharedPreferences.getInstance();
  for (final k in prefs.getKeys().toList()) {
    if (k == 'ntfy_topic' ||
        k == 'ntfy_server' ||
        k.startsWith('ntfy_peer_endpoint_')) {
      await prefs.remove(k);
    }
  }
  final m = prefs.getString(_modeKey);
  if (m == 'ntfy' || m == 'unifiedPush') await prefs.remove(_modeKey);
}
