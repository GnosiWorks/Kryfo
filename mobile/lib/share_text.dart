// SPDX-License-Identifier: GPL-3.0-or-later
// words another app shares: its subject and its text made one, cleaned as
// anything else that comes in, and cut to what a message holds. they wait
// for the lock, and what one session was shown never shows in another
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'bidi_safe.dart';
import 'lock_guard.dart';

// the most a shared text puts in the composer
const kShareTextMax = 4096;

// controls nobody types, line breaks and tabs aside
final _controls = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');

String _clean(String? s) => unmarked(
  (s ?? '').replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
).replaceAll(_controls, '').trim();

/// the words to land: the subject over the text, unless the text already
/// says it. empty when neither says anything
String sharedWords({String? subject, String? text, int max = kShareTextMax}) {
  final s = _clean(subject);
  final t = _clean(text);
  var words = s.isEmpty || t.contains(s)
      ? t
      : t.isEmpty
      ? s
      : '$s\n$t';
  words = words.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  if (words.length <= max) return words;
  // whole characters only: an emoji or an accent is never cut in two
  final out = StringBuffer();
  for (final c in words.characters) {
    if (out.length + c.length > max) break;
    out.write(c);
  }
  return out.toString().trimRight();
}

class SharedText {
  final String id;
  final String words;
  // the session it was shown in, once it was
  final String? seenIn;
  const SharedText(this.id, this.words, {this.seenIn});

  static SharedText? from(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    return SharedText(
      id,
      sharedWords(
        subject: raw['subject'] as String?,
        text: raw['text'] as String?,
      ),
      seenIn: raw['seen'] as String?,
    );
  }
}

/// the session a share is shown in: the everyday one or the decoy, and
/// whether a vault is open over it
String shareSessionTag({required bool decoy, required bool vault}) =>
    '${decoy ? 'decoy' : 'everyday'}${vault ? '+vault' : ''}';

class ShareGate {
  ShareGate({required this.guard, required this.where});

  final LockGuard guard;
  final String Function() where;

  /// true once [s] may be shown, now or after an unlock. one that came under
  /// the lock goes to whichever session opens it, and is let go when the
  /// app is left first. one already shown shows only in its own session
  Future<bool> clear(SharedText s) async {
    if (guard.isLocked() && !await _unlocked(dropOnLeave: s.seenIn == null)) {
      return false;
    }
    return s.seenIn == null || s.seenIn == where();
  }

  Future<bool> _unlocked({required bool dropOnLeave}) {
    final done = Completer<bool>();
    final watch = _Leave(() {
      if (dropOnLeave && !done.isCompleted) done.complete(false);
    });
    guard.anyUnlock().then((_) {
      if (!done.isCompleted) done.complete(true);
    });
    return done.future.whenComplete(watch.stop);
  }
}

// the app going off screen after it was in front. one that arrives in the
// background passes through hidden on its way up, which is not leaving
class _Leave with WidgetsBindingObserver {
  _Leave(this.left) {
    _front =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  final VoidCallback left;
  bool _front = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _front = true;
    } else if (_front &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      left();
    }
  }

  void stop() => WidgetsBinding.instance.removeObserver(this);
}
