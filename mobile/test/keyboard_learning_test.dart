// SPDX-License-Identifier: GPL-3.0-or-later
// every text field in lib/ turns the keyboard's personalised learning off,
// and a field that hides what is typed takes no suggestions either
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/secret_field.dart';

// fields that may let the keyboard learn, each with its reason. the key is
// the file and the field's controller: 'lib/x.dart#_ctrl'
const _allowed = <String, String>{};

final _field = RegExp(
  r'(?<![\w$])(TextField|TextFormField|CupertinoTextField|EditableText)\s*\(',
);

// [src] with comments and the insides of strings blanked out, so only code
// is left where it was
String _codeOnly(String src) {
  final out = src.split('');
  void blank(int from, int to) {
    for (var k = from; k < to; k++) {
      if (out[k] != '\n') out[k] = ' ';
    }
  }

  late final int Function(int) skipString;

  // code up to the brace that closes an interpolation opened before [i]
  int skipCode(int i, {bool toBrace = false}) {
    var depth = 0;
    while (i < src.length) {
      final c = src[i];
      if (src.startsWith('//', i)) {
        final end = src.indexOf('\n', i);
        final to = end < 0 ? src.length : end;
        blank(i, to);
        i = to;
      } else if (src.startsWith('/*', i)) {
        var d = 0;
        final from = i;
        while (i < src.length) {
          if (src.startsWith('/*', i)) {
            d++;
            i += 2;
          } else if (src.startsWith('*/', i)) {
            i += 2;
            if (--d == 0) break;
          } else {
            i++;
          }
        }
        blank(from, i);
      } else if (c == '"' ||
          c == "'" ||
          (c == 'r' &&
              i + 1 < src.length &&
              (src[i + 1] == '"' || src[i + 1] == "'") &&
              (i == 0 || !RegExp(r'[\w$]').hasMatch(src[i - 1])))) {
        i = skipString(i);
      } else if (c == '{') {
        depth++;
        i++;
      } else if (c == '}') {
        if (toBrace && depth == 0) return i + 1;
        depth--;
        i++;
      } else {
        i++;
      }
    }
    return i;
  }

  skipString = (int i) {
    final raw = src[i] == 'r';
    if (raw) i++;
    final q = src[i];
    final triple = src.startsWith(q * 3, i);
    final close = triple ? q * 3 : q;
    i += close.length;
    final from = i;
    while (i < src.length) {
      if (!raw && src[i] == r'\') {
        i += 2;
      } else if (src.startsWith(close, i)) {
        blank(from, i);
        return i + close.length;
      } else if (!raw && src.startsWith(r'${', i)) {
        i = skipCode(i + 2, toBrace: true);
      } else if (!triple && src[i] == '\n') {
        break;
      } else {
        i++;
      }
    }
    blank(from, i);
    return i;
  };

  skipCode(0);
  return out.join();
}

// the top-level named arguments of the call whose '(' is at [open]
Map<String, String> _args(String code, int open) {
  final args = <String, String>{};
  var depth = 0;
  var start = open + 1;
  void take(int end) {
    final part = code.substring(start, end).trim();
    final m = RegExp(r'^(\w+)\s*:\s*([\s\S]*)$').firstMatch(part);
    if (m != null) {
      args[m[1]!] = m[2]!.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }

  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      if (--depth == 0) {
        take(i);
        return args;
      }
    } else if (c == ',' && depth == 1) {
      take(i);
      start = i + 1;
    }
  }
  fail('no end to the call at $open');
}

typedef _Found = ({String key, int line, Map<String, String> args});

List<_Found> _fields(String path, String src) {
  final code = _codeOnly(src);
  return [
    for (final m in _field.allMatches(code))
      () {
        final args = _args(code, m.end - 1);
        return (
          key: '$path#${args['controller'] ?? ''}',
          line: '\n'.allMatches(code.substring(0, m.start)).length + 1,
          args: args,
        );
      }(),
  ];
}

// what is wrong with one field, or null
String? _wrong(_Found f) {
  final a = f.args;
  if (a['enableIMEPersonalizedLearning'] != 'false' &&
      !_allowed.containsKey(f.key)) {
    return 'keyboard learning is not off';
  }
  final hides = a['obscureText'];
  if (hides == null || hides == 'false') return null;
  // what makes it a secret field at all: the parts of the condition that
  // are not the eye toggle
  final gates = hides
      .split('&&')
      .map((s) => s.trim())
      .where((s) => !s.startsWith('!'));
  bool off(String? v) =>
      v == 'false' || (v != null && gates.any((g) => v.contains('!$g')));
  if (!off(a['autocorrect'])) return 'autocorrect is on while it hides';
  if (!off(a['enableSuggestions'])) return 'suggestions are on while it hides';
  return null;
}

void main() {
  test('the check finds a field that lets the keyboard learn', () {
    const src = r'''
// TextField(controller: a) in a comment
final s = 'TextField(controller: b) in a string ${f(')')}';
Widget x() => Column(children: [
  TextField(controller: _good, enableIMEPersonalizedLearning: false),
  m.TextField(
    controller: _bad,
    decoration: InputDecoration(hintText: 'x'),
  ),
  TextFormField(
    controller: _hidden,
    obscureText: !shown,
    enableIMEPersonalizedLearning: false,
  ),
]);
''';
    final found = _fields('lib/x.dart', src);
    expect(found.map((f) => f.key), [
      'lib/x.dart#_good',
      'lib/x.dart#_bad',
      'lib/x.dart#_hidden',
    ]);
    expect(found.map(_wrong).toList(), [
      null,
      'keyboard learning is not off',
      'autocorrect is on while it hides',
    ]);
    expect(found[1].line, 5);
  });

  test('every text field in lib/ keeps the keyboard from learning', () {
    final seen = <String>{};
    final bad = <String>[];
    var count = 0;
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      for (final f in _fields(path, file.readAsStringSync())) {
        count++;
        seen.add(f.key);
        final why = _wrong(f);
        if (why != null) bad.add('$path:${f.line} $why');
      }
    }
    // the scan itself still works: the app has far more than this
    expect(count, greaterThanOrEqualTo(20));
    expect(bad, isEmpty, reason: bad.join('\n'));
    final stale = _allowed.keys.where((k) => !seen.contains(k));
    expect(stale, isEmpty, reason: 'allowed fields no longer there');
  });

  testWidgets('a passphrase field asks the keyboard for nothing', (t) async {
    for (final shown in [false, true]) {
      final ctrl = TextEditingController();
      await t.pumpWidget(
        MaterialApp(
          home: Material(
            child: SecretField(
              label: 'Passphrase',
              controller: ctrl,
              shown: shown,
              onToggle: () {},
            ),
          ),
        ),
      );
      final f = t.widget<TextField>(find.byType(TextField));
      expect(f.enableIMEPersonalizedLearning, isFalse);
      expect(f.autocorrect, isFalse);
      expect(f.enableSuggestions, isFalse);
      expect(f.obscureText, !shown);
      ctrl.dispose();
    }
  });
}
