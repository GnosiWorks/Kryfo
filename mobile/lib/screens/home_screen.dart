// SPDX-License-Identifier: GPL-3.0-or-later
// home screen: date header, the chat list or empty state, and the nav tabs.

import 'history_copy_screen.dart';
import 'saved_screen.dart';
import 'transport_screen.dart';
import '../widgets/desk_menu.dart';
import '../widgets/press_scale.dart';
import '../widgets/entrance.dart';
import '../widgets/ease_size.dart' show EaseSize;
import '../widgets/stagger_in.dart';
import 'requests_screen.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'donate_screen.dart';
import 'tip_screen.dart';
import 'profile_screen.dart';
import 'tools_screen.dart';
import 'photo_knows_screen.dart';
import 'qr_screen.dart';
import 'lock_file_screen.dart';
import 'open_locked_screen.dart';
import 'share_sheet.dart';
import 'share_files_sheet.dart';
import '../tools/tools_bridge.dart';
import '../tools/desk_tools.dart';
import '../desktop/attach_tray.dart' show clipboardFiles;
import '../desktop/clip_picture.dart' show clipboardPicture;
import '../desktop/drag_in.dart' show draggedFiles;
import '../lock_guard.dart' show lockGuard;
import '../lock_state.dart';
import '../store.dart';
import '../widgets/nav_bar.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../invite_share.dart' show shareInvite;
import '../desktop/desktop_mode.dart' show canShareOut, computerLock, onDesktop;
import '../wide/wide_home.dart';
import '../wide/wide_pane.dart';
import 'backup_screen.dart';
import '../rooms.dart' show looksLikeRoomKey, roomTag;
import '../widgets/room_countdown.dart';
import '../widgets/room_join.dart';
import '../widgets/kryfo_avatar.dart';
import 'notes_screen.dart';
import 'bridges_screen.dart';
import 'bridge_sheets.dart' show showTorBlockedSheet;
import '../bridge_mode.dart';
import 'archived_screen.dart';
import '../miui_autostart.dart';
import '../devices/history_link.dart'
    show HistoryCopyStage, HistoryCopyStep, historyCopyOver;
import '../main.dart' hide live;
import '../tor_valve.dart' show ValveStage;
import '../link_view.dart' show LinkKind;
import '../widgets/motion.dart';
import '../widgets/route_merged_card.dart';
import '../widgets/halo_hero.dart';
import '../widgets/shift_in_place.dart';
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/row_motion.dart';
import '../widgets/count_badge.dart';
import '../widgets/chat_parts.dart' show GrowSwap;
import '../widgets/swap.dart';
import '../drafts.dart' show draftsRevision;
import '../home_drafts.dart';
import '../widgets/typing_mark.dart';
import '../widgets/card_action.dart';
import '../widgets/message_menu.dart' show MenuSheetRow;
import '../widgets/confirm_sheet.dart';
import '../widgets/hidden_mark.dart';
import '../widgets/home_pin.dart';
import '../widgets/swipe_actions.dart';
import '../notif_permission.dart';
import '../seen_timers.dart';
import '../delivery_mode.dart';
import 'notifications_screen.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../l10n/numbers.dart';
import '../devchat/dev_chat.dart' show DevRow;
import '../widgets/dev_avatar.dart';
import 'dev_about_sheet.dart';
import 'search_screen.dart';
import 'group_info_screen.dart' show endedLine, leaveLine;
import 'support_screen.dart' show SupportPin, supportRoute;
import '../widgets/update_card.dart' show UpdateHint;
import '../devices/linked_switch.dart' show kLinkedDevicesOn;
import '../devices/own_device_store.dart' show linkNotices;
import 'linked_devices_screen.dart' show LinkedDevicesScreen, linkNoticeWords;

bool _miuiPromptChecked = false;

/// the battery and phone maker asks, once per start. a test hands in its own
@visibleForTesting
Future<void> Function(BuildContext context) homeBackgroundAsk =
    maybeShowBackgroundPrompt;

@visibleForTesting
void askBackgroundAgainForTest() => _miuiPromptChecked = false;

/// the clock the date head reads. a test hands in its own
@visibleForTesting
DateTime Function() homeClock = DateTime.now;

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
  StreamSubscription<void>? _sharedTextSub;
  final _texts = ShareTexts();
  // a photo or video shared in: a chat, or the one photo tool, which shows
  // what it gives away first, then one button that removes all of it
  late final _files = ShareFiles(
    onCheck: (f) => _openTool(PhotoKnowsScreen(file: f)),
  );
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
    _sharedSub = ToolsBridge.instance.sharedFiles.listen((_) {
      if (mounted) _files.arrived(context, () => mounted);
    });
    _sharedTextSub = ToolsBridge.instance.sharedText.listen((_) {
      if (mounted) _texts.arrived(context, () => mounted);
    });
    lockState.addListener(_onLock);
    appState.addListener(_maybeAskBridge);
    lockState.addListener(_maybeAskBridge);
    // a tab opened once stays in the tree behind an Offstage, so a theme
    // switch has to repaint the tabs behind this one too
    themeRevision.addListener(_repaint);
    if (onDesktop) HardwareKeyboard.instance.addHandler(_deskKey);
    ToolsBridge.instance.sweep();
    _sweeper.every(
      const Duration(minutes: 5),
      () => ToolsBridge.instance.sweep(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _files.take(context, () => mounted);
      if (mounted) _texts.take(context, () => mounted);
    });
  }

  @override
  void dispose() {
    _sharedSub?.cancel();
    _sharedTextSub?.cancel();
    _texts.dispose();
    _files.dispose();
    lockState.removeListener(_onLock);
    appState.removeListener(_maybeAskBridge);
    lockState.removeListener(_maybeAskBridge);
    themeRevision.removeListener(_repaint);
    HardwareKeyboard.instance.removeHandler(_deskKey);
    _sweeper.dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  // automatic found tor blocked on a new install: the sheet comes up over
  // whatever is open, once, never under the lock
  void _maybeAskBridge() {
    if (!mounted || !appState.bridgeAskDue || lockState.locked) return;
    final ctx = rootNavKey.currentState?.overlay?.context ?? context;
    appState.bridgeAskTaken();
    showTorBlockedSheet(ctx, asked: true);
  }

  Future<void> _pickToRead(String kind) async {
    final f = await ToolsBridge.instance.pick(kind);
    if (f != null) _openTool(PhotoKnowsScreen(file: f));
  }

  Future<void> _pickFor(Widget Function(PickedFile) screen) async {
    final f = await ToolsBridge.instance.pick('any');
    if (f != null) _openTool(screen(f));
  }

  // the lock is a route on this same navigator. opening a tool under it, or
  // clearing the stack to make room for one, would take the lock away, so a
  // share or a pick that lands while locked waits for the pin.
  void _openTool(Widget screen) {
    if (!mounted) return;
    if (!lockState.loaded || lockState.locked) {
      _heldTool = screen;
      return;
    }
    if (onDesktop) {
      // into the pane, beside the tab, as a chat opens; a drop on the page
      // opens what was dropped in its place
      _pick(HaloTab.tools);
      unawaited(
        deskPush(
          context,
          haloRoute<void>(
            DeskToolsIn(onFile: _deskFile, page: true, child: screen),
          ),
        ),
      );
      return;
    }
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    _pick(HaloTab.tools);
    nav.push(haloRoute(screen));
  }

  // a file dropped or pasted on the tools on a computer opens in its tool:
  // a photo or video in the cleaner, an age file in open, anything else in
  // lock after one plain choice
  Future<void> _deskFile(String path) async {
    if (!mounted || lockState.locked) return;
    final f = deskPicked(path);
    if (f == null) {
      showHaloToast(context, l10n.chatCouldNotReadThat);
      return;
    }
    switch (deskToolFor(path)) {
      case DeskToolFor.picture || DeskToolFor.video:
        _openTool(PhotoKnowsScreen(file: f));
      case DeskToolFor.locked:
        _openTool(OpenLockedScreen(file: f));
      case DeskToolFor.other:
        if (await askLockThisFile(context, f.name ?? '') && mounted) {
          _openTool(LockFileScreen(file: f));
        }
    }
  }

  // ctrl and v on the tools tab or a tool's page, while no field has the
  // keys: copied files take a drop's way, a copied picture goes to the
  // cleaner from memory. a locked app takes nothing
  bool _deskKey(KeyEvent e) {
    if (!isPasteKey(e) ||
        !mounted ||
        lockState.locked ||
        _tab != HaloTab.tools ||
        typingInAField() ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return false;
    }
    final pane = widePane;
    final free =
        pane == null || pane.depth.value == 0 || DeskToolsIn.pageInFront();
    if (!free) return false;
    unawaited(_deskPaste());
    return true;
  }

  Future<void> _deskPaste() async {
    final paths = draggedFiles(await clipboardFiles());
    if (!mounted || lockState.locked) return;
    if (paths.length > 1) {
      showHaloToast(context, l10n.toolsOneFileAtATime);
      return;
    }
    if (paths.length == 1) return _deskFile(paths.single);
    final png = await clipboardPicture();
    if (png == null || !mounted || lockState.locked) return;
    final f = await pastedPicture(png);
    if (f != null && mounted && !lockState.locked) {
      _openTool(PhotoKnowsScreen(file: f));
    }
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
        return DeskToolsIn(
          onFile: _deskFile,
          child: ToolsScreen(
            onPickPhoto: () => _pickToRead('image'),
            onPickVideo: () => _pickToRead('video'),
            onQr: () => _openTool(const QrScreen()),
            onLock: () => _pickFor((f) => LockFileScreen(file: f)),
            onOpenLocked: () => _pickFor((f) => OpenLockedScreen(file: f)),
          ),
        );
      case HaloTab.support:
        // the play build tips through google play, and names no other way
        return kPlayBuild ? const TipScreen() : const DonateScreen();
      case HaloTab.me:
        return ProfileScreen(onOpenSupport: () => _pick(HaloTab.support));
    }
  }

  @override
  Widget build(BuildContext context) {
    // read where it lands: the desktop's list is narrower than the window
    final tabs = Builder(
      builder: (context) => MediaQuery.removePadding(
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
                    // a theme switch rebuilds every widget in place
                    // (ThemeRefresh): a tab keeps its scroll and state
                    child: _Arrive(
                      on: t == _tab,
                      towards: _towards,
                      fresh: t == _picked,
                      child: _body(t),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
    final bar = SafeArea(
      top: false,
      child: HaloNavBar(
        active: _tab,
        onPick: _pick,
        // the developer screen is for debug builds only
        onMeLongPress: kDebugMode ? widget.onOpenDev : null,
      ),
    );
    return PopScope(
      canPop: _tab == HaloTab.chats,
      onPopInvokedWithResult: (done, _) {
        if (!done) _pick(HaloTab.chats);
      },
      child: onDesktop
          ? WideHome(
              tab: _tab,
              onPick: _pick,
              onMeLongPress: kDebugMode ? widget.onOpenDev : null,
              tabs: tabs,
              bar: bar,
              onSearch: () => deskPush(context, searchRoute(context)),
              onAdd: widget.onAddContact,
              onSettings: widget.onOpenSettingsDirect,
            )
          : Scaffold(
              backgroundColor: HaloColors.surface,
              body: Column(
                children: [
                  Expanded(child: tabs),
                  bar,
                ],
              ),
            ),
    );
  }
}

// a tab coming into view slides in from the side of the bar it lies on,
// fading up. reduced motion: no animation
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
    final now = homeClock();
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
        // google push wakes the phone itself, as setup says
        if (appState.deliveryMode == DeliveryMode.google) return;
        homeBackgroundAsk(context);
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
              onSearch: () => deskPush(context, searchRoute(context)),
            ),
          ),
          const _OfflineStrip(),
          const _AutoStrip(),
          const _AutoOffer(),
          const _BridgeHint(),
          const _BridgeStuckHint(),
          const _RelayDownHint(),
          const _RouteMergedCard(),
          const OfflineCard(),
          const _KeepsStoppingCard(),
          const _HelperGoneCard(),
          const _GooglePushCard(),
          const _NotificationsBlockedHint(),
          const UpdateHint(),
          const _ShotsCard(),
          const _ComputerBackupCard(),
          if (kLinkedDevicesOn) const _LinkNoticeCard(),
          if (kLinkedDevicesOn) const _HistoryCopyCard(),
          if (kLinkedDevicesOn) const _LinkedComingCard(),
          StaggerIn(
            index: 1,
            child: _QuickTiles(
              onNotes: () => deskPush(context, haloRoute(const NotesScreen())),
              onSaved: () => deskPush(context, haloRoute(const SavedScreen())),
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
                      onTap: () =>
                          deskPush(context, haloRoute(const RequestsScreen())),
                    ),
                  )
                : const SizedBox(key: ValueKey('no-requests'), width: 1),
          ),
          if (support != null)
            StaggerIn(
              index: 2,
              child: SupportPin(
                waiting: support!,
                onTap: () => deskPush(context, supportRoute()),
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
                      deskPush(context, haloRoute(const ArchivedScreen()));
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
                      onNewGroup: onNewGroup,
                      onNewRoom: onNewRoom,
                      expiredRoomName: expiredRoomName,
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
  // the chat blocks screenshots on this phone
  final bool shotsBlocking;
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
    this.shotsBlocking = false,
  });
}

// minimal shape needed by home for rendering a group row. app/shell.dart
// builds these from appState.groups.
class GroupSummary {
  final String groupId;
  final String name;
  final int memberCount;
  final int unread;
  final bool mentioned;
  final int? expiresAt; // set for a burner room
  // a room not let in yet: when its join went
  final int? joiningAt;
  final bool hidden;
  // who ended it, null while it runs
  final String? endedBy;
  // its last message as the row says it ("Name: text"), and when
  final String? preview;
  final DateTime? when;
  const GroupSummary({
    required this.groupId,
    required this.name,
    required this.memberCount,
    this.preview,
    this.when,
    this.unread = 0,
    this.mentioned = false,
    this.expiresAt,
    this.joiningAt,
    this.hidden = false,
    this.endedBy,
  });
  bool get isRoom => expiresAt != null;
  bool get ended => endedBy != null;
}

/// a group row's line: ours as "You: text", theirs as "Name: text" with the
/// name kept apart from the words' direction, a group that blocks with no
/// name at all. [from]: the writer's id, null for ours or a blocking group
String? groupRowLine({
  required String? body,
  required bool out,
  required String? from,
  required Map<String, String> nicks,
}) {
  if (body == null) return null;
  if (out) return l10n.appYou(body);
  if (from == null) return body;
  final name = nicks[from] ?? (looksLikeRoomKey(from) ? roomTag(from) : from);
  // first strong isolates: an arabic name before english words, or the
  // other way, stays in its own order
  return l10n.homeGroupLine('\u2068$name\u2069', body);
}

// ---- date header ----

// a header button: a round of kDoorRound in a full finger's room of
// kDoorBox, top-aligned so the rounds line up with the date beside them
class _HeadRoom extends StatelessWidget {
  final Widget child;
  const _HeadRoom({required this.child});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: kDoorBox,
    height: kDoorBox,
    child: Align(alignment: Alignment.topCenter, child: child),
  );
}

class _AddScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddScanButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: l10n.homeAddAContact,
      scale: 0.9,
      onTap: onTap,
      child: _HeadRoom(
        child: Container(
          width: kDoorRound,
          height: kDoorRound,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: HaloColors.amber.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
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
      child: _HeadRoom(
        child: Container(
          width: kDoorRound,
          height: kDoorRound,
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

/// the text size from which home's id line sits under the header buttons
const kIdUnderScale = 1.3;

class _HomeHead extends StatelessWidget {
  final DateTime now;
  final String haloId;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  final VoidCallback onSearch;
  const _HomeHead({
    required this.now,
    required this.haloId,
    required this.onAdd,
    required this.onSettings,
    required this.onSearch,
  });
  // the three words and their label. the list beside a chat is narrower
  // than a phone: there they take a line of their own under the buttons,
  // at the phone's size
  List<Widget> _name() => [
    const SizedBox(height: 8),
    // one line, shrunk to fit: at large text the column beside the buttons
    // is narrow and the label would break inside its words
    FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        l10n.homeYourKryfo,
        maxLines: 1,
        softWrap: false,
        style: HaloType.mono(size: 9.5, color: HaloColors.text, letter: 0.14),
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
          color: HaloColors.amberText,
          weight: FontWeight.w700,
          letter: 0.02,
        ),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // at large text the column beside the buttons is too narrow for the
    // id: it goes under them, as on a computer
    final under =
        onDesktop || MediaQuery.textScalerOf(context).scale(1) >= kIdUnderScale;
    final row = Row(
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
                    MediaQuery.of(context).textScaler.scale(1).clamp(1.0, 1.15),
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
                    color: HaloColors.amberText,
                    italic: true,
                  ),
                  textScaler: TextScaler.linear(
                    MediaQuery.of(context).textScaler.scale(1).clamp(1.0, 1.15),
                  ),
                ),
              ),
              if (!under) ..._name(),
            ],
          ),
        ),
        // the rooms meet edge to edge: their margins make the gaps
        // between the rounds
        SearchDoor(onTap: onSearch),
        _GearButton(onTap: onSettings),
        // people are added on the phone a device is linked to
        if (!linkedRole) _AddScanButton(onTap: onAdd),
        const SizedBox(width: 12 - (kDoorBox - kDoorRound) / 2),
        TorHalo(label: true),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: !under
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [row, ..._name()],
            ),
    );
  }
}

// one card over the list: a pulsing dot and its title, a line, and what
// can be done. it opens its height as it comes, sliding the list down under
// it, and folds away when it goes. no animation with reduced motion
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
  // how far something under way is, 0 to 1: a bar under the line
  final double? progress;
  const _HomeCard({
    required this.show,
    required this.id,
    required this.tint,
    required this.title,
    required this.line,
    required this.actions,
    this.lineColor,
    this.wash = false,
    this.progress,
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
                      color: lineColor ?? HaloColors.text,
                    ),
                  ),
                  // the bar grows in and moves on smoothly, at once under
                  // reduced motion
                  EaseSize(
                    child: progress == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: progress!.clamp(0.0, 1.0)),
                              duration: motionStill(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: v,
                                  minHeight: 3,
                                  color: tint,
                                  backgroundColor: tint.withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    // the answers flow onto a second line in longer languages
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// a device was linked to the account: said on every own device, and it
// stays until the person opens the devices page. never in the decoy
class _LinkNoticeCard extends StatelessWidget {
  const _LinkNoticeCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([linkNotices, lockState]),
      builder: (context, _) {
        final all = linkNotices.value;
        final show = all.isNotEmpty && !lockState.inDecoy && !sessionQuiet;
        final words = all.isEmpty
            ? (title: l10n.devicesNewNotice, line: '')
            : linkNoticeWords([
                for (final n in all) (name: n.name, at: n.at, why: n.why),
              ], homeClock());
        return _HomeCard(
          show: show,
          id: 'link-notice',
          tint: HaloColors.amber,
          wash: true,
          title: words.title,
          line: words.line,
          lineColor: HaloColors.text,
          actions: [
            CardAction(
              label: l10n.devicesNewNoticeOpen,
              onTap: () async {
                HapticFeedback.selectionClick();
                final src = await ownDevicesSource();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  haloRoute(
                    LinkedDevicesScreen(source: src, copyPage: historyCopyPage),
                  ),
                );
              },
              fill: HaloColors.amber,
              ink: HaloColors.onAmber,
            ),
          ],
        );
      },
    );
  }
}

// a linked computer whose chats may still be on their way from its phone:
// a copy not begun, or a phone not heard for a day. it never looks like a
// home of its own meanwhile
class _LinkedComingCard extends StatefulWidget {
  const _LinkedComingCard();
  @override
  State<_LinkedComingCard> createState() => _LinkedComingCardState();
}

class _LinkedComingCardState extends State<_LinkedComingCard> {
  bool _show = false;
  Timer? _every;
  late final Listenable _moves = Listenable.merge([
    historyCopyShown,
    lockState,
  ]);

  Future<void> _check() async {
    final v = await linkedChatsComing();
    if (mounted && v != _show) setState(() => _show = v);
  }

  @override
  void initState() {
    super.initState();
    _moves.addListener(_check);
    _every = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    _check();
  }

  @override
  void dispose() {
    _moves.removeListener(_check);
    _every?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _HomeCard(
    show: _show,
    id: 'linked-coming',
    tint: HaloColors.amber,
    wash: true,
    title: l10n.settingsLinkedToYourPhone,
    line: l10n.homeLinkedChatsComing,
    lineColor: HaloColors.text,
    actions: const [],
  );
}

// a history copy under way, or one that ended and has not been seen: said
// on the phone and on the new device until the person opens it. never in
// the decoy
/// the history copy's page, as the card and a link that took open it
Widget historyCopyPage(BuildContext _) => HistoryCopyScreen(
  stage: historyCopyShown,
  nameOf: historyChatName,
  onSeen: historyCopyOpened,
);

class _HistoryCopyCard extends StatelessWidget {
  const _HistoryCopyCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        historyCopyShown,
        historyCopySeen,
        lockState,
      ]),
      builder: (context, _) {
        final s = historyCopyShown.value;
        final over = s != null && historyCopyOver(s.step);
        final show =
            s != null &&
            (!over || !historyCopySeen.value) &&
            !lockState.inDecoy &&
            !sessionQuiet;
        final words = historyCopyWords(
          s ?? const HistoryCopyStage(HistoryCopyStep.making),
        );
        return _HomeCard(
          show: show,
          id: 'history-copy',
          tint: HaloColors.amber,
          wash: true,
          title: words.title,
          line: s != null && s.bytes > 0 && !over
              ? l10n.historyCopySize(historyCopySize(s.bytes))
              : words.line,
          lineColor: HaloColors.text,
          progress:
              s != null &&
                  !over &&
                  s.records > 0 &&
                  s.step != HistoryCopyStep.making
              ? s.share
              : null,
          actions: [
            CardAction(
              label: l10n.historyCopySee,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(haloRoute(historyCopyPage(context)));
              },
              fill: HaloColors.amber,
              ink: HaloColors.onAmber,
            ),
          ],
        );
      },
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
class OfflineCard extends StatefulWidget {
  const OfflineCard({super.key});

  @override
  State<OfflineCard> createState() => _OfflineCardState();
}

class _OfflineCardState extends State<OfflineCard> {
  // its "for how long" moves on while the card is seen
  final _timers = SeenTimers();

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
      // the way out is the chats' too: a reconnect done there counts here
      animation: Listenable.merge([appState, torValve]),
      builder: (context, _) {
        final since = appState.offlineFor ?? Duration.zero;
        torValve.sawLink(appState.linkUp);
        // a decoy has no network: nothing to say, nothing to restart
        final quiet = sessionQuiet;
        final stage = torValve.stageFor(
          private: appState.sendMode == 'private',
          quiet: quiet,
          online: appState.online,
          waitingSince: DateTime.now().subtract(since),
          linkUp: appState.linkUp,
        );
        final busy = stage == ValveStage.working || stage == ValveStage.cooling;
        final restart = stage == ValveStage.restart;
        return _HomeCard(
          show: appState.looksOffline && !quiet,
          id: 'offline',
          tint: HaloColors.rose,
          title: l10n.homeKryfoIsOffline,
          line: l10n.homeTorHasNotBeen(_howLong(since)),
          lineColor: HaloColors.warm,
          actions: [
            // a reconnect first, and a restart that keeps the queue when tor
            // would not take it
            CardAction(
              label: busy
                  ? l10n.homeReconnecting
                  : restart
                  ? l10n.valveRestartKryfo
                  : l10n.homeReconnect,
              onTap: busy
                  ? null
                  : restart
                  ? torValve.tryRestart
                  : torValve.tryReconnect,
              fill: HaloColors.roseFill,
              ink: HaloColors.onRose,
              swap: true,
            ),
            CardAction(
              label: l10n.homeWhatIsWrong,
              onTap: () =>
                  deskPush(context, haloRoute(const TransportScreen())),
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
          CardAction(
            label: l10n.homeSwitchToCheckIns,
            onTap: _switch,
            fill: HaloColors.amber,
            ink: HaloColors.onAmber,
          ),
          CardAction(
            label: l10n.homeNotNow,
            onTap: () => appState.nudgeAnswered(),
            ink: HaloColors.warm,
          ),
        ],
      ),
    );
  }
}

// the helper app chosen for waking kryfo is no longer on the phone, or our
// relay stopped knocking: the phone is back on check-ins. said once
class _HelperGoneCard extends StatelessWidget {
  const _HelperGoneCard();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => _HomeCard(
        show: appState.helperGoneDue,
        id: 'helper-gone',
        tint: HaloColors.amber,
        title: appState.helperRelayStopped
            ? l10n.homeHelperRelayTitle
            : appState.helperGoneWasGoogle
            ? l10n.homeGoogleGoneTitle
            : l10n.homeHelperGoneTitle,
        line: l10n.homeHelperGoneLine,
        lineColor: HaloColors.warm,
        actions: [
          CardAction(
            label: l10n.homeHelperGoneChoose,
            onTap: () {
              unawaited(appState.helperGoneAnswered());
              deskPush(context, haloRoute(const NotificationsScreen()));
            },
            fill: HaloColors.amber,
            ink: HaloColors.onAmber,
          ),
          CardAction(
            label: l10n.homeNotNow,
            onTap: () => appState.helperGoneAnswered(),
            ink: HaloColors.warm,
          ),
        ],
      ),
    );
  }
}

// a play build updated from before google push: one calm card offering it,
// once. never in a decoy (googleCardDue)
class _GooglePushCard extends StatefulWidget {
  const _GooglePushCard();

  @override
  State<_GooglePushCard> createState() => _GooglePushCardState();
}

class _GooglePushCardState extends State<_GooglePushCard> {
  bool _busy = false;

  Future<void> _use() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await appState.useGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      HapticFeedback.lightImpact();
      showHaloToast(context, l10n.homeGoogleOn);
    } else {
      // the card stays, so it can be tried again
      HapticFeedback.heavyImpact();
      showHaloToast(context, l10n.notificationsGoogleNoStart);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => _HomeCard(
        show: appState.googleCardDue,
        id: 'google-push',
        tint: HaloColors.amber,
        wash: true,
        title: l10n.homeGoogleTitle,
        // on fast it also says what our servers see while they wake it
        line: appState.sendMode == 'private'
            ? l10n.homeGoogleLine
            : '${l10n.homeGoogleLine}\n${l10n.notificationsGoogleOnFast}',
        lineColor: HaloColors.warm,
        actions: [
          CardAction(
            label: _busy
                ? l10n.notificationsGoogleStarting
                : l10n.homeGoogleUse,
            onTap: _busy ? null : _use,
            fill: HaloColors.amber,
            ink: HaloColors.onAmber,
            swap: true,
          ),
          CardAction(
            label: l10n.homeNotNow,
            onTap: _busy ? null : () => appState.googleCardAnswered(),
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
        CardAction(
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
        CardAction(
          label: l10n.homeLeaveThemOff,
          onTap: () async {
            await dismissNotifHint();
            if (mounted) setState(() => _show = false);
          },
          ink: HaloColors.text,
        ),
      ],
    );
  }
}

// the old switch for the whole app was on: one ask about the chats' own
// switches, then never again
class _ShotsCard extends StatefulWidget {
  const _ShotsCard();

  @override
  State<_ShotsCard> createState() => _ShotsCardState();
}

class _ShotsCardState extends State<_ShotsCard> {
  bool _busy = false;

  Future<void> _answer(bool on) async {
    if (_busy) return;
    setState(() => _busy = true);
    final n = await appState.answerShotsCard(on: on);
    if (!mounted) return;
    setState(() => _busy = false);
    if (on && n > 0) showHaloToast(context, l10n.homeShotsTurnedOn(n));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, lockState]),
      builder: (context, _) => _HomeCard(
        show: appState.shotsCardDue,
        id: 'shots-per-chat',
        tint: HaloColors.amber,
        title: l10n.homeShotsPerChat,
        line: '${l10n.homeShotsTurnOnForAll} ${l10n.homeShotsTheySeeIt}',
        actions: [
          // a yes needs a chat whose phone knows the block; until one does
          // the card says so in its place
          if (appState.shotsCardCan)
            CardAction(
              label: l10n.homeShotsTurnOn,
              onTap: () => _answer(true),
              fill: HaloColors.amber,
              ink: HaloColors.onAmber,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.chatShotsWhenTheyUpdateShown,
                style: HaloType.sans(size: 12.5, color: HaloColors.text),
              ),
            ),
          CardAction(
            label: l10n.homeShotsLeaveOff,
            onTap: () => _answer(false),
            ink: HaloColors.text,
          ),
        ],
      ),
    );
  }
}

// windows without a passphrase: the computer's key goes with the account
// and its security chip, so a backup is the way back. shown once and put
// away for good on this side; a decoy shows the same card and keeps its
// answer to itself
class _ComputerBackupCard extends StatelessWidget {
  const _ComputerBackupCard();

  @override
  Widget build(BuildContext context) {
    final lock = computerLock;
    if (lock == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([lock, lockState]),
      builder: (context, _) {
        final decoy = lockState.inDecoy;
        return _HomeCard(
          // a linked computer keeps no backup: its phone has every chat
          show:
              !lockState.inVault &&
              !linkedRole &&
              lock.backupCardDue(decoy: decoy),
          id: 'computer-backup',
          tint: HaloColors.amber,
          title: l10n.desktopBackupCardTitle,
          line: l10n.desktopBackupCardLine,
          actions: [
            CardAction(
              label: l10n.backupBackUpKryfo,
              onTap: () {
                HapticFeedback.selectionClick();
                unawaited(lock.backupCardSeen(decoy: decoy));
                Navigator.of(context).push(haloRoute(const BackupScreen()));
              },
              fill: HaloColors.amber,
              ink: HaloColors.onAmber,
            ),
            CardAction(
              label: l10n.homeMergedGotIt,
              onTap: () {
                HapticFeedback.selectionClick();
                unawaited(lock.backupCardSeen(decoy: decoy));
              },
              ink: HaloColors.text,
            ),
          ],
        );
      },
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
        show: appState.suggestPrivateFallback,
        id: 'relay-down',
        tint: HaloColors.amber,
        title: l10n.homeOursDownTitle,
        line: l10n.homeOursDownLine,
        actions: [
          CardAction(
            label: l10n.homeUsePrivate,
            onTap: () async {
              try {
                await appState.setSendMode('private');
              } catch (_) {
                if (context.mounted) {
                  showHaloToast(context, l10n.modesNotChanged);
                }
                return;
              }
              if (context.mounted) {
                showHaloToast(context, l10n.homeSwitchedToPrivate);
              }
            },
            fill: HaloColors.amber,
            ink: HaloColors.onAmber,
          ),
          CardAction(
            label: l10n.homeKeepWaiting,
            onTap: () => appState.dismissRelayHint(),
            ink: HaloColors.text,
          ),
        ],
      ),
    );
  }
}

// once, after the update, for whoever was on relay or fast: the two are one
// route now, and private is a tap away
class _RouteMergedCard extends StatelessWidget {
  const _RouteMergedCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => GrowSwap(
        alignment: Alignment.topCenter,
        child: !appState.routeMergeCardDue
            ? const SizedBox(key: ValueKey('no-merged'), width: 1)
            : RouteMergedCard(
                key: const ValueKey('merged'),
                onGotIt: () {
                  HapticFeedback.selectionClick();
                  appState.routeMergeCardSeen();
                },
                onPrivate: () async {
                  HapticFeedback.mediumImpact();
                  try {
                    await appState.setSendMode('private');
                  } catch (_) {
                    if (context.mounted) {
                      showHaloToast(context, l10n.modesNotChanged);
                    }
                    return;
                  }
                  await appState.routeMergeCardSeen();
                  if (context.mounted) {
                    showHaloToast(context, l10n.homeSwitchedToPrivate);
                  }
                },
              ),
      ),
    );
  }
}

// automatic is past the usual way or gave up: its own line, and the way
// to the details
class _AutoStrip extends StatelessWidget {
  const _AutoStrip();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final line = shownBridgeLine();
        final a = line.action;
        // fast quiet, after the bridge way: this network sees it
        final relay = CardAction(
          label: l10n.homeUseFast,
          onTap: () => switchToRelay(context),
          ink: HaloColors.amberText,
        );
        return _HomeCard(
          show: appState.homeBridgeCard == 'auto',
          id: 'auto',
          tint: line.tone == BridgeTone.rose
              ? HaloColors.rose
              : HaloColors.amber,
          title: line.head,
          line: line.detail ?? '',
          actions: [
            // nothing got through: the bridge way, then fast
            if (a != null)
              CardAction(
                label: bridgeActionLabel(a),
                onTap: () async {
                  if (a == BridgeAction.tryAgain) return appState.bridgeRetry();
                  if (a == BridgeAction.openWifi) {
                    await openWifiSettings();
                    return;
                  }
                  await showTorBlockedSheet(context);
                },
                fill: HaloColors.amber,
                ink: HaloColors.onAmber,
              ),
            if (line.offerRelay) relay,
            CardAction(
              label: l10n.bridgesDetails,
              onTap: () => deskPush(context, haloRoute(const BridgesScreen())),
              ink: HaloColors.amber,
              bold: true,
            ),
          ],
        );
      },
    );
  }
}

// an upgrade from before automatic, on tor alone: offered once
class _AutoOffer extends StatelessWidget {
  const _AutoOffer();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => _HomeCard(
        show: appState.homeBridgeCard == 'offer',
        id: 'auto-offer',
        tint: HaloColors.violet,
        wash: true,
        title: l10n.bridgesKryfoCanGetAround,
        line: l10n.bridgesAutomaticFindsAWay,
        actions: [
          CardAction(
            label: l10n.bridgesTurnOnAutomatic,
            onTap: () async {
              HapticFeedback.selectionClick();
              await appState.chooseBridge(BridgeChoice.auto);
            },
            fill: HaloColors.violet,
            ink: HaloColors.onViolet,
          ),
          CardAction(
            label: l10n.bridgesNotNow,
            onTap: () => appState.dismissAutoOffer(),
            ink: HaloColors.text,
          ),
        ],
      ),
    );
  }
}

// a bridge picked by hand is not getting through
class _BridgeStuckHint extends StatelessWidget {
  const _BridgeStuckHint();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => _HomeCard(
        show: appState.homeBridgeCard == 'stuck',
        id: 'bridges-stuck',
        tint: HaloColors.rose,
        title: l10n.bridgesThisBridgeIsnTGetting,
        line: l10n.bridgesBridgesGoDeadWithout,
        actions: [
          CardAction(
            label: l10n.bridgesSwitchToAutomatic,
            onTap: () async {
              await appState.chooseBridge(BridgeChoice.auto);
              appState.applyBridgeNow();
            },
            fill: HaloColors.roseFill,
            ink: HaloColors.onRose,
          ),
        ],
      ),
    );
  }
}

// tor alone is not getting through: let kryfo find a bridge, or fast last,
// with what this network sees on it
class _BridgeHint extends StatelessWidget {
  const _BridgeHint();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => _HomeCard(
        show: appState.homeBridgeCard == 'hint',
        id: 'bridges',
        tint: HaloColors.violet,
        wash: true,
        title: l10n.bridgesTorSeemsBlocked,
        line: l10n.bridgesBridgeFirstFastSeen,
        actions: [
          CardAction(
            label: l10n.bridgesTryAutomatic,
            onTap: () async {
              await appState.chooseBridge(BridgeChoice.auto);
              appState.applyBridgeNow();
            },
            fill: HaloColors.violet,
            ink: HaloColors.onViolet,
          ),
          CardAction(
            label: l10n.homeUseFast,
            onTap: () => switchToRelay(context),
            ink: HaloColors.violet,
            bold: true,
          ),
          CardAction(
            label: l10n.homeKeepWaiting,
            onTap: () => appState.dismissBridgeHint(),
            ink: HaloColors.text,
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
    // the reading the pill above it shows: the same grace, the same words
    return LinkViewBuilder(
      builder: (context, link) {
        // a message for someone who has not added you back waits on them,
        // and their chat says so: the strip counts only what the phone
        // itself holds back
        final n = appState.queued - appState.parkedQueued;
        // a send in flight while the phone can send is not news. the strip
        // speaks when the phone cannot send.
        final offline = link.kind == LinkKind.offline;
        final cannotSend = !link.connected;
        // the route coming up is what every launch looks like: with an
        // empty queue there is nothing to explain. offline is worth stating
        // even with nothing queued.
        final show = cannotSend && (offline || n > 0);
        // it opens its height and folds away, so the list slides
        return GrowSwap(
          alignment: Alignment.topCenter,
          child: show
              ? KeyedSubtree(
                  key: const ValueKey('strip'),
                  child: _strip(context, n, offline, link.text),
                )
              : const SizedBox(key: ValueKey('no-strip'), width: 1),
        );
      },
    );
  }

  Widget _strip(BuildContext context, int n, bool offline, String state) {
    // a status: the warn yellow, never the accent
    final tint = offline ? HaloColors.rose : HaloColors.warn;
    final words = offline ? HaloColors.rose : HaloColors.warnText;
    final head = offline ? l10n.homeOffline : l10n.homeWaiting;
    // say whether anything is queued, not only that the phone is offline.
    // it only shows when the phone cannot send, so it offers no retry
    final tail = n == 0
        ? l10n.homeNothingWaitingToSend
        : offline
        ? l10n.homeWaitingSendsWhenYou(n)
        : l10n.homeWaitingState(n, state);

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
              color: words,
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
                color: words.withValues(alpha: 0.85),
                weight: FontWeight.w500,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- empty state ----

// no chats yet: the developer chat's row on top, the groups heading under
// it, and the page still asks to add someone. short phones and big fonts
// scroll it
class _EmptyWithDev extends StatelessWidget {
  final DevRow? dev;
  final void Function(String chatId) onOpenDev;
  final VoidCallback onAdd;
  final VoidCallback onNewGroup;
  final VoidCallback onNewRoom;
  final String? expiredRoomName;
  const _EmptyWithDev({
    super.key,
    required this.dev,
    required this.onOpenDev,
    required this.onAdd,
    required this.onNewGroup,
    required this.onNewRoom,
    this.expiredRoomName,
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
        // a room needs no contacts, so the way to one is here too
        SliverToBoxAdapter(
          child: _GroupsHead(
            onNewGroup: onNewGroup,
            onNewRoom: onNewRoom,
            expiredRoomName: expiredRoomName,
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
  // the ring pulses twice as the page arrives, then stops: nothing
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

  bool _sharing = false;

  // no share sheet on a desktop: the add page has the link to copy
  Future<void> _invite() async {
    if (!canShareOut) return widget.onAdd();
    if (_sharing) return;
    _sharing = true;
    try {
      await shareInvite(context);
    } finally {
      _sharing = false;
    }
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
              // a linked device adds no one: its phone does
              linkedRole
                  ? l10n.linkedAddOnPhone
                  : l10n.homeScanTheirCodeSendShown,
              textAlign: TextAlign.center,
              style: HaloType.sans(size: 13, color: HaloColors.text),
            ),
            if (!linkedRole) ...[
              const SizedBox(height: 22),
              // one clear way: the invite goes out in any messenger. the
              // code and the @name sit under it
              PressScale(
                onTap: _invite,
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
                        Icons.ios_share_rounded,
                        size: 16,
                        color: HaloColors.onAmber,
                      ),
                      const SizedBox(width: 8),
                      // a large font wraps the label instead of cutting it
                      Flexible(
                        child: Text(
                          l10n.homeInviteSomeone,
                          textAlign: TextAlign.center,
                          style: HaloType.sans(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: HaloColors.onAmber,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Semantics(
                button: true,
                child: PressScale(
                  onTap: widget.onAdd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      l10n.homeAddSomeone,
                      textAlign: TextAlign.center,
                      style: HaloType.sans(
                        size: 13,
                        weight: FontWeight.w500,
                        color: HaloColors.amberText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
// is new grows in, one that goes folds away, and one that moves slides to
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

  // the session the drafts were read for: a vault opening or shutting
  // makes a new one, so a hidden chat's draft shows only while it is open
  Object? _draftsRead;

  void _reloadDrafts() {
    final s = session;
    _draftsRead = s;
    unawaited(HomeDrafts.reload(s, s.drafts));
  }

  List<_Item> _topItems() => [
    if (widget.dev case final d? when d.pinned) _Item.dev(d, top: true),
  ];

  List<_Item> _chatItems() {
    final chats = draftOrder(widget.contacts, HomeDrafts.times);
    final items = [for (final c in chats) _Item.chat(c)];
    final d = widget.dev;
    if (d != null && !d.pinned) {
      items.insert(devSlot(d, chats), _Item.dev(d, top: false));
    }
    return items;
  }

  // a draft typed or let go: its row moves to its place
  void _draftsMoved() {
    if (!mounted) return;
    _chats.update(_chatItems(), quiet: lockGuard.isLocked());
  }

  @override
  void initState() {
    super.initState();
    draftsRevision.addListener(_reloadDrafts);
    HomeDrafts.shown.addListener(_draftsMoved);
    _reloadDrafts();
    _top.start(_topItems());
    _groups.start([for (final g in widget.groups) _Item.group(g)]);
    _chats.start(_chatItems());
  }

  @override
  void didUpdateWidget(_ContactList old) {
    super.didUpdateWidget(old);
    if (!identical(session, _draftsRead) || HomeDrafts.unread) {
      _reloadDrafts();
    }
    final quiet = lockGuard.isLocked();
    _top.update(_topItems(), quiet: quiet);
    _groups.update([
      for (final g in widget.groups) _Item.group(g),
    ], quiet: quiet);
    _chats.update(_chatItems(), quiet: quiet);
  }

  @override
  void dispose() {
    draftsRevision.removeListener(_reloadDrafts);
    HomeDrafts.shown.removeListener(_draftsMoved);
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
    // the chat open in the desktop's pane is marked
    final marked = WideMark(
      id: g != null ? 'group:${g.groupId}' : d?.chatId ?? c!.haloId,
      child: row,
    );
    // keyed, so a row that moves up on a new message slides there
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
              child: marked,
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
          deskPush(context, searchRoute(context));
        }
        if (n.metrics.pixels >= 0) _opened = false;
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // the developer chat, pinned: above everything, the groups too
          for (final (n, d) in top.indexed) _row(_top, d, n),
          // on the phone the heading is where a group or a room is made, even
          // with none yet. a linked device makes neither, so it shows only
          // over groups or an ended room
          if (!linkedRole ||
              groups.isNotEmpty ||
              widget.expiredRoomName != null)
            _GroupsHead(
              onNewGroup: widget.onNewGroup,
              onNewRoom: widget.onNewRoom,
              expiredRoomName: widget.expiredRoomName,
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

// the groups heading with its two ways in, and under it the line for a
// room that just ended, which opens and folds away a few seconds later.
// the empty home shows it too: a room needs no contacts
class _GroupsHead extends StatelessWidget {
  final VoidCallback onNewGroup;
  final VoidCallback onNewRoom;
  final String? expiredRoomName;
  const _GroupsHead({
    required this.onNewGroup,
    required this.onNewRoom,
    this.expiredRoomName,
  });

  @override
  Widget build(BuildContext context) {
    final expired = expiredRoomName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionHead(
          label: l10n.homeGroups,
          actions: [
            // burner rooms stay on the phone
            if (!linkedRole)
              _HeadAction(
                icon: Icons.timer_outlined,
                label: l10n.homeRoom,
                color: HaloColors.violet,
                onTap: onNewRoom,
              ),
            // and so are groups: a phone takes no group from a device
            if (!linkedRole)
              _HeadAction(
                icon: Icons.add_rounded,
                label: l10n.homeNew,
                color: HaloColors.amber,
                onTap: onNewGroup,
              ),
          ],
        ),
        GrowSwap(
          alignment: Alignment.topCenter,
          child: expired == null
              ? const SizedBox(key: ValueKey('no-expired'), width: 1)
              : Padding(
                  key: ValueKey('expired-$expired'),
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      l10n.homeRoomExpired(expired),
                      style: HaloType.mono(
                        size: 10,
                        color: HaloColors.violetText,
                      ),
                    ),
                  ),
                ),
        ),
      ],
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
            child: Semantics(
              header: true,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HaloType.mono(
                  size: 10,
                  color: HaloColors.text,
                  weight: FontWeight.w500,
                  letter: 0.14,
                ),
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
                  // the words take the tone's text twin: the raw one is under 4.5:1 in light
                  color: HaloColors.wordsIn(color),
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
  final _entrance = Entrance();

  // motion off or a held ticker: the row at rest from the first frame
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animate && !_c.isCompleted && entranceOff(context)) _c.value = 1;
  }

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
        if (mounted) _entrance.play(context, _c);
      });
    }
  }

  @override
  void dispose() {
    // a row past its entrance never made one, and a ticker is not made on
    // the way out
    _entrance.dispose();
    if (_animate) _c.dispose();
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
    // the menu key and shift+f10 on a computer, as a right click
    return DeskMenuKeys(
      onMenu: () => _groupMenu(context, g),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          // held: its menu, as a chat's. a right click on a computer
          onLongPress: () => _groupMenu(context, g),
          onSecondaryTap: onDesktop ? () => _groupMenu(context, g) : null,
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
                  // an ended group's tile goes quiet, as a closed room's link
                  HaloHero(
                    tag: 'group-${g.groupId}',
                    child: AnimatedContainer(
                      duration: motionStill(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: g.ended
                            ? HaloColors.surface2
                            : g.isRoom
                            ? HaloColors.violet.withValues(alpha: 0.14)
                            : HaloColors.amberSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: g.ended
                              ? HaloColors.line2
                              : (g.isRoom
                                        ? HaloColors.violet
                                        : HaloColors.amber)
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
                          color: g.ended
                              ? HaloColors.text2
                              : g.isRoom
                              ? HaloColors.violetText
                              : HaloColors.amberText,
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
                                  color: g.ended
                                      ? HaloColors.text2
                                      : HaloColors.text,
                                ),
                              ),
                            ),
                            HiddenMark(on: g.hidden),
                            // when its last message came, as a chat row says
                            if (g.when case final at?) ...[
                              const Spacer(),
                              const SizedBox(width: 8),
                              Text(
                                _relTime(at),
                                maxLines: 1,
                                style: HaloType.mono(
                                  size: 10.5,
                                  color: g.unread > 0
                                      ? HaloColors.amberText
                                      : HaloColors.text2,
                                  weight: g.unread > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        // not let in yet: no clock, no count, until it is.
                        // a new state rises in over the last one
                        ValueListenableBuilder(
                          valueListenable: HomeDrafts.shown,
                          builder: (_, drafts, _) {
                            final draft =
                                drafts[HomeDrafts.rowKey(
                                  g.groupId,
                                  group: true,
                                )];
                            return RiseSwap(
                              child: g.ended
                                  // its admin ended it: the line, in place of all else
                                  ? Text(
                                      endedLine((at: 0, by: g.endedBy!)),
                                      key: const ValueKey('ended'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HaloType.sans(
                                        size: 12,
                                        color: HaloColors.text,
                                      ).copyWith(fontStyle: slant()),
                                    )
                                  : g.isRoom && g.joiningAt != null
                                  ? RoomJoinLine(
                                      key: const ValueKey('joining'),
                                      joiningAt: g.joiningAt!,
                                      full: appState.roomFull(g.groupId),
                                    )
                                  : g.isRoom
                                  ? RoomCountdown(
                                      key: const ValueKey('room'),
                                      expiresAt: g.expiresAt!,
                                      size: 10,
                                    )
                                  // a draft wins over the last message
                                  : draft != null
                                  ? DraftLine(
                                      key: const ValueKey('draft'),
                                      text: draft,
                                    )
                                  : g.preview != null
                                  // who wrote last, and what, as a chat row says it
                                  ? Text(
                                      g.preview!,
                                      key: ValueKey('line:${g.preview}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HaloType.sans(
                                        size: 12,
                                        color: g.unread > 0
                                            ? HaloColors.text
                                            : HaloColors.text2,
                                      ),
                                    )
                                  : Text(
                                      l10n.homeMembers(g.memberCount),
                                      key: const ValueKey('members'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HaloType.mono(
                                        size: 10,
                                        color: HaloColors.text,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // your three words came up in there: an @ by the count
                  MentionBadge(on: g.mentioned && !g.ended, lead: 8),
                  // pops in, rolls to each new count, pops away once read
                  CountBadge(count: g.unread, lead: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// the @ by a group's count while someone wrote your three words in there:
/// it pops in with the house spring, as the count does, and fades when the
/// phone asks for no movement
class MentionBadge extends StatelessWidget {
  final bool on;
  final double lead;
  const MentionBadge({super.key, required this.on, this.lead = 0});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final badge = Semantics(
      key: const ValueKey('at'),
      label: l10n.homeMentionedYou,
      child: ExcludeSemantics(
        child: Container(
          margin: EdgeInsetsDirectional.only(start: lead),
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HaloColors.amber,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '@',
            maxLines: 1,
            style: HaloType.mono(
              size: 11,
              weight: FontWeight.w700,
              color: HaloColors.onAmber,
              letter: 0,
            ).copyWith(height: 1.2),
          ),
        ),
      ),
    );
    return AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 120 : 260),
      reverseDuration: Duration(milliseconds: still ? 120 : 160),
      transitionBuilder: (child, a) => still
          ? FadeTransition(opacity: a, child: child)
          : FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: ScaleTransition(
                scale: Tween(begin: 0.4, end: 1.0).animate(
                  CurvedAnimation(
                    parent: a,
                    curve: kHouseCurve,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
                child: child,
              ),
            ),
      child: on ? badge : const SizedBox.shrink(key: ValueKey('no-at')),
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
      style: HaloType.mono(size: 8, color: HaloColors.amberText),
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
  showMenuSheet<String>(
    context,
    groups: (ctx) {
      void pick(String a) => Navigator.pop(ctx, a);
      return [
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
            sub: l10n.homeMessagesAndContactGoneShown,
            danger: true,
            onTap: () => pick('delete'),
          ),
        ],
      ];
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

/// a group hides while hidden chats are open. a room cannot: it ends with
/// its clock, and its rows never move
@visibleForTesting
bool groupMenuHides(GroupSummary g, {required bool inVault}) =>
    inVault && !g.isRoom;

// a group's or a room's menu: hide it while hidden chats are open, or
// leave it, after saying what leaving costs
void _groupMenu(BuildContext context, GroupSummary g) {
  HapticFeedback.mediumImpact();
  showMenuSheet<String>(
    context,
    groups: (ctx) {
      void pick(String a) => Navigator.pop(ctx, a);
      return [
        if (groupMenuHides(g, inVault: lockState.inVault))
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
        // a linked device leaves on its phone (GroupOnPhone); an ended
        // group still goes from here alone
        if (g.ended || !linkedRole)
          [
            MenuSheetRow(
              icon: g.ended ? Icons.delete_outline : Icons.logout_rounded,
              label: g.ended
                  ? l10n.groupInfoDeleteGroup
                  : g.isRoom
                  ? l10n.groupInfoLeaveRoom2
                  : l10n.groupInfoLeaveGroup2,
              danger: true,
              onTap: () => pick('leave'),
            ),
          ]
        else
          [
            MenuSheetRow(
              icon: Icons.smartphone_outlined,
              label: l10n.linkedDoOnPhone,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
      ];
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
    title: g.ended
        ? l10n.groupInfoDeleteThisGroup
        : g.isRoom
        ? l10n.groupInfoLeaveRoom
        : l10n.groupInfoLeaveGroup,
    line: g.ended
        ? l10n.groupInfoDeleteGroupLine
        : leaveLine(
            room: g.isRoom,
            admin: ((row?['is_admin'] as int?) ?? 0) == 1,
          ),
    yes: g.ended ? l10n.commonDelete : l10n.groupInfoLeave,
  );
  if (!ok) return;
  HapticFeedback.heavyImpact();
  await appState.leaveGroupAndAnnounce(g.groupId);
}

Future<void> _confirmDelete(BuildContext context, ContactPreview c) async {
  final ok = await showConfirmSheet(
    context,
    title: l10n.homeDeleteThisChat,
    line: ownChatEndsHere
        ? l10n.linkedDeleteHereOnly
        : l10n.homeEveryMessageWithGoesShown(c.nickname ?? c.haloId),
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
  showMenuSheet<String>(
    context,
    groups: (ctx) {
      void pick(String a) => Navigator.pop(ctx, a);
      return [
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
      ];
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
    // the menu key and shift+f10 on a computer, as a right click
    return DeskMenuKeys(
      onMenu: onLongPress,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          // a right click on a computer opens the row's menu
          onSecondaryTap: onDesktop ? onLongPress : null,
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
                HaloHero(tag: kDevFaceHero, child: const DevAvatar(pop: true)),
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
                                color: HaloColors.text,
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
                                    ? HaloColors.amberText
                                    : HaloColors.text2,
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
    // the menu key and shift+f10 on a computer, as a right click
    return DeskMenuKeys(
      onMenu: onLongPress,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          // a right click on a computer opens the row's menu
          onSecondaryTap: onDesktop ? onLongPress : null,
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
                      HaloHero(
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
                                    color: HaloColors.text,
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
                                        ? HaloColors.amberText
                                        : HaloColors.text2,
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
                            // "Typing" takes the preview's place while they
                            // type, over a draft too
                            child: TypingSwap(
                              showing: c.blocked
                                  ? const AlwaysStoppedAnimation(false)
                                  : appState.typing.board.of(
                                      appState.typingKey(c.haloId),
                                    ),
                              style: typingStyle(size: 12),
                              // a draft takes the last message's place
                              child: ValueListenableBuilder(
                                valueListenable: HomeDrafts.shown,
                                builder: (_, drafts, _) {
                                  final draft = c.blocked
                                      ? null
                                      : drafts[HomeDrafts.rowKey(
                                          c.haloId,
                                          group: false,
                                        )];
                                  return RiseSwap(
                                    child: draft != null
                                        ? DraftLine(
                                            key: const ValueKey('draft'),
                                            text: draft,
                                          )
                                        : Text(
                                            // a room link is an invitation,
                                            // not a line of two hundred
                                            // characters
                                            (c.preview ?? '').contains(
                                                  'kryfo://room?',
                                                )
                                                ? l10n.homeRoomInvite
                                                : (c.preview ?? ''),
                                            key: const ValueKey('preview'),
                                            // unread reads in full colour
                                            // until it is read
                                            style: HaloType.sans(
                                              size: 12,
                                              color: c.unread > 0
                                                  ? HaloColors.text
                                                  : HaloColors.text2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  );
                                },
                              ),
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
      ),
    );
  }
}

/// the chats in list order once drafts count: a chat whose draft is newer
/// than its last message moves up to where that time falls among the
/// others. pinned rows stay where they are, the rest keep their order
@visibleForTesting
List<ContactPreview> draftOrder(
  List<ContactPreview> chats,
  Map<String, int> drafts,
) {
  int? draftAt(ContactPreview c) {
    if (c.pinned || c.blocked) return null;
    final at = drafts[HomeDrafts.rowKey(c.haloId, group: false)];
    if (at == null) return null;
    final last = c.when?.millisecondsSinceEpoch ?? 0;
    return at > last ? at : null;
  }

  final moving = [
    for (final c in chats)
      if (draftAt(c) != null) c,
  ]..sort((a, b) => draftAt(b)!.compareTo(draftAt(a)!));
  if (moving.isEmpty) return chats;
  final out = [
    for (final c in chats)
      if (!moving.contains(c)) c,
  ];
  for (final m in moving.reversed) {
    final at = draftAt(m)!;
    var i = 0;
    // under the pinned rows and anything newer
    while (i < out.length &&
        (out[i].pinned ||
            (out[i].when?.millisecondsSinceEpoch ?? 0) >= at ||
            (draftAt(out[i]) ?? 0) >= at)) {
      i++;
    }
    out.insert(i, m);
  }
  return out;
}

/// a chat row's draft: the label in the accent, then the words in their own
/// direction, one line
class DraftLine extends StatelessWidget {
  const DraftLine({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: l10n.homeDraftA11y(text),
      excludeSemantics: true,
      child: Row(
        children: [
          Text(
            l10n.homeDraftLabel,
            maxLines: 1,
            style: HaloType.sans(
              size: 12,
              weight: FontWeight.w600,
              color: HaloColors.amberText,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: writtenDir(text),
              style: HaloType.sans(size: 12, color: HaloColors.text),
            ),
          ),
        ],
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
                line: l10n.homeOnlyOnThisPhoneShown,
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
                    style: HaloType.sans(size: 10.5, color: HaloColors.text),
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
