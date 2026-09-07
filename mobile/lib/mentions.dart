// SPDX-License-Identifier: GPL-3.0-or-later
// @mentions in groups. a mention is the person's three words after an @, so
// it survives nicknames, which never leave the phone. these are the pure
// parts: what the composer is asking for, how a pick lands in the text, and
// how a message is split for the amber highlight.
import 'package:flutter/material.dart';

import 'theme.dart';

final _idRe = RegExp(r'@([a-z]+-[a-z]+-[a-z]+)');

// someone the picker can offer: their id, our name for them, their face
class MentionCandidate {
  final String id;
  final String? name;
  final int? avatar;
  const MentionCandidate({required this.id, this.name, this.avatar});
}

// the partial handle being typed at the cursor, or null when the cursor is
// not right after an @word. an @ mid-word (an email) does not count.
String? mentionQuery(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final head = text.substring(0, cursor);
  final at = head.lastIndexOf('@');
  if (at < 0) return null;
  if (at > 0 && !RegExp(r'\s').hasMatch(head[at - 1])) return null;
  final q = head.substring(at + 1);
  if (RegExp(r'\s').hasMatch(q)) return null;
  return q.toLowerCase();
}

// replace the @partial at the cursor with @id and a space. returns the new
// text and where the cursor lands.
({String text, int cursor}) insertMention(String text, int cursor, String id) {
  final head = text.substring(0, cursor);
  final at = head.lastIndexOf('@');
  if (at < 0) return (text: text, cursor: cursor);
  final before = text.substring(0, at);
  final after = text.substring(cursor);
  final ins = '@$id ';
  return (text: '$before$ins$after', cursor: before.length + ins.length);
}

// members whose name or id starts with what was typed, name matches first
List<T> mentionMatches<T>(
  String query,
  List<T> members,
  String Function(T) id,
  String? Function(T) name,
) {
  final q = query.toLowerCase();
  bool starts(String? s) => s != null && s.toLowerCase().startsWith(q);
  final byName = [
    for (final m in members)
      if (starts(name(m))) m,
  ];
  final byId = [
    for (final m in members)
      if (!byName.contains(m) && starts(id(m))) m,
  ];
  return [...byName, ...byId];
}

bool mentionsMe(String text, String myId) =>
    myId.isNotEmpty && _idRe.allMatches(text).any((m) => m.group(1) == myId);

// the message with its mentions picked out. amber on a dark bubble; on the
// sender's amber bubble amber would vanish, so there it is the bubble's own
// text colour, heavier and underlined.
TextSpan mentionRich(String text, TextStyle base, {Color? accent}) {
  final spans = <TextSpan>[];
  var last = 0;
  for (final m in _idRe.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    spans.add(
      TextSpan(
        text: m.group(0),
        style: base.copyWith(
          color: accent ?? HaloColors.amber,
          fontWeight: FontWeight.w700,
          decoration: accent == null ? null : TextDecoration.underline,
          decorationColor: accent,
        ),
      ),
    );
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return TextSpan(style: base, children: spans);
}
