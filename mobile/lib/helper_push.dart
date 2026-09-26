// SPDX-License-Identifier: GPL-3.0-or-later
// the helper app mode: unifiedpush, spoken directly to the distributor.
// the knock carries nothing; on a knock kryfo checks in over tor. the
// helper's server learns only the timing, and the relay sends decoy knocks.
// always sixteen endpoints, see helper_slots.dart. the mode stays out of the
// picker until the relay can knock.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dlog.dart';
import 'helper_slots.dart';

const kHelperModeReady = false;

// slot -> endpoint, as json
const kHelperEndpointsKey = 'helper_endpoints';
// address -> slot, as json
const kHelperSlotsKey = 'helper_slots';
// a knock is free to send and costs us a tor fetch, so one app that knocks
// in a loop cannot be allowed to run the battery down
const kKnockFloorMs = 60 * 1000;

class HelperApp {
  final String package;
  final String name;
  const HelperApp(this.package, this.name);
}

class HelperPush {
  HelperPush._(this._ch);
  static final HelperPush instance = HelperPush._(
    const MethodChannel('halo/helper'),
  );
  final MethodChannel _ch;

  /// called when a knock arrives, after the rate limit
  void Function()? onKnock;

  /// called with an endpoint the distributor handed out, to be registered
  /// with the relay
  Future<void> Function(String endpoint)? onEndpoint;

  int _lastKnock = 0;

  void listen() {
    _ch.setMethodCallHandler((call) async {
      final a = call.arguments;
      final args = a is Map ? a : const {};
      switch (call.method) {
        case 'knock':
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastKnock < kKnockFloorMs) {
            dlog('helper: knock ignored, too soon after the last');
            return null;
          }
          _lastKnock = now;
          onKnock?.call();
        case 'endpoint':
          final e = args['endpoint'];
          final who = args['instance'];
          if (e is! String || !e.startsWith('https://')) return null;
          if (who is! String || !who.startsWith('kryfo-')) return null;
          final slot = int.tryParse(who.substring(6));
          if (slot == null || slot < 0 || slot >= kHelperSlots) return null;
          final prefs = await SharedPreferences.getInstance();
          final all = Map<String, dynamic>.from(
            jsonDecode(prefs.getString(kHelperEndpointsKey) ?? '{}') as Map,
          )..['$slot'] = e;
          await prefs.setString(kHelperEndpointsKey, jsonEncode(all));
          await onEndpoint?.call(e);
        case 'unregistered':
          dlog('helper: the helper app dropped a registration');
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(kHelperEndpointsKey);
        case 'failed':
          dlog('helper: registration refused: ${args['reason']}');
      }
      return null;
    });
  }

  Future<List<HelperApp>> apps() async {
    try {
      final raw = await _ch.invokeMethod<List<Object?>>('helperApps');
      return [
        for (final r in raw ?? const [])
          if (r is Map && r['package'] is String)
            HelperApp(r['package'] as String, (r['name'] as String?) ?? ''),
      ];
    } on PlatformException {
      return const [];
    }
  }

  Future<String?> chosen() async {
    try {
      return await _ch.invokeMethod<String>('helperChosen');
    } on PlatformException {
      return null;
    }
  }

  /// registers all sixteen slots with [package]. the distributor answers each
  /// one separately, and every answer lands in onEndpoint.
  Future<int> registerAll(String package) async {
    var ok = 0;
    for (var i = 0; i < kHelperSlots; i++) {
      try {
        final done = await _ch.invokeMethod<bool>('helperRegister', {
          'package': package,
          'instance': slotInstance(i),
        });
        if (done == true) ok++;
      } on PlatformException {
        // one refusal does not stop the rest
      }
    }
    return ok;
  }

  Future<void> unregister() async {
    try {
      await _ch.invokeMethod('helperUnregister');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kHelperEndpointsKey);
    } on PlatformException {
      return;
    }
  }

  /// slot -> endpoint, for the slots the distributor has answered for
  Future<Map<int, String>> endpoints() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(prefs.getString(kHelperEndpointsKey) ?? '{}');
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (int.tryParse('${e.key}') != null && e.value is String)
            int.parse('${e.key}'): e.value as String,
      };
    } catch (_) {
      return {};
    }
  }
}
