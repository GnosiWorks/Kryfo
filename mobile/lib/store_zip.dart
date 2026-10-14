// SPDX-License-Identifier: GPL-3.0-or-later
// a zip of stored entries, written straight to a file. photos and voice notes
// are packed already, so nothing is compressed. no zip64: an export that
// would need it is refused
import 'dart:io';
import 'dart:typed_data';

class ZipTooLarge implements Exception {
  const ZipTooLarge();
}

class ZipStopped implements Exception {
  const ZipStopped();
}

final Uint32List _table = () {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();

int _crc(int crc, List<int> data, int len) {
  var c = crc ^ 0xFFFFFFFF;
  for (var i = 0; i < len; i++) {
    c = _table[(c ^ data[i]) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

const _max32 = 0xFFFFFFFF;

class StoreZip {
  StoreZip._(this._out, this._time, this._date);

  final RandomAccessFile _out;
  final int _time;
  final int _date;
  final _central = BytesBuilder();
  var _count = 0;

  // every entry carries [at] as its time
  static Future<StoreZip> create(String path, DateTime at) async {
    final out = await File(path).open(mode: FileMode.writeOnly);
    final y = at.year < 1980 ? 1980 : at.year;
    return StoreZip._(
      out,
      (at.hour << 11) | (at.minute << 5) | (at.second ~/ 2),
      ((y - 1980) << 9) | (at.month << 5) | at.day,
    );
  }

  Future<void> addBytes(String name, List<int> data) async {
    final at = await _head(name);
    await _out.writeFrom(data);
    await _seal(name, at, _crc(0, data, data.length), data.length);
  }

  // [stopped] is asked between blocks; [moved] hears each block's length
  Future<void> addFile(
    String name,
    File from, {
    bool Function()? stopped,
    void Function(int n)? moved,
  }) async {
    final at = await _head(name);
    final src = await from.open();
    var crc = 0, size = 0;
    final buf = Uint8List(256 * 1024);
    try {
      while (true) {
        if (stopped?.call() ?? false) throw const ZipStopped();
        final n = await src.readInto(buf);
        if (n == 0) break;
        crc = _crc(crc, buf, n);
        size += n;
        if (size > _max32) throw const ZipTooLarge();
        await _out.writeFrom(buf, 0, n);
        moved?.call(n);
      }
    } finally {
      await src.close();
    }
    await _seal(name, at, crc, size);
  }

  Future<void> close() async {
    try {
      final cd = await _out.position();
      final dir = _central.takeBytes();
      if (cd > _max32 || _count > 0xFFFF) throw const ZipTooLarge();
      await _out.writeFrom(dir);
      final end = ByteData(22)
        ..setUint32(0, 0x06054b50, Endian.little)
        ..setUint16(8, _count, Endian.little)
        ..setUint16(10, _count, Endian.little)
        ..setUint32(12, dir.length, Endian.little)
        ..setUint32(16, cd, Endian.little);
      await _out.writeFrom(end.buffer.asUint8List());
      await _out.flush();
    } finally {
      await _out.close();
    }
  }

  // the local header with its sizes left at zero until the data is written
  Future<int> _head(String name) async {
    final at = await _out.position();
    if (at > _max32) throw const ZipTooLarge();
    final n = Uint8List.fromList(name.codeUnits);
    final h = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(8, 0, Endian.little)
      ..setUint16(10, _time, Endian.little)
      ..setUint16(12, _date, Endian.little)
      ..setUint16(26, n.length, Endian.little);
    await _out.writeFrom(h.buffer.asUint8List());
    await _out.writeFrom(n);
    return at;
  }

  Future<void> _seal(String name, int at, int crc, int size) async {
    final end = await _out.position();
    final sizes = ByteData(12)
      ..setUint32(0, crc, Endian.little)
      ..setUint32(4, size, Endian.little)
      ..setUint32(8, size, Endian.little);
    await _out.setPosition(at + 14);
    await _out.writeFrom(sizes.buffer.asUint8List());
    await _out.setPosition(end);
    final n = Uint8List.fromList(name.codeUnits);
    final c = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(12, _time, Endian.little)
      ..setUint16(14, _date, Endian.little)
      ..setUint32(16, crc, Endian.little)
      ..setUint32(20, size, Endian.little)
      ..setUint32(24, size, Endian.little)
      ..setUint16(28, n.length, Endian.little)
      ..setUint32(42, at, Endian.little);
    _central
      ..add(c.buffer.asUint8List())
      ..add(n);
    _count++;
  }
}
