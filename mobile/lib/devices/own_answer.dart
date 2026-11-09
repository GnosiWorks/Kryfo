// SPDX-License-Identifier: GPL-3.0-or-later
// what a linked device may hand the developer's phone to send in his
// inbox ('oa', own_sync.dart): text with a reply, a link's title or a
// timer, a reaction, an edit, a take-back. never a file, a voice note, a
// picture, a sticker, a poll, an introduction or a group word. the phone
// reads it again with its own words around it, so nothing of the
// computer's sender, proof of work or caps goes on
import 'dart:convert';

import '../message_envelope.dart' show kEnvelopePrefix;
import '../voice_format.dart' show kOpusWire;

/// the most answers one computer hands the phone in an hour
const kOwnAnswersAnHour = 120;

/// the words an answer carries to the phone
const kAnswerKept = {'u', 'm', 'q', 'pv', 'b', 'r', 'ed', 'un'};

/// the words a send puts on that the phone puts on again as its own, or
/// that an answer never needs
const kAnswerDropped = {
  'w', 'h', 'e', 'o', 'x', 'av', 'bg', 'pw', 'pb', 'cp', 'sc', kOpusWire, //
};

/// the longest a timer on an answer may be: a month
const kAnswerBurnMost = 30 * 24 * 3600;

final _uidShape = RegExp(r'^[A-Za-z0-9_\-]{1,64}$');

enum AnswerKind { text, reaction, edit, takeBack }

/// an answer as the phone sends it. [uid]: the message's own for a text,
/// the one it speaks of for the rest
typedef OwnAnswer = ({
  AnswerKind kind,
  String uid,
  String text,
  String? reply,
  Map<String, String>? preview,
  int? burn,
});

/// [frame] read as an answer; null for anything else
OwnAnswer? ownAnswerOf(String frame) {
  if (!frame.startsWith(kEnvelopePrefix)) return null;
  final Object? j;
  try {
    j = jsonDecode(frame.substring(kEnvelopePrefix.length));
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  for (final k in j.keys) {
    if (!kAnswerKept.contains(k) && !kAnswerDropped.contains(k)) return null;
  }
  final controls = [
    for (final k in const ['r', 'ed', 'un'])
      if (j.containsKey(k)) k,
  ];
  if (controls.length > 1) return null;
  final m = j['m'];
  if (m != null && m is! String) return null;
  String? uidOf(Object? u) => u is String && _uidShape.hasMatch(u) ? u : null;

  if (controls.isNotEmpty) {
    // a word on a message says nothing of its own
    if ((m as String? ?? '').isNotEmpty) return null;
    for (final k in const ['u', 'q', 'pv', 'b']) {
      if (j.containsKey(k)) return null;
    }
  }
  switch (controls.firstOrNull) {
    case 'r':
      final r = j['r'];
      if (r is! Map || r.keys.any((k) => k != 'u' && k != 'e')) return null;
      final u = uidOf(r['u']), e = r['e'];
      if (u == null || e is! String || e.length > 32) return null;
      return _answer(AnswerKind.reaction, u, e);
    case 'ed':
      final ed = j['ed'];
      if (ed is! Map || ed.keys.any((k) => k != 'u' && k != 'm')) return null;
      final u = uidOf(ed['u']), t = ed['m'];
      if (u == null || t is! String || t.trim().isEmpty) return null;
      return _answer(AnswerKind.edit, u, t);
    case 'un':
      final u = uidOf(j['un']);
      return u == null ? null : _answer(AnswerKind.takeBack, u, '');
  }
  final u = uidOf(j['u']);
  if (u == null || m is! String || m.trim().isEmpty) return null;
  final q = j['q'];
  if (q != null && uidOf(q) == null) return null;
  final b = j['b'];
  if (b != null && (b is! int || b <= 0 || b > kAnswerBurnMost)) return null;
  Map<String, String>? preview;
  final pv = j['pv'];
  if (pv != null) {
    // a link's address and title, no picture
    if (pv is! Map) return null;
    preview = {};
    for (final e in pv.entries) {
      final k = e.key, v = e.value;
      if (k is! String || !const {'url', 'title', 'by'}.contains(k)) {
        return null;
      }
      if (v is! String || v.length > 2048) return null;
      preview[k] = v;
    }
  }
  return (
    kind: AnswerKind.text,
    uid: u,
    text: m,
    reply: q as String?,
    preview: preview,
    burn: b as int?,
  );
}

OwnAnswer _answer(AnswerKind kind, String uid, String text) =>
    (kind: kind, uid: uid, text: text, reply: null, preview: null, burn: null);
