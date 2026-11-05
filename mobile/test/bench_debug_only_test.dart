// SPDX-License-Identifier: GPL-3.0-or-later
// the reliability harness's sender exists in debug and profile builds only,
// and what it logs is times and counts
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _app = 'android/app';

void main() {
  test('the receiver is in the debug and profile manifests only', () {
    for (final t in ['debug', 'profile']) {
      final m = File('$_app/src/$t/AndroidManifest.xml').readAsStringSync();
      expect(m, contains('android:name="app.kryfo.BenchReceiver"'), reason: t);
      expect(
        m,
        contains('android:permission="android.permission.DUMP"'),
        reason: t,
      );
    }
    final main = File('$_app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(main, isNot(contains('Bench')));
  });

  test('its kotlin is a source of debug and profile builds only', () {
    final g = File('$_app/build.gradle.kts').readAsStringSync();
    final dirs = RegExp(
      r'getByName\("(\w+)"\)\.java\.srcDir\("src/bench/kotlin"\)',
    ).allMatches(g).map((x) => x.group(1)).toSet();
    expect(dirs, {'debug', 'profile'});
    expect(RegExp('src/bench').allMatches(g).length, 2);
    for (final f in Directory('$_app/src').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.kt')) continue;
      if (!f.readAsStringSync().contains('kryfo/bench')) continue;
      expect(f.path, startsWith('$_app/src/bench/'));
    }
  });

  test('every way in stops in a release build', () {
    final s = File('lib/app/state_bench.dart').readAsStringSync();
    for (final fn in [
      'void benchLog(',
      'void benchListen(',
      'Future<bool> benchSend(',
      'void benchGot(',
    ]) {
      final at = s.indexOf(fn);
      expect(at, isNot(-1), reason: fn);
      final body = s.substring(
        at,
        s.indexOf('\n', s.indexOf('{', at) + 1) + 80,
      );
      expect(body, contains('kReleaseMode'), reason: fn);
    }
  });

  test('its lines carry times and counts, no words, names or ids', () {
    final s = File('lib/app/state_bench.dart').readAsStringSync();
    final lines = RegExp(
      r"benchLog\(\s*'([^']*)'",
    ).allMatches(s).map((x) => x.group(1)!).toList();
    expect(lines, isNotEmpty);
    for (final l in lines) {
      for (final v in RegExp(r'\$\{?([a-zA-Z_.]+)').allMatches(l)) {
        expect(
          {'n', 'wrote', 'ok', 'DateTime.now'},
          contains(v.group(1)),
          reason: l,
        );
      }
    }
    final kt = File(
      '$_app/src/bench/kotlin/app/kryfo/BenchReceiver.kt',
    ).readAsStringSync();
    for (final l in RegExp(r'Log\.i\(TAG, "([^"]*)"').allMatches(kt)) {
      expect(l.group(1), isNot(contains(r'$to')));
    }
  });
}
