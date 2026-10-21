// SPDX-License-Identifier: GPL-3.0-or-later
// opening a received file with another app, and what a video bubble needs
// to draw itself. both are the phone's own machinery behind one channel.
// an app installer is never handed to another app, here or natively
import 'package:flutter/services.dart';
import 'dlog.dart';
import 'file_kind.dart';
import 'l10n/numbers.dart';

const _channel = MethodChannel('halo/platform');

/// whether what is shared now is from a hidden chat or the decoy: its copy
/// then goes with the next lock or switch of pin. the app sets it
bool Function() shareGoesWithLock = () => false;

enum OpenAnswer { opened, nothing, refused }

/// hands [path] to whichever app the person picks for that kind of file.
/// [name] is the name the sender gave it; ours on disk has a prefix.
/// nothing: no app on the phone opens it, and the caller falls back to
/// share. refused: an app installer, which only ever goes to a save
Future<OpenAnswer> openWithAnotherApp(String path, {String? name}) async {
  final facts = await readFileFacts(path, name);
  if (facts.installer) return OpenAnswer.refused;
  try {
    final r = await _channel.invokeMethod<Object?>('openFile', {
      'path': path,
      'name': safeFileName(name, facts: facts),
      'mime': facts.mime,
    });
    if (r == true) return OpenAnswer.opened;
    if (r == 'refused') return OpenAnswer.refused;
    return OpenAnswer.nothing;
  } catch (_) {
    return OpenAnswer.nothing;
  }
}

/// how a share sheet ended. [picked] says only that an app was chosen,
/// not that the file reached anyone
enum ShareEnd { picked, closed, failed }

/// the platform's answer: anything unknown is a sheet that did not open
ShareEnd shareEndOf(Object? answer) => switch (answer) {
  'picked' => ShareEnd.picked,
  'closed' => ShareEnd.closed,
  _ => ShareEnd.failed,
};

/// the share sheet with a copy of [path] the app keeps and shreds itself,
/// not the share plugin's, which goes unzeroed at the next share. answers
/// once the sheet is over: failed when the copy was not made or the sheet
/// did not open, and always for an app installer. a [backup] is
/// ciphertext, kept until the next one or a day. a [quiet] copy goes with
/// the next lock, wherever it was shared from
Future<ShareEnd> shareFileOut(
  String path, {
  String? name,
  String? text,
  String? subject,
  bool backup = false,
  bool quiet = false,
}) async {
  var shown = name;
  if (!backup) {
    final facts = await readFileFacts(path, name);
    if (facts.installer) return ShareEnd.failed;
    if (name != null) shown = safeFileName(name, facts: facts);
  }
  try {
    return shareEndOf(
      await _channel.invokeMethod<Object>('shareFile', {
        'path': path,
        'name': shown,
        'text': text,
        'subject': subject,
        'backup': backup,
        'quiet': !backup && (quiet || shareGoesWithLock()),
      }),
    );
  } catch (e) {
    dlog('share: ${e.runtimeType}');
    return ShareEnd.failed;
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

// asked for, then shredded before the answer: the answer is not kept
final Set<String> _gone = {};

/// the frame of a file that is going, out of memory now
void forgetVideoInfo(String path) {
  _infos.remove(path);
  if (_asking.containsKey(path)) _gone.add(path);
}

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
    } catch (e) {
      dlog('video info: ${e.runtimeType}');
    }
    if (!_gone.remove(path)) {
      if (_infos.length >= 40) _infos.remove(_infos.keys.first);
      _infos[path] = out;
    }
    _asking.remove(path);
    return out;
  }();
}

String videoLength(Duration d) {
  final s = d.inSeconds;
  final m = s ~/ 60;
  final h = m ~/ 60;
  // the language's digits: ۰:۰۵ in persian
  final ss = twoDigits(s % 60);
  if (h > 0) return '${whole(h)}:${twoDigits(m % 60)}:$ss';
  return '${whole(m)}:$ss';
}
