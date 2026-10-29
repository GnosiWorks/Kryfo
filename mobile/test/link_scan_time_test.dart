// SPDX-License-Identifier: GPL-3.0-or-later
// anyone can send any words, and every bubble reads its links. no text
// makes that slow: each reader is linear in what it is given. the check is
// the growth, not the clock: eight times the text may take at most 24 times
// as long (linear is about 8, quadratic about 64). each size keeps its
// fastest of seven runs, so a loaded machine only adds noise it drops
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/link_preview.dart';
import 'package:kryfo/mentions.dart';
import 'package:kryfo/place_link.dart';
import 'package:kryfo/rooms.dart';

const _size = 40000;

String _fill(String unit, {String tail = '', int size = _size}) =>
    unit * (size ~/ unit.length) + tail;

// each text at a given size
final _texts = <String, String Function(int)>{
  'open labels': (n) => _fill('geo:( ', size: n),
  'open labels with no spaces': (n) => _fill('(geo:', size: n),
  'open labels and their closers': (n) =>
      '${_fill('(geo:', size: n)}${')' * n}',
  'places and links in turn': (n) => _fill('geo: https://a ', size: n),
  'a link closed many times': (n) => 'https://x${')' * n}',
  'a place closed many times': (n) => 'geo:1,2${')' * n}',
  'a link stopped many times': (n) => 'https://x${'.' * n}',
  'links in labels': (n) => _fill('geo:1,2(https://a ', size: n),
  'kryfo links': (n) => _fill('kryfo://room?x ', size: n),
  'mentions': (n) => _fill('@a-b-c ', size: n),
  'a mention that never ends': (n) => '@${'a-' * n}',
};

void _readAll(String text) {
  firstUrl(text);
  firstPlace(text);
  geoSpans(text).length;
  firstKryfoLink(text);
  kryfoLinksIn(text).length;
  mentionsMe(text, 'a-b-c');
}

// the fastest of [runs] reads, in microseconds
int _fastest(String text, {int runs = 7}) {
  var best = -1;
  for (var i = 0; i < runs; i++) {
    final w = Stopwatch()..start();
    _readAll(text);
    final us = w.elapsedMicroseconds;
    if (best < 0 || us < best) best = us;
  }
  return best;
}

void main() {
  for (final e in _texts.entries) {
    test('${e.key}: read in good time', () {
      final small = e.value(_size ~/ 8), big = e.value(_size);
      // warm up first: the first runs are compiled as they go
      for (var i = 0; i < 3; i++) {
        _readAll(small);
        _readAll(big);
      }
      // a floor of 200 us: below it the timer's own steps count
      final a = _fastest(small).clamp(200, 1 << 40);
      final b = _fastest(big);
      expect(
        b / a,
        lessThan(24),
        reason: '${e.key}: ${a}us at ${_size ~/ 8}, ${b}us at $_size',
      );
      // and never seconds: about 10 ms here unloaded
      expect(b, lessThan(2000000), reason: e.key);
    });
  }

  test('what is found is the same', () {
    expect(
      firstUrl('${'geo:( ' * 50}https://a.example/x.'),
      'https://a.example/x',
    );
    expect(
      firstUrl('geo:1,2(https://a.example/x) https://b.example/y'),
      'https://b.example/y',
    );
    expect(firstUrl('https://x${')' * 500}'), 'https://x');
    expect(firstUrl('(https://x)'), 'https://x');
    expect(firstUrl('https://x/a_(b)'), 'https://x/a_(b)');
    expect(firstPlace('${'(geo:' * 50} geo:1,2.')?.coords, '1, 2');
    expect(firstPlace('geo:0,0?q=1,2(eiffel tower) ok')?.label, 'eiffel tower');
    // a label closes within the cap, or it is not one
    final far = 'geo:1,2(${'a ' * 400})';
    expect(firstPlace(far)?.label, isNull);
    expect(firstUrl('$far https://c.example'), 'https://c.example');
  });

  test('a message reads its links once until its words change', () {
    final m = _Msg('see geo:1,2 and https://a.example');
    expect(m.url, 'https://a.example');
    expect(m.place?.coords, '1, 2');
    final url = m.url, place = m.place;
    expect(identical(m.place, place), isTrue);
    expect(m.url, url);
    m.text = 'now https://b.example';
    expect(m.url, 'https://b.example');
    expect(m.place, isNull);
  });
}

class _Msg with WordLinks {
  @override
  String text;
  _Msg(this.text);
}
