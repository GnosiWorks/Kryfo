// SPDX-License-Identifier: GPL-3.0-or-later
// group info / settings. shows: name (edit if admin), member list, add
// member (admin), remove member (admin), leave group (everyone).

import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart' show appState, db;
import '../theme.dart';
import '../widgets/kryfo_avatar.dart';
import '../rooms.dart';
import 'room_link_sheet.dart';
import '../widgets/motion.dart' show haloRoute;
import 'package:flutter/services.dart';
import 'chat_screen.dart'
    show MediaGalleryScreen, Atmo, atmoFromName, atmoAccent, atmoLabel;
import '../widgets/stagger_in.dart';
import '../widgets/sheet_handle.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});
  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  String _name = '';
  bool _isAdmin = false;
  // room fields, null for a plain group
  String? _roomPub;
  int? _roomExpiresAt;
  bool get _isRoom => _roomPub != null;
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
      _roomPub = g?['room_pub'] as String?;
      _roomExpiresAt = g?['expires_at'] as int?;
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
      try {
        await appState.addMembersToGroup(widget.groupId, picked.toList());
      } catch (e) {
        // group full toast
        if (mounted) {
          showHaloToast(context, e is StateError ? e.message : 'could not add');
        }
        return;
      }
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

  Future<void> _pickAtmosphere() async {
    final current = atmoFromName(await db.getGroupAtmosphere(widget.groupId));
    if (!mounted) return;
    final picked = await showModalBottomSheet<Atmo>(
      context: context,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 8),
              Text(
                'atmosphere',
                style: HaloType.serif(size: 18, color: HaloColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                'a quiet wash behind this group. yours only.',
                style: HaloType.sans(size: 12, color: HaloColors.text2),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: Atmo.values.map((a) {
                  final sel = a == current;
                  final accent = atmoAccent(a);
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, a),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: a == Atmo.none
                                ? HaloColors.surface3
                                : accent.withValues(alpha: 0.18),
                            border: Border.all(
                              color: sel ? HaloColors.amber : HaloColors.line,
                              width: sel ? 1.5 : 0.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: a == Atmo.none
                              ? Icon(
                                  Icons.not_interested,
                                  size: 16,
                                  color: HaloColors.text3,
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          atmoLabel(a),
                          style: HaloType.mono(
                            size: 10,
                            color: sel ? HaloColors.amber : HaloColors.text3,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    await db.setGroupAtmosphere(widget.groupId, picked.name);
  }

  Future<void> _openSharedMedia() async {
    final rows = await db.loadGroupMessages(widget.groupId);
    final paths = <String>[];
    for (final r in rows) {
      final mp = r['media_path'] as String?;
      if (mp != null && mp.isNotEmpty && await File(mp).exists()) {
        paths.add(mp);
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      haloRoute(
        MediaGalleryScreen(paths: paths.reversed.toList(), title: _name),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: HaloColors.surface2,
        title: Text(
          'clear this conversation?',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
        content: Text(
          'every message here is erased from this phone. this only clears '
          'your copy, other members keep theirs.',
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
              'clear',
              style: HaloType.sans(size: 13, color: HaloColors.rose),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await db.clearGroupConversation(widget.groupId);
      if (!mounted) return;
      showHaloToast(context, 'conversation cleared');
    }
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: HaloColors.surface2,
        title: Text(
          _isRoom ? 'leave room?' : 'leave group?',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
        content: Text(
          _isRoom
              ? 'everything in it is wiped from this phone now, and the key you used here is gone for good.'
              : 'you will stop receiving messages and other members will see you leave.',
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
                        color: HaloColors.amber.withValues(alpha: 0.45),
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
                    onTap: _isAdmin && !_isRoom ? _rename : null,
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
                        if (_isAdmin && !_isRoom) ...[
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
                  if (_isRoom)
                    GestureDetector(
                      onTap: () async {
                        final link = await appState.roomLinkFor(widget.groupId);
                        if (link != null && context.mounted) {
                          await showRoomLinkSheet(context, link);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_2_outlined,
                            size: 14,
                            color: HaloColors.violet,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'invite',
                            style: HaloType.mono(
                              size: 10,
                              color: HaloColors.violet,
                              letter: 0.14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isAdmin && !_isRoom)
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
                  final isMe = m == myId || (_isRoom && m == _roomPub);
                  return StaggerIn(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          KryfoAvatar(seed: m, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  looksLikeRoomKey(m) ? roomTag(m) : m,
                                  style: looksLikeRoomKey(m)
                                      ? HaloType.mono(
                                          size: 13,
                                          color: HaloColors.text,
                                        )
                                      : HaloType.sans(
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
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: _pickAtmosphere,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'atmosphere',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: HaloColors.text2,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: _openSharedMedia,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'shared media',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: HaloColors.text2,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: _confirmClear,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'clear conversation',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: HaloColors.text2,
                    ),
                  ),
                ),
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
                      color: HaloColors.rose.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _isRoom ? 'leave room' : 'leave group',
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
                        KryfoAvatar(seed: c.avatarSeed, size: 32),
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
