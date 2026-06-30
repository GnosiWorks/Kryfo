// SPDX-License-Identifier: GPL-3.0-or-later
// pick a name + members from your contacts and create a group locally.
// fires the create-and-announce flow on submit.

import 'package:flutter/material.dart';
import '../main.dart' show appState;
import '../theme.dart';
import '../widgets/halo_avatar.dart';
import 'group_chat_screen.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});
  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _nameCtrl = TextEditingController();
  final Set<String> _selected = {};
  bool _creating = false;

  bool get _canCreate =>
      _nameCtrl.text.trim().isNotEmpty && _selected.isNotEmpty && !_creating;

  Future<void> _create() async {
    setState(() => _creating = true);
    final groupId = await appState.createGroupAndAnnounce(
      _nameCtrl.text.trim(),
      _selected.toList(),
    );
    if (!mounted) return;
    // pop the picker, then push the group chat - the user lands inside
    // the group they just made, the way every other messenger does it.
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: groupId)),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = appState.contacts;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: HaloColors.text,
                      size: 26,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'new group',
                      style: HaloType.serif(
                        size: 18,
                        italic: true,
                        color: HaloColors.text,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _canCreate ? _create : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _canCreate
                            ? HaloColors.amber
                            : HaloColors.surface3,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _creating ? 'creating...' : 'create',
                        style: HaloType.sans(
                          size: 12,
                          weight: FontWeight.w500,
                          color: _canCreate
                              ? HaloColors.onAmber
                              : HaloColors.text3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                style: HaloType.sans(size: 16, color: HaloColors.text),
                cursorColor: HaloColors.amber,
                decoration: InputDecoration(
                  hintText: 'group name',
                  hintStyle: HaloType.serif(
                    size: 16,
                    italic: true,
                    color: HaloColors.text3,
                  ),
                  filled: true,
                  fillColor: HaloColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Row(
                children: [
                  Text(
                    'members',
                    style: HaloType.mono(
                      size: 10,
                      color: HaloColors.text3,
                      letter: 0.14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _selected.isEmpty
                        ? 'pick at least one'
                        : '${_selected.length} selected',
                    style: HaloType.mono(
                      size: 10,
                      color: HaloColors.text3,
                      letter: 0.14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: contacts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'add at least one contact first before creating a group.',
                          textAlign: TextAlign.center,
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text2,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (_, i) {
                        final c = contacts[i];
                        final picked = _selected.contains(c.haloId);
                        return InkWell(
                          onTap: () => setState(() {
                            if (picked) {
                              _selected.remove(c.haloId);
                            } else {
                              _selected.add(c.haloId);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                HaloAvatar(seed: c.avatarSeed, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    c.haloId,
                                    style: HaloType.sans(
                                      size: 14,
                                      weight: FontWeight.w500,
                                      color: HaloColors.text,
                                    ),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: picked
                                        ? HaloColors.amber
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: picked
                                          ? HaloColors.amber
                                          : HaloColors.line2,
                                      width: 1.4,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: picked
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: HaloColors.onAmber,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
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
