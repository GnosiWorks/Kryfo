// SPDX-License-Identifier: GPL-3.0-or-later
// screens reach only the open session, never the everyday database or
// identity under it, and send nothing from a quiet session. read off the
// source, so a new screen that forgets fails here.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

List<File> _uiFiles() => [
  for (final dir in ['lib/screens', 'lib/widgets'])
    ...Directory(
      dir,
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
];

List<File> _libFiles() => [
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart')) f,
];

// the source with its comments dropped and its strings kept, so a word in
// a comment is not a use
String _code(String src) {
  final out = StringBuffer();
  var i = 0;
  while (i < src.length) {
    if (src.startsWith('//', i)) {
      final end = src.indexOf('\n', i);
      i = end < 0 ? src.length : end;
      continue;
    }
    if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      i = end < 0 ? src.length : end + 2;
      out.write(' ');
      continue;
    }
    final c = src[i];
    if (c == "'" || c == '"') {
      final q = src.startsWith(c * 3, i) ? c * 3 : c;
      final raw = i > 0 && src[i - 1] == 'r';
      var j = i + q.length;
      while (j < src.length && !src.startsWith(q, j)) {
        if (q.length == 1 && src[j] == '\n') break;
        if (!raw && src[j] == r'\') j++;
        j++;
      }
      j = min(j + q.length, src.length);
      out.write(src.substring(i, j));
      i = j;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

// what Session declares, read off its class: a member starts two spaces in
Set<String> _sessionMembers() {
  final src = _code(File('lib/session.dart').readAsStringSync());
  final start = src.indexOf('class Session {');
  final end = src.indexOf('\n}', start);
  final accessor = RegExp(r'\b(?:get|set)\s+(\w+)');
  final field = RegExp(
    r'^(?:static\s+)?(?:final|const|late|var)\b[^=;(]*?(\w+)\s*[=;]',
  );
  final method = RegExp(r'(\w+)\s*\(');
  final names = <String>{};
  for (final line in src.substring(start, end).split('\n')) {
    if (!RegExp(r'^  [A-Za-z_]').hasMatch(line)) continue;
    final l = line.trim();
    final m =
        accessor.firstMatch(l) ?? field.firstMatch(l) ?? method.firstMatch(l);
    if (m != null) names.add(m.group(1)!);
  }
  return names;
}

// session.x, and a chain broken over lines. _session, x.session and a file
// name like 'session.dart' are not it
final _use = RegExp(r"""(?<![\w.$'"/])session\s*\.\s*([A-Za-z_]\w*)""");
// the databases under the session
final _under = RegExp(r'(?<![\w.$])session\s*\.\s*(?:primary|vault)\b');

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

  test('screens never name a database or the router', () {
    final bad = <String>[];
    final router = RegExp(
      r"""^\s*(?:import|export)\s+['"][^'"]*\brouter\.dart['"]""",
      multiLine: true,
    );
    for (final f in _uiFiles()) {
      final src = _code(f.readAsStringSync());
      if (RegExp(r'\bHaloDb\b').hasMatch(src)) bad.add('${f.path}: HaloDb');
      if (_under.hasMatch(src)) bad.add('${f.path}: session.primary or vault');
      if (router.hasMatch(src)) bad.add('${f.path}: router.dart');
    }
    expect(bad, isEmpty);
  });

  // the hidden chats' list, their key and what came sealed are read and
  // written in one place, so nothing else can say a vault exists
  test('only the router names its tables', () {
    final tables = RegExp(r'\b(?:hidden_chats|vault_meta|vault_inbox)\b');
    final bad = <String>[];
    for (final f in _libFiles()) {
      if (f.path == 'lib/router.dart') continue;
      final m = tables.firstMatch(_code(f.readAsStringSync()));
      if (m != null) bad.add('${f.path}: ${m.group(0)}');
    }
    expect(bad, isEmpty);
    // and the reading itself still works
    expect(
      tables.allMatches(_code(File('lib/router.dart').readAsStringSync())),
      hasLength(greaterThanOrEqualTo(3)),
    );
  });

  // a database is opened, folded, closed and read for its identity only by
  // start-up and backup; everything else asks the session
  test('only main.dart and backup.dart reach under the session', () {
    final bad = <String>[];
    for (final f in _libFiles()) {
      if (f.path == 'lib/main.dart' || f.path == 'lib/backup.dart') continue;
      if (_under.hasMatch(_code(f.readAsStringSync()))) bad.add(f.path);
    }
    expect(bad, isEmpty);
  });

  test('every session call is one Session makes', () {
    final members = _sessionMembers();
    expect(members, containsAll(['primary', 'vault', 'container']));
    for (final own in ['open', 'checkpoint', 'close', 'loadIdentity']) {
      expect(members, isNot(contains(own)), reason: 'session.primary.$own');
    }
    final used = <String, String>{};
    for (final f in _libFiles()) {
      for (final m in _use.allMatches(_code(f.readAsStringSync()))) {
        used[m.group(1)!] = f.path;
      }
    }
    // the reading itself still works
    expect(used.length, greaterThan(80));
    final missing = [
      for (final e in used.entries)
        if (!members.contains(e.key)) '${e.key} (${e.value})',
    ];
    expect(missing, isEmpty);
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
