// SPDX-License-Identifier: GPL-3.0-or-later
// search for people who asked to be found, over tor to the handle registry
// only. search text goes there only when the person asks for people
import 'dart:convert';

import 'bidi_safe.dart';
import 'handle_lookup.dart' show kHandleRegistry;

class PublicHandle {
  final String handle;
  final String name;
  final String bio;
  final bool verified;
  final String fp;
  const PublicHandle({
    required this.handle,
    this.name = '',
    this.bio = '',
    this.verified = false,
    this.fp = '',
  });
}

final _handleRe = RegExp(r'^[a-z0-9_]{3,20}$');

/// the query as the registry takes it, or null when the registry's own rule
/// would refuse it
String? peopleQuery(String raw) {
  var q = raw.trim().toLowerCase();
  if (q.startsWith('@')) q = q.substring(1);
  q = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  var n = 0;
  var alnum = 0;
  for (final r in q.runes) {
    n++;
    final c = String.fromCharCode(r);
    if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(c)) {
      alnum++;
    } else if (!' _-.'.contains(c)) {
      return null;
    }
  }
  return n >= 3 && n <= 32 && alnum >= 3 ? q : null;
}

bool looksLikePerson(String raw) => raw.trim().startsWith('@');

/// the registry's answer: valid handles only, names and bios trimmed to the
/// registry's limits, twenty at most
List<PublicHandle> parsePeople(String body) {
  try {
    final j = jsonDecode(body);
    if (j is! Map || j['results'] is! List) return const [];
    final out = <PublicHandle>[];
    for (final e in j['results'] as List) {
      if (e is! Map) continue;
      final h = e['handle'];
      if (h is! String || !_handleRe.hasMatch(h)) continue;
      String str(Object? v, int max) {
        if (v is! String) return '';
        final t = unmarked(v).replaceAll(RegExp(r'\s+'), ' ').trim();
        return t.length > max ? t.substring(0, max) : t;
      }

      out.add(
        PublicHandle(
          handle: h,
          name: str(e['name'], 40),
          bio: str(e['bio'], 121),
          verified: e['verified'] == true,
          fp: str(e['fp'], 9),
        ),
      );
      if (out.length == 20) break;
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// what went wrong, so the screen can say it plainly
enum PeopleError { none, offline, busy, unreachable }

/// the answer where nothing is sent: it reads as the registry not reached,
/// the line adding by handle gives there too
const kRegistryNotReached = 'error: registry not reached';

/// [post] is passed in so tests can hand in a canned answer. the query goes
/// in the body, never in the url: a url can end up in a proxy's log
Future<({List<PublicHandle> people, PeopleError error})> searchPeople(
  String raw,
  Future<String> Function(String url, String body) post,
) async {
  final q = peopleQuery(raw);
  if (q == null) {
    return (people: const <PublicHandle>[], error: PeopleError.none);
  }
  final String body;
  try {
    body = await post('$kHandleRegistry/handle/search', jsonEncode({'q': q}));
  } catch (_) {
    return (people: const <PublicHandle>[], error: PeopleError.unreachable);
  }
  if (body.startsWith('error:')) {
    final e = body.contains('status 429')
        ? PeopleError.busy
        : body.contains('tor')
        ? PeopleError.offline
        : PeopleError.unreachable;
    return (people: const <PublicHandle>[], error: e);
  }
  return (people: parsePeople(body), error: PeopleError.none);
}
