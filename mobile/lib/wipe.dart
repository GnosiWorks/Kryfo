// SPDX-License-Identifier: GPL-3.0-or-later
// wipe.dart - nukes everything on this device: db (+ sqlcipher wal/shm),
// onion key, saved media, caches, sessions, prefs, secure storage. used
// when the user wants to leave no trace. the app exits after, so the next
// launch starts clean from onboarding.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// everything still running checks this before touching the database. the
// timers outlive the widget tree and cannot all be cancelled from here.
bool haloWiping = false;

Future<void> wipeHalo() async {
  haloWiping = true;
  // a beat for anything mid-query to finish before the files vanish
  await Future.delayed(const Duration(milliseconds: 120));
  try {
    // identity markers go first. if anything below fails the next launch
    // still starts at onboarding instead of an empty home screen.
    await const FlutterSecureStorage().deleteAll();
    await const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ).deleteAll();
    final prefs0 = await SharedPreferences.getInstance();
    await prefs0.clear();
    // recursively empty every app storage dir. deleting halo.db by name
    // left the wal/shm sidecars and the media/ folder behind.
    final dirs = <Directory>[
      await getApplicationDocumentsDirectory(),
      await getApplicationSupportDirectory(),
      await getTemporaryDirectory(),
    ];
    for (final d in dirs) {
      if (!await d.exists()) continue;
      await for (final entry in d.list()) {
        try {
          await entry.delete(recursive: true);
        } catch (_) {}
      }
    }

    debugPrint('wipe: complete');
  } catch (e) {
    // never rethrow. a half-finished wipe that leaves the app running is
    // worse than one that exits - the keys are already gone by here.
    debugPrint('wipe error: $e');
  }
  // exit so the user reopens fresh
  exit(0);
}
