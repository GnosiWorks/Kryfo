// SPDX-License-Identifier: GPL-3.0-or-later
// erases everything on this device: db with its wal/shm, onion key, media,
// caches, sessions, prefs, secure storage. the next launch starts at
// onboarding. the real erase is android's clear-data call over the platform
// channel: it takes the keystore-wrapped prefs and force-stops the package so
// the listener service cannot bring the process back. the deletes below are
// the fallback where that call refuses.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart' show engine;
import 'package:shared_preferences/shared_preferences.dart';
import 'dlog.dart';

// everything still running checks this before touching the database. the
// timers outlive the widget tree and cannot all be cancelled from here.
bool haloWiping = false;

Future<void> wipeHalo() async {
  haloWiping = true;
  // a beat for anything mid-query to finish before the files vanish
  await Future.delayed(const Duration(milliseconds: 120));
  // give the handle back while the key that proves it is ours still exists.
  // best effort with a short cap: a wipe must not wait on the network.
  try {
    final h = await const FlutterSecureStorage().read(key: 'my_handle');
    if (h != null && h.isNotEmpty) {
      await Future.any([
        engine.handleRelease(h),
        Future.delayed(const Duration(seconds: 4)),
      ]);
    }
  } catch (_) {}
  try {
    // identity markers go first. if anything below fails the next launch
    // still starts at onboarding instead of an empty home screen.
    await const FlutterSecureStorage().deleteAll();
    await const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ).deleteAll();
    final prefs0 = await SharedPreferences.getInstance();
    await prefs0.clear();
    // empty every app storage dir, so the wal/shm sidecars and media/ go
    // with halo.db
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
    dlog('wipe: files gone');
  } catch (e) {
    // never rethrow: the keys are already gone, and a half-wiped app left
    // running is worse than one that exits
    dlog('wipe error: $e');
  }
  // the call that finishes the job kills this process before it can
  // answer, so a reply at all means it did not happen.
  var native = false;
  try {
    native = await Future.any([
      const MethodChannel(
        'halo/platform',
      ).invokeMethod<bool>('wipe').then((v) => v ?? false),
      Future.delayed(const Duration(seconds: 5), () => false),
    ]);
  } catch (e) {
    dlog('wipe native: $e');
  }
  dlog('wipe: native refused ($native), exiting');
  // fallback: preference clears reach disk with a delay, so wait for them
  // before exit
  await Future.delayed(const Duration(milliseconds: 600));
  exit(0);
}
