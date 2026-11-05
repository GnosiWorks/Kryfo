// SPDX-License-Identifier: GPL-3.0-or-later
// the linked devices' clocks read the relays at each tick, in whatever
// mode: a relay that answers moves the time, none leaves it where it was,
// so a tick after it counts nothing
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/own_unlink.dart' show relayContactSince;
import 'package:kryfo/main.dart'
    show AppStateRoute, HaloEngine, appState, useEngineForTest;

class _Engine implements HaloEngine {
  List<Map<String, dynamic>> relays = const [];
  @override
  Map<String, dynamic> transportState() => {'relays': relays};
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a tick reads the relays itself, in private mode too', () {
    final e = _Engine();
    useEngineForTest(e);
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000000);
    final t1 = t0.add(const Duration(minutes: 5));
    appState.sampleRelayUp(now: t0);
    expect(appState.relayUpAt, isNull);
    e.relays = [
      {'url': 'wss://a', 'up': false},
    ];
    appState.sampleRelayUp(now: t0);
    expect(appState.relayUpAt, isNull);
    e.relays = [
      {'url': 'wss://a', 'up': false},
      {'url': 'wss://b', 'up': true},
    ];
    appState.sampleRelayUp(now: t0);
    expect(appState.relayUpAt, t0.millisecondsSinceEpoch);
    // the next tick, still answering: it counts
    appState.sampleRelayUp(now: t1);
    expect(
      relayContactSince(appState.relayUpAt, t0.millisecondsSinceEpoch),
      isTrue,
    );
    // none answers since: the time stays, the tick after counts nothing
    e.relays = const [];
    appState.sampleRelayUp(now: t1.add(const Duration(minutes: 5)));
    expect(appState.relayUpAt, t1.millisecondsSinceEpoch);
    expect(
      relayContactSince(
        appState.relayUpAt,
        t1.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      ),
      isFalse,
    );
  });
}
