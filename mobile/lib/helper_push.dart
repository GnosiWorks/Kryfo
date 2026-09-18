// SPDX-License-Identifier: GPL-3.0-or-later
// the helper app mode: unifiedpush, spoken directly to the distributor.
//
// a helper (ntfy is the usual one) keeps one light connection for every app
// on the phone and wakes each when something arrives. kryfo's wake-up
// carries nothing: the helper's server is told an endpoint to knock and
// never what the knock is about. on a knock kryfo fetches over tor, the
// same check-in the fifteen-minute job runs.
//
// what the helper's server can learn is the timing: that this endpoint was
// knocked, and when. that is the whole cost of the mode and it is said on
// the screen. the relay sends decoy knocks so the timing is not the truth.
//
// none of this works until the relay can knock. that change is its own diff
// (~/kryfo-notes/delivery/relay-knock.diff) and its own deploy, so the mode
// stays out of the picker until then: a dead option in a settings screen is
// what we just finished removing.
//
// kryfo listens on a pairwise address per contact, so the shape of the
// registration is the whole privacy question. it is sixteen endpoints, always
// sixteen, whatever the contact count: see helper_slots.dart. the empty ones
// are registered with a random address nothing is ever sent to, so the helper
// sees the same sixteen topics on every phone and the relay cannot tell a
// dummy from a real one. below sixteen contacts no two real addresses share an
// endpoint, so the relay links nothing.
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
        // the rest still go: a distributor that refuses one is not a reason
        // to leave the other fifteen unregistered
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
