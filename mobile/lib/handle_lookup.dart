// SPDX-License-Identifier: GPL-3.0-or-later
//
// find someone by their public handle. the registry already serves a small
// json answer for each claimed handle (the same one the web page is built
// from), so a lookup is one read: @wren becomes the invite wren published,
// and the invite goes through the normal add path. nothing about the person
// looking is sent - the request carries the handle and nothing else.
import 'dart:convert';

const kHandleRegistry = 'https://relay.kryfo.app';

final _handleRe = RegExp(r'^[a-z0-9_]{3,20}$');

// pull a handle out of whatever someone typed or scanned: "@wren", "wren"
// is not enough on its own (three words look like that too), but the page
// link "relay.kryfo.app/@wren" with or without https is. null when the text
// is something else, so the caller can try it as an invite.
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
// only a kryfo invite for the handle we asked about is accepted.
String? inviteFromRegistryJson(String body, String handle) {
  try {
    final j = jsonDecode(body);
    if (j is! Map) return null;
    final names = j['names'];
    if (names is! Map || !names.containsKey(handle)) return null;
    final inv = j['invite'];
    if (inv is! String || !inv.startsWith('kryfo://share')) return null;
    return inv;
  } catch (_) {
    return null;
  }
}

// resolve a handle to its invite. fetch is whatever reads a url through the
// engine, so tests can hand in a canned answer. returns the invite, or a
// short line for the toast prefixed 'error: '.
Future<String> resolveHandle(
  String handle,
  Future<String> Function(String url) fetch,
) async {
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
  final inv = inviteFromRegistryJson(body, h);
  if (inv == null) return 'error: nobody has claimed @$h';
  return inv;
}
