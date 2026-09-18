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
// AND ONE THING IS NOT DECIDED. kryfo does not listen on one address, it
// listens on a pairwise address per contact. so either
//   - one endpoint per address: the helper's server sees one topic per
//     contact, so it learns roughly how many people write to you, or
//   - one endpoint for all of them: the relay is told which addresses share
//     an endpoint, and can tie your pairwise addresses to each other, which
//     today it cannot.
// that is a trade nobody should make quietly, so onEndpoint below is a seam
// with nothing behind it and the endpoint is only kept on the phone.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dlog.dart';

const kHelperModeReady = false;

const kHelperInstance = 'main';
const kHelperEndpointKey = 'helper_endpoint';
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
          if (e is! String || !e.startsWith('https://')) return null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(kHelperEndpointKey, e);
          await onEndpoint?.call(e);
        case 'unregistered':
          dlog('helper: the helper app dropped our registration');
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(kHelperEndpointKey);
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

  Future<bool> register(String package) async {
    try {
      return await _ch.invokeMethod<bool>('helperRegister', {
            'package': package,
            'instance': kHelperInstance,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> unregister() async {
    try {
      await _ch.invokeMethod('helperUnregister');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kHelperEndpointKey);
    } on PlatformException {
      return;
    }
  }

  Future<String?> endpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kHelperEndpointKey);
  }
}
