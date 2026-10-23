// SPDX-License-Identifier: GPL-3.0-or-later
// unsent drafts, so text survives leaving a chat and android stopping the
// app. each one is a row in the database of the container that holds its
// chat: a hidden chat's only in the vault, the decoy's only in the decoy.
// memory keeps the ones seen in this process, keyed by chatKey
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'container.dart';
import 'dlog.dart';
import 'secure_store.dart';

/// what a composer held and did not send
@immutable
class Draft {
  const Draft(this.text, {this.replyTo, this.at = 0});

  final String text;
  // the uid of the message it quotes
  final String? replyTo;
  // when it was last typed, in ms: the chat list orders by it
  final int at;

  bool get isEmpty => text.trim().isEmpty;

  bool sameAs(Draft o) => text == o.text && replyTo == o.replyTo;
}

/// a draft as the chat list reads it: its chat, and whether a group's
typedef KeptDraft = ({String chat, bool group, Draft draft});

/// where a container's drafts are kept: its own database
abstract interface class DraftRows {
  HaloContainer get container;
  // a shut database is never opened for a draft: a vault that locked or a
  // decoy being removed must not come back as a new file
  bool get isOpen;
  Future<Draft?> draftOf(String chatId, {required bool group});
  Future<void> putDraft(String chatId, Draft d, {required bool group});
  Future<void> dropDraftRow(String chatId, {required bool group});
}

/// how long typing rests before the draft is written
const kDraftWait = Duration(milliseconds: 400);

class _Waiting {
  _Waiting(this.rows, this.chatId, this.group, this.draft, this.timer);
  final DraftRows rows;
  final String chatId;
  final bool group;
  final Draft draft;
  final Timer timer;
}

final Map<String, Draft> _held = {};
final Map<String, _Waiting> _waiting = {};
// set by a wipe: nothing is held or written after it
bool _shut = false;

/// goes up when a draft is written or dropped, for the chat list
final draftsRevision = ValueNotifier<int>(0);

String _key(HaloContainer c, String chatId, bool group) =>
    '${group ? 'g' : 'p'}${c.chatKey(chatId)}';

// a key of [c]'s: past the p or g, its chatKey
bool _ofContainer(HaloContainer c, String k) => k.startsWith(c.chatKey(''), 1);

void _bump() => draftsRevision.value++;

/// what this process holds for [chatId] in [c], without a read
Draft? heldDraft(HaloContainer c, String chatId, {required bool group}) =>
    _held[_key(c, chatId, group)];

/// [chatId]'s draft: memory first, then its row. a read that fails is none
Future<Draft?> readDraft(
  DraftRows rows,
  String chatId, {
  required bool group,
}) async {
  final k = _key(rows.container, chatId, group);
  final held = _held[k];
  if (held != null || _shut) return held;
  try {
    final d = await rows.draftOf(chatId, group: group);
    // typed or dropped while it read: that wins
    if (d == null || d.isEmpty || _waiting.containsKey(k) || _shut) {
      return _held[k];
    }
    return _held[k] ??= d;
  } catch (e) {
    dlog('drafts: not read (${e.runtimeType})');
    return null;
  }
}

/// a composer changed: held now, written once typing rests. an empty one
/// is dropped at once
void typedDraft(DraftRows rows, String chatId, Draft d, {required bool group}) {
  if (_shut) return;
  final k = _key(rows.container, chatId, group);
  if (d.isEmpty) {
    // an empty composer touched again holds nothing to drop
    if (_held.containsKey(k) || _waiting.containsKey(k)) {
      unawaited(dropDraft(rows, chatId, group: group));
    }
    return;
  }
  final was = _held[k];
  // a cursor move or the draft put back is not a new draft
  if (was != null && was.sameAs(d)) return;
  _held[k] = d;
  _waiting.remove(k)?.timer.cancel();
  _waiting[k] = _Waiting(
    rows,
    chatId,
    group,
    d,
    Timer(kDraftWait, () => unawaited(_write(k))),
  );
}

Future<void> _write(String k) async {
  final w = _waiting.remove(k);
  if (w == null) return;
  w.timer.cancel();
  try {
    if (_shut || !w.rows.isOpen) return;
    await w.rows.putDraft(w.chatId, w.draft, group: w.group);
    _bump();
  } catch (e) {
    dlog('drafts: not written (${e.runtimeType})');
  }
}

/// a chat's unsent words gone: from memory, from a write still waiting,
/// and from its row
Future<void> dropDraft(
  DraftRows rows,
  String chatId, {
  required bool group,
}) async {
  final k = _key(rows.container, chatId, group);
  _held.remove(k);
  _waiting.remove(k)?.timer.cancel();
  try {
    if (_shut || !rows.isOpen) return;
    await rows.dropDraftRow(chatId, group: group);
    _bump();
  } catch (e) {
    dlog('drafts: not dropped (${e.runtimeType})');
  }
}

/// [chatId]'s waiting write, now: its chat is being left
Future<void> writeDraftNow(
  DraftRows rows,
  String chatId, {
  required bool group,
}) => _write(_key(rows.container, chatId, group));

/// every write still waiting, now: the app is going out of sight, a chat
/// is left, or a database is about to shut. [only] keeps it to one
/// container
Future<void> flushDrafts({HaloContainer? only}) async {
  final ks = [
    for (final e in _waiting.entries)
      if (only == null || e.value.rows.container == only) e.key,
  ];
  await Future.wait(ks.map(_write));
}

/// [c]'s drafts written, then let go from memory: its database is shutting
Future<void> settleDrafts(HaloContainer c) async {
  _held.removeWhere((k, _) => _ofContainer(c, k));
  await flushDrafts(only: c);
}

/// [c]'s files are going: what it held goes from memory, unwritten
void forgetDrafts(HaloContainer c) {
  for (final e in _waiting.entries) {
    if (_ofContainer(c, e.key)) e.value.timer.cancel();
  }
  _waiting.removeWhere((k, _) => _ofContainer(c, k));
  _held.removeWhere((k, _) => _ofContainer(c, k));
}

/// the wipe: nothing held and nothing written from here on
void forgetAllDrafts() {
  _shut = true;
  for (final w in _waiting.values) {
    w.timer.cancel();
  }
  _waiting.clear();
  _held.clear();
}

/// this process ended: memory and waiting writes gone, the rows stay
@visibleForTesting
void endProcessForTest() {
  for (final w in _waiting.values) {
    w.timer.cancel();
  }
  _waiting.clear();
  _held.clear();
  _shut = false;
}

/// writes what waits as the app leaves the screen: android may stop the
/// process any time after
class DraftsOnPause with WidgetsBindingObserver {
  const DraftsOnPause();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(flushDrafts());
    }
  }
}

/// the drafts written, then the restart
Future<void> restartKeepingDrafts(Future<bool> Function() reopen) async {
  await flushDrafts();
  await reopen();
}

const _keptKey = 'kept_drafts';
final _kept = HaloContainer.everyday.key(_keptKey);

/// a copy an older version wrote down for a restart, into [rows] once: the
/// written copy goes as it is read, and a row already there wins
Future<void> restoreKeptDrafts(
  DraftRows rows, {
  FlutterSecureStorage store = secureStore,
}) async {
  final raw = await store.read(key: _kept);
  if (raw == null) return;
  await store.delete(key: _kept);
  final every = '${HaloContainer.everyday.id}|';
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    for (final (m, group) in [('p', false), ('g', true)]) {
      final part = j[m];
      if (part is! Map) continue;
      for (final e in part.entries) {
        final k = e.key as String, v = e.value;
        if (v is! String || !k.startsWith(every)) continue;
        final id = k.substring(every.length);
        if (await rows.draftOf(id, group: group) != null) continue;
        final d = Draft(v, at: DateTime.now().millisecondsSinceEpoch);
        if (!d.isEmpty) await rows.putDraft(id, d, group: group);
      }
    }
  } catch (e) {
    // a copy that will not read is gone all the same
    dlog('drafts: old copy not read (${e.runtimeType})');
  }
}
