// SPDX-License-Identifier: GPL-3.0-or-later
// note to self as one file: text or markdown, in a zip with the photos and
// voice notes when there are any, locked with a passphrase in the age format
// unless plain was chosen. it is made in cache/notes_out, the app's own, and
// whatever held plaintext there is shredded on every way out
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dlog.dart';
import 'shred.dart';
import 'store_zip.dart';
import 'tools/age_ffi.dart';

enum NotesFormat { text, markdown }

const kNotesOut = 'notes_out';

class NotesExportFailed implements Exception {
  final AgeError? age;
  const NotesExportFailed([this.age]);
}

class NotesExportStopped implements Exception {
  const NotesExportStopped();
}

// more than a zip without zip64 holds: said before anything is written
class NotesExportTooLarge implements Exception {
  const NotesExportTooLarge();
}

Future<Directory> notesOutDir() async =>
    Directory(p.join((await getTemporaryDirectory()).path, kNotesOut));

// the sweep at launch, and whether an export began since: one that began
// is never swept from under, and one that begins during the sweep waits
Future<void>? _sweeping;
var _began = false;

@visibleForTesting
void forgetNotesExportRun() {
  _sweeping = null;
  _began = false;
}

/// what an export the app did not live through left behind. once, at launch
Future<void> sweepNotesExports(Directory cache) {
  if (_began) return Future.value();
  return _sweeping ??= () async {
    try {
      await shredTree(p.join(cache.path, kNotesOut));
    } catch (e) {
      dlog('notes export: leftovers stayed (${e.runtimeType})');
    }
  }();
}

// exports being made now, and made files android may still be copying
var _making = 0;
Completer<void>? _idle;
final _handed = <String>{};

/// a made file whose save kryfo stopped waiting for: a drop only unlinks it,
/// so a copy android still runs keeps reading
void notesExportHanded(String path) => _handed.add(path);

/// what this session's exports left, at a lock or a switch to another pin:
/// once any export being made has ended, every file is shredded, but one
/// android may still read is only unlinked
Future<void> dropNotesExports([Directory? cache]) async {
  while (_making > 0) {
    await (_idle ??= Completer<void>()).future;
  }
  try {
    final dir = Directory(
      p.join((cache ?? await getTemporaryDirectory()).path, kNotesOut),
    );
    if (!await dir.exists()) return;
    await for (final e in dir.list(followLinks: false)) {
      if (e is File && !_handed.remove(e.path)) {
        await shredFile(e.path);
      } else {
        await e.delete(recursive: true);
      }
    }
  } catch (e) {
    dlog('notes export: not dropped (${e.runtimeType})');
  }
}

typedef NoteFile = ({int note, String entry, File file, bool photo});

const _photoExts = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'avif'};

/// each note's photo or voice note still on the phone, with its place in
/// the zip
List<NoteFile> noteFiles(List<Map<String, Object?>> notes) {
  final out = <NoteFile>[];
  for (var i = 0; i < notes.length; i++) {
    for (final col in const ['media_path', 'file_path']) {
      final path = notes[i][col] as String?;
      if (path == null || path.isEmpty) continue;
      // a link is never followed out of the app's folders
      if (FileSystemEntity.typeSync(path, followLinks: false) !=
          FileSystemEntityType.file) {
        continue;
      }
      final named = col == 'file_path'
          ? notes[i]['file_name'] as String?
          : null;
      final ext = p
          .extension(named ?? path)
          .toLowerCase()
          .replaceAll(RegExp('[^a-z0-9]'), '');
      final n = (out.length + 1).toString().padLeft(3, '0');
      out.add((
        note: i,
        entry: 'media/$n${ext.isEmpty || ext.length > 8 ? '' : '.$ext'}',
        file: File(path),
        photo: col == 'media_path' && _photoExts.contains(ext),
      ));
    }
  }
  return out;
}

String _two(int n) => n.toString().padLeft(2, '0');
String _day(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';
String _stamp(DateTime t) => '${_day(t)} ${_two(t.hour)}:${_two(t.minute)}';

/// the notes' words, oldest first, each under its time, with where its
/// files sit in the zip
String notesBody(
  List<Map<String, Object?>> notes,
  NotesFormat format, [
  List<NoteFile> files = const [],
]) {
  final md = format == NotesFormat.markdown;
  final parts = <String>[];
  for (var i = 0; i < notes.length; i++) {
    final at = DateTime.fromMillisecondsSinceEpoch(
      notes[i]['sent_at'] as int? ?? 0,
    );
    final text = (notes[i]['plaintext'] as String? ?? '').trim();
    final lines = [
      md ? '## ${_stamp(at)}' : _stamp(at),
      if (text.isNotEmpty) text,
      for (final f in files)
        if (f.note == i)
          !md
              ? f.entry
              : f.photo
              ? '![](${f.entry})'
              : '[${p.basename(f.entry)}](${f.entry})',
    ];
    parts.add(lines.join(md ? '\n\n' : '\n'));
  }
  return '${parts.join('\n\n')}\n';
}

String _leaf() {
  final r = Random.secure();
  return List.generate(
    12,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// the export of [notes], made in [dir]: its path and the name it is saved
/// under. a null [passphrase] leaves it plain. nothing is left in [dir] when
/// it fails or [stopped] says so, and a locked one leaves no plaintext
Future<({String path, String name})> makeNotesExport(
  List<Map<String, Object?>> notes, {
  required NotesFormat format,
  required String? passphrase,
  required Directory dir,
  DateTime? now,
  bool Function()? stopped,
  void Function(double done)? progress,
}) async {
  _began = true;
  _making++;
  try {
    await _sweeping;
    return await _make(
      notes,
      format: format,
      passphrase: passphrase,
      dir: dir,
      now: now,
      stopped: stopped,
      progress: progress,
    );
  } finally {
    if (--_making == 0) {
      _idle?.complete();
      _idle = null;
    }
  }
}

Future<({String path, String name})> _make(
  List<Map<String, Object?>> notes, {
  required NotesFormat format,
  required String? passphrase,
  required Directory dir,
  DateTime? now,
  bool Function()? stopped,
  void Function(double done)? progress,
}) async {
  bool halt() => stopped?.call() ?? false;
  final at = now ?? DateTime.now();
  final files = noteFiles(notes);
  final ext = format == NotesFormat.text ? 'txt' : 'md';
  final kind = files.isEmpty ? ext : 'zip';
  final lock = passphrase != null;
  final name = 'kryfo-notes-${_day(at)}.$kind${lock ? '.age' : ''}';
  final leaf = _leaf();
  final plain = p.join(dir.path, '$leaf.$kind');
  final locked = p.join(dir.path, '$leaf.age');
  // the zip's share of the bar, the lock has the rest
  final share = files.isEmpty ? 0.0 : (lock ? 0.5 : 1.0);
  var kept = false;
  try {
    final body = utf8.encode(notesBody(notes, format, files));
    var total = 0, done = 0;
    for (final f in files) {
      total += await f.file.length();
    }
    // the data, each entry's two headers and the end record
    var whole = body.length + total + 22;
    for (final name in ['notes.$ext', for (final f in files) f.entry]) {
      whole += 30 + 46 + 2 * utf8.encode(name).length;
    }
    if (files.isNotEmpty && whole >= kZipLimit) {
      throw const NotesExportTooLarge();
    }
    await dir.create(recursive: true);
    if (files.isEmpty) {
      await File(plain).writeAsBytes(body, flush: true);
    } else {
      final zip = await StoreZip.create(plain, at);
      try {
        await zip.addBytes('notes.$ext', body);
        for (final f in files) {
          await zip.addFile(
            f.entry,
            f.file,
            stopped: halt,
            moved: (n) {
              done += n;
              if (total > 0) progress?.call(share * done / total);
            },
          );
        }
      } finally {
        await zip.close();
      }
    }
    if (halt()) throw const NotesExportStopped();
    if (!lock) {
      kept = true;
      return (path: plain, name: name);
    }
    final size = await File(plain).length();
    final watch = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (halt()) ageCancel();
      if (size > 0) {
        progress?.call(share + (1 - share) * min(1, ageProgress() / size));
      }
    });
    final AgeError? err;
    try {
      err = await ageLockPath(plain, locked, passphrase);
    } finally {
      watch.cancel();
    }
    if (err == AgeError.cancelled || halt()) throw const NotesExportStopped();
    if (err != null) throw NotesExportFailed(err);
    kept = true;
    return (path: locked, name: name);
  } on ZipStopped {
    throw const NotesExportStopped();
  } on NotesExportStopped {
    rethrow;
  } on NotesExportFailed {
    rethrow;
  } on NotesExportTooLarge {
    rethrow;
  } catch (e) {
    dlog('notes export: not made (${e.runtimeType})');
    throw const NotesExportFailed();
  } finally {
    if (lock || !kept) await shredFile(plain);
    if (!kept) await shredFile(locked);
  }
}
