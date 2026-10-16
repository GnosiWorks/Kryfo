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
part 'app/dev_screen.dart';
part 'app/engine.dart';
part 'app/files.dart';
part 'app/gates.dart';
part 'app/groups.dart';
part 'app/links.dart';
part 'app/routing.dart';
part 'app/sending.dart';
part 'app/shell.dart';
part 'app/signal.dart';
part 'app/state.dart';

void main() async {
  dlog('launch main');
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
    dlog('launch headless');
    // no window: the service or the job brought the process back, and
    // runApp would throw without a view. only an engine with something to
    // serve boots here: samsung relaunches a recently used app's process
    // right after its data is cleared, and booting then would make a fresh
    // identity out of a panic wipe. the rest waits for a window.
    unawaited(() async {
      if (await _hasLocalData()) {
        await appState.boot();
      } else {
        dlog('launch headless with nothing here, waiting for a window');
      }
    }());
    Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (PlatformDispatcher.instance.implicitView == null) return;
      t.cancel();
      dlog('launch window arrived');
      WidgetsBinding.instance.addObserver(lockBack);
      runApp(const HaloApp());
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotif());
    });
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) => dlog('launch frame'));
  // before runApp, so it is asked about back before the app's navigator
  WidgetsBinding.instance.addObserver(lockBack);
  runApp(const HaloApp());
  dlog('launch runApp returned');
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
