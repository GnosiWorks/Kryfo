// SPDX-License-Identifier: GPL-3.0-or-later
// how long a voice note is: what its file holds, from the first sample the
// mic wrote, shown to the nearest second wherever it shows
import 'dart:io';
import 'dart:typed_data';

import 'l10n/numbers.dart';

/// m:ss, or h:mm:ss from an hour, rounded to the nearest second
String voiceClock(int ms) {
  final s = (ms < 0 ? 0 : ms + 500) ~/ 1000;
  final m = s ~/ 60, h = m ~/ 60;
  final ss = twoDigits(s % 60);
  if (h > 0) return '${whole(h)}:${twoDigits(m % 60)}:$ss';
  return '${whole(m)}:$ss';
}

/// how long a pcm wav plays, from its head, or null for anything else.
/// [size] is the whole file's, for a data length never written
int? wavMs(Uint8List b, [int? size]) {
  if (b.length < 12) return null;
  final d = ByteData.sublistView(b);
  String tag(int at) => String.fromCharCodes(b.sublist(at, at + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
  final total = size ?? b.length;
  var at = 12;
  int? bits, rate;
  var channels = 0;
  while (at + 8 <= b.length) {
    final id = tag(at);
    final len = d.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ' && body + 16 <= b.length) {
      final format = d.getUint16(body, Endian.little);
      if (format != 1 && format != 0xFFFE) return null;
      channels = d.getUint16(body + 2, Endian.little);
      rate = d.getUint32(body + 4, Endian.little);
      bits = d.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (bits == null || bits < 8 || bits % 8 != 0) return null;
      if (channels < 1 || rate == null || rate < 1) return null;
      // a length written before the end says nothing, or too much: the
      // rest of the file is the samples
      final n = len == 0 || body + len > total ? total - body : len;
      final frames = n ~/ (bits ~/ 8 * channels);
      return frames * 1000 ~/ rate;
    }
    at = body + len + (len & 1);
  }
  return null;
}

/// [wavMs] of a file, read from its first few kilobytes
Future<int?> wavFileMs(String path) async {
  RandomAccessFile? f;
  try {
    f = await File(path).open();
    final size = await f.length();
    final head = await f.read(4096);
    return wavMs(head, size);
  } catch (_) {
    return null;
  } finally {
    await f?.close();
  }
}

/// the recorder's file has samples in it: its head alone is 44 bytes
bool samplesIn(String path) {
  try {
    return File(path).lengthSync() > 44;
  } catch (_) {
    return false;
  }
}
