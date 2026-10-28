// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop app's start: the platform answers, private folders, the
// network watch and notifications put in place, then the vault's passphrase,
// and only then the app itself
import 'dart:async';

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
import 'desktop_channels.dart';
import 'desktop_db.dart';
import 'desktop_lock_screen.dart';
import 'desktop_mode.dart';
import 'desktop_net.dart';
import 'desktop_paths.dart';
import 'desktop_platform.dart';
import 'desktop_posix.dart';
import 'desktop_prefs.dart';
import 'desktop_vault.dart';

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

/// why the desktop will not start, before anything of it runs
enum DesktopStop { alreadyOpen, notYours, notPrivate }

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

  final paths = DesktopPaths(root);
  PathProviderPlatform.instance = paths;
  final vault = DesktopVault(p.join(root, 'vault.kv'));
  host.destroyKeys = vault.destroy;
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
  unawaited(sayTrayWords());
  // the key goes from memory as the engine lets the app go
  closeOnDetach = AppLifecycleListener(onDetach: vault.close);
  var started = false;
  runApp(
    DesktopLockApp(
      vault: vault,
      onOpen: () {
        if (started) return;
        started = true;
        unawaited(appMain());
      },
    ),
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
