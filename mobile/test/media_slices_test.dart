import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show saveSlices;
import 'package:kryfo/media_send.dart';

// a file is sent as base64 slices read straight from disk, and rebuilt on
// the far side one slice at a time. the wire must not notice: the slices
// have to be the same pieces the old whole-string cut produced, and the
// rebuilt file has to be the original, byte for byte.
void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kryfo_slices');
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Future<File> fileOf(int n, {int seed = 7}) async {
    final r = Random(seed);
    final f = File('${tmp.path}/in_$n');
    await f.writeAsBytes([for (var i = 0; i < n; i++) r.nextInt(256)]);
    return f;
  }

  for (final n in [0, 1, 3, 12287, 12288, 12289, 40000, 200000]) {
    test('slices of a $n byte file match the whole-string cut', () async {
      final f = await fileOf(n);
      final whole = base64Encode(await f.readAsBytes());
      final total = await mediaSliceCount(f.path);
      expect(total, (whole.length + mediaChunkSize - 1) ~/ mediaChunkSize);
      final parts = <String>[];
      for (var i = 0; i < total; i++) {
        parts.add(await mediaSlice(f.path, i));
      }
      for (var i = 0; i < total; i++) {
        final start = i * mediaChunkSize;
        expect(
          parts[i],
          whole.substring(start, min(start + mediaChunkSize, whole.length)),
        );
      }
      expect(parts.join(), whole);
    });
  }

  test('a file rebuilt slice by slice is the original', () async {
    final f = await fileOf(100001, seed: 3);
    final total = await mediaSliceCount(f.path);
    final out = File('${tmp.path}/out');
    await saveSlices(out, total, (i) => mediaSlice(f.path, i));
    expect(await out.readAsBytes(), await f.readAsBytes());
  });

  test('a missing slice leaves no half file behind', () async {
    final f = await fileOf(50000, seed: 5);
    final total = await mediaSliceCount(f.path);
    final out = File('${tmp.path}/out2');
    await expectLater(
      saveSlices(
        out,
        total,
        (i) async => i == 2 ? null : mediaSlice(f.path, i),
      ),
      throwsStateError,
    );
    expect(await out.exists(), isFalse);
  });
}
