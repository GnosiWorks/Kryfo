// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's secure storage, as every part of the app opens it. all of it
// sits in one store on android, so every caller asks for the same: a read
// that fails throws, and every key stays where it is
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const secureStore = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
);

// the keys written with encrypted shared preferences: the database keys,
// the lock's counters and what backups keep beside them
const secureStoreEsp = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: false,
  ),
);

// the plugin runs one call at a time on one thread, so a call that never
// returns holds every call after it. only a new process lets go of it
class KeyStoreStuck implements Exception {
  const KeyStoreStuck();
  @override
  String toString() =>
      'KeyStoreStuck: no answer in ${keyStoreWait.inSeconds} s';
}

// how long a start waits on the key store before it gives up
@visibleForTesting
var keyStoreWait = const Duration(seconds: 45);

// how long before the splash offers a reopen
@visibleForTesting
var keyStoreSlowAfter = const Duration(seconds: 30);

// true while a call has waited longer than keyStoreSlowAfter
final keyStoreSlow = ValueNotifier<bool>(false);
var _waiting = 0;

// a key store call a start waits on. one that gives up throws KeyStoreStuck
// and goes on in the plugin, and every call asked after it still waits for
// it there: a write that lands late is what the next read returns
Future<T> keyStoreCall<T>(Future<T> Function() call) {
  _waiting++;
  final slow = Timer(keyStoreSlowAfter, () => keyStoreSlow.value = true);
  return Future.sync(call)
      .timeout(keyStoreWait, onTimeout: () => throw const KeyStoreStuck())
      .whenComplete(() {
        slow.cancel();
        if (--_waiting == 0) keyStoreSlow.value = false;
      });
}
