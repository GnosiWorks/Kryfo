// SPDX-License-Identifier: GPL-3.0-or-later
// find in one chat: the hits come from the search index of the chat's own
// database, so the whole chat is searched without loading it. the screens
// bring the thread in around a hit only when one is moved to. a hit is a
// row id; the count and the place are over every hit, loaded or not
import 'dart:async';

import 'main.dart' show ChatHit;
import 'msg_order.dart' show byWritten;
import 'search.dart' show ftsMatch, matchRanges;

/// a chat's rows that are held in memory, for hits the index has not taken
/// in yet: the first fill runs in the background after an update
typedef HeldRow = ({int id, int at, String text});

class ChatFind {
  String query = '';
  // every hit, oldest first in the chat's order
  List<ChatHit> _hits = const [];
  int _pos = 0;
  int _ask = 0;

  List<ChatHit> get hits => _hits;
  int get count => _hits.length;

  /// 1-based, as the head says it; 0 with no hits
  int get shown => _hits.isEmpty ? 0 : _pos + 1;

  /// the row in view, null with no hits
  int? get current => _hits.isEmpty ? null : _hits[_pos].id;

  bool get active => query.isNotEmpty;

  /// looks for [raw]: false when a newer look overtook this one. [index]
  /// asks the chat's index; a failure there leaves the rows in [held].
  /// [stay]: the same question again, the hit in view kept when it still is
  Future<bool> look(
    String raw,
    Future<List<ChatHit>> Function(String match) index,
    Iterable<HeldRow> held, {
    bool stay = false,
  }) async {
    final was = current;
    final ask = ++_ask;
    final q = raw.trim();
    final match = q.isEmpty ? null : ftsMatch(q);
    var found = <ChatHit>[];
    if (match != null) {
      try {
        found = List.of(await index(match));
      } catch (_) {
        // the index not there: what is on screen is still looked at
      }
      if (ask != _ask) return false;
      final have = {for (final h in found) h.id};
      for (final r in held) {
        if (r.id <= 0 || have.contains(r.id)) continue;
        if (matchRanges(r.text, q).isNotEmpty) {
          found.add((id: r.id, at: r.at));
        }
      }
      found.sort((a, b) => byWritten(a.at, a.id, b.at, b.id));
    }
    if (ask != _ask) return false;
    final same = q == query;
    query = q;
    _hits = found;
    // the newest first, as the list opens at the bottom
    final kept = stay && same ? found.indexWhere((h) => h.id == was) : -1;
    _pos = kept >= 0 ? kept : (found.isEmpty ? 0 : found.length - 1);
    return true;
  }

  /// one step: -1 older, +1 newer, wrapping
  int? step(int delta) {
    if (_hits.isEmpty) return null;
    _pos = (_pos + delta) % _hits.length;
    if (_pos < 0) _pos += _hits.length;
    return current;
  }

  /// a hit that turned out to be gone
  void drop(int id) {
    final i = _hits.indexWhere((h) => h.id == id);
    if (i < 0) return;
    _hits = [..._hits]..removeAt(i);
    if (i < _pos) _pos--;
    if (_pos >= _hits.length) _pos = _hits.isEmpty ? 0 : _hits.length - 1;
  }

  void clear() {
    _ask++;
    query = '';
    _hits = const [];
    _pos = 0;
  }

  /// the ids of every hit, for the rows' highlight
  Set<int> get ids => {for (final h in _hits) h.id};
}

/// says "finding" only when the wait is long enough to notice: [on] after
/// [after], off at once when the work ends
class SlowLine {
  SlowLine(this.on, {this.after = const Duration(milliseconds: 300)});
  final void Function(bool shown) on;
  final Duration after;
  Timer? _t;
  bool _shown = false;

  Future<T> over<T>(Future<T> Function() work) async {
    _t?.cancel();
    _t = Timer(after, () {
      _shown = true;
      on(true);
    });
    try {
      return await work();
    } finally {
      _t?.cancel();
      _t = null;
      if (_shown) {
        _shown = false;
        on(false);
      }
    }
  }

  void dispose() => _t?.cancel();
}
