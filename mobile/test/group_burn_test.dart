// SPDX-License-Identifier: GPL-3.0-or-later
// a disappearing message in a group keeps its timer through anything that
// sends it again: a retry after the chat was reopened, the chat's own retry
// of a reloaded row, the outbox. the timer is written with the row and read
// back with it, the way the 1:1 chat has it
import 'package:flutter_test/flutter_test.dart';

import 'source_body.dart';

void main() {
  final screen = sourceOf('lib/screens/group_chat_screen.dart');
  final app = sourceOf('lib/main.dart');

  test('every row the group chat saves for a send keeps the timer', () {
    final saves = callsOf(screen, 'session.saveMessage(');
    // a photo, a voice note, a file
    expect(saves.length, 3);
    for (final s in saves) {
      expect(s, contains('burnSecs: burn,'), reason: s);
    }
  });

  test('so does the one sendToGroup saves for a text, sticker or poll', () {
    final body = bodyOf(app, 'Future<bool> sendToGroup(');
    final saves = callsOf(body, 'session.saveMessage(');
    expect(saves.length, 1);
    expect(saves.single, contains('burnSecs:'));
  });

  test('every way the group chat reads its rows reads the timer back', () {
    final rows = callsOf(screen, '_GMsg(').where((c) => c.contains("r['"));
    // the first page, a full reload, the newest rows
    expect(rows.length, 3);
    for (final r in rows) {
      expect(r, contains("burnSecs: (r['burn_secs'] as num?)?.toInt(),"));
    }
  });

  test('a retry sends the timer it read', () {
    final body = bodyOf(screen, 'Future<void> _retryGroup(');
    expect(RegExp(r'burnSeconds: m\.burnSecs,').allMatches(body).length, 2);
  });
}
