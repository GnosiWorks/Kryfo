// SPDX-License-Identifier: GPL-3.0-or-later
// albums as a chat holds them: how a pick is cut, how a grid is laid out
// for each count, and which rows make one album in which order
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart';

class _Row {
  final String who;
  final AlbumTag? tag;
  final bool media;
  final String name;
  final int at;
  final String text;
  const _Row(
    this.name,
    this.tag, {
    this.who = 'in',
    this.media = true,
    this.at = 0,
    this.text = '',
  });
  @override
  String toString() => name;
}

AlbumIndex<_Row> _index(List<_Row> rows) => AlbumIndex<_Row>(
  rows,
  tag: (r) => r.tag,
  owner: (r) => r.who,
  media: (r) => r.media,
  written: (r) => r.at,
);

const _a = '00112233445566aa';
const _b = '00112233445566bb';

void main() {
  group('the cut', () {
    test('ten or fewer is one album', () {
      expect(albumBatches(List.generate(10, (i) => i)), [
        List.generate(10, (i) => i),
      ]);
      expect(albumBatches([1, 2]), [
        [1, 2],
      ]);
      expect(albumBatches(<int>[]), isEmpty);
    });

    test('more is cut evenly, never leaving one alone', () {
      List<int> sizes(int n) => [
        for (final b in albumBatches(List.generate(n, (i) => i))) b.length,
      ];
      expect(sizes(11), [6, 5]);
      expect(sizes(20), [10, 10]);
      expect(sizes(21), [7, 7, 7]);
      expect(sizes(30), [10, 10, 10]);
      // the order holds across the cut
      expect(
        albumBatches(List.generate(13, (i) => i)).expand((b) => b).toList(),
        List.generate(13, (i) => i),
      );
    });

    test('the caption rides on the very first item, each has its place', () {
      final plan = albumPlan(List.generate(12, (i) => 'p$i'), 'hello');
      expect([for (final g in plan) g.item], List.generate(12, (i) => 'p$i'));
      expect(
        [for (final g in plan) g.caption],
        ['hello', ...List.filled(11, '')],
      );
      // twelve: six and six, under two ids
      final tags = [for (final g in plan) g.album!];
      expect([for (final t in tags) t.n], List.filled(12, 6));
      expect([for (final t in tags) t.i], [0, 1, 2, 3, 4, 5, 0, 1, 2, 3, 4, 5]);
      expect(tags.map((t) => t.id).toSet(), hasLength(2));
      expect(tags.take(6).map((t) => t.id).toSet(), hasLength(1));
    });

    test('one item, or each on its own, carries no album', () {
      final one = albumPlan(['p'], 'c');
      expect(one.single.album, isNull);
      expect(one.single.caption, 'c');
      final alone = albumPlan(['a', 'b', 'c'], 'c', alone: true);
      expect([for (final g in alone) g.album], [null, null, null]);
      expect([for (final g in alone) g.caption], ['c', '', '']);
    });

    test('a new album id is its own', () {
      final ids = {for (var i = 0; i < 50; i++) newAlbumId()};
      expect(ids.length, 50);
      for (final id in ids) {
        expect(AlbumTag.fromWire({'id': id, 'n': 2, 'i': 0}), isNotNull);
      }
    });
  });

  group('the grid', () {
    const w = 300.0;
    const g = kAlbumGap;

    void inside(List<AlbumCell> cells, double h) {
      for (final c in cells) {
        expect(c.rect.left, greaterThanOrEqualTo(0));
        expect(c.rect.top, greaterThanOrEqualTo(0));
        expect(c.rect.right, lessThanOrEqualTo(w + 0.001));
        expect(c.rect.bottom, lessThanOrEqualTo(h + 0.001));
      }
      // no two tiles overlap
      for (var i = 0; i < cells.length; i++) {
        for (var j = i + 1; j < cells.length; j++) {
          final o = cells[i].rect.intersect(cells[j].rect);
          expect(o.width <= 0 || o.height <= 0, isTrue, reason: '$i $j');
        }
      }
    }

    test('two side by side', () {
      final c = albumCells(2, w);
      final h = albumHeight(2, w);
      expect(c.map((x) => x.slot), [0, 1]);
      expect(c[0].rect, Rect.fromLTWH(0, 0, (w - g) / 2, h));
      expect(c[1].rect.left, (w - g) / 2 + g);
      expect(c[1].rect.height, h);
      inside(c, h);
    });

    test('three as one big and two small', () {
      final c = albumCells(3, w);
      final h = albumHeight(3, w);
      expect(c.map((x) => x.slot), [0, 1, 2]);
      expect(c[0].rect.height, h);
      expect(c[0].rect.width, greaterThan(c[1].rect.width));
      expect(c[1].rect.left, c[2].rect.left);
      expect(c[1].rect.width, c[2].rect.width);
      expect(c[1].rect.height + g + c[2].rect.height, closeTo(h, 0.001));
      expect(c[1].rect.right, closeTo(w, 0.001));
      inside(c, h);
    });

    test('four as two by two', () {
      final c = albumCells(4, w);
      final h = albumHeight(4, w);
      expect(h, w);
      expect(c.map((x) => x.slot), [0, 1, 2, 3]);
      expect(c.every((x) => x.more == 0), isTrue);
      final side = (w - g) / 2;
      for (final x in c) {
        expect(x.rect.width, side);
        expect(x.rect.height, side);
      }
      inside(c, h);
    });

    test('more as two by two with the rest on the last', () {
      for (final n in [5, 7, 10]) {
        final c = albumCells(n, w);
        expect(c.length, 4, reason: '$n');
        expect(c.map((x) => x.more), [0, 0, 0, n - 4], reason: '$n');
        expect(albumHeight(n, w), albumHeight(4, w));
      }
    });

    test('the height hangs on the count alone', () {
      for (final n in [2, 3, 4, 9]) {
        expect(albumHeight(n, w), albumHeight(n, w));
        final c = albumCells(n, w);
        expect(
          c.map((x) => x.rect.bottom).reduce((a, b) => a > b ? a : b),
          closeTo(albumHeight(n, w), 0.001),
        );
      }
    });
  });

  group('the rows', () {
    test('out of order arrival keeps the album order', () {
      final r2 = _Row('r2', const AlbumTag(_a, 3, 2));
      final r0 = _Row('r0', const AlbumTag(_a, 3, 0));
      final r1 = _Row('r1', const AlbumTag(_a, 3, 1));
      final ix = _index([r2, r0, r1]);
      final run = ix.runOf(r0)!;
      expect(run.slots, [r0, r1, r2]);
      expect(run.present, [r0, r1, r2]);
      expect(run.whole, isTrue);
      // drawn where its first row in the chat is, the rest hidden
      expect(ix.isLead(r2), isTrue);
      expect(ix.hidden(r0), isTrue);
      expect(ix.hidden(r1), isTrue);
      expect(run.anchor, r0);
    });

    test('a partial album holds a place for what is still coming', () {
      final r1 = _Row('r1', const AlbumTag(_a, 4, 1));
      final r3 = _Row('r3', const AlbumTag(_a, 4, 3));
      final run = _index([r3, r1]).runOf(r1)!;
      expect(run.slots, [null, r1, null, r3]);
      expect(run.whole, isFalse);
      // its reactions and replies go to the first one here
      expect(run.anchor, r1);
      // one item in, still drawn as the album it will be
      final lone = _Row('lone', const AlbumTag(_b, 3, 2));
      expect(_index([lone]).runOf(lone)!.slots, [null, null, lone]);
    });

    test('two senders never share an album', () {
      final a = _Row('a', const AlbumTag(_a, 2, 0), who: 'alice');
      final b = _Row('b', const AlbumTag(_a, 2, 1), who: 'bob');
      final ix = _index([a, b]);
      expect(identical(ix.runOf(a), ix.runOf(b)), isFalse);
      expect(ix.runOf(a)!.present, [a]);
      expect(ix.runOf(b)!.present, [b]);
    });

    test('a row that disagrees stands alone', () {
      final r0 = _Row('r0', const AlbumTag(_a, 3, 0));
      final twin = _Row('twin', const AlbumTag(_a, 3, 0));
      final other = _Row('other', const AlbumTag(_a, 5, 1));
      final text = _Row('text', const AlbumTag(_a, 3, 1), media: false);
      final ix = _index([r0, twin, other, text]);
      expect(ix.runOf(r0)!.present, [r0]);
      expect(ix.runOf(twin), isNull);
      expect(ix.runOf(other), isNull);
      expect(ix.runOf(text), isNull);
    });

    test('rows of no album are left as they are', () {
      final plain = const _Row('plain', null);
      final ix = _index([plain]);
      expect(ix.runOf(plain), isNull);
      expect(ix.runs, isEmpty);
    });
  });

  group('round two', () {
    const min = 60000;

    test('one written past the window stands alone, within it joins', () {
      final r0 = const _Row('r0', AlbumTag(_a, 3, 0));
      final near = const _Row('near', AlbumTag(_a, 3, 1), at: 10 * min);
      final far = const _Row('far', AlbumTag(_a, 3, 2), at: 10 * min + 1);
      final ix = _index([r0, near, far]);
      expect(ix.runOf(r0)!.present, [r0, near]);
      expect(ix.runOf(far), isNull);
      expect(ix.hidden(far), isFalse);
      expect(albumInWindow(0, 10 * min), isTrue);
      expect(albumInWindow(10 * min + 1, 0), isFalse);
    });

    test('with its first places missing, what is here is drawn', () {
      final rows = [
        for (var i = 4; i < 9; i++) _Row('r$i', AlbumTag(_a, 9, i)),
      ];
      final run = _index(rows).runOf(rows.first)!;
      expect(run.drawn, rows);
      // with the first here, a place for each
      final r0 = const _Row('r0', AlbumTag(_b, 3, 0));
      final full = _index([r0]).runOf(r0)!;
      expect(full.drawn, [r0, null, null]);
    });

    test('any tile opens the viewer on what is here', () {
      expect(albumOpenAt(['a', null, 'c', null], 0), 0);
      expect(albumOpenAt(['a', null, 'c', null], 1), 1);
      expect(albumOpenAt(['a', null, 'c', null], 2), 1);
      expect(albumOpenAt(['a', null, 'c', null], 3), 1);
      expect(albumOpenAt([null, null, 'c'], 0), 0);
      expect(albumOpenAt(<String?>[null, null], 0), isNull);
    });

    test('the caption is the first words any item carries', () {
      final rows = [
        const _Row('r0', AlbumTag(_a, 3, 0)),
        const _Row('r1', AlbumTag(_a, 3, 1), text: '  '),
        const _Row('r2', AlbumTag(_a, 3, 2), text: 'look'),
      ];
      expect(_index(rows).runOf(rows[0])!.caption((r) => r.text), 'look');
      final quiet = [const _Row('q', AlbumTag(_b, 2, 0))];
      expect(_index(quiet).runOf(quiet[0])!.caption((r) => r.text), '');
    });

    test('a late item takes the album\'s clock, but never under the '
        'grace, and never past its own', () {
      const now = 1000000;
      final grace = kAlbumBurnGrace.inMilliseconds;
      // the album burns well after now: the late item burns with it
      expect(albumItemBurnAt(now + 60000, [now + 30000], now), now + 30000);
      // the album is about to burn: the late item still shows a while
      expect(albumItemBurnAt(now + 60000, [now + 1000], now), now + grace);
      // its own window is shorter than the grace: its own
      expect(albumItemBurnAt(now + 3000, [now + 1000], now), now + 3000);
      // alone, its own
      expect(albumItemBurnAt(now + 3000, [null], now), now + 3000);
    });
  });

  test('reactions show each reactor once, the first item first', () {
    expect(
      albumReactions([
        {'': '❤️'},
        {'': '👍', 'bob': '😂'},
        {'bob': '🔥', 'carol': '😮'},
      ]),
      {'': '❤️', 'bob': '😂', 'carol': '😮'},
    );
  });

  test('an album burns on the earliest clock any item has', () {
    expect(albumBurnAt([null, null]), isNull);
    expect(albumBurnAt([500, null, 300, 900]), 300);
  });
}
