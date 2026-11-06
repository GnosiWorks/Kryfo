// SPDX-License-Identifier: GPL-3.0-or-later
// a file leaves the desktop app only through a save the person picks: the
// system's save dialog, then a copy kryfo makes and checks. it answers the
// phone's save calls in their own shapes, so every caller works as is
import 'dart:async';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:path/path.dart' as p;

import 'desktop_posix.dart' show syncFolder;

/// the dialog, behind a seam for the tests: a path picked, or null
typedef PickSave = Future<String?> Function(String suggestedName);

Future<String?> _dialog(String name) async =>
    (await FileSelectorPlatform.instance.getSaveLocation(
      options: SaveDialogOptions(suggestedName: name),
    ))?.path;

class DesktopSave {
  DesktopSave({PickSave? pick}) : _pick = pick ?? _dialog;

  final PickSave _pick;
  String _stage = 'idle';
  int _copied = 0;
  bool _stop = false;

  /// the phone's saveDocumentState answer
  Map<String, Object?> state() => {'stage': _stage, 'copied': _copied};

  /// a copy running stops at its next block and takes away what it wrote
  void cancel() => _stop = true;

  /// the dialog and the copy: saved, cancelled, full or failed, and the
  /// folder it went to
  Future<Map<String, Object?>> save(String from, String name) async {
    if (_stage != 'idle') return {'state': 'failed'};
    _stop = false;
    _copied = 0;
    _stage = 'picking';
    final String? to;
    try {
      to = await _pick(p.basename(name));
    } catch (_) {
      _stage = 'idle';
      return {'state': 'failed'};
    }
    if (to == null || _stop) {
      _stage = 'idle';
      return {'state': 'cancelled'};
    }
    if (p.equals(to, from)) {
      _stage = 'idle';
      return {'state': 'failed'};
    }
    _stage = 'copying';
    final part = File('$to.part');
    try {
      final src = File(from).openSync();
      final dst = part.openSync(mode: FileMode.writeOnly);
      try {
        while (true) {
          if (_stop) throw const _Stopped();
          final b = src.readSync(1 << 20);
          if (b.isEmpty) break;
          dst.writeFromSync(b);
          _copied += b.length;
          // a long copy lets the page ask how it goes
          await Future<void>.delayed(Duration.zero);
        }
        dst.flushSync();
      } finally {
        dst.closeSync();
        src.closeSync();
      }
      _stage = 'checking';
      if (part.lengthSync() != File(from).lengthSync()) {
        throw const FileSystemException('short copy');
      }
      part.renameSync(to);
      syncFolder(p.dirname(to));
      return {'state': 'saved', 'where': p.basename(p.dirname(to))};
    } on _Stopped {
      _drop(part);
      return {'state': 'cancelled'};
    } on FileSystemException catch (e) {
      _drop(part);
      return {'state': e.osError?.errorCode == 28 ? 'full' : 'failed'};
    } catch (_) {
      _drop(part);
      return {'state': 'failed'};
    } finally {
      _stage = 'idle';
    }
  }

  void _drop(File f) {
    try {
      f.deleteSync();
    } catch (_) {}
  }

  /// the tools' and the camera's save: 'saved', 'kept' when the dialog was
  /// closed, 'failed'
  Future<String> saveAs(String from, String name) async {
    final r = await save(from, name);
    return switch (r['state']) {
      'saved' => 'saved',
      'cancelled' => 'kept',
      _ => 'failed',
    };
  }

  /// the dialog alone: the place picked, or null when it was closed
  Future<String?> pickTo(String name) async {
    if (_stage != 'idle') return null;
    _stage = 'picking';
    try {
      return await _pick(p.basename(name));
    } catch (_) {
      return null;
    } finally {
      _stage = 'idle';
    }
  }

  /// [write] makes `<to>.part`, which is moved into place when it says it
  /// wrote it whole: saved, full or failed. a part left by a failure goes
  Future<String> writeTo(
    String to,
    Future<bool> Function(String part) write,
  ) async {
    if (_stage != 'idle') return 'failed';
    _stage = 'copying';
    final part = File('$to.part');
    try {
      if (!await write(part.path) || !part.existsSync()) {
        _drop(part);
        return 'failed';
      }
      part.renameSync(to);
      syncFolder(p.dirname(to));
      return 'saved';
    } on FileSystemException catch (e) {
      _drop(part);
      return e.osError?.errorCode == 28 ? 'full' : 'failed';
    } catch (_) {
      _drop(part);
      return 'failed';
    } finally {
      _stage = 'idle';
    }
  }

  /// the dialog, then [write] straight to the picked place: nothing plain
  /// waits anywhere else on the way. 'saved', 'kept' when the dialog was
  /// closed, 'failed'
  Future<String> saveWith(
    String name,
    Future<bool> Function(String part) write,
  ) async {
    final to = await pickTo(name);
    if (to == null) return 'kept';
    final r = await writeTo(to, write);
    return r == 'saved' ? 'saved' : 'failed';
  }

  /// bytes in memory (a take, a cleaned picture, a qr) through the same
  /// dialog, written only at the place picked
  Future<String> saveBytes(List<int> bytes, String name) =>
      saveWith(name, (part) async {
        final f = File(part).openSync(mode: FileMode.writeOnly);
        try {
          f.writeFromSync(bytes);
          f.flushSync();
        } finally {
          f.closeSync();
        }
        return File(part).lengthSync() == bytes.length;
      });
}

/// the one save the desktop's answers and the tools share, so one dialog
/// is up at a time. a test puts its own
DesktopSave deskSaver = DesktopSave();

class _Stopped implements Exception {
  const _Stopped();
}
