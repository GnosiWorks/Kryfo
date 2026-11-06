// SPDX-License-Identifier: GPL-3.0-or-later
// what the desktop says on each android channel the app calls. the phone's
// list lives in MainActivity.kt, ToolsBridge.kt, HaloApplication.kt,
// NetWatch.kt, VideoPlayers.kt and HelperPush.kt; desktop_platform_test
// checks every method named there has a line here
import 'dart:async';
import 'dart:io';
import 'dart:io' as io show exit;

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../l10n/l10n.dart';

import 'desktop_channels.dart';
import 'desktop_db.dart';
import 'desktop_mode.dart' show kLinkNextEnv;
import 'desktop_posix.dart' show execSelf, setEnvHere;
import 'desktop_save.dart';
import 'desktop_wipe.dart';

/// flutter_secure_storage's channel to libsecret
const keyringChannel = 'plugins.it_nomads.com/flutter_secure_storage';

/// the android channels and what desktop answers on each
const androidChannels = [
  'halo/platform',
  'halo/tools',
  'halo/restart',
  'halo/helper',
  'halo/gpush',
  'kryfo/app_icon',
  'kryfo/net',
  'kryfo/phone',
  'kryfo/video',
  'kryfo/transfers',
];

/// methods with a desktop answer on halo/platform. the rest say not here:
/// the pin key, the finger, the launcher icon, android's settings pages,
/// video, sharing
const platformAnswered = {
  'askNotifications',
  'notificationsEnabled',
  'isBatteryExempt',
  'applyDeliveryMode',
  'photoPickerReady',
  'setSecure',
  'setRecentsHidden',
  'appIconSet',
  'openNotificationSettings',
  'openWifiSettings',
  'openAutostartSettings',
  'uptimeMs',
  'bootCount',
  'bootedAtMs',
  'processUptimeMs',
  'lastExit',
  'reopen',
  'wipe',
  'saveDocument',
  'saveDocumentState',
  'saveDocumentCancel',
  'saveToPictures',
  'openFile',
};

/// not here on desktop, each for a reason the caller already handles
const platformNotHere = {
  // no keystore and no finger: the vault's passphrase guards the keys
  'pinKeyInfo', 'pinKeyMake', 'pinKeyMac', 'pinKeyKcv', 'pinKeyDrop',
  'bioReady', 'bioState', 'bioSeal', 'bioDisable', 'bioUnlock',
  // phone makers and android's installer
  'isMiui', 'phoneMaker', 'installSource',
  // the plain clipboard is the caller's fallback
  'copySensitive', 'clearClip', 'clearOurClip',
  // the caller sends the photo as it is
  'shrinkJpeg',
  // no profile photo is added on desktop (photoAddOffered)
  'squareJpeg',
  // no share sheet, no android video reader
  'shareFile', 'videoInfo',
};

/// the same for halo/tools: nothing is shared into a desktop app. a pick
/// is the system's open dialog, and the file is read where it is
const toolsAnswered = {
  'takeShared',
  'takeSharedText',
  'seenSharedText',
  'dropSharedText',
  'freeBytes',
  'sweep',
  'saveToFiles',
  'saveToGallery',
  'pick',
  'copyIn',
  'cancelCopy',
};

/// no share sheet, nothing deleted from the person's folders, and the age
/// tools take paths on desktop (age_ffi.dart)
const toolsNotHere = {
  'shareOut',
  'deleteOriginal',
  'openForRead',
  'createDocument',
  'openCreated',
  'dropCreated',
  'openCacheOut',
  'sdk',
};

/// the open dialog, behind a seam for the tests: a path picked, or null
typedef PickOpen = Future<String?> Function(String kind);

const _pictureTypes = [
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'heif',
  'avif',
  'gif',
];
const _videoTypes = ['mp4', 'mov', 'm4v', '3gp'];

Future<String?> _openDialog(String kind) async {
  final groups = switch (kind) {
    'image' => [
      XTypeGroup(label: l10n.photoKnowsPhoto, extensions: _pictureTypes),
    ],
    'video' => [
      XTypeGroup(label: l10n.photoKnowsVideo, extensions: _videoTypes),
    ],
    _ => const <XTypeGroup>[],
  };
  return (await FileSelectorPlatform.instance.openFile(
    acceptedTypeGroups: groups,
  ))?.path;
}

/// a file of the person's as a tool takes it: its path is its uri, it is
/// read in place and never copied, and nothing deletes it
Map<String, Object?>? pickedAt(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  return {
    'uri': path,
    'name': p.basename(path),
    'size': f.lengthSync(),
    'inPlace': true,
  };
}

/// the clocks and the process, behind a seam for the tests
class DesktopHost {
  DesktopHost({
    required this.dataDir,
    this.exit = _exit,
    this.relaunch = _relaunch,
    this.relaunchLink = _relaunchLink,
    this.destroyKeys,
  });

  final String dataDir;
  final void Function(int) exit;
  final Future<void> Function() relaunch;

  /// a new run after a wipe for a link: it opens onboarding's link at once
  final Future<void> Function() relaunchLink;

  /// the vault overwritten before the folder goes
  void Function()? destroyKeys;

  /// what the computer account kept for the vault goes after it
  Future<void> Function()? forgetKeys;

  /// what holds a file open lets go of it: the databases
  Future<void> Function()? letGo;

  /// kryfo no longer starts with the computer: the run value, the
  /// autostart file, the portal's grant
  Future<void> Function()? startOff;

  /// the engine's folder zeroed and gone, once the engine let go of it
  void Function()? engineGone;

  /// what is kept and cleared as the process ends or becomes a new run
  void Function()? beforeExit;
  final _since = Stopwatch()..start();

  static void _exit(int code) => io.exit(code);
  // the same process becomes the new run, so a restart never ends with no
  // app. a new process is the fallback, and it waits for this one's lock
  static Future<void> _relaunch() async {
    // windows has no exec: the new kryfo.exe waits for this one's lock
    if (!Platform.isWindows) execSelf(Platform.resolvedExecutable);
    await Process.start(
      Platform.resolvedExecutable,
      Platform.isWindows ? const ['--reopen'] : const [],
      mode: ProcessStartMode.detached,
      // a link asked of an earlier run is never asked again
      environment: const {kLinkNextEnv: ''},
    );
  }
  // the same, with the link asked of the new run
  static Future<void> _relaunchLink() async {
    if (!Platform.isWindows) {
      setEnvHere(kLinkNextEnv, '1');
      execSelf(Platform.resolvedExecutable);
    }
    await Process.start(
      Platform.resolvedExecutable,
      Platform.isWindows ? const ['--reopen'] : const [],
      mode: ProcessStartMode.detached,
      environment: const {kLinkNextEnv: '1'},
    );
  }


  /// time since boot, suspend included, as android's elapsedRealtime
  int uptimeMs() {
    try {
      final s = File('/proc/uptime').readAsStringSync().split(' ').first;
      return (double.parse(s) * 1000).round();
    } catch (_) {
      return 0;
    }
  }

  int processUptimeMs() => _since.elapsedMilliseconds;

  /// free bytes where the app keeps its files, null when unread
  Future<int?> freeBytes() async {
    if (Platform.isWindows) return null;
    try {
      final r = await Process.run('df', ['-Pk', dataDir]);
      final last = '${r.stdout}'.trim().split('\n').last.split(RegExp(r'\s+'));
      return int.parse(last[3]) * 1024;
    } catch (_) {
      return null;
    }
  }

  /// the panic wipe's last step, as android's clear of the app's data: the
  /// vault is overwritten and what the account kept for it cleared, keys
  /// first, then the start with the computer goes, every file is let go of
  /// and every file goes, and the process ends. a file windows still holds
  /// goes at the next start (clearWithoutVault). [link]: a new run starts
  /// once every file is gone, at onboarding's link
  Future<void> wipe({bool link = false}) async {
    try {
      destroyKeys?.call();
    } catch (_) {}
    try {
      await forgetKeys?.call().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await startOff?.call().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await letGo?.call().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      engineGone?.call();
    } catch (_) {}
    try {
      await clearDataDir(dataDir);
    } catch (_) {}
    if (link) {
      // no run after it is still a clean start: onboarding
      try {
        await relaunchLink();
      } catch (_) {}
    }
    exit(0);
  }
}

Map<String, DesktopAnswer> desktopAnswers(
  DesktopHost host,
  DesktopDb db, {
  DesktopSave? save,
  PickOpen? open,
}) {
  final pickOpen = open ?? _openDialog;
  final saver = save ?? deskSaver;
  String arg(MethodCall c, String k) => '${(c.arguments as Map?)?[k] ?? ''}';
  Object? platform(MethodCall c) => switch (c.method) {
    'askNotifications' => null,
    'notificationsEnabled' => true,
    // no battery saver stops a desktop app, and nothing is handed off to a
    // service: the window's process is the app
    'isBatteryExempt' => true,
    'applyDeliveryMode' => true,
    'photoPickerReady' => false,
    // linux cannot keep a window out of screenshots
    'setSecure' => false,
    // no app switcher picture to keep out
    'setRecentsHidden' => false,
    'appIconSet' => false,
    'openNotificationSettings' ||
    'openWifiSettings' ||
    'openAutostartSettings' => false,
    'uptimeMs' => host.uptimeMs(),
    // no boot counter: unknown, as on a phone that does not say
    'bootCount' => -1,
    'bootedAtMs' => DateTime.now().millisecondsSinceEpoch - host.uptimeMs(),
    'processUptimeMs' => host.processUptimeMs(),
    'lastExit' => null,
    _ => notHere,
  };

  Future<Object?> platformAsync(MethodCall c) async {
    switch (c.method) {
      case 'reopen':
        host.beforeExit?.call();
        await host.relaunch();
        host.exit(0);
        return null;
      case 'wipe':
        await host.wipe(link: (c.arguments as Map?)?['link'] == true);
        return false;
      // the dialog and kryfo's own copy, in the phone's answer shapes
      case 'saveDocument':
        return saver.save(arg(c, 'path'), arg(c, 'name'));
      case 'saveDocumentState':
        return saver.state();
      case 'saveDocumentCancel':
        saver.cancel();
        return null;
      case 'saveToPictures':
        final b = (c.arguments as Map?)?['bytes'];
        if (b is! List<int>) return false;
        return await saver.saveBytes(b, arg(c, 'name')) == 'saved';
      // nothing outside opens a file kryfo holds: it goes to a save
      case 'openFile':
        return 'refused';
    }
    return platform(c);
  }

  Future<Object?> tools(MethodCall c) async => switch (c.method) {
    'takeShared' || 'takeSharedText' => null,
    'seenSharedText' || 'dropSharedText' || 'sweep' => null,
    'freeBytes' => await host.freeBytes() ?? -1,
    'saveToFiles' ||
    'saveToGallery' => await saver.saveAs(arg(c, 'path'), arg(c, 'name')),
    'pick' => switch (await pickOpen(arg(c, 'kind'))) {
      final String path => pickedAt(path),
      null => null,
    },
    // read where it is: the path is the file
    'copyIn' =>
      File(arg(c, 'uri')).existsSync()
          ? arg(c, 'uri')
          : throw PlatformException(code: 'read'),
    'cancelCopy' => null,
    _ => notHere,
  };

  Object? none(MethodCall _) => notHere;

  // libsecret hands a secret to any process of the user: the plugin's own
  // channel is shut, so nothing reaches it even past the vault
  Object? keyring(MethodCall _) => throw PlatformException(
    code: 'desktop',
    message: 'secrets live in the vault on desktop',
  );

  return {
    'halo/platform': platformAsync,
    'halo/tools': tools,
    for (final ch in androidChannels)
      if (ch != 'halo/platform' && ch != 'halo/tools') ch: none,
    sqlcipherChannel: (c) => db.call(c.method, c.arguments),
    keyringChannel: keyring,
  };
}
