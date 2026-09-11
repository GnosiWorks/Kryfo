// SPDX-License-Identifier: GPL-3.0-or-later
// miui_autostart.dart - onboarding nag for xiaomi devices.
// miui kills background apps unless autostart is enabled per-app.
// no way to enable it programmatically, so we explain + open the right
// settings panel. both asks sit on the house sheet like every other ask.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/confirm_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme.dart';

const _channel = MethodChannel('halo/platform');
const _prefKey = 'miui_autostart_prompt_seen';
const _battPrefKey = 'battery_opt_prompt_seen';

Future<bool> isMiui() async {
  try {
    return await _channel.invokeMethod<bool>('isMiui') ?? false;
  } catch (_) {
    return false;
  }
}

// true when a settings page opened. false means neither the miui page
// nor the app details page could be launched, and the caller says so
Future<bool> openAutostartSettings() async {
  try {
    return await _channel.invokeMethod<bool>('openAutostartSettings') ?? false;
  } catch (_) {
    return false;
  }
}

// non-xiaomi phones (samsung etc) kill background apps via battery
// optimization. ask android to exempt us so messages still land when
// kryfo is closed. miui keeps the autostart flow below.
Future<void> maybeShowBackgroundPrompt(BuildContext context) async {
  if (await isMiui()) {
    if (context.mounted) await maybeShowMiuiPrompt(context);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_battPrefKey) ?? false) return;
  if (await Permission.ignoreBatteryOptimizations.isGranted) {
    await prefs.setBool(_battPrefKey, true);
    return;
  }
  if (!context.mounted) return;
  await _askBattery(context);
  await prefs.setBool(_battPrefKey, true);
}

// force-show the background prompt on demand (settings row). ignores the
// seen-flag so it can be re-triggered any time, and re-checks grant state.
Future<void> forceShowBackgroundPrompt(BuildContext context) async {
  if (await isMiui()) {
    if (context.mounted) await _askAutostart(context);
    return;
  }
  if (await Permission.ignoreBatteryOptimizations.isGranted) {
    if (context.mounted) {
      showHaloToast(context, 'already allowed to run in the background');
    }
    return;
  }
  if (context.mounted) await _askBattery(context);
}

Future<void> _askBattery(BuildContext context) async {
  final ok = await showConfirmSheet(
    context,
    title: 'let kryfo run in the background',
    line:
        'your phone pauses apps to save battery. without an exception, '
        'kryfo cannot receive messages while it is closed.',
    yes: 'allow',
    keep: 'skip',
    rose: false,
  );
  if (ok) await Permission.ignoreBatteryOptimizations.request();
}

Future<void> maybeShowMiuiPrompt(BuildContext context) async {
  if (!await isMiui()) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefKey) ?? false) return;
  if (!context.mounted) return;
  await _askAutostart(context);
  await prefs.setBool(_prefKey, true);
}

Future<void> _askAutostart(BuildContext context) async {
  final ok = await showConfirmSheet(
    context,
    title: 'let kryfo run in the background',
    line:
        'xiaomi turns off background apps by default. without autostart, '
        'kryfo cannot deliver messages when the app is closed. on the next '
        'screen, find kryfo in the list and turn the toggle on.',
    yes: 'open settings',
    keep: 'skip',
    rose: false,
  );
  if (!ok) return;
  final opened = await openAutostartSettings();
  if (!opened && context.mounted) {
    showHaloToast(
      context,
      "couldn't open it. look for autostart in phone settings",
    );
  }
}
