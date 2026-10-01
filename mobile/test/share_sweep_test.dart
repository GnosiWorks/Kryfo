// SPDX-License-Identifier: GPL-3.0-or-later
// a file handed to the share sheet is a plain copy in the share plugin's
// folder. it goes at every start, and once it is a few minutes old when the
// app comes back to the front, not at the next share
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show sweepShareCopies;

import 'source_body.dart';

void main() {
  late Directory cache;
  setUp(() => cache = Directory.systemTemp.createTempSync('share_sweep'));
  tearDown(() => cache.deleteSync(recursive: true));

  test('the shared copies go and the rest of the cache stays', () async {
    final shared = File('${cache.path}/share_plus/statement.pdf')
      ..createSync(recursive: true)
      ..writeAsStringSync('a decrypted file');
    final nested = File('${cache.path}/share_plus/x/kryfo-backup.kryfo')
      ..createSync(recursive: true)
      ..writeAsStringSync('a backup');
    final other = File('${cache.path}/vn_1.wav')..writeAsStringSync('keep');
    await sweepShareCopies(cache);
    expect(shared.existsSync(), isFalse);
    expect(nested.existsSync(), isFalse);
    expect(Directory('${cache.path}/share_plus').existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('nothing shared, nothing to do', () async {
    await sweepShareCopies(cache);
    expect(cache.listSync(), isEmpty);
  });

  test('the start sweep runs it', () {
    final body = bodyOf(
      sourceOf('lib/main.dart'),
      'Future<void> sweepCaptures(',
    );
    expect(body, contains('await sweepShareCopies(tmp)'));
  });

  test('android clears it at every start, and on resume once it is old', () {
    const kt = 'android/app/src/main/kotlin/app/kryfo';
    final act = sourceOf('$kt/MainActivity.kt');
    final clear = bodyOf(act, 'private fun clearOpenCopies(');
    expect(clear, contains('clearShareCopies()'));
    // a target that reads its copy after this app is back still finds it
    expect(clear, isNot(contains('"share_plus").deleteRecursively()')));
    final aged = bodyOf(act, 'private fun clearAgedShareCopies(');
    expect(aged, contains('if (f.lastModified() < cutoff) {'));
    expect(aged, contains('young = true'));
    // and what is left young is looked at again once it is not
    final sweep = bodyOf(act, 'private fun clearShareCopies(');
    expect(sweep, contains('shareTimer.postDelayed(shareSweep, shareGraceMs)'));
    expect(
      sourceOf('$kt/HaloApplication.kt'),
      contains('File(cacheDir, "share_plus").deleteRecursively()'),
    );
  });
}
