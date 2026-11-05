// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop app's start: the platform answers, private folders, the
// network watch and notifications put in place, then the vault opened by the
// computer's key or its passphrase, and only then the app itself
import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications_linux/flutter_local_notifications_linux.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart'
    show SharedPreferencesAsyncLinux;
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../dlog.dart';
import '../l10n/app_locale.dart' show loadAppLocale;
import '../l10n/l10n.dart';
import 'desktop_audio.dart';
import '../container.dart' show HaloContainer;
import 'desktop_channels.dart';
import 'desktop_db.dart';
import 'desktop_lock_screen.dart';
import 'desktop_mode.dart';
import 'desktop_net.dart';
import 'computer_lock.dart';
import 'desktop_paths.dart';
import 'desktop_trace.dart';
import 'desktop_platform.dart';
import 'desktop_run.dart';
import 'desktop_posix.dart';
import 'desktop_prefs.dart';
import 'desktop_toasts.dart';
import 'desktop_vault.dart';
import 'desktop_wipe.dart';
import 'keyring_linux.dart';
import 'sealed_format.dart' show EngineChunkCrypto;
import 'sealed_io.dart';
import 'sealed_native.dart' show nativeFilesSealed, sweepNativeCopies;
import 'seal_windows.dart';
import 'sealed_setup.dart';
import 'system_seal.dart';

/// the binding whose messenger answers the android channels
class DesktopBinding extends WidgetsFlutterBinding {
  // the field is set before the base constructor asks for the messenger
  DesktopBinding._(this._answers);

  static DesktopBinding install(Map<String, DesktopAnswer> answers) {
    DesktopBinding._(answers);
    return WidgetsBinding.instance as DesktopBinding;
  }

  final Map<String, DesktopAnswer> _answers;

  @override
  BinaryMessenger createBinaryMessenger() =>
      DesktopMessenger(super.createBinaryMessenger(), _answers);
}

/// notifications on desktop say what the phone's preview setting gave the
/// post: kryfo and new message unless previews are on
class QuietLinuxNotifications extends LinuxFlutterLocalNotificationsPlugin {
  /// a click brings the window up from the tray before the chat opens
  @override
  Future<bool?> initialize({
    required LinuxInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) => super.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: windowFirst(
      onDidReceiveNotificationResponse,
    ),
  );

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    LinuxNotificationDetails? notificationDetails,
    String? payload,
  }) {
    // a plain post has no title: still only that something came
    final named = title != null;
    return post(
      id: id,
      title: named ? title : 'Kryfo',
      body: named
          ? (body ?? l10n.notificationsNewMessage)
          : l10n.notificationsNewMessage,
      payload: payload,
    );
  }

  /// what reaches the desktop's notification server
  @visibleForTesting
  Future<void> post({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) => super.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: quietDetails(),
    payload: payload,
  );
}

/// a post's details: its sound as the notifications page's switch has it
@visibleForTesting
LinuxNotificationDetails quietDetails() =>
    LinuxNotificationDetails(suppressSound: !deskSound.value);

/// no camera plugin for desktop yet: none to offer, so the scan and the
/// camera screens say so instead of waiting on a reader that never starts
class NoCameras extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async => const [];
}

/// shared preferences in the app's own folder, not the plugin's own one
class _PrefsPlace extends PathProviderLinux {
  _PrefsPlace(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

/// tray words, in the app's language. the runner keeps the window's
/// process running in the tray while one is shown
const _desktopChannel = MethodChannel('kryfo/desktop');

/// a notification click: the window up first, then what the app does
@visibleForTesting
DidReceiveNotificationResponseCallback windowFirst(
  DidReceiveNotificationResponseCallback? then, {
  Future<void> Function() show = showWindow,
}) => (r) {
  unawaited(show());
  then?.call(r);
};

/// the window, shown and raised
Future<void> showWindow() async {
  try {
    await _desktopChannel.invokeMethod<void>('show');
  } catch (_) {}
}

/// [locked]: before the vault opens nothing arrives, and the tip says so.
/// once it is open, the runner also gets the line for the first close to
/// the tray, until it says it was shown
Future<void> sayTrayWords({bool locked = false}) async {
  final run = desktopRun;
  final hint = !locked && run is DesktopRun && !run.trayHinted;
  try {
    await _desktopChannel.invokeMethod<void>(
      'tray',
      trayWords(locked: locked, hint: hint),
    );
  } catch (_) {
    // a runner without a tray: closing the window ends the app
  }
}

/// the tray's words, in the app's language
@visibleForTesting
Map<String, String> trayWords({bool locked = false, bool hint = false}) => {
  'open': l10n.desktopLockOpen,
  'quit': l10n.desktopTrayQuit,
  'tip': locked ? l10n.desktopTrayLockedTip : l10n.desktopTrayTip,
  if (hint) 'hint': l10n.desktopTrayStillRunning,
};

/// started with the computer ([startHiddenFlag]): the runner keeps the
/// window hidden, so the tray icon comes before the vault opens, as the
/// way to the lock screen. the same icon whatever opens after
Future<bool> trayBeforeOpen({
  Future<bool?> Function() hidden = startedHidden,
  Future<void> Function()? words,
}) async {
  if (await hidden() != true) return false;
  await (words ?? () => sayTrayWords(locked: true))();
  return true;
}

/// true when the runner started with no window
Future<bool?> startedHidden() async {
  try {
    return await _desktopChannel.invokeMethod<bool>('startHidden');
  } catch (_) {
    return null;
  }
}

/// what keeps the vault's key without a passphrase: the Secret Service on
/// linux, dpapi on windows
SystemSeal? systemSeal() {
  if (Platform.isLinux) return KeyringSeal(const FfiSecretApi());
  if (Platform.isWindows) return WindowsSeal(const FfiWinCrypt());
  return null;
}

/// why the desktop will not start, before anything of it runs
enum DesktopStop { alreadyOpen, notYours, notPrivate, noMemory, failed }

/// the folder checks, in the order they are made: private, the user's own,
/// and no other process on it. a reopen's new process may find the old one
/// still letting go, so the lock is asked a few times
@visibleForTesting
Future<DesktopStop?> claimFolder(
  String root, {
  int Function() uid = getuid,
  Duration wait = const Duration(seconds: 3),
}) async {
  if (Platform.isWindows) {
    return windowsFolderStop(Platform.environment['KRYFO_FOLDER']);
  }
  if (!makePrivateDir(root)) return DesktopStop.notPrivate;
  if (ownerOf(root) != uid()) return DesktopStop.notYours;
  final lock = p.join(root, 'lock');
  final until = DateTime.now().add(wait);
  while (!holdLock(lock)) {
    if (DateTime.now().isAfter(until)) return DesktopStop.alreadyOpen;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return null;
}

/// on windows kryfo.exe checks, closes and locks the folder before dart
/// runs (runner/kryfo_win.cpp) and says how it went in KRYFO_FOLDER
@visibleForTesting
DesktopStop? windowsFolderStop(String? word) => switch (word) {
  'ok' => null,
  'locked' => DesktopStop.alreadyOpen,
  'owner' => DesktopStop.notYours,
  _ => DesktopStop.notPrivate,
};

Future<void> startDesktop(Future<void> Function() appMain) async {
  onDesktop = true;
  privateUmask();
  final root = desktopDataDir();
  final stop = await claimFolder(root);
  if (stop == null) startTrace(root);
  if (stop != null) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(DesktopStopApp(stop: stop));
    return;
  }
  // what a wipe could not take while its process ran (a file windows held)
  // goes before anything reads the folder: with no vault nothing opens
  await clearWithoutVault(root);
  final db = DesktopDb();
  final host = DesktopHost(dataDir: root);
  DesktopBinding.install(desktopAnswers(host, db));

  final uid = Platform.isWindows ? 0 : getuid();
  final runtime = desktopRuntimeDir(uid: uid, root: root);
  // without a folder in memory the engine's files and the temporary ones
  // would be plain on the disk while the app runs: linux refuses that.
  // windows has no tmpfs and keeps them in <root>/tmp (its own branch)
  if (runtime == null && !Platform.isWindows) {
    runApp(const DesktopStopApp(stop: DesktopStop.noMemory));
    return;
  }
  sweepOldRuntimeDirs(runtime, uid: uid, root: root);
  final paths = DesktopPaths(root, runtime: runtime);
  PathProviderPlatform.instance = paths;
  final vault = DesktopVault(p.join(root, 'vault.kv'));
  final seal = systemSeal();
  host.destroyKeys = vault.destroy;
  if (seal != null) host.forgetKeys = () => vault.forgetSystem(seal);
  host.letGo = db.closeAll;
  host.startOff = startOffHere;
  wipeThrough(host);
  final lock = DesktopComputerLock(vault, seal);
  computerLock = lock;
  FlutterSecureStoragePlatform.instance = VaultStorage(vault);
  SharedPreferencesStorePlatform.instance = VaultPrefs(vault);
  if (defaultTargetPlatform == TargetPlatform.linux) {
    final async = SharedPreferencesAsyncPlatform.instance;
    if (async is SharedPreferencesAsyncLinux) {
      // the plugin's own seam for where its file goes, marked for tests
      // ignore: invalid_use_of_visible_for_testing_member
      async.pathProvider = _PrefsPlace(
        (await paths.getApplicationSupportPath())!,
      );
    }
    ConnectivityPlatform.instance = DesktopConnectivity();
    FlutterLocalNotificationsPlatform.instance = QuietLinuxNotifications();
    Gst.registryDir = (await paths.getApplicationCachePath())!;
    JustAudioPlatform.instance = DesktopAudio();
  }
  if (Platform.isWindows) {
    FlutterLocalNotificationsPlatform.instance = QuietWindowsNotifications(
      raise: showWindow,
    );
  }
  CameraPlatform.instance = NoCameras();
  assertVaultOnly();

  // the prefs are shut until the vault opens: the lock screen speaks the
  // system's language
  await loadAppLocale();
  // the key goes from memory as the engine lets the app go
  closeOnDetach = AppLifecycleListener(onDetach: vault.close);
  // ended from outside, or from the tray: the marks kept, memory cleared,
  // the key let go, before the process goes
  void ending() {
    try {
      host.beforeExit?.call();
    } catch (_) {}
    vault.close();
  }

  // a logout, a terminal's ctrl-c, a closed terminal: one way out
  if (!Platform.isWindows) {
    for (final sig in [
      ProcessSignal.sigterm,
      ProcessSignal.sigint,
      ProcessSignal.sighup,
    ]) {
      sig.watch().listen((_) {
        ending();
        exit(0);
      });
    }
  }
  _desktopChannel.setMethodCallHandler((call) async {
    if (call.method == 'quit') ending();
    // the first close to the tray was said: never again
    final run = desktopRun;
    if (call.method == 'hinted' && run is DesktopRun) await run.markHinted();
    if (call.method == 'sessionLock') heardSessionLock(call.arguments);
    return null;
  });
  // windows: toasts go neutral while the session is locked
  if (Platform.isWindows) unawaited(readSessionLock(_desktopChannel));
  // a run before's temporary files: its key died with it, they go unread
  // tor's own folder stays: its state is no secret of the run
  if (Platform.isWindows) {
    clearFolder(
      p.join(root, 'tmp'),
      keep: [p.join(root, 'tmp', kEngineFolder, 'tor')],
    );
  }
  // asked before the vault can open, so its words never come after begin's
  await trayBeforeOpen();
  // what memory held from a run before goes now, before anything is plain
  if (runtime != null) {
    final docs = (await paths.getApplicationDocumentsPath())!;
    EngineFiles(
      docs: docs,
      support: (await paths.getApplicationSupportPath())!,
      runtime: runtime,
    ).clearMemory();
  } else {
    // windows: the plain copies a crash left for code outside dart
    sweepNativeCopies(p.join(root, 'tmp', 'native'));
  }
  var started = false;
  runApp(
    DesktopLockApp(
      vault: vault,
      seal: seal,
      onOpen: () {
        if (started) return;
        started = true;
        lock.opened();
        // the tray, as the switch was left. nothing arrives before the
        // vault opens, so closing the passphrase screen just quits, unless
        // the start with the computer put the icon up
        final run = DesktopRun(
          tray: const ChannelTray(sayTrayWords),
          place: startPlaceHere(read: vault.read, write: vault.write),
          read: vault.read,
          write: vault.write,
        );
        desktopRun = run;
        unawaited(run.begin());
        unawaited(() async {
          var step = 'seal';
          try {
            trace('vault open');
            await openSeal(
              root: root,
              runtime: runtime,
              vault: vault,
              host: host,
              paths: paths,
            );
            step = 'app';
            trace('seal open');
            await readDeskSound();
            await appMain();
            trace('app started');
          } catch (e, st) {
            // said, not left as a lock screen that never moves
            dlog('desktop start: $step ${e.runtimeType}');
            traceError(step, e, st);
            runApp(const DesktopStopApp(stop: DesktopStop.failed));
          }
        }());
      },
    ),
  );
}

/// 32 random bytes for this run's temporary files
@visibleForTesting
Uint8List sessionKey() {
  final r = Random.secure();
  return Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)));
}

/// every file under [dir] zeroed and removed, the folder kept, but for
/// what lies under [keep]. best effort: a file windows still holds stays
/// for the next start
@visibleForTesting
void clearFolder(String dir, {List<String> keep = const []}) {
  final d = Directory(dir);
  final List<FileSystemEntity> all;
  try {
    if (!d.existsSync()) return;
    all = d.listSync(recursive: true, followLinks: false);
  } catch (e, st) {
    traceError('clear', e, st);
    return;
  }
  for (final e in all) {
    if (e is! File) continue;
    if (keep.any((k) => p.equals(k, e.path) || p.isWithin(k, e.path))) {
      continue;
    }
    try {
      final n = e.lengthSync();
      final r = e.openSync(mode: FileMode.writeOnlyAppend);
      try {
        r.setPositionSync(0);
        for (var at = 0; at < n; at += 1 << 16) {
          r.writeFromSync(Uint8List(n - at < 1 << 16 ? n - at : 1 << 16));
        }
        r.flushSync();
      } finally {
        r.closeSync();
      }
      e.deleteSync();
    } catch (_) {}
  }
}

/// the seal over kryfo's files, once the vault is open: every file the
/// app reads and writes from here on goes through it
Future<void> openSeal({
  required String root,
  required String? runtime,
  required DesktopVault vault,
  required DesktopHost host,
  required DesktopPaths paths,
}) async {
  final docs = (await paths.getApplicationDocumentsPath())!;
  final support = (await paths.getApplicationSupportPath())!;
  // a sealed file may go out in the clear only into memory: not into a
  // temporary folder that is on the disk
  final areas = SealedAreas(
    docs: docs,
    support: support,
    runtime: runtime == null ? null : (await paths.getTemporaryPath())!,
    // windows has no folder in memory: its temporary files are on the disk,
    // sealed under a key that never leaves this process
    tmp: Platform.isWindows ? p.join(root, 'tmp') : null,
  )..filesKey = await filesKeyFrom(vault);
  if (Platform.isWindows) areas.sessionKey = sessionKey();
  final io = SealedIO(areas, const EngineChunkCrypto());
  IOOverrides.global = io;
  // where code outside dart gets its copies when there is no memfd: on
  // windows <root>/tmp, on the disk (B9), each gone when its reader is
  final spill = runtime == null ? p.join(root, 'tmp', 'native') : null;
  isolateRunner = <R>(FutureOr<R> Function() f) => runSealed(f);
  nativeFiles =
      <T>(
        List<String> ins,
        List<String> outs,
        Future<T> Function(List<String>, List<String>) run,
        bool Function(T)? ok,
      ) => nativeFilesSealed(areas, ins, outs, run, ok, spill);
  // a backup is encrypted already and may be large: on the disk
  bulkTempDir = () async {
    final d = p.join(root, 'tmp');
    makePrivateDir(d);
    return d;
  };

  for (final area in ['', '_k2', '_k3', '_k4', '*']) {
    if (vault.read(sweptEntry(area)) != null) areas.swept.add(area);
  }
  Future<void> sweep(String area, List<String> dirs) =>
      sweepArea(areas, vault, area, dirs);

  final keys = ContainerKeys(
    areas,
    onOpened: (suffix) => unawaited(
      sweep(suffix, [
        for (final f in ['media', 'wallpapers']) p.join(docs, '$f$suffix'),
      ]),
    ),
  );
  containerOpened = keys.opened;
  containerClosed = (id) => keys.closed(id, HaloContainer.byId(id)?.suffix);
  areas.lateKey = (suffix) {
    for (final c in [HaloContainer.everyday, HaloContainer.decoy]) {
      if (c.suffix != suffix) continue;
      final k = vault.read(c.keyName!);
      return k == null ? null : mediaKeyOf(k, c.id);
    }
    return null;
  };
  unawaited(
    sweep('*', [
      support,
      p.join(docs, 'restore_stage'),
      p.join(docs, 'restore_hidden'),
    ]),
  );
  makePlaceholders(docs);
  containersSwept = () => makePlaceholders(docs);

  final vaultGone = host.destroyKeys;
  EngineFiles? engineFiles;
  {
    // the engine is never handed docs: on windows its folder is on the disk
    // under <root>/tmp, its marks still sealed between runs
    final ef = engineFiles = EngineFiles(
      docs: docs,
      support: support,
      runtime: runtime ?? p.join(root, 'tmp'),
    );
    await ef.prepare(vault);
    ef.watch(vault);
    engineDirOf = (_) => ef.dir;
    engineStarter = (_, start) => ef.start(start);
  }
  host.destroyKeys = () {
    keys.closeAll();
    final f = areas.filesKey;
    f?.fillRange(0, f.length, 0);
    areas.filesKey = null;
    vaultGone?.call();
  };
  // after the engine has let go: its folder holds plain things while it runs
  host.engineGone = () => engineFiles?.destroy();
  host.beforeExit = () {
    engineFiles?.detach();
    keys.closeAll();
    final f = areas.filesKey;
    f?.fillRange(0, f.length, 0);
    areas.filesKey = null;
  };
  closeOnDetach?.dispose();
  closeOnDetach = AppLifecycleListener(
    onDetach: () {
      host.beforeExit?.call();
      vault.close();
    },
  );
}

/// an area's sweep, done once: from then a plain file there is damage.
/// top level, so the job the isolate gets holds its folder alone: made
/// inside openSeal it held openSeal's whole context, the vault with it,
/// and isolate.run could not send it
@visibleForTesting
Future<void> sweepArea(
  SealedAreas areas,
  DesktopVault vault,
  String area,
  List<String> dirs,
) async {
  if (areas.swept.contains(area)) return;
  try {
    for (final d in dirs) {
      await runSealed(sealUnderJob(d));
    }
    await vault.write(sweptEntry(area), '1');
    areas.swept.add(area);
  } catch (e, st) {
    // the next start sweeps again
    traceError('sweep', e, st);
  }
}

/// the shared wipe's desktop steps, through [host]: the keys first,
/// before a file is touched, then the databases let go of theirs
void wipeThrough(DesktopHost host) {
  desktopWipeKeys = () async {
    try {
      host.destroyKeys?.call();
    } catch (_) {}
    try {
      await host.forgetKeys?.call().timeout(const Duration(seconds: 5));
    } catch (_) {}
  };
  desktopLetGo = () async {
    try {
      await host.letGo?.call().timeout(const Duration(seconds: 3));
    } catch (_) {}
  };
}

/// kryfo no longer starts with the computer, for the wipe. the portal is
/// asked only when its grant was not known to be off: a request can show
/// the desktop's own question
Future<void> startOffHere() async {
  final place = startPlaceHere(read: (_) => null, write: (_, _) async {});
  if (place == null) return;
  if (place is PortalStart && desktopRun?.start == StartAnswer.off) return;
  await place.set(false);
}

/// held so the listener lives as long as the app
@visibleForTesting
AppLifecycleListener? closeOnDetach;

/// secrets and prefs reach the vault and nothing else
void assertVaultOnly() {
  if (FlutterSecureStoragePlatform.instance is! VaultStorage ||
      SharedPreferencesStorePlatform.instance is! VaultPrefs) {
    throw StateError('desktop storage is not the vault');
  }
}
