// SPDX-License-Identifier: GPL-3.0-or-later
// screens reach only the open session, never the everyday database or
// identity under it, and send nothing from a quiet session. read off the
// source, so a new screen that forgets fails here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _uiFiles() => [
  for (final dir in ['lib/screens', 'lib/widgets'])
    ...Directory(dir).listSync().whereType<File>().where(
      (f) => f.path.endsWith('.dart'),
    ),
];

// the import of main.dart, whole, however many lines it takes
String? _mainImport(String src) {
  final m = RegExp(r"import '\.\./main\.dart'[^;]*;").firstMatch(src);
  return m?.group(0);
}

// engine calls that reach the network for the person using the screen
const _wire = [
  'engine.sendTo(',
  'engine.nostrSend(',
  'engine.sendFirstContact(',
  'engine.pairCodePublish(',
  'engine.pairCodeFetch(',
  'engine.handleClaim(',
  'engine.handleCheck(',
  'engine.handleRelease(',
  'engine.handleListing(',
  'appState.sendEdit(',
];

// the start of the member a line sits in: a declaration two spaces in
final _member = RegExp(
  r'^  (?:static |@override)?\s*(?:Future|void|Widget|String|bool|int|[A-Z]\w*)[^=;]*\(',
);

void main() {
  test('screens never name the everyday database', () {
    final bad = <String>[];
    for (final f in _uiFiles()) {
      final imp = _mainImport(f.readAsStringSync());
      if (imp == null) continue;
      final words = imp.replaceAll(RegExp(r'\s+'), ' ');
      final shows = RegExp(r' show (.*);').firstMatch(words)?.group(1);
      final hides = RegExp(r' hide (.*);').firstMatch(words)?.group(1);
      final ok = shows != null
          ? !shows.split(',').map((s) => s.trim()).contains('live')
          : (hides ?? '').split(',').map((s) => s.trim()).contains('live');
      if (!ok) bad.add(f.path);
    }
    expect(bad, isEmpty, reason: 'show a list without live, or hide live');
  });

  test('screens show the session identity', () {
    final bad = <String>[];
    for (final f in _uiFiles()) {
      final src = f.readAsStringSync();
      for (final w in [
        'engine.myXPubkey(',
        'engine.myEdPubkey(',
        'engine.myId(',
        'buildHaloUriV3(',
        'makePreKeyBundleB64(',
        'appState.myId',
        'appState.myOnion',
      ]) {
        if (src.contains(w)) bad.add('${f.path}: $w');
      }
    }
    expect(bad, isEmpty);
  });

  test('screen sends check for a quiet session', () {
    final bad = <String>[];
    for (final f in _uiFiles()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!_wire.any(lines[i].contains)) continue;
        if (lines[i].trimLeft().startsWith('//')) continue;
        var asked = false;
        for (var j = i; j >= 0; j--) {
          if (lines[j].contains('sessionQuiet')) {
            asked = true;
            break;
          }
          if (j < i && _member.hasMatch(lines[j])) break;
        }
        if (!asked) bad.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(bad, isEmpty);
  });
}
