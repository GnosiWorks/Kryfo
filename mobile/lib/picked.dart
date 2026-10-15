// the pickers leave a copy of what was chosen in the app cache. once the
// bytes are in hand it is zeroed and removed, with the plugin's own folder.
// the recorder's take goes the same way.
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

/// one item for the send preview, in the order picked: a photo's bytes,
/// read whole and shrunk, or a video's picker copy, left where it is until
/// the preview is done with it
class PickedMedia {
  final Uint8List? photo;
  final XFile? video;
  const PickedMedia.photo(Uint8List this.photo) : video = null;
  const PickedMedia.video(XFile this.video) : photo = null;
  bool get isVideo => video != null;
}

/// the gallery's picks for the preview, in the order chosen. photos are
/// read and shrunk as readPickedPhotos does, their copies gone at once;
/// a video's copy stays for the send, and goes with shredPickedImages
Future<List<PickedMedia>> readGalleryPicks(
  List<XFile> picked, {
  Future<Uint8List> Function(Uint8List b)? shrink,
  Future<void> Function(List<XFile> x)? drop,
}) async {
  final picks = {for (final x in picked) x.path: x}.values.toList();
  final photos = await readPickedPhotos(
    [
      for (final x in picks)
        if (!isVideoPick(x)) x,
    ],
    shrink: shrink,
    drop: drop,
  );
  var i = 0;
  return [
    for (final x in picks)
      isVideoPick(x) ? PickedMedia.video(x) : PickedMedia.photo(photos[i++]),
  ];
}

/// what the send preview gives back: the items in their order, the
/// caption for the first, and whether they open protected
class MediaSendResult {
  final List<PickedMedia> items;
  final String caption;
  final bool secure;
  const MediaSendResult({
    required this.items,
    this.caption = '',
    this.secure = false,
  });
}

// a gallery pick, through the send preview. [preview] shows what was read
// and gives back what to send, null when the person backed out; its second
// argument reopens the picker ([pickMore]) for more. [send] sends it. every
// video copy read along the way goes once it is done with, sent or not.
// [shrink] and [drop] stand in for the platform and the shred in tests
Future<void> sendGalleryPicks(
  List<XFile> picked, {
  required Future<MediaSendResult?> Function(
    List<PickedMedia> items,
    Future<List<PickedMedia>> Function() more,
  )
  preview,
  required Future<void> Function(MediaSendResult r) send,
  Future<List<XFile>> Function()? pickMore,
  Future<Uint8List> Function(Uint8List b)? shrink,
  Future<void> Function(List<XFile> x)? drop,
}) async {
  final shred = drop ?? shredPickedImages;
  final videos = <XFile>[];
  Future<List<PickedMedia>> read(List<XFile> x) async {
    if (x.isEmpty) return const [];
    final got = await readGalleryPicks(x, shrink: shrink, drop: drop);
    videos.addAll([for (final m in got) ?m.video]);
    return got;
  }

  try {
    final first = await read(picked);
    if (first.isEmpty) return;
    final r = await preview(
      first,
      () async => read(await pickMore?.call() ?? const []),
    );
    if (r == null || r.items.isEmpty) return;
    await send(r);
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
