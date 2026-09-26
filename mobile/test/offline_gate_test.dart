// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/offline_gate.dart';

void main() {
  final t0 = DateTime(2026, 9, 19, 0, 50);

  Duration? gate({
    DeliveryMode mode = DeliveryMode.always,
    bool torHeld = false,
    bool torReady = false,
    DateTime? tryingSince,
    Duration since = const Duration(minutes: 10),
  }) => offlineDurationFor(
    mode: mode,
    torHeld: torHeld,
    torReady: torReady,
    tryingSince: tryingSince ?? t0,
    now: t0.add(since),
  );

  test('always on without tor for hours is offline', () {
    final d = gate(since: const Duration(hours: 10, minutes: 36));
    expect(d, isNotNull);
    expect(d!.inHours, 10);
  });

  test('a working tor is never offline', () {
    expect(gate(torReady: true, since: const Duration(hours: 10)), isNull);
  });

  test('check-ins mode is never offline', () {
    expect(gate(mode: DeliveryMode.checkins), isNull);
    expect(
      gate(mode: DeliveryMode.checkins, since: const Duration(hours: 10)),
      isNull,
    );
  });

  test('tor held by the app is not offline', () {
    expect(gate(torHeld: true), isNull);
  });

  test('nothing to measure before the first try', () {
    expect(
      offlineDurationFor(
        mode: DeliveryMode.always,
        torHeld: false,
        torReady: false,
        tryingSince: null,
        now: t0,
      ),
      isNull,
    );
  });

  test('a future start reads as zero', () {
    final d = offlineDurationFor(
      mode: DeliveryMode.always,
      torHeld: false,
      torReady: false,
      tryingSince: t0.add(const Duration(minutes: 5)),
      now: t0,
    );
    expect(d, Duration.zero);
  });

  group('the five minute line', () {
    const line = Duration(minutes: 5);
    test('four minutes stays quiet', () {
      expect(gate(since: const Duration(minutes: 4))! < line, isTrue);
    });
    test('five minutes shows the line', () {
      expect(gate(since: const Duration(minutes: 5))! >= line, isTrue);
    });
    test('just under five stays quiet', () {
      expect(
        gate(since: const Duration(minutes: 4, seconds: 59))! >= line,
        isFalse,
      );
    });
  });
}
