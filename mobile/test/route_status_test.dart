// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/motion.dart';

// the status line grew two fields: whether a relay has actually connected
// through the current route, and the route generation. an engine from before
// them must still read as it always did.
void main() {
  test('new engine: route verdict and generation are read', () {
    expect(parseRouteOK('publishing|100|3|1|7'), isTrue);
    expect(parseRouteOK('publishing|100|3|0|7'), isFalse);
    expect(parseRouteGen('publishing|100|3|0|7'), 7);
    expect(parseTorStatus('publishing|100|3|0|7'), TorStatus.publishing);
    expect(parseBootstrapPct('starting|42|0|0|2'), 42);
  });

  test('old engine without the fields reads as a working route', () {
    expect(parseRouteOK('reachable|100|4'), isTrue);
    expect(parseRouteGen('reachable|100|4'), 0);
  });

  test('tor saying ready is not the same as the route working', () {
    // the flight-mode case: tor publishing, no relay connecting
    const raw = 'publishing|100|0|0|3';
    expect(parseTorStatus(raw), TorStatus.publishing);
    expect(parseRouteOK(raw), isFalse);
  });
}
