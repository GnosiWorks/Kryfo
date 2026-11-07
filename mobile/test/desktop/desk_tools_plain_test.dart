// SPDX-License-Identifier: GPL-3.0-or-later
// the tools on a computer write nothing plain into kryfo's folder: after
// each tool's run the data folder is walked as the disk holds it. windows
// keeps its tmp there (sealed under the run's key), so it is the case
// tested: a cleaned photo or video and a pasted picture are sealed, a
// locked file is age's ciphertext, and an opened one, a cleaned copy saved
// and a qr saved are only at the place picked
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_paths.dart';
import 'package:kryfo/desktop/desktop_save.dart';
import 'package:kryfo/desktop/desktop_start.dart' show clearFolder;
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_native.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/tools/age_ffi.dart';
import 'package:kryfo/tools/cleaner.dart';
import 'package:kryfo/tools/desk_tools.dart';
import 'package:kryfo/tools/qr_payload.dart';
import 'package:kryfo/tools/qr_png.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../host_engine.dart';
import 'sealed_file_test.dart' show ToyCrypto;

Uint8List _k(int b) => Uint8List.fromList(List.filled(32, b));

const _pass = 'correct-horse-battery-staple';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = loadHostEngine();
  late Directory root, home;
  late SealedIO io;
  late String picked;

  setUp(() {
    root = Directory.systemTemp.createTempSync('desk_tools_data');
    home = Directory.systemTemp.createTempSync('desk_tools_home');
    final tmp = p.join(root.path, 'tmp');
    final areas = SealedAreas(
      docs: p.join(root.path, 'docs'),
      support: p.join(root.path, 'support'),
      tmp: tmp,
    )..sessionKey = _k(7);
    io = SealedIO(areas, ToyCrypto());
    PathProviderPlatform.instance = DesktopPaths(root.path);
    onDesktop = true;
    lockState.openForTest();
    isolateRunner = <R>(f) => runSealed(f);
    nativeFiles = <T>(ins, outs, run, ok) =>
        nativeFilesSealed(areas, ins, outs, run, ok, p.join(tmp, 'native'));
    engineDirOf = (_) => p.join(tmp, kEngineFolder);
    picked = p.join(home.path, 'picked');
    deskSaver = DesktopSave(pick: (_) async => picked);
  });

  tearDown(() {
    onDesktop = false;
    isolateRunner = null;
    nativeFiles = null;
    engineDirOf = null;
    deskSaver = DesktopSave();
    root.deleteSync(recursive: true);
    home.deleteSync(recursive: true);
  });

  Future<T> sealed<T>(Future<T> Function() f) =>
      IOOverrides.runWithIOOverrides(f, io);

  // every file kryfo's folder holds, as the disk has it: none carries
  // [words] or starts as a picture, a video or [head]
  List<String> plainIn({List<String> words = const [], List<int>? head}) {
    final bad = <String>[];
    for (final e in root.listSync(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final b = e.readAsBytesSync();
      final text = latin1.decode(b, allowInvalid: true);
      final looks =
          (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) ||
          (b.length > 8 && b[0] == 0x89 && b[1] == 0x50) ||
          (b.length > 8 && latin1.decode(b.sublist(4, 8)) == 'ftyp') ||
          (head != null &&
              b.length >= head.length &&
              _same(b.sublist(0, head.length), head));
      if (looks || words.any(text.contains)) bad.add(e.path);
    }
    return bad;
  }

  test('the photo cleaner: read in place, cleaned sealed, saved only where '
      'picked, gone with the page', () async {
    final photo = File(p.join(home.path, 'IMG_1.jpg'))
      ..writeAsBytesSync(
        File('test/fixtures/gallery_gps.jpg').readAsBytesSync(),
      );
    final r = await sealed(() async {
      final before = await readFileOffUi(photo.path);
      expect(before.gps, isNotNull);
      final tmp = p.join(root.path, 'tmp', 'tools_out');
      return cleanFile(photo.path, tmp, originalName: 'IMG_1.jpg');
    });
    expect(r.failure, isNull);
    expect(r.path, startsWith(root.path));
    expect(plainIn(words: ['SM-S918B']), isEmpty);
    // the original is only read
    expect(
      photo.readAsBytesSync(),
      File('test/fixtures/gallery_gps.jpg').readAsBytesSync(),
    );

    picked = p.join(home.path, 'photo clean.jpg');
    expect(await sealed(() => deskSaver.saveAs(r.path!, r.name!)), 'saved');
    final out = File(picked).readAsBytesSync();
    expect(out.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    expect(latin1.decode(out, allowInvalid: true), isNot(contains('SM-S918B')));
    expect(plainIn(words: ['SM-S918B']), isEmpty);
    await sealed(() async => dropToolsFolder(r.path!));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(Directory(p.dirname(r.path!)).existsSync(), isFalse);
  });

  test('the video cleaner: the copy is sealed while it is worked on', () async {
    final video = File(p.join(home.path, 'clip.mp4'))
      ..writeAsBytesSync(
        File('test/fixtures/gopro_hero5_cut.mp4').readAsBytesSync(),
      );
    final r = await sealed(
      () => cleanFile(
        video.path,
        p.join(root.path, 'tmp', 'tools_out'),
        originalName: 'clip.mp4',
      ),
    );
    expect(r.failure, isNull);
    expect(plainIn(words: ['GoPro']), isEmpty);
  });

  test(
    'a pasted picture is kryfo\'s own sealed copy, never a plain png',
    () async {
      final png = await _png();
      final f = await sealed(() => pastedPicture(png));
      expect(f, isNotNull);
      expect(f!.inPlace, isFalse);
      expect(plainIn(), isEmpty);
      expect(await sealed(() => File(f.uri).readAsBytes()), png);
    },
  );

  test('a qr is saved from memory to the place picked alone', () async {
    final png = (await renderQrPng(
      gridFor('https://kryfo.app')!,
      const ui.Color(0xFF000000),
      const ui.Color(0xFFFFFFFF),
    ))!;
    picked = p.join(home.path, 'qr code.png');
    expect(await sealed(() => deskSaveBytes(png, 'qr code.png')), 'saved');
    expect(File(picked).readAsBytesSync(), png);
    expect(plainIn(), isEmpty);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test('lock and open: age in the engine\'s folder, the plain file only at '
      'the place picked', () async {
    final plain = File(p.join(home.path, 'plan.txt'))
      ..writeAsStringSync('the plan, in full, ' * 200);
    final locked = await sealed(() async {
      final d = await engineToolsFolder();
      final out = p.join(d.path, 'plan.txt.age');
      expect(await ageLockPath(plain.path, out, _pass), isNull);
      return out;
    });
    expect(plainIn(words: ['the plan']), isEmpty);
    expect(
      String.fromCharCodes(File(locked).readAsBytesSync().take(21)),
      'age-encryption.org/v1',
    );

    picked = p.join(home.path, 'plan back.txt');
    final how = await sealed(() async {
      expect(await ageOpenBeginPath(locked, _pass), isNull);
      return deskSaver.writeTo(
        picked,
        (part) async => await ageOpenFinishPath(part) == null,
      );
    });
    expect(how, 'saved');
    expect(File(picked).readAsStringSync(), plain.readAsStringSync());
    expect(File('$picked.part').existsSync(), isFalse);
    expect(plainIn(words: ['the plan']), isEmpty);

    // a wrong password writes nothing anywhere
    picked = p.join(home.path, 'never.txt');
    expect(
      await sealed(() => ageOpenBeginPath(locked, 'wrong')),
      AgeError.wrongPassword,
    );
    expect(File(picked).existsSync(), isFalse);
  }, skip: !engine);

  test('by path, as windows runs it', () async {
    ageByPath = true;
    addTearDown(() => ageByPath = Platform.isWindows);
    final plain = File(p.join(home.path, 'a.txt'))
      ..writeAsStringSync('the plan, in full');
    final locked = await sealed(() async {
      final out = p.join((await engineToolsFolder()).path, 'a.txt.age');
      expect(await ageLockPath(plain.path, out, _pass), isNull);
      return out;
    });
    expect(plainIn(words: ['the plan']), isEmpty);
    picked = p.join(home.path, 'a back.txt');
    expect(await sealed(() => ageOpenBeginPath(locked, _pass)), isNull);
    expect(
      await sealed(
        () => deskSaver.writeTo(
          picked,
          (part) async => await ageOpenFinishPath(part) == null,
        ),
      ),
      'saved',
    );
    expect(File(picked).readAsStringSync(), 'the plan, in full');
    expect(plainIn(words: ['the plan']), isEmpty);
  }, skip: !engine);

  test('linux: a locked file is age on the disk\'s tmp, not in memory, and '
      'a start clears what a cut run left', () async {
    final mem = Directory.systemTemp.createTempSync('desk_tools_mem');
    addTearDown(() => mem.deleteSync(recursive: true));
    final areas = SealedAreas(
      docs: p.join(root.path, 'docs'),
      support: p.join(root.path, 'support'),
      runtime: mem.path,
    );
    final linux = SealedIO(areas, ToyCrypto());
    PathProviderPlatform.instance = DesktopPaths(root.path, runtime: mem.path);
    engineDirOf = (_) => p.join(mem.path, kEngineFolder);
    final disk = p.join(root.path, 'tmp');
    bulkTempDir = () async {
      makePrivateDir(disk);
      return disk;
    };
    addTearDown(() => bulkTempDir = null);
    final plain = File(p.join(home.path, 'big.txt'))
      ..writeAsStringSync('the plan, in full, ' * 200);
    final locked = await IOOverrides.runWithIOOverrides(() async {
      final d = await engineToolsFolder();
      final out = p.join(d.path, 'big.txt.age');
      expect(await ageLockPath(plain.path, out, _pass), isNull);
      return out;
    }, linux);
    expect(p.isWithin(disk, locked), isTrue);
    expect(plainIn(words: ['the plan']), isEmpty);
    expect(
      String.fromCharCodes(File(locked).readAsBytesSync().take(21)),
      'age-encryption.org/v1',
    );
    clearFolder(disk);
    expect(File(locked).existsSync(), isFalse);
  }, skip: !engine);
}

bool _same(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<Uint8List> _png() async {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF3366FF),
  );
  final img = await rec.endRecording().toImage(4, 4);
  final b = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return b!.buffer.asUint8List();
}
