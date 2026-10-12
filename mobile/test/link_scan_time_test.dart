// SPDX-License-Identifier: GPL-3.0-or-later
// anyone can send any words, and every bubble reads its links. no text
// makes that slow: each reader is linear in what it is given. the bound is
// loose on purpose, a slow reader takes seconds on these
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/link_preview.dart';
import 'package:kryfo/mentions.dart';
import 'package:kryfo/place_link.dart';
import 'package:kryfo/rooms.dart';

const _size = 40000;

String _fill(String unit, {String tail = ''}) =>
    unit * (_size ~/ unit.length) + tail;

final _texts = <String, String>{
  'open labels': _fill('geo:( '),
  'open labels with no spaces': _fill('(geo:'),
  'open labels and their closers': '${_fill('(geo:')}${')' * _size}',
  'places and links in turn': _fill('geo: https://a '),
  'a link closed many times': 'https://x${')' * _size}',
  'a place closed many times': 'geo:1,2${')' * _size}',
  'a link stopped many times': 'https://x${'.' * _size}',
  'links in labels': _fill('geo:1,2(https://a '),
  'kryfo links': _fill('kryfo://room?x '),
  'mentions': _fill('@a-b-c '),
  'a mention that never ends': '@${'a-' * _size}',
};

void main() {
  for (final e in _texts.entries) {
    test('${e.key}: read in good time', () {
      final text = e.value;
      final w = Stopwatch()..start();
      firstUrl(text);
      firstPlace(text);
      geoSpans(text).length;
      firstKryfoLink(text);
      kryfoLinksIn(text).length;
      mentionsMe(text, 'a-b-c');
      expect(w.elapsedMilliseconds, lessThan(400), reason: e.key);
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
