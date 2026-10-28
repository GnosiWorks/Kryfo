// SPDX-License-Identifier: GPL-3.0-or-later
// the network watch on linux. connectivity_plus asks networkmanager over
// d-bus, which many systems do not run and a flatpak may not reach; when it
// is not there its stream fails and the app would think itself offline.
// the kernel's route tables say the same on every system: a default route
// up is a network, its interface says which kind
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/foundation.dart';

const _rtfUp = 0x1;
const _rtfReject = 0x200;

/// the interfaces with a default route, from /proc/net/route and
/// /proc/net/ipv6_route as text
@visibleForTesting
Set<String> defaultRoutes(String v4, String v6) {
  final out = <String>{};
  for (final l in v4.split('\n').skip(1)) {
    final f = l.trim().split(RegExp(r'\s+'));
    if (f.length < 8) continue;
    final flags = int.tryParse(f[3], radix: 16) ?? 0;
    if (f[1] == '00000000' &&
        f[7] == '00000000' &&
        flags & _rtfUp != 0 &&
        flags & _rtfReject == 0) {
      out.add(f[0]);
    }
  }
  for (final l in v6.split('\n')) {
    final f = l.trim().split(RegExp(r'\s+'));
    if (f.length < 10) continue;
    final flags = int.tryParse(f[8], radix: 16) ?? 0;
    if (f[0] == '0' * 32 &&
        f[1] == '00' &&
        flags & _rtfUp != 0 &&
        flags & _rtfReject == 0) {
      out.add(f[9]);
    }
  }
  out.remove('lo');
  return out;
}

/// what kind of network an interface is
@visibleForTesting
ConnectivityResult kindOf(String iface, {String sys = '/sys/class/net'}) {
  if (Directory('$sys/$iface/wireless').existsSync()) {
    return ConnectivityResult.wifi;
  }
  if (RegExp(r'^(tun|tap|wg|ppp|tailscale|zt)').hasMatch(iface)) {
    return ConnectivityResult.vpn;
  }
  if (RegExp(r'^(wwan|wwp)').hasMatch(iface)) {
    return ConnectivityResult.mobile;
  }
  if (RegExp(r'^(en|eth|em)').hasMatch(iface)) {
    return ConnectivityResult.ethernet;
  }
  return ConnectivityResult.other;
}

class DesktopConnectivity extends ConnectivityPlatform {
  DesktopConnectivity({
    this.every = const Duration(seconds: 3),
    String Function(String path)? read,
    this.sys = '/sys/class/net',
  }) : _read = read ?? _readFile;

  final Duration every;
  final String Function(String) _read;
  final String sys;

  static String _readFile(String path) {
    try {
      return File(path).readAsStringSync();
    } catch (_) {
      return '';
    }
  }

  List<ConnectivityResult> now() {
    final up = defaultRoutes(
      _read('/proc/net/route'),
      _read('/proc/net/ipv6_route'),
    );
    if (up.isEmpty) return const [ConnectivityResult.none];
    final kinds = {for (final i in up) kindOf(i, sys: sys)}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return kinds;
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => now();

  // a change is said once, when the next look differs from the last
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    late StreamController<List<ConnectivityResult>> c;
    Timer? t;
    String? said;
    void look() {
      final n = now();
      final key = n.map((r) => r.name).join(',');
      if (key == said) return;
      said = key;
      c.add(n);
    }

    c = StreamController<List<ConnectivityResult>>(
      onListen: () {
        look();
        t = Timer.periodic(every, (_) => look());
      },
      onCancel: () => t?.cancel(),
    );
    return c.stream;
  }
}
