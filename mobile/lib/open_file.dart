// SPDX-License-Identifier: GPL-3.0-or-later
// opening a received file with another app, and what a video bubble needs
// to draw itself. both are the phone's own machinery behind one channel.
import 'package:flutter/services.dart';

const _channel = MethodChannel('halo/platform');

/// hands [path] to whichever app the person picks for that kind of file.
/// [name] is the name the sender gave it; ours on disk has a prefix. false
/// when nothing on the phone opens it, and the caller falls back to share.
Future<bool> openWithAnotherApp(String path, {String? name}) async {
  try {
    return await _channel.invokeMethod<bool>('openFile', {
          'path': path,
          'name': name,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

const _videoExts = {'mp4', 'm4v', 'mov', '3gp', '3g2', 'mkv', 'webm'};

/// a file the chat draws as a video. by the name alone, the way the file
/// card picks its icon; a name that lies gets a bubble with no picture and
/// still opens in whatever the phone offers.
bool nameSaysVideo(String? name) {
  if (name == null) return false;
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  return _videoExts.contains(name.substring(dot + 1).toLowerCase());
}

class VideoInfo {
  final Uint8List? jpeg; // one frame, null when the phone could not read one
  final Duration length;
  final int width;
  final int height;
  const VideoInfo(this.jpeg, this.length, this.width, this.height);
  double get aspect => height <= 0 ? 16 / 9 : width / height;
}

// frames live here and nowhere else: a thumbnail written to disk would
// still be there after the message burned. a few dozen small jpegs.
final Map<String, VideoInfo?> _infos = {};
final Map<String, Future<VideoInfo?>> _asking = {};

VideoInfo? videoInfoNow(String path) => _infos[path];

Future<VideoInfo?> videoInfoFor(String path) {
  if (_infos.containsKey(path)) return Future.value(_infos[path]);
  return _asking[path] ??= () async {
    VideoInfo? out;
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('videoInfo', {
        'path': path,
        'maxEdge': 640,
      });
      if (m != null) {
        out = VideoInfo(
          m['jpeg'] as Uint8List?,
          Duration(milliseconds: (m['ms'] as num?)?.toInt() ?? 0),
          (m['w'] as num?)?.toInt() ?? 16,
          (m['h'] as num?)?.toInt() ?? 9,
        );
      }
    } catch (_) {}
    if (_infos.length >= 40) _infos.remove(_infos.keys.first);
    _infos[path] = out;
    _asking.remove(path);
    return out;
  }();
}

String videoLength(Duration d) {
  final s = d.inSeconds;
  final m = s ~/ 60;
  final h = m ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${(m % 60).toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}
