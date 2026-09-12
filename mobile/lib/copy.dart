// SPDX-License-Identifier: GPL-3.0-or-later
// copy.dart - sentence case for the copy that goes through shared widgets.
// labels, hints, tabs and sheet titles were all lowercase; the first
// letter of a sentence is capitalised now, telegram-style. identifiers
// stay as they are: a kryfo name, a handle, a version, an onion.

String sentence(String s) {
  if (s.isEmpty) return s;
  final first = s.codeUnitAt(0);
  if (first < 0x61 || first > 0x7a) return s;
  final word = s.split(' ').first;
  // a word carrying punctuation or digits is a name, not a word
  if (RegExp(r'[0-9.\-_/:@]').hasMatch(word)) return s;
  final out = StringBuffer(s[0].toUpperCase());
  var capNext = false;
  for (var i = 1; i < s.length; i++) {
    final c = s[i];
    if (capNext && c != ' ') {
      out.write(c.toUpperCase());
      capNext = false;
      continue;
    }
    out.write(c);
    // a full stop then a space starts the next sentence
    if ((c == '.' || c == '!' || c == '?') &&
        i + 1 < s.length &&
        s[i + 1] == ' ') {
      capNext = true;
    }
  }
  return out.toString();
}
