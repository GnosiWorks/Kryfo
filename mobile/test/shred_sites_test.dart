// SPDX-License-Identifier: GPL-3.0-or-later
// every file that held plaintext is zeroed before it is unlinked: a half
// received file, a decoy's or a vault's pictures when it goes, a picture
// downloaded for the gif panel, what a backup or a restore staged, and the
// tools' copies of the person's own pictures. the folders are real ones in
// a scratch folder, and a hard link shows what was left in a file's blocks
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart'
    show forgetLeftoverSweep, sweepBackupLeftovers;
import 'package:kryfo/container.dart';
import 'package:kryfo/gifs/gif_source.dart' show gifPartsDir, sweepGifParts;
import 'package:kryfo/main.dart' show saveSlices, shredTree;
import 'package:shared_preferences/shared_preferences.dart';

import 'shred_twin.dart';
import 'source_body.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory twins;

  File put(String rel, [String what = 'plaintext']) => File('${root.path}/$rel')
    ..createSync(recursive: true)
    ..writeAsStringSync(what);

  setUp(() {
    root = Directory.systemTemp.createTempSync('shred_sites');
    twins = Directory.systemTemp.createTempSync('shred_twins');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'halo.d.key': "x'${'2e' * 32}'",
    });
    forgetLeftoverSweep();
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    twins.deleteSync(recursive: true);
  });

  group('shredTree', () {
    test('zeroes every file under a folder, then the folder goes', () async {
      final a = twinOf(put('t/a.jpg').path, twins);
      final b = twinOf(put('t/deep/b.wav').path, twins);
      await shredTree('${root.path}/t');
      expect(Directory('${root.path}/t').existsSync(), isFalse);
      expect(zeroed(a) && zeroed(b), isTrue);
    });

    test(
      'a plain file is shredded on its own, a missing one is fine',
      () async {
        final a = twinOf(put('one.jpg').path, twins);
        await shredTree('${root.path}/one.jpg');
        await shredTree('${root.path}/never.jpg');
        expect(File('${root.path}/one.jpg').existsSync(), isFalse);
        expect(zeroed(a), isTrue);
      },
    );
  });

  test('a received file cut short is shredded', () async {
    final out = put('media/in_x.jpg', '');
    final twin = twinOf(out.path, twins);
    await expectLater(
      saveSlices(out, 2, (i) async => i == 0 ? 'cGxhaW50ZXh0' : null),
      throwsStateError,
    );
    expect(out.existsSync(), isFalse);
    expect(zeroed(twin), isTrue);
  });

  test("a decoy's pictures are shredded when it goes", () async {
    put('halo_d.db', 'decoy');
    final photo = twinOf(put('media_d/d.jpg').path, twins);
    final wall = twinOf(put('wallpapers_d/w.jpg').path, twins);
    final mine = put('media/a.jpg', 'everyday photo');
    await HaloContainer.decoy.wipeFiles();
    expect(Directory('${root.path}/media_d').existsSync(), isFalse);
    expect(zeroed(photo) && zeroed(wall), isTrue);
    expect(mine.readAsStringSync(), 'everyday photo');
  });

  test('a picture left from the gif panel is shredded', () async {
    final parts = await gifPartsDir();
    final f = File('${parts.path}/x.part')
      ..createSync(recursive: true)
      ..writeAsStringSync('a gif');
    final twin = twinOf(f.path, twins);
    await sweepGifParts();
    expect(parts.existsSync(), isFalse);
    expect(zeroed(twin), isTrue);
  });

  test('what a backup or a restore staged is shredded', () async {
    final staged = twinOf(put('backup_stage/media/a.jpg').path, twins);
    final restored = twinOf(put('restore_stage/media/r.jpg').path, twins);
    await sweepBackupLeftovers();
    expect(zeroed(staged) && zeroed(restored), isTrue);
  });

  test('no plain recursive delete is left where plaintext is staged', () {
    for (final f in [
      'lib/backup.dart',
      'lib/container.dart',
      'lib/gifs/gif_source.dart',
      'lib/tools/cleaner.dart',
      'lib/screens/clean_screen.dart',
      'lib/screens/photo_knows_screen.dart',
    ]) {
      expect(
        sourceOf(f),
        isNot(contains('delete(recursive: true)')),
        reason: f,
      );
      expect(sourceOf(f), isNot(contains('deleteSync(')), reason: f);
    }
  });
}
