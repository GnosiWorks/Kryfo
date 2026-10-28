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

  test('bytes the camera made go through the same dialog', () async {
    final to = p.join(tmp.path, 'shot.jpg');
    final s = DesktopSave(pick: (_) async => to);
    expect(await s.saveBytes([1, 2, 3], 'shot.jpg', tmp.path), isTrue);
    expect(File(to).readAsBytesSync(), [1, 2, 3]);
    // its own working copy is gone
    expect(
      tmp.listSync().whereType<File>().map((f) => p.basename(f.path)),
      unorderedEquals(['in_ab12', 'shot.jpg']),
    );
  });
}
