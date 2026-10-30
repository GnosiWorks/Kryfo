// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop app's start: the platform answers, private folders, the
// network watch and notifications put in place, then the vault opened by the
// computer's key or its passphrase, and only then the app itself
import 'dart:async';
import 'dart:io';

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
import 'desktop_platform.dart';
import 'desktop_run.dart';
import 'desktop_posix.dart';
import 'desktop_prefs.dart';
import 'desktop_vault.dart';
import 'keyring_linux.dart';
import 'sealed_format.dart' show EngineChunkCrypto;
import 'sealed_io.dart';
import 'sealed_native.dart' show nativeFilesSealed;
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

/// notifications on desktop say only that something came. gnome and kde keep
/// a history of them on disk, and the phone's choice of what to show does
/// not reach that far
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
  }) => post(
    id: id,
    title: 'Kryfo',
    body: l10n.notificationsNewMessage,
    payload: payload,
  );

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
    notificationDetails: const LinuxNotificationDetails(),
    payload: payload,
  );
}

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

Future<void> sayTrayWords() async {
  try {
    await _desktopChannel.invokeMethod<void>('tray', {
      'open': l10n.desktopLockOpen,
      'quit': l10n.desktopTrayQuit,
      'tip': l10n.desktopTrayTip,
    });
  } catch (_) {
    // a runner without a tray: closing the window ends the app
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
enum DesktopStop { alreadyOpen, notYours, notPrivate, noMemory }

/// the folder checks, in the order they are made: private, the user's own,
/// and no other process on it. a reopen's new process may find the old one
/// still letting go, so the lock is asked a few times
@visibleForTesting
Future<DesktopStop?> claimFolder(
  String root, {
  int Function() uid = getuid,
  Duration wait = const Duration(seconds: 3),
}) async {
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

Future<void> startDesktop(Future<void> Function() appMain) async {
  onDesktop = true;
  privateUmask();
  final root = desktopDataDir();
  final stop = await claimFolder(root);
  if (stop != null) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(DesktopStopApp(stop: stop));
    return;
  }
  final db = DesktopDb();
  final host = DesktopHost(dataDir: root);
  DesktopBinding.install(desktopAnswers(host, db));

  final runtime = desktopRuntimeDir(uid: getuid(), root: root);
  // without a folder in memory the engine's files and the temporary ones
  // would be plain on the disk while the app runs: linux refuses that.
  // windows has no tmpfs and keeps them in <root>/tmp (its own branch)
  if (runtime == null && !Platform.isWindows) {
    runApp(const DesktopStopApp(stop: DesktopStop.noMemory));
    return;
  }
  sweepOldRuntimeDirs(runtime, uid: getuid(), root: root);
  final paths = DesktopPaths(root, runtime: runtime);
  PathProviderPlatform.instance = paths;
  final vault = DesktopVault(p.join(root, 'vault.kv'));
  final seal = systemSeal();
  host.destroyKeys = vault.destroy;
  if (seal != null) host.forgetKeys = () => vault.forgetSystem(seal);
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
    return null;
  });
  // what memory held from a run before goes now, before anything is plain
  if (runtime != null) {
    final docs = (await paths.getApplicationDocumentsPath())!;
    EngineFiles(
      docs: docs,
      support: (await paths.getApplicationSupportPath())!,
      runtime: runtime,
    ).clearMemory();
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
        // vault opens, so closing the passphrase screen just quits
        final run = DesktopRun(
          tray: const ChannelTray(sayTrayWords),
          place: startPlaceHere(read: vault.read, write: vault.write),
          read: vault.read,
          write: vault.write,
        );
        desktopRun = run;
        unawaited(run.begin());
        unawaited(() async {
          await openSeal(
            root: root,
            runtime: runtime,
            vault: vault,
            host: host,
            paths: paths,
          );
          await appMain();
        }());
      },
    ),
  );
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
  )..filesKey = await filesKeyFrom(vault);
  final io = SealedIO(areas, const EngineChunkCrypto());
  IOOverrides.global = io;
  isolateRunner = <R>(FutureOr<R> Function() f) => runSealed(f);
  nativeFiles =
      <T>(
        List<String> ins,
        List<String> outs,
        Future<T> Function(List<String>, List<String>) run,
        bool Function(T)? ok,
      ) => nativeFilesSealed(areas, ins, outs, run, ok);
  // a backup is encrypted already and may be large: on the disk
  bulkTempDir = () async {
    final d = p.join(root, 'tmp');
    makePrivateDir(d);
    return d;
  };

  for (final area in ['', '_k2', '_k3', '_k4', '*']) {
    if (vault.read(sweptEntry(area)) != null) areas.swept.add(area);
  }
  // an area's sweep done once: from then a plain file there is damage
  Future<void> sweep(String area, List<String> dirs) async {
    if (areas.swept.contains(area)) return;
    try {
      for (final d in dirs) {
        await runSealed(() => sealPlainUnder(d));
      }
      await vault.write(sweptEntry(area), '1');
      areas.swept.add(area);
    } catch (_) {
      // the next start sweeps again
    }
  }

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
    engineFiles?.destroy();
    keys.closeAll();
    vaultGone?.call();
  };
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
