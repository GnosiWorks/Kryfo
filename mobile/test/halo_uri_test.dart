import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart';

// a pairing link that quietly loses a field costs someone a contact

void main() {
  test('v1 link round-trips', () {
    final uri = buildHaloUri('amber-fox-run', 'xyz.onion', 'pub456');
    final parsed = parseHaloUri(uri);

    expect(parsed, isNotNull);
    expect(parsed!['id'], 'amber-fox-run');
    expect(parsed['onion'], 'xyz.onion');
    expect(parsed['xpub'], 'pub456');
    expect(parsed['v'], '1');
  });

  test('refuses anything but a share link', () {
    expect(parseHaloUri(''), isNull);
    expect(parseHaloUri('https://example.com'), isNull);
    expect(parseHaloUri('kryfo://other?id=a&onion=b'), isNull);
  });

  test('refuses a link missing a field', () {
    expect(parseHaloUri('kryfo://share?onion=b&xpub=c'), isNull);
    expect(parseHaloUri('kryfo://share?id=calm-mild-stone&xpub=c'), isNull);
    // v1 without xpub, v2 without bundle
    expect(parseHaloUri('kryfo://share?id=calm-mild-stone&onion=b'), isNull);
    expect(
      parseHaloUri('kryfo://share?id=calm-mild-stone&onion=b&v=2'),
      isNull,
    );
  });

  test('v2 and v3 carry their bundle', () {
    final v2 = parseHaloUri(
      'kryfo://share?id=calm-mild-stone&onion=b&v=2&bundle=BUN',
    );
    expect(v2!['v'], '2');
    expect(v2['bundle'], 'BUN');

    final v3 = parseHaloUri(
      'kryfo://share?id=calm-mild-stone&onion=b&v=3&bundle=BUN',
    );
    expect(v3!['v'], '3');
    expect(v3['bundle'], 'BUN');
  });

  test('keeps a first-contact key only at full length', () {
    final good = 'f' * 64;
    expect(
      parseHaloUri(
        'kryfo://share?id=calm-mild-stone&onion=b&v=3&bundle=B&fc=$good',
      )!['fc'],
      good,
    );
    // truncated key: pair anyway, fall back to onion-only first contact
    expect(
      parseHaloUri(
        'kryfo://share?id=calm-mild-stone&onion=b&v=3&bundle=B&fc=short',
      )!.containsKey('fc'),
      isFalse,
    );
  });

  // the id is shown to the person as a name before anything is added: one
  // that is not three words, as every version makes them, is no invite
  test('takes an id only as three words', () {
    String card(String id) =>
        'kryfo://share?id=${Uri.encodeQueryComponent(id)}&onion=b&v=2'
        '&bundle=BUN';
    for (final id in ['calm-mild-stone', 'abandon-zoo-ability', 'a-b-c']) {
      expect(parseHaloUri(card(id))?['id'], id, reason: id);
    }
    for (final id in [
      'abc123',
      'Calm-mild-stone',
      'calm-mild',
      'calm-mild-stone-more',
      'calm-mild-st0ne',
      'calm mild stone',
      'calm-mild-stone\n',
      'calm-mild-\u202Eenots',
      'calm-mild-stone\u200B',
      '\u0441alm-mild-stone',
      '',
    ]) {
      expect(parseHaloUri(card(id)), isNull, reason: id);
    }
  });
}
