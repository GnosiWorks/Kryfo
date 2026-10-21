// SPDX-License-Identifier: GPL-3.0-or-later
// the transport screen reads the engine's latest bounces: how many of each
// kind this process made, the most first, and the latest with their time,
// each reason in the person's language
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/dates.dart' show hourMinute;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/transport_screen.dart'
    show bounceNotes, bounceTotals, bounceWhen, bounceWhy;

void main() {
  tearDown(() => setL10nLocale(const Locale('en')));

  test('totals, the most first, none for none', () {
    expect(bounceTotals({}), isNull);
    expect(bounceTotals({'bounce_counts': <String, dynamic>{}}), isNull);
    expect(
      bounceTotals({
        'bounce_counts': {'circuits': 1, 'network': 3},
      }),
      '4 · Network change 3 · New circuits 1',
    );
  });

  test('the latest, as the engine lists them, odd rows left out', () {
    final got = bounceNotes({
      'bounces': [
        {'at': 1792570000, 'why': 'network'},
        {'at': 'x', 'why': 'hand'},
        {'at': 1792569000, 'why': 'circuits'},
      ],
    });
    expect(got.map((b) => b.why), ['network', 'circuits']);
    expect(got.first.at, 1792570000);
    expect(bounceNotes({'bounces': null}), isEmpty);
  });

  test('every code has its words, in another language too', () {
    const codes = [
      'network',
      'hand',
      'relays',
      'stall',
      'tor_off',
      'dialer',
      'onion',
      'bridges',
      'auto',
      'offline',
      'circuits',
    ];
    final en = {for (final c in codes) bounceWhy(c)};
    expect(en, hasLength(codes.length));
    expect(en, isNot(contains(l10n.transportWhyOther)));
    expect(bounceWhy('something new'), l10n.transportWhyOther);
    setL10nLocale(const Locale('de'));
    expect(bounceWhy('network'), 'Netzwechsel');
    expect(l10n.transportReconnects, 'Neuverbindungen');
    expect(
      bounceTotals({
        'bounce_counts': {'network': 2},
      }),
      '2 · Netzwechsel 2',
    );
    for (final c in codes) {
      expect(en, isNot(contains(bounceWhy(c))), reason: c);
    }
  });

  test('a time from another day says the day', () {
    final now = DateTime(2026, 10, 21, 12);
    final today = DateTime(2026, 10, 21, 9, 5);
    final before = DateTime(2026, 10, 20, 9, 5);
    expect(bounceWhen(today, now: now), hourMinute(today));
    expect(bounceWhen(before, now: now), isNot(hourMinute(before)));
    expect(bounceWhen(before, now: now), contains(hourMinute(before)));
  });
}
