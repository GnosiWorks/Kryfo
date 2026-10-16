// SPDX-License-Identifier: GPL-3.0-or-later
// quiet restarts and the sweeps at launch

part of '../main.dart';

// the way out of a send stuck on tor, shared by every chat and the home card
final torValve = TorValve(
  reconnect: () => appState.reconnectNow(),
  restart: () => restartKeepingDrafts(reopenApp),
  busyElsewhere: () =>
      mediaInflight.isNotEmpty ||
      incomingMediaProgress.keys.any((k) => !incomingMediaStalled.contains(k)),
  passRuns: () => appState.autoPassRuns,
);

// a tor dead in this process, out of sight: a new process, now and then
final autoRestart = AutoRestart(
  view: appState.autoView,
  reconnect: () => appState.reconnectNow(),
  restart: restartQuietly,
  clock: bootTime,
);

// android says yes first, then every database is shut, then the process
// ends: a write cut half way is worse than one not begun. one the end did
// not take opens again on its next use
@visibleForTesting
Future<bool> restartQuietly() async {
  if (!await armQuietRestart()) return false;
  await _shutDatabases();
  return endQuietly();
}

Future<void> _shutDatabases() async {
  final open = <HaloDb>{live, session.primary, ?session.vault};
  for (final d in open) {
    try {
      await d.close();
    } catch (e) {
      dlog('restart: a database would not close (${e.runtimeType})');
    }
  }
}

// raw voice recordings a crash, or an older build, left in the cache: the
// voice as spoken, before any disguise. the decrypted open-with copies are
// cleared on the native side, on every resume.
Future<void> _sweepPlaintextLeftovers() async {
  try {
    await sweepVoiceLeftovers(await getTemporaryDirectory());
  } catch (e) {
    dlog('sweep: voice leftovers (${e.runtimeType})');
  }
  await sweepGifParts();
  // what a wipe moved aside and did not live to shred
  await sweepWipeLeftovers();
  // a contact card written for a share and left
  try {
    await sweepCardLeftovers(await getTemporaryDirectory());
  } catch (e) {
    dlog('sweep: card leftovers (${e.runtimeType})');
  }
}

// at launch, before anything can be exported: an export the app did not
// live through. later sweeps never look there
Future<void> _sweepNotesAtLaunch() async {
  try {
    await sweepNotesExports(await getTemporaryDirectory());
  } catch (e) {
    dlog('sweep: notes exports (${e.runtimeType})');
  }
}

// every raw recording in [dir]: one that will not go is logged and the
// rest still go. [drop] stands in for the shred in tests
@visibleForTesting
Future<void> sweepVoiceLeftovers(
  Directory dir, {
  Future<void> Function(File f)? drop,
}) async {
  await for (final e in dir.list()) {
    final name = e.uri.pathSegments.isEmpty ? '' : e.uri.pathSegments.last;
    if (e is! File || !name.startsWith('vn_') || !name.endsWith('.wav')) {
      continue;
    }
    try {
      await (drop ?? (f) => shredFile(f.path))(e);
    } catch (err) {
      dlog('sweep: a voice leftover stayed (${err.runtimeType})');
    }
  }
}

// the database exists: this phone has been set up at some point. a plain file
// check on purpose: reading secure storage on a wiped app would create its
// keystore key and write a prefs file, which is a trace of its own. the
// native side asks the same question (KryfoState.hasData).
Future<bool> _hasLocalData() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/halo.db').exists();
  } catch (_) {
    // cannot tell: assume it has been set up
    return true;
  }
}
