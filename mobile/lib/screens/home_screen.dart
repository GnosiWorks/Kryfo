// SPDX-License-Identifier: GPL-3.0-or-later
// home screen. date header, hero card or empty state, nav tabs.
// matches 08_complete_spec.html "the everyday" home tile.

import 'saved_screen.dart';
import '../widgets/press_scale.dart';
import 'requests_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'donate_screen.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/room_countdown.dart';
import '../widgets/kryfo_avatar.dart';
import 'notes_screen.dart';
import 'backup_screen.dart';
import 'bridges_screen.dart';
import 'archived_screen.dart';
import '../miui_autostart.dart';
import '../main.dart';
import '../widgets/motion.dart';

bool _miuiPromptChecked = false;

class HomeScreen extends StatelessWidget {
  final String haloId; // "neon-tiger-saturn"
  final List<ContactPreview> contacts;
  final List<GroupSummary> groups;
  final int pendingCount;
  final VoidCallback onAddContact;
  final VoidCallback onNewGroup;
  final VoidCallback onNewRoom;
  final String? expiredRoomName;
  final VoidCallback onOpenDev;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSettingsDirect;
  final void Function(String kryfo) onOpenChat;
  final void Function(String groupId) onOpenGroup;

  const HomeScreen({
    super.key,
    required this.haloId,
    this.contacts = const [],
    this.groups = const [],
    required this.onAddContact,
    required this.onNewGroup,
    required this.onNewRoom,
    this.expiredRoomName,
    required this.onOpenDev,
    required this.onOpenSettings,
    required this.onOpenSettingsDirect,
    this.pendingCount = 0,
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
        maybeShowBackgroundPrompt(context);
      });
    }
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _HomeHead(
              now: now,
              haloId: haloId,
              onAdd: onAddContact,
              onSettings: onOpenSettingsDirect,
            ),
            const _OfflineStrip(),
            const _BackupNudge(),
            const _BridgeHint(),
            const _BridgeStuckHint(),
            const _RelayDownHint(),
            _NotesPin(
              onTap: () =>
                  Navigator.of(context).push(haloRoute(const NotesScreen())),
            ),
            if (pendingCount > 0)
              _RequestsPin(
                count: pendingCount,
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const RequestsScreen())),
              ),
            _SavedPin(
              onTap: () =>
                  Navigator.of(context).push(haloRoute(const SavedScreen())),
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
                      onNewRoom: onNewRoom,
                      expiredRoomName: expiredRoomName,
                    ),
            ),
            _NavTabs(
              active: 'chats',
              onDevLongPress: onOpenDev,
              onMeTap: onOpenSettings,
              onSupportTap: () =>
                  Navigator.of(context).push(haloRoute(const DonateScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

Route<void> _archivedRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const ArchivedScreen(),
    transitionsBuilder: (_, anim, _, child) {
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

class ContactPreview {
  final String haloId;
  final String? nickname;
  final String? preview;
  final DateTime? when;
  final String avatarSeed;
  // the face they picked, if they have. null means draw from their id.
  final int? avatar;
  final bool blocked;
  final bool archived;
  final bool muted;
  final bool verified;
  final int unread;
  final bool pinned;
  final String? supporterBadge;
  ContactPreview({
    required this.haloId,
    this.nickname,
    this.preview,
    this.when,
    required this.avatarSeed,
    this.avatar,
    this.blocked = false,
    this.archived = false,
    this.muted = false,
    this.verified = false,
    this.unread = 0,
    this.pinned = false,
    this.supporterBadge,
  });
}

// minimal shape needed by home for rendering a group row. main.dart
// builds these from appState.groups.
class GroupSummary {
  final String groupId;
  final String name;
  final int memberCount;
  final int unread;
  final int? expiresAt; // set for a burner room
  const GroupSummary({
    required this.groupId,
    required this.name,
    required this.memberCount,
    this.unread = 0,
    this.expiresAt,
  });
  bool get isRoom => expiresAt != null;
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
// the relay route's colour - cool enough never to read as tor's violet
const kRelayCyan = Color(0xFF4BB8C9);

class _AddScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddScanButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: HaloColors.amber.withValues(alpha: 0.55),
            width: 1.4,
          ),
        ),
        child: Semantics(
          label: 'add a contact',
          button: true,
          child: Icon(Icons.add, size: 20, color: HaloColors.amber),
        ),
      ),
    );
  }
}

class _GearButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GearButton({required this.onTap});
  @override
  State<_GearButton> createState() => _GearButtonState();
}

class _GearButtonState extends State<_GearButton> {
  double _s = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _s = 0.9),
      onTapUp: (_) => setState(() => _s = 1.0),
      onTapCancel: () => setState(() => _s = 1.0),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _s,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: HaloColors.line2, width: 1.4),
          ),
          child: Icon(
            Icons.settings_outlined,
            size: 19,
            color: HaloColors.text2,
          ),
        ),
      ),
    );
  }
}

class _HomeHead extends StatelessWidget {
  final DateTime now;
  final String haloId;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  const _HomeHead({
    required this.now,
    required this.haloId,
    required this.onAdd,
    required this.onSettings,
  });
  @override
  Widget build(BuildContext context) {
    final day = _days[now.weekday - 1];
    final month = _months[now.month - 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$day,',
                  style: HaloType.serif(size: 26, weight: FontWeight.w400),
                  // display type, capped. at 200% this became one word per
                  // line and pushed the whole list off screen.
                  textScaler: TextScaler.linear(
                    MediaQuery.of(context).textScaler.scale(1).clamp(1.0, 1.15),
                  ),
                ),
                Text(
                  '$month ${now.day}',
                  style: HaloType.serif(
                    size: 26,
                    weight: FontWeight.w300,
                    color: HaloColors.amber,
                    italic: true,
                  ),
                  textScaler: TextScaler.linear(
                    MediaQuery.of(context).textScaler.scale(1).clamp(1.0, 1.15),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'your kryfo',
                  style: HaloType.mono(
                    size: 9.5,
                    color: HaloColors.text3,
                    letter: 0.14,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    haloId,
                    maxLines: 1,
                    softWrap: false,
                    style: HaloType.mono(
                      size: 20,
                      color: HaloColors.amber,
                      weight: FontWeight.w700,
                      letter: 0.02,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _GearButton(onTap: onSettings),
          const SizedBox(width: 10),
          _AddScanButton(onTap: onAdd),
          const SizedBox(width: 12),
          TorHalo(label: true),
        ],
      ),
    );
  }
}

// ───────── empty state ─────────

class _RelayDownHint extends StatelessWidget {
  const _RelayDownHint();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.suggestFastFallback) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: HaloColors.amber.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HaloColors.amber.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BreathDot(color: HaloColors.amber, size: 7),
                  const SizedBox(width: 9),
                  Text(
                    'our relay is quiet',
                    style: HaloType.mono(
                      size: 11,
                      color: HaloColors.amber,
                      weight: FontWeight.w600,
                      letter: 0.12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "relay mode uses only our own relay, and it is not answering "
                "right now. fast mode adds public relays alongside it, so "
                "messages still land. everything stays sealed either way.",
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await appState.setSendMode('fast');
                      if (context.mounted) {
                        showHaloToast(context, 'switched to fast');
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: HaloColors.amber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'use fast mode',
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.ink,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => appState.dismissRelayHint(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'keep waiting',
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.text3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BridgeStuckHint extends StatelessWidget {
  const _BridgeStuckHint();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.suggestBridgesOff) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: HaloColors.rose.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HaloColors.rose.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BreathDot(color: HaloColors.rose, size: 7),
                  const SizedBox(width: 9),
                  Text(
                    'not connecting',
                    style: HaloType.mono(
                      size: 11,
                      color: HaloColors.rose,
                      weight: FontWeight.w600,
                      letter: 0.12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "bridges are on and tor still is not through. bridges are "
                "slower, and some go dead without warning. if your network "
                "does not block tor, going direct is faster and more reliable.",
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
              const SizedBox(height: 13),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await appState.applyBridges(appState.bridgeLines, false);
                  engine.restartTor();
                  if (context.mounted) {
                    showHaloToast(context, 'going direct · reconnecting');
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.rose,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'turn bridges off',
                    style: HaloType.mono(
                      size: 11.5,
                      color: HaloColors.text,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BridgeHint extends StatelessWidget {
  const _BridgeHint();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.suggestBridges) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HaloColors.violet.withValues(alpha: 0.16),
                HaloColors.violet.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: HaloColors.violet.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BreathDot(color: HaloColors.violet, size: 7),
                  const SizedBox(width: 9),
                  Text(
                    'still trying',
                    style: HaloType.mono(
                      size: 11,
                      color: HaloColors.violet,
                      weight: FontWeight.w600,
                      letter: 0.12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "tor is not getting through. some networks block it on "
                "purpose. our own relay is one plain connection and usually "
                "works anyway - or bridges, which take longer to set up.",
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await appState.setSendMode('balanced');
                      if (context.mounted) {
                        showHaloToast(context, 'switched to relay');
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: kRelayCyan,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'use our relay',
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.ink,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(
                        context,
                      ).push(haloRoute(const BridgesScreen()));
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'bridges',
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.violet,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => appState.dismissBridgeHint(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'keep waiting',
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.text3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackupNudge extends StatelessWidget {
  const _BackupNudge();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.showBackupNudge) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          decoration: BoxDecoration(
            color: HaloColors.amber.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HaloColors.amber.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'lose this phone, lose this account',
                style: HaloType.sans(
                  size: 13.5,
                  color: HaloColors.text,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'there is no password reset here, and no one to ask. a '
                'backup takes a minute.',
                style: HaloType.sans(size: 12, color: HaloColors.text3),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(
                        context,
                      ).push(haloRoute(const BackupScreen()));
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: HaloColors.amber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'back up now',
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.onAmber,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => appState.dismissBackupNudge(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'not now',
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.text3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final n = appState.queued;
        // nothing wrong and nothing waiting, so say nothing
        if (appState.online && n == 0) return const SizedBox.shrink();

        final offline = !appState.online;
        final tint = offline ? HaloColors.rose : HaloColors.amber;
        final head = offline ? 'offline' : 'waiting';
        // the old strip said "offline" and stopped, which left people
        // guessing whether anything was queued or lost.
        final tail = n == 0
            ? 'nothing waiting to send'
            : offline
            ? "$n waiting · sends when you're back"
            : '$n waiting · sending now';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            border: Border(
              bottom: BorderSide(
                color: tint.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BreathDot(color: tint, size: 7),
              const SizedBox(width: 10),
              Text(
                head,
                style: HaloType.mono(
                  size: 12,
                  color: tint,
                  weight: FontWeight.w500,
                  letter: 0.08,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  tail,
                  style: HaloType.mono(
                    size: 11.5,
                    color: tint.withValues(alpha: 0.85),
                    weight: FontWeight.w500,
                  ),
                  maxLines: 2,
                ),
              ),
              if (n > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    appState.flushOutboxNow();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'retry',
                      style: HaloType.mono(
                        size: 11,
                        color: tint,
                        weight: FontWeight.w600,
                        letter: 0.06,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatefulWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // soft amber ring breathing outward - the app quietly waiting.
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, _) {
                      final t = Curves.easeOut.transform(_pulse.value);
                      return Container(
                        width: 56 + 22 * t,
                        height: 56 + 22 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HaloColors.amber.withValues(
                            alpha: 0.10 * (1 - t),
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HaloColors.amberSoft,
                      border: Border.all(
                        color: HaloColors.amber.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      color: HaloColors.amber,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'no kryfos yet.',
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
            PressScale(
              onTap: widget.onAdd,
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
  final void Function(String kryfo) onTap;
  final void Function(String groupId) onOpenGroup;
  final VoidCallback onNewGroup;
  final VoidCallback onNewRoom;
  final String? expiredRoomName;
  const _ContactList({
    required this.contacts,
    required this.groups,
    required this.onTap,
    required this.onOpenGroup,
    required this.onNewGroup,
    required this.onNewRoom,
    this.expiredRoomName,
  });
  @override
  Widget build(BuildContext context) {
    final rest = contacts;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
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
                onTap: onNewRoom,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: HaloColors.violet,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'room',
                        style: HaloType.mono(
                          size: 10,
                          color: HaloColors.violet,
                          letter: 0.14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
        // a room that just ended: one quiet line, gone in a few seconds
        if (expiredRoomName != null)
          _Enter(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '${expiredRoomName!} · room expired',
                style: HaloType.mono(size: 10, color: HaloColors.violet),
              ),
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
      splashColor: HaloColors.amber.withValues(alpha: 0.10),
      highlightColor: HaloColors.amber.withValues(alpha: 0.05),
      child: Ink(
        decoration: g.unread > 0
            ? BoxDecoration(
                color: HaloColors.amber.withValues(alpha: 0.06),
                border: Border(
                  left: BorderSide(color: HaloColors.amber, width: 2),
                ),
              )
            : null,
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
                  color: g.isRoom
                      ? HaloColors.violet.withValues(alpha: 0.14)
                      : HaloColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (g.isRoom ? HaloColors.violet : HaloColors.amber)
                        .withValues(alpha: 0.35),
                    width: 0.6,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  g.name.isEmpty ? '·' : g.name.characters.first.toUpperCase(),
                  style: HaloType.serif(
                    size: 18,
                    italic: true,
                    color: g.isRoom ? HaloColors.violet : HaloColors.amber,
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
                        weight: g.unread > 0
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: HaloColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (g.isRoom)
                      RoomCountdown(expiresAt: g.expiresAt!, size: 10)
                    else
                      Text(
                        '${g.memberCount} members',
                        style: HaloType.mono(size: 10, color: HaloColors.text3),
                      ),
                  ],
                ),
              ),
              if (g.unread > 0) ...[
                const SizedBox(width: 8),
                _UnreadBadge(g.unread),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// unread count. pops when the number changes so a message arriving while you
// are looking at the list is not a silent swap.
class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 0.55, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        constraints: const BoxConstraints(minWidth: 18),
        decoration: BoxDecoration(
          color: HaloColors.amber,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: HaloType.sans(
            size: 10,
            weight: FontWeight.w600,
            color: HaloColors.onAmber,
          ),
        ),
      ),
    );
  }
}

Widget _supporterPill() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: HaloColors.amber.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: HaloColors.amber.withValues(alpha: 0.4)),
    ),
    child: Text(
      'supporter',
      style: HaloType.mono(size: 8, color: HaloColors.amber),
    ),
  );
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
      key: ValueKey('swipe_${c.haloId}'),
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
        child: Semantics(
          label: 'archived chats',
          button: true,
          child: Icon(
            Icons.archive_outlined,
            size: 20,
            color: HaloColors.amber,
          ),
        ),
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
      child: _Row(c: c, onTap: onTap, onLongPress: () => _chatMenu(context, c)),
    );
  }
}

void _chatMenu(BuildContext context, ContactPreview c) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: HaloColors.surface2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: HaloColors.text3.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: Icon(
              c.muted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: HaloColors.text2,
              size: 22,
            ),
            title: Text(
              c.muted ? 'unmute' : 'mute',
              style: HaloType.sans(size: 15, color: HaloColors.text),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              c.muted ? appState.unmute(c.haloId) : appState.mute(c.haloId);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.archive_outlined,
              color: HaloColors.amber,
              size: 22,
            ),
            title: Text(
              'archive',
              style: HaloType.sans(size: 15, color: HaloColors.text),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              appState.archive(c.haloId);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: HaloColors.rose,
              size: 22,
            ),
            title: Text(
              'delete chat',
              style: HaloType.sans(size: 15, color: HaloColors.rose),
            ),
            subtitle: Text(
              'messages and contact, gone from this phone',
              style: HaloType.mono(size: 11, color: HaloColors.text3),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              _confirmDelete(context, c);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _confirmDelete(BuildContext context, ContactPreview c) {
  showDialog<void>(
    context: context,
    builder: (dctx) => AlertDialog(
      backgroundColor: HaloColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'delete this chat?',
        style: HaloType.serif(size: 19, color: HaloColors.text),
      ),
      content: Text(
        'every message with ${c.nickname ?? c.haloId} goes, and they stop '
        'being a contact. it only clears this phone - their copy stays with '
        'them. if they message again it lands in requests.',
        style: HaloType.sans(size: 14, color: HaloColors.text2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx),
          child: Text(
            'keep',
            style: HaloType.sans(size: 14, color: HaloColors.text2),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dctx);
            HapticFeedback.heavyImpact();
            await appState.deleteConversation(c.haloId);
          },
          child: Text(
            'delete',
            style: HaloType.sans(
              size: 14,
              color: HaloColors.rose,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  final ContactPreview c;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _Row({required this.c, required this.onTap, this.onLongPress});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: HaloColors.amber.withValues(alpha: 0.10),
      highlightColor: HaloColors.amber.withValues(alpha: 0.05),
      // Ink, not Container: an unread row tints itself amber, and a Container
      // paints that tint over the splash so the tap looks dead.
      child: Ink(
        decoration: c.unread > 0
            ? BoxDecoration(
                color: HaloColors.amber.withValues(alpha: 0.06),
                border: Border(
                  left: BorderSide(color: HaloColors.amber, width: 2),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Opacity(
              opacity: c.blocked ? 0.4 : 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  KryfoAvatar(seed: c.avatarSeed, size: 44, choice: c.avatar),
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
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                c.nickname ?? c.haloId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HaloType.sans(
                                  size: 14,
                                  weight: c.unread > 0
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: c.blocked
                                      ? HaloColors.text3
                                      : HaloColors.text,
                                ),
                              ),
                            ),
                            if (c.supporterBadge != null) ...[
                              const SizedBox(width: 6),
                              _supporterPill(),
                            ],
                          ],
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
                            style: HaloType.serif(
                              size: 11.5,
                              italic: true,
                              color: c.unread > 0
                                  ? HaloColors.amber
                                  : HaloColors.text3,
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
                            color: c.unread > 0
                                ? HaloColors.text2
                                : HaloColors.text2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.unread > 0) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(c.unread),
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
  if (d.inDays == 1) return 'yesterday';
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
  final VoidCallback onSupportTap;
  const _NavTabs({
    required this.active,
    required this.onDevLongPress,
    required this.onMeTap,
    required this.onSupportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
      // every tab gets the SAME padding and an equal share of the row.
      // before, only Support/Me were padded, so the gaps were visibly
      // uneven. 'Drop' is gone - it had no handler and did nothing.
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(
                child: _Tab(label: 'Chats', active: active == 'chats'),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onSupportTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Center(
                  child: _Tab(label: 'Support', active: active == 'support'),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: onDevLongPress,
              onTap: onMeTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Center(
                  child: _Tab(label: 'Me', active: active == 'me'),
                ),
              ),
            ),
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

class _SavedPin extends StatelessWidget {
  final VoidCallback onTap;
  const _SavedPin({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
              child: Icon(Icons.bookmark, color: HaloColors.amber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'saved',
                    style: HaloType.serif(
                      size: 14,
                      color: HaloColors.text,
                      italic: true,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'messages you kept, from every chat',
                    style: HaloType.sans(size: 11.5, color: HaloColors.text3),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: HaloColors.text3, size: 18),
          ],
        ),
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
            Icon(Icons.chevron_right, color: HaloColors.text3, size: 18),
          ],
        ),
      ),
    );
  }
}

// unknown-sender requests. amber, shows a count, only rendered when > 0.
class _RequestsPin extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _RequestsPin({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: HaloColors.amber.withValues(alpha: 0.35),
            width: 0.8,
          ),
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
                Icons.mail_outline,
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
                    'requests',
                    style: HaloType.serif(
                      size: 14,
                      color: HaloColors.text,
                      italic: true,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    count == 1
                        ? '1 person wants to reach you'
                        : '$count people want to reach you',
                    style: HaloType.sans(size: 11, color: HaloColors.text3),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: HaloType.sans(
                  size: 12,
                  weight: FontWeight.w700,
                  color: const Color(0xFF1A0F04),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
