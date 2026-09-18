// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:typed_data';

import 'byte_source.dart';

class FileSource implements ByteSource {
  final RandomAccessFile _raf;
  @override
  final int length;
  FileSource._(this._raf, this.length);

  static FileSource open(String path) {
    final raf = File(path).openSync();
    return FileSource._(raf, raf.lengthSync());
  }

  @override
  Uint8List read(int offset, int count) {
    if (offset < 0 || count < 0 || offset + count > length) {
      throw RangeError('read $count at $offset of $length');
    }
    _raf.setPositionSync(offset);
    final b = _raf.readSync(count);
    if (b.length != count) throw RangeError('short read at $offset');
    return b;
  }

  void close() => _raf.closeSync();
}
