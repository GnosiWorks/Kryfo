// SPDX-License-Identifier: GPL-3.0-or-later
// photos and videos picked together go as one album. each item still
// travels as its own message; 'al' on every slice says which album it is
// in, how many it has and where it stands. a phone without albums reads
// past the field and shows the items one by one, as before.
import 'dart:math' as math;
import 'dart:ui' show Rect;

/// the most one album holds; a bigger pick goes as several
const kAlbumMax = 10;

/// the most a pick holds before the preview takes no more
const kPickMax = 30;

/// the most an album that came in may say it holds
const kAlbumMaxIn = 32;

final _albumId = RegExp(r'^[0-9a-f]{16,32}$');
final _rnd = math.Random.secure();

String newAlbumId() =>
    [for (var i = 0; i < 16; i++) _rnd.nextInt(16).toRadixString(16)].join();

class AlbumTag {
  final String id;
  final int n;
  final int i;
  // files sent together: one bubble with a row each. they travel under
  // 'fa', which a phone before them reads past, and are kept with an 'f:'
  // before their id so a photo album never takes one in
  final bool files;
  const AlbumTag(this.id, this.n, this.i, {this.files = false});

  /// the id as a row keeps it
  String get rowId => files ? '$kFileSetRow$id' : id;

  /// the frame's field the tag goes under
  String get wireKey => files ? kFileSetWire : 'al';

  Map<String, Object> toWire() => {'id': id, 'n': n, 'i': i};

  Map<String, Object?> toRow() => {
    'album_id': rowId,
    'album_n': n,
    'album_i': i,
  };

  static AlbumTag? _of(Object? id, Object? n, Object? i, {bool files = false}) {
    if (id is String && id.startsWith(kFileSetRow)) {
      id = id.substring(kFileSetRow.length);
      files = true;
    }
    if (id is! String || !_albumId.hasMatch(id)) return null;
    if (n is! num || i is! num) return null;
    if (n != n.truncate() || i != i.truncate()) return null;
    final count = n.toInt();
    final at = i.toInt();
    if (count < 2 || count > kAlbumMaxIn || at < 0 || at >= count) {
      return null;
    }
    return AlbumTag(id, count, at, files: files);
  }

  /// null for anything that is not a whole, sane album place. [files]: it
  /// came under 'fa'
  static AlbumTag? fromWire(Object? raw, {bool files = false}) => raw is Map
      ? _of(
          raw['id'] is String && (raw['id'] as String).startsWith(kFileSetRow)
              ? null
              : raw['id'],
          raw['n'],
          raw['i'],
          files: files,
        )
      : null;

  static AlbumTag? ofRow(Map<String, Object?> r) =>
      _of(r['album_id'], r['album_n'], r['album_i']);

  @override
  bool operator ==(Object other) =>
      other is AlbumTag &&
      other.id == id &&
      other.n == n &&
      other.i == i &&
      other.files == files;

  @override
  int get hashCode => Object.hash(id, n, i, files);

  @override
  String toString() => 'AlbumTag($id, $i of $n${files ? ', files' : ''})';
}

/// the frame's field for a place among files sent together
const kFileSetWire = 'fa';

/// what a file set's id is kept under, apart from photo albums
const kFileSetRow = 'f:';

/// [items] cut into albums of at most [max], as even as they go: eleven are
/// six and five, never ten and one left on its own
List<List<T>> albumBatches<T>(List<T> items, {int max = kAlbumMax}) {
  if (items.isEmpty) return const [];
  final parts = (items.length + max - 1) ~/ max;
  final base = items.length ~/ parts;
  final extra = items.length % parts;
  final out = <List<T>>[];
  var at = 0;
  for (var p = 0; p < parts; p++) {
    final size = base + (p < extra ? 1 : 0);
    out.add(items.sublist(at, at + size));
    at += size;
  }
  return out;
}

/// how [items] go: each with its caption and its place. albums of up to
/// [max] in the order given, the caption on the very first item only, and
/// each on its own with no album when [alone] (to someone who has not
/// accepted yet, where each counts on its own)
List<({T item, String caption, AlbumTag? album})> albumPlan<T>(
  List<T> items,
  String caption, {
  bool alone = false,
  int max = kAlbumMax,
  bool files = false,
}) {
  final out = <({T item, String caption, AlbumTag? album})>[];
  final batches = alone
      ? [
          for (final x in items) [x],
        ]
      : albumBatches(items, max: max);
  for (final b in batches) {
    final id = b.length > 1 ? newAlbumId() : null;
    for (final (i, x) in b.indexed) {
      out.add((
        item: x,
        caption: out.isEmpty ? caption : '',
        album: id == null ? null : AlbumTag(id, b.length, i, files: files),
      ));
    }
  }
  return out;
}

/// one tile of an album's grid. [rect] is measured from the start edge, so
/// the grid mirrors in a right-to-left language. [more] is how many items
/// the tile stands for beyond itself
class AlbumCell {
  final int slot;
  final Rect rect;
  final int more;
  const AlbumCell(this.slot, this.rect, {this.more = 0});
}

const kAlbumGap = 2.0;

/// the grid's height for [n] items at width [w]. it hangs on the count
/// alone, so nothing moves as the items land
double albumHeight(int n, double w) => switch (n) {
  <= 1 => w,
  2 => w * 0.62,
  3 => w * 0.8,
  _ => w,
};

/// two side by side, three as one big and two small, four as two by two,
/// more as two by two with the rest counted on the last
List<AlbumCell> albumCells(int n, double w) {
  const g = kAlbumGap;
  final h = albumHeight(n, w);
  if (n <= 1) return [AlbumCell(0, Rect.fromLTWH(0, 0, w, h))];
  if (n == 2) {
    final cw = (w - g) / 2;
    return [
      AlbumCell(0, Rect.fromLTWH(0, 0, cw, h)),
      AlbumCell(1, Rect.fromLTWH(cw + g, 0, cw, h)),
    ];
  }
  if (n == 3) {
    final big = (w - g) * 0.62;
    final small = w - g - big;
    final sh = (h - g) / 2;
    return [
      AlbumCell(0, Rect.fromLTWH(0, 0, big, h)),
      AlbumCell(1, Rect.fromLTWH(big + g, 0, small, sh)),
      AlbumCell(2, Rect.fromLTWH(big + g, sh + g, small, sh)),
    ];
  }
  final c = (w - g) / 2;
  return [
    AlbumCell(0, Rect.fromLTWH(0, 0, c, c)),
    AlbumCell(1, Rect.fromLTWH(c + g, 0, c, c)),
    AlbumCell(2, Rect.fromLTWH(0, c + g, c, c)),
    AlbumCell(3, Rect.fromLTWH(c + g, c + g, c, c), more: n - 4),
  ];
}

/// how far apart an album's items may have been written. one written
/// further from the album's first row is no part of it and stands alone
const kAlbumWindow = Duration(minutes: 10);

/// what an album that came in and went is remembered under in gone_in,
/// beside the uids of its items
String albumGoneUid(String albumId) => 'al:$albumId';

/// whether an item written at [written] may join an album whose first row
/// was written at [first]
bool albumInWindow(int first, int written) =>
    (written - first).abs() <= kAlbumWindow.inMilliseconds;

/// one album as a chat holds it: a slot per place, null for one not here
/// yet. [lead] is the first of it in the chat's order, the row that draws
/// the whole album, and [start] when that row was written
class AlbumRun<T> {
  final String key;
  final AlbumTag tag;
  final List<T?> slots;
  final int start;
  T lead;
  AlbumRun(this.key, this.tag, this.lead, this.start)
    : slots = List.filled(tag.n, null);

  int get n => tag.n;

  /// the ones here, in album order
  List<T> get present => [for (final s in slots) ?s];

  bool get whole => slots.every((s) => s != null);

  /// what the grid draws: a place for each, so nothing moves as the rest
  /// lands, while the first is here; with the first places missing, only
  /// what is here, so nothing that came hides behind an empty tile
  List<T?> get drawn => slots.first == null ? present : slots;

  /// the caption: the first words any of it carries, the first item's as
  /// sent
  String caption(String Function(T) text) {
    for (final s in present) {
      final t = text(s);
      if (t.trim().isNotEmpty) return t;
    }
    return '';
  }

  /// what the album's reactions, replies and pins go to: its first item, or
  /// the first one here while that one is still on its way
  T get anchor => present.isEmpty ? lead : present.first;
}

/// a chat's albums. a row is in one when it carries a tag, is a photo or a
/// video ([media]), its place is free, it agrees on the count, and it was
/// written within [kAlbumWindow] of the album's first row ([written]); any
/// other row stands alone. [owner] keeps two senders' albums apart
class AlbumIndex<T> {
  final Map<String, AlbumRun<T>> _runs = {};
  final Map<T, AlbumRun<T>> _of = Map.identity();

  AlbumIndex(
    Iterable<T> rows, {
    required AlbumTag? Function(T) tag,
    required String Function(T) owner,
    required bool Function(T) media,
    required int Function(T) written,
    // a row a set of files may hold: a file, not a voice note or words
    bool Function(T)? file,
  }) {
    for (final r in rows) {
      final t = tag(r);
      // a set of files takes any row that says so; an album only photos
      // and videos
      if (t == null || !(t.files ? (file?.call(r) ?? true) : media(r))) {
        continue;
      }
      final key = '${owner(r)}\u0000${t.files ? kFileSetRow : ''}${t.id}';
      final run = _runs.putIfAbsent(
        key,
        () => AlbumRun<T>(key, t, r, written(r)),
      );
      if (run.n != t.n || run.slots[t.i] != null) continue;
      if (!albumInWindow(run.start, written(r))) continue;
      run.slots[t.i] = r;
      _of[r] = run;
    }
  }

  AlbumRun<T>? runOf(T row) => _of[row];

  bool isLead(T row) {
    final run = _of[row];
    return run != null && identical(run.lead, row);
  }

  /// in the chat but drawn by its album's lead
  bool hidden(T row) {
    final run = _of[row];
    return run != null && !identical(run.lead, row);
  }

  Iterable<AlbumRun<T>> get runs => _runs.values;
}

/// where the viewer opens for tile [at] of [drawn]: its own item, or for a
/// place still coming the next item here, else the last one before it.
/// counted over what is here. null when nothing is
int? albumOpenAt<T>(List<T?> drawn, int at) {
  final here = [
    for (final (i, x) in drawn.indexed)
      if (x != null) i,
  ];
  if (here.isEmpty) return null;
  final next = here.indexWhere((i) => i >= at);
  return next >= 0 ? next : here.length - 1;
}

/// the reactions an album shows: each reactor once, from the first item
/// they reacted to
Map<String, String> albumReactions(Iterable<Map<String, String>> members) {
  final out = <String, String>{};
  for (final m in members) {
    for (final e in m.entries) {
      out.putIfAbsent(e.key, () => e.value);
    }
  }
  return out;
}

/// the clock an album burns on: the earliest any of its items has, so all
/// of it goes together. null while none has one
int? albumBurnAt(Iterable<int?> clocks) {
  int? at;
  for (final c in clocks) {
    if (c != null && (at == null || c < at)) at = c;
  }
  return at;
}

/// the least an item that joins an album late is shown for: it never
/// lands burned already
const kAlbumBurnGrace = Duration(seconds: 10);

/// the clock an item of an album takes: the album's ([mates]), held to at
/// least [kAlbumBurnGrace] from [now], and never past its own ([own])
int albumItemBurnAt(int own, Iterable<int?> mates, int now) {
  final album = albumBurnAt(mates);
  if (album == null) return own;
  return math.min(own, math.max(album, now + kAlbumBurnGrace.inMilliseconds));
}
