// push_mode.dart — how halo gets woken up to receive messages.
// only PushMode.tor is fully wired today. ntfy ships in sprint 11.
// fcm is deferred until a play-store variant.

import 'package:shared_preferences/shared_preferences.dart';

enum PushMode { tor, fcm, ntfy }

const _modeKey = 'push_mode';
const _serverKey = 'ntfy_server';
const defaultNtfyServer = 'https://ntfy.sh';

Future<PushMode> loadPushMode() async {
  final prefs = await SharedPreferences.getInstance();
  switch (prefs.getString(_modeKey)) {
    case 'fcm':
      return PushMode.fcm;
    case 'ntfy':
    case 'unifiedPush': // legacy key from earlier build
      return PushMode.ntfy;
    default:
      return PushMode.tor;
  }
}

Future<void> savePushMode(PushMode m) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_modeKey, m.name);
}

Future<String> loadNtfyServer() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_serverKey) ?? defaultNtfyServer;
}

Future<void> saveNtfyServer(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_serverKey, url);
}
