// SPDX-License-Identifier: GPL-3.0-or-later
// every accent in both themes holds wcag aa: words on the accent and on its
// deep tone 4.5:1, the accent as an icon or large text 3:1 on every surface
// it sits on, its wash included. the velvet stays clear of the rose that
// errors and warnings wear.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/theme.dart';

double ratio(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

// oklab: lightness and a hue that follow what the eye sees
({double l, double a, double b}) oklab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final l = math.pow(
    0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    1 / 3,
  );
  final m = math.pow(
    0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    1 / 3,
  );
  final s = math.pow(
    0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    1 / 3,
  );
  return (
    l: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

double hueOf(({double l, double a, double b}) c) =>
    (math.atan2(c.b, c.a) * 180 / math.pi) % 360;

void main() {
  tearDown(() {
    HaloColors.setLight(false);
    HaloColors.setAccent(HaloAccent.yellow);
  });

  for (final accent in HaloAccent.values) {
    for (final light in [false, true]) {
      final mode = light ? 'light' : 'dark';
      test('${accent.name} in $mode holds its contrast', () {
        HaloColors.setLight(light);
        HaloColors.setAccent(accent);
        final fails = <String>[];
        void need(String what, Color a, Color b, double min) {
          final r = ratio(a, b);
          if (r < min) fails.add('$what ${r.toStringAsFixed(2)} < $min');
        }

        // labels and message text on the accent: own bubbles, buttons
        need('on / accent', HaloColors.onAmber, HaloColors.amber, 4.5);
        need('on / deep', HaloColors.onAmber, HaloColors.amberDeep, 4.5);
        // the accent's words on its on colour: a search hit or a join
        // button inside your own bubble
        need('words / on', HaloColors.amberOnOn, HaloColors.onAmber, 4.5);
        // the accent as an icon, a ring or large text
        for (final (name, ground) in [
          ('ink', HaloColors.ink),
          ('surface', HaloColors.surface),
          ('surface2', HaloColors.surface2),
        ]) {
          need('accent / $name', HaloColors.amber, ground, 3);
          // the soft wash over that ground: a row's icon tile, a chip
          final washed = Color.alphaBlend(HaloColors.amberSoft, ground);
          need('accent / soft on $name', HaloColors.amber, washed, 3);
          need('text / soft on $name', HaloColors.text, washed, 4.5);
          // the accent's own words on its wash: a chip's label
          need('words / soft on $name', HaloColors.amberText, washed, 4.5);
        }
        // the accent's own words, a mention or a small line, on every
        // ground one sits on: pages, cards, their bubble
        for (final (name, ground) in [
          ('ink', HaloColors.ink),
          ('surface', HaloColors.surface),
          ('surface2', HaloColors.surface2),
          ('surface3', HaloColors.surface3),
          ('bubbleIn', HaloColors.bubbleIn),
        ]) {
          need('words / $name', HaloColors.amberText, ground, 4.5);
          need('warn words / $name', HaloColors.warnText, ground, 4.5);
          need('warn / $name', HaloColors.warn, ground, 3);
        }
        need('on warn / warn', HaloColors.onWarn, HaloColors.warn, 4.5);
        // the light theme draws the deep tone on the page itself
        if (light) {
          need('deep / surface', HaloColors.amberDeep, HaloColors.surface, 3);
        }
        // the bright card in tools, the same in both themes
        need(
          'on bright / bright',
          HaloColors.onAmberBright,
          HaloColors.amberBright,
          4.5,
        );
        need(
          'on bright / bright deep',
          HaloColors.onAmberBright,
          HaloColors.amberBrightDeep,
          4.5,
        );
        expect(fails, isEmpty);
      });
    }
  }

  // what a status or a warning wears, and the onion pill's own lilac
  List<(String, Color)> statusColours() => [
    ('violet', HaloColors.violet),
    ('green', HaloColors.green),
    ('sky', HaloColors.sky),
    ('rose', HaloColors.rose),
    ('lilac', const Color(0xFFB79CFF)),
  ];

  double distance(Color x, Color y) {
    final a = oklab(x), b = oklab(y);
    return math.sqrt(
      math.pow(a.l - b.l, 2) + math.pow(a.a - b.a, 2) + math.pow(a.b - b.b, 2),
    );
  }

  test('no accent passes for a status colour', () {
    final close = <String>[];
    for (final accent in HaloAccent.values) {
      for (final light in [false, true]) {
        HaloColors.setLight(light);
        HaloColors.setAccent(accent);
        for (final (name, c) in statusColours()) {
          // the accent itself, and its words
          for (final (what, tone) in [
            ('accent', HaloColors.amber),
            ('words', HaloColors.amberText),
          ]) {
            final d = distance(tone, c);
            if (d < 0.12) {
              close.add(
                '${accent.name} ${light ? 'light' : 'dark'} $what ~ $name '
                '${d.toStringAsFixed(3)}',
              );
            }
          }
        }
      }
    }
    expect(close, isEmpty);
  });

  test('the warn tone is the yellow whatever the accent', () {
    for (final light in [false, true]) {
      HaloColors.setLight(light);
      for (final accent in HaloAccent.values) {
        HaloColors.setAccent(accent);
        final y = HaloAccent.yellow.tones(light);
        expect(
          (HaloColors.warn, HaloColors.warnText, HaloColors.onWarn),
          (y.accent, y.text, y.on),
          reason: accent.name,
        );
      }
    }
  });

  test('velvet\'s words stay clear of the rose too', () {
    for (final light in [false, true]) {
      HaloColors.setLight(light);
      HaloColors.setAccent(HaloAccent.velvet);
      expect(
        distance(HaloColors.amberText, HaloColors.rose),
        greaterThanOrEqualTo(0.12),
      );
    }
  });

  test('the wash is the accent itself, faint', () {
    for (final accent in HaloAccent.values) {
      for (final light in [false, true]) {
        final t = accent.tones(light);
        expect(t.soft.withValues(alpha: 1), t.accent, reason: accent.name);
        expect(t.soft.a, inInclusiveRange(0.1, 0.2), reason: accent.name);
      }
    }
  });

  test('velvet never reads as the error rose', () {
    for (final light in [false, true]) {
      HaloColors.setLight(light);
      HaloColors.setAccent(HaloAccent.velvet);
      final v = oklab(HaloColors.amber);
      final r = oklab(HaloColors.rose);
      var dh = (hueOf(v) - hueOf(r)).abs();
      dh = math.min(dh, 360 - dh);
      final dl = (v.l - r.l).abs();
      final de = math.sqrt(
        math.pow(v.l - r.l, 2) +
            math.pow(v.a - r.a, 2) +
            math.pow(v.b - r.b, 2),
      );
      final mode = light ? 'light' : 'dark';
      // a step of hue toward red, and darker: wine, not a warning pink
      expect(dh, greaterThanOrEqualTo(20), reason: '$mode hue apart');
      expect(dl, greaterThanOrEqualTo(0.1), reason: '$mode lightness apart');
      expect(de, greaterThanOrEqualTo(0.15), reason: '$mode distance');
      expect(v.l, lessThan(r.l), reason: '$mode velvet is the darker');
    }
  });

  test('yellow is the default and an unknown name falls back to it', () {
    expect(HaloColors.accent, HaloAccent.yellow);
    expect(HaloAccent.byName(null), HaloAccent.yellow);
    expect(HaloAccent.byName('teal'), HaloAccent.yellow);
    expect(HaloAccent.byName('velvet'), HaloAccent.velvet);
  });

  test('the yellow stays yellow whatever the accent', () {
    for (final light in [false, true]) {
      HaloColors.setLight(light);
      HaloColors.setAccent(HaloAccent.yellow);
      final y = (HaloColors.yellow, HaloColors.yellowDeep, HaloColors.onYellow);
      HaloColors.setAccent(HaloAccent.blue);
      expect((
        HaloColors.yellow,
        HaloColors.yellowDeep,
        HaloColors.onYellow,
      ), y);
      expect(HaloColors.amber, isNot(y.$1));
    }
  });

  test('the theme and the accent switch in either order', () {
    HaloColors.setAccent(HaloAccent.lime);
    HaloColors.setLight(true);
    expect(HaloColors.amber, HaloAccent.lime.light.accent);
    HaloColors.setLight(false);
    expect(HaloColors.amber, HaloAccent.lime.dark.accent);
    HaloColors.setAccent(HaloAccent.purple);
    expect(HaloColors.onAmber, HaloAccent.purple.dark.on);
  });
}
