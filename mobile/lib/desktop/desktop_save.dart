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

  /// bytes the camera made, through the same dialog
  Future<bool> saveBytes(List<int> bytes, String name, String tmpDir) async {
    final f = File(
      p.join(tmpDir, 'out_${DateTime.now().microsecondsSinceEpoch}'),
    );
    try {
      f.writeAsBytesSync(bytes, flush: true);
      return (await save(f.path, name))['state'] == 'saved';
    } finally {
      _drop(f);
    }
  }
}

class _Stopped implements Exception {
  const _Stopped();
}
