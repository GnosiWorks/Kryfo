// SPDX-License-Identifier: GPL-3.0-or-later
// the one cleaner every lane that sends or saves a file goes through: a
// picture or a video, told by its bytes (a video by its name too), cleaned
// in place on our own copy and then read again. what still reads as
// anything is refused, never passed on half clean. anything else is not
// media and is left exactly as it is.
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';

import 'file_kind.dart' show bytesSayIsoVideo;
import 'image_strip.dart';
import 'meta/file_source.dart';
import 'meta/meta_reader.dart';
import 'mp4_strip.dart';
import 'shred.dart';

enum MediaClean { clean, notMedia, refused }

class MediaCleaned {
  final MediaClean how;

  /// a video, for the line a refusal shows
  final bool video;
  const MediaCleaned(this.how, {this.video = false});
}

/// cleans [path] in place, off the ui thread. [name] is what the file was
/// called; a [raw] picture is never walked as a video
Future<MediaCleaned> cleanMediaFile(
  String path, {
  String name = '',
  bool raw = false,
}) async {
  try {
    return await Isolate.run(
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
    return MediaCleaned(MediaClean.refused, video: videoNameNeedsStrip(name));
  }
  // what is left in there is clean, and the start sweep takes it if this fails
  try {
    await shredTree(dir.path);
  } catch (_) {}
  return done;
}
