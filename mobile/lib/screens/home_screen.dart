// home screen. date header, hero card or empty state, nav tabs.
// matches 08_complete_spec.html "the everyday" home tile.

import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/halo_avatar.dart';
import 'notes_screen.dart';
import 'archived_screen.dart';
import '../miui_autostart.dart';

bool _miuiPromptChecked = false;

class HomeScreen extends StatelessWidget {
  final String haloId;            // "neon-tiger-saturn"
  final List<ContactPreview> contacts;
  final List<GroupSummary> groups;
  final VoidCallback onAddContact;
  final VoidCallback onNewGroup;
  final VoidCallback onOpenDev;
  final VoidCallback onOpenSettings;
  final void Function(String halo) onOpenChat;
  final void Function(String groupId) onOpenGroup;

  const HomeScreen({
    super.key,
    required this.haloId,
    this.contacts = const [],
    this.groups = const [],
    required this.onAddContact,
    required this.onNewGroup,
    required this.onOpenDev,
    required this.onOpenSettings,
    required this.onOpenChat,
    required this.onOpenGroup,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = contacts.where((c) => !c.archived).toList();
    final hasArchived = contacts.any((c) => c.archived);
    if (!_miuiPromptChecked) {
      _miuiPromptChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        maybeShowMiuiPrompt(context);
      });
    }
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const _StatusBar(),
            _HomeHead(now: now, haloId: haloId),
            _NotesPin(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotesScreen()),
              ),
            ),
            if (hasArchived)
              _ArchivedPin(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ArchivedScreen()),
                ),
              ),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyState(onAdd: onAddContact)
                  : _ContactList(
                      contacts: visible,
                      groups: groups,
                      onTap: onOpenChat,
                      onOpenGroup: onOpenGroup,
                      onNewGroup: onNewGroup,
                    ),
            ),
            _NavTabs(active: 'chats', onDevLongPress: onOpenDev, onMeTap: onOpenSettings),
          ],
        ),
      ),
    );
  }
}

class ContactPreview {
  final String haloId;
  final String? nickname;
  final String? preview;
  final DateTime? when;
  final String avatarSeed;
  final bool blocked;
  final bool archived;
  ContactPreview({
    required this.haloId,
    this.nickname,
    this.preview,
    this.when,
    required this.avatarSeed,
    this.blocked = false,
    this.archived = false,
  });
}

// minimal shape needed by home for rendering a group row. main.dart
// builds these from appState.groups.
class GroupSummary {
  final String groupId;
  final String name;
  final int memberCount;
  const GroupSummary({
    required this.groupId,
    required this.name,
    required this.memberCount,
  });
}

// ───────── status bar ─────────

class _StatusBar extends StatelessWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('9:41', style: HaloType.sans(size: 11, weight: FontWeight.w500, color: HaloColors.text2)),
          Text('•••', style: HaloType.sans(size: 11, color: HaloColors.text2.withOpacity(0.6), letter: 2)),
        ],
      ),
    );
  }
}

// ───────── date header ─────────

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class _HomeHead extends StatelessWidget {
  final DateTime now;
  final String haloId;
  const _HomeHead({required this.now, required this.haloId});
  @override
  Widget build(BuildContext context) {
    final day = _days[now.weekday - 1];
    final month = _months[now.month - 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$day,', style: HaloType.serif(size: 26, weight: FontWeight.w400)),
          Text('$month ${now.day}',
              style: HaloType.serif(
                size: 26, weight: FontWeight.w300,
                color: HaloColors.amber, italic: true,
              )),
          const SizedBox(height: 8),
          Text('your halo · $haloId',
              style: HaloType.mono(size: 11, color: HaloColors.text2, letter: 0.04)),
        ],
      ),
    );
  }
}

// ───────── empty state ─────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HaloColors.amberSoft,
                border: Border.all(color: HaloColors.amber.withOpacity(0.3), width: 0.5),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: HaloColors.amber, size: 26),
            ),
            const SizedBox(height: 18),
            Text('no halos yet.',
                textAlign: TextAlign.center,
                style: HaloType.serif(
                  size: 22, weight: FontWeight.w300,
                  italic: true, color: HaloColors.text,
                )),
            const SizedBox(height: 8),
            Text('scan a QR to add your first one.',
                textAlign: TextAlign.center,
                style: HaloType.sans(size: 13, color: HaloColors.text2)),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('scan',
                    style: HaloType.sans(
                      size: 13, weight: FontWeight.w500,
                      color: HaloColors.onAmber, height: 1,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── contact list (used once contacts exist) ─────────

class _ArchivedPin extends StatelessWidget {
  final VoidCallback onTap;
  const _ArchivedPin({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          const Icon(Icons.archive_outlined, size: 16, color: HaloColors.text3),
          const SizedBox(width: 12),
          Text('archived',
              style: HaloType.sans(size: 13, color: HaloColors.text2)),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Color(0xFF6B625A), size: 18),
        ]),
      ),
    );
  }
}

class _ContactList extends StatelessWidget {
  final List<ContactPreview> contacts;
  final List<GroupSummary> groups;
  final void Function(String halo) onTap;
  final void Function(String groupId) onOpenGroup;
  final VoidCallback onNewGroup;
  const _ContactList({
    required this.contacts,
    required this.groups,
    required this.onTap,
    required this.onOpenGroup,
    required this.onNewGroup,
  });
  @override
  Widget build(BuildContext context) {
    final hero = contacts.first;
    final rest = contacts.skip(1).toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _HeroCard(c: hero, onTap: () => onTap(hero.haloId)),
        // groups section (header + rows + new-group tile). always show the
        // tile so user can create a group even with no existing groups.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Row(
            children: [
              Text('groups',
                  style: HaloType.mono(
                    size: 10, color: HaloColors.text3, letter: 0.14,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: onNewGroup,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded,
                        size: 14, color: HaloColors.amber),
                    const SizedBox(width: 3),
                    Text('new',
                        style: HaloType.mono(
                          size: 10, color: HaloColors.amber, letter: 0.14,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...groups.map((g) => _GroupRow(g: g, onTap: () => onOpenGroup(g.groupId))),
        if (rest.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text('more',
                style: HaloType.mono(
                  size: 10, color: HaloColors.text3, letter: 0.14,
                )),
          ),
          ...rest.map((c) => _Row(c: c, onTap: () => onTap(c.haloId))),
        ],
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  final GroupSummary g;
  final VoidCallback onTap;
  const _GroupRow({required this.g, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // group avatar: square tile in amberSoft with the first letter
          // of the group name in italic serif. distinct from contact
          // avatars (circular) so groups feel different at a glance.
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: HaloColors.amberSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: HaloColors.amber.withOpacity(0.35), width: 0.6),
            ),
            alignment: Alignment.center,
            child: Text(
              g.name.isEmpty ? '·' : g.name.characters.first.toUpperCase(),
              style: HaloType.serif(
                size: 18, italic: true, color: HaloColors.amber,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name,
                    style: HaloType.sans(
                        size: 14, weight: FontWeight.w500, color: HaloColors.text)),
                const SizedBox(height: 2),
                Text('${g.memberCount} members',
                    style: HaloType.mono(size: 10, color: HaloColors.text3)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ContactPreview c;
  final VoidCallback onTap;
  const _HeroCard({required this.c, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [HaloColors.amber, HaloColors.amberDeep],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              HaloAvatar(seed: c.avatarSeed, size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nickname ?? c.haloId,
                        style: HaloType.sans(size: 14, weight: FontWeight.w500, color: HaloColors.onAmber)),
                    Text((c.blocked ? 'blocked' : _relTime(c.when)),
                        style: HaloType.mono(size: 11, color: HaloColors.onAmber.withOpacity(0.7))),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(c.preview ?? '',
                style: HaloType.sans(size: 13, color: HaloColors.onAmber, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final ContactPreview c;
  final VoidCallback onTap;
  const _Row({required this.c, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          HaloAvatar(seed: c.avatarSeed, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c.nickname ?? c.haloId,
                        style: HaloType.sans(size: 14, weight: FontWeight.w500, color: HaloColors.text)),
                    Text((c.blocked ? 'blocked' : _relTime(c.when)),
                        style: HaloType.mono(size: 10, color: HaloColors.text3)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(c.preview ?? '',
                    style: HaloType.sans(size: 12, color: HaloColors.text2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

String _relTime(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}

// ───────── nav tabs ─────────

class _NavTabs extends StatelessWidget {
  final String active;
  final VoidCallback onDevLongPress;
  final VoidCallback onMeTap;
  const _NavTabs({required this.active, required this.onDevLongPress, required this.onMeTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Tab(label: 'Chats', active: active == 'chats'),
          _Tab(label: 'Drop', active: active == 'drop'),
          _Tab(label: 'Market', active: active == 'market'),
          GestureDetector(
            onLongPress: onDevLongPress,
            onTap: onMeTap,
            behavior: HitTestBehavior.opaque,
            child: _Tab(label: 'Me', active: active == 'me'),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  const _Tab({required this.label, required this.active});
  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: HaloType.sans(
          size: 11,
          weight: active ? FontWeight.w500 : FontWeight.w400,
          color: active ? HaloColors.text : HaloColors.text2,
        ));
  }
}

class _NotesPin extends StatelessWidget {
  final VoidCallback onTap;
  const _NotesPin({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.bookmark_outline,
                  color: HaloColors.amber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('note to self',
                      style: HaloType.serif(
                          size: 14,
                          color: HaloColors.text,
                          italic: true)),
                  const SizedBox(height: 2),
                  Text('a private space, only on this phone',
                      style: HaloType.sans(
                          size: 11.5, color: HaloColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF6B625A), size: 18),
          ],
        ),
      ),
    );
  }
}

