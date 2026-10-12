// SPDX-License-Identifier: GPL-3.0-or-later
// link previews. a link shows its bare domain until the reader asks, then one
// request over the app's route fetches the page and only the title is kept.
// no image is ever loaded. these are the pure parts.

import 'bidi_safe.dart';
import 'place_link.dart';

final _url = RegExp(r'https?://[^\s]+', caseSensitive: false);

// the first http(s) url in a message, scheme lowercased. keyboards
// capitalise the first letter of a message, so "Https://" has to count.
// a link inside a geo: label is part of the place and is never fetched
String? firstUrl(String text) {
  final geo = geoSpans(text).iterator;
  var more = geo.moveNext();
  // the furthest a geo: link that starts before the url reaches
  var reach = -1;
  for (final m in _url.allMatches(text)) {
    while (more && geo.current.$1 <= m.start) {
      if (geo.current.$2 > reach) reach = geo.current.$2;
      more = geo.moveNext();
    }
    if (m.start < reach) continue;
    // a sentence's own punctuation after the link: "see https://x.y/z."
    final raw = trimTail(m.group(0)!);
    if (!raw.contains('://')) return null;
    final colon = raw.indexOf('://');
    return raw.substring(0, colon).toLowerCase() + raw.substring(colon);
  }
  return null;
}

/// a message's first link and place, read again only when its words change:
/// a bubble is built far more often than it is edited
mixin WordLinks {
  String get text;
  String? _readFor;
  String? _url;
  Place? _place;

  String? get url {
    _read();
    return _url;
  }

  Place? get place {
    _read();
    return _place;
  }

  void _read() {
    final t = text;
    if (_readFor != null && _readFor == t) return;
    _url = firstUrl(t);
    _place = firstPlace(t);
    _readFor = t;
  }
}

// what a sender ships inside the message: the url, its title on one line
// and capped, and who fetched it. the receiver renders this and asks the
// network for nothing.
Map<String, String> senderPreview(String url, String title) => {
  'url': url,
  'title': title
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .substring(
        0,
        title.replaceAll(RegExp(r'\s+'), ' ').trim().length.clamp(0, 120),
      ),
  'by': 'sender',
};

// "example.com" for anything that parses, the raw text otherwise
String domainOf(String url) {
  final u = Uri.tryParse(url.trim());
  var host = u?.host ?? '';
  if (host.isEmpty) return url.trim();
  if (host.startsWith('www.')) host = host.substring(4);
  return host;
}

String unescapeHtml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ');

// the page's own title: og:title, then twitter:title, then <title>. trimmed,
// one line, capped. null when the page offers none.
String? titleFromHtml(String html) {
  String? grab(String prop) {
    final re = RegExp(
      '<meta[^>]+(?:property|name)=["\']${RegExp.escape(prop)}["\'][^>]+content=["\']([^"\']+)',
      caseSensitive: false,
    );
    return re.firstMatch(html)?.group(1);
  }

  var t = grab('og:title') ?? grab('twitter:title');
  t ??= RegExp(
    r'<title[^>]*>([^<]+)',
    caseSensitive: false,
  ).firstMatch(html)?.group(1);
  if (t == null) return null;
  // a page's title is anyone's words: no direction controls (bidi_safe.dart)
  t = unmarked(unescapeHtml(t)).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  return t.length > 120 ? '${t.substring(0, 119)}…' : t;
}
