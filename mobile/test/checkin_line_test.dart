// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';

void main() {
  test('the last check-in is worded when shown', () {
    final ok = jsonEncode({'how': 'ok_norelay', 'secs': 48, 'why': 'push'});
    expect(checkInLine(ok), 'ok, no relay began, 48s, by push');
    expect(checkInOk(ok), isTrue);
    final bad = jsonEncode({'how': 'notready', 'secs': 76, 'why': 'job'});
    expect(checkInLine(bad), 'tor not ready in 75s, 76s, by job');
    expect(checkInOk(bad), isFalse);
  });

  test('a line an older build saved is shown as it is', () {
    expect(checkInLine('ok, 31s, by job'), 'ok, 31s, by job');
    expect(checkInOk('ok, 31s, by job'), isTrue);
    expect(catchupLine('relay.kryfo.app 2.1s'), 'relay.kryfo.app 2.1s');
    expect(catchupDropped('x 30.0s dropped'), isTrue);
  });

  test('the catch-up line, fast, slow and dropped', () {
    final stored = jsonEncode([
      {'host': 'a.example', 'ms': 2100, 'long': false, 'dropped': false},
      {
        'host': 'b.example',
        'ms': 30000,
        'long': true,
        'dropped': true,
        'connect_ms': 4200,
        'pages': 3,
        'events': 120,
        'subs': 12,
        'held': 2,
      },
      {
        'host': 'c.example',
        'ms': 6400,
        'dropped': false,
        'connect_ms': 900,
        'pages': 1,
        'events': 4,
        'subs': 1,
      },
    ]);
    expect(
      catchupLine(stored),
      'a.example 2.1s · '
      'b.example 30.0s dropped long window (2 of 12, connect 4.2s, 3 pages, 120 events) · '
      'c.example 6.4s (connect 0.9s, 1 page, 4 events)',
    );
    expect(catchupDropped(stored), isTrue);
  });
}
