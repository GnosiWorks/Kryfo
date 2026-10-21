// SPDX-License-Identifier: GPL-3.0-or-later
// xiaomi, huawei and a few other makers kill background apps unless a
// switch of their own is on for them, and no api turns it on, so we explain
// and open the settings page (battery_brand.dart says which).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'battery_brand.dart';
import 'widgets/confirm_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme.dart';
import 'l10n/l10n.dart';

const _channel = MethodChannel('halo/platform');
// named for xiaomi, the first, and kept: who saw it there is not asked again
const _prefKey = 'miui_autostart_prompt_seen';
const _battPrefKey = 'battery_opt_prompt_seen';

Future<PhoneBrand> phoneBrand() async {
  try {
    final m = await _channel.invokeMapMethod<String, String>('phoneMaker');
    return brandOf(m?['manufacturer'] ?? '', m?['brand'] ?? '');
  } catch (_) {
    return PhoneBrand.other;
  }
}

// true when a settings page opened. false means neither the maker's page
// nor the app details page could be launched, and the caller says so.
// [brand] lets the phone start from the page closest to the guide's steps
Future<bool> openAutostartSettings([PhoneBrand? brand]) async {
  try {
    return await _channel.invokeMethod<bool>('openAutostartSettings', {
          'brand': brand?.name,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

// battery optimization kills background apps, so ask android to exempt us
// and messages still land while kryfo is closed
Future<void> maybeShowBackgroundPrompt(BuildContext context) async {
  // these makers need both: their own switch so the system may bring kryfo
  // back, and the battery exemption so it may stay awake once it is back
  final brand = await phoneBrand();
  final guide = brandGuide(brand);
  if (guide != null && context.mounted) {
    await _maybeAskBrand(context, brand, guide);
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
  final brand = await phoneBrand();
  final guide = brandGuide(brand);
  if (guide != null) {
    if (context.mounted) await _askBrand(context, brand, guide);
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

Future<void> _maybeAskBrand(
  BuildContext context,
  PhoneBrand brand,
  BrandGuide guide,
) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefKey) ?? false) return;
  if (!context.mounted) return;
  await _askBrand(context, brand, guide);
  await prefs.setBool(_prefKey, true);
}

Future<void> _askBrand(
  BuildContext context,
  PhoneBrand brand,
  BrandGuide guide,
) async {
  final ok = await showConfirmSheet(
    context,
    title: guide.title,
    line: guide.line,
    steps: guide.steps,
    detail: guide.after,
    yes: l10n.miuiAutostartOpenSettings,
    keep: l10n.commonSkip,
    rose: false,
  );
  if (!ok) return;
  final opened = await openAutostartSettings(brand);
  if (!opened && context.mounted) {
    showHaloToast(context, l10n.miuiAutostartCouldnTOpenIt);
  }
}
