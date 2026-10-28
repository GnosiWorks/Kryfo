// SPDX-License-Identifier: GPL-3.0-or-later
// what 0.5.3's signal_stores.dart asks of its dev chat keys. this peer
// plays no dev chat, so it knows no key: a dev: address trusts nothing
import 'dart:typed_data';

enum DevKeyStatus { current, previous, retired }

class DevKey {
  const DevKey(this.status);
  final DevKeyStatus status;
}

bool isDevChat(String id) => id.startsWith('dev:');

DevKey? devKeyById(String keyId) => null;

Uint8List pinnedIdentity(DevKey k) => Uint8List(0);
