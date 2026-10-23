// SPDX-License-Identifier: GPL-3.0-or-later
// the icon and name the phone's home screen shows for kryfo: its own, or
// a plain one. android keeps which (AppIcon.kt, one launcher entry each),
// so this side only asks and tells; nothing about it is saved here
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'container.dart';
import 'dlog.dart';
import 'l10n/l10n.dart';

enum AppFace { kryfo, notes, weather, tasks, news }

extension AppFaceWords on AppFace {
  /// the launcher's name for it, in the app's language. the plain ones are
  /// android's own words too (values*/strings.xml), so both always agree
  String get label => switch (this) {
    AppFace.kryfo => 'Kryfo',
    AppFace.notes => l10n.androidIconNotes,
    AppFace.weather => l10n.androidIconWeather,
    AppFace.tasks => l10n.androidIconTasks,
    AppFace.news => l10n.androidIconNews,
  };

  /// the small icon a plain notification wears
  String get glyph => this == AppFace.kryfo ? 'ic_plain_dot' : 'ic_plain_$name';
}

AppFace? faceNamed(String? name) {
  for (final f in AppFace.values) {
    if (f.name == name) return f;
  }
  return null;
}

/// what is asked of android, behind a seam for tests
abstract class AppFaceChannel {
  Future<AppFace?> read();

  /// switches, then the app closes and opens again. false when android
  /// would not take it, and nothing changed
  Future<bool> switchTo(AppFace face);
}

class PlatformFaceChannel implements AppFaceChannel {
  const PlatformFaceChannel();

  // on the process's own engine: a process with no screen asks it too
  static const _read = MethodChannel('kryfo/app_icon');
  static const _screen = MethodChannel('halo/platform');

  @override
  Future<AppFace?> read() async {
    try {
      return faceNamed(await _read.invokeMethod<String>('get'));
    } catch (e) {
      dlog('app icon: not read (${e.runtimeType})');
      return null;
    }
  }

  @override
  Future<bool> switchTo(AppFace face) async {
    try {
      return await _screen.invokeMethod<bool>('appIconSet', {
            'icon': face.name,
          }) ??
          false;
    } catch (e) {
      dlog('app icon: not switched (${e.runtimeType})');
      return false;
    }
  }
}

AppFaceChannel appFaceChannel = const PlatformFaceChannel();

/// the icon in use as last read, null until then. android is asked once a
/// process: a switch ends the process it was made in
final appFaceNow = ValueNotifier<AppFace?>(null);

Future<AppFace> readAppFace() async {
  final known = appFaceNow.value;
  if (known != null) return known;
  final f = await appFaceChannel.read() ?? AppFace.kryfo;
  appFaceNow.value = f;
  return f;
}

@visibleForTesting
void forgetAppFace() => appFaceNow.value = null;

// set just before a switch and read once after it, for the line that says
// it worked. the phone's, like the icon
const _changedKey = 'icon_changed';

Future<void> noteFaceChanged() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(HaloContainer.everyday.key(_changedKey), true);
}

/// true once after a switch: the flag goes as it is read
Future<bool> takeFaceChanged() async {
  final prefs = await SharedPreferences.getInstance();
  final k = HaloContainer.everyday.key(_changedKey);
  if (prefs.getBool(k) != true) return false;
  await prefs.remove(k);
  return true;
}
