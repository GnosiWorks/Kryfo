// SPDX-License-Identifier: GPL-3.0-or-later
// keep running in the tray and start with the computer. the tray is the
// runner's; the start is a file in ~/.config/autostart on linux, the
// background portal's in a flatpak, and the user's run key on windows.
// nothing here needs an admin, and a refusal is said as it is
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../l10n/l10n.dart';
import 'desktop_mode.dart';

/// where the two switches are kept, in the vault: the same in every session
const runEntry = 'kryfo.run';

/// the runner's channel: the tray, the window, the portal
const runChannel = MethodChannel('kryfo/desktop');

/// the runner's tray
abstract class TrayHost {
  /// the icon up, with its words: closing then hides the window
  Future<void> show();

  /// the icon gone: closing then quits
  Future<void> hide();

  /// the desktop shows the icon. null when the runner cannot say
  Future<bool?> shown();
}

class ChannelTray implements TrayHost {
  const ChannelTray(this.words);

  /// the icon's words, said in the app's language
  final Future<void> Function() words;

  @override
  Future<void> show() => words();

  @override
  Future<void> hide() async {
    try {
      await runChannel.invokeMethod<void>('noTray');
    } catch (_) {}
  }

  @override
  Future<bool?> shown() async {
    try {
      return await runChannel.invokeMethod<bool>('trayState');
    } catch (_) {
      return null;
    }
  }
}

/// what the start with the computer passes: the app starts in the tray,
/// with no window, unless the desktop has no tray
const startHiddenFlag = '--hidden';

/// where the computer keeps what starts with it
abstract class StartPlace {
  /// an entry kept from before (another file, no [startHiddenFlag]) written
  /// again as this app writes it. nothing when it is off
  Future<void> mend();

  /// on, off, or held off by the computer's own settings
  Future<StartAnswer> read();

  /// [StartAnswer.refused] when the computer would not take it
  Future<StartAnswer> set(bool on);
}

/// the switches and what the computer says, for the notifications page
class DesktopRun extends ChangeNotifier implements DesktopRunView {
  DesktopRun({
    required this.tray,
    required this.place,
    required String? Function(String key) read,
    required Future<void> Function(String key, String value) write,
    this.trayWait = const Duration(milliseconds: 500),
  }) : _read = read,
       _write = write;

  final TrayHost tray;

  /// how long a new icon gets to find its place in the tray
  final Duration trayWait;
  final StartPlace? place;
  final String? Function(String key) _read;
  final Future<void> Function(String key, String value) _write;

  bool? _trayShown;
  StartAnswer? _start;
  bool _refused = false;

  Map<String, dynamic> _kept() {
    try {
      final raw = _read(runEntry);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _keep(String key, Object value) =>
      _write(runEntry, jsonEncode(_kept()..[key] = value));

  /// on unless turned off
  @override
  bool get trayOn => _kept()['tray'] != false;

  /// the first close to the tray has said the app keeps running there
  bool get trayHinted => _kept()['hinted'] == true;

  Future<void> markHinted() async {
    try {
      await _keep('hinted', true);
    } catch (_) {}
  }

  @override
  bool? get trayShown => _trayShown;

  @override
  bool get canStart => place != null;

  @override
  StartAnswer? get start => _start;

  @override
  bool get startRefused => _refused;

  /// the tray as kept, once the vault is open
  Future<void> begin() async {
    try {
      await place?.mend();
    } catch (_) {}
    if (!trayOn) return refresh();
    await tray.show();
    await refresh();
    if (_trayShown == false) {
      _trayShown = await _settled();
      notifyListeners();
    }
  }

  // the icon finds its place a moment after it is made: a no is asked
  // once more before it is said
  Future<bool?> _settled() async {
    final first = await tray.shown();
    if (first != false) return first;
    await Future<void>.delayed(trayWait);
    return trayOn ? await tray.shown() : null;
  }

  @override
  Future<void> refresh() async {
    final shown = trayOn ? await tray.shown() : null;
    StartAnswer? start;
    try {
      start = await place?.read();
    } catch (_) {
      start = StartAnswer.off;
    }
    _trayShown = shown;
    _start = start;
    notifyListeners();
  }

  @override
  Future<void> setTray(bool on) async {
    if (on == trayOn) return;
    await _keep('tray', on);
    notifyListeners();
    if (on) {
      await tray.show();
    } else {
      await tray.hide();
    }
    _trayShown = on ? await _settled() : null;
    notifyListeners();
  }

  @override
  Future<StartAnswer> setStart(bool on) async {
    final pl = place;
    if (pl == null) return StartAnswer.refused;
    StartAnswer a;
    try {
      a = await pl.set(on);
    } catch (_) {
      a = StartAnswer.refused;
    }
    _refused = a == StartAnswer.refused;
    if (_refused) {
      try {
        _start = await pl.read();
      } catch (_) {
        _start = StartAnswer.off;
      }
    } else {
      _start = a;
    }
    notifyListeners();
    return a;
  }
}

/// the place for this computer: the portal in a flatpak, the autostart
/// folder elsewhere on linux, the run key on windows
StartPlace? startPlaceHere({
  required String? Function(String key) read,
  required Future<void> Function(String key, String value) write,
}) {
  final exe = Platform.resolvedExecutable;
  if (Platform.isWindows) return WindowsStart(FfiRunKey(), exe);
  if (!Platform.isLinux) return null;
  final env = Platform.environment;
  if (env['FLATPAK_ID'] != null || File('/.flatpak-info').existsSync()) {
    return PortalStart(const ChannelPortal(), read: read, write: write);
  }
  final home = env['HOME'];
  final config = env['XDG_CONFIG_HOME'];
  final dir = config != null && p.isAbsolute(config)
      ? config
      : home == null
      ? null
      : p.join(home, '.config');
  if (dir == null) return null;
  return LinuxStart(p.join(dir, 'autostart'), linuxStartFile(exe, env));
}

/// the file the entry starts. an appimage runs from a mount that is gone at
/// the next login, so the image itself, but only when this binary is in
/// that mount: $APPIMAGE is passed on to whatever an appimage starts
@visibleForTesting
String linuxStartFile(String exe, Map<String, String> env) {
  final image = env['APPIMAGE'];
  final mount = env['APPDIR'];
  if (image == null || mount == null) return exe;
  if (!p.isAbsolute(image) || !p.isAbsolute(mount)) return exe;
  return p.isWithin(mount, exe) ? image : exe;
}

// --- linux: an xdg autostart entry

/// the name the entry has in the autostart folder
const autostartFile = 'app.kryfo.Kryfo.desktop';

class LinuxStart implements StartPlace {
  LinuxStart(this.dir, this.exe);

  /// ~/.config/autostart, or $XDG_CONFIG_HOME/autostart
  final String dir;
  final String exe;

  File get _file => File(p.join(dir, autostartFile));

  /// an entry that is on but starts another file (the bundle moved or was
  /// updated elsewhere) or starts it without [startHiddenFlag] is written
  /// again for this one
  @override
  Future<void> mend() async {
    final f = _file;
    if (!f.existsSync() || await read() != StartAnswer.on) return;
    final exec = desktopExec(exe);
    if (exec == null) return;
    final lines = const LineSplitter().convert(f.readAsStringSync());
    if (lines.contains('Exec=$exec $startHiddenFlag')) return;
    await set(true);
  }

  @override
  Future<StartAnswer> read() async {
    final f = _file;
    if (!f.existsSync()) return StartAnswer.off;
    return entrySaysOff(f.readAsStringSync())
        ? StartAnswer.off
        : StartAnswer.on;
  }

  @override
  Future<StartAnswer> set(bool on) async {
    try {
      if (!on) {
        if (_file.existsSync()) _file.deleteSync();
        return _file.existsSync() ? StartAnswer.refused : StartAnswer.off;
      }
      final exec = desktopExec(exe);
      if (exec == null) return StartAnswer.refused;
      Directory(dir).createSync(recursive: true);
      final tmp = File(p.join(dir, '.$autostartFile.new'));
      tmp.writeAsStringSync(autostartEntry(exec), flush: true);
      tmp.renameSync(_file.path);
      return await read() == StartAnswer.on
          ? StartAnswer.on
          : StartAnswer.refused;
    } on FileSystemException {
      return StartAnswer.refused;
    }
  }
}

/// turned off from the desktop's own settings: Hidden=true, or any
/// desktop's X-*-Autostart-enabled=false, keys and values trimmed, in the
/// main group
@visibleForTesting
bool entrySaysOff(String text) {
  final switchKey = RegExp(r'^X-[A-Za-z0-9-]+-Autostart-enabled$');
  var main = true;
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.startsWith('[')) {
      main = line == '[Desktop Entry]';
      continue;
    }
    if (!main || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq < 0) continue;
    final key = line.substring(0, eq).trim();
    final value = line.substring(eq + 1).trim();
    if (key == 'Hidden' && value == 'true') return true;
    if (switchKey.hasMatch(key) && value == 'false') return true;
  }
  return false;
}

/// the entry's text
@visibleForTesting
String autostartEntry(String exec) =>
    '[Desktop Entry]\n'
    'Type=Application\n'
    'Name=Kryfo\n'
    'Exec=$exec $startHiddenFlag\n'
    'Icon=app.kryfo.Kryfo\n'
    'Terminal=false\n'
    'X-GNOME-Autostart-enabled=true\n';

/// [exe] as an Exec value: quoted as the desktop entry spec asks, then
/// escaped as a string value. null for a path no entry can hold
@visibleForTesting
String? desktopExec(String exe) {
  if (exe.isEmpty || exe.contains(RegExp(r'[\x00-\x1f\x7f]'))) return null;
  final quoted = exe.replaceAllMapped(RegExp(r'["`$\\]'), (m) => '\\${m[0]}');
  // a field code is %x; a plain percent is %%. backslashes are doubled
  // once more as the string value is read
  return '"$quoted"'.replaceAll(r'\', r'\\').replaceAll('%', '%%');
}

// --- flatpak: the background portal

/// the portal's request, through the runner (gio's dbus)
abstract class BackgroundPortal {
  /// true when the portal granted [on], false when it said no, null when
  /// there was no answer
  Future<bool?> autostart(bool on);
}

class ChannelPortal implements BackgroundPortal {
  const ChannelPortal();

  @override
  Future<bool?> autostart(bool on) async {
    try {
      return await runChannel.invokeMethod<bool>('autostart', {
        'on': on,
        'reason': l10n.desktopStartHint,
      });
    } catch (_) {
      return null;
    }
  }
}

/// a flatpak cannot see the host's autostart folder: what the portal last
/// granted is kept in the vault. the runner gives the portal the command
/// line, with [startHiddenFlag]
class PortalStart implements StartPlace {
  PortalStart(
    this.portal, {
    required String? Function(String key) read,
    required Future<void> Function(String key, String value) write,
  }) : _readKv = read,
       _writeKv = write;

  final BackgroundPortal portal;
  final String? Function(String key) _readKv;
  final Future<void> Function(String key, String value) _writeKv;

  Map<String, dynamic> _kept() {
    try {
      final raw = _readKv(runEntry);
      return raw == null ? {} : (jsonDecode(raw) as Map).cast();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<StartAnswer> read() async =>
      _kept()['portalStart'] == true ? StartAnswer.on : StartAnswer.off;

  /// nothing: the kept grant is only what was last asked, and the user may
  /// have switched the start off outside kryfo. asking again would turn it
  /// back on unasked. an old grant starts with the window until the switch
  /// is flipped
  @override
  Future<void> mend() async {}

  @override
  Future<StartAnswer> set(bool on) async {
    final granted = await portal.autostart(on);
    if (granted != true) return StartAnswer.refused;
    await _writeKv(runEntry, jsonEncode(_kept()..['portalStart'] = on));
    return on ? StartAnswer.on : StartAnswer.off;
  }
}

// --- windows: the user's run key

/// HKCU\...\Run and its startup approved flag, behind a seam for tests
abstract class RunKey {
  /// the value [name] under Run, null when there is none
  String? value(String name);

  /// false when windows refused
  bool setValue(String name, String data);

  /// true when there is no value [name] left
  bool deleteValue(String name);

  /// the user switched [name] off in windows' startup apps
  bool switchedOff(String name);
}

/// the value's name under Run
const runValueName = 'Kryfo';

class WindowsStart implements StartPlace {
  WindowsStart(this.key, this.exe);
  final RunKey key;
  final String exe;

  /// the exe path quoted, so a folder with spaces starts the right file
  String get command => '"$exe" $startHiddenFlag';

  /// a value from before (another file, no flag) written again. the
  /// user's switch in windows' settings is kept by name, so it stays theirs
  @override
  Future<void> mend() async {
    final now = key.value(runValueName);
    if (now == null || now == command || exe.contains('"')) return;
    key.setValue(runValueName, command);
  }

  @override
  Future<StartAnswer> read() async {
    if (key.value(runValueName) == null) return StartAnswer.off;
    return key.switchedOff(runValueName) ? StartAnswer.heldOff : StartAnswer.on;
  }

  @override
  Future<StartAnswer> set(bool on) async {
    if (!on) {
      return key.deleteValue(runValueName)
          ? StartAnswer.off
          : StartAnswer.refused;
    }
    if (exe.contains('"')) return StartAnswer.refused;
    if (!key.setValue(runValueName, command)) return StartAnswer.refused;
    if (key.value(runValueName) != command) return StartAnswer.refused;
    // the user's own switch in windows' settings stays theirs
    return key.switchedOff(runValueName) ? StartAnswer.heldOff : StartAnswer.on;
  }
}

// HKEY_CURRENT_USER is (HKEY)(LONG)0x80000001: sign-extended on 64-bit
const _hkcu = -0x7fffffff;
const _runPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
const _approvedPath =
    r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
const _keyQuery = 0x0001, _keySet = 0x0002;
const _regSz = 1;

typedef _CreateC =
    Int32 Function(
      IntPtr,
      Pointer<Utf16>,
      Uint32,
      Pointer<Utf16>,
      Uint32,
      Uint32,
      Pointer<Void>,
      Pointer<IntPtr>,
      Pointer<Uint32>,
    );
typedef _Create =
    int Function(
      int,
      Pointer<Utf16>,
      int,
      Pointer<Utf16>,
      int,
      int,
      Pointer<Void>,
      Pointer<IntPtr>,
      Pointer<Uint32>,
    );
typedef _OpenC =
    Int32 Function(IntPtr, Pointer<Utf16>, Uint32, Uint32, Pointer<IntPtr>);
typedef _Open = int Function(int, Pointer<Utf16>, int, int, Pointer<IntPtr>);
typedef _QueryC =
    Int32 Function(
      IntPtr,
      Pointer<Utf16>,
      Pointer<Uint32>,
      Pointer<Uint32>,
      Pointer<Uint8>,
      Pointer<Uint32>,
    );
typedef _Query =
    int Function(
      int,
      Pointer<Utf16>,
      Pointer<Uint32>,
      Pointer<Uint32>,
      Pointer<Uint8>,
      Pointer<Uint32>,
    );
typedef _SetC =
    Int32 Function(
      IntPtr,
      Pointer<Utf16>,
      Uint32,
      Uint32,
      Pointer<Uint8>,
      Uint32,
    );
typedef _Set = int Function(int, Pointer<Utf16>, int, int, Pointer<Uint8>, int);
typedef _DeleteC = Int32 Function(IntPtr, Pointer<Utf16>);
typedef _Delete = int Function(int, Pointer<Utf16>);
typedef _CloseC = Int32 Function(IntPtr);
typedef _Close = int Function(int);

/// advapi32's registry calls, per user, no admin
class FfiRunKey implements RunKey {
  static final _lib = DynamicLibrary.open('advapi32.dll');
  static final _create = _lib.lookupFunction<_CreateC, _Create>(
    'RegCreateKeyExW',
  );
  static final _open = _lib.lookupFunction<_OpenC, _Open>('RegOpenKeyExW');
  static final _query = _lib.lookupFunction<_QueryC, _Query>(
    'RegQueryValueExW',
  );
  static final _set = _lib.lookupFunction<_SetC, _Set>('RegSetValueExW');
  static final _delete = _lib.lookupFunction<_DeleteC, _Delete>(
    'RegDeleteValueW',
  );
  static final _close = _lib.lookupFunction<_CloseC, _Close>('RegCloseKey');

  /// [use] with the key at [path] open, or null when it does not open
  T? _with<T>(
    String path,
    int access,
    T Function(int key) use, {
    bool create = false,
  }) {
    final out = calloc<IntPtr>();
    final sub = path.toNativeUtf16();
    try {
      final rc = create
          ? _create(_hkcu, sub, 0, nullptr, 0, access, nullptr, out, nullptr)
          : _open(_hkcu, sub, 0, access, out);
      if (rc != 0) return null;
      try {
        return use(out.value);
      } finally {
        _close(out.value);
      }
    } finally {
      calloc.free(sub);
      calloc.free(out);
    }
  }

  Uint8List? _bytes(int key, String name) {
    final n = name.toNativeUtf16();
    final size = calloc<Uint32>();
    final type = calloc<Uint32>();
    try {
      if (_query(key, n, nullptr, type, nullptr, size) != 0) return null;
      final buf = calloc<Uint8>(size.value + 2);
      try {
        if (_query(key, n, nullptr, type, buf, size) != 0) return null;
        return Uint8List.fromList(buf.asTypedList(size.value));
      } finally {
        calloc.free(buf);
      }
    } finally {
      calloc.free(n);
      calloc.free(size);
      calloc.free(type);
    }
  }

  @override
  String? value(String name) => _with<String?>(_runPath, _keyQuery, (k) {
    final b = _bytes(k, name);
    if (b == null) return null;
    final units = Uint16List.view(b.buffer, 0, b.length ~/ 2);
    final s = String.fromCharCodes(units);
    final end = s.indexOf('\u0000');
    return end < 0 ? s : s.substring(0, end);
  });

  @override
  bool setValue(String name, String data) =>
      _with(_runPath, _keySet | _keyQuery, (k) {
        final n = name.toNativeUtf16();
        final d = data.toNativeUtf16();
        try {
          // the size in bytes, with the closing nul
          final bytes = (data.length + 1) * 2;
          return _set(k, n, 0, _regSz, d.cast<Uint8>(), bytes) == 0;
        } finally {
          calloc.free(n);
          calloc.free(d);
        }
      }, create: true) ??
      false;

  @override
  bool deleteValue(String name) =>
      _with(_runPath, _keySet | _keyQuery, (k) {
        final n = name.toNativeUtf16();
        try {
          final rc = _delete(k, n);
          // ERROR_FILE_NOT_FOUND: there was none
          return rc == 0 || rc == 2;
        } finally {
          calloc.free(n);
        }
      }) ??
      true;

  /// an odd first byte is off (03, 07), an even one on (02, 06)
  @override
  bool switchedOff(String name) =>
      _with(_approvedPath, _keyQuery, (k) {
        final b = _bytes(k, name);
        return b != null && b.isNotEmpty && b[0].isOdd;
      }) ??
      false;
}
