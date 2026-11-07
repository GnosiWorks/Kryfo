// SPDX-License-Identifier: GPL-3.0-or-later
// the files a history copy still brings to this device: a photo or a voice
// note whose row came before its bytes shows as on its way, not as lost,
// and draws itself once its file lands
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class HistoryFilesComing extends ChangeNotifier {
  final _waiting = <String>{};

  /// true while the copy still brings the file at [path]
  bool coming(String? path) =>
      path != null &&
      _waiting.isNotEmpty &&
      _waiting.contains(p.normalize(path));

  bool get any => _waiting.isNotEmpty;

  /// files the copy will bring, on top of those it brings already
  void add(Iterable<String> paths) {
    final n = _waiting.length;
    _waiting.addAll(paths.map(p.normalize));
    if (_waiting.length != n) notifyListeners();
  }

  /// the files the copy brings, as its list says: any other no longer comes
  void only(Iterable<String> paths) {
    final want = paths.map(p.normalize).toSet();
    final was = _waiting.length;
    _waiting.retainWhere(want.contains);
    final more = want.difference(_waiting);
    _waiting.addAll(more);
    if (_waiting.length != was || more.isNotEmpty) notifyListeners();
  }

  /// the file at [path] landed, or will not come
  void done(String path) {
    if (_waiting.remove(p.normalize(path))) notifyListeners();
  }

  /// the copy is over or stopped here: nothing more is awaited
  void clear() {
    if (_waiting.isEmpty) return;
    _waiting.clear();
    notifyListeners();
  }
}

/// this device's copy, for the bubbles
final historyFilesComing = HistoryFilesComing();
