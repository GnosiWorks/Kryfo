// SPDX-License-Identifier: GPL-3.0-or-later
// room for a transcription. a run holds ~150 MB (the model and whisper's
// buffers: +145 MB rss on the a12) and keeps the cores busy for a while.
// on a phone already short of memory android then kills apps to make room,
// and the app in front goes last but does go (the a12 killed kryfo with a
// 60 s note on 2026-11-11). so a run starts only with room to spare and
// stops itself before the phone runs out. fewer threads would not help: the
// memory is the model's whatever the threads, and with half the cores free
// the kernel has the cpu to reclaim (2 threads at 574 MB free took 17 s for
// a 10 s note, with no memory pressure at all). where there is no
// /proc/meminfo (windows) nothing is checked.
import 'dart:io' show File;
import 'dart:math' show max;

/// memory the system can hand out now and all it has, in bytes
class MemRoom {
  const MemRoom(this.free, this.total);
  final int free;
  final int total;
}

/// what a run takes while it holds the model, in bytes
const kVoiceRunBytes = 160 << 20;

/// the room a run leaves to the system: below it android kills apps, ours too
int memReserve(int total) => max(256 << 20, total ~/ 10);

/// whether a run fits in [room] and still leaves the reserve. null room:
/// nothing to go by, it runs
bool voiceRunFits(MemRoom? room) =>
    room == null || room.free - kVoiceRunBytes >= memReserve(room.total);

/// a run under way stops when free memory is under the reserve
bool memRunOut(MemRoom? room) =>
    room != null && room.free < memReserve(room.total);

/// the room now, null when it cannot be read
MemRoom? readMemRoom({String path = '/proc/meminfo'}) {
  try {
    return parseMemInfo(File(path).readAsStringSync());
  } catch (_) {
    return null;
  }
}

/// MemAvailable and MemTotal of a /proc/meminfo; null without them
MemRoom? parseMemInfo(String s) {
  int? avail;
  int? total;
  for (final line in s.split('\n')) {
    final m = _row.firstMatch(line);
    if (m == null) continue;
    final kb = int.parse(m.group(2)!);
    if (m.group(1) == 'MemAvailable') avail = kb << 10;
    if (m.group(1) == 'MemTotal') total = kb << 10;
  }
  if (avail == null || total == null || total <= 0) return null;
  return MemRoom(avail, total);
}

final _row = RegExp(r'^(MemAvailable|MemTotal):\s+(\d+) kB');
