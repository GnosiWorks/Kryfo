// SPDX-License-Identifier: GPL-3.0-or-later
// into a chat from a list of its messages or its people: a group, the
// developer chat or a person's own, landing on one message when asked
import 'package:flutter/material.dart';

import '../devchat/dev_key.dart' show isDevChat;
import '../main.dart' show appState, session;
import '../widgets/motion.dart' show haloRoute;
import 'chat_screen.dart';
import 'dev_about_sheet.dart' show devChatRoute;
import 'group_chat_screen.dart';

// a page that stands in for the chat, which needs the engine
@visibleForTesting
Widget Function({String? groupId, String? peer, String? uid})? chatPageForTest;

// false when there is no such chat on this phone any more
Future<bool> openChatAt(
  BuildContext context, {
  String? groupId,
  String? peer,
  String? uid,
}) async {
  final nav = Navigator.of(context);
  final group = groupId != null && groupId.isNotEmpty ? groupId : null;
  final Route<void> route;
  if (group != null) {
    if (!await session.groupExists(group)) return false;
    route = haloRoute(GroupChatScreen(groupId: group, jumpToUid: uid));
  } else if (peer == null || peer.isEmpty) {
    return false;
  } else if (isDevChat(peer)) {
    if (appState.devRow?.chatId != peer) return false;
    route = devChatRoute(peer, jumpToUid: uid);
  } else {
    final rows = await session.contacts();
    final row = rows.where((r) => r['halo_id'] == peer).firstOrNull;
    if (row == null) return false;
    route = haloRoute(
      ChatScreen(
        peerHaloId: peer,
        peerOnion: (row['onion'] as String?) ?? '',
        peerXPub: (row['xpub'] as String?) ?? '',
        avatarSeed: peer,
        avatarChoice: (row['avatar'] as num?)?.toInt(),
        jumpToUid: uid,
      ),
    );
  }
  final stand = chatPageForTest;
  nav.push(
    stand == null
        ? route
        : haloRoute(stand(groupId: group, peer: peer, uid: uid)),
  );
  return true;
}
