// SPDX-License-Identifier: GPL-3.0-or-later
// erases everything on this device: db with its wal/shm, onion key, media,
// caches, sessions, prefs, secure storage. the next launch starts at
// onboarding. the real erase is android's clear-data call over the platform
// channel: it takes the keystore-wrapped prefs and force-stops the package so
// the listener service cannot bring the process back. the deletes below are
// the fallback where that call refuses.

import 'dart:io';
import 'dart:math';
import 'secure_store.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'main.dart' show engine, session, sessionQuiet;
import 'package:shared_preferences/shared_preferences.dart';
import 'dlog.dart';
import 'shred.dart' show shredFile;

// everything still running checks this before touching the database. the
// timers outlive the widget tree and cannot all be cancelled from here.
bool haloWiping = false;

// what the app keeps in memory of messages on their way in, dropped as the
// wipe starts. the app sets it
void Function() wipeForget = () {};

// how the wipe ends the process, so a test can watch what it leaves
@visibleForTesting
void Function(int code) wipeExit = exit;

// what held plaintext or a key in the clear leaves its folder at once, under
// a random name in here, beside the folders the wipe empties, and is
// shredded behind it. what a process that died first left goes at the next
// start (sweepWipeLeftovers)
const kWipeHeld = 'wipe_held';

// how long android's erase waits for that shred: it takes the rest
// unzeroed, and a panic wipe stays quick
const kWipeShredWait = Duration(seconds: 2);

// the shred of one held entry, a stand-in in tests
@visibleForTesting
Future<void> Function(String path) wipeShred = shredHeld;

Future<void> _shredding = Future<void>.value();

// what this process moved aside and is shredding: a start sweep leaves it
final _moving = <String>{};

// every shred the wipe started, done
@visibleForTesting
Future<void> get wipeShredding => _shredding;

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
  final shredFrom = Stopwatch()..start();
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
  final wait = kWipeShredWait - shredFrom.elapsed;
  if (wait > Duration.zero) {
    await Future.any([_shredding, Future<void>.delayed(wait)]);
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
// folder's entries named in [keep]. the databases, sealed under keys
// already gone, are unlinked. everything else leaves its folder by a
// rename, at once, and is shredded behind
Future<void> _erase({Set<String> keep = const {}}) async {
  // the fingerprint key, so nothing it sealed opens again
  try {
    await const MethodChannel(
      'halo/platform',
    ).invokeMethod<bool>('bioDisable').timeout(const Duration(seconds: 1));
  } catch (e) {
    dlog('wipe: finger key left (${e.runtimeType})');
  }
  try {
    // identity markers go first. if anything below fails the next launch
    // still starts at onboarding instead of an empty home screen.
    await secureStore.deleteAll();
    final prefs0 = await SharedPreferences.getInstance();
    await prefs0.clear();
    final docs = await getApplicationDocumentsDirectory();
    final held = _heldIn(docs);
    final dirs = <Directory>[
      docs,
      await getApplicationSupportDirectory(),
      await getTemporaryDirectory(),
    ];
    final behind = <String>[];
    // the ones that would not move
    final stuck = <FileSystemEntity>[];
    for (final d in dirs) {
      if (!await d.exists()) continue;
      await for (final entry in d.list(followLinks: false)) {
        final name = p.basename(entry.path);
        if (d.path == docs.path && keep.contains(name)) continue;
        if (!_sealed(name) && entry is! Link) {
          final to = p.join(held, _rnd());
          _moving.add(to);
          try {
            await Directory(held).create(recursive: true);
            behind.add((await entry.rename(to)).path);
            continue;
          } catch (e) {
            dlog('wipe: an entry not moved (${e.runtimeType})');
            _moving.remove(to);
            stuck.add(entry);
            continue;
          }
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
    _shredBehind(behind, held);
    if (stuck.isNotEmpty) {
      // shredded where they lie, for a moment at most, then unlinked with
      // whatever is left: nothing stays under its name
      await Future.any([
        Future.wait([for (final e in stuck) _shredOne(e.path)]),
        Future<void>.delayed(kWipeShredWait),
      ]);
      for (final e in stuck) {
        try {
          await e.delete(recursive: true);
        } on PathNotFoundException {
          // shredded already
        } catch (err) {
          dlog('wipe: an entry stayed (${err.runtimeType})');
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

// beside the app's folders, in the folder that holds them
String _heldIn(Directory docs) => p.join(p.dirname(docs.path), kWipeHeld);

// a database and its sidecars, ciphertext and often large, and tor's own
// folder, which holds nothing of the person's: unlinked, never held
bool _sealed(String name) =>
    name == 'tor' || RegExp(r'\.db(-wal|-shm|-journal)?$').hasMatch(name);

final _random = Random.secure();

String _rnd() => [
  for (var i = 0; i < 16; i++) _random.nextInt(256).toRadixString(16),
].map((h) => h.padLeft(2, '0')).join();

Future<void> _shredOne(String path) => wipeShred(path).catchError((Object e) {
  dlog('wipe: not shredded (${e.runtimeType})');
});

void _shredBehind(List<String> paths, String held) {
  final before = _shredding;
  _shredding = () async {
    await Future.wait([
      before,
      for (final x in paths) _shredOne(x).whenComplete(() => _moving.remove(x)),
    ]);
    await _dropIfEmpty(held);
  }();
}

Future<void> _dropIfEmpty(String held) async {
  try {
    await Directory(held).delete();
  } catch (_) {
    // something is still in it
  }
}

/// what a held entry was: every file zeroed, but a database's, which is
/// ciphertext under keys already gone and only unlinked. a link is unlinked,
/// never followed
Future<void> shredHeld(String path) async {
  final type = await FileSystemEntity.type(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return;
  if (type != FileSystemEntityType.directory) {
    await _shredOrUnlink(path);
    return;
  }
  await for (final e in Directory(
    path,
  ).list(recursive: true, followLinks: false)) {
    if (e is File) await _shredOrUnlink(e.path);
  }
  await Directory(path).delete(recursive: true);
}

Future<void> _shredOrUnlink(String path) async {
  if (!_sealed(p.basename(path))) return shredFile(path);
  try {
    await File(path).delete();
  } catch (e) {
    dlog('wipe: not unlinked (${e.runtimeType})');
  }
}

/// what a wipe held and its process did not live to shred, at every start.
/// what a wipe running now is moving is its own
Future<void> sweepWipeLeftovers() async {
  if (haloWiping) return;
  try {
    final held = _heldIn(await getApplicationDocumentsDirectory());
    final d = Directory(held);
    if (!await d.exists()) return;
    await for (final e in d.list(followLinks: false)) {
      if (_moving.contains(e.path)) continue;
      await shredHeld(e.path);
    }
    await _dropIfEmpty(held);
  } catch (e) {
    dlog('wipe: leftovers stayed (${e.runtimeType})');
  }
}
