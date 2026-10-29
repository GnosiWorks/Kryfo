// SPDX-License-Identifier: GPL-3.0-or-later
// the notification while files send or come in: how far, never which chat
// or which file. with message previews hidden it says only that files
// move; with plain notifications it takes the neutral icon; while kryfo is
// quiet it shows nothing. on a phone without the always on service it
// keeps the process up until the files are across. plain notifications
// give it one neutral word and a bar
import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import 'delivery_mode.dart';
import 'dlog.dart';
import 'l10n/l10n.dart';
import 'lock_state.dart' show lockState, quietNow;
import 'media_progress.dart';
import 'notifications.dart' show loadHideNotifContent, loadNotifPlain;
import 'transfers.dart';
import 'widgets/media_bubbles.dart' show humanFileSize;

const _ch = MethodChannel('kryfo/transfers');

/// what the notification says for what moves now. null: nothing moves.
/// [plain]: one neutral word that android's side puts in, and no line
({String title, String? text, int done, int total})? transferNoteOf(
  ({int sending, int receiving, int done, int total}) now, {
  required bool hidden,
  bool plain = false,
}) {
  if (now.sending == 0 && now.receiving == 0) return null;
  // kilobytes: what an int on the other side holds
  final done = now.done ~/ 1024, total = now.total ~/ 1024;
  // plain wins over previews, as for a message
  if (plain) return (title: '', text: null, done: done, total: total);
  final title = l10n.transferNoteTitle;
  if (hidden) return (title: title, text: null, done: done, total: total);
  final of = l10n.transferDoneOf(
    humanFileSize(now.done),
    humanFileSize(now.total),
  );
  final text = now.sending > 0 && now.receiving > 0
      ? l10n.transferBoth(of)
      : now.sending > 0
      ? l10n.transferSending(of)
      : l10n.transferReceiving(of);
  return (title: title, text: text, done: done, total: total);
}

class TransferNote {
  TransferNote._(this._quietRead);
  static final TransferNote instance = TransferNote._(quietNow);

  /// one of its own, for a test: [quiet] stands for the lock's word
  @visibleForTesting
  factory TransferNote.forTest(Future<bool> Function() quiet) =>
      TransferNote._(quiet);

  final Future<bool> Function() _quietRead;
  bool _up = false;
  bool _started = false;
  Timer? _tick;
  // while it is up: a look now and then, so a transfer that stalled with
  // no tick still takes it down
  Timer? _look;
  // the lock's quiet word, read once per lock or session change
  bool? _quiet;
  int _quietGen = 0;
  // one post at a time: a quiet look never passes a show still on its way
  Future<void> _last = Future.value();

  /// follows the transfers from now on. one left up by a process that
  /// died goes first
  void start() {
    if (_started) return;
    _started = true;
    unawaited(_end());
    mediaProgressTick.addListener(_soon);
    fileWaits.addListener(_soon);
    lockState.addListener(refresh);
  }

  /// stops following: a test's own note goes with its test
  @visibleForTesting
  void stopForTest() {
    mediaProgressTick.removeListener(_soon);
    fileWaits.removeListener(_soon);
    lockState.removeListener(refresh);
    _tick?.cancel();
    _look?.cancel();
    _started = false;
  }

  /// the session or the lock changed: quiet is read again, and the note
  /// goes at once when it is quiet now
  void refresh() {
    _quiet = null;
    _quietGen++;
    if (!_started) return;
    _tick?.cancel();
    _tick = null;
    _post();
  }

  // at most a post a second: android drops faster updates anyway
  void _soon() {
    _tick ??= Timer(const Duration(seconds: 1), () {
      _tick = null;
      _post();
    });
  }

  void _post() => _last = _last.then((_) => _postNow());

  Future<void> _end() async {
    _up = false;
    _look?.cancel();
    _look = null;
    try {
      await _ch.invokeMethod<bool>('end');
    } on MissingPluginException {
      // no android side
    } catch (e) {
      dlog('transfers: note not ended (${e.runtimeType})');
    }
  }

  Future<void> _postNow() async {
    try {
      var quiet = _quiet;
      if (quiet == null) {
        final gen = _quietGen;
        quiet = await _quietRead();
        // a change while it was read: the post after this one reads again
        if (gen == _quietGen) _quiet = quiet;
      }
      if (quiet) {
        // quiet: nothing of kryfo shows, whatever moves
        if (_up) await _end();
        return;
      }
      final now = transfersNow();
      final plain = await loadNotifPlain();
      final note = transferNoteOf(
        now,
        hidden: await loadHideNotifContent(),
        plain: plain,
      );
      if (note == null) {
        if (_up) await _end();
        return;
      }
      final mode = await loadDeliveryMode();
      await _ch.invokeMethod<bool>('show', {
        // plain: a channel name that says nothing either
        'channel': plain ? l10n.notifPlainChannel : l10n.transferChannel,
        'channelLine': plain ? '' : l10n.transferChannelLine,
        'title': note.title,
        'text': note.text,
        'done': note.done,
        'total': note.total,
        'plain': plain,
        // the always on service keeps the process already
        'hold': mode != DeliveryMode.always,
      });
      _up = true;
      _look ??= Timer.periodic(const Duration(seconds: 15), (_) => _soon());
    } on MissingPluginException {
      // no android side: the desktop has no such notification
    } catch (e) {
      dlog('transfers: note not posted (${e.runtimeType})');
    }
  }
}
