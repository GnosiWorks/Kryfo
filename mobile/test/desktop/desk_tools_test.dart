// SPDX-License-Identifier: GPL-3.0-or-later
// a file dropped or pasted on the tools on a computer opens in its tool by
// what it is, not by its name. what a tool sends to a chat waits for that
// chat's row alone, and a lock takes it back with the file a tool made
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/attach_tray.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/tools/desk_tools.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('desk_tools');
    lockState.openForTest();
  });
  tearDown(() {
    lockState.openForTest();
    tmp.deleteSync(recursive: true);
  });

  String put(String name, List<int> bytes) =>
      (File(p.join(tmp.path, name))..writeAsBytesSync(bytes)).path;

  test('each file opens in the tool for what it is', () {
    final photo = File('test/fixtures/gallery_gps.jpg').readAsBytesSync();
    final video = File('test/fixtures/gopro_hero5_cut.mp4').readAsBytesSync();
    expect(deskToolFor(put('a.jpg', photo)), DeskToolFor.picture);
    // a name that lies does not decide
    expect(deskToolFor(put('notes.txt', photo)), DeskToolFor.picture);
    expect(deskToolFor(put('clip.mp4', video)), DeskToolFor.video);
    expect(
      deskToolFor(put('x', 'age-encryption.org/v1\n-> scrypt'.codeUnits)),
      DeskToolFor.locked,
    );
    expect(
      deskToolFor(
        put('y', '-----BEGIN AGE ENCRYPTED FILE-----\nYWdl'.codeUnits),
      ),
      DeskToolFor.locked,
    );
    expect(deskToolFor(put('z.age', List.filled(40, 7))), DeskToolFor.locked);
    expect(
      deskToolFor(put('plan.pdf', '%PDF-1.7 a plan'.codeUnits)),
      DeskToolFor.other,
    );
    expect(deskToolFor(put('empty', const [])), DeskToolFor.other);
    expect(deskToolFor(p.join(tmp.path, 'gone')), DeskToolFor.other);
  });

  test('a picked file is read in place and never deleted', () {
    final f = deskPicked(put('holiday.jpg', [1, 2, 3]))!;
    expect(f.inPlace, isTrue);
    expect(f.canDelete, isFalse);
    expect(f.name, 'holiday.jpg');
    expect(f.size, 3);
    expect(deskPicked(p.join(tmp.path, 'gone')), isNull);
  });

  test('a hand-off waits for its own chat\'s row alone', () {
    final png = Uint8List.fromList([1, 2, 3]);
    DeskTrays.handOff(
      'c1|alice',
      TrayHandoff.picture(png, name: 'qr code.png'),
    );
    expect(DeskTrays.takeHandedOff('c1|bob'), isEmpty);
    expect(DeskTrays.takeHandedOff('c2|alice'), isEmpty);
    final got = DeskTrays.takeHandedOff('c1|alice');
    expect(got.single.bytes, png);
    expect(got.single.name, 'qr code.png');
    expect(DeskTrays.takeHandedOff('c1|alice'), isEmpty);
  });

  test('a locked file a tool made goes once its row lets go of it', () async {
    final dir = Directory(p.join(tmp.path, 'tools_out', 'ab'))
      ..createSync(recursive: true);
    final made = put(p.join('tools_out', 'ab', 'plan.txt.age'), [9, 9, 9]);
    DeskTrays.handOff('c1|alice', TrayHandoff.file(made, owned: true));
    final h = DeskTrays.takeHandedOff('c1|alice').single;
    final tray = DeskTrays.of('c1|alice');
    await tray.add([h.path!], most: () async => 1 << 20);
    expect(tray.items.single.path, made);
    // sent: taken, then let go once read
    final sent = tray.take();
    expect(File(made).existsSync(), isTrue);
    AttachTray.sent(sent);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(dir.existsSync(), isFalse);
  });

  test('a lock takes back what waits, and the files tools made', () async {
    final dir = Directory(p.join(tmp.path, 'o', 'cd'))
      ..createSync(recursive: true);
    final made = put(p.join('o', 'cd', 'x.age'), [1]);
    DeskTrays.handOff('c1|alice', TrayHandoff.file(made, owned: true));
    DeskTrays.of('c1|alice');
    lockState.openForTest(enabled: true);
    lockState.lock();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(DeskTrays.takeHandedOff('c1|alice'), isEmpty);
    expect(dir.existsSync(), isFalse);
    // and while locked nothing is taken
    final other = put('y.age', [1]);
    DeskTrays.handOff('c1|alice', TrayHandoff.file(other));
    expect(DeskTrays.takeHandedOff('c1|alice'), isEmpty);
    expect(File(other).existsSync(), isTrue);
  });
}
