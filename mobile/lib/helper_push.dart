// SPDX-License-Identifier: GPL-3.0-or-later
// the helper app mode's channel to android (HelperPush.kt): which helper
// apps are on the phone, and the sixteen registrations with the chosen one.
// a knock never comes this way: the receiver hands it to the job, which
// runs a check-in (HaloPeriodicJobService, KnockGate).
import 'package:flutter/services.dart';

import 'dlog.dart';

class HelperApp {
  final String package;
  final String name;
  const HelperApp(this.package, this.name);
}

class HelperPush {
  HelperPush(this._ch);
  static final HelperPush instance = HelperPush(
    const MethodChannel('halo/helper'),
  );
  final MethodChannel _ch;

  /// a registration got its endpoint, or lost it
  void Function()? onChange;

  void listen() {
    _ch.setMethodCallHandler((call) async {
      final a = call.arguments;
      final args = a is Map ? a : const {};
      switch (call.method) {
        case 'endpoint':
        case 'unregistered':
          onChange?.call();
        case 'failed':
          dlog('helper: a registration was refused: ${args['reason']}');
      }
      return null;
    });
  }

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } catch (e) {
      dlog('helper: $method (${e.runtimeType})');
      return null;
    }
  }

  Future<List<HelperApp>> apps() async {
    final raw = await _call<List<Object?>>('helperApps');
    return [
      for (final r in raw ?? const [])
        if (r is Map && r['package'] is String)
          HelperApp(r['package'] as String, (r['name'] as String?) ?? ''),
    ];
  }

  /// the package registered with last, if any
  Future<String?> chosen() => _call<String>('helperChosen');

  /// instance -> endpoint, for the registrations the phone holds
  Future<Map<String, String>> endpoints() async {
    final raw = await _call<Map<Object?, Object?>>('helperEndpoints');
    return {
      for (final e in (raw ?? const {}).entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
  }

  /// asks [package] for one registration per instance. the endpoints come
  /// back one by one, each in a broadcast of its own
  Future<int> register(String package, Iterable<String> instances) async {
    var ok = 0;
    for (final i in instances) {
      final done = await _call<bool>('helperRegister', {
        'package': package,
        'instance': i,
      });
      if (done == true) ok++;
    }
    return ok;
  }

  Future<void> unregisterOne(String instance) =>
      _call<bool>('helperUnregisterOne', {'instance': instance});

  Future<void> unregister() => _call<bool>('helperUnregister');
}
