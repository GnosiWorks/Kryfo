// SPDX-License-Identifier: GPL-3.0-or-later
// home screen. date header, hero card or empty state, nav tabs.
// matches 08_complete_spec.html "the everyday" home tile.

import 'saved_screen.dart';
import 'transport_screen.dart';
import '../widgets/press_scale.dart';
import 'modes_screen.dart' show showFastGateSheet;
import '../widgets/stagger_in.dart';
import '../widgets/breathing_ring.dart';
import 'requests_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'donate_screen.dart';
import 'profile_screen.dart';
import 'tools_screen.dart';
import 'clean_screen.dart';
import 'photo_knows_screen.dart';
import 'qr_screen.dart';
import 'lock_file_screen.dart';
import 'open_locked_screen.dart';
import '../tools/tools_bridge.dart';
import '../lock_state.dart';
import '../widgets/nav_bar.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/room_countdown.dart';
import '../widgets/kryfo_avatar.dart';
import 'notes_screen.dart';
import 'bridges_screen.dart';
import 'archived_screen.dart';
import '../miui_autostart.dart';
import '../main.dart';
import '../widgets/motion.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/shift_in_place.dart';
import '../widgets/confirm_sheet.dart';
import '../notif_permission.dart';
import '../delivery_mode.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../l10n/numbers.dart';
import 'search_screen.dart';

bool _miuiPromptChecked = false;

class HomeScreen extends StatefulWidget {
  final String haloId; // "neon-tiger-saturn"
  final List<ContactPreview> contacts;
  final List<GroupSummary> groups;
  final int pendingCount;
  final VoidCallback onAddContact;
  final VoidCallback onNewGroup;
  final VoidCallback onNewRoom;
  final String? expiredRoomName;
  final VoidCallback onOpenDev;
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
    required this.onOpenSettingsDirect,
    this.pendingCount = 0,
    required this.onOpenChat,
    required this.onOpenGroup,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HaloTab _tab = HaloTab.chats;
  final Set<HaloTab> _seen = {HaloTab.chats};
  StreamSubscription<void>? _sharedSub;
  Timer? _sweeper;
  Widget? _heldTool;

  @override
  void initState() {
    super.initState();
    _sharedSub = ToolsBridge.instance.shared.listen((_) => _takeShared());
    lockState.addListener(_onLock);
    // a tab that has been opened once stays in the tree behind an Offstage,
    // which is what makes switching back instant - and what left it painted
    // in the palette it was built in. switching to the light theme from
    // settings repainted this screen and not the tools tab behind it, so the
    // heading there stayed white on cream until the app was restarted.
    themeRevision.addListener(_repaint);
    ToolsBridge.instance.sweep();
    _sweeper = Timer.periodic(
      const Duration(minutes: 5),
      (_) => ToolsBridge.instance.sweep(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeShared());
  }

  @override
  void dispose() {
    _sharedSub?.cancel();
    lockState.removeListener(_onLock);
    themeRevision.removeListener(_repaint);
    _sweeper?.cancel();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  Future<void> _takeShared() async {
    final f = await ToolsBridge.instance.takeShared();
    if (f != null) _clean(f);
  }

  Future<void> _pickToClean() async {
    final f = await ToolsBridge.instance.pick('media');
    if (f != null) _clean(f);
  }

  Future<void> _pickToRead(String kind) async {
    final f = await ToolsBridge.instance.pick(kind);
    if (f != null) _openTool(PhotoKnowsScreen(file: f));
  }

  Future<void> _pickFor(Widget Function(PickedFile) screen) async {
    final f = await ToolsBridge.instance.pick('any');
    if (f != null) _openTool(screen(f));
  }

  void _clean(PickedFile f) => _openTool(CleanScreen(file: f));

  // the lock is a route on this same navigator. opening a tool under it, or
  // clearing the stack to make room for one, would take the lock away, so a
  // share or a pick that lands while locked waits for the pin.
  void _openTool(Widget screen) {
    if (!mounted) return;
    if (!lockState.loaded || lockState.locked) {
      _heldTool = screen;
      return;
    }
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    _pick(HaloTab.tools);
    nav.push(haloRoute(screen));
  }

  void _onLock() {
    final held = _heldTool;
    if (held == null || !lockState.loaded || lockState.locked) return;
    _heldTool = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTool(held));
  }

  void _pick(HaloTab t) {
    if (t == _tab) return;
    setState(() {
      _tab = t;
      _seen.add(t);
    });
  }

  Widget _body(HaloTab t) {
    switch (t) {
      case HaloTab.chats:
        return _ChatsTab(
          haloId: widget.haloId,
          contacts: widget.contacts,
          groups: widget.groups,
          pendingCount: widget.pendingCount,
          onAddContact: widget.onAddContact,
          onNewGroup: widget.onNewGroup,
          onNewRoom: widget.onNewRoom,
          expiredRoomName: widget.expiredRoomName,
          onOpenSettingsDirect: widget.onOpenSettingsDirect,
          onOpenChat: widget.onOpenChat,
          onOpenGroup: widget.onOpenGroup,
        );
      case HaloTab.tools:
        return ToolsScreen(
          onPickPhoto: () => _pickToRead('image'),
          onPickVideo: () => _pickToRead('video'),
          onClean: _pickToClean,
          onQr: () => _openTool(const QrScreen()),
          onLock: () => _pickFor((f) => LockFileScreen(file: f)),
          onOpenLocked: () => _pickFor((f) => OpenLockedScreen(file: f)),
        );
      case HaloTab.support:
        return const DonateScreen();
      case HaloTab.me:
        return ProfileScreen(onOpenSupport: () => _pick(HaloTab.support));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == HaloTab.chats,
      onPopInvokedWithResult: (done, _) {
        if (!done) _pick(HaloTab.chats);
      },
      child: Scaffold(
        backgroundColor: HaloColors.surface,
        body: Column(
          children: [
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Stack(
                  children: [
                    for (final t in HaloTab.values)
                      if (_seen.contains(t))
                        Offstage(
                          offstage: t != _tab,
                          child: TickerMode(
                            enabled: t == _tab,
                            // keyed on the theme so a switch rebuilds the
                            // whole tab from scratch. HaloColors is a palette
                            // swapped in place, and a const widget handed back
                            // to a rebuild is skipped, so anything const in
                            // here would otherwise keep the colours it was
                            // first built with. the tools heading stayed white
                            // on cream that way until the app was restarted.
                            child: KeyedSubtree(
                              key: ValueKey(HaloColors.isLight),
                              child: _Arrive(on: t == _tab, child: _body(t)),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: HaloNavBar(
                active: _tab,
                onPick: _pick,
                onMeLongPress: widget.onOpenDev,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Arrive extends StatefulWidget {
  final bool on;
  final Widget child;
  const _Arrive({required this.on, required this.child});
  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );

  @override
  void didUpdateWidget(_Arrive old) {
    super.didUpdateWidget(old);
    if (!widget.on || old.on) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, 8 * (1 - a.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  final String haloId; // "neon-tiger-saturn"
  final List<ContactPreview> contacts;
  final List<GroupSummary> groups;
  final int pendingCount;
  final VoidCallback onAddContact;
  final VoidCallback onNewGroup;
  final VoidCallback onNewRoom;
  final String? expiredRoomName;
  final VoidCallback onOpenSettingsDirect;
  final void Function(String kryfo) onOpenChat;
  final void Function(String groupId) onOpenGroup;

  const _ChatsTab({
    required this.haloId,
    this.contacts = const [],
    this.groups = const [],
    required this.onAddContact,
    required this.onNewGroup,
    required this.onNewRoom,
    this.expiredRoomName,
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
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          StaggerIn(
            index: 0,
            child: _HomeHead(
              now: now,
              haloId: haloId,
              onAdd: onAddContact,
              onSettings: onOpenSettingsDirect,
            ),
          ),
          const _OfflineStrip(),
          const _BridgeHint(),
          const _BridgeStuckHint(),
          const _RelayDownHint(),
          const _OfflineCard(),
          const _KeepsStoppingCard(),
          const _NotificationsBlockedHint(),
          StaggerIn(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: SearchField(
                onTap: () => Navigator.of(context).push(searchRoute()),
              ),
            ),
          ),
          StaggerIn(
            index: 1,
            child: _QuickTiles(
              onNotes: () =>
                  Navigator.of(context).push(haloRoute(const NotesScreen())),
              onSaved: () =>
                  Navigator.of(context).push(haloRoute(const SavedScreen())),
            ),
          ),
          if (pendingCount > 0)
            StaggerIn(
              index: 2,
              child: _RequestsPin(
                count: pendingCount,
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const RequestsScreen())),
              ),
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
            child: visible.isEmpty && groups.isEmpty
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
        ],
      ),
    );
  }
}

Route<void> _archivedRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 280),
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
  final bool mentioned;
  final int? expiresAt; // set for a burner room
  const GroupSummary({
    required this.groupId,
    required this.name,
    required this.memberCount,
    this.unread = 0,
    this.mentioned = false,
    this.expiresAt,
  });
  bool get isRoom => expiresAt != null;
}

// ───────── date header ─────────

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
          label: l10n.homeAddAContact,
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
    return Semantics(
      label: l10n.commonSettings,
      button: true,
      child: GestureDetector(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // one line each, shrunk to fit rather than broken: a long
                // weekday or month ("Donnerstag", "24. September") beside the
                // buttons was split in the middle of the word
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.homeDateWeekday(weekday(now)),
                    maxLines: 1,
                    style: HaloType.serif(size: 26, weight: FontWeight.w400),
                    // display type, capped. at 200% this became one word per
                    // line and pushed the whole list off screen.
                    textScaler: TextScaler.linear(
                      MediaQuery.of(
                        context,
                      ).textScaler.scale(1).clamp(1.0, 1.15),
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    dayMonthLong(now),
                    maxLines: 1,
                    style: HaloType.serif(
                      size: 26,
                      weight: FontWeight.w300,
                      color: HaloColors.amber,
                      italic: true,
                    ),
                    textScaler: TextScaler.linear(
                      MediaQuery.of(
                        context,
                      ).textScaler.scale(1).clamp(1.0, 1.15),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.homeYourKryfo,
                  style: HaloType.mono(
                    size: 9.5,
                    color: HaloColors.text3,
                    letter: 0.14,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
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

// android is not letting kryfo put a notification up. nothing arrives
// while the app is closed and, before this, nothing said so. the android
// 13 permission dialog does not come back once the answer is final, so
// the only way out is the page this opens.
class _NotificationsBlockedHint extends StatefulWidget {
  const _NotificationsBlockedHint();

  @override
  State<_NotificationsBlockedHint> createState() =>
      _NotificationsBlockedHintState();
}

// this phone has killed kryfo three times in a day while it was supposed
// to be staying connected. said once, ever, and only after it has happened:
// no vendor list, no guessing from the model name.
// tor has been unable to carry traffic for five minutes while kryfo is meant
// to be connected. a samsung once sat like this for ten and a half hours with
// nothing on screen; silence is the part being fixed here, so this says it
// plainly and offers the one useful button.
//
// it keeps its own timer because the status poll only wakes listeners when
// the status changes, and staying off is the absence of a change.
class _OfflineCard extends StatefulWidget {
  const _OfflineCard();

  @override
  State<_OfflineCard> createState() => _OfflineCardState();
}

class _OfflineCardState extends State<_OfflineCard> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _reconnect() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    engine.restartTor();
    // the bounce reports itself through the status poll; this only stops the
    // button being hammered while it runs.
    await Future<void>.delayed(const Duration(seconds: 6));
    if (mounted) setState(() => _busy = false);
  }

  String _howLong(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      return h == 1 ? l10n.homeAnHour : l10n.homeHours(h);
    }
    return l10n.homeMinutes(d.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        if (!appState.looksOffline) return const SizedBox.shrink();
        final since = appState.offlineFor ?? Duration.zero;
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
                    l10n.homeKryfoIsOffline,
                    style: HaloType.mono(
                      size: 11,
                      color: HaloColors.rose,
                      weight: FontWeight.w600,
                      letter: 0.12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.homeTorHasNotBeen(_howLong(since)),
                style: HaloType.sans(size: 13, color: HaloColors.warm),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: _busy ? null : _reconnect,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _busy
                            ? HaloColors.rose.withValues(alpha: 0.45)
                            : HaloColors.rose,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _busy ? l10n.homeReconnecting : l10n.homeReconnect,
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
                    onTap: () => Navigator.of(
                      context,
                    ).push(haloRoute(const TransportScreen())),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.homeWhatIsWrong,
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.warm,
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

class _KeepsStoppingCard extends StatefulWidget {
  const _KeepsStoppingCard();

  @override
  State<_KeepsStoppingCard> createState() => _KeepsStoppingCardState();
}

class _KeepsStoppingCardState extends State<_KeepsStoppingCard> {
  bool _busy = false;

  Future<void> _switch() async {
    if (_busy) return;
    setState(() => _busy = true);
    await appState.setDeliveryMode(DeliveryMode.checkins);
    await appState.nudgeAnswered();
    if (!mounted) return;
    showHaloToast(context, l10n.homeKryfoWillCheckIn);
    unawaited(forceShowBackgroundPrompt(context));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        if (!appState.nudgeDue) return const SizedBox.shrink();
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
                    l10n.homeYourPhoneKeepsStopping,
                    style: HaloType.mono(
                      size: 11,
                      color: HaloColors.amber,
                      weight: FontWeight.w600,
                      letter: 0.12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.homeItHasClosedKryfo,
                style: HaloType.sans(size: 13, color: HaloColors.warm),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: _switch,
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
                        l10n.homeSwitchToCheckIns,
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
                    onTap: () => appState.nudgeAnswered(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.homeNotNow,
                        style: HaloType.mono(
                          size: 11.5,
                          color: HaloColors.warm,
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

class _NotificationsBlockedHintState extends State<_NotificationsBlockedHint>
    with WidgetsBindingObserver {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // coming back from android's settings is the moment the answer changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final on = await notificationsEnabled();
    if (on) await clearNotifHintDismissal();
    final show = !on && !await notifHintDismissed();
    if (mounted && show != _show) setState(() => _show = show);
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
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
                l10n.homeNotificationsAreOff,
                style: HaloType.mono(
                  size: 11,
                  color: HaloColors.amber,
                  weight: FontWeight.w600,
                  letter: 0.12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.homeAndroidIsBlockingThem,
            style: HaloType.sans(size: 13, color: HaloColors.text2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final opened = await openNotificationSettings();
                  if (!opened && context.mounted) {
                    showHaloToast(context, l10n.homeCouldnTOpenIt);
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
                    l10n.homeTurnThemOn,
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
                onTap: () async {
                  await dismissNotifHint();
                  if (mounted) setState(() => _show = false);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.homeLeaveThemOff,
                    style: HaloType.mono(size: 11.5, color: HaloColors.text2),
                  ),
                ),
              ),
            ],
          ),
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
                    l10n.homeOurRelayIsQuiet,
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
                l10n.homeRelayModeUsesOnly,
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      // same warning as the modes screen: fast mode shows
                      // your address to public relays
                      final ok = await showFastGateSheet(context);
                      if (!ok || !context.mounted) return;
                      await appState.setSendMode('fast');
                      if (context.mounted) {
                        showHaloToast(context, l10n.homeSwitchedToFast);
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
                        l10n.homeUseFastMode,
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
                        l10n.homeKeepWaiting,
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
                    l10n.homeNotConnecting,
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
                l10n.homeBridgesAreOnAnd,
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
              const SizedBox(height: 13),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await appState.applyBridges(appState.bridgeLines, false);
                  engine.restartTor();
                  if (context.mounted) {
                    showHaloToast(context, l10n.homeGoingDirectReconnecting);
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
                    l10n.homeTurnBridgesOff,
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
                    l10n.homeStillTrying,
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
                l10n.homeTorIsNotGetting,
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
                        showHaloToast(context, l10n.homeSwitchedToRelay);
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
                        l10n.homeUseOurRelay,
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
                        l10n.homeBridges,
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
                        l10n.homeKeepWaiting,
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
        final p = appState.parkedQueued;
        // a send in flight while the phone can send is not news: it showed
        // "waiting" and a retry for every message typed from home. the strip
        // speaks when the phone cannot send, or when a message waits on
        // someone who has not added you back.
        final cannotSend = !appState.online || !appState.torReady;
        // "or when a message waits on someone who has not added you back"
        // is the second half of the rule above, and it was dropped from
        // this line. without it every branch below that needs a working
        // phone was unreachable: the parked tails and the retry button
        // could not render at all, so a message parked on a peer who has
        // not added you back was invisible everywhere on home.
        if (!cannotSend && p == 0) return const SizedBox.shrink();

        final offline = !appState.online;
        final torDown = !offline && !appState.torReady;
        // tor coming up is what every launch looks like. with an empty
        // queue there is nothing to explain and the halo already says so,
        // and the strip said "waiting" over "nothing waiting to send",
        // which is two opposite things at once. offline is different: that
        // is worth stating even with nothing queued.
        if (torDown && n == 0 && p == 0) return const SizedBox.shrink();
        final tint = offline ? HaloColors.rose : HaloColors.amber;
        final head = offline ? l10n.homeOffline : l10n.homeWaiting;
        // the old strip said "offline" and stopped, which left people
        // guessing whether anything was queued or lost.
        final tail = n == 0
            ? l10n.homeNothingWaitingToSend
            : offline
            ? l10n.homeWaitingSendsWhenYou(n)
            : torDown
            ? l10n.homeWaitingTorIsStill(n)
            : p >= n
            ? l10n.homeWaitingForThemTo(n)
            : p > 0
            ? l10n.homeWaitingForThemToAddYou(n, p)
            : l10n.homeWaitingSendingNow(n);

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
              if (n > 0 && !offline && !torDown) ...[
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
                      l10n.commonRetry,
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

class _EmptyStateState extends State<_EmptyState> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreathingRing(
              child: Container(
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
                  Icons.person_add_alt_1_outlined,
                  color: HaloColors.amber,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.homeNoKryfosYet,
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
              l10n.homeScanTheirCodeSend,
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
                  l10n.homeAddSomeone,
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
                        l10n.homeArchived,
                        style: HaloType.sans(
                          size: 14,
                          weight: FontWeight.w500,
                          color: HaloColors.text,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        l10n.home1Chat(count),
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
    // pulled down past the top, the list opens search
    var opened = false;
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        if (!opened &&
            n.dragDetails != null &&
            n.metrics.axis == Axis.vertical &&
            n.metrics.pixels < -72) {
          opened = true;
          HapticFeedback.lightImpact();
          Navigator.of(context).push(searchRoute());
        }
        if (n.metrics.pixels >= 0) opened = false;
        return false;
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // groups section (header + rows + new-group tile). always show the
          // tile so user can create a group even with no existing groups.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: Row(
              children: [
                Text(
                  l10n.homeGroups,
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
                    padding: const EdgeInsetsDirectional.only(end: 14),
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
                          l10n.homeRoom,
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
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: HaloColors.amber,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        l10n.homeNew,
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
                  l10n.homeRoomExpired(expiredRoomName!),
                  style: HaloType.mono(size: 10, color: HaloColors.violet),
                ),
              ),
            ),
          // keyed, so a row that moves up on a new message glides there
          ...groups.asMap().entries.map(
            (e) => ShiftInPlace(
              key: ValueKey('g-${e.value.groupId}'),
              index: e.key,
              child: _Enter(
                index: 1 + e.key,
                child: _GroupRow(
                  g: e.value,
                  onTap: () => onOpenGroup(e.value.groupId),
                ),
              ),
            ),
          ),
          if (rest.isNotEmpty) ...[
            ...rest.asMap().entries.map(
              (e) => ShiftInPlace(
                key: ValueKey('c-${e.value.haloId}'),
                index: groups.length + e.key,
                child: _Enter(
                  index: 1 + groups.length + e.key,
                  child: _SwipeRow(
                    c: e.value,
                    onTap: () => onTap(e.value.haloId),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
                border: BorderDirectional(
                  start: BorderSide(color: HaloColors.amber, width: 2),
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
              Hero(
                tag: 'group-${g.groupId}',
                child: Container(
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
                    g.name.isEmpty
                        ? '·'
                        : g.name.characters.first.toUpperCase(),
                    style: HaloType.serif(
                      size: 18,
                      italic: true,
                      color: g.isRoom ? HaloColors.violet : HaloColors.amber,
                    ),
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
                    else if (g.mentioned)
                      // your three words came up in there
                      Text(
                        l10n.homeMentionedYou,
                        style: HaloType.mono(
                          size: 10,
                          color: HaloColors.amber,
                          weight: FontWeight.w600,
                          letter: 0.06,
                        ),
                      )
                    else
                      Text(
                        l10n.homeMembers(g.memberCount),
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
      l10n.homeSupporter,
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
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsetsDirectional.only(start: 24),
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
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        child: Semantics(
          label: l10n.homeArchivedChats,
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
  showHaloSheet<void>(
    context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
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
              c.muted ? l10n.homeUnmute : l10n.homeMute,
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
              l10n.homeArchive,
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
              l10n.homeDeleteChat,
              style: HaloType.sans(size: 15, color: HaloColors.rose),
            ),
            subtitle: Text(
              l10n.homeMessagesAndContactGone,
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

Future<void> _confirmDelete(BuildContext context, ContactPreview c) async {
  final ok = await showConfirmSheet(
    context,
    title: l10n.homeDeleteThisChat,
    line: l10n.homeEveryMessageWithGoes(c.nickname ?? c.haloId),
    yes: l10n.commonDelete,
  );
  if (!ok) return;
  HapticFeedback.heavyImpact();
  await appState.deleteConversation(c.haloId);
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
                border: BorderDirectional(
                  start: BorderSide(color: HaloColors.amber, width: 2),
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
                  Hero(
                    tag: 'face-${c.avatarSeed}',
                    child: KryfoAvatar(
                      seed: c.avatarSeed,
                      size: 44,
                      choice: c.avatar,
                    ),
                  ),
                  if (c.verified)
                    PositionedDirectional(
                      end: -1,
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
                          // a message still in the outbox says so where the
                          // time would be, so the row is honest about it
                          if (!c.blocked &&
                              appState.queuedFor(c.haloId) > 0 &&
                              (!appState.online || !appState.torReady))
                            Text(
                              l10n.homeQueued,
                              style: HaloType.mono(
                                size: 10,
                                color: HaloColors.text2,
                                letter: 0.08,
                              ),
                            )
                          else
                            Text(
                              (c.blocked ? l10n.homeBlocked : _relTime(c.when)),
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
                          // a room link is an invitation, not a line of
                          // two hundred characters
                          (c.preview ?? '').contains('kryfo://room?')
                              ? l10n.homeRoomInvite
                              : (c.preview ?? ''),
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
  if (d.inMinutes < 1) return l10n.homeNow;
  if (d.inMinutes < 60) return l10n.homeM(whole(d.inMinutes));
  if (d.inHours < 24) return l10n.homeH(whole(d.inHours));
  if (d.inDays == 1) return l10n.homeYesterday;
  if (d.inDays < 7) return l10n.homeD(whole(d.inDays));
  // older than a week: a short date reads better than a big day count
  return dayMonth(t);
}

// unknown-sender requests. amber, shows a count, only rendered when > 0.
// the two quiet places, side by side, so the chats start higher up
class _QuickTiles extends StatelessWidget {
  final VoidCallback onNotes;
  final VoidCallback onSaved;
  const _QuickTiles({required this.onNotes, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    // the two tiles keep one height when one subtitle wraps and the other
    // does not
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.edit_note_rounded,
                title: l10n.homeNoteToSelf,
                line: l10n.homeOnlyOnThisPhone,
                onTap: onNotes,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickTile(
                icon: Icons.bookmark,
                title: l10n.homeSaved,
                line: l10n.homeKeptFromEveryChat,
                onTap: onSaved,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line;
  final VoidCallback onTap;
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.line,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: title,
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 10, 11),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: HaloColors.amber, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // the whole title, shrunk if it has to be: at a big
                  // font size in german it read "Notiz an ..."
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: HaloType.serif(
                        size: 14,
                        color: HaloColors.text,
                        italic: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.sans(size: 10.5, color: HaloColors.text3),
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
                    l10n.homeRequests,
                    style: HaloType.serif(
                      size: 14,
                      color: HaloColors.text,
                      italic: true,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    l10n.home1PersonWantsTo(count),
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
                  color: HaloColors.onAmber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
