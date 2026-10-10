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

Future<void> keepDrafts({FlutterSecureStorage store = secureStore}) async {
  final kept = {
    'p': {
      for (final e in draftPerPeer.entries)
        if (_everyday(e.key) && e.value.trim().isNotEmpty) e.key: e.value,
    },
    'g': {
      for (final e in draftPerGroup.entries)
        if (_everyday(e.key) && e.value.trim().isNotEmpty) e.key: e.value,
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
