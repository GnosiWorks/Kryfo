// SPDX-License-Identifier: GPL-3.0-or-later
// shared preferences on desktop live in the vault too: what the app keeps
// there says which chats are muted, which routes are set, when it last
// ran. one entry, the whole map with each value's type. before the vault is
// open every call fails, so nothing reads an empty set and keeps it
import 'dart:convert';

import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'desktop_vault.dart';

const _entry = 'kryfo.prefs';

class VaultPrefs extends SharedPreferencesStorePlatform {
  VaultPrefs(this.vault);
  final DesktopVault vault;

  Map<String, Object> _all() {
    final raw = vault.read(_entry);
    if (raw == null) return {};
    final out = <String, Object>{};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    for (final e in m.entries) {
      final t = e.value as List;
      final v = t[1];
      out[e.key] = switch (t[0]) {
        'b' => v as bool,
        'i' => v as int,
        'd' => (v as num).toDouble(),
        'l' => (v as List).cast<String>().toList(),
        _ => v as String,
      };
    }
    return out;
  }

  Future<void> _save(Map<String, Object> m) => vault.write(
    _entry,
    jsonEncode({
      for (final e in m.entries)
        e.key: switch (e.value) {
          final bool b => ['b', b],
          final int i => ['i', i],
          final double d => ['d', d],
          final List<String> l => ['l', l],
          final Object o => ['s', '$o'],
        },
    }),
  );

  bool _fits(String key, PreferencesFilter f) =>
      key.startsWith(f.prefix) &&
      (f.allowList == null || f.allowList!.contains(key));

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final m = _all()..[key] = value is List ? value.cast<String>() : value;
    await _save(m);
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    final m = _all();
    if (m.remove(key) != null) await _save(m);
    return true;
  }

  @override
  Future<bool> clear() => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: 'flutter.')),
  );

  @override
  Future<bool> clearWithPrefix(String prefix) => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: prefix)),
  );

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final m = _all()..removeWhere((k, _) => _fits(k, parameters.filter));
    await _save(m);
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() => getAllWithParameters(
    GetAllParameters(filter: PreferencesFilter(prefix: 'flutter.')),
  );

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) =>
      getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
      );

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async => _all()..removeWhere((k, _) => !_fits(k, parameters.filter));
}
