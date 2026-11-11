// SPDX-License-Identifier: GPL-3.0-or-later
// what may leave a chat from the viewer and a selection: nothing from a
// chat that blocks screenshots or a burner room, no timed message, marked
// photo or spoiler, and a hidden chat's never goes out
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/viewer_rules.dart';

void main() {
  test('an everyday chat lets a photo go', () {
    expect(mayLeave(blocking: false), isTrue);
    expect(maySaveOut(blocking: false), isTrue);
  });

  test('each rule keeps it in on its own', () {
    expect(mayLeave(blocking: true), isFalse);
    expect(mayLeave(blocking: false, room: true), isFalse);
    expect(mayLeave(blocking: false, timed: true), isFalse);
    expect(mayLeave(blocking: false, marked: true), isFalse);
    expect(mayLeave(blocking: false, spoiler: true), isFalse);
    expect(maySaveOut(blocking: false, hidden: true), isFalse);
    expect(mayLeave(blocking: false, hidden: true), isFalse);
  });

  test('a photo is saved under when it was sent, never its file name', () {
    expect(
      savedPhotoName('/m/1a2b3c.JPG', DateTime(2026, 3, 4, 5, 6, 7)),
      'Kryfo-20260304-050607.jpg',
    );
    expect(
      savedPhotoName('/m/noext', DateTime(2026, 3, 4)),
      'Kryfo-20260304-000000.jpg',
    );
  });
}
