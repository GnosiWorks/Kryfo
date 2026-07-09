// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../main.dart' show appState;

// lists contacts you have blocked. unblock restores them to your chats and
// lets their messages through again. blocking never notifies the other side.
class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  List<({String haloId, String? nickname})> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await appState.blockedContacts();
    if (mounted) {
      setState(() {
        _blocked = list;
        _loading = false;
      });
    }
  }

  Future<void> _unblock(String haloId) async {
    await appState.unblock(haloId);
    await _load();
  }

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
                    'blocked',
                    style: HaloType.serif(size: 22, color: HaloColors.text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const SizedBox()
                  : _blocked.isEmpty
                  ? Center(
                      child: Text(
                        'no one is blocked',
                        style: HaloType.serif(
                          size: 18,
                          italic: true,
                          color: HaloColors.text2,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final (i, c) in _blocked.indexed)
                          StaggerIn(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.nickname ?? c.haloId,
                                          style: HaloType.sans(
                                            size: 14,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                        if (c.nickname != null)
                                          Text(
                                            c.haloId,
                                            style: HaloType.mono(
                                              size: 10,
                                              color: HaloColors.text3,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _unblock(c.haloId),
                                    child: Text(
                                      'unblock',
                                      style: HaloType.sans(
                                        size: 13,
                                        weight: FontWeight.w500,
                                        color: HaloColors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
