// SPDX-License-Identifier: GPL-3.0-or-later
// people search, the phone's side. the registry's side is tested in
// server/handle/search_test.go.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/handle_search.dart';

void main() {
  test('sends only queries the registry takes', () {
    expect(peopleQuery('wren'), 'wren');
    expect(peopleQuery('@Wren'), 'wren');
    expect(peopleQuery('  Wren   F  '), 'wren f');
    expect(peopleQuery('مریم'), 'مریم');
    expect(peopleQuery('李小龍'), '李小龍');
    for (final bad in [
      '',
      'ab',
      '@ab',
      'a b',
      '***',
      'wr*',
      'wren%',
      '___',
      '<script>',
      'x' * 33,
    ]) {
      expect(peopleQuery(bad), isNull, reason: bad);
    }
  });

  test('only @ searches without a tap', () {
    expect(looksLikePerson('@wren'), isTrue);
    expect(looksLikePerson(' @wren'), isTrue);
    expect(looksLikePerson('wren'), isFalse);
    expect(looksLikePerson('dinner at 8'), isFalse);
  });

  test('parses the answer strictly', () {
    final p = parsePeople('''
      {"results": [
        {"handle": "wren", "name": "Wren  F.", "bio": "hi", "verified": true, "fp": "ABCD 1234"},
        {"handle": "NOT a handle", "name": "x"},
        {"handle": "evil<script>"},
        {"handle": "anna", "name": 42, "bio": null},
        "junk"
      ]}''');
    expect(p.map((e) => e.handle), ['wren', 'anna']);
    expect(p.first.name, 'Wren F.');
    expect(p.first.verified, isTrue);
    expect(p[1].name, '');
    expect(p[1].verified, isFalse);
    expect(parsePeople('not json'), isEmpty);
    expect(parsePeople('{"results": "x"}'), isEmpty);
    final many =
        '{"results": [${List.generate(30, (i) => '{"handle": "user$i"}').join(',')}]}';
    expect(parsePeople(many).length, 20);
  });

  test(
    'posts the query and sorts errors',
    () async {
      String? asked, sent;
      final ok = await searchPeople('@Wren F', (url, body) async {
        asked = url;
        sent = body;
        return '{"results": [{"handle": "wren", "verified": true}]}';
      });
      // the question travels in the body, never in the url
      expect(asked, 'https://relay.kryfo.app/handle/search');
      expect(jsonDecode(sent!), {'q': 'wren f'});
      expect(ok.people.single.handle, 'wren');
      expect(ok.error, PeopleError.none);

      var called = false;
      final none = await searchPeople('ab', (url, body) async {
        called = true;
        return '';
      });
      expect(called, isFalse);
      expect(none.people, isEmpty);

      expect(
        (await searchPeople(
          'wren',
          (_, _) async => 'error: tor: not started',
        )).error,
        PeopleError.offline,
      );
      expect(
        (await searchPeople('wren', (_, _) async => 'error: status 429')).error,
        PeopleError.busy,
      );
      expect(
        (await searchPeople(
          'wren',
          (_, _) async => throw Exception('x'),
        )).error,
        PeopleError.unreachable,
      );
    },
  );

  // a quiet session answers without sending, and says what adding by
  // handle says there
  test('the answer where nothing is sent reads as the registry not '
      'reached', () async {
    final r = await searchPeople('@wren', (_, _) async => kRegistryNotReached);
    expect(r.error, PeopleError.unreachable);
    expect(r.people, isEmpty);
  });
}
