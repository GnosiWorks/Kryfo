// SPDX-License-Identifier: GPL-3.0-or-later
// which chat is on screen, and opening one from a notification

part of '../main.dart';

// opens a room on the root navigator, a beat later: whoever asked for the
// join is a sheet or a screen about to close itself, and a room pushed
// before that close would be the thing that got closed.
void openRoomSoon(String groupId) {
  Future.delayed(
    const Duration(milliseconds: 450),
    // one of a kind only while it waits for the lock: opened by hand twice
    // in a row, it opens twice
    () => lockGuard.afterUnlock(
      key: lockGuard.isLocked() ? 'room:$groupId' : null,
      () async {
        final nav = rootNavKey.currentState;
        if (nav == null || !await session.groupExists(groupId)) return;
        if (backToOpenGroup(nav, groupId)) return;
        nav.push(haloRoute(GroupChatScreen(groupId: groupId)));
      },
    ),
  );
}

// a link naming the developer's own key opens his chat, a beat later, as a
// room link does. tests watch it here
@visibleForTesting
void Function(String chatId) openDevChatLater = _openChatSoon;

// someone added from a link or a code: their chat opens a beat later, as
// his does. tests watch it here
@visibleForTesting
void Function(String haloId) openAddedChatLater = _openChatSoon;

void _openChatSoon(String chatId) {
  Future.delayed(
    const Duration(milliseconds: 450),
    () => openChatForHalo(chatId),
  );
}

// someone added whose chat is in his inbox: a beat later, once the add's
// own sheet or screen has closed, he is asked where it goes. tests watch
// it here
@visibleForTesting
void Function(String haloId) askInboxMove = _askInboxMoveSoon;

void _askInboxMoveSoon(String haloId) {
  unawaited(() async {
    // once the add's screen or sheet is gone: asked over it, its own close
    // would close the question instead. a few seconds at most
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!(rootNavKey.currentState?.canPop() ?? false)) break;
    }
    await lockGuard.afterUnlock(key: 'inbox-move:$haloId', () async {
      final ctx = rootNavKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await askMoveIntoChats(ctx, haloId);
    });
  }());
}

// what a room says once its creator lets this phone in. tests listen here
@visibleForTesting
void Function(String line) sayRoomJoined = _sayLinkResult;

// what a link opened from outside the app came to, so an expired or full
// room does not look like nothing happening
void _sayLinkResult(String result) {
  final ctx = rootNavKey.currentContext;
  if (ctx != null && ctx.mounted) showHaloToast(ctx, result);
}

// a notification tap, warm or cold start, opens the chat once the app lock
// is open
Future<void> openChatForHalo(String? haloId) =>
    lockGuard.afterUnlock(() => _openChatFor(haloId), key: 'chat:$haloId');

// a tapped notification names its chat by tag only. the tag is read once
// the app lock is open, in the containers of the session it opened to
Future<void> openChatForNotif(String? tag, [int? id]) async {
  if (tag == null || tag.isEmpty) return;
  await lockGuard.afterUnlock(() async {
    final chat = await notifChatFor(tag);
    if (chat == null) return;
    // the message it rang for, kept here by its id. with none the chat
    // opens at its newest, where the line and the new messages show
    String? uid;
    if (id != null) {
      try {
        uid = await session.ringOf(id, chat);
      } catch (e) {
        dlog('notif tap: ring not read (${e.runtimeType})');
      }
    }
    await openNotifChat(chat, uid);
  }, key: 'notif:$tag');
}

// what a resolved tap opens, on the message it rang for. tests watch it
// here
@visibleForTesting
Future<void> Function(String chat, String? uid) openNotifChat = _openChatFor;

// the support summary's payload is the inbox itself, the same on every post
@visibleForTesting
Future<String?> notifChatFor(String tag) async {
  if (tag == kSupportPayload) return tag;
  try {
    return await session.chatOfNotifTag(tag);
  } catch (e) {
    dlog('notif tap: not read (${e.runtimeType})');
    return null;
  }
}

// what a tapped notification opens in the session on screen: a group or
// room, the requests for someone not yet let in, or an accepted chat
sealed class NotifTarget {
  const NotifTarget();
}

class NotifGroup extends NotifTarget {
  const NotifGroup(this.groupId);
  final String groupId;
}

class NotifRequests extends NotifTarget {
  const NotifRequests();
}

class NotifChat extends NotifTarget {
  const NotifChat(this.row);
  final Map<String, Object?> row;
}

// null when the chat is gone, is not this session's, or is the one open
@visibleForTesting
Future<NotifTarget?> notifTargetFor(String payload) async {
  if (payload == currentChatPeer) return null;
  if (payload.startsWith('group:')) {
    final id = payload.substring('group:'.length);
    if (id.isEmpty || !await session.groupExists(id)) return null;
    return NotifGroup(id);
  }
  final rows = await session.contacts();
  final row = rows.where((r) => r['halo_id'] == payload).firstOrNull;
  if (row != null) return NotifChat(row);
  // a request is read and answered on its own screen, where the shield is
  final c = await session.getContact(payload);
  if (c == null || (c['blocked'] as int? ?? 0) == 1) return null;
  // a deleted chat is in no list until they write again
  if ((c['archived'] as int? ?? 0) == 1) return null;
  if ((c['accepted'] as int? ?? 0) != 1) return const NotifRequests();
  return null;
}

Future<void> _openChatFor(String? haloId, [String? uid]) async {
  if (haloId == null || haloId.isEmpty) return;
  final nav = rootNavKey.currentState;
  if (nav == null) return;
  // the developer's own phone: its support inbox, or one of its chats
  if (haloId.startsWith(kSupportPayload)) {
    return openSupportTap(nav, haloId.substring(kSupportPayload.length));
  }
  // the developer chat has its own door, and only while it is there
  if (isDevChat(haloId)) {
    if (haloId == currentChatPeer) return;
    if ((await session.devChat.load())?.chatId != haloId) return;
    nav.push(devChatRoute(haloId, jumpToUid: uid));
    return;
  }
  final target = await notifTargetFor(haloId);
  if (target == null) return;
  final Map<String, Object?> row;
  switch (target) {
    // one already open is gone back to, never stacked twice
    case NotifGroup(:final groupId):
      if (!backToOpenGroup(nav, groupId)) {
        nav.push(haloRoute(GroupChatScreen(groupId: groupId, jumpToUid: uid)));
      }
      return;
    case NotifRequests():
      if (!backToRequests(nav)) nav.push(haloRoute(const RequestsScreen()));
      return;
    case NotifChat(row: final r):
      row = r;
  }
  nav.push(
    haloRoute(
      ChatScreen(
        peerHaloId: haloId,
        peerOnion: row['onion'] as String,
        peerXPub: row['xpub'] as String,
        avatarSeed: haloId,
        avatarChoice: (row['avatar'] as num?)?.toInt(),
        nickname: row['nickname'] as String?,
        jumpToUid: uid,
      ),
    ),
  );
}

// the chat or group whose screen is open ('group:<id>' for a group), as the
// screens report it, and the container of the session it is open in
String? _chatOnScreen;
HaloContainer? _chatOnScreenIn;

// the chat being read: the one on screen, and only while the lock is down.
// a message for it is marked read and its notification suppressed, so under
// the lock there is none
String? get currentChatPeer => lockGuard.isLocked() ? null : _chatOnScreen;

void claimChat(String id) {
  _chatOnScreen = id;
  _chatOnScreenIn = session.container;
  appState.chatFirst(id);
}

void releaseChat(String id) {
  if (_chatOnScreen != id) return;
  _chatOnScreen = null;
  _chatOnScreenIn = null;
  appState.chatFirst(null);
}

// whether [id] is being read where the rows of [c] show: the chat on
// screen, in a session that holds [c]. the same id in another container is
// another chat
bool readingIn(String id, HaloContainer c) {
  final open = _chatOnScreenIn;
  return currentChatPeer == id &&
      open != null &&
      (c == open || c.extended == open);
}

// the root navigator. each session gets its own: switching sessions under
// the lock swaps the key, and every route, popping route, hero flight, toast
// and menu of the other session goes with the old navigator at once
GlobalKey<NavigatorState> _rootNavKey = GlobalKey<NavigatorState>();
GlobalKey<NavigatorState> get rootNavKey => _rootNavKey;
final navRevision = ValueNotifier<int>(0);

void renewRootNavigator() {
  haloClearToasts();
  WallImages.clear();
  _rootNavKey = GlobalKey<NavigatorState>();
  navRevision.value++;
}

@visibleForTesting
Future<void> openFromNotifForTest() => _openFromNotif();

Future<void> _openFromNotif() async {
  try {
    final details = await notifPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details?.notificationResponse?.payload;
      final id = details?.notificationResponse?.id;
      Future.delayed(
        const Duration(milliseconds: 500),
        () => openChatForNotif(payload, id),
      );
    }
  } catch (e) {
    dlog('notif launch: $e');
  }
}
