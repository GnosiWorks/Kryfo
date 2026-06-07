// home screen. date header, hero card or empty state, nav tabs.
// matches 08_complete_spec.html "the everyday" home tile.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/halo_avatar.dart';
import 'notes_screen.dart';
import 'archived_screen.dart';
import '../miui_autostart.dart';
import '../main.dart';
import '../widgets/motion.dart';

bool _miuiPromptChecked = false;

class HomeScreen extends StatelessWidget {
  final String haloId; // "neon-tiger-saturn"
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
            _HomeHead(now: now, haloId: haloId),
            _NotesPin(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const NotesScreen())),
            ),
            if (hasArchived)
              _ArchivedPin(
                count: contacts.where((c) => c.archived).length,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(_archivedRoute());
                },
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
            _NavTabs(
              active: 'chats',
              onDevLongPress: onOpenDev,
              onMeTap: onOpenSettings,
            ),
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
  final bool muted;
  final bool verified;
  final int unread;
  final bool pinned;
  ContactPreview({
    required this.haloId,
    this.nickname,
    this.preview,
    this.when,
    required this.avatarSeed,
    this.blocked = false,
    this.archived = false,
    this.muted = false,
    this.verified = false,
    this.unread = 0,
    this.pinned = false,
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
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '9:41',
                style: HaloType.sans(
                  size: 11,
                  weight: FontWeight.w500,
                  color: HaloColors.text2,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showConnectionSheet(context),
                child: _ConnectionHalo(
                  status: appState.torStatus,
                  pct: appState.bootstrapPct,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────── date header ─────────

const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _ConnectionHalo extends StatefulWidget {
  final TorStatus status;
  final int pct;
  const _ConnectionHalo({required this.status, required this.pct});
  @override
  State<_ConnectionHalo> createState() => _ConnectionHaloState();
}

class _ConnectionHaloState extends State<_ConnectionHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int _peak = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _peak = widget.pct;
    if (widget.status != TorStatus.reachable) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ConnectionHalo old) {
    super.didUpdateWidget(old);
    if (widget.pct > _peak) _peak = widget.pct;
    final live = widget.status != TorStatus.reachable;
    if (live && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!live && _c.isAnimating) {
      _c.animateTo(0, duration: const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _label() {
    if (widget.status == TorStatus.reachable) return 'connected';
    return _peak > 0 ? 'connecting $_peak%' : 'connecting';
  }

  @override
  Widget build(BuildContext context) {
    final reachable = widget.status == TorStatus.reachable;
    final dot = reachable ? HaloColors.green : HaloColors.amber;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            final glow = reachable ? 0.45 : (0.2 + 0.5 * t);
            final spread = reachable ? 1.0 : (0.4 + 2.4 * t);
            return Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot,
                boxShadow: [
                  BoxShadow(
                    color: dot.withOpacity(glow),
                    blurRadius: reachable ? 5 : (3 + 5 * t),
                    spreadRadius: spread,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 7),
        Text(
          _label(),
          style: HaloType.mono(
            size: 10,
            color: reachable ? HaloColors.text2 : HaloColors.amber,
            letter: 0.04,
          ),
        ),
      ],
    );
  }
}

void _showConnectionSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HaloColors.surface2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: ListenableBuilder(
        listenable: appState,
        builder: (ctx, _) {
          final reachable = appState.torStatus == TorStatus.reachable;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'your connection',
                  style: HaloType.serif(size: 20, color: HaloColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  reachable ? 'connected over tor' : 'connecting over tor',
                  style: HaloType.mono(
                    size: 11,
                    color: reachable ? HaloColors.green : HaloColors.amber,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TorWarmupGraph(
                    status: appState.torStatus,
                    bootstrapPct: appState.bootstrapPct,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'halo sends every message through tor — a chain of relays '
                  'that hides who you are talking to and where you are. no '
                  'single server ever sees both ends.',
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text2,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'the first connection after opening takes a moment while '
                  'that path is built. once it is green, you are through.',
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text3,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

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
          Text(
            '$day,',
            style: HaloType.serif(size: 26, weight: FontWeight.w400),
          ),
          Text(
            '$month ${now.day}',
            style: HaloType.serif(
              size: 26,
              weight: FontWeight.w300,
              color: HaloColors.amber,
              italic: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'your halo · $haloId',
            style: HaloType.mono(
              size: 11,
              color: HaloColors.text2,
              letter: 0.04,
            ),
          ),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HaloColors.amberSoft,
                border: Border.all(
                  color: HaloColors.amber.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                color: HaloColors.amber,
                size: 26,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'no halos yet.',
              textAlign: TextAlign.center,
              style: HaloType.serif(
                size: 22,
                weight: FontWeight.w300,
                italic: true,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'scan a QR to add your first one.',
              textAlign: TextAlign.center,
              style: HaloType.sans(size: 13, color: HaloColors.text2),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'scan',
                  style: HaloType.sans(
                    size: 13,
                    weight: FontWeight.w500,
                    color: HaloColors.onAmber,
                    height: 1,
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

// ───────── contact list (used once contacts exist) ─────────

Route<void> _archivedRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const ArchivedScreen(),
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ArchivedPin extends StatelessWidget {
  final VoidCallback onTap;
  final int count;
  const _ArchivedPin({required this.onTap, required this.count});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.amberSoft,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: HaloColors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'archived',
                        style: HaloType.sans(
                          size: 14,
                          weight: FontWeight.w500,
                          color: HaloColors.text,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        count == 1 ? '1 chat' : '$count chats',
                        style: HaloType.mono(size: 10, color: HaloColors.text3),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: HaloColors.text3, size: 18),
              ],
            ),
          ),
        ),
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
        _Enter(
          index: 0,
          child: _HeroCard(c: hero, onTap: () => onTap(hero.haloId)),
        ),
        // groups section (header + rows + new-group tile). always show the
        // tile so user can create a group even with no existing groups.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Row(
            children: [
              Text(
                'groups',
                style: HaloType.mono(
                  size: 10,
                  color: HaloColors.text3,
                  letter: 0.14,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onNewGroup,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: HaloColors.amber),
                    const SizedBox(width: 3),
                    Text(
                      'new',
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
        ...groups.asMap().entries.map(
          (e) => _Enter(
            index: 1 + e.key,
            child: _GroupRow(
              g: e.value,
              onTap: () => onOpenGroup(e.value.groupId),
            ),
          ),
        ),
        if (rest.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'more',
              style: HaloType.mono(
                size: 10,
                color: HaloColors.text3,
                letter: 0.14,
              ),
            ),
          ),
          ...rest.asMap().entries.map(
            (e) => _Enter(
              index: 1 + groups.length + e.key,
              child: _SwipeRow(c: e.value, onTap: () => onTap(e.value.haloId)),
            ),
          ),
        ],
      ],
    );
  }
}

bool _homeEntered = false;

// one-shot staggered entrance for the home list. plays on the first render
// after launch, then stays put so message updates never re-animate rows.
class _Enter extends StatefulWidget {
  final int index;
  final Widget child;
  const _Enter({required this.index, required this.child});
  @override
  State<_Enter> createState() => _EnterState();
}

class _EnterState extends State<_Enter> with SingleTickerProviderStateMixin {
  late final bool _animate = !_homeEntered;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: _animate ? 0.0 : 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (_animate) {
      if (!_homeEntered) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _homeEntered = true,
        );
      }
      Future.delayed(Duration(milliseconds: widget.index * 45), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) return widget.child;
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - curved.value)),
          child: child,
        ),
      ),
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
        child: Row(
          children: [
            // group avatar: square tile in amberSoft with the first letter
            // of the group name in italic serif. distinct from contact
            // avatars (circular) so groups feel different at a glance.
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: HaloColors.amber.withOpacity(0.35),
                  width: 0.6,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                g.name.isEmpty ? '·' : g.name.characters.first.toUpperCase(),
                style: HaloType.serif(
                  size: 18,
                  italic: true,
                  color: HaloColors.amber,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.name,
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: HaloColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${g.memberCount} members',
                    style: HaloType.mono(size: 10, color: HaloColors.text3),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HaloColors.amber, HaloColors.amberDeep],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    HaloAvatar(seed: c.avatarSeed, size: 42),
                    if (c.verified)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: _verifiedTick(onAmber: true),
                      ),
                  ],
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nickname ?? c.haloId,
                        style: HaloType.sans(
                          size: 14,
                          weight: FontWeight.w500,
                          color: HaloColors.onAmber,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.muted) ...[
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 12,
                              color: HaloColors.onAmber.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            (c.blocked ? 'blocked' : _relTime(c.when)),
                            style: HaloType.mono(
                              size: 11,
                              color: HaloColors.onAmber.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              c.preview ?? '',
              style: HaloType.sans(
                size: 13,
                color: HaloColors.onAmber,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _verifiedTick({required bool onAmber}) {
  final ring = onAmber ? HaloColors.amber : HaloColors.surface;
  final fill = onAmber ? HaloColors.onAmber : HaloColors.amber;
  final glyph = onAmber ? HaloColors.amber : HaloColors.surface;
  return Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: fill,
      border: Border.all(color: ring, width: 1.5),
    ),
    alignment: Alignment.center,
    child: Icon(Icons.check, size: 8, color: glyph),
  );
}

class _SwipeRow extends StatelessWidget {
  final ContactPreview c;
  final VoidCallback onTap;
  const _SwipeRow({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('swipe_' + c.haloId),
      background: Container(
        color: HaloColors.surface2,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Icon(
          c.muted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          size: 20,
          color: HaloColors.text2,
        ),
      ),
      secondaryBackground: Container(
        color: HaloColors.surface2,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.archive_outlined, size: 20, color: HaloColors.amber),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.endToStart) {
          await appState.archive(c.haloId);
        } else if (c.muted) {
          await appState.unmute(c.haloId);
        } else {
          await appState.mute(c.haloId);
        }
        return false;
      },
      child: _Row(c: c, onTap: onTap),
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
        child: Row(
          children: [
            Opacity(
              opacity: c.blocked ? 0.4 : 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  HaloAvatar(seed: c.avatarSeed, size: 36),
                  if (c.verified)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: _verifiedTick(onAmber: false),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        c.nickname ?? c.haloId,
                        style: HaloType.sans(
                          size: 14,
                          weight: FontWeight.w500,
                          color: c.blocked ? HaloColors.text3 : HaloColors.text,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.pinned) ...[
                            Icon(
                              Icons.push_pin,
                              size: 11,
                              color: HaloColors.text3,
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (c.muted) ...[
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 12,
                              color: HaloColors.text3,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            (c.blocked ? 'blocked' : _relTime(c.when)),
                            style: HaloType.mono(
                              size: 10,
                              color: HaloColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.preview ?? '',
                          style: HaloType.sans(
                            size: 12,
                            color: HaloColors.text2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          decoration: BoxDecoration(
                            color: HaloColors.amber,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            c.unread > 99 ? '99+' : '\${c.unread}',
                            textAlign: TextAlign.center,
                            style: HaloType.sans(
                              size: 10,
                              weight: FontWeight.w600,
                              color: HaloColors.onAmber,
                            ),
                          ),
                        ),
                      ],
                    ],
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

String _relTime(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  // older than a week: a short date reads better than a big day count
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${t.day} ${months[t.month - 1]}';
}

// ───────── nav tabs ─────────

class _NavTabs extends StatelessWidget {
  final String active;
  final VoidCallback onDevLongPress;
  final VoidCallback onMeTap;
  const _NavTabs({
    required this.active,
    required this.onDevLongPress,
    required this.onMeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
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
    return Text(
      label,
      style: HaloType.sans(
        size: 11,
        weight: active ? FontWeight.w500 : FontWeight.w400,
        color: active ? HaloColors.text : HaloColors.text2,
      ),
    );
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
              child: Icon(
                Icons.bookmark_outline,
                color: HaloColors.amber,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'note to self',
                    style: HaloType.serif(
                      size: 14,
                      color: HaloColors.text,
                      italic: true,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'a private space, only on this phone',
                    style: HaloType.sans(size: 11.5, color: HaloColors.text3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF6B625A), size: 18),
          ],
        ),
      ),
    );
  }
}
