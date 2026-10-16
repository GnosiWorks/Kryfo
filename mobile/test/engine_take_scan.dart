// SPDX-License-Identifier: GPL-3.0-or-later
// reads the bindings off the source: every lookup of an engine call that
// returns a string has its pointer handed straight to engineTake,
// engineTakeSecret or a one-line wrapper of them, so it is always freed
import 'dart:io';

/// the source without its comments, strings kept
String sourceCode(String path) => uncomment(File(path).readAsStringSync());

String uncomment(String s) {
  final b = StringBuffer();
  var i = 0;
  while (i < s.length) {
    if (s.startsWith('//', i)) {
      while (i < s.length && s[i] != '\n') {
        i++;
      }
      continue;
    }
    if (s.startsWith('/*', i)) {
      final end = s.indexOf('*/', i + 2);
      i = end < 0 ? s.length : end + 2;
      continue;
    }
    final q = ["'''", '"""', "'", '"'].where((q) => s.startsWith(q, i));
    if (q.isEmpty) {
      b.write(s[i++]);
      continue;
    }
    final raw = i > 0 && s[i - 1] == 'r';
    var j = i + q.first.length;
    while (j < s.length && !s.startsWith(q.first, j)) {
      j += !raw && s[j] == r'\' ? 2 : 1;
    }
    j = j + q.first.length > s.length ? s.length : j + q.first.length;
    b.write(s.substring(i, j));
    i = j;
  }
  return b.toString();
}

/// the engine's exports that hand back a string, read off its go source
Set<String> goStringExports([String dir = '../engine']) {
  final exp = RegExp(r'//export (\w+)\s*\nfunc \1\([^)]*\) \*C\.char');
  return {
    for (final f in Directory(dir).listSync())
      if (f is File && f.path.endsWith('.go') && !f.path.endsWith('_test.go'))
        ...exp.allMatches(f.readAsStringSync()).map((m) => m.group(1)!),
  };
}

/// every lib file that looks up an engine call, without its comments
Map<String, String> bindingSources([String dir = 'lib']) => {
  for (final f in Directory(dir).listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart'))
      if (sourceCode(f.path) case final c when c.contains('lookupFunction'))
        f.path.replaceAll(r'\', '/'): c,
};

/// where a string an engine call returns is not taken: [files] maps a path
/// to its source without comments, [goStrings] names the exports that
/// return one
List<String> takeMisses(Map<String, String> files, Set<String> goStrings) {
  final misses = <String>[];
  final strTypes = {
    for (final c in files.values)
      ...RegExp(
        r'typedef\s+(\w+)\s*=\s*Pointer<Utf8>\s+Function\s*\(',
      ).allMatches(c).map((m) => m.group(1)!),
  };
  for (final MapEntry(key: path, value: c) in files.entries) {
    final takers = {
      'engineTake',
      'engineTakeSecret',
      ...RegExp(
        r'(\w+)\s*\(\s*Pointer<Utf8>\s+(\w+)\s*\)\s*(?:=>|\{)\s*'
        r'(?:final\s+\w+\s*=\s*)?engineTake(?:Secret)?\(\s*\2\s*\)',
      ).allMatches(c).map((m) => m.group(1)!),
    };
    final taken = RegExp('\\b(?:${takers.join('|')})\\(\\s*\$');
    bool takenAt(int at) => taken.hasMatch(c.substring(0, at));
    int line(int at) => '\n'.allMatches(c.substring(0, at)).length + 1;

    for (final m in RegExp(r'\blookupFunction\s*<').allMatches(c)) {
      final where = '$path:${line(m.start)}';
      // the type arguments, split at their top level commas
      final args = <String>[];
      var i = m.end, depth = 1, from = m.end;
      for (; depth > 0; i++) {
        final ch = c[i];
        if (ch == '<' || ch == '(') depth++;
        if (ch == '>' || ch == ')') depth--;
        if (depth == 1 && ch == ',' || depth == 0) {
          args.add(c.substring(from, i).replaceAll(RegExp(r'\s+'), ' ').trim());
          from = i + 1;
        }
      }
      final open = c.indexOf('(', i);
      final close = c.indexOf(')', open);
      final symbol = RegExp(
        r'''^\s*['"](\w+)['"]\s*,?\s*$''',
      ).firstMatch(c.substring(open + 1, close))?.group(1);
      final native = args.first;
      final isString =
          strTypes.contains(native) ||
          native.startsWith('Pointer<Utf8> Function');
      if (!isString) {
        if (symbol == null) {
          misses.add('$where: a symbol in a variable, typed as $native');
        } else if (goStrings.contains(symbol)) {
          misses.add('$where: $symbol returns a string, typed as $native');
        }
        continue;
      }
      // the receiver: _lib. lib. _lib(). Engine._lib().
      final recv = RegExp(
        r'[\w.]*\w(?:\(\))?\s*\.\s*$',
      ).firstMatch(c.substring(0, m.start));
      final before = recv?.start ?? m.start;
      final what = symbol ?? native;
      if (c.substring(close + 1).trimLeft().startsWith('(')) {
        if (!takenAt(before)) misses.add('$where: $what called, not taken');
        continue;
      }
      final name = RegExp(
        r'(\w+)\s*=\s*$',
      ).firstMatch(c.substring(0, before))?.group(1);
      if (name == null) {
        misses.add('$where: $what neither called nor named');
        continue;
      }
      // a field is called anywhere in the file, a local until it is set again
      final field = RegExp(
        'late\\s+final\\s+[^;=]*?\\b$name\\s*[;=]',
      ).hasMatch(c);
      var end = c.length;
      if (!field) {
        final again = RegExp('(?<![\\w.])$name\\s*=(?!=)').allMatches(c, close);
        if (again.isNotEmpty) end = again.first.start;
      }
      final calls = RegExp(
        '(?<![\\w.])$name\\s*\\(',
      ).allMatches(c.substring(0, end), field ? 0 : close);
      for (final call in calls) {
        if (!takenAt(call.start)) {
          misses.add('$path:${line(call.start)}: $name() for $what not taken');
        }
      }
      // a function handed on is called where this cannot see
      final uses = RegExp(
        '(?:[=(,>:]|return)\\s*$name\\b(?!\\s*\\()',
      ).allMatches(c.substring(0, end), field ? 0 : close);
      for (final use in uses) {
        misses.add('$path:${line(use.start)}: $name for $what handed on');
      }
    }
  }
  return misses;
}
