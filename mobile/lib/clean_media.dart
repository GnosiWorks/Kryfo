// SPDX-License-Identifier: GPL-3.0-or-later
// the one cleaner every lane that sends or saves a file goes through: a
// picture or a video, told by its bytes (a video by its name too), cleaned
// in place on our own copy and then read again. what still reads as
// anything is refused, never passed on half clean. anything else is not
// media and is left exactly as it is. a send or a note (copyForSend) draws
// a picture the cleaner refuses again as a clean jpeg, and sends one that
// cannot be drawn as it is, never asking
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_kind.dart' show bytesSayIsoVideo;
import 'image_strip.dart';
import 'meta/file_source.dart';
import 'meta/meta_reader.dart';
import 'mp4_strip.dart';
import 'shred.dart';
import 'desktop/desktop_mode.dart' show onDesktop, runIsolated;
import 'picture_convert.dart' show cleanJpegOf, kConvertMost;

enum MediaClean { clean, notMedia, refused }

class MediaCleaned {
  final MediaClean how;

  /// a video, for the line a refusal shows
  final bool video;

  /// refused because the disk stopped it (full, gone), not for what the
  /// file holds: such a file never goes as it is
  final bool io;
  const MediaCleaned(this.how, {this.video = false, this.io = false});
}

/// cleans [path] in place, off the ui thread. [name] is what the file was
/// called; a [raw] picture is never walked as a video
Future<MediaCleaned> cleanMediaFile(
  String path, {
  String name = '',
  bool raw = false,
}) async {
  try {
    return await runIsolated(
      () => cleanMediaFileHere(path, name: name, raw: raw),
    );
  } catch (_) {
    return MediaCleaned(MediaClean.refused, video: videoNameNeedsStrip(name));
  }
}

/// never throws: a disk that fills while zeroing, or anything else that
/// stops the clean half way, is a refusal, and the caller shreds the copy
Future<MediaCleaned> cleanMediaFileHere(
  String path, {
  String name = '',
  bool raw = false,
}) async {
  try {
    return await _clean(path, name, raw);
  } on FileSystemException {
    return MediaCleaned(
      MediaClean.refused,
      video: videoNameNeedsStrip(name),
      io: true,
    );
  } catch (_) {
    return MediaCleaned(MediaClean.refused, video: videoNameNeedsStrip(name));
  }
}

Future<MediaCleaned> _clean(String path, String name, bool raw) async {
  if (!raw && (videoNameNeedsStrip(name) || await bytesSayIsoVideo(path))) {
    final ok = stripMp4Sync(path) == true && mp4MetadataCountSync(path) == 0;
    return MediaCleaned(
      ok ? MediaClean.clean : MediaClean.refused,
      video: true,
    );
  }
  final ok = await stripPictureFile(path);
  if (ok == null) return const MediaCleaned(MediaClean.refused);
  if (!ok) return const MediaCleaned(MediaClean.notMedia);
  return MediaCleaned(readsClean(path) ? MediaClean.clean : MediaClean.refused);
}

/// true when the reader finds nothing beside the picture or video in [path]
bool readsClean(String path) {
  final src = FileSource.open(path);
  try {
    return readMetaStrict(src).status == MetaStatus.nothing;
  } catch (_) {
    return false;
  } finally {
    src.close();
  }
}

/// the folder in the cache that clean copies for a save or a send are made
/// in, swept at every start
const kSaveCopies = 'save_clean';

/// what a save hands out for [path]: a clean copy made under [cache], the
/// file itself when it is not a picture or a video, or null when it is one
/// and cannot be cleaned. the caller shreds [copy] once the save is done
Future<({String? path, String? copy})> cleanedForSave(
  String path,
  String? name,
  Directory cache,
) async {
  final dir = Directory('${cache.path}/$kSaveCopies/${_leaf()}');
  final copy = '${dir.path}/${_safe(name)}';
  try {
    await dir.create(recursive: true);
    await File(path).copy(copy);
    final done = await cleanMediaFile(copy, name: name ?? '');
    switch (done.how) {
      case MediaClean.clean:
        return (path: copy, copy: dir.path);
      case MediaClean.notMedia:
        await shredTree(dir.path);
        return (path: path, copy: null);
      case MediaClean.refused:
        await shredTree(dir.path);
        return (path: null, copy: null);
    }
  } catch (_) {
    // whatever stopped it, the copy does not stay behind
    try {
      await shredTree(dir.path);
    } catch (_) {}
    return (path: null, copy: null);
  }
}

final _rnd = Random.secure();

String _leaf() => [
  for (var i = 0; i < 8; i++)
    _rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

String _safe(String? name) {
  final n = (name ?? '').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return n.isEmpty ? 'file' : n;
}

/// [src] copied to [dest] clean. the copy is made and cleaned in a private
/// folder under [cache] (the app's cache when null), and only a clean one,
/// or one that is no media, is moved to [dest]. any error on the way shreds
/// what was made and is a refusal, so the media folder never holds a copy
/// that was not cleaned. [copier] stands in for the copy in tests
Future<MediaCleaned> copyClean(
  String src,
  String dest, {
  String name = '',
  bool raw = false,
  Directory? cache,
  @visibleForTesting Future<void> Function(String from, String to)? copier,
}) async {
  Directory? dir;
  var moved = false;
  final MediaCleaned done;
  try {
    final root = cache ?? await getTemporaryDirectory();
    dir = Directory('${root.path}/$kSaveCopies/${_leaf()}');
    final part = '${dir.path}/${_safe(name)}';
    await dir.create(recursive: true);
    await (copier ?? (a, b) => File(a).copy(b))(src, part);
    done = await cleanMediaFile(part, name: name, raw: raw);
    if (done.how == MediaClean.refused) {
      await shredTree(dir.path);
      return done;
    }
    moved = true;
    try {
      await File(part).rename(dest);
    } on FileSystemException {
      // another file system: copied over, then the private copy goes
      await File(part).copy(dest);
    }
  } catch (_) {
    try {
      if (dir != null) await shredTree(dir.path);
      if (moved && await File(dest).exists()) await shredFile(dest);
    } catch (_) {}
    return MediaCleaned(
      MediaClean.refused,
      video: videoNameNeedsStrip(name),
      io: true,
    );
  }
  // what is left in there is clean, and the start sweep takes it if this fails
  try {
    await shredTree(dir.path);
  } catch (_) {}
  return done;
}

/// a file made ready to send or keep: its copy at [path] under [name], or
/// no path when it cannot go (a video the cleaner refuses, a read that
/// fails; [video] says which)
typedef ReadyCopy = ({String? path, String name, bool video});

/// [src] copied to [dest] for a send or a note, under [name]. media is
/// cleaned on our copy (copyClean). a picture the cleaner cannot clean, a
/// [raw] one first of all, is drawn again as a clean jpeg (cleanJpegOf)
/// and goes as a .jpg; one that cannot be drawn goes as it is, never asked
/// about. a video that cannot be cleaned does not go
Future<ReadyCopy> copyForSend(
  String src,
  String dest, {
  required String name,
  bool raw = false,
  Directory? cache,
}) async {
  var io = false;
  if (!raw) {
    final done = await copyClean(src, dest, name: name, cache: cache);
    if (done.how != MediaClean.refused) {
      return (path: dest, name: name, video: false);
    }
    if (done.video) return (path: null, name: name, video: true);
    io = done.io;
  }
  final jpeg = await _drawnClean(src);
  if (jpeg != null) {
    final to = p.setExtension(dest, '.jpg');
    try {
      await File(to).writeAsBytes(jpeg, flush: true);
      return (path: to, name: p.setExtension(name, '.jpg'), video: false);
    } catch (_) {
      try {
        await shredFile(to);
      } catch (_) {}
    }
  }
  // a raw one the cleaner may still take part of, else as it is
  if (raw) {
    final done = await copyClean(
      src,
      dest,
      name: name,
      raw: true,
      cache: cache,
    );
    if (done.how != MediaClean.refused) {
      return (path: dest, name: name, video: false);
    }
    io = done.io;
  }
  // a clean the disk stopped is no picture the cleaner cannot read: it
  // would go with all it holds
  if (io) return (path: null, name: name, video: false);
  try {
    await File(src).copy(dest);
    return (path: dest, name: name, video: false);
  } catch (_) {
    try {
      await shredFile(dest);
    } catch (_) {}
    return (path: null, name: name, video: false);
  }
}

// the picture at [path] as a clean jpeg; null where it cannot be drawn. a
// computer has nothing to draw it with
Future<Uint8List?> _drawnClean(String path) async {
  if (onDesktop) return null;
  try {
    final f = File(path);
    if (await f.length() > kConvertMost) return null;
    return await cleanJpegOf(await f.readAsBytes());
  } catch (_) {
    return null;
  }
}

/// [bytes] written to [f] as a copy made ready to send. a write that fails,
/// a full phone say, leaves no part of it behind and says false
Future<bool> writeMadeCopy(File f, Uint8List bytes) async {
  try {
    await f.writeAsBytes(bytes, flush: true);
    return true;
  } catch (_) {
    try {
      if (await f.exists()) await shredFile(f.path);
    } catch (_) {}
    return false;
  }
}
