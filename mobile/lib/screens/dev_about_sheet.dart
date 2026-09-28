// SPDX-License-Identifier: GPL-3.0-or-later
// the developer chat as the screens reach it: the one door into its chat,
// its flags and its delete, the settings entry, and the sheet that says who
// Marios is and which key every message is checked against. his three words
// are shown here like anyone's, and nothing trusts them
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../devchat/dev_chat.dart' show DevRow, devModeOf;
import '../devchat/dev_key.dart';
import '../devchat/dev_start.dart' show forgetDevChoices;
import '../l10n/l10n.dart';
import '../main.dart' show appState, session, sessionQuiet;
import '../notifications.dart' show clearNotificationsFor;
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/dev_avatar.dart';
import '../widgets/halo_rows.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/stagger_in.dart';
import 'chat_screen.dart';
import 'home_screen.dart' show ContactPreview;

// a key is pinned and this is not the developer's own phone. a decoy is
// never his
bool get devChatOffered =>
    currentDevKey != null && (sessionQuiet || !devModeOf(appState.myXPub));

// the one door into the chat's screen, so what the chat does on its own
// lands in one place
Route<void> devChatRoute(
  String chatId, {
  String? initialText,
  String? jumpToUid,
}) {
  final key = devKeyById(chatId.substring('dev:'.length));
  return haloRoute(
    devChatPageForTest?.call(chatId, initialText) ??
        ChatScreen(
          peerHaloId: chatId,
          peerOnion: '',
          peerXPub: key?.xPub ?? '',
          avatarSeed: chatId,
          initialText: initialText,
          jumpToUid: jumpToUid,
        ),
  );
}

// a page that stands in for the chat, which needs the engine
@visibleForTesting
Widget Function(String chatId, String? initialText)? devChatPageForTest;

Future<void> openDevChat(
  BuildContext context,
  String chatId, {
  String? initialText,
  String? jumpToUid,
}) => Navigator.of(
  context,
).push(devChatRoute(chatId, initialText: initialText, jumpToUid: jumpToUid));

// before the first send the flags are the chat's own row, after it its
// contact row. either way home reads them back
Future<void> setDevMuted(bool on) => _flag(session.devChat.setMuted(on));
Future<void> setDevPinned(bool on) => _flag(session.devChat.setPinned(on));
Future<void> setDevArchived(bool on) => _flag(session.devChat.setArchived(on));

Future<void> _flag(Future<bool> set) async {
  await set;
  await appState.refreshContacts();
}

// deleted means gone: asked once, then every message of it and the chat
// itself go, and only the settings row brings a fresh one back
Future<bool> deleteDevChat(BuildContext context, DevRow d) async {
  final ok = await showConfirmSheet(
    context,
    title: l10n.homeDeleteThisChat,
    line: d.anonymous ? l10n.devDeleteLineAnon : l10n.devDeleteLine,
    yes: l10n.commonDelete,
  );
  if (!ok) return false;
  HapticFeedback.heavyImpact();
  await _gone(d.chatId);
  return true;
}

// the rows, and what the wire still held for it
Future<void> _gone(String chatId) async {
  await appState.devDelete();
  // a chat made again later starts with the three words
  forgetDevChoices();
  unawaited(clearNotificationsFor(chatId));
  await appState.refreshContacts();
}

// a chat restored without the name it was made with only reads: asked once,
// it goes and a fresh one takes its place, on this tap. the chat to open,
// or null when kept
Future<String?> startNewDevChat(BuildContext context, String chatId) async {
  final ok = await showConfirmSheet(
    context,
    title: l10n.homeDeleteThisChat,
    line: l10n.devStartNewLine,
    yes: l10n.devStartNewChat,
  );
  if (!ok) return null;
  HapticFeedback.heavyImpact();
  await _gone(chatId);
  final id = await session.devChat.writeToMarios();
  await appState.refreshContacts();
  return id;
}

// the settings row: the chat as it is, or after a delete a fresh one, made
// on this tap only
Future<void> writeToMarios(BuildContext context) async {
  final id = await session.devChat.writeToMarios();
  await appState.refreshContacts();
  if (id == null || !context.mounted) return;
  await openDevChat(context, id);
}

// a forward lands only in a chat that has started, so it never skips what
// the chat says before the first send. a retired key takes nothing, and
// nor does a chat that only reads
DevRow? get devForwardTarget {
  final d = appState.devRow;
  if (d == null ||
      !d.started ||
      d.nameless ||
      d.status == DevKeyStatus.retired) {
    return null;
  }
  return d;
}

// the developer chat as a forward target, the same row in every sheet
class DevForwardTile extends StatelessWidget {
  const DevForwardTile({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            const DevAvatar(size: 32, tick: false),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.devRowTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HaloType.sans(size: 14, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// where the row goes among chats kept pinned first, then newest first
int devSlot(DevRow d, List<ContactPreview> chats) {
  if (d.pinned) return 0;
  final at = d.when;
  for (var i = 0; i < chats.length; i++) {
    final c = chats[i];
    if (c.pinned) continue;
    if (at != null && (c.when ?? DateTime(0)).isBefore(at)) return i;
  }
  return chats.length;
}

// a key as it is checked on the website: sixteen groups of four, read left
// to right in every language
List<String> devFingerprint(String hex) => [
  for (var i = 0; i + 4 <= hex.length; i += 4) hex.substring(i, i + 4),
];

Future<void> showDevAboutSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  return showHaloSheet<void>(context, builder: (_) => const DevAboutSheet());
}

// who Marios is, the key the app was built with, and what can be done with
// the chat: mute, pin, archive, delete. no nickname and no block
class DevAboutSheet extends StatelessWidget {
  const DevAboutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final d = appState.devRow;
        // deleted while open: the sheet is on its way out
        if (d == null) return const SizedBox(width: double.infinity);
        return _About(d: d);
      },
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.d});
  final DevRow d;

  @override
  Widget build(BuildContext context) {
    final key = devKeyById(d.keyId);
    final still = motionStill(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 14),
            ...staggerAllIn(context, [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: still ? 1 : 0.85, end: 1),
                  duration: kHouseTime,
                  curve: kHouseCurve,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: const DevAvatar(size: 68, tick: false),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.devRowTitle,
                textAlign: TextAlign.center,
                style: HaloType.serif(size: 22, color: HaloColors.text),
              ),
              if (key != null) ...[
                const SizedBox(height: 5),
                Text(
                  key.threeWords,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: HaloType.mono(
                    size: 12.5,
                    color: HaloColors.amber,
                    letter: 0.04,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _Marks(anonymous: d.anonymous),
              const SizedBox(height: 14),
              Text(
                l10n.devAboutLine,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13.5,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
              if (key != null) ...[
                const SizedBox(height: 16),
                _KeyCard(xPub: key.xPub),
              ],
              const SizedBox(height: 16),
              _Actions(d: d),
            ]),
          ],
        ),
      ),
    );
  }
}

// pinned in the app, and anonymous when it started that way
class _Marks extends StatelessWidget {
  const _Marks({required this.anonymous});
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DevTick(size: 13, cut: HaloColors.surface2),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.devPinned,
                style: HaloType.mono(
                  size: 10.5,
                  color: HaloColors.amber,
                  letter: 0.3,
                ),
              ),
            ),
          ],
        ),
        if (anonymous)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: HaloColors.amberSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: HaloColors.amber.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            child: Text(
              l10n.devAnonymous,
              style: HaloType.mono(size: 10, color: HaloColors.amber),
            ),
          ),
      ],
    );
  }
}

// the pinned key, four groups to a line. mono and left to right, as the
// website prints it, so the two can be read side by side
class _KeyCard extends StatelessWidget {
  const _KeyCard({required this.xPub});
  final String xPub;

  @override
  Widget build(BuildContext context) {
    final groups = devFingerprint(xPub);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: HaloColors.surface3,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.devKeyLabel,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.text3,
              letter: 0.14,
            ),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                for (var at = 0; at < groups.length; at += 4)
                  Padding(
                    padding: EdgeInsets.only(top: at == 0 ? 0 : 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (
                            var i = at;
                            i < math.min(at + 4, groups.length);
                            i++
                          ) ...[
                            if (i > at) const SizedBox(width: 16),
                            // the groups come in in reading order
                            StaggerIn(
                              index: 2 + i ~/ 2,
                              child: Text(
                                groups[i],
                                style: HaloType.mono(
                                  size: 15,
                                  color: HaloColors.text,
                                  letter: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// what can be done with the chat, as rows: every language's longest words
// fit at every font size
class _Actions extends StatelessWidget {
  const _Actions({required this.d});
  final DevRow d;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HaloGroup(
          children: [
            HaloRow(
              icon: d.muted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_none,
              label: d.muted ? l10n.contactUnmute : l10n.contactMute,
              onTap: () {
                HapticFeedback.selectionClick();
                setDevMuted(!d.muted);
              },
            ),
            HaloRow(
              icon: d.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: d.pinned ? l10n.contactUnpin : l10n.contactPinToTop,
              onTap: () {
                HapticFeedback.selectionClick();
                setDevPinned(!d.pinned);
              },
            ),
            HaloRow(
              icon: d.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              label: d.archived ? l10n.archivedUnarchive : l10n.contactArchive,
              onTap: () async {
                final nav = Navigator.of(context);
                final was = d.archived;
                await setDevArchived(!was);
                // out of the list: back to it, as an archived chat is left
                if (!was) nav.popUntil((r) => r.isFirst);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // what cannot be taken back, apart and in rose
        HaloGroup(
          rose: true,
          children: [
            HaloRow(
              icon: Icons.delete_outline,
              label: l10n.contactDeleteChat,
              rose: true,
              onTap: () async {
                final nav = Navigator.of(context);
                if (await deleteDevChat(context, d)) {
                  nav.popUntil((r) => r.isFirst);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
