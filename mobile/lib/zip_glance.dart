// SPDX-License-Identifier: GPL-3.0-or-later
// what a zip holds, read from its central directory only: nothing is ever
// unpacked. the sender reads its own file and puts a small summary in the
// message under 'zg'; the one it comes to draws that before any download,
// and may read the real file the same way once it is here. both ends are
// capped, and the summary that comes is untrusted: every field is bounded
// and every name is only ever shown, never used as a path
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// the most entries read, and the most of the directory read
const kZipMostEntries = 2000;
const kZipMostDirBytes = 256 * 1024;

/// the most a summary shows of a name, and its rows
const kZipNameMost = 40;
const kZipRowsMost = 4;

// bounds on what a summary may say
const _countMost = 10000000;
const _bytesMost = 1 << 50;

const kZipGlanceWire = 'zg';

/// a file's or a folder's line in the glance: a folder has how many files
/// it holds, a file -1
class ZipTop {
  final String name;
  final int files;
  const ZipTop(this.name, this.files);
  bool get folder => files >= 0;

  @override
  bool operator ==(Object other) =>
      other is ZipTop && other.name == name && other.files == files;
  @override
  int get hashCode => Object.hash(name, files);
  @override
  String toString() => 'ZipTop($name, $files)';
}

class ZipGlance {
  // its files, folders not counted
  final int count;
  // what they come to unpacked, when every entry was read
  final int? unpacked;
  final List<ZipTop> top;
  // a password guards some of it
  final bool locked;
  const ZipGlance({
    required this.count,
    required this.top,
    this.unpacked,
    this.locked = false,
  });

  /// the files not in the rows shown
  int get more {
    var shown = 0;
    for (final t in top) {
      shown += t.folder ? t.files : 1;
    }
    return math.max(0, count - shown);
  }

  Map<String, Object> toWire() => {
    'n': count,
    'u': ?unpacked,
    't': [
      for (final t in top) [t.name, t.files],
    ],
    if (locked) 'p': 1,
  };

  /// null for anything that is not a sane summary. bounded field by field
  static ZipGlance? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final n = raw['n'];
    if (n is! int || n < 0 || n > _countMost) return null;
    final u = raw['u'];
    final int? unpacked = u is int && u >= 0 && u <= _bytesMost ? u : null;
    final t = raw['t'];
    if (t is! List) return null;
    final top = <ZipTop>[];
    for (final row in t.take(kZipRowsMost)) {
      if (row is! List || row.length != 2) continue;
      final name = row[0];
      final files = row[1];
      if (name is! String || files is! int) continue;
      if (files < -1 || files > _countMost) continue;
      // a top-level name only: whatever path it carries is cut to its
      // first real part, and that is only ever shown
      final shown = _topOf(name);
      if (shown == null) continue;
      top.add(ZipTop(shown, files));
    }
    return ZipGlance(
      count: n,
      unpacked: unpacked,
      top: top,
      locked: raw['p'] == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ZipGlance &&
      other.count == count &&
      other.unpacked == unpacked &&
      other.locked == locked &&
      listEquals(other.top, top);
  @override
  int get hashCode => Object.hash(count, unpacked, locked, Object.hashAll(top));
}

/// true for a name the glance reads: .zip only for now
bool zipGlanced(String? name) =>
    name != null && name.toLowerCase().endsWith('.zip');

// controls, direction marks and overrides, and the line breaks of other
// scripts: none is shown
final _unshown = RegExp(
  '[\u0000-\u001f\u007f-\u009f\u061c\u200b-\u200f\u2028-\u202e\u2060-\u2069\ufeff\ufff9-\ufffb]',
);

// the first part of [name] that is a name: never empty, '.' or '..'
String? _topOf(String name) {
  for (final p in name.split(RegExp(r'[/\\]'))) {
    final s = zipShownName(p);
    if (s.isNotEmpty && s != '.' && s != '..') return s;
  }
  return null;
}

/// [name] as a glance shows it: no controls, no direction marks, one line,
/// at most [kZipNameMost] characters
String zipShownName(String name) {
  var s = name.replaceAll(_unshown, '').trim();
  final r = s.runes.toList();
  if (r.length > kZipNameMost) {
    s = '${String.fromCharCodes(r.take(kZipNameMost - 1))}\u2026';
  }
  return s;
}

int _u16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);
int _u32(Uint8List b, int o) => _u16(b, o) | (_u16(b, o + 2) << 16);
int _u64(Uint8List b, int o) {
  final lo = _u32(b, o);
  final hi = _u32(b, o + 4);
  // past 2^50 nothing real: clamped, never wrapped
  if (hi >= (1 << 18)) return _bytesMost;
  return hi * 0x100000000 + lo;
}

/// reads [len] bytes at [off] of the file, fewer at its end
typedef ZipRead = Future<Uint8List> Function(int off, int len);

/// the glance of a zip [length] bytes long, read through [read] in at most
/// three short reads. null for anything that is no zip this reader trusts
Future<ZipGlance?> zipGlanceRead(int length, ZipRead read) async {
  if (length < 22) return null;
  // the end record sits in the last 22 + 65535 bytes
  final tailLen = math.min(length, 22 + 0xffff);
  final tailAt = length - tailLen;
  final tail = await read(tailAt, tailLen);
  if (tail.length != tailLen) return null;
  var e = -1;
  for (var i = tail.length - 22; i >= 0; i--) {
    if (tail[i] == 0x50 &&
        tail[i + 1] == 0x4b &&
        tail[i + 2] == 0x05 &&
        tail[i + 3] == 0x06) {
      e = i;
      break;
    }
  }
  if (e < 0) return null;
  var entries = _u16(tail, e + 10);
  var dirSize = _u32(tail, e + 12);
  var dirAt = _u32(tail, e + 16);
  final endAt = tailAt + e;
  // zip64: the real numbers are in the zip64 end record its locator names
  if (entries == 0xffff || dirSize == 0xffffffff || dirAt == 0xffffffff) {
    if (e < 20) return null;
    final l = e - 20;
    if (_u32(tail, l) != 0x07064b50) return null;
    final recAt = _u64(tail, l + 8);
    if (recAt < 0 || recAt + 56 > endAt) return null;
    final rec = await read(recAt, 56);
    if (rec.length != 56 || _u32(rec, 0) != 0x06064b50) return null;
    entries = math.min(_u64(rec, 32), _countMost);
    dirSize = _u64(rec, 40);
    dirAt = _u64(rec, 48);
  }
  // the directory lies before its end record, whole
  if (dirAt < 0 || dirSize < 0 || dirAt + dirSize > endAt) return null;
  final take = math.min(dirSize, kZipMostDirBytes);
  final dir = await read(dirAt, take);
  if (dir.length != take) return null;

  var o = 0;
  var read0 = 0;
  var files = 0;
  var bytes = 0;
  var locked = false;
  final folders = <String, int>{};
  final order = <String>[];
  final plain = <String>{};
  while (read0 < kZipMostEntries && o + 46 <= dir.length) {
    if (_u32(dir, o) != 0x02014b50) break;
    final flags = _u16(dir, o + 8);
    var size = _u32(dir, o + 24);
    final nameLen = _u16(dir, o + 28);
    final extraLen = _u16(dir, o + 30);
    final noteLen = _u16(dir, o + 32);
    final next = o + 46 + nameLen + extraLen + noteLen;
    if (next > dir.length) break;
    final raw = dir.sublist(o + 46, o + 46 + nameLen);
    // zip64: the size in its extra field
    if (size == 0xffffffff) {
      size = 0;
      var x = o + 46 + nameLen;
      final xEnd = x + extraLen;
      while (x + 4 <= xEnd) {
        final id = _u16(dir, x);
        final len = _u16(dir, x + 2);
        if (x + 4 + len > xEnd) break;
        if (id == 0x0001 && len >= 8) size = _u64(dir, x + 4);
        x += 4 + len;
      }
    }
    o = next;
    read0++;
    if (flags & 1 != 0) locked = true;
    final name = utf8.decode(raw, allowMalformed: true);
    // display only: no part of it is ever a way up or out
    final parts = [
      for (final p in name.split(RegExp(r'[/\\]')))
        if (zipShownName(p) case final s
            when s.isNotEmpty && s != '.' && s != '..')
          s,
    ];
    if (parts.isEmpty) continue;
    final dirEntry = name.endsWith('/') || name.endsWith('\\');
    if (!dirEntry) {
      files++;
      bytes = math.min(_bytesMost, bytes + math.max(0, size));
    }
    if (parts.length == 1 && !dirEntry) {
      final k = parts.first;
      if (plain.add(k) && !folders.containsKey(k)) order.add(k);
      continue;
    }
    final k = parts.first;
    if (!folders.containsKey(k)) {
      folders[k] = 0;
      if (!plain.contains(k)) order.add(k);
    }
    if (!dirEntry) folders[k] = folders[k]! + 1;
  }
  if (read0 == 0 && entries != 0) return null;
  // every entry read: the count and the size are whole
  final whole = read0 >= entries && take == dirSize;
  return ZipGlance(
    count: whole ? files : math.min(math.max(files, entries), _countMost),
    unpacked: whole ? bytes : null,
    // folders first, then files, each in name order
    top: [
      for (final k
          in (order.toList()..sort((x, y) {
                final fx = folders.containsKey(x), fy = folders.containsKey(y);
                if (fx != fy) return fx ? -1 : 1;
                return x.toLowerCase().compareTo(y.toLowerCase());
              }))
              .take(kZipRowsMost))
        ZipTop(zipShownName(k), folders[k] ?? -1),
    ],
    locked: locked,
  );
}

/// the glance of the zip in [bytes], for tests and small files
Future<ZipGlance?> zipGlanceOfBytes(Uint8List bytes) => zipGlanceRead(
  bytes.length,
  (off, len) async {
    if (off < 0 || off >= bytes.length || len <= 0) return Uint8List(0);
    return Uint8List.sublistView(bytes, off, math.min(bytes.length, off + len));
  },
);

/// the glance of the zip at [path]; null when it is none or cannot be read
Future<ZipGlance?> zipGlanceOf(String path) async {
  try {
    final f = File(path);
    final length = await f.length();
    return await zipGlanceRead(length, (off, len) async {
      if (off < 0 || len <= 0 || off >= length) return Uint8List(0);
      final b = BytesBuilder(copy: false);
      await for (final c in f.openRead(off, math.min(length, off + len))) {
        b.add(c);
      }
      return b.takeBytes();
    });
  } catch (_) {
    return null;
  }
}
