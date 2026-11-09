// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

// the worker's open models by direction, least recently used first. each
// is about 50 MB, so past [max] the oldest goes before another opens. a held
// one (a translation under way, both legs of a pivot) is never closed: it
// can keep the count past max for a while, and goes on a later trim
class ModelCache<H extends Object> {
  final int max;
  final void Function(H) _close;
  // a linked map: insertion order is use order
  final _open = <String, H>{};
  ModelCache(this.max, this._close);

  Iterable<String> get keys => _open.keys;
  int get length => _open.length;

  // the open model for key, now the most recently used
  H? use(String key) {
    final h = _open.remove(key);
    if (h != null) _open[key] = h;
    return h;
  }

  // before key opens: room for it, closing only what is not held
  void makeRoom(String key, Iterable<String> held) =>
      _trim(max - 1, {...held, key});

  void add(String key, H h) {
    final old = _open.remove(key);
    if (old != null && !identical(old, h)) _close(old);
    _open[key] = h;
  }

  // down to max again once a hold has let go
  void trim(Iterable<String> held) => _trim(max, held.toSet());

  void _trim(int to, Set<String> keep) {
    for (final k in [..._open.keys]) {
      if (_open.length <= to) return;
      if (keep.contains(k)) continue;
      _close(_open.remove(k)!);
    }
  }

  void closeAll() {
    final all = [..._open.values];
    _open.clear();
    all.forEach(_close);
  }
}

// models stay in memory only while used: the worker goes [after] the last
// translation or hold let go, and on away() as soon as nothing runs. a
// translation or a hold under way (both legs of a pivot) is never cut
class ModelIdle {
  final Duration after;
  final void Function() _shut;
  ModelIdle(this.after, this._shut);

  int _busy = 0;
  int get busy => _busy;
  Timer? _timer;
  bool get timing => _timer != null;
  bool _away = false;
  bool get awayPending => _away;

  void begin() {
    _busy++;
    _timer?.cancel();
    _timer = null;
  }

  void end() {
    if (_busy > 0) _busy--;
    if (_busy > 0) return;
    if (_away) return shut();
    _timer?.cancel();
    _timer = Timer(after, () {
      _timer = null;
      if (_busy == 0) shut();
    });
  }

  // the app went to the background: now, or once the last one ends
  void away() {
    if (_busy > 0) {
      _away = true;
      return;
    }
    shut();
  }

  void shut() {
    _away = false;
    _timer?.cancel();
    _timer = null;
    _shut();
  }
}
