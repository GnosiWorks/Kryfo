// group info / settings. shows: name (edit if admin), member list, add
// member (admin), remove member (admin), leave group (everyone).

import 'package:flutter/material.dart';
import '../main.dart' show appState, db;
import '../theme.dart';
import '../widgets/halo_avatar.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});
  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  String _name = '';
  bool _isAdmin = false;
  List<String> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await db.getGroup(widget.groupId);
    final members = await db.getGroupMembers(widget.groupId);
    if (!mounted) return;
    setState(() {
      _name = (g?['name'] as String?) ?? 'group';
      _isAdmin = ((g?['is_admin'] as int?) ?? 0) == 1;
      _members = members;
      _loading = false;
    });
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: HaloColors.surface2,
        title: Text(
          'rename group',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: HaloType.sans(size: 14, color: HaloColors.text),
          cursorColor: HaloColors.amber,
          decoration: const InputDecoration(border: UnderlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              'cancel',
              style: HaloType.sans(size: 13, color: HaloColors.text2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: Text(
              'save',
              style: HaloType.sans(size: 13, color: HaloColors.amber),
            ),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != _name) {
      await appState.renameGroupAndAnnounce(widget.groupId, newName);
      await _load();
    }
  }

  Future<void> _addMembers() async {
    final available = appState.contacts
        .where((c) => !_members.contains(c.haloId))
        .toList();
    if (available.isEmpty) {
      showHaloToast(context, 'no contacts to add');
      return;
    }
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: HaloColors.surface2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => _AddMemberSheet(available: available),
    );
    if (picked != null && picked.isNotEmpty) {
      await appState.addMembersToGroup(widget.groupId, picked.toList());
      await _load();
    }
  }

  Future<void> _confirmRemove(String haloId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: HaloColors.surface2,
        title: Text(
          'remove $haloId?',
          style: HaloType.serif(size: 16, italic: true, color: HaloColors.text),
        ),
        content: Text(
          'they will stop receiving messages from this group.',
          style: HaloType.sans(size: 13, color: HaloColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'cancel',
              style: HaloType.sans(size: 13, color: HaloColors.text2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              'remove',
              style: HaloType.sans(size: 13, color: HaloColors.rose),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await appState.removeMembersFromGroup(widget.groupId, [haloId]);
      await _load();
    }
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: HaloColors.surface2,
        title: Text(
          'leave group?',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
        content: Text(
          'you will stop receiving messages and other members will see you leave.',
          style: HaloType.sans(size: 13, color: HaloColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'cancel',
              style: HaloType.sans(size: 13, color: HaloColors.text2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              'leave',
              style: HaloType.sans(size: 13, color: HaloColors.rose),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await appState.leaveGroupAndAnnounce(widget.groupId);
      if (!mounted) return;
      // pop info + chat in one go
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: HaloColors.surface,
        body: Center(child: CircularProgressIndicator(color: HaloColors.amber)),
      );
    }
    final myId = appState.myId;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // header
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
                      'group info',
                      style: HaloType.serif(
                        size: 18,
                        italic: true,
                        color: HaloColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // big group identity
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: HaloColors.amberSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: HaloColors.amber.withOpacity(0.45),
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _name.isEmpty
                          ? '·'
                          : _name.characters.first.toUpperCase(),
                      style: HaloType.serif(
                        size: 36,
                        italic: true,
                        color: HaloColors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _isAdmin ? _rename : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _name,
                          style: HaloType.serif(
                            size: 22,
                            italic: true,
                            color: HaloColors.text,
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: HaloColors.text3,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_members.length} members',
                    style: HaloType.mono(
                      size: 11,
                      color: HaloColors.text3,
                      letter: 0.1,
                    ),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 4),
                    Text(
                      'admin',
                      style: HaloType.mono(
                        size: 10,
                        color: HaloColors.amber,
                        letter: 0.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // members header + add button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                  if (_isAdmin)
                    GestureDetector(
                      onTap: _addMembers,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: HaloColors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'add',
                            style: HaloType.mono(
                              size: 10,
                              color: HaloColors.amber,
                              letter: 0.14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (_, i) {
                  final m = _members[i];
                  final isMe = m == myId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        HaloAvatar(seed: m, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m,
                                style: HaloType.sans(
                                  size: 14,
                                  weight: FontWeight.w500,
                                  color: HaloColors.text,
                                ),
                              ),
                              if (isMe)
                                Text(
                                  'you',
                                  style: HaloType.mono(
                                    size: 10,
                                    color: HaloColors.amber,
                                    letter: 0.3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_isAdmin && !isMe)
                          IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                              color: HaloColors.text3,
                            ),
                            onPressed: () => _confirmRemove(m),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // leave (everyone)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: GestureDetector(
                onTap: _confirmLeave,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HaloColors.rose.withOpacity(0.4),
                      width: 0.6,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'leave group',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: HaloColors.rose,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberSheet extends StatefulWidget {
  final List available;
  const _AddMemberSheet({required this.available});
  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final Set<String> _picked = {};
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: HaloColors.line2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 20),
              Text(
                'add members',
                style: HaloType.serif(
                  size: 16,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.pop(context, _picked),
                child: Text(
                  'add ${_picked.length}',
                  style: HaloType.sans(
                    size: 13,
                    color: _picked.isEmpty
                        ? HaloColors.text3
                        : HaloColors.amber,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.available.length,
              itemBuilder: (_, i) {
                final c = widget.available[i];
                final picked = _picked.contains(c.haloId);
                return InkWell(
                  onTap: () => setState(() {
                    if (picked) {
                      _picked.remove(c.haloId);
                    } else {
                      _picked.add(c.haloId);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        HaloAvatar(seed: c.avatarSeed, size: 32),
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
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: picked
                                ? HaloColors.amber
                                : Colors.transparent,
                            border: Border.all(
                              color: picked
                                  ? HaloColors.amber
                                  : HaloColors.line2,
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: picked
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 12,
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
