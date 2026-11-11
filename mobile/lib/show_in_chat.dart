// SPDX-License-Identifier: GPL-3.0-or-later
// "Show in chat" from the shared page: the chat it came from takes the
// pages above it down and goes to the message. only a chat that is open
// under the page answers, so the menu offers it only then
import 'package:flutter/foundation.dart';

/// the chats on screen now, by id, each as often as it is open
final Map<String, int> _open = {};

void chatShown(String id) => _open[id] = (_open[id] ?? 0) + 1;

void chatGone(String id) {
  final n = (_open[id] ?? 1) - 1;
  if (n <= 0) {
    _open.remove(id);
  } else {
    _open[id] = n;
  }
}

/// a chat [id] is open under whatever is on top
bool chatOpenUnder(String id) => _open.containsKey(id);

/// the message a chat is asked to show: its chat's id and its uid
final ValueNotifier<({String chat, String uid})?> showInChat = ValueNotifier(
  null,
);

void askShowInChat(String chat, String uid) =>
    showInChat.value = (chat: chat, uid: uid);
