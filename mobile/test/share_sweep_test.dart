// SPDX-License-Identifier: GPL-3.0-or-later
// a file shared or opened with another app is a plain copy in the cache,
// made by this app and handed over by its own provider. the app it went to
// may read it only after this one is back, or after a restart, so a copy is
// shredded once it is past the grace and not before, by a job that comes
// back while one is young. a time far ahead is a clock that moved and counts
// as old. an open copy also goes with a lock, a switch of pin or a wipe
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart' show PinResult;
import 'package:kryfo/main.dart'
    show containerFor, kShareGrace, sweepShareCopies;

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

  final now = DateTime.now();
  // the copy and the folders made for it, all written [age] ago
  File copy(String rel, String what, Duration age, {String top = 'share'}) {
    final f = File('${cache.path}/$top/$rel')
      ..createSync(recursive: true)
      ..writeAsStringSync(what)
      ..setLastModifiedSync(now.subtract(age));
    for (var d = f.parent; d.path != '${cache.path}/$top'; d = d.parent) {
      d.age(now.subtract(age));
    }
    return f;
  }

  test('an old copy is shredded and the rest of the cache stays', () async {
    final shared = copy('statement.pdf', 'a decrypted file', kShareGrace * 2);
    final nested = copy(
      'x/kryfo-backup.kryfo',
      'a backup',
      kShareGrace * 2,
      top: 'share_plus',
    );
    final a = twinOf(shared.path, twins);
    final b = twinOf(nested.path, twins);
    final other = File('${cache.path}/vn_1.wav')..writeAsStringSync('keep');
    await sweepShareCopies(cache, now: now);
    expect(shared.existsSync(), isFalse);
    expect(nested.existsSync(), isFalse);
    expect(zeroed(a), isTrue);
    expect(zeroed(b), isTrue);
    expect(Directory('${cache.path}/share').existsSync(), isFalse);
    expect(Directory('${cache.path}/share_plus').existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('a copy still in its grace stays, whole, at start', () async {
    final young = copy('y/photo.jpg', 'still being read', kShareGrace ~/ 2);
    final old = copy('o/photo.jpg', 'read long ago', kShareGrace * 2);
    await sweepShareCopies(cache, now: now);
    expect(young.readAsStringSync(), 'still being read');
    expect(old.existsSync(), isFalse);
    expect(Directory('${cache.path}/share/o').existsSync(), isFalse);
    expect(Directory('${cache.path}/share/y').existsSync(), isTrue);
  });

  test('a folder made just now for a copy on its way stays', () async {
    final fresh = Directory('${cache.path}/share/ab12')
      ..createSync(recursive: true);
    await sweepShareCopies(cache, now: now);
    expect(fresh.existsSync(), isTrue);
  });

  test('a copy dated in the future is a clock that moved: it goes', () async {
    final ahead = copy(
      'z/photo.jpg',
      'kept forever?',
      -const Duration(days: 2),
    );
    final twin = twinOf(ahead.path, twins);
    await sweepShareCopies(cache, now: now);
    expect(ahead.existsSync(), isFalse);
    expect(zeroed(twin), isTrue);
  });

  test('a link is unlinked and what it points at stays', () async {
    final outside = File('${twins.path}/kept.txt')..writeAsStringSync('keep');
    Directory('${cache.path}/share').createSync();
    final link = Link('${cache.path}/share/l')..createSync(outside.path);
    await sweepShareCopies(cache, now: now);
    expect(link.existsSync(), isFalse);
    expect(outside.readAsStringSync(), 'keep');
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

  test('every file goes out through a copy of ours, none the plugin '
      'drops unzeroed', () {
    for (final f in [
      'lib/contact_card.dart',
      'lib/widgets/video_bubble.dart',
      'lib/screens/backup_screen.dart',
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      final src = sourceOf(f);
      expect(src, contains('shareFileOut('), reason: f);
      expect(src, isNot(contains('files: [')), reason: f);
    }
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      expect(e.readAsStringSync(), isNot(contains('files: [XFile')));
    }
  });

  test('a lock and an unlock unlink a handed copy; a switch of pin and a '
      'wipe shred it', () {
    final main = sourceOf('lib/main.dart');
    final lock = bodyOf(main, 'void lockingUp(');
    expect(lock, contains('unawaited(dropOpenCopies());'));
    expect(
      lock,
      contains('_lockedIn = (_session.vault ?? _session.primary).container;'),
    );
    final unlock = bodyOf(main, 'Future<void> _sessionFor(');
    expect(
      unlock,
      contains(
        'all: from != null && from != containerFor(r, vaultKey: vaultKey)',
      ),
    );
    // a wipe shreds them with every other plaintext (wipe_order_test)
    expect(
      bodyOf(sourceOf('lib/wipe.dart'), 'Future<void> _erase('),
      contains('entry.rename('),
    );
  });

  test('an unlock knows the side it opens', () {
    expect(containerFor(PinResult.normal), HaloContainer.everyday);
    expect(containerFor(PinResult.decoy), HaloContainer.decoy);
    expect(containerFor(PinResult.vault, vaultKey: 'k'), HaloContainer.vault);
    expect(
      containerFor(PinResult.decoy, vaultKey: 'k'),
      HaloContainer.decoyVault,
    );
  });

  test('a backup goes out on a rule of its own', () {
    const kt = 'android/app/src/main/kotlin/app/kryfo';
    final shred = sourceOf('$kt/Shred.kt');
    expect(shred, contains('const val BACKUP_OUT = "backup_out"'));
    expect(shred, contains('const val BACKUP_KEEP_MS = 24 * 60 * 60 * 1000L'));
    final drop = bodyOf(shred, 'fun dropBackups(');
    expect(drop, contains('for (e in bottomUp(f)) e.delete()'));
    expect(drop, isNot(contains('file(')));
    final act = sourceOf('$kt/MainActivity.kt');
    final out = bodyOf(act, 'private fun handOut(');
    expect(out, contains('Shred.dropBackups(cacheDir, true)'));
    expect(out, contains('if (!backup) JobSetup.scheduleCopySweep(this)'));
    expect(
      bodyOf(act, 'private fun shareFile('),
      contains('handOut(File(path), name, Shred.shareInto(backup, quiet))'),
    );
    final into = bodyOf(shred, 'fun shareInto(');
    expect(into, contains('backup -> BACKUP_OUT'));
    expect(into, contains('quiet -> SHARE_QUIET'));
    expect(into, contains('else -> "share"'));
    expect(shred, contains('const val SHARE_QUIET = "share_q"'));
    expect(
      sourceOf('android/app/src/main/res/xml/open_paths.xml'),
      contains('<cache-path name="share_q" path="share_q/" />'),
    );
    expect(
      sourceOf('lib/open_file.dart'),
      contains("'quiet': !backup && shareGoesWithLock(),"),
    );
    expect(
      sourceOf('lib/main.dart'),
      contains(
        'shareGoesWithLock = () => sessionQuiet || session.vault != null;',
      ),
    );
    expect(
      sourceOf('$kt/HaloApplication.kt'),
      contains('Shred.dropBackups(cacheDir, false)'),
    );
    expect(
      sourceOf('android/app/src/main/res/xml/open_paths.xml'),
      contains('<cache-path name="backup_out" path="backup_out/" />'),
    );
    expect(
      sourceOf('lib/screens/backup_screen.dart'),
      contains('backup: true,'),
    );
  });

  group('android', () {
    const kt = 'android/app/src/main/kotlin/app/kryfo';

    test('start keeps a young copy and shreds an old one', () {
      final app = sourceOf('$kt/HaloApplication.kt');
      expect(
        app,
        contains(
          'if (Shred.handed(cacheDir)) JobSetup.scheduleCopySweep(this)',
        ),
      );
      expect(app, isNot(contains('deleteRecursively')));
      final shred = sourceOf('$kt/Shred.kt');
      expect(
        shred,
        contains(
          'val HANDED = listOf("open", "share", "share_plus", SHARE_QUIET)',
        ),
      );
      expect(shred, contains('const val GRACE_MS = 10 * 60 * 1000L'));
      expect(kShareGrace, const Duration(minutes: 10));
      // a clock that moved ahead does not keep a copy young
      expect(shred, contains('at < cutoff || at > now + SKEW_MS'));
      final aged = bodyOf(shred, 'fun aged(');
      expect(aged, contains('val made = all.associateWith'));
      expect(aged, contains('} else if (old(at, cutoff, now)) {'));
      expect(aged, contains('young = true'));
      // links are unlinked, never followed
      final walk = bodyOf(shred, 'private fun bottomUp(');
      expect(walk, contains('if (!isLink(f) && f.isDirectory)'));
      final file = bodyOf(shred, 'fun file(');
      expect(file, contains('raf.write(zeros, 0, n)'));
      expect(file, contains('raf.fd.sync()'));
      expect(file, contains('} finally {'));
    });

    test('resume and a hand-out leave the rest to a job, not a timer', () {
      final act = sourceOf('$kt/MainActivity.kt');
      expect(act, isNot(contains('postDelayed(shareSweep')));
      expect(act, isNot(contains('deleteRecursively')));
      expect(
        bodyOf(act, 'private fun clearOpenCopies('),
        contains('JobSetup.scheduleCopySweep(this)'),
      );
      final out = bodyOf(act, 'private fun handOut(');
      expect(out, contains('Shred.aged(top, '));
      expect(out, contains('val dir = File(top, rnd)'));
      expect(out, contains('Shred.tree(dir)'));
      expect(out, contains('JobSetup.scheduleCopySweep(this)'));
      final job = sourceOf('$kt/CopySweepJobService.kt');
      expect(job, contains('val young = Shred.handed(cacheDir)'));
      expect(job, contains('if (young) JobSetup.scheduleCopySweep(this)'));
      expect(
        sourceOf('android/app/src/main/AndroidManifest.xml'),
        contains('android:name=".CopySweepJobService"'),
      );
      expect(
        sourceOf('android/app/src/main/res/xml/open_paths.xml'),
        contains('<cache-path name="share" path="share/" />'),
      );
    });

    test('a copy no app was handed is shredded at once', () {
      final act = sourceOf('$kt/MainActivity.kt');
      for (final sig in ['private fun openFile(', 'private fun shareFile(']) {
        final body = bodyOf(act, sig);
        expect(body, contains('handOut(File(path), name, '), reason: sig);
        expect(
          'Shred.tree(dst.parentFile!!)'.allMatches(body).length,
          greaterThanOrEqualTo(2),
          reason: sig,
        );
      }
      expect(
        bodyOf(act, 'private fun openFile('),
        contains('} catch (e: ActivityNotFoundException) {'),
      );
    });

    test('the tools shred off the ui thread, and a result waits its age', () {
      final tools = sourceOf('$kt/ToolsBridge.kt');
      expect(tools, isNot(contains('deleteRecursively')));
      final sweep = bodyOf(tools, 'fun sweep(');
      expect(sweep, contains('Shred.old(f.lastModified(), now - MAX_AGE_MS'));
      expect(
        sweep,
        contains('if (old || (all && name == IN_DIR)) Shred.tree(f)'),
      );
      final call = tools.substring(tools.indexOf('"sweep" -> {'));
      expect(call.substring(0, call.indexOf('"sdk" ->')), contains('Thread {'));
    });

    test('a shrink runs off the ui thread', () {
      final act = sourceOf('$kt/MainActivity.kt');
      final call = act.substring(act.indexOf('"shrinkJpeg" -> {'));
      expect(
        call.substring(0, call.indexOf('"saveToPictures" ->')),
        contains('Thread {'),
      );
    });
  });
}

extension on Directory {
  void age(DateTime t) {
    final r = Process.runSync('touch', ['-d', t.toIso8601String(), path]);
    if (r.exitCode != 0) throw StateError('touch: ${r.stderr}');
  }
}
