// SPDX-License-Identifier: GPL-3.0-or-later
// a file handed to the share sheet or opened with another app is a plain
// copy in the cache. the app it went to may read it only after this one is
// back, or after a restart, so a copy is shredded once it is past the grace
// and not before: at start as on resume, on both sides
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show kShareGrace, sweepShareCopies;

import 'shred_twin.dart';
import 'source_body.dart';

void main() {
  late Directory cache;
  late Directory twins;
  setUp(() {
    cache = Directory.systemTemp.createTempSync('share_sweep');
    twins = Directory.systemTemp.createTempSync('share_twins');
  });
  tearDown(() {
    cache.deleteSync(recursive: true);
    twins.deleteSync(recursive: true);
  });

  final now = DateTime(2026, 10, 10, 12);
  File copy(String rel, String what, Duration age) =>
      File('${cache.path}/share_plus/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(what)
        ..setLastModifiedSync(now.subtract(age));

  test('an old copy is shredded and the rest of the cache stays', () async {
    final shared = copy('statement.pdf', 'a decrypted file', kShareGrace * 2);
    final nested = copy('x/kryfo-backup.kryfo', 'a backup', kShareGrace * 2);
    final a = twinOf(shared.path, twins);
    final b = twinOf(nested.path, twins);
    final other = File('${cache.path}/vn_1.wav')..writeAsStringSync('keep');
    await sweepShareCopies(cache, now: now);
    expect(shared.existsSync(), isFalse);
    expect(nested.existsSync(), isFalse);
    expect(zeroed(a), isTrue);
    expect(zeroed(b), isTrue);
    expect(Directory('${cache.path}/share_plus').existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('a copy still in its grace stays, whole, at start', () async {
    final young = copy('y/photo.jpg', 'still being read', kShareGrace ~/ 2);
    final old = copy('o/photo.jpg', 'read long ago', kShareGrace * 2);
    await sweepShareCopies(cache, now: now);
    expect(young.readAsStringSync(), 'still being read');
    expect(old.existsSync(), isFalse);
    // the emptied folder goes, the one still holding a copy stays
    expect(Directory('${cache.path}/share_plus/o').existsSync(), isFalse);
    expect(Directory('${cache.path}/share_plus/y').existsSync(), isTrue);
  });

  test('nothing shared, nothing to do', () async {
    await sweepShareCopies(cache, now: now);
    expect(cache.listSync(), isEmpty);
  });

  test('the start sweep runs it', () {
    final body = bodyOf(
      sourceOf('lib/main.dart'),
      'Future<void> sweepCaptures(',
    );
    expect(body, contains('await sweepShareCopies(tmp)'));
  });

  group('android', () {
    const kt = 'android/app/src/main/kotlin/app/kryfo';

    test('start keeps a young copy and shreds an old one', () {
      final app = sourceOf('$kt/HaloApplication.kt');
      expect(app, contains('Shred.handed(cacheDir)'));
      expect(app, isNot(contains('deleteRecursively')));
      final shred = sourceOf('$kt/Shred.kt');
      expect(shred, contains('val HANDED = listOf("open", "share_plus")'));
      expect(shred, contains('const val GRACE_MS = 10 * 60 * 1000L'));
      expect(kShareGrace, const Duration(minutes: 10));
      final aged = bodyOf(shred, 'fun aged(');
      expect(aged, contains('if (f.lastModified() < cutoff) {'));
      expect(aged, contains('file(f)'));
      expect(aged, contains('young = true'));
      // a shred is zeros written and synced before the unlink
      final file = bodyOf(shred, 'fun file(');
      expect(file, contains('raf.write(zeros, 0, n)'));
      expect(file, contains('raf.fd.sync()'));
    });

    test('resume does the same, and looks again while one is young', () {
      final act = sourceOf('$kt/MainActivity.kt');
      final clear = bodyOf(act, 'private fun clearOpenCopies(');
      expect(clear, contains('Shred.handed(cacheDir)'));
      expect(
        clear,
        contains('shareTimer.postDelayed(shareSweep, shareGraceMs)'),
      );
      expect(act, isNot(contains('deleteRecursively')));
      // a new open never writes over, or shreds, a copy still in its grace
      final open = bodyOf(act, 'private fun openFile(');
      expect(open, contains('Shred.aged(open, '));
      expect(open, contains('val dir = File(open, rnd)'));
    });

    test('the tools shred their copies, and a result waits out its age', () {
      final tools = sourceOf('$kt/ToolsBridge.kt');
      expect(tools, isNot(contains('deleteRecursively')));
      final sweep = bodyOf(tools, 'fun sweep(');
      expect(
        sweep,
        contains('if (old || (all && name == IN_DIR)) Shred.tree(f)'),
      );
    });
  });
}
