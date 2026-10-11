// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';

// android's word on the default network: whether there is one, its type,
// whether android validated it, a captive portal, a vpn. each change goes
// to the engine as the json android sent
const _net = MethodChannel('kryfo/net');

Future<void> listenNetDetail(void Function(String json) onDetail) async {
  try {
    _net.setMethodCallHandler((call) async {
      final a = call.arguments;
      if (call.method == 'net' && a is String) onDetail(a);
      return null;
    });
    final s = await _net.invokeMethod<String>('state');
    if (s != null) onDetail(s);
  } catch (_) {
    // no android side: the engine keeps the plain online signal
  }
}
