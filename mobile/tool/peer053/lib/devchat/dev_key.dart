// SPDX-License-Identifier: GPL-3.0-or-later
// what 0.5.3's signal_stores.dart asks of its dev chat keys: the key a test
// pins for a dev: address, else none, so it trusts nothing
import 'dart:typed_data';

enum DevKeyStatus { current, previous, retired }

class DevKey {
  const DevKey(this.status);
  final DevKeyStatus status;
}

bool isDevChat(String id) => id.startsWith('dev:');

// the keys a test pins, as the 0.5.x app pins m1: by key id
final _pins = <String, (DevKey, Uint8List)>{};

void pinDevKeyForTest(String keyId, Uint8List identity) =>
    _pins[keyId] = (DevKey(DevKeyStatus.current), identity);

DevKey? devKeyById(String keyId) => _pins[keyId]?.$1;

Uint8List pinnedIdentity(DevKey k) {
  for (final p in _pins.values) {
    if (identical(p.$1, k)) return p.$2;
  }
  return Uint8List(0);
}
