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
  const Draft(this.text, {this.replyTo, this.at = 0, this.burnSecs});

  final String text;
  // the uid of the message it quotes
  final String? replyTo;
  // when it was last typed, in ms: the chat list orders by it
  final int at;
  // typed while the chat sent timed messages: it goes as one of them
  // would, this long after its last edit
  final int? burnSecs;

  bool get isEmpty => text.trim().isEmpty;

  bool sameAs(Draft o) =>
      text == o.text && replyTo == o.replyTo && burnSecs == o.burnSecs;

  /// past its time at [now]: a timed chat's draft is never shown after
  bool spentAt(int now) {
    final s = burnSecs;
    return s != null && at + s * 1000 <= now;
  }
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
  // the chats whose timed draft is past its time at [now]
  Future<List<({String chat, bool group})>> spentDrafts(int now);
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
// chats on their way between containers: nothing of theirs is held or
// written until the session says where they are
final Map<String, int> _moving = {};
// set by a wipe: nothing is held or written after it
bool _shut = false;

/// goes up when a draft is written or dropped, for the chat list
final draftsRevision = ValueNotifier<int>(0);

String _key(HaloContainer c, String chatId, bool group) =>
    '${group ? 'g' : 'p'}${c.chatKey(chatId)}';

// a key of [c]'s: past the p or g, its chatKey
bool _ofContainer(HaloContainer c, String k) => k.startsWith(c.chatKey(''), 1);

void _bump() => draftsRevision.value++;

int _now() => DateTime.now().millisecondsSinceEpoch;

/// what this process holds for [chatId] in [c], without a read. one past
/// its time is let go
Draft? heldDraft(HaloContainer c, String chatId, {required bool group}) {
  final k = _key(c, chatId, group);
  final d = _held[k];
  if (d == null || !d.spentAt(_now())) return d;
  _held.remove(k);
  _waiting.remove(k)?.timer.cancel();
  return null;
}

/// [chats] are moving between containers: their drafts are neither held
/// nor written until the call handed back. a draft typed meanwhile would
/// name a hidden chat in the everyday file
void Function() holdDraftsOf(Iterable<String> chats) {
  final ids = chats.toSet();
  for (final id in ids) {
    _moving[id] = (_moving[id] ?? 0) + 1;
  }
  var done = false;
  return () {
    if (done) return;
    done = true;
    for (final id in ids) {
      final n = (_moving[id] ?? 1) - 1;
      n > 0 ? _moving[id] = n : _moving.remove(id);
    }
  };
}

/// [chatId]'s draft: memory first, then its row. a read that fails is none
Future<Draft?> readDraft(
  DraftRows rows,
  String chatId, {
  required bool group,
}) async {
  final k = _key(rows.container, chatId, group);
  final held = heldDraft(rows.container, chatId, group: group);
  if (held != null || _shut) return held;
  try {
    final d = await rows.draftOf(chatId, group: group);
    // typed or dropped while it read: that wins
    if (d == null || d.isEmpty || _waiting.containsKey(k) || _shut) {
      return _held[k];
    }
    // past its time: the sweep had not reached it yet
    if (d.spentAt(_now())) {
      unawaited(dropDraft(rows, chatId, group: group));
      return null;
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
  if (_shut || _moving.containsKey(chatId)) return;
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
    if (_shut || _moving.containsKey(w.chatId) || !w.rows.isOpen) return;
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

/// [chatId] left [c] with its rows: what memory held for it there goes,
/// and a write still waiting is not made
void forgetDraft(HaloContainer c, String chatId, {required bool group}) {
  final k = _key(c, chatId, group);
  _held.remove(k);
  _waiting.remove(k)?.timer.cancel();
}

/// timed chats' drafts past their time go, from memory and their rows, as
/// their timed messages would. [onScreen] keeps a composer still open.
/// [spent], when the caller read it already, saves a read
Future<void> sweepDrafts(
  DraftRows rows, {
  bool Function(String chatId, bool group)? onScreen,
  List<({String chat, bool group})>? spent,
}) async {
  if (_shut || !rows.isOpen) return;
  final c = rows.container;
  final now = _now();
  bool shown(String id, bool group) => onScreen?.call(id, group) ?? false;
  try {
    for (final e in _held.entries.toList()) {
      if (!_ofContainer(c, e.key) || !e.value.spentAt(now)) continue;
      final w = _waiting[e.key];
      final group = e.key.startsWith('g');
      final id = e.key.substring(1 + c.chatKey('').length);
      if (shown(id, group)) continue;
      _held.remove(e.key);
      w?.timer.cancel();
      _waiting.remove(e.key);
    }
    for (final d in spent ?? await rows.spentDrafts(now)) {
      if (shown(d.chat, d.group)) continue;
      // typed again since the row was written: the new one counts
      if (_held.containsKey(_key(c, d.chat, d.group))) continue;
      await rows.dropDraftRow(d.chat, group: d.group);
      _bump();
    }
  } catch (e) {
    dlog('drafts: not swept (${e.runtimeType})');
  }
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
  _moving.clear();
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
