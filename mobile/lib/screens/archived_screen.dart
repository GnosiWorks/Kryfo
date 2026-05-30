import 'package:flutter/material.dart';
import '../theme.dart';
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
                    icon: const Icon(Icons.chevron_left,
                        color: HaloColors.text2, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text('archived',
                      style: HaloType.serif(size: 22, color: HaloColors.text)),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: appState,
                builder: (_, __) {
                  final archived =
                      appState.contacts.where((c) => c.archived).toList();
                  if (archived.isEmpty) {
                    return Center(
                      child: Text('nothing archived',
                          style: HaloType.serif(
                              size: 18,
                              italic: true,
                              color: HaloColors.text2)),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final c in archived)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(c.nickname ?? c.haloId,
                                    style: HaloType.sans(
                                        size: 14, weight: FontWeight.w500)),
                              ),
                              TextButton(
                                onPressed: () => appState.unarchive(c.haloId),
                                child: Text('unarchive',
                                    style: HaloType.sans(
                                        size: 13,
                                        weight: FontWeight.w500,
                                        color: HaloColors.amber)),
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
