// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's secure storage, as every part of the app opens it. all of it
// sits in one store on android, so every caller asks for the same: a read
// that fails throws, and every key stays where it is
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
