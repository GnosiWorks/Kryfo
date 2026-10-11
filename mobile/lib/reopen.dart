// SPDX-License-Identifier: GPL-3.0-or-later
// closing the app's process and opening it again. a call stuck in a plugin's
// thread holds every call after it, and a retry in the same process only
// waits behind it
import 'package:flutter/services.dart';
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

// the process ends with nothing on screen, and the always-on service brings
// it back as after any kill. false when android would not: no service up,
// the app in front, or one too recent
Future<bool> restartQuietly() async {
  try {
    return await _restart.invokeMethod<bool>('quiet') ?? false;
  } catch (e) {
    dlog('restart: ${e.runtimeType}');
    return false;
  }
}
