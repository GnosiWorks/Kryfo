// wipe.dart — nukes everything on this device: db (+ sqlcipher wal/shm),
// onion key, saved media, caches, sessions, prefs, secure storage. used
// when the user wants to leave no trace. the app exits after, so the next
// launch starts clean from onboarding.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> wipeHalo() async {
  try {
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

    await const FlutterSecureStorage().deleteAll();
    await const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ).deleteAll();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    debugPrint('wipe: complete');
  } catch (e) {
    debugPrint('wipe error: $e');
    rethrow;
  }
  // exit so the user reopens fresh
  await Future.delayed(const Duration(milliseconds: 200));
  exit(0);
}
