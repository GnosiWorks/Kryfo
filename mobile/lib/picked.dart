// the pickers leave a copy of what was chosen in the app cache. once the
// bytes are in hand it is zeroed and removed, with the plugin's own folder.
// the recorder's take is moved where it is kept, or shredded.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show ImagePickerPlatform;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dlog.dart';
import 'image_strip.dart' show PictureKind, pictureKind;
import 'open_file.dart' show nameSaysVideo;
import 'shred.dart';
import 'voice_mask.dart' show maskWavFile;

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

const _platform = MethodChannel('halo/platform');

// a photo brought to what a gallery pick gets: 1280 on the long edge, jpeg
// 70, upright. decoded pixels carry no metadata. the bytes as they came when
// the platform cannot
Future<Uint8List> shrinkPhoto(Uint8List b) async {
  try {
    final r = await _platform.invokeMethod<Uint8List>('shrinkJpeg', {
      'bytes': b,
      'maxEdge': 1280,
      'quality': 70,
    });
    if (r != null && r.isNotEmpty) return r;
  } catch (e) {
    dlog('shrink: $e');
  }
  return b;
}

// the gallery's picks, asked for whole and shrunk here: the picker's own
// shrink writes cache/scaled_<name>, so two picks of one name came back as
// the last of them twice. a jpeg is shrunk; a png, gif, webp or heic keeps
// its own format, which the send lane cleans as it is; anything else is
// drawn again as a jpeg. what the picker left goes even when a read fails.
// [shrink] and [drop] stand in for the platform and the shred in tests
Future<List<Uint8List>> readPickedPhotos(
  List<XFile> picked, {
  Future<Uint8List> Function(Uint8List b)? shrink,
  Future<void> Function(List<XFile> x)? drop,
}) async {
  Future<Uint8List> fit(Uint8List b) async => switch (pictureKind(b)) {
    PictureKind.jpeg || PictureKind.other => (shrink ?? shrinkPhoto)(b),
    _ => b,
  };
  try {
    return [
      for (final path in {for (final x in picked) x.path})
        await fit(await File(path).readAsBytes()),
    ];
  } finally {
    await (drop ?? shredPickedImages)(picked);
  }
}

// android's photo picker: built in from 13, a system update on 11 and 12,
// google play on older phones. without it a mixed pick is the file browser
Future<bool> photoPickerReady() async {
  try {
    return await _platform.invokeMethod<bool>('photoPickerReady') ?? false;
  } catch (_) {
    return false;
  }
}

// the gallery tile: photos and videos in one sheet where the photo picker
// is, photos alone elsewhere, where videos keep their own tile
Future<List<XFile>> pickGallery({
  ImagePicker? picker,
  Future<bool> Function()? ready,
}) async {
  final p = picker ?? ImagePicker();
  if (!await (ready ?? photoPickerReady)()) return p.pickMultiImage();
  final android = ImagePickerPlatform.instance;
  if (android is! ImagePickerAndroid) return p.pickMultipleMedia();
  // read as the call goes out, so no other pick sees it
  final was = android.useAndroidPhotoPicker;
  android.useAndroidPhotoPicker = true;
  try {
    return p.pickMultipleMedia();
  } finally {
    android.useAndroidPhotoPicker = was;
  }
}

// the picker names its copy for the type it was given
bool isVideoPick(XFile x) =>
    nameSaysVideo(x.name) || (x.mimeType?.startsWith('video/') ?? false);

// a gallery pick sent in the order chosen. photos are read whole and shrunk
// as readPickedPhotos does; a video goes to [video] as the video tile's does
// and its copy is shredded once sent. [photo] hears whether it is the only
// pick. either returning false stops the rest, and what is left still goes
Future<void> sendGalleryPicks(
  List<XFile> picked, {
  required Future<bool> Function(Uint8List bytes, bool alone) photo,
  required Future<bool> Function(XFile video) video,
  Future<Uint8List> Function(Uint8List b)? shrink,
  Future<void> Function(List<XFile> x)? drop,
}) async {
  final shred = drop ?? shredPickedImages;
  final picks = {for (final x in picked) x.path: x}.values.toList();
  final videos = [
    for (final x in picks)
      if (isVideoPick(x)) x,
  ];
  try {
    final bytesOf = await readPickedPhotos(
      [
        for (final x in picks)
          if (!isVideoPick(x)) x,
      ],
      shrink: shrink,
      drop: drop,
    );
    final alone = picks.length == 1;
    var i = 0;
    for (final x in picks) {
      if (!isVideoPick(x)) {
        if (!await photo(bytesOf[i++], alone)) return;
        continue;
      }
      videos.remove(x);
      try {
        if (!await video(x)) return;
      } finally {
        await shred([x]);
      }
    }
  } finally {
    if (videos.isNotEmpty) await shred(videos);
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

/// a voice note put where it is kept, at [dest]: disguised when
/// [disguise], else as recorded. the recorder's own file at [take] is the
/// voice before any disguise: moved to [dest] when it goes as it is, else
/// shredded once the disguise is there. [masked] is a disguise of it made
/// already, moved to [dest] or shredded. never read whole. false, with
/// nothing at [dest], when there is no take or no disguise of it
Future<bool> placeVoice(
  String take,
  String dest, {
  required bool disguise,
  String? masked,
}) async {
  try {
    if (!disguise) {
      if (masked != null) await shredFile(masked);
      return await _moveFile(take, dest);
    }
    if (masked != null && await _moveFile(masked, dest)) return true;
    if (!await File(take).exists()) return false;
    return await maskWavFile(take, dest);
  } catch (e) {
    dlog('voice: not placed (${e.runtimeType})');
    await shredFile(dest);
    return false;
  } finally {
    if (masked != null) await shredFile(masked);
    await shredFile(take);
  }
}

/// a voice note that will not go: its take and any disguise made of it
/// shredded
Future<void> dropTake(String take, String? masked) async {
  if (masked != null) await shredFile(masked);
  await shredFile(take);
}

// [from] renamed to [to], or copied there and shredded where it was.
// false, with nothing at [to], when neither works
Future<bool> _moveFile(String from, String to) async {
  if (!await File(from).exists()) return false;
  try {
    await File(from).rename(to);
    return true;
  } on FileSystemException {
    // another file system: copied over
  }
  try {
    await File(from).openRead().pipe(File(to).openWrite());
    return true;
  } catch (e) {
    dlog('voice: not copied (${e.runtimeType})');
    await shredFile(to);
    return false;
  } finally {
    await shredFile(from);
  }
}
