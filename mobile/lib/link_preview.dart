// SPDX-License-Identifier: GPL-3.0-or-later
// link previews, the honest kind. a link in a message shows its bare domain
// and nothing else until the reader asks; the ask is one request for the
// page, over whatever route the app is on, and only the title comes back.
// no image is ever loaded. these are the pure parts.

// the first http(s) url in a message, scheme lowercased. keyboards
// capitalise the first letter of a message, so "Https://" has to count.
String? firstUrl(String text) {
  final m = RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(text);
  if (m == null) return null;
  final raw = m.group(0)!;
  final colon = raw.indexOf('://');
  return raw.substring(0, colon).toLowerCase() + raw.substring(colon);
}

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
  t = unescapeHtml(t).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  return t.length > 120 ? '${t.substring(0, 119)}…' : t;
}
