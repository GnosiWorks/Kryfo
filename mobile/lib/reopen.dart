// SPDX-License-Identifier: GPL-3.0-or-later
// closing the app's process and opening it again. a call stuck in a plugin's
// thread holds every call after it, and a retry in the same process only
// waits behind it
import 'package:flutter/services.dart';
import 'dlog.dart';

const _channel = MethodChannel('halo/platform');

// android starts the first screen again in a new process and ends this one
Future<void> reopenApp() async {
  try {
    await _channel.invokeMethod<void>('reopen');
  } catch (e) {
    dlog('reopen: ${e.runtimeType}');
  }
}
