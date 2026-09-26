// SPDX-License-Identifier: GPL-3.0-or-later
// people who asked to be found, by handle or by the name they gave. the
// question goes to the handle registry over tor and nowhere else; the
// registry answers with at most twenty and keeps no record of the question.
// nothing typed into search goes there unless the person asks for people:
// a word someone looks for in their own chats is theirs.
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

/// the question as the registry takes it, or null when it would refuse
/// it: 3 to 32 characters of letters, digits, spaces and _ - . with at
/// least three letters or digits. the same rule as the registry's.
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

/// true when what was typed is plainly a person: @ and a handle's start
bool looksLikePerson(String raw) => raw.trim().startsWith('@');

/// the registry's answer, taken apart carefully: only handles that are
/// handles, names and bios trimmed to what the registry allows, twenty at
/// most. anything else in it is ignored.
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

/// ask the registry. [post] sends a body to a url over tor only ("error: ..."
/// when it could not), so tests can hand in a canned answer. the question
/// goes in the body, never in the url: a url can end up in a proxy's log
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
