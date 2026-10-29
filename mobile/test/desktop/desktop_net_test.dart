// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop network watch reads the kernel's route tables
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_net.dart';
import 'package:path/path.dart' as p;

// as this machine's kernel wrote them: a default route on eth0, and the
// ipv6 table's unreachable default on lo
const _v4 =
    'Iface\tDestination\tGateway \tFlags\tRefCnt\tUse\tMetric\tMask\t\tMTU\tWindow\tIRTT\n'
    'eth0\t00000000\t018012AC\t0003\t0\t0\t0\t00000000\t0\t0\t0\n'
    'eth0\t008012AC\t00000000\t0001\t0\t0\t0\t00F0FFFF\t0\t0\t0\n';
const _v6 =
    'fe800000000000000000000000000000 40 00000000000000000000000000000000 00 00000000000000000000000000000000 00000100 00000001 00000000 00000001     eth0\n'
    '00000000000000000000000000000000 00 00000000000000000000000000000000 00 00000000000000000000000000000000 ffffffff 00000001 00000000 00200200       lo\n';
const _v6wifi =
    '00000000000000000000000000000000 00 00000000000000000000000000000000 00 fe800000000000000000000000000001 00000400 00000001 00000000 00000003   wlp2s0\n';

void main() {
  test('a default route up is a network, a rejecting one is not', () {
    expect(defaultRoutes(_v4, _v6), {'eth0'});
    expect(defaultRoutes(_v4.split('\n').first, _v6), isEmpty);
    expect(defaultRoutes('', _v6wifi), {'wlp2s0'});
  });

  test('this computer\'s own tables read without an error', () {
    String read(String f) {
      try {
        return File(f).readAsStringSync();
      } catch (_) {
        return '';
      }
    }

    final got = defaultRoutes(
      read('/proc/net/route'),
      read('/proc/net/ipv6_route'),
    );
    expect(got.contains('lo'), isFalse);
  });

  test('the interface says the kind', () {
    final sys = Directory.systemTemp.createTempSync('net');
    addTearDown(() => sys.deleteSync(recursive: true));
    Directory(
      p.join(sys.path, 'wlp2s0', 'wireless'),
    ).createSync(recursive: true);
    expect(kindOf('wlp2s0', sys: sys.path), ConnectivityResult.wifi);
    expect(kindOf('enp3s0', sys: sys.path), ConnectivityResult.ethernet);
    expect(kindOf('eth0', sys: sys.path), ConnectivityResult.ethernet);
    expect(kindOf('wg0', sys: sys.path), ConnectivityResult.vpn);
    expect(kindOf('tun0', sys: sys.path), ConnectivityResult.vpn);
    expect(kindOf('wwan0', sys: sys.path), ConnectivityResult.mobile);
    expect(kindOf('br-x', sys: sys.path), ConnectivityResult.other);
  });

  test('a change is said once, the same look again is not news', () async {
    var v4 = _v4;
    final c = DesktopConnectivity(
      every: const Duration(milliseconds: 10),
      read: (f) => f.endsWith('ipv6_route') ? '' : v4,
      sys: '/nonexistent',
    );
    expect(await c.checkConnectivity(), [ConnectivityResult.ethernet]);
    final seen = <List<ConnectivityResult>>[];
    final sub = c.onConnectivityChanged.listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    v4 = _v4.split('\n').first;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    v4 = _v4;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await sub.cancel();
    expect(seen, [
      [ConnectivityResult.ethernet],
      [ConnectivityResult.none],
      [ConnectivityResult.ethernet],
    ]);
  });
}
