// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

abstract class ByteSource {
  int get length;
  Uint8List read(int offset, int count);
}

class MemorySource implements ByteSource {
  final Uint8List bytes;
  const MemorySource(this.bytes);
  @override
  int get length => bytes.length;
  @override
  Uint8List read(int offset, int count) {
    if (offset < 0 || count < 0 || offset + count > bytes.length) {
      throw RangeError('read $count at $offset of ${bytes.length}');
    }
    return Uint8List.sublistView(bytes, offset, offset + count);
  }
}
