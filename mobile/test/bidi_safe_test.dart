// SPDX-License-Identifier: GPL-3.0-or-later
// direction controls never reach the screen from someone else's words
// (bidi_safe.dart)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bidi_safe.dart';
import 'package:kryfo/message_envelope.dart';

// a line with one of each kind of control in it
const marked =
    '\u2067one\u2069 \u202etwo\u202c \u200fthree\u200e \u2066four\u2069';

void main() {
  test('strips direction controls, keeps the joiners', () {
    expect(unmarked(marked), 'one two three four');
    expect(unmarked('\u202egpj.exe'), 'gpj.exe');
    expect(unmarked('\u2067a\u202ab\u202bc\u202cd\u202de'), 'abcde');
    expect(unmarked('\u200f\u061cسلام'), 'سلام');
    // persian needs its non-joiner, emoji need the joiner
    expect(unmarked('می‌خواهم'), 'می‌خواهم');
    expect(unmarked('👩‍💻'), '👩‍💻');
    expect(unmarked('plain'), 'plain');
  });

  test('strips controls from a message and its names', () {
    final sent = {
      'm': marked,
      'h': 'aaa-bbb-ccc',
      'fn': '\u202egpj.exe',
      'q': 'uid1',
      'gc': {'t': 'rename', 'n': '\u2067group\u2069'},
      'i': 'AAAA',
    };
    final env = unwrapMessage('halo/1:${jsonEncode(sent)}');
    expect(env.message, 'one two three four');
    expect(env.fileName, 'gpj.exe');
    expect(env.groupControl!.name, 'group');
    expect(env.imageB64, 'AAAA');
    // the proof of work was done over what was sent
    expect(env.powText, marked);
  });

  test('strips controls escaped in the json', () {
    final raw = 'halo/1:{"m":"\\u2068abc\\u2069","h":"x"}';
    expect(unwrapMessage(raw).message, 'abc');
    expect(unwrapMessage('plain \u2066text').message, 'plain text');
  });

  test('a paste strips them and keeps the caret', () {
    const f = UnmarkedInput();
    final v = f.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: marked,
        selection: TextSelection.collapsed(offset: 9),
      ),
    );
    expect(v.text, 'one two three four');
    expect(v.selection.baseOffset, 6);
  });

  test('translations use one isolate shape', () {
    // one shape for every isolate in the translations (bidi_safe.dart)
    final one = RegExp(r'(?:\u2066|\u2068)@?\{\w+\}\u2069');
    final opener = RegExp(r'[\u2066-\u2068]');
    final beside = RegExp(r'^[\s\p{P}\p{Script=Arabic}]$', unicode: true);
    final bad = <String>[];
    for (final f in Directory('lib/l10n').listSync()) {
      if (!f.path.endsWith('.arb')) continue;
      final arb = jsonDecode(File(f.path).readAsStringSync()) as Map;
      for (final e in arb.entries) {
        final v = e.value;
        if (e.key.startsWith('@') || v is! String) continue;
        final found = one.allMatches(v).toList();
        if (found.length != opener.allMatches(v).length) {
          bad.add(e.key);
          continue;
        }
        for (final m in found) {
          final before = m.start == 0 ? ' ' : v[m.start - 1];
          final after = m.end == v.length ? ' ' : v[m.end];
          if (!beside.hasMatch(before) || !beside.hasMatch(after)) {
            bad.add(e.key);
          }
        }
      }
    }
    expect(bad, isEmpty);
  });
}
