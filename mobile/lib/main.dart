// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'secure_store.dart';
import 'widgets/boot_failed.dart';
import 'widgets/fade_over.dart';
import 'widgets/tor_boot_splash.dart';
import 'widgets/theme_refresh.dart';
import 'widgets/wall_images.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:ffi';
import 'dart:io';
import 'shred.dart';
import 'album.dart' show AlbumTag, albumGoneUid, albumInWindow, albumItemBurnAt;
export 'shred.dart' show shredFile, shredTree;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'image_strip.dart' show photoToSendOffUi;
import 'package:path_provider/path_provider.dart';
import 'notifications.dart';
import 'orientation.dart' show appOrientations;
import 'backup.dart' show backupRunning, restoreRunning, sweepBackupLeftovers;
import 'picked.dart'
    show dropPickerCopies, sweepFilePickerCopies, sweepPickerLeftovers;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'theme.dart';
import 'wipe.dart';
import 'group_end.dart';
import 'group_media_send.dart';
import 'media_progress.dart';
import 'media_send.dart';
import 'msg_order.dart';
import 'send_order.dart';
import 'media_resend.dart';
import 'delivery_mode.dart';
import 'bridge_mode.dart';
import 'screens/bridges_screen.dart' show BridgesScreen;
import 'offline_gate.dart';
import 'in_front.dart';
import 'reopen.dart';
import 'tor_valve.dart';
import 'auto_restart.dart';
import 'drafts.dart'
    show dropDraft, everydayChats, restartKeepingDrafts, restoreKeptDrafts;
import 'helper_delivery.dart';
import 'helper_push.dart';
import 'screens/getting_messages_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_group_screen.dart';
import 'screens/room_create_sheet.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/group_chat_screen.dart';
import 'screens/requests_screen.dart' show RequestsScreen, backToRequests;
import 'screens/chat_door.dart' show openChatAt;
import 'screens/chat_screen.dart';
import 'screens/dev_about_sheet.dart' show devChatRoute;
import 'devchat/dev_start.dart' show DevKeyCheckFailed, DevStart;
import 'screens/pair_code_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/my_kryfo_screen.dart';
import 'screens/onboarding_screen.dart';
import 'contact_card.dart' show sweepCardLeftovers;
import 'container.dart';
import 'lock_state.dart';
import 'app_shell.dart';
import 'lock_guard.dart';
import 'lock_layer.dart';
import 'screens/lock_screen.dart';
import 'screens/lock_setup_screen.dart';
import 'screens/moved_screen.dart';
import 'pin_gate.dart';
import 'widgets/pins.dart' show kMaxPins;
import 'push_mode.dart';
import 'intro_prefs.dart';
import 'scam_prefs.dart';
import 'scam_shield.dart';
import 'rooms.dart';
import 'outbox.dart';
import 'supporter.dart';
import 'chat_shots.dart';
import 'message_envelope.dart';
import 'polls.dart';
import 'open_file.dart' show nameSaysVideo, shareGoesWithLock;
import 'search.dart';
import 'search_bench.dart';
import 'session.dart';
import 'router.dart';
import 'vault_life.dart';
import 'voice_choice.dart';
import 'tools/tools_bridge.dart' show ToolsBridge;
import 'devchat/dev_chat.dart';
import 'devchat/dev_frame.dart' show DevSelf, devInFrame;
import 'devchat/dev_gate.dart';
import 'devchat/dev_key.dart';
import 'devchat/dev_lane.dart';
import 'devchat/support.dart';
import 'screens/support_screen.dart' show askMoveIntoChats, openSupportTap;
import 'stickers/sticker_pack.dart' show StickerLibrary;
import 'stickers/sticker_wire.dart' show StickerWire, stickerText;
import 'widgets/motion.dart';
import 'widgets/pair_join.dart' show pairUnreached;
import 'widgets/pair_code_panel.dart' show PairCodes;
import 'widgets/kryfo_link_text.dart'
    show addScanned, askTakeNameSheet, takeOutsideLink, takeOwnLink;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:app_links/app_links.dart';
import 'signal_session.dart';
import 'key_number.dart';
import 'signal_stores.dart'
    show invitePreKeyId, kDevSignalPrefix, onPeerKeyChanged;
import 'dart:isolate';
import 'dlog.dart';
import 'read_burn.dart' show burnStartBy, burnWaitsRow, burnWaitsSql, kBurnSkew;
import 'stranger_gate.dart';
import 'first_contact.dart';
import 'text_send.dart' show kSendBlocked;
import 'fast_gate.dart';
import 'mentions.dart';
import 'gifs/gif_source.dart' show sweepGifParts;
import 'notes_export.dart' show dropNotesExports, sweepNotesExports;
import 'handle_lookup.dart';
import 'handle_repoint.dart';
import 'widgets/sheet_handle.dart';
import 'widgets/halo_sheet.dart';
import 'widgets/owned_text.dart';
import 'bidi_safe.dart';
import 'engine_strings.dart';
import 'net_detail.dart';
import 'relay_poll.dart';
import 'l10n/l10n.dart';
import 'l10n/numbers.dart';
import 'l10n/app_locale.dart';
import 'widgets/shift_tap_guard.dart';
import 'wire_pad.dart';

part 'app/arrivals.dart';
part 'app/boot.dart';
part 'app/database.dart';
part 'app/engine.dart';
part 'app/files.dart';
part 'app/groups.dart';
part 'app/links.dart';
part 'app/routing.dart';
part 'app/sending.dart';
part 'app/signal.dart';
part 'app/state.dart';

void main() async {
  dlog('LAUNCH main');
  WidgetsFlutterBinding.ensureInitialized();
  // a key saved for someone that is not the one held before: open pages that
  // show it read again
  onPeerKeyChanged = appState.keyChanged;
  // a toast shown while the lock is up waits for it to lift
  haloWhenOpen = (act) => lockGuard.afterUnlock(act);
  // toasts live in the root overlay, over every route and sheet
  haloToastOverlay = () => rootNavKey.currentState?.overlay;
  // an unlock opens its session under the lock screen, before it lifts
  lockState.onOutcome = appState.sessionFor;
  lockState.sessionsReady = appState.containersReady;
  lockState.picksDropped = dropPickerCopies;
  // a draft is written down for a restart only for a chat that is still
  // there
  everydayChats = () => live.draftChats();
  // what a hidden chat or the decoy shares goes with the next lock
  shareGoesWithLock = () => sessionQuiet || session.vault != null;
  unawaited(_sweepNotesAtLaunch());
  unawaited(_sweepPlaintextLeftovers());
  // what a backup or a restore cut short left, before either can run again
  unawaited(sweepBackupLeftovers());
  // not awaited: this is a platform call, and with no activity attached it
  // never answers
  unawaited(SystemChrome.setPreferredOrientations(appOrientations));
  // drawn under the bars on android 10 to 14 too, as 15 and later force.
  // older versions ignore it. android keeps this on the screen, which the
  // engine outlives: asked before one was attached, or of one since
  // replaced, it is lost, so it is asked again on every return
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  WidgetsBinding.instance.addObserver(_underBars);
  // the periodic job knocks here every fifteen minutes. registered before
  // anything that could fail, and whether or not a screen is attached:
  // after a kill the system restarts the process for the service or the
  // job, and this handler is what is there to answer.
  const MethodChannel('halo/job').setMethodCallHandler((call) async {
    if (call.method != 'drain') return null;
    dlog('job: drain asked');
    appState.noteJobRun();
    final args = call.arguments;
    final ago = args is Map ? args['ago'] : null;
    // a knock from the helper app, or the timer: the same check-in, locked,
    // in a decoy or not
    final why = args is Map && args['why'] == 'push' ? 'push' : 'job';
    return appState.drainNow(
      serviceUp: args is Map && args['up'] == true,
      jobAgo: ago is int ? Duration(milliseconds: ago) : null,
      why: why,
    );
  });
  // the language, before anything says a word: the first frame, or a
  // notification from a process the job started
  await loadAppLocale();
  // the theme pref sits in secure storage, and the first read on a new phone
  // creates the keystore key, which takes seconds. the splash paints dark
  // first. started before the window check so a headless start loads it too.
  unawaited(
    appState.loadThemePref().then((_) {
      if (HaloColors.isLight || HaloColors.accent != HaloAccent.yellow) {
        themeRevision.value++;
      }
    }),
  );
  if (PlatformDispatcher.instance.implicitView == null) {
    dlog('LAUNCH headless');
    // no window: the service or the job brought the process back, and
    // runApp would throw without a view. only an engine with something to
    // serve boots here: samsung relaunches a recently used app's process
    // right after its data is cleared, and booting then would make a fresh
    // identity out of a panic wipe. the rest waits for a window.
    unawaited(() async {
      if (await _hasLocalData()) {
        await appState.boot();
      } else {
        dlog('LAUNCH headless with nothing here - waiting for a window');
      }
    }());
    Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (PlatformDispatcher.instance.implicitView == null) return;
      t.cancel();
      dlog('LAUNCH window arrived');
      WidgetsBinding.instance.addObserver(lockBack);
      runApp(const HaloApp());
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotif());
    });
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) => dlog('LAUNCH frame'));
  // before runApp, so it is asked about back before the app's navigator
  WidgetsBinding.instance.addObserver(lockBack);
  runApp(const HaloApp());
  dlog('LAUNCH runApp returned');
  // cold-start: if launched from a notification tap, open the chat
  // after the first frame so rootNavKey has a navigator.
  WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotif());
}

final _underBars = _UnderBars();

class _UnderBars with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }
}

final themeRevision = ValueNotifier<int>(0);

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ThemeRefresh(
      revision: themeRevision,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          themeRevision,
          localeRevision,
          navRevision,
        ]),
        builder: (context, _) => haloAppShell(
          navigatorKey: rootNavKey,
          locale: l10nLocale,
          lock: (navigator) => _LockGate(child: navigator),
          home: _LocaleScope(child: _OnboardingGate(child: RootShell())),
        ),
      ),
    );
  }
}

// true when the phone asks for less movement. widgets check this before
// running anything decorative.
bool reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_onChange);
    // boot after the first frame is on screen. loading libhalo.so pulls in the
    // whole go runtime + embedded tor and blocks briefly, and before the first
    // paint that can trip the anr watchdog on weak phones.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => appState.bootWhenWanted(),
    );
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    appState.removeListener(_onChange);
    super.dispose();
  }

  void _open(Widget w) {
    Navigator.push(context, haloRoute(w));
  }

  @override
  Widget build(BuildContext context) {
    if (!appState.ready) {
      return Scaffold(
        backgroundColor: HaloColors.surface,
        body: Center(
          child: Text(
            appState.onboardingComplete
                ? l10n.appBooting
                : l10n.appSettingUpYourIdentity,
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
        ),
      );
    }
    return HomeScreen(
      key: ValueKey(appState.sessionRev),
      haloId: appState.sessionId,
      contacts: appState.contacts,
      devRow: appState.devRow,
      pendingCount: appState.pendingCount,
      support: appState.devMode ? appState.supportWaiting : null,
      groups: appState.groups
          .map(
            (g) => GroupSummary(
              groupId: g.groupId,
              name: g.name,
              memberCount: g.memberCount,
              unread: g.unread,
              mentioned: g.mentioned,
              expiresAt: g.expiresAt,
              joiningAt: g.joiningAt,
              hidden: g.hidden,
              endedBy: g.endedBy,
            ),
          )
          .toList(),
      onAddContact: () => showAddContact(context),
      onNewGroup: () => _open(const NewGroupScreen()),
      onNewRoom: () async {
        final id = await showRoomCreateSheet(context);
        if (id == null || !mounted) return;
        _open(GroupChatScreen(groupId: id));
      },
      expiredRoomName: appState.expiredRoomName,
      onOpenDev: () => _open(const DevScreen()),
      onOpenSettingsDirect: () => _open(SettingsScreen()),
      onOpenChat: (id) => openChatAt(context, peer: id),
      onOpenGroup: (groupId) async {
        if (!mounted) return;
        Navigator.push(context, haloRoute(GroupChatScreen(groupId: groupId)));
      },
    );
  }
}

Future<void> showAddContact(BuildContext context) async {
  final ctrl = TextEditingController();
  final action = await showHaloSheet<String>(
    context,
    builder: (sheetCtx) => _AddSheet(ctrl: ctrl, done: sheetCtx),
  );
  if (action == null || !context.mounted) return;
  if (action == 'mine') {
    await Navigator.of(context).push(haloRoute(const MyKryfoScreen()));
    return;
  }

  String uri;
  if (action == 'scan') {
    final result = await Navigator.of(
      context,
    ).push<String>(haloRoute<String>(const ScanScreen()));
    if (result == null) return;
    uri = result;
  } else {
    uri = ctrl.text.trim();
    if (uri.isEmpty) return;
  }

  if (!context.mounted) return;
  // a room shows what its link says first: put away, nothing happened
  final status = await takeOwnLink(
    context,
    uri,
    act: action == 'scan' ? addScanned : handleHaloUri,
  );
  if (status == null) return;
  await appState.refreshContacts();
  if (!context.mounted) return;
  showHaloToast(context, status);
}

// the add someone sheet. the field lights up while it is typed in, and
// "add them" fills once there is something to add. the house sheet scrolls
// it above the keyboard
class _AddSheet extends StatefulWidget {
  final TextEditingController ctrl;
  // the sheet's own context, which the choice pops
  final BuildContext done;
  const _AddSheet({required this.ctrl, required this.done});
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    _focus.addListener(_repaint);
    widget.ctrl.addListener(_repaint);
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_repaint);
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  // nothing to add yet: the sheet stays, the field shakes and takes the
  // focus, so a link can go straight in
  void _add() {
    if (widget.ctrl.text.trim().isNotEmpty) {
      Navigator.pop(widget.done, 'paste');
      return;
    }
    _focus.requestFocus();
    if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final sheetCtx = widget.done;
    final still = MediaQuery.disableAnimationsOf(context);
    final d = still ? Duration.zero : const Duration(milliseconds: 200);
    final typed = widget.ctrl.text.trim().isNotEmpty;
    final lit = _focus.hasFocus;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 18),
            Text(
              l10n.appAddSomeone,
              style: HaloType.serif(
                size: 22,
                italic: true,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.appScanTheirCodeOr,
              style: HaloType.sans(size: 12.5, color: HaloColors.text2),
            ),
            const SizedBox(height: 16),
            _Pressable(
              onTap: () => Navigator.pop(sheetCtx, 'scan'),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 19,
                      color: HaloColors.onAmber,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      l10n.appScanTheirCode,
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: HaloColors.onAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _shake,
              // a damped side to side, three swings
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  sin(_shake.value * pi * 6) * 9 * (1 - _shake.value),
                  0,
                ),
                child: child,
              ),
              child: AnimatedContainer(
                duration: d,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.surface3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: lit
                        ? HaloColors.amber.withValues(alpha: 0.7)
                        : HaloColors.line,
                    width: lit ? 1 : 0.5,
                  ),
                ),
                child: ShiftTapGuard(
                  controller: widget.ctrl,
                  child: TextField(
                    textDirection: TextDirection.ltr,
                    controller: widget.ctrl,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 3,
                    // "add them" under it comes into view with it
                    scrollPadding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      20 + 10 + 46,
                    ),
                    style: HaloType.mono(size: 12, color: HaloColors.text),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l10n.appAKryfoLinkA,
                      hintStyle: HaloType.mono(
                        size: 12,
                        color: HaloColors.text3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _Pressable(
              onTap: _add,
              child: AnimatedContainer(
                duration: d,
                curve: Curves.easeOutCubic,
                height: 46,
                decoration: BoxDecoration(
                  color: typed ? HaloColors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HaloColors.amber, width: 1),
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: d,
                    style: HaloType.sans(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: typed ? HaloColors.onAmber : HaloColors.amberText,
                    ),
                    child: Text(l10n.appAddThem),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // the page with every way in: your own code, a link to send,
            // handles, introductions
            _Pressable(
              onTap: () => Navigator.pop(sheetCtx, 'mine'),
              // the door most people need, so it gets the amber edge and glow
              // the jump button uses
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: HaloColors.amber.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HaloColors.amber.withValues(alpha: 0.16),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: HaloColors.amberSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.qr_code_2,
                        size: 20,
                        color: HaloColors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.appEveryWayToAdd,
                            style: HaloType.sans(
                              size: 14.5,
                              weight: FontWeight.w600,
                              color: HaloColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.appShowYourCodeSend,
                            style: HaloType.sans(
                              size: 11.5,
                              color: HaloColors.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: HaloColors.amber,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  double _scale = 1;
  void _set(double v) {
    if (mounted) setState(() => _scale = v);
  }

  @override
  Widget build(BuildContext context) {
    // with less movement the press is felt, not seen
    final still = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(0.96),
      onTapUp: (_) => _set(1),
      onTapCancel: () => _set(1),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: still ? 1 : _scale,
        duration: Duration(milliseconds: _scale < 1 ? 90 : 240),
        curve: _scale < 1 ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

class DevScreen extends StatefulWidget {
  const DevScreen({super.key});
  @override
  State<DevScreen> createState() => _DevScreenState();
}

/// scan, pairing code or a pasted link: the choice and the words pasted.
/// null when cancelled or dismissed
@visibleForTesting
Future<(String, String)?> showImportPeerDialog(BuildContext context) =>
    showDialog<(String, String)>(
      context: context,
      builder: (_) => OwnedText(
        builder: (ctx, ctrl) => AlertDialog(
          backgroundColor: HaloColors.surface2,
          title: Text(
            l10n.appAddAKryfo,
            style: HaloType.sans(color: HaloColors.amberText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, ('scan', ctrl.text)),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.appScanQr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HaloColors.amber,
                    foregroundColor: HaloColors.onAmber,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.maxFinite,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, ('code', ctrl.text)),
                  icon: const Icon(Icons.dialpad, size: 18),
                  label: Text(l10n.appPairingCode),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HaloColors.text2,
                    side: BorderSide(color: HaloColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.appOrPaste,
                style: HaloType.sans(size: 11, color: HaloColors.text2),
              ),
              const SizedBox(height: 10),
              ShiftTapGuard(
                controller: ctrl,
                child: TextField(
                  textDirection: TextDirection.ltr,
                  controller: ctrl,
                  maxLines: 4,
                  style: HaloType.mono(size: 11, color: HaloColors.text),
                  decoration: InputDecoration(
                    hintText: 'kryfo://share?...',
                    hintStyle: HaloType.mono(size: 11, color: HaloColors.text3),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ('paste', ctrl.text)),
              child: Text(
                l10n.appImport,
                style: HaloType.sans(color: HaloColors.amberText),
              ),
            ),
          ],
        ),
      ),
    );

class _DevScreenState extends State<DevScreen> {
  final _msgCtrl = TextEditingController(text: l10n.appHelloFromTheOther);
  String _myAddr = '';
  String _status = '';
  TorStatus _torStatus = TorStatus.off;
  int _bootstrapPct = 0;
  String _peerId = '';
  String _peerOnion = '';
  String _peerXPub = '';

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _status = appState.restored
        ? l10n.appIdentityRestored
        : l10n.appIdentityCreated;
    _loadLastPeer();
  }

  Future<void> _loadLastPeer() async {
    final rows = await session.contacts();
    if (rows.isEmpty) return;
    setState(() {
      _peerId = rows.first['halo_id'] as String;
      _peerOnion = rows.first['onion'] as String;
      _peerXPub = rows.first['xpub'] as String;
    });
  }

  Future<void> _startListener() async {
    setState(() => _status = l10n.appStartingTor30s);
    final docsDir = await getApplicationDocumentsDirectory();
    // off the ui thread: starting tor blocks on socket i/o long enough to
    // trip an anr
    final addr = await _startListenerOnIsolate(docsDir.path);
    setState(() {
      if (addr.startsWith('error')) {
        _status = addr;
      } else {
        _myAddr = addr;
        _status = '';
      }
    });
    _pollTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final raw = engine.getStatus();
      final newStatus = parseTorStatus(raw);
      final newPct = parseBootstrapPct(raw);
      if ((newStatus != _torStatus || newPct != _bootstrapPct) && mounted) {
        setState(() {
          _torStatus = newStatus;
          _bootstrapPct = newPct;
        });
      }
      final msgs = engine.drainInbox();
      if (msgs.isEmpty || _peerXPub.isEmpty) return;
      for (final r in msgs) {
        final plain = engine.decryptFrom(_peerXPub, r);
        if (!plain.startsWith('error')) {
          session.saveMessage(_peerId, 'in', plain);
        }
        setState(() {});
      }
    });
  }

  Future<void> _send() async {
    if (_peerOnion.isEmpty || _peerXPub.isEmpty) {
      setState(() => _status = l10n.appScanOrImportA);
      return;
    }
    setState(() => _status = l10n.appEncryptingSending30s);
    final plain = _msgCtrl.text;
    final cipher = engine.encryptFor(_peerXPub, plain);
    if (cipher.startsWith('error')) {
      setState(() => _status = cipher);
      return;
    }
    final result = await Future(() => engine.sendTo(_peerOnion, cipher));
    if (result == 'ok') {
      await session.saveMessage(_peerId, 'out', plain);
    }
    setState(() => _status = result);
  }

  Future<void> _showMyQr() async {
    if (_myAddr.isEmpty) {
      setState(() => _status = l10n.appTapStartListeningFirst);
      return;
    }
    final uri = await buildHaloUriV3(
      appState.myId,
      _myAddr,
      appState.fcCounter,
    );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: HaloColors.onAmber,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appYourKryfo,
                style: HaloType.serif(
                  size: 14,
                  italic: true,
                  color: HaloColors.amberText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appState.myId,
                style: HaloType.mono(size: 18, color: HaloColors.amberText),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: QrImageView(
                  data: uri,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HaloColors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  uri,
                  style: HaloType.mono(size: 9, color: HaloColors.amberText),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  copySensitive(uri);
                  showHaloToast(context, l10n.appUriCopied);
                },
                child: Text(
                  l10n.appCopyUri,
                  style: HaloType.sans(color: HaloColors.amberText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importPeer() async {
    final picked = await showImportPeerDialog(context);
    final action = picked?.$1;
    if (action == null || !mounted) return;

    if (action == 'code') {
      await Navigator.of(context).push(haloRoute(const PairCodeScreen()));
      await appState.refreshContacts();
      return;
    }

    String uri;
    if (action == 'scan') {
      final result = await Navigator.of(
        context,
      ).push<String>(haloRoute<String>(const ScanScreen()));
      if (result == null) return;
      uri = result;
    } else {
      uri = picked!.$2;
    }

    if (!mounted) return;
    final status = await takeOwnLink(
      context,
      uri,
      act: action == 'scan' ? addScanned : handleHaloUri,
    );
    if (status == null) return;
    await appState.refreshContacts();
    final parsed = parseHaloUri(uri);
    if (!mounted) return;
    setState(() {
      if (parsed != null) {
        _peerId = parsed['id'] ?? '';
        _peerOnion = parsed['onion'] ?? '';
        _peerXPub = parsed['xpub'] ?? '';
      }
      _status = status;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        title: Text(
          l10n.appDev,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Kryfo',
                style: HaloType.serif(
                  size: 56,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.amberText,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                engine.version(),
                style: HaloType.sans(size: 11, color: HaloColors.text2),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.appYourKryfo2,
                style: HaloType.sans(size: 11, color: HaloColors.text2),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: HaloColors.onAmber,
                  border: Border.all(color: HaloColors.amber, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  appState.myId.isEmpty ? '...' : appState.myId,
                  style: HaloType.mono(
                    size: 18,
                    color: HaloColors.amberText,
                    letter: 0.04,
                  ),
                ),
              ),
              if (appState.restored)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.appRestoredFromDisk,
                    style: HaloType.mono(size: 9, color: HaloColors.green),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _myAddr.isEmpty ? _startListener : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _myAddr.isEmpty ? l10n.appStartListening : l10n.appListening,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.qr_code, color: HaloColors.amber),
                      label: Text(l10n.appShowMyQr),
                      onPressed: _showMyQr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.content_paste, color: HaloColors.violet),
                      label: Text(l10n.appImportPeer),
                      onPressed: _importPeer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_peerId.isNotEmpty) ...[
                Text(
                  l10n.appPeer,
                  style: HaloType.sans(size: 11, color: HaloColors.text2),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: HaloColors.surface3,
                    border: Border.all(color: HaloColors.green, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _peerId,
                    style: HaloType.mono(size: 14, color: HaloColors.green),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ShiftTapGuard(
                controller: _msgCtrl,
                child: TextField(
                  controller: _msgCtrl,
                  style: HaloType.sans(color: HaloColors.text),
                  decoration: InputDecoration(
                    labelText: l10n.appMessageWillBeEncrypted,
                    labelStyle: HaloType.sans(color: HaloColors.text2),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (_myAddr.isEmpty || _peerOnion.isEmpty)
                    ? null
                    : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(l10n.appEncryptSend),
              ),
              const SizedBox(height: 16),
              TorWarmupGraph(status: _torStatus, bootstrapPct: _bootstrapPct),
              const SizedBox(height: 12),
              if (_status.isNotEmpty)
                Text(
                  l10n.appStatus(_status),
                  style: HaloType.sans(size: 12, color: HaloColors.text2),
                ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).push(haloRoute(const ModesScreen())),
                child: Text(
                  l10n.appSpeedPrivacy,
                  style: HaloType.mono(size: 11, color: HaloColors.amberText),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const GettingMessagesScreen())),
                child: Text(
                  l10n.appGettingMessages,
                  style: HaloType.mono(size: 11, color: HaloColors.amberText),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  if (lockState.lockOn) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: HaloColors.surface3,
                        title: Text(
                          l10n.appDisableAppLock,
                          style: HaloType.serif(
                            size: 18,
                            color: HaloColors.text,
                          ),
                        ),
                        content: Text(
                          l10n.appThePinWillBe,
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text2,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(
                              l10n.commonCancel,
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.text2,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(
                              l10n.appDisable,
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.rose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await lockState.disable();
                  } else {
                    Navigator.of(
                      context,
                    ).push(haloRoute(const LockSetupScreen()));
                  }
                },
                child: AnimatedBuilder(
                  animation: lockState,
                  builder: (_, _) => Text(
                    lockState.lockOn ? l10n.appAppLockOn : l10n.appAppLockOff,
                    style: HaloType.mono(size: 11, color: HaloColors.amberText),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingGate extends StatefulWidget {
  final Widget child;
  const _OnboardingGate({required this.child});
  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

// when the cold start's splash lets go, set once for the process: a gate
// built again for a switched session holds it to the same moment
DateTime? _splashUntil;

class _OnboardingGateState extends State<_OnboardingGate> {
  // boot is quick enough that the onion is gone before it registers. hold
  // the splash a beat on cold start so it gets seen. warm reopens skip it.
  bool _hold = false;
  // keeps the onboarding's state while it fades out over home
  var _onboardingKey = GlobalKey();
  Widget? _last;
  Widget? _leaving;

  @override
  void initState() {
    super.initState();
    if (!appState.ready) {
      appState.bootWhenWanted();
      _splashUntil ??= DateTime.now().add(const Duration(milliseconds: 2500));
    }
    final left = _splashUntil?.difference(DateTime.now());
    if (left != null && left > Duration.zero) {
      _hold = true;
      Future.delayed(left, () {
        if (mounted) setState(() => _hold = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final Widget before;
        if (appState.bootError != null) {
          before = BootFailedScreen(
            key: const ValueKey('failed'),
            error: appState.bootError!,
            onRetry: () {
              setState(() => _hold = false);
              appState.retryBoot();
            },
            onReopen: appState.bootStuck ? reopenApp : null,
          );
        } else if (!appState.ready || _hold || appState.firstRunAsk) {
          before = const TorBootSplash(key: ValueKey('splash'));
        } else if (appState.movedAway && !appState.movedReadOnly) {
          before = const MovedScreen(key: ValueKey('moved'));
        } else if (!appState.onboardingComplete) {
          before = OnboardingScreen(
            key: _onboardingKey,
            appState: appState,
            onComplete: () => appState.markOnboardingComplete(),
          );
        } else {
          // the onboarding fades out over home, once
          if (_last?.key == _onboardingKey) _leaving = _last;
          _last = null;
          return FadeOver(leaving: _leaving, child: widget.child);
        }
        // an onboarding gone another way may still be fading in the switcher
        if (_last?.key == _onboardingKey && before.key != _onboardingKey) {
          _onboardingKey = GlobalKey();
        }
        _last = before;
        _leaving = null;
        // the splash goes out first, then the next screen comes up: no
        // cut, and never both at once
        return AnimatedSwitcher(
          duration: motionStill(context)
              ? Duration.zero
              : const Duration(milliseconds: 440),
          switchInCurve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
          switchOutCurve: const Interval(0.65, 1, curve: Curves.easeIn),
          child: before,
        );
      },
    );
  }
}

// a language switch redraws everything below here from scratch, on the
// first screen: whatever was open above it is closed. the lock and the
// navigator stay, so a switch never asks for the pin again.
class _LocaleScope extends StatefulWidget {
  final Widget child;
  const _LocaleScope({required this.child});
  @override
  State<_LocaleScope> createState() => _LocaleScopeState();
}

class _LocaleScopeState extends State<_LocaleScope>
    with SingleTickerProviderStateMixin {
  // the new language comes up out of the background instead of every word
  // changing in one frame
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final _shown = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    localeRevision.addListener(_switched);
  }

  @override
  void dispose() {
    localeRevision.removeListener(_switched);
    _shown.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _switched() {
    if (lockGuard.isLocked()) {
      // under the lock nothing animates, so nothing may be left mid-pop:
      // a new navigator, home only
      renewRootNavigator();
    } else {
      rootNavKey.currentState?.popUntil((r) => r.isFirst);
    }
    setState(() {});
    if (!reduceMotion(context)) _fade.forward(from: 0);
    unawaited(appState.languageChanged());
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: HaloColors.surface,
    child: FadeTransition(
      opacity: _shown,
      child: KeyedSubtree(
        key: ValueKey(localeRevision.value),
        child: widget.child,
      ),
    ),
  );
}

class _LockGate extends StatefulWidget {
  final Widget child;
  const _LockGate({required this.child});
  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  @override
  Widget build(BuildContext context) => LockGate(
    app: widget.child,
    lock: lockState,
    loaded: () => lockState.loaded,
    locked: () => lockState.locked,
    load: lockState.load,
    leaving: lockState.leaving,
    returned: lockState.returned,
    left: lockState.left,
    guard: lockGuard,
    quiet: () => sessionQuiet,
    pad: (_) => const LockScreen(),
    lockingUp: appState.lockingUp,
    inFront: appState.appInFront,
    localesChanged: systemLocalesChanged,
    revealed: () {
      appRevealed = true;
      homeRevealed();
    },
  );
}

class TorHalo extends StatefulWidget {
  final bool label;
  const TorHalo({super.key, this.label = false});
  @override
  State<TorHalo> createState() => TorHaloState();
}

/// how long a bare connecting may stand before the pill says what it waits
/// for
const pillPatience = Duration(seconds: 30);

/// what the home pill says, and which kind of line it is: the words change
/// in place within a kind and cross over between kinds. offline is offline
/// in every mode. a decoy hears connected, connecting or offline
@visibleForTesting
({String text, String kind}) pillWords({
  required String mode,
  required TorStatus status,
  required bool online,
  required bool ready,
  required int pct,
  required Duration waited,
  required bool decoy,
}) {
  final off = status == TorStatus.off;
  if (!online && !(mode == 'private' && off)) {
    return (text: l10n.appOffline, kind: 'offline');
  }
  if (mode == 'balanced') return (text: l10n.appViaRelay, kind: 'relay');
  if (mode == 'fast') return (text: l10n.appFast, kind: 'fast');
  if (off) return (text: l10n.appTorOff, kind: 'off');
  if (ready) return (text: l10n.appTorReady, kind: 'ready');
  if (decoy || waited < pillPatience) {
    return (text: l10n.appConnecting2, kind: 'connecting');
  }
  // still building its route: how far along. up with no relay through:
  // that it waits for one
  if (status == TorStatus.starting) {
    return (text: l10n.appConnecting(percent(pct / 100)), kind: 'climbing');
  }
  return (text: l10n.appWaitingForARelay, kind: 'relay-wait');
}

class TorHaloState extends State<TorHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  // wakes the pill when a bare connecting has stood long enough
  Timer? _patience;

  // pulses only while tor is still coming up. once it is usable the chip
  // says so and rests, even when the onion is never confirmed reachable
  bool get _isConnecting => appState.torStatus == TorStatus.starting;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    appState.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  // a few pulses each time tor starts, then still: where tor is blocked it
  // can sit in starting for minutes, and nothing here may run that long.
  // each new way automatic tries gets a few more
  bool _pulsed = false;
  int _attempt = 0;

  // how long tor has been trying, as the app keeps it
  Duration get _waited {
    final t = appState.torTryingSince;
    return t == null ? Duration.zero : DateTime.now().difference(t);
  }

  void _armPatience() {
    final waiting =
        appState.sendMode == 'private' &&
        appState.online &&
        appState.torStatus != TorStatus.off &&
        !appState.torUsable;
    final left = pillPatience - _waited;
    if (!waiting || left <= Duration.zero) {
      _patience?.cancel();
      _patience = null;
      return;
    }
    if (_patience?.isActive ?? false) return;
    _patience = Timer(left + const Duration(milliseconds: 50), () {
      _patience = null;
      if (!mounted) return;
      setState(() {});
      _armPatience();
    });
  }

  void _sync() {
    _armPatience();
    if (!_isConnecting) {
      _pulsed = false;
      if (_c.isAnimating) _c.stop();
      return;
    }
    final a = appState.bridgeStatus.attempt;
    if (a != _attempt) {
      _attempt = a;
      if (a > 1) _pulsed = false;
    }
    if (_pulsed || _c.isAnimating) return;
    _pulsed = true;
    if (mounted && motionStill(context)) return;
    _c.repeat(count: _attempt > 1 ? 3 : 8);
  }

  // tor blocked or nothing got through: the way out is the bridges page
  void _tap() {
    final s = appState.bridgeStatus;
    if (!appState.inDecoyView && (s.exhausted || s.tryingAnother)) {
      Navigator.of(context).push(haloRoute(const BridgesScreen()));
      return;
    }
    _explain();
  }

  @override
  void dispose() {
    appState.removeListener(_sync);
    _patience?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _explain() {
    // capped and scrolling: on a small phone the words run taller than the
    // room above the navigation bar
    showHaloSheet(
      context,
      builder: (_) => AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final s = appState.torStatus;
          final pct = appState.bootstrapPct;
          // no network: tor keeps its last word and the route reads down, but
          // nothing about relays is true then. the home strip says offline too
          final offline = s != TorStatus.off && !appState.online;
          // bootstrapped and publishing both mean tor's client side is live:
          // messages send and arrive over relays, full 3 hops. the remaining
          // wait only publishes our own address so peers can dial us direct.
          // none of it counts while no relay gets through
          final line = s == TorStatus.off
              ? l10n.appTorIsOff
              : offline
              ? l10n.appOffline
              : !appState.torUsable && s != TorStatus.starting
              ? l10n.appConnecting2
              : s == TorStatus.reachable
              ? l10n.appConnectedRoutedThrough3
              : s == TorStatus.publishing
              ? l10n.appReadyToSendPublishing
              : s == TorStatus.bootstrapped
              ? l10n.appReadyToSendFinishing
              : l10n.appConnecting(percent(pct / 100));
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 8),
                  Text(
                    l10n.appTor,
                    style: HaloType.serif(
                      size: 20,
                      italic: true,
                      color: HaloColors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TorWarmupGraph(status: s, bootstrapPct: pct),
                  const SizedBox(height: 16),
                  Text(
                    line,
                    style: HaloType.mono(size: 12, color: HaloColors.text),
                  ),
                  if (s != TorStatus.reachable ||
                      !appState.torUsable ||
                      offline) ...[
                    const SizedBox(height: 16),
                    // past starting with no relay through, the first connection
                    // line would promise a wait that is already over
                    Text(
                      s == TorStatus.off
                          ? l10n.appTorIsOffTurn
                          : offline
                          ? l10n.onboardingKryfoBuildsAPrivateRouteBefore
                          : !appState.torUsable && s != TorStatus.starting
                          ? l10n.appTorNoRelayYet
                          : l10n.appTheFirstConnectionTakes,
                      style: HaloType.sans(
                        size: 12.5,
                        color: HaloColors.text,
                      ).copyWith(height: 1.5),
                    ),
                    // another send mode is no way out of having no network
                    if (!offline) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n.appRelayAndFastModes,
                        style: HaloType.sans(size: 11, color: HaloColors.text2),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ring(double size, Color color, double w) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: w),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // nothing to explain outside onion: no bootstrap, no circuit, no
      // descriptor
      onTap: appState.sendMode == 'private' ? _tap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([appState, _c]),
        builder: (context, _) {
          final s = appState.torStatus;
          final off = s == TorStatus.off;
          // ready is the test the outbox and the offline card use, so the
          // pill never says ready over a route nothing gets through
          final ready = appState.torUsable;
          final secured = ready && s == TorStatus.reachable;
          final connecting = _isConnecting;
          final still = motionStill(context);
          final said = pillWords(
            mode: appState.sendMode,
            status: s,
            online: appState.online,
            ready: ready,
            pct: appState.bootstrapPct,
            waited: _waited,
            decoy: appState.inDecoyView,
          );
          // relay does not go through tor, so tor being off never greys it
          final relay = said.kind == 'relay';
          final dim = off && !relay;
          final accent = relay
              ? HaloColors.sky
              : off
              ? HaloColors.text2
              : said.kind == 'offline'
              ? HaloColors.warn
              // one route, one colour. onion stays violet whether tor is
              // merely usable or fully published.
              : appState.sendMode == 'fast'
              ? HaloColors.greenText
              : ready
              ? HaloColors.violetText
              : HaloColors.warnText;
          final t = _c.value;
          Widget dot(Color accent) => SizedBox(
            width: 18,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (connecting)
                  Transform.scale(
                    scale: 0.5 + t,
                    child: Opacity(
                      opacity: (1 - t) * 0.7,
                      child: _ring(12, accent, 1.4),
                    ),
                  ),
                _ring(
                  12,
                  dim
                      ? HaloColors.text3.withValues(alpha: 0.4)
                      : accent.withValues(alpha: secured ? 1.0 : 0.85),
                  1.4,
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
              ],
            ),
          );
          // the state changes are the most watched thing on the screen: the
          // colour slides to the new one and the words cross-fade, rather
          // than both snapping
          Widget tinted(Widget Function(Color) build) =>
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: accent),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (_, c, _) => build(c ?? accent),
              );
          if (!widget.label) {
            return tinted(
              (c) =>
                  SizedBox(width: 20, height: 20, child: Center(child: dot(c))),
            );
          }
          return tinted(
            (c) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dot(c),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    said.text,
                    key: ValueKey(said.kind),
                    style: HaloType.mono(size: 11, color: c),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
