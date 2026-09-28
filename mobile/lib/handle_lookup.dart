// SPDX-License-Identifier: GPL-3.0-or-later
// find someone by their public handle: one registry read turns @wren into
// the invite wren published. the request carries the handle and nothing else.
import 'dart:convert';

const kHandleRegistry = 'https://relay.kryfo.app';

final _handleRe = RegExp(r'^[a-z0-9_]{3,20}$');

// "@wren" or the page link "relay.kryfo.app/@wren". a bare "wren" is not
// enough, three words look like that too. null lets the caller try the
// text as an invite.
String? handleFromInput(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  for (final p in ['https://', 'http://']) {
    if (s.startsWith(p)) s = s.substring(p.length);
  }
  final host = kHandleRegistry.replaceFirst('https://', '');
  if (s.startsWith('$host/@')) s = s.substring(host.length + 1);
  if (!s.startsWith('@')) return null;
  s = s.substring(1);
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return _handleRe.hasMatch(s) ? s : null;
}

// the registry answer is {"names": {handle: pubkey}, "invite": "kryfo://..."}.
// only a kryfo invite for the handle we asked about is accepted. with
// [idOf], only one whose id is the three words of the key that claimed it
String? inviteFromRegistryJson(
  String body,
  String handle, {
  String Function(String pub)? idOf,
}) {
  try {
    final j = jsonDecode(body);
    if (j is! Map) return null;
    final names = j['names'];
    if (names is! Map || !names.containsKey(handle)) return null;
    final inv = j['invite'];
    if (inv is! String || !inv.startsWith('kryfo://share')) return null;
    if (idOf != null) {
      final pub = names[handle];
      final id = Uri.parse(inv).queryParameters['id'];
      if (pub is! String || id == null || idOf(pub) != id) return null;
    }
    return inv;
  } catch (_) {
    return null;
  }
}

// the invite, or a toast line prefixed 'error: '. fetch is passed in so
// tests can hand in a canned answer.
Future<String> resolveHandle(
  String handle,
  Future<String> Function(String url) fetch, {
  String Function(String pub)? idOf,
}) async {
  final h = handle.toLowerCase();
  if (!_handleRe.hasMatch(h)) return 'error: that is not a handle';
  final String body;
  try {
    body = await fetch('$kHandleRegistry/.well-known/kryfo.json?name=$h');
  } catch (_) {
    return "error: couldn't reach the registry";
  }
  if (body.startsWith('error:')) {
    return body.contains('status 404')
        ? 'error: nobody has claimed @$h'
        : "error: couldn't reach the registry";
  }
  final inv = inviteFromRegistryJson(body, h, idOf: idOf);
  if (inv == null) return 'error: nobody has claimed @$h';
  return inv;
}
