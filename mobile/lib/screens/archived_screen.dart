// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/halo_avatar.dart';
import '../main.dart' show appState;

// chats you have archived. they are hidden from the main list but still
// receive normally. unarchive brings them back to the top level.
class ArchivedScreen extends StatelessWidget {
  const ArchivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: HaloColors.text2,
                      size: 26,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'archived',
                    style: HaloType.serif(size: 22, color: HaloColors.text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: appState,
                builder: (_, __) {
                  final archived = appState.contacts
                      .where((c) => c.archived)
                      .toList();
                  if (archived.isEmpty) {
                    return Center(
                      child: Text(
                        'nothing archived',
                        style: HaloType.serif(
                          size: 18,
                          italic: true,
                          color: HaloColors.text2,
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final c in archived)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Opacity(
                                opacity: 0.85,
                                child: HaloAvatar(seed: c.avatarSeed, size: 36),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    if (c.preview != null &&
                                        c.preview!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        c.preview!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: HaloType.sans(
                                          size: 12,
                                          color: HaloColors.text2,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => appState.unarchive(c.haloId),
                                child: Text(
                                  'unarchive',
                                  style: HaloType.sans(
                                    size: 12.5,
                                    weight: FontWeight.w500,
                                    color: HaloColors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
