// SPDX-License-Identifier: GPL-3.0-or-later
// geo: links as map apps share them. the card shows the place and hands it
// to a maps app. nothing here asks the network for anything, and firstUrl
// never sees inside one.
import 'bidi_safe.dart';

class Place {
  final double lat, lon;
  final String? label;
  // rebuilt from the checked parts, so what opens is what the card shows
  final Uri uri;
  const Place(this.lat, this.lon, this.label, this.uri);

  // five places is about a metre
  String get coords => '${_short(lat)}, ${_short(lon)}';
}

String _short(double v) {
  var s = v.toStringAsFixed(5);
  s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s == '-0' ? '0' : s;
}

const _labelCap = 80;
const _tokenCap = 600;

// starts the text or follows a space or an opening mark, never a letter
final _start = RegExp(
  '(?<![^\\s(\\[{<"\'«“‘])geo:',
  caseSensitive: false,
  unicode: true,
);
const _num = r'[+-]?\d{1,3}(?:\.\d{1,15})?';
final _path = RegExp('^($_num),($_num)(?:,$_num)?((?:;[^;=]+=[^;]*)*)\$');
final _q = RegExp('^($_num),($_num)\\s*(?:\\((.*)\\))?\$', dotAll: true);

/// where each geo: link in [text] starts and ends
Iterable<(int, int)> geoSpans(String text) sync* {
  for (final m in _start.allMatches(text)) {
    yield (m.start, _end(text, m.start));
  }
}

int _end(String text, int from) {
  var i = from;
  while (i < text.length && !_space(text.codeUnitAt(i))) {
    i++;
  }
  // a label written with its spaces: "(eiffel tower)" runs to its bracket
  final head = text.substring(from, i);
  if ('('.allMatches(head).length > ')'.allMatches(head).length) {
    final close = text.indexOf(')', i);
    final line = text.indexOf('\n', i);
    if (close > 0 && (line < 0 || close < line) && close - from < _tokenCap) {
      i = close + 1;
    }
  }
  return i;
}

bool _space(int c) =>
    c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 || c == 0xA0;

/// the first geo: link in [text] that names a real place, or null
Place? firstPlace(String text) {
  for (final (s, e) in geoSpans(text)) {
    final p = _parse(_trimTail(text.substring(s, e)));
    if (p != null) return p;
  }
  return null;
}

// a sentence's own punctuation after the link, as firstUrl does it
String _trimTail(String raw) {
  while (raw.isNotEmpty) {
    final last = raw[raw.length - 1];
    final closes = last == ')' || last == ']';
    final opens = last == ')' ? '(' : '[';
    if ('.,;:!?\'"'.contains(last) || (closes && !raw.contains(opens))) {
      raw = raw.substring(0, raw.length - 1);
    } else {
      break;
    }
  }
  return raw;
}

Place? _parse(String raw) {
  // the tail trim can eat the colon of a bare "geo:"
  if (raw.length > _tokenCap || !raw.toLowerCase().startsWith('geo:')) {
    return null;
  }
  final body = raw.substring(4);
  final qi = body.indexOf('?');
  final pm = _path.firstMatch(qi < 0 ? body : body.substring(0, qi));
  if (pm == null) return null;
  for (final p in pm.group(3)!.split(';').skip(1)) {
    final eq = p.indexOf('=');
    final k = p.substring(0, eq).toLowerCase();
    final v = p.substring(eq + 1);
    // another datum would put the pin somewhere else
    if (k == 'crs' && v.toLowerCase() != 'wgs84') return null;
    if (k == 'u' && (double.tryParse(v) ?? -1) < 0) return null;
  }
  var latS = pm.group(1)!, lonS = pm.group(2)!;
  String? label, zoom;
  var named = false;
  if (qi >= 0) {
    for (final kv in body.substring(qi + 1).split('&')) {
      final eq = kv.indexOf('=');
      if (eq < 0) continue;
      final k = kv.substring(0, eq).toLowerCase();
      final v = _decode(kv.substring(eq + 1));
      if (k == 'z' && RegExp(r'^\d{1,2}(?:\.\d)?$').hasMatch(v)) {
        final z = double.parse(v);
        if (z >= 1 && z <= 21) zoom = v;
      } else if (k == 'q') {
        final qm = _q.firstMatch(v.trim());
        if (qm == null) continue;
        named = true;
        // "geo:0,0?q=lat,lon(label)" keeps the place in q
        if (_zero(latS) && _zero(lonS)) {
          latS = qm.group(1)!;
          lonS = qm.group(2)!;
        }
        label = _clean(qm.group(3) ?? '');
      }
    }
  }
  // "geo:0,0?q=an address" is a search, not a place
  if (!named && qi >= 0 && _zero(latS) && _zero(lonS)) return null;
  latS = latS.replaceFirst('+', '');
  lonS = lonS.replaceFirst('+', '');
  final lat = double.parse(latS), lon = double.parse(lonS);
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  final q =
      '$latS,$lonS${label == null ? '' : '(${Uri.encodeComponent(label)})'}';
  final uri = Uri.parse(
    'geo:$latS,$lonS?${zoom == null ? '' : 'z=$zoom&'}q=$q',
  );
  return Place(lat, lon, label, uri);
}

bool _zero(String s) => double.parse(s) == 0;

// labels come percent-encoded, and some apps write spaces as '+'
String _decode(String v) {
  final plus = v.replaceAll('+', ' ');
  try {
    return Uri.decodeComponent(plus);
  } catch (_) {
    return plus;
  }
}

// anyone's words: no direction controls, no control characters, one line
String? _clean(String s) {
  var t = unmarked(s)
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (t.isEmpty) return null;
  final r = t.runes.toList();
  if (r.length > _labelCap) {
    t = '${String.fromCharCodes(r.take(_labelCap - 1)).trimRight()}…';
  }
  return t;
}
