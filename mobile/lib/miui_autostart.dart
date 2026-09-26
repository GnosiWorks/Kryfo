// SPDX-License-Identifier: GPL-3.0-or-later
// miui kills background apps unless autostart is on for them, and no api
// turns it on, so we explain and open the settings page.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/confirm_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme.dart';
import 'l10n/l10n.dart';

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

// battery optimization kills background apps, so ask android to exempt us
// and messages still land while kryfo is closed
Future<void> maybeShowBackgroundPrompt(BuildContext context) async {
  // xiaomi needs both: autostart so the system may bring kryfo back, and
  // the battery exemption so it may stay awake once it is back
  if (await isMiui()) {
    if (context.mounted) await maybeShowMiuiPrompt(context);
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

// for the settings row: ignores the seen flags and checks the grant again
Future<void> forceShowBackgroundPrompt(BuildContext context) async {
  if (await isMiui()) {
    if (context.mounted) await _askAutostart(context);
    if (!context.mounted) return;
  }
  if (await Permission.ignoreBatteryOptimizations.isGranted) {
    if (context.mounted) {
      showHaloToast(context, l10n.miuiAutostartAlreadyAllowedToRun);
    }
    return;
  }
  if (context.mounted) await _askBattery(context);
}

Future<void> _askBattery(BuildContext context) async {
  final ok = await showConfirmSheet(
    context,
    title: l10n.miuiAutostartLetKryfoRunIn,
    line: l10n.miuiAutostartYourPhonePausesApps,
    yes: l10n.commonAllow,
    keep: l10n.commonSkip,
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
    title: l10n.miuiAutostartLetKryfoRunIn,
    line: l10n.miuiAutostartXiaomiTurnsOffBackground,
    yes: l10n.miuiAutostartOpenSettings,
    keep: l10n.commonSkip,
    rose: false,
  );
  if (!ok) return;
  final opened = await openAutostartSettings();
  if (!opened && context.mounted) {
    showHaloToast(context, l10n.miuiAutostartCouldnTOpenIt);
  }
}
