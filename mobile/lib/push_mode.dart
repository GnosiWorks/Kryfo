// push_mode.dart — how halo gets woken up to receive messages.
// only PushMode.tor is wired in phase 1. fcm and unifiedPush are stubs
// until sprints 11 and 12 ship.

import 'package:shared_preferences/shared_preferences.dart';

enum PushMode { tor, fcm, unifiedPush }

const _prefKey = 'push_mode';

Future<PushMode> loadPushMode() async {
  final prefs = await SharedPreferences.getInstance();
  switch (prefs.getString(_prefKey)) {
    case 'fcm':
      return PushMode.fcm;
    case 'unifiedPush':
      return PushMode.unifiedPush;
    default:
      return PushMode.tor;
  }
}

Future<void> savePushMode(PushMode m) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefKey, m.name);
}
