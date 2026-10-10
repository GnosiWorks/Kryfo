// SPDX-License-Identifier: GPL-3.0-or-later
// the forward picker: the chats words can go to, those held marked and
// asked about before anything goes to them. a forward and words shared from
// another app both pick here, and both land in a composer, never sent
import 'package:flutter/material.dart';

import '../devchat/dev_chat.dart' show DevRow;
import '../devchat/dev_key.dart' show isDevChat;
import '../l10n/l10n.dart';
import '../main.dart' show appState, session;
import '../theme.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/key_held.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import 'chat_screen.dart';
import 'dev_about_sheet.dart' show DevForwardTile, devChatRoute, devSlot;

/// the chat picked, once a held one's way out was taken. null when none
/// was. [words], when given, are shown above the list. [onSheet] hears the
/// sheet's own context
Future<String?> pickWordsChat(
  BuildContext context, {
  required String title,
  required String empty,
  DevRow? dev,
  String? words,
  void Function(BuildContext sheet)? onSheet,
}) async {
  final targets = appState.contacts.where((c) => !c.blocked).toList();
  // who is held is marked, and picked asks for the way out first
  final held = await keysHeldShown();
  if (!context.mounted) return null;
  final devAt = dev == null ? -1 : devSlot(dev, targets);
  final id = await showHaloSheet<String>(
    context,
    builder: (ctx) {
      onSheet?.call(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                title,
                style: HaloType.serif(
                  size: 18,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
            ),
            if (words != null) _WordsCard(words: words),
            if (targets.isEmpty && dev == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  empty,
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
              )
            else
              // the sheet scrolls as one, so the list is laid out in full
              // and does not scroll on its own
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final (i, c) in targets.indexed) ...[
                    if (i == devAt)
                      DevForwardTile(
                        onTap: () => Navigator.pop(ctx, dev!.chatId),
                      ),
                    PressScale(
                      scale: 0.98,
                      onTap: () => Navigator.pop(ctx, c.haloId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            KryfoAvatar(
                              seed: c.avatarSeed,
                              size: 32,
                              choice: c.avatar,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.nickname ?? c.haloId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: HaloType.sans(
                                      size: 14,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  KeyHeldMark(on: held.contains(c.haloId)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (devAt == targets.length)
                    DevForwardTile(
                      onTap: () => Navigator.pop(ctx, dev!.chatId),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );
  if (id == null || !context.mounted) return null;
  if (held.contains(id)) {
    final c = targets.where((c) => c.haloId == id).firstOrNull;
    final name = c?.nickname ?? id;
    if (!await showKeyHeldSheet(context, id, name)) return null;
  }
  return id;
}

/// the chat [id] opens on, [words] under what its composer already holds
Future<Route<void>?> wordsRoute(String id, String words) async {
  if (isDevChat(id)) return devChatRoute(id, initialText: words);
  final row = await session.getContact(id);
  if (row == null) return null;
  return haloRoute<void>(
    ChatScreen(
      peerHaloId: id,
      peerOnion: (row['onion'] as String?) ?? '',
      peerXPub: (row['xpub'] as String?) ?? '',
      avatarSeed: id,
      avatarChoice: (row['avatar'] as num?)?.toInt(),
      initialText: words,
    ),
  );
}

// what was shared, as it will land: a few lines, in its own direction
class _WordsCard extends StatelessWidget {
  const _WordsCard({required this.words});
  final String words;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: HaloColors.surface3,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: HaloColors.amber,
                child: const SizedBox(width: 2),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Text(
                    words,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textDirection: writtenDir(words),
                    style: HaloType.sans(size: 13, color: HaloColors.text2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
