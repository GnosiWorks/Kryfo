import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart';

// the pairing link is the one string a stranger types or scans by hand, so a
// round-trip that quietly loses a field costs someone a contact. this replaces
// the flutter counter template, which tested a widget this app has never had.

void main() {
  test('v1 link round-trips', () {
    final uri = buildHaloUri('abc123', 'xyz.onion', 'pub456');
    final parsed = parseHaloUri(uri);

    expect(parsed, isNotNull);
    expect(parsed!['id'], 'abc123');
    expect(parsed['onion'], 'xyz.onion');
    expect(parsed['xpub'], 'pub456');
    expect(parsed['v'], '1');
  });

  test('anything that is not a share link is refused', () {
    expect(parseHaloUri(''), isNull);
    expect(parseHaloUri('https://example.com'), isNull);
    expect(parseHaloUri('kryfo://other?id=a&onion=b'), isNull);
  });

  test('a link missing a field is refused, not half-read', () {
    expect(parseHaloUri('kryfo://share?onion=b&xpub=c'), isNull);
    expect(parseHaloUri('kryfo://share?id=a&xpub=c'), isNull);
    // v1 without xpub, v2 without bundle
    expect(parseHaloUri('kryfo://share?id=a&onion=b'), isNull);
    expect(parseHaloUri('kryfo://share?id=a&onion=b&v=2'), isNull);
  });

  test('v2 and v3 carry their bundle', () {
    final v2 = parseHaloUri('kryfo://share?id=a&onion=b&v=2&bundle=BUN');
    expect(v2!['v'], '2');
    expect(v2['bundle'], 'BUN');

    final v3 = parseHaloUri('kryfo://share?id=a&onion=b&v=3&bundle=BUN');
    expect(v3!['v'], '3');
    expect(v3['bundle'], 'BUN');
  });

  test('a first-contact key is kept only at full length', () {
    final good = 'f' * 64;
    expect(
      parseHaloUri('kryfo://share?id=a&onion=b&v=3&bundle=B&fc=$good')!['fc'],
      good,
    );
    // truncated key: pair anyway, fall back to onion-only first contact
    expect(
      parseHaloUri(
        'kryfo://share?id=a&onion=b&v=3&bundle=B&fc=short',
      )!.containsKey('fc'),
      isFalse,
    );
  });
}
