// SPDX-License-Identifier: GPL-3.0-or-later
// where the desktop app keeps its files. path_provider's linux answer for
// documents is ~/Documents, which file indexers read and sync clients copy,
// so every directory the app asks for is under one folder of its own, mode
// 0700, and the process makes its files 0600
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'desktop_posix.dart' as posix show ownerOf;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// the app's folder: $XDG_DATA_HOME/kryfo (inside a flatpak that is the
/// sandbox's own data dir), else ~/.local/share/kryfo, %LOCALAPPDATA%\Kryfo
/// on windows
String desktopDataDir({Map<String, String>? env}) {
  final e = env ?? Platform.environment;
  if (Platform.isWindows) {
    final local =
        e['LOCALAPPDATA'] ??
        p.join(e['USERPROFILE'] ?? '.', 'AppData', 'Local');
    return p.join(local, 'Kryfo');
  }
  final xdg = e['XDG_DATA_HOME'];
  final base = xdg != null && p.isAbsolute(xdg)
      ? xdg
      : p.join(e['HOME'] ?? '/nonexistent', '.local', 'share');
  return p.join(base, 'kryfo');
}

typedef _ModeC = Int32 Function(Pointer<Utf8>, Uint32);
typedef _Mode = int Function(Pointer<Utf8>, int);
typedef _UmaskC = Uint32 Function(Uint32);
typedef _Umask = int Function(int);

/// mode 0700 on dir, made if missing. false when chmod failed
bool makePrivateDir(String dir) {
  try {
    Directory(dir).createSync(recursive: true);
  } catch (_) {
    return false;
  }
  if (Platform.isWindows) return true;
  final chmod = DynamicLibrary.process().lookupFunction<_ModeC, _Mode>('chmod');
  final path = dir.toNativeUtf8();
  try {
    return chmod(path, 448) == 0; // 0700
  } finally {
    calloc.free(path);
  }
}

/// files and folders the process makes are its user's alone
void privateUmask() {
  if (Platform.isWindows) return;
  DynamicLibrary.process().lookupFunction<_UmaskC, _Umask>('umask')(63); // 077
}

/// a folder in memory for what lives only while the app runs: kryfo's own
/// one in the session's tmpfs ($XDG_RUNTIME_DIR), else in /dev/shm. one
/// found there is taken only when it is no link, this user's, and 0700;
/// otherwise a new one with a random name is made beside it. null when no
/// memory folder can be had, and the caller keeps temporary files in its
/// own folder on the disk
String? desktopRuntimeDir({
  Map<String, String>? env,
  required int uid,
  int? Function(String path)? owner,
  int? Function(String path)? mode,
}) {
  if (Platform.isWindows) return null;
  final e = env ?? Platform.environment;
  final ownerOf_ = owner ?? _ownerOf;
  final modeOf = mode ?? _modeOf;
  final bases = <(String, String)>[];
  final run = e['XDG_RUNTIME_DIR'];
  if (run != null && p.isAbsolute(run) && Directory(run).existsSync()) {
    bases.add((run, 'kryfo'));
  }
  if (Directory('/dev/shm').existsSync()) bases.add(('/dev/shm', 'kryfo-$uid'));
  for (final (base, name) in bases) {
    final d = p.join(base, name);
    final type = FileSystemEntity.typeSync(d, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      try {
        Directory(d).createSync();
      } catch (_) {}
    }
    if (FileSystemEntity.typeSync(d, followLinks: false) ==
            FileSystemEntityType.directory &&
        ownerOf_(d) == uid) {
      makePrivateDir(d);
      if (modeOf(d) == 448) return d;
    }
    // someone else's, a link, or open to others: one of our own, by chance
    try {
      final t = Directory(base).createTempSync('kryfo-');
      if (ownerOf_(t.path) == uid && modeOf(t.path) == 448) return t.path;
      t.deleteSync();
    } catch (_) {}
  }
  return null;
}

int? _ownerOf(String path) => posix.ownerOf(path);

/// folders a run before made by chance (kryfo-XXXXXX, see
/// [desktopRuntimeDir]) and left behind: ours, no link, not [keep]. what
/// they hold is zeroed before they go
void sweepOldRuntimeDirs(
  String? keep, {
  Map<String, String>? env,
  required int uid,
  int? Function(String path)? owner,
}) {
  if (Platform.isWindows) return;
  final e = env ?? Platform.environment;
  final ownerOf_ = owner ?? _ownerOf;
  final run = e['XDG_RUNTIME_DIR'];
  final bases = [if (run != null && p.isAbsolute(run)) run, '/dev/shm'];
  final made = RegExp(r'^kryfo-[A-Za-z0-9]{6}$');
  for (final base in bases) {
    final d = Directory(base);
    if (!d.existsSync()) continue;
    for (final x in d.listSync(followLinks: false)) {
      final name = p.basename(x.path);
      if (x is! Directory || !made.hasMatch(name) || name == 'kryfo-$uid') {
        continue;
      }
      if (keep != null && p.equals(x.path, keep)) continue;
      if (ownerOf_(x.path) != uid) continue;
      try {
        for (final f in x.listSync(recursive: true, followLinks: false)) {
          if (f is File) {
            final n = f.lengthSync();
            final r = f.openSync(mode: FileMode.writeOnlyAppend);
            r.setPositionSync(0);
            r.writeFromSync(List.filled(n, 0));
            r.closeSync();
          }
        }
        x.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

int? _modeOf(String path) {
  try {
    return FileStat.statSync(path).mode & 511;
  } catch (_) {
    return null;
  }
}

/// path_provider's answers on desktop, all inside [root]. the temporary
/// folder is [runtime] when given: a picked photo, a take, a file on its
/// way to a save are plain there, in memory and never on the disk
class DesktopPaths extends PathProviderPlatform {
  DesktopPaths(this.root, {this.runtime});
  final String root;
  final String? runtime;

  String _dir(String name) {
    final d = p.join(root, name);
    makePrivateDir(root);
    makePrivateDir(d);
    return d;
  }

  @override
  Future<String?> getTemporaryPath() async {
    final r = runtime;
    if (r == null) return _dir('tmp');
    makePrivateDir(r);
    final d = p.join(r, 'tmp');
    makePrivateDir(d);
    return d;
  }

  @override
  Future<String?> getApplicationSupportPath() async => _dir('support');
  @override
  Future<String?> getLibraryPath() async => _dir('support');
  @override
  Future<String?> getApplicationDocumentsPath() async => _dir('docs');
  @override
  Future<String?> getApplicationCachePath() async => _dir('cache');
  // downloads and external storage are where a user's own files go: the app
  // never puts anything there by itself
  @override
  Future<String?> getExternalStoragePath() async => null;
  @override
  Future<List<String>?> getExternalCachePaths() async => null;
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => null;
  @override
  Future<String?> getDownloadsPath() async => null;
}
