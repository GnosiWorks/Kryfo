// SPDX-License-Identifier: GPL-3.0-or-later
// the icon and name the phone's home screen shows for kryfo: its own, or
// a plain one. android keeps which (AppIcon.kt, one launcher entry each),
// so this side only asks and tells; nothing about it is saved here
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_icon_art.dart' show plainArt;
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

/// the app switcher's title: the name on the home screen, as the launcher
/// writes it. nothing while the icon is not known
String switcherTitle(AppFace? face, [String? launcherLabel]) {
  if (face == null) return '';
  if (face == AppFace.kryfo) return 'Kryfo';
  return launcherLabel ?? face.label;
}

/// the app switcher's colour: a plain icon's own, kryfo's accent once its
/// icon is known, a plain dark one before
Color? switcherColor(AppFace? face) {
  if (face == AppFace.kryfo) return null;
  final art = plainArt[face?.name];
  return Color(art?.background ?? 0xFF202124);
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

  // the name with the launcher's own label, in the phone's language
  @override
  Future<AppFace?> read() async {
    try {
      final r = await _read.invokeMethod<Object?>('get');
      if (r is Map) {
        final face = faceNamed(r['name'] as String?);
        final label = r['label'];
        if (face != null) appFaceLabel.value = label is String ? label : null;
        return face;
      }
      return faceNamed(r as String?);
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

/// the icon in use as android said it, null while it is not known: not
/// read yet, or a read that failed. a switch ends the process it was made
/// in, so one answer holds for the process
final appFaceNow = ValueNotifier<AppFace?>(null);

/// the launcher's label for a plain icon, in the phone's language, as
/// android said it with the icon
final appFaceLabel = ValueNotifier<String?>(null);

/// kryfo's own look only once android has said kryfo's icon is on. an
/// icon not known yet hides as a plain one does
bool get looksKryfo => appFaceNow.value == AppFace.kryfo;

/// the icon in use, read from android once known. null when the read
/// failed: nothing is kept, and the next read asks again
Future<AppFace?> readAppFace() async {
  final known = appFaceNow.value;
  if (known != null) return known;
  final f = await appFaceChannel.read();
  if (f != null) appFaceNow.value = f;
  return f;
}

@visibleForTesting
void forgetAppFace() {
  appFaceNow.value = null;
  appFaceLabel.value = null;
}

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
