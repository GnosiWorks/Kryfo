// SPDX-License-Identifier: GPL-3.0-or-later
// the listener service is started only when it is not up: a start of one
// that is up posts its notification again, on every resume and every job
// run. read off the kotlin source, which has no tests of its own.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _dir = 'android/app/src/main/kotlin/app/kryfo';

// the source without its comments
String _code(String file) => File('$_dir/$file')
    .readAsStringSync()
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'//.*'), ''))
    .join('\n');

// the body of [fun], braces counted
String _body(String code, String fun) {
  final at = code.indexOf(fun);
  expect(at, isNot(-1), reason: fun);
  final open = code.indexOf('{', at);
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if (code[i] == '{') depth++;
    if (code[i] == '}' && --depth == 0) return code.substring(open, i + 1);
  }
  fail('no end to $fun');
}

void main() {
  test('the service says when it is up', () {
    final s = _code('HaloListenerService.kt');
    expect(s, contains('var running = false'));
    expect(_body(s, 'fun onStartCommand'), contains('running = true'));
    expect(_body(s, 'fun onDestroy'), contains('running = false'));
  });

  test('a resume leaves a running service alone', () {
    final resume = _body(_code('MainActivity.kt'), 'override fun onResume');
    final start = RegExp(r'^\s*(.*)startListenerService\(\)', multiLine: true);
    final calls = start.allMatches(resume).toList();
    expect(calls, isNotEmpty);
    for (final c in calls) {
      expect(c.group(1), contains('!HaloListenerService.running'));
    }
  });

  test('the periodic job leaves a running service alone', () {
    final job = _body(
      _code('HaloPeriodicJobService.kt'),
      'override fun onStartJob',
    );
    expect(job, contains('HaloListenerService.running'));
    expect(job, contains('if (staysOn && !up)'));
  });
}
