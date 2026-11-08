// SPDX-License-Identifier: GPL-3.0-or-later
// photos, videos and files shared from another app, once a chat was
// picked for them: kryfo's own copies in the tools folder, waiting for that
// chat to take them into its send preview. a lock, or a newer share, lets
// them go; a chat that takes them shreds them once they went its own way
import 'package:path/path.dart' as p;

import 'lock_state.dart';
import 'shred.dart';
import 'tools/tools_bridge.dart' show PickedFile;

enum SharedKind { photo, video, file }

/// how a shared item goes: a photo or a video through the send preview,
/// anything else as a file. the type the sharing app gave counts first
SharedKind sharedKindOf(String? mime, String? name) {
  final m = (mime ?? '').split(';').first.trim().toLowerCase();
  if (m.startsWith('video/')) return SharedKind.video;
  // a drawing in xml is no photo
  if (m.startsWith('image/') && !m.contains('svg')) return SharedKind.photo;
  if (m.isEmpty || m == 'application/octet-stream') {
    final ext = p.extension(name ?? '').toLowerCase();
    if (_videoExts.contains(ext)) return SharedKind.video;
    if (_photoExts.contains(ext)) return SharedKind.photo;
  }
  return SharedKind.file;
}

const _videoExts = {'.mp4', '.m4v', '.mov', '.3gp', '.webm', '.mkv'};
const _photoExts = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'};

SharedKind kindOfPicked(PickedFile f) => sharedKindOf(f.mime, f.name);

/// the shared items over [most] bytes, and those that may be copied. a
/// size the sharing app did not say is found out while copying
({List<PickedFile> fit, PickedFile? over}) sortBySize(
  List<PickedFile> items,
  int most,
) {
  final fit = <PickedFile>[];
  PickedFile? over;
  for (final f in items) {
    if (f.size > most) {
      over ??= f;
    } else {
      fit.add(f);
    }
  }
  return (fit: fit, over: over);
}

class SharedCopy {
  final String path;
  final String name;
  final String? mime;
  const SharedCopy(this.path, {required this.name, this.mime});

  SharedKind get kind => sharedKindOf(mime, name);
}

/// [copies] gone with the folder each was copied into. only the tools
/// folder's own: a path that is not one is never touched
Future<void> shredCopies(Iterable<SharedCopy> copies) async {
  for (final c in copies) {
    final dir = p.dirname(c.path);
    if (p.basename(p.dirname(dir)) != 'tools_in') continue;
    try {
      await shredTree(dir);
    } catch (_) {
      // the sweep takes what will not go now
    }
  }
}

/// copies handed to a chat, by container and chat id
class SharedInbox {
  static final _waiting = <String, List<SharedCopy>>{};
  static bool _watching = false;

  /// [copies] wait for [key]'s chat. one share at a time: what waited for
  /// another chat goes
  static void handOff(String key, List<SharedCopy> copies) {
    if (!_watching) {
      _watching = true;
      lockState.addListener(_onLock);
    }
    for (final k in _waiting.keys.toList()) {
      if (k != key) shredCopies(_waiting.remove(k)!);
    }
    _waiting[key] = [...?_waiting[key], ...copies];
  }

  static List<SharedCopy> take(String key) => _waiting.remove(key) ?? const [];

  static bool waits(String key) => _waiting.containsKey(key);

  static Future<void> dropAll() async {
    final all = [for (final l in _waiting.values) ...l];
    _waiting.clear();
    await shredCopies(all);
  }

  static void _onLock() {
    if (lockState.locked) dropAll();
  }
}
