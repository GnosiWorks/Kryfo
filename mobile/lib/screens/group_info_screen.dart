// SPDX-License-Identifier: GPL-3.0-or-later
// group info: name and member changes for the admin, leave for everyone

import 'dart:io';
import 'package:flutter/material.dart';
import '../lock_state.dart' show lockState;
import '../main.dart' show appState, session;
import '../atmosphere.dart' show Atmo, atmoFromName;
import '../theme.dart';
import '../widgets/kryfo_avatar.dart';
import '../rooms.dart';
import 'room_link_sheet.dart';
import '../widgets/motion.dart' show haloRoute;
import 'package:flutter/services.dart';
import 'chat_screen.dart' show MediaGalleryScreen, atmoFromName;
import 'wallpaper_sheet.dart';
import '../widgets/stagger_in.dart';
import '../widgets/halo_rows.dart';
import '../widgets/page_head.dart';
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/hidden_mark.dart';
import '../lock_guard.dart' show lockGuard;
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/row_motion.dart';
import '../widgets/confirm_sheet.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});
  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _scroll = ScrollController();
  String _name = '';
  bool _isAdmin = false;
  // room fields, null for a plain group
  String? _roomPub;
  bool get _isRoom => _roomPub != null;
  // known before the load, so the tile lands violet out of the room's header
  late final bool _roomAtOpen = appState.groups.any(
    (g) => g.groupId == widget.groupId && g.expiresAt != null,
  );
  List<String> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final g = await session.getGroup(widget.groupId);
    final members = await session.getGroupMembers(widget.groupId);
    if (!mounted) return;
    setState(() {
      _name = (g?['name'] as String?) ?? l10n.groupInfoGroup;
      _isAdmin = ((g?['is_admin'] as int?) ?? 0) == 1;
      _roomPub = g?['room_pub'] as String?;
      _members = members;
      _loading = false;
    });
  }

  Future<void> _rename() async {
    final newName = (await showInputSheet(
      context,
      title: l10n.groupInfoRenameGroup,
      initial: _name,
      save: l10n.groupInfoRename,
    ))?.trim();
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
      showHaloToast(context, l10n.groupInfoNoContactsToAdd);
      return;
    }
    final picked = await showHaloSheet<Set<String>>(
      context,
      scroll: true,
      builder: (c) => _AddMemberSheet(available: available),
    );
    if (picked != null && picked.isNotEmpty) {
      try {
        await appState.addMembersToGroup(widget.groupId, picked.toList());
      } catch (e) {
        // group full toast
        if (mounted) {
          showHaloToast(
            context,
            e is StateError ? e.message : l10n.groupInfoCouldNotAdd,
          );
        }
        return;
      }
      await _load();
    }
  }

  Future<void> _confirmRemove(String haloId) async {
    final ok = await showConfirmSheet(
      context,
      title: l10n.groupInfoRemove(haloId),
      line: l10n.groupInfoTheyWillStopReceiving,
      yes: l10n.commonRemove,
    );
    if (ok == true) {
      await appState.removeMembersFromGroup(widget.groupId, [haloId]);
      await _load();
    }
  }

  Future<void> _pickAtmosphere() async {
    final current = atmoFromName(
      await session.getGroupAtmosphere(widget.groupId),
    );
    if (!mounted) return;
    final picked = await showWallpaperSheet(context, current);
    if (picked is! Atmo) return;
    HapticFeedback.selectionClick();
    await session.setGroupAtmosphere(widget.groupId, picked.name);
  }

  Future<void> _openSharedMedia() async {
    final rows = await session.loadGroupMessages(widget.groupId);
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
    final ok = await showConfirmSheet(
      context,
      title: l10n.groupInfoClearThisConversation,
      line: l10n.groupInfoEveryMessageHereIs,
      yes: l10n.groupInfoClear,
    );
    if (ok == true) {
      await session.clearGroupConversation(widget.groupId);
      if (!mounted) return;
      showHaloToast(context, l10n.groupInfoConversationCleared);
    }
  }

  // its rows move, so the group is left as a left one is
  Future<void> _moveHidden() async {
    final moved = await moveHiddenChat(
      context,
      widget.groupId,
      group: true,
      hide: !session.isHidden(widget.groupId),
    );
    if (!moved || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmLeave() async {
    final ok = await showConfirmSheet(
      context,
      title: _isRoom ? l10n.groupInfoLeaveRoom : l10n.groupInfoLeaveGroup,
      line: _isRoom
          ? l10n.groupInfoEverythingInItIs
          : l10n.groupInfoYouWillStopReceiving,
      yes: l10n.groupInfoLeave,
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
    final myId = appState.sessionId;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 4,
        title: Row(
          children: [
            IconButton(
              tooltip: l10n.commonBack,
              icon: Icon(Icons.chevron_left, color: HaloColors.text, size: 26),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                l10n.groupInfoGroupInfo,
                style: HaloType.serif(
                  size: 18,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
            ),
          ],
        ),
        bottom: HeadLine(controller: _scroll),
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: staggerAllIn(context, [
          // big group identity
          ParallaxHead(
            controller: _scroll,
            child: Center(
              child: Column(
                children: [
                  // the same tile flies here from the chat's header
                  Hero(
                    tag: 'group-${widget.groupId}',
                    flightShuttleBuilder: (_, _, _, _, _) =>
                        FittedBox(child: _tile(_name)),
                    child: _tile(_name),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _isAdmin && !_isRoom ? _rename : null,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.serif(
                              size: 24,
                              weight: FontWeight.w300,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        if (_isAdmin && !_isRoom) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: HaloColors.text3,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.groupInfo1Member(_members.length),
                        style: HaloType.mono(
                          size: 11,
                          color: HaloColors.text3,
                          letter: 0.1,
                        ),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: HaloColors.amberSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.groupInfoAdmin,
                            style: HaloType.mono(
                              size: 9.5,
                              color: HaloColors.amber,
                              weight: FontWeight.w600,
                              letter: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.photo_library_outlined,
                label: l10n.groupInfoSharedMedia,
                onTap: _openSharedMedia,
              ),
              HaloRow(
                icon: Icons.palette_outlined,
                label: l10n.groupInfoWallpaper,
                onTap: _pickAtmosphere,
              ),
              // hidden chats open: out of the everyday list, or back in it
              if (lockState.inVault && !_isRoom)
                HaloRow(
                  icon: session.isHidden(widget.groupId)
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  label: session.isHidden(widget.groupId)
                      ? l10n.chatShowInList
                      : l10n.groupHide,
                  onTap: _moveHidden,
                ),
            ],
          ),
          PageSection(
            l10n.groupInfoMembers2,
            actions: [
              if (_isRoom)
                _Pill(
                  icon: Icons.qr_code_2_outlined,
                  label: l10n.groupInfoInvite,
                  color: HaloColors.violet,
                  onTap: () async {
                    final link = await appState.roomLinkFor(widget.groupId);
                    if (link != null && context.mounted) {
                      await showRoomLinkSheet(context, link);
                    }
                  },
                ),
              if (_isAdmin && !_isRoom)
                _Pill(
                  icon: Icons.add_rounded,
                  label: l10n.commonAdd,
                  color: HaloColors.amber,
                  onTap: _addMembers,
                ),
            ],
          ),
          MembersCard(
            // under the lock nothing is being watched
            quiet: lockGuard.isLocked(),
            members: _members,
            isMe: (m) => m == myId || (_isRoom && m == _roomPub),
            canRemove: _isAdmin,
            onRemove: _confirmRemove,
          ),
          const SizedBox(height: 14),
          // what cannot be taken back, apart and in rose
          HaloGroup(
            rose: true,
            children: [
              HaloRow(
                icon: Icons.delete_sweep_outlined,
                label: l10n.groupInfoClearConversation,
                rose: true,
                onTap: _confirmClear,
              ),
              HaloRow(
                icon: Icons.logout_rounded,
                label: _isRoom
                    ? l10n.groupInfoLeaveRoom2
                    : l10n.groupInfoLeaveGroup2,
                rose: true,
                onTap: _confirmLeave,
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // the group's face: its first letter on an amber tile, square where a
  // person's is round. a room's is violet, as on the chat list
  Widget _tile(String name) {
    final tint = _isRoom || _roomAtOpen ? HaloColors.violet : HaloColors.amber;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: tint == HaloColors.amber
            ? HaloColors.amberSoft
            : tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.45), width: 0.8),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '·' : name.characters.first.toUpperCase(),
        style: HaloType.serif(size: 36, italic: true, color: tint),
      ),
    );
  }
}

// a small tinted pill at the end of a section heading
class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: label,
      onTap: onTap,
      scale: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: HaloType.mono(
                  size: 10,
                  color: color,
                  weight: FontWeight.w500,
                  letter: 0.06,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// everyone in the group, on one card: a face, the three words, and for the
// admin a way to take someone out. someone added grows in, someone who
// went folds away where they were
class MembersCard extends StatefulWidget {
  final List<String> members;
  final bool Function(String id) isMe;
  final bool canRemove;
  final void Function(String id) onRemove;
  // take a change as it is, with no motion
  final bool quiet;
  const MembersCard({
    super.key,
    required this.members,
    required this.isMe,
    required this.canRemove,
    required this.onRemove,
    this.quiet = false,
  });

  @override
  State<MembersCard> createState() => _MembersCardState();
}

class _MembersCardState extends State<MembersCard> {
  late final RowSet<String> _rows = RowSet(
    keyOf: (m) => m,
    onGone: () {
      if (mounted) setState(() {});
    },
  );

  @override
  void initState() {
    super.initState();
    _rows.start(widget.members);
  }

  @override
  void didUpdateWidget(MembersCard old) {
    super.didUpdateWidget(old);
    _rows.update(widget.members, quiet: widget.quiet);
  }

  @override
  void dispose() {
    _rows.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows.rows;
    WidgetsBinding.instance.addPostFrameCallback((_) => _rows.built());
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            IgnorePointer(
              key: ValueKey(rows[i]),
              ignoring: _rows.leaving(rows[i]),
              child: FadeFold(
                leaving: _rows.leaving(rows[i]),
                child: GrowIn(
                  active: _rows.fresh(rows[i]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 60),
                          child: Container(height: 0.5, color: HaloColors.line),
                        ),
                      _member(rows[i]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _member(String m) {
    final isMe = widget.isMe;
    final canRemove = widget.canRemove;
    final onRemove = widget.onRemove;
    final me = isMe(m);
    final room = looksLikeRoomKey(m);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
      child: Row(
        children: [
          KryfoAvatar(seed: m, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room ? roomTag(m) : m,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: room
                      ? HaloType.mono(size: 13, color: HaloColors.text)
                      : HaloType.sans(
                          size: 14,
                          weight: FontWeight.w500,
                          color: HaloColors.text,
                        ),
                ),
                if (me)
                  Text(
                    l10n.groupInfoYou,
                    style: HaloType.mono(
                      size: 10,
                      color: HaloColors.amber,
                      letter: 0.3,
                    ),
                  ),
              ],
            ),
          ),
          if (canRemove && !me)
            IconButton(
              tooltip: l10n.groupInfoRemoveFromGroup,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(
                Icons.remove_circle_outline,
                size: 18,
                color: HaloColors.text3,
              ),
              onPressed: () => onRemove(m),
            )
          else
            const SizedBox(height: 40),
        ],
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
          const SheetHandle(),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 20),
              Text(
                l10n.groupInfoAddMembers,
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
                  l10n.groupInfoAdd(whole(_picked.length)),
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
