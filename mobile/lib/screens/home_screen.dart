// SPDX-License-Identifier: GPL-3.0-or-later
// home screen: date header, the chat list or empty state, and the nav tabs.

import 'saved_screen.dart';
import 'transport_screen.dart';
import '../widgets/press_scale.dart';
import 'modes_screen.dart' show showFastGateSheet;
import '../widgets/stagger_in.dart';
import 'requests_screen.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
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
import '../lock_guard.dart' show lockGuard;
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
import '../main.dart' hide live;
import '../widgets/motion.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/shift_in_place.dart';
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/row_motion.dart';
import '../widgets/count_badge.dart';
import '../widgets/chat_parts.dart' show GrowSwap;
import '../widgets/swap.dart';
import '../widgets/message_menu.dart' show MenuSheet, MenuSheetRow;
import '../widgets/confirm_sheet.dart';
import '../widgets/hidden_mark.dart';
import '../widgets/home_pin.dart';
import '../widgets/swipe_actions.dart';
import '../notif_permission.dart';
import '../seen_timers.dart';
import '../delivery_mode.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../l10n/numbers.dart';
import '../devchat/dev_chat.dart' show DevRow;
import '../widgets/dev_avatar.dart';
import 'dev_about_sheet.dart';
import 'search_screen.dart';
import 'group_info_screen.dart' show leaveLine;
import 'support_screen.dart' show SupportPin, supportRoute;

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
  // the developer chat's row, beside the contacts. none to show: null
  final DevRow? devRow;
  // his own phone: the support chats waiting for an answer. null elsewhere,
  // and no pin
  final int? support;

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
    this.devRow,
    this.support,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HaloTab _tab = HaloTab.chats;
  final Set<HaloTab> _seen = {HaloTab.chats};
  StreamSubscription<void>? _sharedSub;
  // tool leftovers, swept every few minutes while kryfo is in front. away,
  // the timer does not wake the phone; back, a sweep that fell due runs
  final _sweeper = SeenTimers();
  Widget? _heldTool;
  // the way the last tab switch went: 1 towards the end of the bar
  int _towards = 1;
  // the tab picked this frame: made for it, it slides in all the same
  HaloTab? _picked;

  @override
  void initState() {
    super.initState();
    _sharedSub = ToolsBridge.instance.shared.listen((_) => _takeShared());
    lockState.addListener(_onLock);
    // a tab opened once stays in the tree behind an Offstage, so a theme
    // switch has to repaint the tabs behind this one too
    themeRevision.addListener(_repaint);
    ToolsBridge.instance.sweep();
    _sweeper.every(
      const Duration(minutes: 5),
      () => ToolsBridge.instance.sweep(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeShared());
  }

  @override
  void dispose() {
    _sharedSub?.cancel();
    lockState.removeListener(_onLock);
    themeRevision.removeListener(_repaint);
    _sweeper.dispose();
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
      _towards = t.index > _tab.index ? 1 : -1;
      _tab = t;
      _seen.add(t);
      _picked = t;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _picked = null);
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
          devRow: widget.devRow,
          onOpenDevChat: (id) => openDevChat(context, id),
          support: widget.support,
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
                            // here would keep the colours it was built with.
                            child: KeyedSubtree(
                              key: ValueKey(HaloColors.isLight),
                              child: _Arrive(
                                on: t == _tab,
                                towards: _towards,
                                fresh: t == _picked,
                                child: _body(t),
                              ),
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
                // the developer screen is for debug builds only
                onMeLongPress: kDebugMode ? widget.onOpenDev : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// a tab coming into view slides in from the side of the bar it lies on,
// fading up. with less movement it is simply there
class _Arrive extends StatefulWidget {
  final bool on;
  // 1: the tab picked lies towards the end of the bar, so it comes in from
  // that side. -1 from the start
  final int towards;
  // made by the pick: it comes in as a tab seen before does
  final bool fresh;
  final Widget child;
  const _Arrive({
    required this.on,
    required this.towards,
    required this.child,
    this.fresh = false,
  });
  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: kHouseTime,
    value: 1,
  );
  late final _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final _slide = CurvedAnimation(parent: _c, curve: kHouseCurve);
  bool _made = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_made) return;
    _made = true;
    if (widget.on && widget.fresh) _go();
  }

  @override
  void didUpdateWidget(_Arrive old) {
    super.didUpdateWidget(old);
    if (!widget.on || old.on) return;
    _go();
  }

  void _go() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    _slide.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // mirrored where the bar reads right to left
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final from = 28.0 * widget.towards * (rtl ? -1 : 1);
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (_, child) => Transform.translate(
          offset: Offset(from * (1 - _slide.value), 0),
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
  final DevRow? devRow;
  final void Function(String chatId) onOpenDevChat;
  final int? support;

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
    this.devRow,
    required this.onOpenDevChat,
    this.support,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = contacts.where((c) => !c.archived).toList();
    // an archived developer chat counts with the rest in the archive
    final dev = devRow;
    final devShown = dev != null && !dev.archived ? dev : null;
    final archived =
        contacts.where((c) => c.archived).length +
        (dev != null && dev.archived ? 1 : 0);
    final hasArchived = archived > 0;
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
          // the two pins open and fold with what they count, so the list
          // under them slides rather than jumps
          GrowSwap(
            alignment: Alignment.topCenter,
            child: pendingCount > 0
                ? StaggerIn(
                    key: const ValueKey('requests'),
                    index: 2,
                    child: _RequestsPin(
                      count: pendingCount,
                      onTap: () => Navigator.of(
                        context,
                      ).push(haloRoute(const RequestsScreen())),
                    ),
                  )
                : const SizedBox(key: ValueKey('no-requests'), width: 1),
          ),
          if (support != null)
            StaggerIn(
              index: 2,
              child: SupportPin(
                waiting: support!,
                onTap: () => Navigator.of(context).push(supportRoute()),
              ),
            ),
          GrowSwap(
            alignment: Alignment.topCenter,
            child: hasArchived
                ? _ArchivedPin(
                    key: const ValueKey('archived'),
                    count: archived,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(
                        context,
                      ).push(haloRoute(const ArchivedScreen()));
                    },
                  )
                : const SizedBox(key: ValueKey('no-archived'), width: 1),
          ),
          // the empty page and the list cross-fade as the first chat comes
          // or the last one goes
          Expanded(
            child: FadeSwap(
              child: visible.isEmpty && groups.isEmpty
                  ? _EmptyWithDev(
                      key: const ValueKey('empty'),
                      dev: devShown,
                      onOpenDev: onOpenDevChat,
                      onAdd: onAddContact,
                    )
                  : _ContactList(
                      key: const ValueKey('list'),
                      contacts: visible,
                      groups: groups,
                      dev: devShown,
                      onTap: onOpenChat,
                      onOpenDev: onOpenDevChat,
                      onOpenGroup: onOpenGroup,
                      onNewGroup: onNewGroup,
                      onNewRoom: onNewRoom,
                      expiredRoomName: expiredRoomName,
                    ),
            ),
          ),
        ],
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
  // the face they picked, if they have. null means draw from their id.
  final int? avatar;
  final bool blocked;
  final bool archived;
  final bool muted;
  final bool verified;
  final int unread;
  final bool pinned;
  final String? supporterBadge;
  // one of the open vault's: only its session shows it
  final bool hidden;
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
    this.hidden = false,
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
  final bool hidden;
  const GroupSummary({
    required this.groupId,
    required this.name,
    required this.memberCount,
    this.unread = 0,
    this.mentioned = false,
    this.expiresAt,
    this.hidden = false,
  });
  bool get isRoom => expiresAt != null;
}

// ───────── date header ─────────

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

class _GearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GearButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: l10n.commonSettings,
      scale: 0.9,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: HaloColors.line2, width: 1.4),
        ),
        child: Icon(Icons.settings_outlined, size: 19, color: HaloColors.text2),
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
                // buttons would split in the middle of the word
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.homeDateWeekday(weekday(now)),
                    maxLines: 1,
                    style: HaloType.serif(size: 26, weight: FontWeight.w400),
                    // display type, capped: at 200% it goes one word per line
                    // and pushes the whole list off screen
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

// one card over the list: a breathing dot and its title, a line, and what
// can be done. it opens its height as it comes, sliding the list down under
// it, and folds away when it goes. simply there with less movement
class _HomeCard extends StatelessWidget {
  final bool show;
  // the card's own key while shown, so two cards never swap for each other
  final String id;
  final Color tint;
  final String title;
  final String line;
  final Color? lineColor;
  // a soft wash from the top corner rather than a flat tint
  final bool wash;
  final List<Widget> actions;
  const _HomeCard({
    required this.show,
    required this.id,
    required this.tint,
    required this.title,
    required this.line,
    required this.actions,
    this.lineColor,
    this.wash = false,
  });

  @override
  Widget build(BuildContext context) {
    return GrowSwap(
      alignment: Alignment.topCenter,
      child: !show
          ? SizedBox(key: ValueKey('no-$id'), width: 1)
          : Container(
              key: ValueKey(id),
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: wash ? null : tint.withValues(alpha: 0.10),
                gradient: wash
                    ? LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [
                          tint.withValues(alpha: 0.16),
                          tint.withValues(alpha: 0.05),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tint.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BreathDot(color: tint, size: 7, breaths: 3),
                      const SizedBox(width: 9),
                      // a long title wraps rather than running off the card
                      Expanded(
                        child: Text(
                          title,
                          style: HaloType.mono(
                            size: 11,
                            color: tint,
                            weight: FontWeight.w600,
                            letter: 0.12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    line,
                    style: HaloType.sans(
                      size: 13,
                      color: lineColor ?? HaloColors.text2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // the answers flow onto a second line in longer languages
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ),
                ],
              ),
            ),
    );
  }
}

// an answer on a home card: a filled pill for the one the card is for, or
// quiet words beside it. each dips under the finger with a click
class _CardAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  // the pill's fill; null draws quiet words in [ink]
  final Color? fill;
  final Color ink;
  final bool bold;
  // a label that changes while its action runs rises in
  final bool swap;
  const _CardAction({
    required this.label,
    required this.onTap,
    required this.ink,
    this.fill,
    this.bold = false,
    this.swap = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      key: ValueKey(label),
      style: HaloType.mono(
        size: 11.5,
        color: ink,
        weight: fill != null || bold ? FontWeight.w600 : FontWeight.w400,
      ),
    );
    final f = fill;
    return PressScale(
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: f == null
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: text,
              )
            : AnimatedContainer(
                duration: Duration(
                  milliseconds: motionStill(context) ? 0 : 200,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: onTap == null ? f.withValues(alpha: 0.45) : f,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: AnimatedSize(
                  duration: Duration(
                    milliseconds: motionStill(context) ? 0 : 200,
                  ),
                  curve: Curves.easeOutCubic,
                  child: swap ? RiseSwap(child: text) : text,
                ),
              ),
      ),
    );
  }
}

// android is not letting kryfo put a notification up, so nothing arrives
// while the app is closed. the android 13 permission dialog does not come
// back once the answer is final, so the only way out is the page this opens.
class _NotificationsBlockedHint extends StatefulWidget {
  const _NotificationsBlockedHint();

  @override
  State<_NotificationsBlockedHint> createState() =>
      _NotificationsBlockedHintState();
}

// tor has been unable to carry traffic for five minutes while kryfo is meant
// to be connected: say so plainly and offer the one useful button. it keeps
// its own timer because the status poll only wakes listeners when the status
// changes, and staying off is the absence of a change.
class _OfflineCard extends StatefulWidget {
  const _OfflineCard();

  @override
  State<_OfflineCard> createState() => _OfflineCardState();
}

class _OfflineCardState extends State<_OfflineCard> {
  // its "for how long" moves on while the card is seen
  final _timers = SeenTimers();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timers.every(const Duration(seconds: 20), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timers.watch(context);
  }

  @override
  void dispose() {
    _timers.dispose();
    super.dispose();
  }

  Future<void> _reconnect() async {
    if (_busy) return;
    setState(() => _busy = true);
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
        final since = appState.offlineFor ?? Duration.zero;
        return _HomeCard(
          show: appState.looksOffline,
          id: 'offline',
          tint: HaloColors.rose,
          title: l10n.homeKryfoIsOffline,
          line: l10n.homeTorHasNotBeen(_howLong(since)),
          lineColor: HaloColors.warm,
          actions: [
            _CardAction(
              label: _busy ? l10n.homeReconnecting : l10n.homeReconnect,
              onTap: _busy ? null : _reconnect,
              fill: HaloColors.rose,
              ink: HaloColors.amberInk,
              swap: true,
            ),
            _CardAction(
              label: l10n.homeWhatIsWrong,
              onTap: () => Navigator.of(
                context,
              ).push(haloRoute(const TransportScreen())),
              ink: HaloColors.warm,
            ),
          ],
        );
      },
    );
  }
}

// this phone has killed kryfo three times in a day while it was supposed
// to be staying connected. said once, ever, and only after it has happened:
// no vendor list, no guessing from the model name.
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
      builder: (context, _) => _HomeCard(
        show: appState.nudgeDue,
        id: 'keeps-stopping',
        tint: HaloColors.amber,
        title: l10n.homeYourPhoneKeepsStopping,
        line: l10n.homeItHasClosedKryfo,
        lineColor: HaloColors.warm,
        actions: [
          _CardAction(
            label: l10n.homeSwitchToCheckIns,
            onTap: _switch,
            fill: HaloColors.amber,
            ink: HaloColors.onAmber,
          ),
          _CardAction(
            label: l10n.homeNotNow,
            onTap: () => appState.nudgeAnswered(),
            ink: HaloColors.warm,
          ),
        ],
      ),
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
    return _HomeCard(
      show: _show,
      id: 'notifications-off',
      tint: HaloColors.amber,
      title: l10n.homeNotificationsAreOff,
      line: l10n.homeAndroidIsBlockingThem,
      actions: [
        _CardAction(
          label: l10n.homeTurnThemOn,
          onTap: () async {
            final opened = await openNotificationSettings();
            if (!opened && context.mounted) {
              showHaloToast(context, l10n.homeCouldnTOpenIt);
            }
          },
          fill: HaloColors.amber,
          ink: HaloColors.onAmber,
        ),
        _CardAction(
          label: l10n.homeLeaveThemOff,
          onTap: () async {
            await dismissNotifHint();
            if (mounted) setState(() => _show = false);
          },
          ink: HaloColors.text2,
        ),
      ],
    );
  }
}

class _RelayDownHint extends StatelessWidget {
  const _RelayDownHint();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => _HomeCard(
        show: appState.suggestFastFallback,
        id: 'relay-down',
        tint: HaloColors.amber,
        title: l10n.homeOurRelayIsQuiet,
        line: l10n.homeRelayModeUsesOnly,
        actions: [
          _CardAction(
            label: l10n.homeUseFastMode,
            onTap: () async {
              // same warning as the modes screen: fast mode shows your
              // address to public relays
              final ok = await showFastGateSheet(context);
              if (!ok || !context.mounted) return;
              await appState.setSendMode('fast');
              if (context.mounted) {
                showHaloToast(context, l10n.homeSwitchedToFast);
              }
            },
            fill: HaloColors.amber,
            ink: HaloColors.onAmber,
          ),
          _CardAction(
            label: l10n.homeKeepWaiting,
            onTap: () => appState.dismissRelayHint(),
            ink: HaloColors.text2,
          ),
        ],
      ),
    );
  }
}

class _BridgeStuckHint extends StatelessWidget {
  const _BridgeStuckHint();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => _HomeCard(
        show: appState.suggestBridgesOff,
        id: 'bridges-stuck',
        tint: HaloColors.rose,
        title: l10n.homeNotConnecting,
        line: l10n.homeBridgesAreOnAnd,
        actions: [
          _CardAction(
            label: l10n.homeTurnBridgesOff,
            onTap: () async {
              await appState.applyBridges(appState.bridgeLines, false);
              engine.restartTor();
              if (context.mounted) {
                showHaloToast(context, l10n.homeGoingDirectReconnecting);
              }
            },
            fill: HaloColors.rose,
            ink: HaloColors.amberInk,
          ),
        ],
      ),
    );
  }
}

class _BridgeHint extends StatelessWidget {
  const _BridgeHint();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => _HomeCard(
        show: appState.suggestBridges,
        id: 'bridges',
        tint: HaloColors.violet,
        wash: true,
        title: l10n.homeStillTrying,
        line: l10n.homeTorIsNotGetting,
        actions: [
          _CardAction(
            label: l10n.homeUseOurRelay,
            onTap: () async {
              await appState.setSendMode('balanced');
              if (context.mounted) {
                showHaloToast(context, l10n.homeSwitchedToRelay);
              }
            },
            fill: kCyan,
            ink: HaloColors.amberInk,
          ),
          _CardAction(
            label: l10n.homeBridges,
            onTap: () =>
                Navigator.of(context).push(haloRoute(const BridgesScreen())),
            ink: HaloColors.violet,
            bold: true,
          ),
          _CardAction(
            label: l10n.homeKeepWaiting,
            onTap: () => appState.dismissBridgeHint(),
            ink: HaloColors.text2,
          ),
        ],
      ),
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
        // a send in flight while the phone can send is not news. the strip
        // speaks when the phone cannot send, or when a message waits on
        // someone who has not added you back.
        final cannotSend = !appState.online || !appState.torReady;
        final offline = !appState.online;
        final torDown = !offline && !appState.torReady;
        // tor coming up is what every launch looks like: with an empty queue
        // there is nothing to explain. offline is worth stating even with
        // nothing queued.
        final show = (cannotSend || p > 0) && !(torDown && n == 0 && p == 0);
        // it opens its height and folds away, so the list slides
        return GrowSwap(
          alignment: Alignment.topCenter,
          child: show
              ? KeyedSubtree(
                  key: const ValueKey('strip'),
                  child: _strip(n, p, offline, torDown),
                )
              : const SizedBox(key: ValueKey('no-strip'), width: 1),
        );
      },
    );
  }

  Widget _strip(int n, int p, bool offline, bool torDown) {
    final tint = offline ? HaloColors.rose : HaloColors.amber;
    final head = offline ? l10n.homeOffline : l10n.homeWaiting;
    // say whether anything is queued, not only that the phone is offline
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
          bottom: BorderSide(color: tint.withValues(alpha: 0.35), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BreathDot(color: tint, size: 7, breaths: 3),
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
            PressScale(
              label: l10n.commonRetry,
              onTap: () => appState.flushOutboxNow(),
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
  }
}

// ───────── empty state ─────────

// no chats yet: the developer chat's row on top, and under it the page
// still asks to add someone. short phones and big fonts scroll it
class _EmptyWithDev extends StatelessWidget {
  final DevRow? dev;
  final void Function(String chatId) onOpenDev;
  final VoidCallback onAdd;
  const _EmptyWithDev({
    super.key,
    required this.dev,
    required this.onOpenDev,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final d = dev;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          // it folds away on a delete or an archive, and grows back
          child: GrowSwap(
            alignment: Alignment.topCenter,
            child: d == null
                ? const SizedBox(key: ValueKey('no-dev'), width: 1)
                : _Enter(
                    key: const ValueKey('dev'),
                    index: 0,
                    child: _DevSwipeRow(d: d, onTap: () => onOpenDev(d.chatId)),
                  ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(onAdd: onAdd),
        ),
      ],
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
  // the ring breathes out twice as the page arrives, then rests: nothing
  // on an empty home keeps moving while it waits
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ring.isAnimating || _ring.isCompleted) return;
    if (motionStill(context)) {
      _ring.value = 1;
    } else {
      _ring.forward();
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  Widget _mark() {
    const core = 56.0, room = 92.0;
    return SizedBox.square(
      dimension: room,
      child: AnimatedBuilder(
        animation: _ring,
        builder: (_, _) {
          final t = _ring.value;
          // the face pops on the house spring over the first 300 ms
          final pop = kHouseCurve.transform((t * 2600 / 300).clamp(0.0, 1.0));
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var k = 0; k < 2; k++)
                () {
                  final p = (t * 2 - k).clamp(0.0, 1.0);
                  final e = Curves.easeOut.transform(p);
                  final d = core + (room - core) * e;
                  return Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HaloColors.amber.withValues(
                        alpha: p <= 0 || p >= 1 ? 0 : 0.12 * (1 - p),
                      ),
                    ),
                  );
                }(),
              Transform.scale(
                scale: 0.85 + 0.15 * pop,
                child: Container(
                  width: core,
                  height: core,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.amberSoft,
                    border: Border.all(
                      color: HaloColors.amber.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: HaloColors.amber.withValues(alpha: 0.16),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_outlined,
                    color: HaloColors.amber,
                    size: 26,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: staggerAllIn(context, [
            _mark(),
            const SizedBox(height: 10),
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
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: HaloColors.amber.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: HaloColors.onAmber,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.homeAddSomeone,
                      style: HaloType.sans(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: HaloColors.onAmber,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// the archive, under the other pins and shaped like them
class _ArchivedPin extends StatelessWidget {
  final VoidCallback onTap;
  final int count;
  const _ArchivedPin({super.key, required this.onTap, required this.count});
  @override
  Widget build(BuildContext context) {
    return HomePin(
      icon: Icons.inventory_2_outlined,
      title: l10n.homeArchived,
      line: l10n.home1Chat(count),
      lit: false,
      onTap: onTap,
      trailing: Icon(Icons.chevron_right, color: HaloColors.text2, size: 18),
    );
  }
}

// one row of the list: a group, a chat or the developer chat, by the key
// it keeps. the developer chat has a key for each place it can sit, so it
// folds out of one and grows into the other when it is pinned or unpinned
class _Item {
  final String key;
  final GroupSummary? g;
  final ContactPreview? c;
  final DevRow? d;
  _Item.group(GroupSummary this.g) : key = 'g-${g.groupId}', c = null, d = null;
  _Item.chat(ContactPreview this.c) : key = 'c-${c.haloId}', g = null, d = null;
  _Item.dev(DevRow this.d, {required bool top})
    : key = top ? 'dev-top' : 'dev-chat',
      g = null,
      c = null;
}

// the chat list: groups under their heading, chats under theirs. a row that
// is new grows in, one that goes folds away, and one that moves glides to
// its new place (ShiftInPlace). the first build, and anything that changes
// under the lock, just is.
class _ContactList extends StatefulWidget {
  final List<ContactPreview> contacts;
  final List<GroupSummary> groups;
  // pinned, it sits above everything. unpinned, among the chats by time
  final DevRow? dev;
  final void Function(String kryfo) onTap;
  final void Function(String chatId) onOpenDev;
  final void Function(String groupId) onOpenGroup;
  final VoidCallback onNewGroup;
  final VoidCallback onNewRoom;
  final String? expiredRoomName;
  const _ContactList({
    super.key,
    required this.contacts,
    required this.groups,
    this.dev,
    required this.onTap,
    required this.onOpenDev,
    required this.onOpenGroup,
    required this.onNewGroup,
    required this.onNewRoom,
    this.expiredRoomName,
  });

  @override
  State<_ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<_ContactList> {
  late final RowSet<_Item> _top = RowSet(keyOf: _key, onGone: _gone);
  late final RowSet<_Item> _groups = RowSet(keyOf: _key, onGone: _gone);
  late final RowSet<_Item> _chats = RowSet(keyOf: _key, onGone: _gone);
  // pulled down past the top, the list opens search
  bool _opened = false;

  static String _key(_Item i) => i.key;

  void _gone() {
    if (mounted) setState(() {});
  }

  List<_Item> _topItems() => [
    if (widget.dev case final d? when d.pinned) _Item.dev(d, top: true),
  ];

  List<_Item> _chatItems() {
    final items = [for (final c in widget.contacts) _Item.chat(c)];
    final d = widget.dev;
    if (d != null && !d.pinned) {
      items.insert(devSlot(d, widget.contacts), _Item.dev(d, top: false));
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    _top.start(_topItems());
    _groups.start([for (final g in widget.groups) _Item.group(g)]);
    _chats.start(_chatItems());
  }

  @override
  void didUpdateWidget(_ContactList old) {
    super.didUpdateWidget(old);
    final quiet = lockGuard.isLocked();
    _top.update(_topItems(), quiet: quiet);
    _groups.update([
      for (final g in widget.groups) _Item.group(g),
    ], quiet: quiet);
    _chats.update(_chatItems(), quiet: quiet);
  }

  @override
  void dispose() {
    _top.dispose();
    _groups.dispose();
    _chats.dispose();
    super.dispose();
  }

  Widget _row(RowSet<_Item> set, _Item i, int index) {
    final g = i.g;
    final c = i.c;
    final d = i.d;
    final leaving = set.leaving(i);
    final Widget row = g != null
        ? _GroupRow(g: g, onTap: () => widget.onOpenGroup(g.groupId))
        : d != null
        // one ring flies at a time, the one staying
        ? HeroMode(
            enabled: !leaving,
            child: _DevSwipeRow(d: d, onTap: () => widget.onOpenDev(d.chatId)),
          )
        : _SwipeRow(c: c!, onTap: () => widget.onTap(c.haloId));
    // keyed, so a row that moves up on a new message glides there
    return ShiftInPlace(
      key: ValueKey(i.key),
      index: index,
      child: IgnorePointer(
        ignoring: leaving,
        child: FadeFold(
          leaving: leaving,
          child: GrowIn(
            active: set.fresh(i),
            child: _Enter(
              index: d != null && set == _top ? 0 : 1 + index,
              child: row,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = _top.rows;
    final groups = _groups.rows;
    final chats = _chats.rows;
    // the rows built this frame have read whether they are new
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _top.built();
      _groups.built();
      _chats.built();
    });
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        if (!_opened &&
            n.dragDetails != null &&
            n.metrics.axis == Axis.vertical &&
            n.metrics.pixels < -72) {
          _opened = true;
          HapticFeedback.lightImpact();
          Navigator.of(context).push(searchRoute());
        }
        if (n.metrics.pixels >= 0) _opened = false;
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // the developer chat, pinned: above everything, the groups too
          for (final (n, d) in top.indexed) _row(_top, d, n),
          // the groups heading is always there: it is where a group or a
          // room is made, even with none yet
          _SectionHead(
            label: l10n.homeGroups,
            actions: [
              _HeadAction(
                icon: Icons.timer_outlined,
                label: l10n.homeRoom,
                color: HaloColors.violet,
                onTap: widget.onNewRoom,
              ),
              _HeadAction(
                icon: Icons.add_rounded,
                label: l10n.homeNew,
                color: HaloColors.amber,
                onTap: widget.onNewGroup,
              ),
            ],
          ),
          // a room that just ended: one quiet line that opens under the
          // heading and folds away a few seconds later
          GrowSwap(
            alignment: Alignment.topCenter,
            child: widget.expiredRoomName == null
                ? const SizedBox(key: ValueKey('no-expired'), width: 1)
                : Padding(
                    key: ValueKey('expired-${widget.expiredRoomName}'),
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        l10n.homeRoomExpired(widget.expiredRoomName!),
                        style: HaloType.mono(
                          size: 10,
                          color: HaloColors.violet,
                        ),
                      ),
                    ),
                  ),
          ),
          for (final (n, g) in groups.indexed) _row(_groups, g, n),
          if (chats.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionHead(label: l10n.searchChats),
            for (final (n, c) in chats.indexed)
              _row(_chats, c, groups.length + n),
          ],
        ],
      ),
    );
  }
}

// the small mono heading over a section of the list, with its actions at
// the end
class _SectionHead extends StatelessWidget {
  final String label;
  final List<Widget> actions;
  const _SectionHead({required this.label, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.mono(
                size: 10,
                color: HaloColors.text3,
                weight: FontWeight.w500,
                letter: 0.14,
              ),
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 6), a],
        ],
      ),
    );
  }
}

// a small tinted pill in a section heading: make a room, make a group
class _HeadAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _HeadAction({
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

bool _homeEntered = false;
bool _enterUnderLock = false;

// the app came out from under the lock: rows built under it play their
// entrance now, and no row plays one after
void homeRevealed() {
  if (_enterUnderLock) _homeEntered = true;
}

// one-shot staggered entrance for the home list. plays on the first render
// after launch, then stays put so message updates never re-animate rows.
class _Enter extends StatefulWidget {
  final int index;
  final Widget child;
  const _Enter({super.key, required this.index, required this.child});
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
      if (lockGuard.isLocked()) {
        _enterUnderLock = true;
      } else {
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
    // a fade alone when the phone asks for no movement
    final rise = motionStill(context) ? 0.0 : 12.0;
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, rise * (1 - curved.value)),
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
    // its own ink surface: the tint and the splash are drawn with the row,
    // so they fade and slide with it. on the page's surface they were drawn
    // once, under a row still invisible at the start of its entrance, and
    // the tint never showed
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        // held: its menu, as a chat's
        onLongPress: () => _groupMenu(context, g),
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
                // group avatar: a square tile with the first letter of the name
                // in italic serif, so groups differ from round contact avatars
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.sans(
                                size: 14,
                                weight: g.unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: HaloColors.text,
                              ),
                            ),
                          ),
                          HiddenMark(on: g.hidden),
                        ],
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
                          style: HaloType.mono(
                            size: 10,
                            color: HaloColors.text3,
                          ),
                        ),
                    ],
                  ),
                ),
                // pops in, rolls to each new count, pops away once read
                CountBadge(count: g.unread, lead: 8),
              ],
            ),
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
    return SwipeActions(
      rowKey: ValueKey('swipe_${c.haloId}'),
      start: SwipeAction(
        icon: c.muted
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        label: c.muted ? l10n.homeUnmute : l10n.homeMute,
        color: HaloColors.text2,
        ink: HaloColors.surface,
        onDone: () =>
            c.muted ? appState.unmute(c.haloId) : appState.mute(c.haloId),
      ),
      end: SwipeAction(
        icon: Icons.archive_outlined,
        label: l10n.homeArchive,
        color: HaloColors.amber,
        ink: HaloColors.onAmber,
        onDone: () => appState.archive(c.haloId),
      ),
      child: _Row(c: c, onTap: onTap, onLongPress: () => _chatMenu(context, c)),
    );
  }
}

// a chat's menu on the house sheet: what it does to the chat in one group,
// the delete on its own at the end
void _chatMenu(BuildContext context, ContactPreview c) {
  HapticFeedback.mediumImpact();
  showHaloSheet<String>(
    context,
    scroll: true,
    builder: (ctx) {
      void pick(String a) => Navigator.pop(ctx, a);
      return SingleChildScrollView(
        child: MenuSheet(
          groups: [
            [
              MenuSheetRow(
                icon: c.muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                label: c.muted ? l10n.homeUnmute : l10n.homeMute,
                onTap: () => pick('mute'),
              ),
              MenuSheetRow(
                icon: Icons.archive_outlined,
                label: l10n.homeArchive,
                onTap: () => pick('archive'),
              ),
              // hidden chats open: a chat goes out of the everyday list, or
              // comes back to it, and its row says which
              if (lockState.inVault && !c.blocked)
                MenuSheetRow(
                  icon: c.hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  label: c.hidden ? l10n.chatShowInList : l10n.chatHide,
                  tint: HaloColors.violet,
                  onTap: () => pick('hide'),
                ),
            ],
            [
              MenuSheetRow(
                icon: Icons.delete_outline,
                label: l10n.homeDeleteChat,
                sub: l10n.homeMessagesAndContactGone,
                danger: true,
                onTap: () => pick('delete'),
              ),
            ],
          ],
        ),
      );
    },
  ).then((a) {
    if (a == null || !context.mounted) return;
    switch (a) {
      case 'mute':
        c.muted ? appState.unmute(c.haloId) : appState.mute(c.haloId);
      case 'archive':
        appState.archive(c.haloId);
      case 'hide':
        moveHiddenChat(context, c.haloId, group: false, hide: !c.hidden);
      case 'delete':
        _confirmDelete(context, c);
    }
  });
}

// a group's or a room's menu: hide it while hidden chats are open, or
// leave it, after saying what leaving costs
void _groupMenu(BuildContext context, GroupSummary g) {
  HapticFeedback.mediumImpact();
  showHaloSheet<String>(
    context,
    scroll: true,
    builder: (ctx) {
      void pick(String a) => Navigator.pop(ctx, a);
      return SingleChildScrollView(
        child: MenuSheet(
          groups: [
            if (lockState.inVault)
              [
                MenuSheetRow(
                  icon: g.hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  label: g.hidden ? l10n.chatShowInList : l10n.chatHide,
                  tint: HaloColors.violet,
                  onTap: () => pick('hide'),
                ),
              ],
            [
              MenuSheetRow(
                icon: Icons.logout_rounded,
                label: g.isRoom
                    ? l10n.groupInfoLeaveRoom2
                    : l10n.groupInfoLeaveGroup2,
                danger: true,
                onTap: () => pick('leave'),
              ),
            ],
          ],
        ),
      );
    },
  ).then((a) {
    if (a == null || !context.mounted) return;
    switch (a) {
      case 'hide':
        moveHiddenChat(context, g.groupId, group: true, hide: !g.hidden);
      case 'leave':
        _confirmLeave(context, g);
    }
  });
}

Future<void> _confirmLeave(BuildContext context, GroupSummary g) async {
  final row = await session.getGroup(g.groupId);
  if (!context.mounted) return;
  final ok = await showConfirmSheet(
    context,
    title: g.isRoom ? l10n.groupInfoLeaveRoom : l10n.groupInfoLeaveGroup,
    line: leaveLine(
      room: g.isRoom,
      admin: ((row?['is_admin'] as int?) ?? 0) == 1,
    ),
    yes: l10n.groupInfoLeave,
  );
  if (!ok) return;
  HapticFeedback.heavyImpact();
  await appState.leaveGroupAndAnnounce(g.groupId);
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

// the developer chat's row: the same swipes as any chat, and a menu of its
// own. no nickname and no block
class _DevSwipeRow extends StatelessWidget {
  final DevRow d;
  final VoidCallback onTap;
  const _DevSwipeRow({required this.d, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SwipeActions(
      rowKey: const ValueKey('swipe_dev'),
      start: SwipeAction(
        icon: d.muted
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        label: d.muted ? l10n.homeUnmute : l10n.homeMute,
        color: HaloColors.text2,
        ink: HaloColors.surface,
        onDone: () => setDevMuted(!d.muted),
      ),
      end: SwipeAction(
        icon: Icons.archive_outlined,
        label: l10n.homeArchive,
        color: HaloColors.amber,
        ink: HaloColors.onAmber,
        onDone: () => setDevArchived(true),
      ),
      child: _DevRowTile(
        d: d,
        onTap: onTap,
        onLongPress: () => _devMenu(context, d),
      ),
    );
  }
}

void _devMenu(BuildContext context, DevRow d) {
  HapticFeedback.mediumImpact();
  showHaloSheet<String>(
    context,
    scroll: true,
    builder: (ctx) {
      void pick(String a) => Navigator.pop(ctx, a);
      return SingleChildScrollView(
        child: MenuSheet(
          groups: [
            [
              MenuSheetRow(
                icon: d.muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                label: d.muted ? l10n.homeUnmute : l10n.homeMute,
                onTap: () => pick('mute'),
              ),
              MenuSheetRow(
                icon: Icons.archive_outlined,
                label: l10n.homeArchive,
                onTap: () => pick('archive'),
              ),
              MenuSheetRow(
                icon: d.pinned ? Icons.push_pin_outlined : Icons.push_pin,
                label: d.pinned ? l10n.contactUnpin : l10n.contactPinToTop,
                onTap: () => pick('pin'),
              ),
            ],
            [
              MenuSheetRow(
                icon: Icons.delete_outline,
                label: l10n.homeDeleteChat,
                danger: true,
                onTap: () => pick('delete'),
              ),
            ],
          ],
        ),
      );
    },
  ).then((a) {
    if (a == null || !context.mounted) return;
    switch (a) {
      case 'mute':
        setDevMuted(!d.muted);
      case 'archive':
        setDevArchived(true);
      case 'pin':
        setDevPinned(!d.pinned);
      case 'delete':
        deleteDevChat(context, d);
    }
  });
}

// the ring for a face, the tick of a key built into the app, one title in
// every language, and the welcome until a message says more. a fresh row
// has no time and no count: nothing has arrived
class _DevRowTile extends StatelessWidget {
  final DevRow d;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _DevRowTile({
    required this.d,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final unread = d.unread > 0;
    final queued =
        appState.queuedFor(d.chatId) > 0 &&
        (!appState.online || !appState.torReady);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: HaloColors.amber.withValues(alpha: 0.10),
        highlightColor: HaloColors.amber.withValues(alpha: 0.05),
        child: Ink(
          decoration: unread
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
              Hero(tag: kDevFaceHero, child: const DevAvatar(pop: true)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.devRowTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 14,
                              weight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        if (d.pinned) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.push_pin,
                            size: 11,
                            color: HaloColors.text3,
                          ),
                        ],
                        if (d.muted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 12,
                            color: HaloColors.text3,
                          ),
                        ],
                        if (queued) ...[
                          const SizedBox(width: 4),
                          Text(
                            l10n.homeQueued,
                            style: HaloType.mono(
                              size: 10,
                              color: HaloColors.text2,
                              letter: 0.08,
                            ),
                          ),
                        ] else if (d.when != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            _relTime(d.when),
                            style: HaloType.mono(
                              size: 10.5,
                              color: unread
                                  ? HaloColors.amber
                                  : HaloColors.text3,
                              weight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            d.preview ?? l10n.devWelcome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 12,
                              color: unread
                                  ? HaloColors.text
                                  : HaloColors.text2,
                            ),
                          ),
                        ),
                        CountBadge(count: d.unread, lead: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final ContactPreview c;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _Row({required this.c, required this.onTap, this.onLongPress});
  @override
  Widget build(BuildContext context) {
    // its own ink surface, like the group row's
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
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
                              HiddenMark(on: c.hidden),
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
                                (c.blocked
                                    ? l10n.homeBlocked
                                    : _relTime(c.when)),
                                style: HaloType.mono(
                                  size: 10.5,
                                  color: c.unread > 0
                                      ? HaloColors.amber
                                      : HaloColors.text3,
                                  weight: c.unread > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
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
                            // unread reads in full colour until it is read
                            style: HaloType.sans(
                              size: 12,
                              color: c.unread > 0
                                  ? HaloColors.text
                                  : HaloColors.text2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        CountBadge(count: c.unread, lead: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                  // the whole title, shrunk if it has to be, never cut off
                  // at a big font size
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

// unknown-sender requests. amber, shows a count, only rendered when > 0.
class _RequestsPin extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _RequestsPin({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HomePin(
      icon: Icons.mail_outline,
      title: l10n.homeRequests,
      line: l10n.home1PersonWantsTo(count),
      onTap: onTap,
      trailing: CountBadge(
        count: count,
        fontSize: 11.5,
        minWidth: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      ),
    );
  }
}
