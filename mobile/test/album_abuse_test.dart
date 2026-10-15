// SPDX-License-Identifier: GPL-3.0-or-later
// albums a sender shapes against the grid: items whose first places never
// come are still drawn and reachable, a caption on a later item still
// shows, and an item that comes long after its album is its own message
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart';

class R {
  final String dir;
  final AlbumTag? t;
  final String text;
  final int at;
  R(this.dir, this.t, [this.text = '', this.at = 0]);
}

AlbumIndex<R> _index(List<R> rows) => AlbumIndex<R>(
  rows,
  tag: (r) => r.t,
  owner: (r) => r.dir,
  media: (_) => true,
  written: (r) => r.at,
);

void main() {
  const id = '0123456789abcdef';

  test('items 4..31 with places 0..3 missing are drawn, every one '
      'reachable', () {
    final rows = [for (var i = 4; i < 32; i++) R('in', AlbumTag(id, 32, i))];
    final ix = _index(rows);
    final run = ix.runOf(rows.first)!;
    expect(ix.isLead(rows.first), isTrue);
    for (final r in rows.skip(1)) {
      expect(ix.hidden(r), isTrue);
    }
    // the grid is laid out over what is here, so no tile is empty
    final drawn = run.drawn;
    final cells = albumCells(drawn.length, 300);
    expect([for (final c in cells) drawn[c.slot]], rows.take(4).toList());
    expect(cells.last.more, rows.length - 4);
    // and every tile opens the viewer on an item that is here
    for (final c in cells) {
      expect(albumOpenAt(drawn, c.slot), c.slot);
    }
  });

  test('a caption on item 2 is the album\'s caption', () {
    final rows = [
      R('in', const AlbumTag(id, 3, 0)),
      R('in', const AlbumTag(id, 3, 1)),
      R('in', const AlbumTag(id, 3, 2), 'hidden words'),
    ];
    final ix = _index(rows);
    final run = ix.runOf(rows[0])!;
    expect(run.caption((r) => r.text), 'hidden words');
  });

  test('a late item is its own message, not a tile of an old album', () {
    const later = 60 * 60000;
    final rows = [
      R('in', const AlbumTag(id, 3, 0)),
      R('in', const AlbumTag(id, 3, 1)),
      R('out', null, 'many messages later', later),
      R('in', const AlbumTag(id, 3, 2), '', later),
    ];
    final ix = _index(rows);
    expect(ix.hidden(rows[3]), isFalse);
    expect(ix.runOf(rows[3]), isNull);
    expect(ix.runOf(rows[0])!.whole, isFalse);
  });
}
