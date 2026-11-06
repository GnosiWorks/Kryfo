// SPDX-License-Identifier: GPL-3.0-or-later
// words wear the text colour app-wide: text2 or text3 stays on icons,
// lines, a field's placeholder and the dim side of a state (unread or read,
// ready or not), never on plain words
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

const _iconHolders = [
  'Icon(',
  'IconButton(',
  'BackButton(',
  'IconThemeData(',
  'BoxDecoration(',
  'Divider(',
  'CopiedMark(',
  'EmptyChat(',
  '(Icons.',
  '_MarkPainter(',
];
const _textHolders = ['HaloType.', 'TextStyle(', 'Text('];

// each grey use on plain words, as file:line
List<String> greyWords(String path) {
  final s = File(path).readAsStringSync();
  final lines = s.split('\n');
  final bad = <String>[];
  for (final m in RegExp(r'HaloColors\.text[23]\b').allMatches(s)) {
    final before = s.substring(0, m.start);
    int last(List<String> ts) => ts.map(before.lastIndexOf).reduce(math.max);
    if (last(_textHolders) <= last(_iconHolders)) continue;
    final n = '\n'.allMatches(before).length;
    final near = lines.sublist(math.max(0, n - 1), n + 1).join(' ');
    // one side of a state, picked by a condition
    if (near.contains('?')) continue;
    // a field's placeholder
    if (lines.sublist(math.max(0, n - 6), n + 1).join().contains('hint')) {
      continue;
    }
    bad.add('$path:${n + 1}');
  }
  return bad;
}

void main() {
  test('no plain words in text2 or text3', () {
    final bad = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart')) ...greyWords(f.path),
    ];
    expect(bad, isEmpty);
  });

  test('the scan catches grey words and lets the rest by', () {
    final f = File('${Directory.systemTemp.createTempSync().path}/g.dart')
      ..writeAsStringSync(
        "Text('a', style: HaloType.sans(color: HaloColors.text2));\n"
        'Icon(Icons.a, color: HaloColors.text3);\n'
        "Text('b', style: HaloType.sans(color: on ? HaloColors.text : HaloColors.text2));\n"
        'TextField(decoration: InputDecoration(hintText: x,\n'
        '  hintStyle: HaloType.sans(color: HaloColors.text3)));\n',
      );
    expect(greyWords(f.path), ['${f.path}:1']);
  });
}
