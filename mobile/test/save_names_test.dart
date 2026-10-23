// SPDX-License-Identifier: GPL-3.0-or-later
// what kryfo saves under a plain icon looks like any phone's: the camera's
// IMG_ and VID_ names in its folder, plain words for backups, notes and
// cards, and nothing in a new name or folder that says kryfo. under
// kryfo's own icon every name and folder is the one it always was, and a
// file saved before is never moved or renamed. a restore finds a backup
// by what it holds, whatever it is called
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_icon.dart';
import 'package:kryfo/contact_card.dart' show sweepCardLeftovers;
import 'package:kryfo/notes_export.dart';
import 'package:kryfo/save_names.dart';
import 'package:path/path.dart' as p;

import 'source_body.dart';

class _Faces implements AppFaceChannel {
  AppFace face;
  _Faces(this.face);
  @override
  Future<AppFace?> read() async => face;
  @override
  Future<bool> switchTo(AppFace f) async => true;
}

final _at = DateTime(2026, 10, 24, 9, 5, 7);
final _kryfo = RegExp('kryfo', caseSensitive: false);

const _kt = 'android/app/src/main/kotlin/app/kryfo';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(forgetAppFace);

  test('a plain icon names new saves plainly, kryfo\'s as always', () async {
    // not read: kryfo's, as a read that fails gives
    forgetAppFace();
    expect(savesPlain(), isFalse);
    for (final (face, plain) in [
      (AppFace.notes, true),
      (AppFace.news, true),
      (AppFace.kryfo, false),
    ]) {
      forgetAppFace();
      appFaceChannel = _Faces(face);
      await readAppFace();
      expect(savesPlain(), plain, reason: face.name);
    }
  });

  test('plain names say nothing of kryfo', () {
    final names = [
      cameraName(video: false, plain: true, at: _at),
      cameraName(video: true, plain: true, at: _at),
      backupName(plain: true, at: _at),
      notesName(plain: true, day: '2026-10-24', ext: 'md.age'),
      cardName(plain: true, haloId: 'calm-orbit-lantern', ext: 'png'),
      cardName(plain: true, haloId: 'calm-orbit-lantern', ext: 'vcf'),
    ];
    for (final n in names) {
      expect(_kryfo.hasMatch(n), isFalse, reason: n);
    }
    expect(names[0], 'IMG_20261024_090507.jpg');
    expect(names[1], 'VID_20261024_090507.mp4');
    expect(names[2], 'backup_20261024_090507.bin');
    expect(names[3], 'notes-2026-10-24.md.age');
    expect(names[4], 'card-calm-orbit-lantern.png');
  });

  test('under kryfo\'s own icon the names are as before', () {
    final ms = _at.millisecondsSinceEpoch;
    expect(cameraName(video: false, plain: false, at: _at), 'kryfo_$ms.jpg');
    expect(cameraName(video: true, plain: false, at: _at), 'kryfo_$ms.mp4');
    expect(
      backupName(plain: false, at: _at),
      'kryfo-backup-${ms ~/ 1000}.kryfo',
    );
    expect(
      notesName(plain: false, day: '2026-10-24', ext: 'txt'),
      'kryfo-notes-2026-10-24.txt',
    );
    expect(
      cardName(plain: false, haloId: 'calm-orbit-lantern', ext: 'vcf'),
      'kryfo-calm-orbit-lantern.vcf',
    );
  });

  test('a notes export under a plain icon is named plainly', () async {
    final tmp = await Directory.systemTemp.createTemp('notes_plain');
    addTearDown(() => tmp.delete(recursive: true));
    final notes = [
      {'plaintext': 'buy bread', 'sent_at': _at.millisecondsSinceEpoch},
    ];
    final plain = await makeNotesExport(
      notes,
      format: NotesFormat.text,
      passphrase: null,
      dir: tmp,
      now: _at,
      plainName: true,
    );
    expect(plain.name, 'notes-2026-10-24.txt');
    expect(_kryfo.hasMatch(plain.name), isFalse);
    expect(_kryfo.hasMatch(p.basename(plain.path)), isFalse);
    final own = await makeNotesExport(
      notes,
      format: NotesFormat.text,
      passphrase: null,
      dir: tmp,
      now: _at,
    );
    expect(own.name, 'kryfo-notes-2026-10-24.txt');
  });

  test('every save site takes its name from here', () {
    final camera = bodyOf(
      sourceOf('lib/screens/camera_screen.dart'),
      'Future<void> _keepCopy(',
    );
    expect(camera, contains('final plain = savesPlain();'));
    expect(camera, contains('cameraName(video: false, plain: plain)'));
    expect(camera, contains('cameraName(video: true, plain: plain)'));
    expect(camera, isNot(contains("'kryfo_")));
    expect(
      sourceOf('lib/screens/backup_screen.dart'),
      contains('name = backupName(plain: savesPlain());'),
    );
    expect(
      sourceOf('lib/screens/notes_export_screen.dart'),
      contains('plainName: savesPlain(),'),
    );
    final card = sourceOf('lib/contact_card.dart');
    for (final ext in ['png', 'vcf']) {
      expect(
        card,
        contains("cardName(plain: savesPlain(), haloId: haloId, ext: '$ext')"),
      );
    }
    expect(card, isNot(contains("'kryfo-\$haloId")));
  });

  test('a card left in the cache under either name is swept', () async {
    final tmp = await Directory.systemTemp.createTemp('cards');
    addTearDown(() => tmp.delete(recursive: true));
    for (final n in [
      'kryfo-calm-orbit-lantern.png',
      'card-calm-orbit-lantern.vcf',
      'keep.txt',
    ]) {
      File(p.join(tmp.path, n)).writeAsStringSync('x');
    }
    await sweepCardLeftovers(tmp);
    expect([for (final e in tmp.listSync()) p.basename(e.path)], ['keep.txt']);
  });

  test('a restore finds a backup by what it holds, never by its name', () {
    final pick = bodyOf(
      sourceOf('lib/screens/restore_screen.dart'),
      'Future<void> _pick(',
    );
    expect(pick, contains('await isBackupV2(path)'));
    expect(pick, isNot(contains('endsWith(')));
    expect(pick, isNot(contains('extension')));
    expect(pick, isNot(contains('result.name')));
  });

  test('android puts new saves in the phone\'s own folders, moving none', () {
    final place = sourceOf('$_kt/SavePlace.kt');
    expect(
      place,
      contains('!plain -> if (video) "Movies/Kryfo" else "Pictures/Kryfo"'),
    );
    expect(place, contains('camera -> "DCIM/Camera"'));
    for (final f in ['MainActivity.kt', 'ToolsBridge.kt']) {
      final src = sourceOf('$_kt/$f');
      // the album's name only in SavePlace
      expect(src, isNot(contains('"Pictures/Kryfo"')), reason: f);
      expect(src, isNot(contains('"Movies/Kryfo"')), reason: f);
      expect(src, contains('SavePlace.folder('), reason: f);
      // a row is only ever finished, never moved or renamed
      for (final m in RegExp(
        r'contentResolver\.update\(([^)]*)\)',
      ).allMatches(src)) {
        final before = src.substring(m.start - 120, m.start);
        expect(before, contains('IS_PENDING, 0'), reason: f);
        expect(before, isNot(contains('RELATIVE_PATH, ')), reason: f);
      }
    }
    expect(
      bodyOf(sourceOf('$_kt/MainActivity.kt'), 'private fun saveToPictures('),
      contains('SavePlace.folder(this@MainActivity, video, camera = true)'),
    );
    expect(
      bodyOf(sourceOf('$_kt/ToolsBridge.kt'), 'private fun saveToGallery('),
      contains('SavePlace.folder(activity, video, camera = false)'),
    );
  });
}
