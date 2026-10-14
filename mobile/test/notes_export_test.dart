// SPDX-License-Identifier: GPL-3.0-or-later
// an export opens again with the app's own age code into exactly what went
// in: text, markdown, and a zip with a photo and a voice note. a locked one
// leaves no plaintext behind, a stopped or failed one leaves nothing, and
// what a dead app left is gone at the next boot. the age parts need the
// engine built for this computer
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show sweepCaptures;
import 'package:kryfo/notes_export.dart';
import 'package:kryfo/tools/age_ffi.dart';
import 'package:path/path.dart' as p;

import 'host_engine.dart';

const _pass = 'correct-horse-battery-staple';

// the app's age code, the other way
Future<Uint8List> _open(String path, String pass, Directory tmp) async {
  final out = p.join(tmp.path, 'opened');
  final inFd = openFd(path);
  expect(inFd, greaterThanOrEqualTo(0));
  expect(await ageOpenBegin(inFd, pass), isNull);
  final outFd = openFd(out, write: true);
  expect(outFd, greaterThanOrEqualTo(0));
  expect(await ageOpenFinish(outFd), isNull);
  final bytes = File(out).readAsBytesSync();
  File(out).deleteSync();
  return bytes;
}

Map<String, Object?> _note(
  String text,
  DateTime at, {
  String? photo,
  String? voice,
}) => {
  'plaintext': text,
  'sent_at': at.millisecondsSinceEpoch,
  'media_path': ?photo,
  'file_path': ?voice,
  if (voice != null) 'file_name': 'voice.wav',
};

Map<String, Uint8List> _unzip(List<int> bytes) {
  final a = ZipDecoder().decodeBytes(bytes);
  return {
    for (final f in a.files)
      f.name: () {
        final b = f.readBytes()!;
        // the stored crc is the data's
        expect(getCrc32(b), f.crc32, reason: f.name);
        return b;
      }(),
  };
}

List<String> _left(Directory d) => d.existsSync()
    ? [for (final e in d.listSync(recursive: true)) p.basename(e.path)]
    : [];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = loadHostEngine();
  late Directory tmp, out;
  final at = DateTime(2026, 10, 14, 9, 30);
  final notes = [
    _note('buy bread\nand milk', DateTime(2026, 10, 12, 8, 5)),
    _note('  ünïcode ✓ and a [link](x)  ', DateTime(2026, 10, 13, 21, 40)),
  ];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('notes_export');
    out = Directory(p.join(tmp.path, kNotesOut));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('the words come out oldest first, each under its time', () {
    expect(
      notesBody(notes, NotesFormat.text),
      '2026-10-12 08:05\nbuy bread\nand milk\n\n'
      '2026-10-13 21:40\nünïcode ✓ and a [link](x)\n',
    );
    expect(
      notesBody(notes, NotesFormat.markdown),
      '## 2026-10-12 08:05\n\nbuy bread\nand milk\n\n'
      '## 2026-10-13 21:40\n\nünïcode ✓ and a [link](x)\n',
    );
  });

  group('locked', () {
    for (final f in NotesFormat.values) {
      test('${f.name} opens again into what went in', () async {
        final made = await makeNotesExport(
          notes,
          format: f,
          passphrase: _pass,
          dir: out,
          now: at,
        );
        final ext = f == NotesFormat.text ? 'txt' : 'md';
        expect(made.name, 'kryfo-notes-2026-10-14.$ext.age');
        final raw = File(made.path).readAsBytesSync();
        expect(utf8.decode(raw.take(22).toList()), 'age-encryption.org/v1\n');
        expect(
          utf8.decode(raw, allowMalformed: true),
          isNot(contains('bread')),
        );
        final opened = await _open(made.path, _pass, tmp);
        expect(utf8.decode(opened), notesBody(notes, f));
        // the locked file alone: no plaintext stayed beside it
        expect(_left(out), [p.basename(made.path)]);
      }, skip: !engine);
    }

    test('the zip holds the words, the photo and the voice note', () async {
      final photo = File(p.join(tmp.path, 'in_abc_photo.JPG'))
        ..writeAsBytesSync(List.generate(300000, (i) => (i * 7) & 0xFF));
      final voice = File(p.join(tmp.path, 'v1'))
        ..writeAsBytesSync(List.generate(5000, (i) => i & 0xFF));
      final withFiles = [
        ...notes,
        _note('look', DateTime(2026, 10, 14, 7), photo: photo.path),
        _note('', DateTime(2026, 10, 14, 8), voice: voice.path),
        // a file gone from the phone is left out
        _note('gone', DateTime(2026, 10, 14, 9), photo: '${tmp.path}/nope.jpg'),
      ];
      for (final f in NotesFormat.values) {
        final made = await makeNotesExport(
          withFiles,
          format: f,
          passphrase: _pass,
          dir: out,
          now: at,
        );
        expect(made.name, 'kryfo-notes-2026-10-14.zip.age');
        final ext = f == NotesFormat.text ? 'txt' : 'md';
        final files = _unzip(await _open(made.path, _pass, tmp));
        expect(files.keys, ['notes.$ext', 'media/001.jpg', 'media/002.wav']);
        expect(files['media/001.jpg'], photo.readAsBytesSync());
        expect(files['media/002.wav'], voice.readAsBytesSync());
        final body = utf8.decode(files['notes.$ext']!);
        expect(body, notesBody(withFiles, f, noteFiles(withFiles)));
        expect(
          body,
          contains(
            f == NotesFormat.text
                ? '2026-10-14 07:00\nlook\nmedia/001.jpg'
                : '![](media/001.jpg)',
          ),
        );
        if (f == NotesFormat.markdown) {
          expect(body, contains('[002.wav](media/002.wav)'));
        }
        expect(_left(out), [p.basename(made.path)]);
        File(made.path).deleteSync();
      }
    }, skip: !engine);

    test('another passphrase does not open it', () async {
      final made = await makeNotesExport(
        notes,
        format: NotesFormat.text,
        passphrase: _pass,
        dir: out,
      );
      final fd = openFd(made.path);
      expect(
        await ageOpenBegin(fd, 'not the one at all'),
        AgeError.wrongPassword,
      );
    }, skip: !engine);

    test('stopped while it locks: nothing is left', () async {
      var asked = 0;
      await expectLater(
        makeNotesExport(
          notes,
          format: NotesFormat.text,
          passphrase: _pass,
          dir: out,
          // the check before the lock goes through, the lock's own stops it
          stopped: () => ++asked > 1,
        ),
        throwsA(isA<NotesExportStopped>()),
      );
      expect(asked, greaterThan(1));
      expect(_left(out), isEmpty);
    }, skip: !engine);
  });

  group('plain', () {
    test('text is the words themselves', () async {
      final made = await makeNotesExport(
        notes,
        format: NotesFormat.text,
        passphrase: null,
        dir: out,
        now: at,
      );
      expect(made.name, 'kryfo-notes-2026-10-14.txt');
      expect(
        File(made.path).readAsStringSync(),
        notesBody(notes, NotesFormat.text),
      );
      expect(_left(out), [p.basename(made.path)]);
    });

    test('with files it is a zip', () async {
      final photo = File(p.join(tmp.path, 'p.png'))
        ..writeAsBytesSync([1, 2, 3]);
      final rows = [_note('a', at, photo: photo.path)];
      final made = await makeNotesExport(
        rows,
        format: NotesFormat.markdown,
        passphrase: null,
        dir: out,
        now: at,
      );
      expect(made.name, 'kryfo-notes-2026-10-14.zip');
      final files = _unzip(File(made.path).readAsBytesSync());
      expect(files['media/001.png'], [1, 2, 3]);
      expect(utf8.decode(files['notes.md']!), contains('![](media/001.png)'));
    });

    test('stopped while it zips: nothing is left', () async {
      final big = File(p.join(tmp.path, 'big.jpg'))
        ..writeAsBytesSync(Uint8List(1 << 20));
      await expectLater(
        makeNotesExport(
          [_note('x', at, photo: big.path)],
          format: NotesFormat.text,
          passphrase: null,
          dir: out,
          stopped: () => true,
        ),
        throwsA(isA<NotesExportStopped>()),
      );
      expect(_left(out), isEmpty);
    });

    test('a file that cannot be read fails and leaves nothing', () async {
      final photo = File(p.join(tmp.path, 'p.jpg'))..writeAsBytesSync([1]);
      Process.runSync('chmod', ['000', photo.path]);
      await expectLater(
        makeNotesExport(
          [_note('a', at, photo: photo.path)],
          format: NotesFormat.text,
          passphrase: null,
          dir: out,
        ),
        throwsA(isA<NotesExportFailed>()),
      );
      expect(_left(out), isEmpty);
    });
  });

  test('a link is never followed out of the app', () {
    final secret = File(p.join(tmp.path, 'elsewhere'))..writeAsStringSync('x');
    final link = Link(p.join(tmp.path, 'l.jpg'))..createSync(secret.path);
    expect(noteFiles([_note('a', at, photo: link.path)]), isEmpty);
  });

  test('what a dead app left goes at the next boot', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
    File(p.join(out.path, 'a1b2.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('a plaintext note');
    File(p.join(out.path, 'a1b2.zip')).writeAsStringSync('zip');
    await sweepCaptures();
    expect(out.existsSync(), isFalse);
  });
}
