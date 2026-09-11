// SPDX-License-Identifier: GPL-3.0-or-later
// the one link preview setting: whether the add-preview control is offered
// to the sender. off by default, since it costs the sender a request over
// tor. the reader's phone has no setting because it never fetches.
import 'package:shared_preferences/shared_preferences.dart';

const _sendKey = 'kryfo.linkpreviews.send';
bool sendLinkPreviews = false;

Future<void> loadLinkPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  sendLinkPreviews = prefs.getBool(_sendKey) ?? false;
}

Future<void> saveSendLinkPreviews(bool on) async {
  sendLinkPreviews = on;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_sendKey, on);
}
