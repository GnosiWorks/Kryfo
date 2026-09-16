// the v2 container, with a stand-in cipher: the real one lives in the
// engine and needs the phone's library. what is tested here is the shape -
// records in order, files back byte for byte, a cut file refused, a moved
// record refused, a peek that skips what it does not want.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup_stream.dart';

// binds each record to its index and type the way the real cipher does
class FakeCipher implements ChunkCipher {
  final int key;
  FakeCipher(this.key);
  @override
  Uint8List seal(int index, int type, Uint8List plain) {
    final out = Uint8List(plain.length + 3);
    out[0] = index & 255;
    out[1] = type;
    out[2] = key & 255;
    for (var i = 0; i < plain.length; i++) {
      out[i + 3] = plain[i] ^ (key & 255);
    }
    return out;
  }

  @override
  Uint8List? open(int index, int type, Uint8List sealed) {
    if (sealed.length < 3) return null;
    if (sealed[0] != (index & 255) || sealed[1] != type) return null;
    if (sealed[2] != (key & 255)) return null;
    final out = Uint8List(sealed.length - 3);
    for (var i = 0; i < out.length; i++) {
      out[i] = sealed[i + 3] ^ (key & 255);
    }
    return out;
  }
}

Uint8List bytes(int n, int seed) =>
    Uint8List.fromList(List.generate(n, (i) => (i * 7 + seed) & 255));

const names = ['halo.db', 'media/a.jpg', 'media/empty', 'media/b.mp4'];

Future<(Directory, Map<String, dynamic>)> sample() async {
  final d = await Directory.systemTemp.createTemp('bk2');
  final src = Directory('${d.path}/src')..createSync();
  Directory('${src.path}/media').createSync();
  await File('${src.path}/halo.db').writeAsBytes(bytes(2500, 1)); // 3 chunks
  await File('${src.path}/media/a.jpg').writeAsBytes(bytes(1000, 2)); // 1
  await File('${src.path}/media/empty').writeAsBytes(Uint8List(0)); // 0
  await File('${src.path}/media/b.mp4').writeAsBytes(bytes(1001, 3)); // 2
  final m = <String, dynamic>{
    'v': 2,
    'haloId': 'initial-patient-direct',
    'secret': 'shh',
    'chunk': 1000,
    'files': [
      const BackupFileEntry('halo.db', 2500).toJson(),
      const BackupFileEntry('media/a.jpg', 1000).toJson(),
      const BackupFileEntry('media/empty', 0).toJson(),
      const BackupFileEntry('media/b.mp4', 1001).toJson(),
    ],
  };
  return (d, m);
}

Future<String> written(Directory d, Map<String, dynamic> m) async {
  final out = '${d.path}/x.bk';
  await writeBackup(
    outPath: out,
    salt: Uint8List.fromList(List.filled(16, 9)),
    cipher: FakeCipher(5),
    manifest: m,
    root: '${d.path}/src',
  );
  return out;
}

// where each record starts, by walking the headers
List<int> recordStarts(Uint8List all) {
  final starts = <int>[];
  var pos = 24;
  while (pos < all.length) {
    starts.add(pos);
    final len =
        (all[pos + 1] << 24) |
        (all[pos + 2] << 16) |
        (all[pos + 3] << 8) |
        all[pos + 4];
    pos += 5 + len;
  }
  return starts;
}

void main() {
  test('writes, reads the manifest, extracts every file byte for byte', () async {
    final (d, m) = await sample();
    final out = await written(d, m);
    expect(await isBackupV2(out), true);
    expect(await backupSalt(out), List.filled(16, 9));
    final got = await readBackupManifest(out, FakeCipher(5));
    expect(got['haloId'], 'initial-patient-direct');
    expect(got['secret'], 'shh');
    final dst = '${d.path}/dst';
    var last = 0;
    await extractBackup(
      out,
      FakeCipher(5),
      want: (n) => '$dst/$n',
      onProgress: (a, _) => last = a,
    );
    expect(last, 4501);
    for (final n in names) {
      expect(
        await File('$dst/$n').readAsBytes(),
        await File('${d.path}/src/$n').readAsBytes(),
        reason: n,
      );
    }
  });

  test('the wrong key is locked, not damaged', () async {
    final (d, m) = await sample();
    final out = await written(d, m);
    expect(
      () => readBackupManifest(out, FakeCipher(6)),
      throwsA(isA<BackupLocked>()),
    );
  });

  test('a peek skips what it does not want and still needs the end', () async {
    final (d, m) = await sample();
    final out = await written(d, m);
    final peek = '${d.path}/peek.db';
    await extractBackup(
      out,
      FakeCipher(5),
      want: (n) => n == 'halo.db' ? peek : null,
    );
    expect(
      await File(peek).readAsBytes(),
      await File('${d.path}/src/halo.db').readAsBytes(),
    );
    expect(Directory('${d.path}/dst').existsSync(), false);
  });

  test('a file cut short is damaged, even with every file out', () async {
    final (d, m) = await sample();
    final out = await written(d, m);
    final all = await File(out).readAsBytes();
    // drop the end record: 5 header bytes + 3 sealed bytes of nothing
    await File(out).writeAsBytes(all.sublist(0, all.length - 8));
    expect(
      () => extractBackup(out, FakeCipher(5), want: (n) => '${d.path}/dst/$n'),
      throwsA(isA<BackupDamaged>()),
    );
  });

  test('a record moved to another place will not open', () async {
    final (d, m) = await sample();
    final out = await written(d, m);
    final all = await File(out).readAsBytes();
    final starts = recordStarts(all);
    // manifest, 3 for halo.db, 1 for a.jpg, 0 for empty, 2 for b.mp4, end
    expect(starts.length, 1 + 3 + 1 + 0 + 2 + 1);
    // records 1 and 2 are both full chunks of halo.db: swap them
    final r1 = all.sublist(starts[1], starts[2]);
    final r2 = all.sublist(starts[2], starts[3]);
    expect(r1.length, r2.length);
    await File(out).writeAsBytes(
      Uint8List.fromList([
        ...all.sublist(0, starts[1]),
        ...r2,
        ...r1,
        ...all.sublist(starts[3]),
      ]),
    );
    expect(
      () => extractBackup(out, FakeCipher(5), want: (n) => '${d.path}/dst/$n'),
      throwsA(isA<BackupLocked>()),
    );
  });

  test('names that could escape the root are refused', () {
    expect(safeBackupName('halo.db'), true);
    expect(safeBackupName('media/a.jpg'), true);
    expect(safeBackupName('../x'), false);
    expect(safeBackupName('/etc/passwd'), false);
    expect(safeBackupName('media/../../x'), false);
    expect(safeBackupName(r'a\b'), false);
    expect(safeBackupName(''), false);
  });
}
