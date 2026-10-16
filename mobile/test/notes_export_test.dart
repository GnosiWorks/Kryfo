// SPDX-License-Identifier: GPL-3.0-or-later
// an export opens again with the app's own age code into exactly what went
// in: text, markdown, and a zip with a photo and a voice note. a locked one
// leaves no plaintext behind, a stopped or failed one leaves nothing, and
// what a dead app left is gone at the next boot. the age parts need the
// engine built for this computer
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show ByteData, Endian;

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show sweepCaptures;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/notes_export.dart';
import 'package:kryfo/store_zip.dart';
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

// a zip past a test's small limit cannot end either: its file still shuts
Future<void> _shut(StoreZip zip) async {
  try {
    await zip.close();
  } on ZipTooLarge {
    // as asked
  }
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
    forgetNotesExportRun();
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

  group('leftovers', () {
    void leave() {
      File(p.join(out.path, 'a1b2.txt'))
        ..createSync(recursive: true)
        ..writeAsStringSync('a plaintext note');
      File(p.join(out.path, 'a1b2.zip')).writeAsStringSync('zip');
    }

    test('what a dead app left goes at launch', () async {
      leave();
      await sweepNotesExports(tmp);
      expect(out.existsSync(), isFalse);
    });

    test('the later boot sweep never looks there', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => tmp.path,
          );
      leave();
      await sweepCaptures();
      expect(_left(out), hasLength(2));
    });

    test('an export that began is never swept from under', () async {
      final made = await makeNotesExport(
        notes,
        format: NotesFormat.text,
        passphrase: null,
        dir: out,
      );
      await sweepNotesExports(tmp);
      expect(File(made.path).existsSync(), isTrue);
    });

    test('one that begins during the sweep waits for it', () async {
      leave();
      for (var i = 0; i < 40; i++) {
        File(p.join(out.path, 'old$i.txt')).writeAsStringSync('x' * 5000);
      }
      final swept = sweepNotesExports(tmp);
      final made = await makeNotesExport(
        notes,
        format: NotesFormat.text,
        passphrase: null,
        dir: out,
      );
      await swept;
      expect(_left(out), [p.basename(made.path)]);
    });
  });

  group('a lock or a switch', () {
    test('shreds what the session made, a handed file only unlinked', () async {
      final made = File(p.join(out.path, 'a.txt'))
        ..createSync(recursive: true)
        ..writeAsStringSync('plain words');
      final handed = File(p.join(out.path, 'h.txt'))
        ..writeAsStringSync('being copied');
      notesExportHanded(handed.path);
      final reading = handed.openSync();
      final watching = made.openSync();
      addTearDown(() {
        reading.closeSync();
        watching.closeSync();
      });
      await dropNotesExports(tmp);
      expect(_left(out), isEmpty);
      // android's copy reads on; the other was zeroed first
      expect(utf8.decode(reading.readSync(100)), 'being copied');
      expect(watching.readSync(100).every((b) => b == 0), isTrue);
    });

    test('runs at every lock and every unlock', () {
      // the body of the method that starts at [head], read off the source
      String body(String src, String head) {
        final at = src.indexOf(head);
        expect(at, greaterThanOrEqualTo(0), reason: head);
        var depth = 0;
        for (var i = src.indexOf('{', at + head.length); i < src.length; i++) {
          if (src[i] == '{') depth++;
          if (src[i] == '}' && --depth == 0) return src.substring(at, i);
        }
        return '';
      }

      final main = File('lib/app/state.dart').readAsStringSync();
      for (final head in [
        'void lockingUp()',
        'Future<void> _sessionFor(PinResult r, {String? vaultKey}) async',
      ]) {
        expect(body(main, head), contains('dropNotesExports('), reason: head);
      }
    });

    test('stops an export being made at once, and nothing is left', () async {
      final big = File(p.join(tmp.path, 'big.jpg'));
      big.openSync(mode: FileMode.write)
        ..setPositionSync(2 << 30)
        ..writeByteSync(1)
        ..closeSync();
      var moved = false;
      final making = makeNotesExport(
        [_note('x', at, photo: big.path)],
        format: NotesFormat.text,
        passphrase: null,
        dir: out,
        progress: (_) => moved = true,
      );
      final stops = expectLater(making, throwsA(isA<NotesExportStopped>()));
      // a file is being written when the lock comes
      for (var i = 0; !moved && i < 2000; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(_left(out), isNotEmpty);
      final watch = Stopwatch()..start();
      await dropNotesExports(tmp).timeout(const Duration(seconds: 10));
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      await stops;
      expect(_left(out), isEmpty);
    });

    test('an export read before a drop stops and leaves nothing', () async {
      final run = notesExportRun.value;
      await dropNotesExports(tmp);
      await expectLater(
        makeNotesExport(
          notes,
          format: NotesFormat.text,
          passphrase: null,
          dir: out,
          run: run,
        ),
        throwsA(isA<NotesExportStopped>()),
      );
      expect(_left(out), isEmpty);
    });
  });

  group('zip', () {
    test(
      'names are utf-8 and say so',
      () async {
        final path = p.join(tmp.path, 'u.zip');
        final zip = await StoreZip.create(path, at);
        await zip.addBytes('notes-ü✓.txt', utf8.encode('hi'));
        await zip.close();
        final bytes = File(path).readAsBytesSync();
        // the flag in the local header and in the central one
        final d = ByteData.sublistView(bytes);
        expect(d.getUint16(6, Endian.little) & 0x0800, 0x0800);
        final cd = d.getUint32(bytes.length - 6, Endian.little);
        expect(d.getUint16(cd + 8, Endian.little) & 0x0800, 0x0800);
        expect(_unzip(bytes).keys, ['notes-ü✓.txt']);
        // python reads a name as cp437 unless the flag says utf-8
        final py = await Process.run('python3', [
          '-I',
          '-c',
          'import sys, zipfile\n'
              'z = zipfile.ZipFile(sys.argv[1])\n'
              'n = z.namelist()[0]\n'
              'sys.stdout.buffer.write(n.encode() + b"|" + z.read(n))',
          path,
        ], stdoutEncoding: utf8);
        expect(py.exitCode, 0, reason: '${py.stderr}');
        expect(py.stdout, 'notes-ü✓.txt|hi');
      },
      skip: Process.runSync('which', ['python3']).exitCode != 0,
    );

    test('all ones is a marker, never a size', () async {
      final path = p.join(tmp.path, 'l.zip');
      var zip = await StoreZip.create(path, at, limit: 10);
      await zip.addBytes('a', List.filled(9, 1));
      await expectLater(
        zip.addBytes('b', List.filled(10, 1)),
        throwsA(isA<ZipTooLarge>()),
      );
      await _shut(zip);
      final ten = File(p.join(tmp.path, 'ten'))
        ..writeAsBytesSync(List.filled(10, 1));
      zip = await StoreZip.create(path, at, limit: 10);
      await expectLater(zip.addFile('t', ten), throwsA(isA<ZipTooLarge>()));
      await _shut(zip);
      // an entry past where the offset can still be told
      zip = await StoreZip.create(path, at, limit: 40);
      await zip.addBytes('a', List.filled(9, 1));
      await expectLater(zip.addBytes('b', [1]), throwsA(isA<ZipTooLarge>()));
      await _shut(zip);
    });

    test('and never a count', () async {
      final zip = await StoreZip.create(
        p.join(tmp.path, 'c.zip'),
        at,
        entries: 3,
      );
      await zip.addBytes('a', [1]);
      await zip.addBytes('b', [1]);
      await expectLater(zip.addBytes('c', [1]), throwsA(isA<ZipTooLarge>()));
      await zip.close();
    });

    test('an export past 4 GB is refused before anything is written', () async {
      // sparse: as long as it says, without the disk
      final big = File(p.join(tmp.path, 'big.jpg'));
      final raf = big.openSync(mode: FileMode.write)
        ..setPositionSync(kZipLimit - 100)
        ..writeByteSync(1);
      raf.closeSync();
      final watch = Stopwatch()..start();
      await expectLater(
        makeNotesExport(
          [_note('x', at, photo: big.path)],
          format: NotesFormat.text,
          passphrase: null,
          dir: out,
        ),
        throwsA(isA<NotesExportTooLarge>()),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(out.existsSync(), isFalse);
    });
  });

  test(
    'descriptors not yet the engine\'s are closed',
    () async {
      int open() => Directory('/proc/self/fd').listSync().length;
      final src = File(p.join(tmp.path, 'in'))..writeAsStringSync('x');
      ageLockSymbol = 'HaloNoSuchCall';
      addTearDown(() => ageLockSymbol = 'HaloAgeLock');
      final before = open();
      expect(
        await ageLockPath(src.path, p.join(tmp.path, 'o.age'), _pass),
        AgeError.io,
      );
      expect(open(), before);
    },
    skip: !Directory('/proc/self/fd').existsSync(),
  );

  test('the tool is named in quotes, never run into the sentence', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      final line = l.notesExportLockLine;
      final at = line.indexOf(l.toolsOpenALockedFile);
      expect(at, greaterThan(0), reason: '$locale');
      final before = line.substring(0, at).trimRight();
      expect(
        '«„“「"'.contains(before[before.length - 1]),
        isTrue,
        reason: '$locale: $line',
      );
    }
  });
}
