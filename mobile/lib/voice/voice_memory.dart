// SPDX-License-Identifier: GPL-3.0-or-later
// room for a transcription. a run holds ~150 MB (the model and whisper's
// buffers: +145 MB rss on the a12) and keeps the cores busy for a while.
// on a phone already short of memory android then kills apps to make room,
// and the app in front goes last but does go (the a12 killed kryfo with a
// 60 s note on 2026-11-11). so a run starts only with room to spare, takes
// half the threads when room is tight, and stops itself before the phone
// runs out. where there is no /proc/meminfo (windows) nothing is checked.
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

/// threads for a run with [room]: all of [threads] with room to spare,
/// half (2 at least) when it is tight, 0 when a run would not fit now.
/// null room: nothing to go by, all of them
int voiceRunThreads(int threads, MemRoom? room) {
  if (room == null) return threads;
  final spare = room.free - memReserve(room.total) - kVoiceRunBytes;
  if (spare < 0) return 0;
  if (spare < kVoiceRunBytes) return max(2, threads ~/ 2);
  return threads;
}

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
