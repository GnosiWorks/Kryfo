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
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
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
import 'desktop_vault.dart';

/// the binding whose messenger answers the android channels
class DesktopBinding extends WidgetsFlutterBinding {
  // the field is set before the base constructor asks for the messenger
  DesktopBinding._(this._answers);

  static DesktopBinding ensure(Map<String, DesktopAnswer> answers) {
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

Future<void> startDesktop(Future<void> Function() appMain) async {
  onDesktop = true;
  privateUmask();
  final root = desktopDataDir();
  makePrivateDir(root);
  final db = DesktopDb();
  final host = DesktopHost(dataDir: root);
  DesktopBinding.ensure(desktopAnswers(host, db));

  final paths = DesktopPaths(root);
  PathProviderPlatform.instance = paths;
  final support = (await paths.getApplicationSupportPath())!;
  if (defaultTargetPlatform == TargetPlatform.linux) {
    final prefs = SharedPreferencesStorePlatform.instance;
    // the plugin's own seam for where its file goes, marked for tests
    if (prefs is SharedPreferencesLinux) {
      // ignore: invalid_use_of_visible_for_testing_member
      prefs.pathProvider = _PrefsPlace(support);
    }
    final async = SharedPreferencesAsyncPlatform.instance;
    if (async is SharedPreferencesAsyncLinux) {
      // ignore: invalid_use_of_visible_for_testing_member
      async.pathProvider = _PrefsPlace(support);
    }
    ConnectivityPlatform.instance = DesktopConnectivity();
    FlutterLocalNotificationsPlatform.instance = QuietLinuxNotifications();
    JustAudioPlatform.instance = DesktopAudio();
  }

  CameraPlatform.instance = NoCameras();
  final vault = DesktopVault(p.join(root, 'vault.kv'));
  FlutterSecureStoragePlatform.instance = VaultStorage(vault);

  await loadAppLocale();
  unawaited(sayTrayWords());
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
