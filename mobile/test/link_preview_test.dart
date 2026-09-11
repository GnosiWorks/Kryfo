import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/link_preview.dart';

void main() {
  test('domainOf strips scheme, path and www', () {
    expect(domainOf('https://www.example.com/a/b?c=1'), 'example.com');
    expect(domainOf('http://news.site.org'), 'news.site.org');
    expect(domainOf('not a url'), 'not a url');
  });
  test('titleFromHtml prefers og:title, then <title>', () {
    expect(
      titleFromHtml(
        '<html><head><title>fallback</title>'
        '<meta property="og:title" content="the real &amp; title"></head>',
      ),
      'the real & title',
    );
    expect(titleFromHtml('<title>  spaced\n  out </title>'), 'spaced out');
    expect(titleFromHtml('<p>nothing</p>'), isNull);
  });
  test('titleFromHtml caps a runaway title', () {
    final t = titleFromHtml('<title>${'x' * 300}</title>')!;
    expect(t.length, 120);
  });

  test('firstUrl finds a capitalised scheme and lowercases it', () {
    expect(firstUrl('see Https://Example.com/A'), 'https://Example.com/A');
    expect(firstUrl('HTTP://x.y/z ok'), 'http://x.y/z');
    expect(firstUrl('no link here'), isNull);
  });
}
