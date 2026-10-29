// SPDX-License-Identifier: GPL-3.0-or-later
// the windows side that runs on any host: the runner's folder word, the
// temporary folder sealed under a key of the run, and its clearing
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_start.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:path/path.dart' as p;

import 'sealed_file_test.dart' show ToyCrypto;

Uint8List _k(int b) => Uint8List.fromList(List.filled(32, b));

void main() {
  test('the runner\'s folder word', () {
    expect(windowsFolderStop('ok'), isNull);
    expect(windowsFolderStop('locked'), DesktopStop.alreadyOpen);
    expect(windowsFolderStop('owner'), DesktopStop.notYours);
    expect(windowsFolderStop('link'), DesktopStop.notPrivate);
    expect(windowsFolderStop('acl'), DesktopStop.notPrivate);
    // no word: not started by kryfo.exe, so nothing was checked
    expect(windowsFolderStop(null), DesktopStop.notPrivate);
    expect(windowsFolderStop('nofolder'), DesktopStop.notPrivate);
  });

  group('the temporary folder', () {
    late Directory root;
    late String docs, support, tmp;
    late SealedIO io;

    setUp(() {
      root = Directory.systemTemp.createTempSync('win');
      docs = p.join(root.path, 'docs');
      support = p.join(root.path, 'support');
      tmp = p.join(root.path, 'tmp');
      for (final d in [p.join(docs, 'media'), support, tmp]) {
        Directory(d).createSync(recursive: true);
      }
      final areas = SealedAreas(docs: docs, support: support, tmp: tmp)
        ..filesKey = _k(9)
        ..containerKeys[''] = _k(1)
        ..sessionKey = _k(7);
      io = SealedIO(areas, ToyCrypto());
    });
    tearDown(() => root.deleteSync(recursive: true));

    T sealed<T>(T Function() f) => IOOverrides.runWithIOOverrides(f, io);
    bool holds(Uint8List b, String s) =>
        latin1.decode(b, allowInvalid: true).contains(s);

    test('is an area of its own, under the run\'s key', () {
      final a = io.areas;
      expect(a.areaOf(p.join(tmp, 'take.wav')), '~');
      expect(a.areaOf(p.join(tmp, 'deep', 'x')), '~');
      expect(a.keyFor(p.join(tmp, 'take.wav')), _k(7));
      expect(a.areaOf(p.join(root.path, 'vault.kv')), isNull);
      // the engine reads its folder by path: the onion key, its marks
      expect(a.areaOf(p.join(tmp, 'engine')), isNull);
      expect(a.areaOf(p.join(tmp, 'engine', 'onion.key')), isNull);
      expect(a.areaOf(p.join(tmp, 'engines', 'x')), '~');
    });

    test('what dart writes there is sealed on the disk', () {
      final f = p.join(tmp, 'pick.jpg');
      sealed(() => File(f).writeAsStringSync('a picked photo'));
      expect(holds(io.rawFile(f).readAsBytesSync(), 'a picked photo'), isFalse);
      expect(sealed(() => File(f).readAsStringSync()), 'a picked photo');
    });

    test('a move into media seals again under the media key', () {
      final from = p.join(tmp, 'pick.jpg');
      final to = p.join(docs, 'media', 'in_1.jpg');
      sealed(() {
        File(from).writeAsStringSync('a picked photo');
        File(from).renameSync(to);
      });
      expect(io.rawFile(from).existsSync(), isFalse);
      expect(sealed(() => File(to).readAsStringSync()), 'a picked photo');
      final other = SealedIO(
        SealedAreas(docs: docs, support: support, tmp: tmp)
          ..containerKeys[''] = _k(1),
        ToyCrypto(),
      );
      // the media key alone opens it: the run's key is not needed
      expect(
        IOOverrides.runWithIOOverrides(
          () => File(to).readAsStringSync(),
          other,
        ),
        'a picked photo',
      );
    });

    test('without the run\'s key it does not open', () {
      final f = p.join(tmp, 'take.wav');
      sealed(() => File(f).writeAsStringSync('speech'));
      final next = SealedIO(
        SealedAreas(docs: docs, support: support, tmp: tmp)..sessionKey = _k(8),
        ToyCrypto(),
      );
      expect(
        () => IOOverrides.runWithIOOverrides(
          () => File(f).readAsStringSync(),
          next,
        ),
        throwsA(anything),
      );
    });

    test('the key and the folder go to an isolate', () {
      final m = io.areas.toMessage();
      final back = SealedAreas.fromMessage(m);
      expect(back.tmp, tmp);
      expect(back.sessionKey, _k(7));
    });

    test('is cleared at the start, zeroed first', () {
      final f = File(p.join(tmp, 'a', 'left.bin'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(70000, 0x41));
      clearFolder(tmp);
      expect(f.existsSync(), isFalse);
      expect(Directory(tmp).existsSync(), isTrue);
      clearFolder(p.join(root.path, 'none'));
    });

    test('a run\'s key is fresh and 32 bytes', () {
      final a = sessionKey(), b = sessionKey();
      expect(a, hasLength(32));
      expect(a, isNot(b));
    });
  });
}
