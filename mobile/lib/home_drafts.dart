// SPDX-License-Identifier: GPL-3.0-or-later
// the drafts the chat list shows in place of a row's last message. read
// from the open session's own containers: a hidden chat's only while its
// vault is open, the decoy's only in the decoy. memory only, dropped the
// moment the session or its vault changes
import 'package:flutter/foundation.dart';

import 'bidi_safe.dart' show unmarked;
import 'dlog.dart';
import 'drafts.dart' show KeptDraft;
import 'lock_guard.dart' show lockGuard;

class HomeDrafts {
  HomeDrafts._();

  /// a row's draft by [rowKey], as one line
  static final shown = ValueNotifier<Map<String, String>>(const {});

  /// when each of [shown] was last typed, in ms: the list moves its row up
  static Map<String, int> times = const {};
  static Object? _of;
  static int _turn = 0;
  static VoidCallback? _lockOff;

  /// nothing is held: a lock or a wipe let them go, read them again
  static bool get unread => _of == null;

  static String rowKey(String chat, {required bool group}) =>
      '${group ? 'g' : 'p'}:$chat';

  /// [who] names the session and whether its vault is open: another one
  /// lets the old drafts go before anything is read
  static Future<void> reload(
    Object who,
    Future<List<KeptDraft>> Function() read,
  ) async {
    if (!identical(who, _of)) {
      _of = who;
      times = const {};
      shown.value = const {};
    }
    // the lock takes them from memory; the list reads them again after
    _lockOff?.call();
    _lockOff = lockGuard.closeOnLock(clear);
    final turn = ++_turn;
    List<KeptDraft> all;
    try {
      all = await read();
    } catch (e) {
      dlog('home drafts: not read (${e.runtimeType})');
      return;
    }
    if (turn != _turn || !identical(who, _of)) return;
    final kept = [
      for (final d in all)
        if (oneLine(d.draft.text) case final t when t.isNotEmpty)
          (rowKey(d.chat, group: d.group), t, d.draft.at),
    ];
    times = {for (final (k, _, at) in kept) k: at};
    shown.value = {for (final (k, t, _) in kept) k: t};
  }

  /// nothing shown, as at a lock or a wipe
  static void clear() {
    _lockOff?.call();
    _lockOff = null;
    _of = null;
    _turn++;
    times = const {};
    shown.value = const {};
  }

  /// a draft as the row writes it: its first line that has words, without
  /// direction controls
  @visibleForTesting
  static String oneLine(String text) {
    for (final l in unmarked(text).split('\n')) {
      final t = l.trim();
      if (t.isNotEmpty) return t.length > 120 ? t.substring(0, 120) : t;
    }
    return '';
  }
}
