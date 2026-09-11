// SPDX-License-Identifier: GPL-3.0-or-later
// how link previews behave. decided once, the first time a link is tapped,
// and changeable in settings. null means nobody has been asked yet.
import 'package:shared_preferences/shared_preferences.dart';

enum LinkPreviewMode { auto, onTap, off }

const _key = 'kryfo.linkpreviews';

LinkPreviewMode? linkPreviewMode;

// the sender side: whether the add-preview control is offered at all.
// off by default, since it costs the sender a request over tor
const _sendKey = 'kryfo.linkpreviews.send';
bool sendLinkPreviews = false;

Future<void> saveSendLinkPreviews(bool on) async {
  sendLinkPreviews = on;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_sendKey, on);
}

Future<LinkPreviewMode?> loadLinkPreviewMode() async {
  final prefs = await SharedPreferences.getInstance();
  sendLinkPreviews = prefs.getBool(_sendKey) ?? false;
  final s = prefs.getString(_key);
  linkPreviewMode = switch (s) {
    'auto' => LinkPreviewMode.auto,
    'tap' => LinkPreviewMode.onTap,
    'off' => LinkPreviewMode.off,
    _ => null,
  };
  return linkPreviewMode;
}

Future<void> saveLinkPreviewMode(LinkPreviewMode m) async {
  linkPreviewMode = m;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, switch (m) {
    LinkPreviewMode.auto => 'auto',
    LinkPreviewMode.onTap => 'tap',
    LinkPreviewMode.off => 'off',
  });
}

String linkPreviewLabel(LinkPreviewMode? m) => switch (m) {
  LinkPreviewMode.auto => 'automatic',
  LinkPreviewMode.onTap => 'when i tap',
  LinkPreviewMode.off => 'off',
  null => 'not chosen yet',
};
