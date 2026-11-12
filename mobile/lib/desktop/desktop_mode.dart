// SPDX-License-Identifier: GPL-3.0-or-later
// what shared code asks of the desktop, kept small: the phone's build
// reaches this file and the seal (sealed_*.dart, phone_seal.dart) and
// nothing else of lib/desktop
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../container.dart' show HaloContainer;

/// true in the linux and windows app (main_desktop.dart sets it before
/// anything runs). a plain flag, not Platform: the tests run on linux too
/// and test the phone's behaviour there
bool onDesktop = false;

/// what a computer's wipe for a link hands its next run, in the
/// environment: that run opens onboarding's link at once
const kLinkNextEnv = 'KRYFO_LINK_NEXT';

/// set at the start of a run a wipe for a link made: taken once
bool deskLinkAtStart = false;

/// a kryfo: link the linux runner started this run with (the menu entry's
/// %u). app_links on linux hears only a command-line signal the runner
/// never sends, so the cold start's link comes from here
String? deskLaunchLink;

/// the first kryfo: argument, null when none
String? launchLinkOf(List<String> args) {
  for (final a in args) {
    if (a.length <= 8192 && a.toLowerCase().startsWith('kryfo:')) return a;
  }
  return null;
}

/// the launch link, taken once
Uri? takeDeskLaunchLink() {
  final v = deskLaunchLink;
  deskLaunchLink = null;
  return v == null ? null : Uri.tryParse(v);
}

/// whether onboarding opens the link at once, asked once
bool takeDeskLinkAtStart() {
  final v = deskLinkAtStart;
  deskLinkAtStart = false;
  return v;
}

/// this app keeps its window out of screenshots, and so may say it blocks
/// them: a chat's 'ss', a group's 'gs'. a computer cannot yet
bool get shotsHonouredHere => !onDesktop;

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

/// container [c]'s database is open and its files are where its rows say:
/// the phone seals what an older version left plain
void Function(HaloContainer c)? containerSettled;

/// true once a seal is over kryfo's files: the desktop's, or the phone's
/// over its media folders
bool filesSealed = false;

/// a wipe's first step on desktop: the vault overwritten and what the
/// computer's account kept for it cleared, so nothing on the disk opens
/// again before a file is touched. set by the desktop start
Future<void> Function()? desktopWipeKeys;

/// a wipe's next one: the databases let go of their files, which windows
/// does not delete while they are open. set by the desktop start
Future<void> Function()? desktopLetGo;

/// the start's sweep of half-made containers is done: the desktop puts its
/// numbered placeholders back
void Function()? containersSwept;

/// the zone mark under which files are the disk's own bytes, past the
/// desktop's seal
const rawFilesZoneKey = #kryfoRawFiles;

/// [f] with File(path) as the disk holds it: a shred overwrites what is
/// there, sealed or not. the same as [f] where nothing is sealed
R rawFiles<R>(R Function() f) => onDesktop || filesSealed
    ? runZoned(f, zoneValues: {rawFilesZoneKey: true})
    : f();

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

/// the engine's memory folder (engine/folder_mem.go): on windows, which has
/// no folder in memory, the onion key, the relay marks and the wrap queue
/// live in the process alone and are sealed between runs
abstract class EngineMemory {
  /// [b] kept under [name]; the caller zeroes its copy
  void put(String name, Uint8List b);

  /// a copy the caller zeroes, null with none
  Uint8List? get(String name);

  List<String> names();

  /// one file zeroed and gone, or all of them for ''
  void drop([String name = '']);
}

/// set by the windows start; null elsewhere, where the engine's folder is
/// a folder
EngineMemory? engineMemory;

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

  /// what keeps the vault's key, as this session shows it
  ComputerSeal sealedBy({required bool decoy});

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

/// what opens the vault: a passphrase, or the computer account through
/// windows (dpapi, the security chip when there is one) or the keyring
enum ComputerSeal { passphrase, windows, keyring }

/// where a session database keeps the decoy's note (vault_meta)
const kComputerDecoyNote = 'computer_lock';

/// writes the decoy's note into the open decoy's database, set by the app
Future<void> Function(String note)? keepComputerDecoyNote;

/// a computer's notifications make their sound. on unless turned off on
/// the notifications page; each post reads it as it goes
final deskSound = ValueNotifier<bool>(true);

const _deskSoundKey = 'desk_sound';

/// the sound as it was left, read once the vault is open
Future<void> readDeskSound() async {
  try {
    final p = await SharedPreferences.getInstance();
    deskSound.value = p.getBool(_deskSoundKey) ?? true;
  } catch (_) {}
}

Future<void> setDeskSound(bool on) async {
  deskSound.value = on;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_deskSoundKey, on);
  } catch (_) {}
}

/// keep running in the tray and start with the computer, for the
/// notifications page. set by the desktop start; null on the phone
DesktopRunView? desktopRun;

/// what the computer says of starting kryfo with it
enum StartAnswer {
  on,
  off,

  /// kryfo is listed, and the user switched it off in windows' startup apps
  heldOff,

  /// the computer would not take the change
  refused,
}

abstract class DesktopRunView implements Listenable {
  /// closing the window hides kryfo to the tray. on unless turned off
  bool get trayOn;

  /// the desktop shows the tray icon; null when unknown
  bool? get trayShown;

  Future<void> setTray(bool on);

  /// this computer has a place for things that start with it
  bool get canStart;

  /// null until read
  StartAnswer? get start;

  /// the last change was refused
  bool get startRefused;

  Future<StartAnswer> setStart(bool on);

  /// what the computer says now, as the page opens
  Future<void> refresh();
}
