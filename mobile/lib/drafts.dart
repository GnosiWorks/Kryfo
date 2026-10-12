// SPDX-License-Identifier: GPL-3.0-or-later
// unsent drafts, so text survives leaving a chat. in memory, keyed by
// session.chatKey: each container keeps its own. a restart the person asks
// for writes the everyday ones down first and reads them back once
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'container.dart';
import 'secure_store.dart';

final Map<String, String> draftPerPeer = {};
final Map<String, String> draftPerGroup = {};

const _keptKey = 'kept_drafts';
final _kept = HaloContainer.everyday.key(_keptKey);

// the everyday container's only: a decoy's or a vault's draft is never
// written anywhere
bool _everyday(String key) => key.startsWith('${HaloContainer.everyday.id}|');

/// a chat's unsent words go with the chat, deleted or hidden. [key] is the
/// one they are kept under (chatKey)
void dropDraft(String key, {required bool group}) =>
    (group ? draftPerGroup : draftPerPeer).remove(key);

/// the people and groups the everyday side still holds a chat with: a draft
/// of any other is never written down. the app sets it; unset, none is
Future<({Set<String> people, Set<String> groups})> Function()? everydayChats;

Future<void> keepDrafts({FlutterSecureStorage store = secureStore}) async {
  final ({Set<String> people, Set<String> groups}) chats;
  try {
    final read = everydayChats;
    if (read == null) return;
    chats = await read();
  } catch (_) {
    return;
  }
  String id(String key) => key.substring(key.indexOf('|') + 1);
  bool keep(MapEntry<String, String> e, Set<String> held) =>
      _everyday(e.key) && held.contains(id(e.key)) && e.value.trim().isNotEmpty;
  final kept = {
    'p': {
      for (final e in draftPerPeer.entries)
        if (keep(e, chats.people)) e.key: e.value,
    },
    'g': {
      for (final e in draftPerGroup.entries)
        if (keep(e, chats.groups)) e.key: e.value,
    },
  };
  if (kept['p']!.isEmpty && kept['g']!.isEmpty) return;
  await store.write(key: _kept, value: jsonEncode(kept));
}

/// back into memory, once: the written copy goes as it is read
Future<void> restoreKeptDrafts({
  FlutterSecureStorage store = secureStore,
}) async {
  final raw = await store.read(key: _kept);
  if (raw == null) return;
  await store.delete(key: _kept);
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    for (final (m, into) in [('p', draftPerPeer), ('g', draftPerGroup)]) {
      final part = j[m];
      if (part is! Map) continue;
      for (final e in part.entries) {
        final k = e.key as String, v = e.value;
        if (v is String && _everyday(k)) into.putIfAbsent(k, () => v);
      }
    }
  } catch (_) {
    // a copy that will not read is gone all the same
  }
}

Future<void> dropKeptDrafts({FlutterSecureStorage store = secureStore}) =>
    store.delete(key: _kept);

/// the drafts written down, then the restart. one that does not happen
/// takes the written copy back at once: nothing waits on disk for a boot
/// that is not coming
Future<void> restartKeepingDrafts(
  Future<bool> Function() reopen, {
  FlutterSecureStorage store = secureStore,
}) async {
  await keepDrafts(store: store);
  if (!await reopen()) await dropKeptDrafts(store: store);
}
