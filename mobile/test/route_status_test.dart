// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/motion.dart';

// the status line carries whether a relay connected through the current route
// and the route generation. an older engine without them still reads.
void main() {
  test('reads route verdict and generation', () {
    expect(parseRouteOK('publishing|100|3|1|7'), isTrue);
    expect(parseRouteOK('publishing|100|3|0|7'), isFalse);
    expect(parseRouteGen('publishing|100|3|0|7'), 7);
    expect(parseTorStatus('publishing|100|3|0|7'), TorStatus.publishing);
    expect(parseBootstrapPct('starting|42|0|0|2'), 42);
  });

  test('missing fields read as a working route', () {
    expect(parseRouteOK('reachable|100|4'), isTrue);
    expect(parseRouteGen('reachable|100|4'), 0);
  });

  test('tor ready does not mean route working', () {
    // the flight-mode case: tor publishing, no relay connecting
    const raw = 'publishing|100|0|0|3';
    expect(parseTorStatus(raw), TorStatus.publishing);
    expect(parseRouteOK(raw), isFalse);
  });
}
