// SPDX-License-Identifier: GPL-3.0-or-later
// erases everything on this device: db with its wal/shm, onion key, media,
// caches, sessions, prefs, secure storage. the next launch starts at
// onboarding. the real erase is android's clear-data call over the platform
// channel: it takes the keystore-wrapped prefs and force-stops the package so
// the listener service cannot bring the process back. the deletes below are
// the fallback where that call refuses.

import 'dart:io';
import 'secure_store.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'main.dart' show engine, session, sessionQuiet;
import 'package:shared_preferences/shared_preferences.dart';
import 'dlog.dart';

// everything still running checks this before touching the database. the
// timers outlive the widget tree and cannot all be cancelled from here.
bool haloWiping = false;

// what the app keeps in memory of messages on their way in, dropped as the
// wipe starts. the app sets it
void Function() wipeForget = () {};

// how the wipe ends the process, so a test can watch what it leaves
@visibleForTesting
void Function(int code) wipeExit = exit;

// [releaseHandle] gives the handle back on the way, for a wipe chosen in
// settings. a wipe from the lock screen or from a quiet session makes no
// network call at all
Future<void> wipeHalo({bool releaseHandle = false}) async {
  // read before anything goes: a quiet session has no handle and reaches
  // nobody on the everyday identity's behalf
  final release = releaseHandle && !sessionQuiet;
  final handleKey = session.container.key('my_handle');
  haloWiping = true;
  wipeForget();
  // a beat for anything mid-query to finish before the files vanish
  await Future.delayed(const Duration(milliseconds: 120));
  // the handle goes back while the key that proves it is ours is still in
  // the engine's memory. the request runs beside the erase and gets a few
  // seconds at most: nothing here waits on the network
  String? h;
  if (release) {
    try {
      h = await secureStore.read(key: handleKey);
    } catch (e) {
      dlog('wipe: handle not read (${e.runtimeType})');
    }
  }
  final released = h == null || h.isEmpty ? null : _release(h);
  final cap = Future<void>.delayed(const Duration(seconds: 4));
  // keys, prefs and folders first. tor's own folder stays while tor runs
  await _erase(keep: const {'tor'});
  if (released != null) await Future.any([released, cap]);
  // the engine stops its relay listeners and takes tor off the network, and
  // what it wrote meanwhile goes with the rest
  try {
    await Future.any([
      engine.wipeHold(),
      Future.delayed(const Duration(seconds: 3), () => 'late'),
    ]);
  } catch (e) {
    dlog('wipe: engine not held (${e.runtimeType})');
  }
  await _erase();
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
  wipeExit(0);
}

Future<void> _release(String h) async {
  try {
    await engine.handleRelease(h);
  } catch (e) {
    dlog('wipe: handle not released (${e.runtimeType})');
  }
}

// secure storage, prefs and every app folder, but for the documents
// folder's entries named in [keep]
Future<void> _erase({Set<String> keep = const {}}) async {
  try {
    // identity markers go first. if anything below fails the next launch
    // still starts at onboarding instead of an empty home screen.
    await secureStore.deleteAll();
    await secureStoreEsp.deleteAll();
    final prefs0 = await SharedPreferences.getInstance();
    await prefs0.clear();
    // empty every app storage dir, so the wal/shm sidecars and media/ go
    // with halo.db
    final docs = await getApplicationDocumentsDirectory();
    final dirs = <Directory>[
      docs,
      await getApplicationSupportDirectory(),
      await getTemporaryDirectory(),
    ];
    for (final d in dirs) {
      if (!await d.exists()) continue;
      await for (final entry in d.list()) {
        if (d.path == docs.path && keep.contains(p.basename(entry.path))) {
          continue;
        }
        try {
          await entry.delete(recursive: true);
        } catch (e) {
          // one that will not go must not keep the rest. the native call
          // below is the real erase
          dlog('wipe: an entry stayed (${e.runtimeType})');
        }
      }
    }
    dlog('wipe: files gone');
  } catch (e) {
    // never rethrow: the keys are already gone, and a half-wiped app left
    // running is worse than one that exits
    dlog('wipe error: $e');
  }
}
