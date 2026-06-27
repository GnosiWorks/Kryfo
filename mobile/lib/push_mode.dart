// push_mode.dart - how halo gets woken up to receive messages.
// only PushMode.tor is fully wired today. ntfy ships in sprint 11.
// fcm is deferred until a play-store variant.

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

enum PushMode { tor, fcm, ntfy }

const _modeKey = 'push_mode';
const _serverKey = 'ntfy_server';
const _topicKey = 'ntfy_topic';
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

// ntfy topic: 32 hex chars from Random.secure. unguessable, so even
// though ntfy.sh topics are public, randomness keeps the channel private.
Future<String> loadNtfyTopic() async {
  final prefs = await SharedPreferences.getInstance();
  var t = prefs.getString(_topicKey);
  if (t == null || t.isEmpty) {
    t = _generateTopic();
    await prefs.setString(_topicKey, t);
  }
  return t;
}

Future<void> clearNtfyTopic() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_topicKey);
}

String _generateTopic() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String composeNtfyEndpoint(String server, String topic) {
  final s = server.endsWith('/') ? server.substring(0, server.length - 1) : server;
  return '$s/$topic';
}
