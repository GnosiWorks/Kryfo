// SPDX-License-Identifier: GPL-3.0-or-later
// iso base media boxes (mp4, mov, 3gp, heif, avif), read through a
// ByteSource. shared by the reader and the cleaners so both walk a file the
// same way and agree on what is in it.
import 'dart:convert';
import 'dart:typed_data';

import 'byte_source.dart';

/// a file that cannot be walked: a size past its parent, a table cut short
class IsoError implements Exception {
  final String why;
  const IsoError(this.why);
  @override
  String toString() => why;
}

class IsoBox {
  final String type;
  final int start; // of the header
  final int body; // of the payload
  final int end;
  const IsoBox(this.type, this.start, this.body, this.end);
  int get size => end - start;
  int get bodySize => end - body;
}

const kMaxBoxes = 200000;

String fourcc(Uint8List b, int i) => latin1.decode(b.sublist(i, i + 4));
int be16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];
int be32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
int be64(Uint8List b, int i) {
  final hi = be32(b, i);
  if (hi > 0x7fff) throw const IsoError('offset too large');
  return (hi << 32) | be32(b, i + 4);
}

/// the boxes between [from] and [to]. [count] is shared across one walk so a
/// file of a million tiny boxes stops early.
List<IsoBox> isoBoxes(ByteSource s, int from, int to, List<int> count) {
  final out = <IsoBox>[];
  var i = from;
  while (i < to) {
    if (++count[0] > kMaxBoxes) throw const IsoError('too many boxes');
    if (i + 8 > to) throw const IsoError('box header cut short');
    final h = s.read(i, 8);
    var size = be32(h, 0);
    final type = fourcc(h, 4);
    var head = 8;
    if (size == 1) {
      if (i + 16 > to) throw const IsoError('box header cut short');
      size = be64(s.read(i + 8, 8), 0);
      head = 16;
    } else if (size == 0) {
      size = to - i;
    }
    if (size < head || i + size > to) {
      throw const IsoError('box runs past its parent');
    }
    out.add(IsoBox(type, i, i + head, i + size));
    i += size;
  }
  return out;
}

/// the payload of [b], refused past [max] so a lying size cannot ask for
/// gigabytes
Uint8List isoPayload(ByteSource s, IsoBox b, {int max = 16 << 20}) {
  if (b.bodySize > max) throw const IsoError('box too large to read');
  return s.read(b.body, b.bodySize);
}

IsoBox? firstOf(List<IsoBox> boxes, String type) {
  for (final b in boxes) {
    if (b.type == type) return b;
  }
  return null;
}

/// byte ranges, kept sorted and merged
class Ranges {
  final List<int> _a = [];
  final List<int> _b = [];
  bool _sorted = true;

  void add(int from, int to) {
    if (to <= from) return;
    if (_a.isNotEmpty && from < _a.last) _sorted = false;
    _a.add(from);
    _b.add(to);
  }

  void addAll(Ranges o) {
    for (var k = 0; k < o._a.length; k++) {
      add(o._a[k], o._b[k]);
    }
  }

  /// merged, in order
  List<(int, int)> get merged {
    final idx = List<int>.generate(_a.length, (i) => i);
    if (!_sorted) idx.sort((x, y) => _a[x].compareTo(_a[y]));
    final out = <(int, int)>[];
    for (final k in idx) {
      final a = _a[k], b = _b[k];
      if (out.isNotEmpty && a <= out.last.$2) {
        if (b > out.last.$2) out[out.length - 1] = (out.last.$1, b);
      } else {
        out.add((a, b));
      }
    }
    return out;
  }

  bool get isEmpty => _a.isEmpty;

  /// the parts of [from]..[to] no range covers
  static List<(int, int)> gaps(List<(int, int)> merged, int from, int to) {
    final out = <(int, int)>[];
    var at = from;
    for (final (a, b) in merged) {
      if (b <= at) continue;
      if (a >= to) break;
      if (a > at) out.add((at, a));
      if (b > at) at = b;
      if (at >= to) break;
    }
    if (at < to) out.add((at, to));
    return out;
  }
}

/// true when [len] bytes at [at] hold anything but zeros, read in pieces
bool nonZero(ByteSource s, int at, int len) {
  const step = 64 * 1024;
  while (len > 0) {
    final n = len < step ? len : step;
    final b = s.read(at, n);
    for (final x in b) {
      if (x != 0) return true;
    }
    at += n;
    len -= n;
  }
  return false;
}
