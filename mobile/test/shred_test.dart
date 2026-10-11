// SPDX-License-Identifier: GPL-3.0-or-later
// a shred writes zeros over the bytes where they are, over the whole
// length, and the name goes even when a write cannot. a link is unlinked,
// never followed: what it points at is not ours to zero. the files are
// real ones in a scratch folder
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/shred.dart';

import 'shred_twin.dart';
import 'source_body.dart';

void main() {
  late Directory tmp;
  late Directory twins;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('shred');
    twins = Directory.systemTemp.createTempSync('shred_twins');
  });
  tearDown(() {
    for (final d in [tmp, twins]) {
      Process.runSync('chmod', ['-R', 'u+rwx', d.path]);
      d.deleteSync(recursive: true);
    }
  });

  File big(String name) => File('${tmp.path}/$name')
    ..writeAsBytesSync(List.generate(200000, (i) => i % 251 + 1), flush: true);

  test('the length holds through the overwrite', () async {
    final f = big('a.jpg');
    final seen = <int>[];
    await shredFile(f.path, probe: seen.add);
    expect(seen, isNotEmpty);
    expect(seen.toSet(), {200000});
    expect(f.existsSync(), isFalse);
  });

  test('the zeros land in the blocks the bytes were in', () async {
    final f = big('b.jpg');
    final twin = twinOf(f.path, twins);
    final at = extentsOf(twin.path);
    if (at == null) {
      markTestSkipped('no filefrag on this file system');
      return;
    }
    await shredFile(f.path);
    expect(twin.lengthSync(), 200000);
    expect(extentsOf(twin.path), at);
    expect(zeroed(twin), isTrue);
  });

  test('a file that cannot be written still loses its name', () async {
    final f = big('c.jpg');
    Process.runSync('chmod', ['a-w', f.path]);
    await shredFile(f.path);
    expect(f.existsSync(), isFalse);
  });

  test('a link is unlinked and what it points at stays', () async {
    final outside = File('${twins.path}/kept.jpg')..writeAsStringSync('keep');
    final keptDir = Directory('${twins.path}/dir')..createSync();
    final inDir = File('${keptDir.path}/x.jpg')..writeAsStringSync('keep');
    final link = Link('${tmp.path}/l.jpg')..createSync(outside.path);
    await shredFile(link.path);
    expect(link.existsSync(), isFalse);
    expect(outside.readAsStringSync(), 'keep');
    final folder = Directory('${tmp.path}/t')..createSync();
    Link('${folder.path}/to_dir').createSync(keptDir.path);
    Link('${folder.path}/to_file').createSync(outside.path);
    await shredTree(folder.path);
    expect(folder.existsSync(), isFalse);
    expect(inDir.readAsStringSync(), 'keep');
    expect(outside.readAsStringSync(), 'keep');
  });

  test('no shred opens a file in a mode that truncates', () {
    final dart = sourceOf('lib/shred.dart');
    expect(dart, isNot(contains('FileMode.writeOnly')));
    expect(dart, isNot(contains('FileMode.write)')));
    expect(dart, contains('mode: FileMode.append'));
    expect(dart, contains('await raf.setPosition(0);'));
    final kt = sourceOf('android/app/src/main/kotlin/app/kryfo/Shred.kt');
    expect(kt, contains('RandomAccessFile(f, "rw")'));
    expect(kt, isNot(contains('setLength')));
    expect(kt, isNot(contains('FileOutputStream')));
  });

  group('open copies', () {
    File copy(String rel, String what, Duration age) {
      final f = File('${tmp.path}/open/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(what, flush: true)
        ..setLastModifiedSync(DateTime.now().subtract(age));
      return f;
    }

    test(
      'a lock unlinks one still being read: the reader keeps its bytes',
      () async {
        final f = copy('ab12/statement.pdf', 'a decrypted file', Duration.zero);
        final reader = f.openSync();
        addTearDown(reader.closeSync);
        await dropOpenCopies(cache: tmp);
        expect(f.existsSync(), isFalse);
        expect(Directory('${tmp.path}/open').existsSync(), isFalse);
        expect(String.fromCharCodes(reader.readSync(64)), 'a decrypted file');
      },
    );

    test('a lock shreds one past its grace', () async {
      final f = copy('cd34/old.pdf', 'read long ago', kHandedGrace * 2);
      final twin = twinOf(f.path, twins);
      await dropOpenCopies(cache: tmp);
      expect(f.existsSync(), isFalse);
      expect(zeroed(twin), isTrue);
    });

    test('a switch of pin or a wipe shreds every one', () async {
      final f = copy('ef56/now.pdf', 'just opened', Duration.zero);
      final twin = twinOf(f.path, twins);
      await dropOpenCopies(all: true, cache: tmp);
      expect(Directory('${tmp.path}/open').existsSync(), isFalse);
      expect(zeroed(twin), isTrue);
    });
  });

  group('shared copies', () {
    File copy(String top, String what, Duration age) {
      final f = File('${tmp.path}/$top/9a8b/photo.jpg')
        ..createSync(recursive: true)
        ..writeAsStringSync(what, flush: true)
        ..setLastModifiedSync(DateTime.now().subtract(age));
      return f;
    }

    for (final top in ['share', 'share_plus']) {
      test('$top: a lock unlinks one still being read and shreds an old one, '
          'the rest of the cache stays', () async {
        final young = copy(top, 'sent just now', Duration.zero);
        final reader = young.openSync();
        addTearDown(reader.closeSync);
        final old = File('${tmp.path}/$top/7c6d/old.jpg')
          ..createSync(recursive: true)
          ..writeAsStringSync('sent long ago', flush: true)
          ..setLastModifiedSync(DateTime.now().subtract(kHandedGrace * 2));
        final twin = twinOf(old.path, twins);
        final other = File('${tmp.path}/vn_1.wav')..writeAsStringSync('keep');
        await dropOpenCopies(cache: tmp);
        expect(Directory('${tmp.path}/$top').existsSync(), isFalse);
        expect(String.fromCharCodes(reader.readSync(64)), 'sent just now');
        expect(zeroed(twin), isTrue);
        expect(other.existsSync(), isTrue);
      });

      test('$top: a switch of pin or a wipe shreds every one', () async {
        final f = copy(top, 'sent just now', Duration.zero);
        final twin = twinOf(f.path, twins);
        await dropOpenCopies(all: true, cache: tmp);
        expect(Directory('${tmp.path}/$top').existsSync(), isFalse);
        expect(zeroed(twin), isTrue);
      });
    }
  });
}
