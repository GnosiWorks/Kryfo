// SPDX-License-Identifier: GPL-3.0-or-later
// whether android is letting kryfo put a notification up, and the way back
// to the page that decides it.
//
// a messenger whose notifications are blocked looks broken rather than
// quiet: nothing arrives while it is closed and nothing says why. on
// android 13 and up the permission dialog does not come back once the
// answer is final, so the only way to change it is android's own page.
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('halo/platform');
const _dismissedKey = 'notif_blocked_hint_dismissed';

Future<bool> notificationsEnabled() async {
  try {
    return await _channel.invokeMethod<bool>('notificationsEnabled') ?? true;
  } catch (_) {
    // an older android, or no channel yet: say yes rather than cry wolf
    return true;
  }
}

// false when neither android's notification page nor the app details page
// would open, and the caller has to say so
Future<bool> openNotificationSettings() async {
  try {
    return await _channel.invokeMethod<bool>('openNotificationSettings') ??
        false;
  } catch (_) {
    return false;
  }
}

Future<bool> notifHintDismissed() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_dismissedKey) ?? false;
}

Future<void> dismissNotifHint() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_dismissedKey, true);
}

// turning them back on clears the dismissal, so a later block says so again
Future<void> clearNotifHintDismissal() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_dismissedKey);
}
