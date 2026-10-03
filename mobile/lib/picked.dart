// the pickers leave a copy of what was chosen in the app cache. once the
// bytes are in hand it is zeroed and removed, with the plugin's own folder.
// the recorder's take goes the same way.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'main.dart' show shredFile;

// only a path inside the app's own cache is ours to destroy. a picker that
// hands back the real file, as the desktop ones do, gets left alone
Future<void> shredPicked(Iterable<PlatformFile> files) async {
  final cache = (await getTemporaryDirectory()).path;
  for (final f in files) {
    final path = f.path;
    if (path != null && path.startsWith(cache)) await shredFile(path);
  }
  try {
    await FilePicker.clearTemporaryFiles();
  } catch (_) {
    // the boot sweep empties the picker's folder too
  }
}

// the gallery picker copies each pick whole, exif and all, to
// cache/<uuid>/<its own name>. asked to shrink it, it writes
// cache/scaled_<that name> beside it and hands back only that
final _pickerFolder = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
const _scaled = 'scaled_';

bool _isPickerFolder(Directory cache, String path) =>
    p.equals(p.dirname(path), cache.path) &&
    _pickerFolder.hasMatch(p.basename(path));

Future<void> _shredFolder(Directory d) async {
  try {
    await for (final f in d.list(recursive: true, followLinks: false)) {
      if (f is File) await shredFile(f.path);
    }
    await d.delete(recursive: true);
  } catch (_) {
    // the boot sweep tries again
  }
}

Future<void> shredPickedImages(List<XFile> files) async => shredPickerCopies(
  await getTemporaryDirectory(),
  [for (final x in files) x.path],
);

// what the picker handed back goes, and so does the original it was made
// from. other picks' folders are left to their own flows
@visibleForTesting
Future<void> shredPickerCopies(Directory cache, List<String> paths) async {
  final originals = <String>{};
  for (final path in paths) {
    if (!p.isWithin(cache.path, path)) continue;
    final folder = p.dirname(path);
    if (_isPickerFolder(cache, folder)) {
      await _shredFolder(Directory(folder));
      continue;
    }
    await shredFile(path);
    final leaf = p.basename(path);
    if (p.equals(folder, cache.path) && leaf.startsWith(_scaled)) {
      originals.add(leaf.substring(_scaled.length));
    }
  }
  if (originals.isEmpty) return;
  try {
    await for (final d in cache.list(followLinks: false)) {
      if (d is! Directory || !_isPickerFolder(cache, d.path)) continue;
      for (final o in originals) {
        if (await File(p.join(d.path, o)).exists()) {
          await _shredFolder(d);
          break;
        }
      }
    }
  } catch (_) {
    // the boot sweep tries again
  }
}

// at start no pick is under way: every picker folder and shrunk copy goes
Future<void> sweepPickerLeftovers(Directory cache) async {
  if (!await cache.exists()) return;
  await for (final e in cache.list(followLinks: false)) {
    if (e is Directory && _isPickerFolder(cache, e.path)) {
      await _shredFolder(e);
    } else if (e is File && p.basename(e.path).startsWith(_scaled)) {
      await shredFile(e.path);
    }
  }
}

// the file picker keeps its copies in a folder of its own
Future<void> sweepFilePickerCopies(Directory cache) async {
  final picks = Directory(p.join(cache.path, 'file_picker'));
  if (!await picks.exists()) return;
  await for (final f in picks.list(recursive: true)) {
    if (f is File) await shredFile(f.path);
  }
  await picks.delete(recursive: true);
}

// a pick the lock dropped: nothing will read what it left, so every
// picker copy goes now
Future<void> dropPickerCopies() async {
  final cache = await getTemporaryDirectory();
  await sweepPickerLeftovers(cache);
  await sweepFilePickerCopies(cache);
}

// a voice note as recorded, read once and then zeroed and removed: the file
// is the voice before any disguise. null when there is no take to read.
Future<Uint8List?> takeRecording(String path) async {
  final Uint8List bytes;
  try {
    bytes = await File(path).readAsBytes();
  } catch (_) {
    return null;
  } finally {
    await shredFile(path);
  }
  return bytes;
}
