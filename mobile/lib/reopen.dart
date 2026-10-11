// SPDX-License-Identifier: GPL-3.0-or-later
// closing the app's process and opening it again. a call stuck in a plugin's
// thread holds every call after it, and a retry in the same process only
// waits behind it
import 'package:flutter/services.dart';
import 'auto_restart.dart' show BootTime;
import 'dlog.dart';

const _channel = MethodChannel('halo/platform');

// android starts the first screen again in a new process and ends this one
// false when android would not take it, and this process stays
Future<bool> reopenApp() async {
  try {
    await _channel.invokeMethod<void>('reopen');
    return true;
  } catch (e) {
    dlog('reopen: ${e.runtimeType}');
    return false;
  }
}

const _restart = MethodChannel('halo/restart');

// the process's own channel: a process the service started has no screen,
// and the screen's channel is not there

/// the clock since boot and which boot this is, null when unread
Future<BootTime?> bootTime() async {
  try {
    final r = await _restart.invokeListMethod<int>('clock');
    if (r == null || r.length != 2 || r[0] <= 0) return null;
    return BootTime(r[0], r[1]);
  } catch (e) {
    dlog('restart clock: ${e.runtimeType}');
    return null;
  }
}

/// whether android lets the process end with nothing on screen: the
/// service up, the app out of sight and free to start it again, the last
/// one long enough ago. a yes is written down there at once
Future<bool> armQuietRestart() => _ask('arm');

/// the process ends, after a last look that nothing came on screen
Future<bool> endQuietly() => _ask('end');

Future<bool> _ask(String what) async {
  try {
    return await _restart.invokeMethod<bool>(what) ?? false;
  } catch (e) {
    dlog('restart $what: ${e.runtimeType}');
    return false;
  }
}
