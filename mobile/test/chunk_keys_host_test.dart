// SPDX-License-Identifier: GPL-3.0-or-later
// a chunk key the real engine holds (tool/host_engine.sh): it crosses once,
// every chunk names it by its handle, and a dropped handle opens nothing.
// skipped when the host engine is not built
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chunk_keys.dart';

import 'host_engine.dart';

void main() {
  final skip = loadHostEngine() ? false : 'no host engine';

  test('sealed and opened by handle, nothing after the drop', () {
    final keys = ChunkKeys(DynamicLibrary.process());
    final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
    final h = keys.take(key);
    expect(h, greaterThan(0));
    // the caller's bytes are the caller's to zero
    expect(key.first, 1);
    final plain = Uint8List.fromList('a slice of a photo'.codeUnits);
    final cap = plain.length + 16;
    final inp = calloc<Uint8>(cap), out = calloc<Uint8>(cap);
    try {
      inp.asTypedList(cap).setAll(0, plain);
      expect(keys.seal(h, 3, 2, inp, plain.length, out), cap);
      final sealed = Uint8List.fromList(out.asTypedList(cap));
      inp.asTypedList(cap).setAll(0, sealed);
      expect(keys.open(h, 3, 2, inp, cap, out), plain.length);
      expect(out.asTypedList(plain.length), plain);
      expect(keys.open(h, 4, 2, inp, cap, out), -1);
      // the same key under a new handle opens it too
      final h2 = keys.take(key);
      expect(keys.open(h2, 3, 2, inp, cap, out), plain.length);
      keys.drop(h);
      keys.drop(h2);
      expect(keys.open(h, 3, 2, inp, cap, out), -1);
      expect(keys.seal(h, 3, 2, inp, plain.length, out), -1);
    } finally {
      calloc.free(inp);
      calloc.free(out);
    }
    expect(keys.take(Uint8List(31)), 0);
  }, skip: skip);
}
