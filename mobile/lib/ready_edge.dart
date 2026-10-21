// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';

/// calls [onReady] once each time [ready] turns true, as [source] changes.
/// a source that notifies often, tor's status every few seconds, must not
/// ask again while nothing moved
class ReadyEdge {
  ReadyEdge(this._source, this._ready, this._onReady) : _was = _ready() {
    _source.addListener(_look);
  }

  final Listenable _source;
  final bool Function() _ready;
  final VoidCallback _onReady;
  bool _was;

  void _look() {
    final now = _ready();
    if (now && !_was) _onReady();
    _was = now;
  }

  void dispose() => _source.removeListener(_look);
}
