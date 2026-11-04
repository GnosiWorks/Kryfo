// SPDX-License-Identifier: GPL-3.0-or-later
// where there is no memfd (windows), code outside dart still gets a sealed
// file's plaintext and gives one back: as a copy under a random name in
// the spill folder, zeroed and gone once the code is done
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_native.dart';
import 'package:path/path.dart' as p;

import 'sealed_file_test.dart' show ToyCrypto;

void main() {
  late Directory root;
  late SealedIO io;
  late SealedAreas areas;
  late String docs, spill;

  setUp(() {
    root = Directory.systemTemp.createTempSync('spill');
    docs = p.join(root.path, 'docs');
    spill = p.join(root.path, 'tmp', 'native');
    Directory(p.join(docs, 'media')).createSync(recursive: true);
    areas = SealedAreas(docs: docs, support: p.join(root.path, 'support'))
      ..containerKeys[''] = Uint8List.fromList(List.filled(32, 1));
    io = SealedIO(areas, ToyCrypto());
    noMemfdForTest = true;
  });
  tearDown(() {
    noMemfdForTest = false;
    root.deleteSync(recursive: true);
  });

  test('a send, its values and a take back read the plaintext from a copy '
      'that is gone after', () async {
    final src = p.join(docs, 'media', 'f_abc.pdf');
    final out = p.join(docs, 'media', 'f_abc.ogg');
    IOOverrides.runWithIOOverrides(
      () => File(src).writeAsStringSync('the whole report'),
      io,
    );
    String? seenIn;
    final r = await IOOverrides.runWithIOOverrides(
      () => nativeFilesSealed<String>(
        areas,
        [src],
        [out],
        (i, o) async {
          seenIn = i[0];
          expect(p.isWithin(spill, i[0]), isTrue);
          expect(p.isWithin(spill, o[0]), isTrue);
          // what the code reads is the plaintext
          expect(io.rawFile(i[0]).readAsStringSync(), 'the whole report');
          io.rawFile(o[0]).writeAsStringSync('written outside dart');
          return 'ok';
        },
        null,
        spill,
      ),
      io,
    );
    expect(r, 'ok');
    expect(File(seenIn!).existsSync(), isFalse);
    expect(Directory(spill).listSync(), isEmpty);
    // what the code wrote is sealed into place
    final raw = io.rawFile(out).readAsBytesSync();
    expect(isSealedHead(raw), isTrue);
    expect(latin1.decode(raw).contains('outside dart'), isFalse);
    expect(
      IOOverrides.runWithIOOverrides(() => File(out).readAsStringSync(), io),
      'written outside dart',
    );
  });

  test('without memfd and nowhere to spill, it refuses rather than hand '
      'over sealed bytes', () async {
    final src = p.join(docs, 'media', 'f_x.pdf');
    IOOverrides.runWithIOOverrides(() => File(src).writeAsStringSync('x'), io);
    await expectLater(
      IOOverrides.runWithIOOverrides(
        () => nativeFilesSealed<String>(
          areas,
          [src],
          const [],
          (i, _) async => 'ran',
        ),
        io,
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('at start, what a crash left in the spill folder is zeroed and '
      'deleted', () {
    Directory(p.join(spill, 'odd')).createSync(recursive: true);
    final left = File(p.join(spill, 'ab' * 16))
      ..writeAsStringSync('the whole report');
    // a handle held across the sweep sees the zeros it left
    final held = left.openSync();
    sweepNativeCopies(spill);
    expect(Directory(spill).listSync(), isEmpty);
    held.setPositionSync(0);
    expect(held.readSync(64), List.filled(16, 0));
    held.closeSync();
    // nothing there, or no folder at all: nothing to do
    sweepNativeCopies(spill);
    sweepNativeCopies(p.join(root.path, 'none'));
  });

  test('a copy whose zeroing fails is still deleted', () {
    final c = DiskCopy.create(spill);
    File(c.path).writeAsStringSync('plain');
    // read-only: opening it to zero throws
    Process.runSync('chmod', ['444', c.path]);
    expect(
      () => File(c.path).openSync(mode: FileMode.writeOnlyAppend),
      throwsA(isA<FileSystemException>()),
    );
    c.close();
    expect(File(c.path).existsSync(), isFalse);
  });
}
