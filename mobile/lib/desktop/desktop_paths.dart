// SPDX-License-Identifier: GPL-3.0-or-later
// where the desktop app keeps its files. path_provider's linux answer for
// documents is ~/Documents, which file indexers read and sync clients copy,
// so every directory the app asks for is under one folder of its own, mode
// 0700, and the process makes its files 0600
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
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

/// a folder in memory for what lives only while the app runs: the
/// session's tmpfs ($XDG_RUNTIME_DIR), else /dev/shm. null when neither is
/// there
String? desktopRuntimeDir({Map<String, String>? env, int? uid}) {
  if (Platform.isWindows) return null;
  final e = env ?? Platform.environment;
  final run = e['XDG_RUNTIME_DIR'];
  if (run != null && p.isAbsolute(run) && Directory(run).existsSync()) {
    return p.join(run, 'kryfo');
  }
  if (Directory('/dev/shm').existsSync()) {
    return '/dev/shm/kryfo-${uid ?? 0}';
  }
  return null;
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
