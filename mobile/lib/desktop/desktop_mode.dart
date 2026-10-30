// SPDX-License-Identifier: GPL-3.0-or-later
// what shared code asks of the desktop, kept small: the phone's build
// reaches this file and nothing else of lib/desktop
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';

/// true in the linux and windows app (main_desktop.dart sets it before
/// anything runs). a plain flag, not Platform: the tests run on linux too
/// and test the phone's behaviour there
bool onDesktop = false;

/// a share sheet to hand things to other apps. linux has none: share_plus
/// there turns text into a mailto link for the mail client, which writes it
/// to its drafts and its logs. desktop offers copy and the qr instead
bool get canShareOut => !onDesktop;

/// Isolate.run, with the desktop's sealed files readable in the new
/// isolate too. the desktop puts its own in place; the phone runs plain
Future<R> runIsolated<R>(FutureOr<R> Function() f) =>
    (isolateRunner ?? Isolate.run)(f);

/// set by the desktop start
Future<R> Function<R>(FutureOr<R> Function() f)? isolateRunner;

/// code outside dart that reads [ins] and writes [outs] by path: on desktop
/// a sealed one is handed over as memory, never as a plain file. the phone
/// passes the paths as they are
/// [ok] says whether the code's answer means it wrote whole outputs: only
/// then are they kept
Future<T> withNativeFiles<T>(
  List<String> ins,
  List<String> outs,
  Future<T> Function(List<String> ins, List<String> outs) run, {
  bool Function(T answer)? ok,
}) {
  final h = nativeFiles;
  return h == null ? run(ins, outs) : h(ins, outs, run, ok);
}

/// set by the desktop start
Future<T> Function<T>(
  List<String> ins,
  List<String> outs,
  Future<T> Function(List<String> ins, List<String> outs) run,
  bool Function(T answer)? ok,
)?
nativeFiles;

/// a container's database opened with [key]: on desktop its photos, notes
/// and files open with a key made from it. [suffix] names its folders
void Function(String id, String suffix, String key)? containerOpened;

/// the database of container [id] closed
void Function(String id)? containerClosed;

/// the start's sweep of half-made containers is done: the desktop puts its
/// numbered placeholders back
void Function()? containersSwept;

/// the zone mark under which files are the disk's own bytes, past the
/// desktop's seal
const rawFilesZoneKey = #kryfoRawFiles;

/// [f] with File(path) as the disk holds it: a shred overwrites what is
/// there, sealed or not. the same as [f] on the phone
R rawFiles<R>(R Function() f) =>
    onDesktop ? runZoned(f, zoneValues: {rawFilesZoneKey: true}) : f();

/// the engine's own folder for a start in [docs]: on desktop one in memory,
/// whose files are kept sealed between runs
String engineDir(String docs) => engineDirOf?.call(docs) ?? docs;

/// set by the desktop start
String Function(String docs)? engineDirOf;

/// the engine's start, with what the desktop puts in its folder first and
/// takes back after: the onion key, only while the engine reads it
Future<String> startEngineIn(
  String docs,
  Future<String> Function(String dir) start,
) => engineStarter == null ? start(docs) : engineStarter!(docs, start);

/// set by the desktop start
Future<String> Function(String docs, Future<String> Function(String dir) start)?
engineStarter;

/// where a backup is made: on desktop on the disk, not in memory, as it is
/// encrypted already and can be large
Future<String> Function()? bulkTempDir;

/// the computer lock as each session sees it: the settings row and page,
/// and the backup card where losing the computer's key loses the data.
/// set by the desktop start; null on the phone
ComputerLockView? computerLock;

abstract class ComputerLockView implements Listenable {
  /// a passphrase opens Kryfo on this computer, as this session shows it.
  /// a [decoy] session shows its own note and never changes the real lock
  bool passphraseOn({required bool decoy});

  /// the settings page
  Widget page({required bool decoy});

  /// without a passphrase on windows the key goes with the account and its
  /// security chip: a backup is the way back
  bool backupWise({required bool decoy});

  /// the home card that says so, until it is put away on this side
  bool backupCardDue({required bool decoy});

  Future<void> backupCardSeen({required bool decoy});

  /// the decoy's own note, read ahead with the decoy's database
  void decoyNoteRead(String? note);
}

/// where a session database keeps the decoy's note (vault_meta)
const kComputerDecoyNote = 'computer_lock';

/// writes the decoy's note into the open decoy's database, set by the app
Future<void> Function(String note)? keepComputerDecoyNote;
