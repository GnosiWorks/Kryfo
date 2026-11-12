// SPDX-License-Identifier: GPL-3.0-or-later
// room for a transcription. a run holds ~150 MB (the model and whisper's
// buffers) and keeps the cores busy for a while. on a phone short of memory
// android then kills apps to make room, the one in front last. so a run
// starts only with room to spare and stops itself before the phone runs
// out. fewer threads would not help: the memory is the model's whatever the
// threads, and with half the cores free the kernel has the cpu to reclaim.
// where there is no /proc/meminfo (windows) nothing is checked.
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

/// the room a run leaves to the system: below it android kills apps, ours
/// too. a tenth of the phone, 256 to 768 MB: a 12 GB phone does not need 1.2
int memReserve(int total) => (total ~/ 10).clamp(256 << 20, 768 << 20);

/// whether a run fits in [room] and still leaves the reserve. null room:
/// nothing to go by, it runs
bool voiceRunFits(MemRoom? room) =>
    room == null || room.free - kVoiceRunBytes >= memReserve(room.total);

/// a run under way stops below this: lower than the start rule leaves, so
/// a run that started with just enough room is not stopped for using it
int memFloor(int total) => max(192 << 20, memReserve(total) * 3 ~/ 4);

/// this many low readings in a row stop a run: one dip is not running out
const kLowReadings = 3;

/// free memory is under the floor
bool memRunOut(MemRoom? room) =>
    room != null && room.free < memFloor(room.total);

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
