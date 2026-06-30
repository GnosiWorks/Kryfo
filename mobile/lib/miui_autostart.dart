// SPDX-License-Identifier: GPL-3.0-or-later
// miui_autostart.dart - onboarding nag for xiaomi devices.
// miui kills background apps unless autostart is enabled per-app.
// no way to enable it programmatically, so we explain + open the right
// settings panel.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<void> openAutostartSettings() async {
  try {
    await _channel.invokeMethod('openAutostartSettings');
  } catch (_) {}
}

// non-xiaomi phones (samsung etc) kill background apps via battery
// optimization. ask android to exempt us so messages still land when
// halo is closed. miui keeps the autostart flow below.
Future<void> maybeShowBackgroundPrompt(BuildContext context) async {
  if (await isMiui()) {
    await maybeShowMiuiPrompt(context);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_battPrefKey) ?? false) return;
  if (await Permission.ignoreBatteryOptimizations.isGranted) {
    await prefs.setBool(_battPrefKey, true);
    return;
  }
  if (!context.mounted) return;
  await _showBatteryDialog(context);
  await prefs.setBool(_battPrefKey, true);
}

Future<void> _showBatteryDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: HaloColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: HaloColors.line2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'one more step',
              style: HaloType.mono(color: HaloColors.amber, size: 11),
            ),
            const SizedBox(height: 10),
            Text(
              'Let halo run in the background',
              style: HaloType.serif(size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              "Your phone pauses apps to save battery. Without an exception, "
              "halo can't receive messages while it's closed.",
              style: HaloType.sans(color: HaloColors.text2, height: 1.55),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: HaloColors.text2,
                  ),
                  child: const Text('skip'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await Permission.ignoreBatteryOptimizations.request();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HaloColors.amber,
                    foregroundColor: HaloColors.onAmber,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('allow'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> maybeShowMiuiPrompt(BuildContext context) async {
  if (!await isMiui()) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefKey) ?? false) return;
  if (!context.mounted) return;
  await _showDialog(context);
  await prefs.setBool(_prefKey, true);
}

Future<void> _showDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: HaloColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: HaloColors.line2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'one more step',
              style: HaloType.mono(color: HaloColors.amber, size: 11),
            ),
            const SizedBox(height: 10),
            Text(
              'Let halo run in the background',
              style: HaloType.serif(size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              'Xiaomi turns off background apps by default. Without autostart, halo can\'t deliver messages when the app is closed.',
              style: HaloType.sans(color: HaloColors.text2, height: 1.55),
            ),
            const SizedBox(height: 16),
            Text(
              'On the next screen: find halo in the list and tap the toggle on.',
              style: HaloType.sans(
                color: HaloColors.text3,
                height: 1.55,
                size: 12,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: HaloColors.text2,
                  ),
                  child: const Text('skip'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await openAutostartSettings();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HaloColors.amber,
                    foregroundColor: HaloColors.onAmber,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('open settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
