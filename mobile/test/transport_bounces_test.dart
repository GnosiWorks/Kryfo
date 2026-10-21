// SPDX-License-Identifier: GPL-3.0-or-later
// the transport screen reads the engine's latest bounces: how many of each
// kind this process made, the most first, and the latest with their time
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/transport_screen.dart'
    show bounceNotes, bounceTotals;

void main() {
  test('totals, the most first, none for none', () {
    expect(bounceTotals({}), isNull);
    expect(bounceTotals({'bounce_counts': <String, dynamic>{}}), isNull);
    expect(
      bounceTotals({
        'bounce_counts': {'new circuits': 1, 'network change': 3},
      }),
      '4 · network change 3 · new circuits 1',
    );
  });

  test('the latest, as the engine lists them, odd rows left out', () {
    final got = bounceNotes({
      'bounces': [
        {'at': 1792570000, 'why': 'network change'},
        {'at': 'x', 'why': 'by hand'},
        {'at': 1792569000, 'why': 'new circuits'},
      ],
    });
    expect(got.map((b) => b.why), ['network change', 'new circuits']);
    expect(got.first.at, 1792570000);
    expect(bounceNotes({'bounces': null}), isEmpty);
  });

  test('the row has its words in every language', () {
    expect(l10n.transportReconnects, 'Reconnects');
  });
}
