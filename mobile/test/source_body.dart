// SPDX-License-Identifier: GPL-3.0-or-later
// a function's body out of a source file, for the tests that check which
// path a screen's code takes where pumping the screen would prove nothing
import 'dart:io';

String sourceOf(String path) => File(path).readAsStringSync();

/// the text from [signature], which ends in its opening parenthesis, to the
/// brace that closes its body
String bodyOf(String src, String signature) {
  final at = src.indexOf(signature);
  if (at < 0) throw StateError('not found: $signature');
  // past the parameter list, whose named ones sit in braces of their own
  var i = at + signature.length;
  for (var parens = 1; parens > 0; i++) {
    if (src[i] == '(') parens++;
    if (src[i] == ')') parens--;
  }
  final open = src.indexOf('{', i);
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    final c = src[i];
    if (c == '{') depth++;
    if (c == '}' && --depth == 0) return src.substring(at, i + 1);
  }
  throw StateError('unclosed: $signature');
}

/// every call that starts with [opening], which ends in its parenthesis, up
/// to the parenthesis that closes it
List<String> callsOf(String src, String opening) {
  final out = <String>[];
  var from = 0;
  while (true) {
    final at = src.indexOf(opening, from);
    if (at < 0) return out;
    var i = at + opening.length;
    for (var parens = 1; parens > 0; i++) {
      if (src[i] == '(') parens++;
      if (src[i] == ')') parens--;
    }
    out.add(src.substring(at, i));
    from = i;
  }
}
