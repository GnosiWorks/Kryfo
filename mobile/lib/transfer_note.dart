// SPDX-License-Identifier: GPL-3.0-or-later
// the notification while files send or come in: how far, never which chat
// or which file. with message previews hidden it says only that files
// move; with plain notifications it takes the neutral icon; while kryfo is
// quiet it shows nothing. on a phone without the always on service it
// keeps the process up until the files are across
import 'dart:async';

import 'package:flutter/services.dart';

import 'delivery_mode.dart';
import 'dlog.dart';
import 'l10n/l10n.dart';
import 'lock_state.dart' show quietNow;
import 'media_progress.dart';
import 'notifications.dart' show loadHideNotifContent, loadNotifPlain;
import 'transfers.dart';
import 'widgets/media_bubbles.dart' show humanFileSize;

const _ch = MethodChannel('kryfo/transfers');

/// what the notification says for what moves now. null: nothing moves
({String title, String? text, int done, int total})? transferNoteOf(
  ({int sending, int receiving, int done, int total}) now, {
  required bool hidden,
}) {
  if (now.sending == 0 && now.receiving == 0) return null;
  final title = l10n.transferNoteTitle;
  // kilobytes: what an int on the other side holds
  final done = now.done ~/ 1024, total = now.total ~/ 1024;
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
  TransferNote._();
  static final TransferNote instance = TransferNote._();

  bool _up = false;
  bool _started = false;
  Timer? _tick;

  /// follows the transfers from now on
  void start() {
    if (_started) return;
    _started = true;
    mediaProgressTick.addListener(_soon);
    fileWaits.addListener(_soon);
  }

  // at most a post a second: android drops faster updates anyway
  void _soon() {
    _tick ??= Timer(const Duration(seconds: 1), () {
      _tick = null;
      unawaited(_post());
    });
  }

  Future<void> _post() async {
    try {
      final now = transfersNow();
      final quiet = await quietNow();
      final note = quiet
          ? null
          : transferNoteOf(now, hidden: await loadHideNotifContent());
      if (note == null) {
        if (_up) {
          _up = false;
          await _ch.invokeMethod<bool>('end');
        }
        return;
      }
      final mode = await loadDeliveryMode();
      await _ch.invokeMethod<bool>('show', {
        'channel': l10n.transferChannel,
        'channelLine': l10n.transferChannelLine,
        'title': note.title,
        'text': note.text,
        'done': note.done,
        'total': note.total,
        'plain': await loadNotifPlain(),
        // the always on service keeps the process already
        'hold': mode != DeliveryMode.always,
      });
      _up = true;
    } on MissingPluginException {
      // no android side: the desktop has no such notification
    } catch (e) {
      dlog('transfers: note not posted (${e.runtimeType})');
    }
  }
}
