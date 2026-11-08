// SPDX-License-Identifier: GPL-3.0-or-later
// a file leaves the desktop app through the save dialog and kryfo's copy
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_save.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late File src;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('save');
    src = File(p.join(tmp.path, 'in_ab12'))
      ..writeAsBytesSync(List.generate(3 << 20, (i) => i & 255));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('picked, copied whole, under the name picked', () async {
    final to = p.join(tmp.path, 'out', 'report.pdf');
    Directory(p.dirname(to)).createSync();
    String? asked;
    final s = DesktopSave(
      pick: (n) async {
        asked = n;
        return to;
      },
    );
    final r = await s.save(src.path, 'report.pdf');
    expect(r, {'state': 'saved', 'where': 'out'});
    expect(asked, 'report.pdf');
    expect(File(to).readAsBytesSync(), src.readAsBytesSync());
    expect(File('$to.part').existsSync(), isFalse);
    expect(s.state(), {'stage': 'idle', 'copied': 3 << 20});
  });

  test('the dialog closed is a cancel, and nothing is written', () async {
    final s = DesktopSave(pick: (_) async => null);
    expect(await s.save(src.path, 'a.txt'), {'state': 'cancelled'});
    expect(await s.saveAs(src.path, 'a.txt'), 'kept');
    expect(tmp.listSync(), hasLength(1));
  });

  test('a cancel mid copy takes away what was written', () async {
    final to = p.join(tmp.path, 'b.bin');
    late DesktopSave s;
    s = DesktopSave(pick: (_) async => to);
    final f = s.save(src.path, 'b.bin');
    // the copy yields after each block
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    s.cancel();
    expect((await f)['state'], 'cancelled');
    expect(File(to).existsSync(), isFalse);
    expect(File('$to.part').existsSync(), isFalse);
  });

  test(
    'a place it cannot write fails, a picked file over itself too',
    () async {
      final s = DesktopSave(pick: (_) async => '/proc/kryfo/x.bin');
      expect((await s.save(src.path, 'x.bin'))['state'], 'failed');
      final same = DesktopSave(pick: (_) async => src.path);
      expect((await same.save(src.path, 'x'))['state'], 'failed');
      expect(src.lengthSync(), 3 << 20);
    },
  );

  test('a second save while one runs is refused', () async {
    final to = p.join(tmp.path, 'c.bin');
    final s = DesktopSave(pick: (_) async => to);
    final a = s.save(src.path, 'c');
    expect((await s.save(src.path, 'c'))['state'], 'failed');
    expect((await a)['state'], 'saved');
  });

  test('bytes in memory go only to the place picked', () async {
    final to = p.join(tmp.path, 'out', 'shot.jpg');
    Directory(p.dirname(to)).createSync();
    final s = DesktopSave(pick: (_) async => to);
    expect(await s.saveBytes([1, 2, 3], 'shot.jpg'), 'saved');
    expect(File(to).readAsBytesSync(), [1, 2, 3]);
    // nothing of it anywhere else, not even for a moment: no working copy
    // in a folder of kryfo's, and the part became the file
    final all = tmp.listSync(recursive: true).whereType<File>();
    expect(
      all.map((f) => p.relative(f.path, from: tmp.path)),
      unorderedEquals(['in_ab12', p.join('out', 'shot.jpg')]),
    );
    expect(
      await DesktopSave(pick: (_) async => null).saveBytes([1], 'x'),
      'kept',
    );
  });

  test(
    'a writer saves straight to the place, and a failed one leaves nothing',
    () async {
      final to = p.join(tmp.path, 'opened.txt');
      final s = DesktopSave(pick: (_) async => to);
      expect(
        await s.saveWith('opened.txt', (part) async {
          expect(part, '$to.part');
          File(part).writeAsStringSync('plain');
          return true;
        }),
        'saved',
      );
      expect(File(to).readAsStringSync(), 'plain');
      final bad = p.join(tmp.path, 'bad.txt');
      final b = DesktopSave(pick: (_) async => bad);
      expect(
        await b.saveWith('bad.txt', (part) async {
          File(part).writeAsStringSync('half');
          return false;
        }),
        'failed',
      );
      expect(File(bad).existsSync(), isFalse);
      expect(File('$bad.part').existsSync(), isFalse);
      expect(
        await b.saveWith(
          'bad.txt',
          (part) async => throw const FileSystemException('x'),
        ),
        'failed',
      );
      expect(File('$bad.part').existsSync(), isFalse);
    },
  );
}
