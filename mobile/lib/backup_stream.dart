// SPDX-License-Identifier: GPL-3.0-or-later
// the v2 backup file, streamed a sealed record at a time so memory stays
// flat whatever the size:
//
//   "KRYFOBK2"          8 bytes, the magic
//   salt                16 bytes, for the passphrase key
//   records until the end record:
//     type              1 byte: 1 manifest, 2 file chunk, 3 end
//     len               4 bytes big-endian, the sealed length
//     sealed            len bytes
//
// record 0 is the manifest (identity, secrets, prefs, files with sizes).
// each file follows as ceil(size / chunk) chunks. the empty end record says
// the file is whole. index and type go to the cipher so a moved or
// retyped record fails to open.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const kBackupMagic = 'KRYFOBK2';
const kBackupChunk = 1024 * 1024;

const recManifest = 1;
const recChunk = 2;
const recEnd = 3;

/// a record must only open at the index and type it was sealed with
abstract class ChunkCipher {
  Uint8List seal(int index, int type, Uint8List plain);

  /// null when the passphrase is wrong or the record was moved or changed
  Uint8List? open(int index, int type, Uint8List sealed);
}

class BackupDamaged implements Exception {
  final String why;
  const BackupDamaged(this.why);
  @override
  String toString() => 'BackupDamaged($why)';
}

/// thrown when a record will not open: wrong passphrase, or bytes changed
class BackupLocked implements Exception {
  const BackupLocked();
}

class BackupFileEntry {
  final String name; // relative, forward slashes, no dot segments
  final int size;
  const BackupFileEntry(this.name, this.size);
  Map<String, dynamic> toJson() => {'name': name, 'size': size};
  static BackupFileEntry fromJson(Map<String, dynamic> j) =>
      BackupFileEntry(j['name'] as String, j['size'] as int);
}

/// a name that could only ever land inside the restore root
bool safeBackupName(String n) {
  if (n.isEmpty || n.startsWith('/') || n.contains(r'\')) return false;
  if (n.codeUnits.any((c) => c < 32)) return false;
  for (final seg in n.split('/')) {
    if (seg.isEmpty || seg == '.' || seg == '..') return false;
  }
  return true;
}

int _u32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

Uint8List _be32(int v) => Uint8List.fromList([
  (v >> 24) & 255,
  (v >> 16) & 255,
  (v >> 8) & 255,
  v & 255,
]);

/// [manifest] must carry 'files' as BackupFileEntry json, read from
/// [root]/name in that order. 'chunk' is filled in when absent.
Future<void> writeBackup({
  required String outPath,
  required Uint8List salt,
  required ChunkCipher cipher,
  required Map<String, dynamic> manifest,
  required String root,
  void Function(int done, int total)? onProgress,
}) async {
  if (salt.length != 16) throw ArgumentError('salt must be 16 bytes');
  final chunk = manifest['chunk'] as int? ?? kBackupChunk;
  manifest['chunk'] = chunk;
  final files = [
    for (final f in manifest['files'] as List)
      BackupFileEntry.fromJson(f as Map<String, dynamic>),
  ];
  for (final f in files) {
    if (!safeBackupName(f.name)) throw ArgumentError('bad name ${f.name}');
  }
  final total = files.fold<int>(0, (a, f) => a + f.size);
  var done = 0;
  var index = 0;
  final out = await File(outPath).open(mode: FileMode.write);
  try {
    await out.writeFrom(ascii.encode(kBackupMagic));
    await out.writeFrom(salt);
    Future<void> put(int type, Uint8List plain) async {
      final sealed = cipher.seal(index++, type, plain);
      await out.writeFrom([type]);
      await out.writeFrom(_be32(sealed.length));
      await out.writeFrom(sealed);
    }

    await put(recManifest, utf8.encode(jsonEncode(manifest)));
    final buf = Uint8List(chunk);
    for (final f in files) {
      final raf = await File('$root/${f.name}').open();
      try {
        var left = f.size;
        while (left > 0) {
          final n = left < chunk ? left : chunk;
          final got = await raf.readInto(buf, 0, n);
          // the file shrank under us. the reader trusts sizes, so this is a
          // broken backup, not a short one
          if (got < n) throw BackupDamaged('${f.name} shorter than listed');
          await put(recChunk, Uint8List.sublistView(buf, 0, n));
          left -= n;
          done += n;
          onProgress?.call(done, total);
        }
      } finally {
        await raf.close();
      }
    }
    await put(recEnd, Uint8List(0));
    await out.flush();
  } finally {
    await out.close();
  }
}

/// true when the first bytes are the v2 magic
Future<bool> isBackupV2(String path) async {
  final raf = await File(path).open();
  try {
    if (await raf.length() < 24) return false;
    final head = await raf.read(8);
    return ascii.decode(head, allowInvalid: true) == kBackupMagic;
  } finally {
    await raf.close();
  }
}

/// the salt, so the caller can derive the key before opening anything
Future<Uint8List> backupSalt(String path) async {
  final raf = await File(path).open();
  try {
    await raf.setPosition(8);
    final s = await raf.read(16);
    if (s.length != 16) throw const BackupDamaged('no salt');
    return s;
  } finally {
    await raf.close();
  }
}

class _Rec {
  final int type;
  final int len;
  final int at; // where the sealed bytes start
  const _Rec(this.type, this.len, this.at);
}

Future<_Rec> _header(RandomAccessFile raf, int pos, int end) async {
  if (pos + 5 > end) throw const BackupDamaged('ends inside a record header');
  await raf.setPosition(pos);
  final h = await raf.read(5);
  if (h.length < 5) throw const BackupDamaged('short header');
  final type = h[0];
  final len = _u32(h, 1);
  if (type < recManifest || type > recEnd) {
    throw BackupDamaged('unknown record type $type');
  }
  if (pos + 5 + len > end) {
    throw const BackupDamaged('record runs past the end');
  }
  return _Rec(type, len, pos + 5);
}

/// record 0, decoded. BackupLocked when it will not open.
Future<Map<String, dynamic>> readBackupManifest(
  String path,
  ChunkCipher cipher,
) async {
  final raf = await File(path).open();
  try {
    final end = await raf.length();
    final r = await _header(raf, 24, end);
    if (r.type != recManifest) throw const BackupDamaged('no manifest first');
    await raf.setPosition(r.at);
    final sealed = await raf.read(r.len);
    final plain = cipher.open(0, recManifest, sealed);
    if (plain == null) throw const BackupLocked();
    final m = jsonDecode(utf8.decode(plain));
    if (m is! Map<String, dynamic>) {
      throw const BackupDamaged('manifest shape');
    }
    if (m['files'] is! List || m['chunk'] is! int) {
      throw const BackupDamaged('manifest fields');
    }
    for (final f in m['files'] as List) {
      final e = BackupFileEntry.fromJson(f as Map<String, dynamic>);
      if (!safeBackupName(e.name)) throw BackupDamaged('bad name ${e.name}');
    }
    return m;
  } finally {
    await raf.close();
  }
}

/// [want] maps a name to its destination; null skips the file without
/// opening its records. without the end record the backup counts as cut
/// short, whatever was already written.
Future<void> extractBackup(
  String path,
  ChunkCipher cipher, {
  required String? Function(String name) want,
  void Function(int done, int total)? onProgress,
}) async {
  final manifest = await readBackupManifest(path, cipher);
  final chunk = manifest['chunk'] as int;
  final files = [
    for (final f in manifest['files'] as List)
      BackupFileEntry.fromJson(f as Map<String, dynamic>),
  ];
  final total = files.fold<int>(0, (a, f) => a + f.size);
  var done = 0;
  final raf = await File(path).open();
  try {
    final end = await raf.length();
    // past the manifest
    var r = await _header(raf, 24, end);
    var pos = r.at + r.len;
    var index = 1;
    for (final f in files) {
      final records = (f.size + chunk - 1) ~/ chunk;
      final dest = want(f.name);
      RandomAccessFile? out;
      if (dest != null) {
        await File(dest).parent.create(recursive: true);
        out = await File(dest).open(mode: FileMode.write);
      }
      try {
        var left = f.size;
        for (var i = 0; i < records; i++) {
          r = await _header(raf, pos, end);
          if (r.type != recChunk) throw const BackupDamaged('chunk expected');
          final n = left < chunk ? left : chunk;
          if (out != null) {
            await raf.setPosition(r.at);
            final sealed = await raf.read(r.len);
            final plain = cipher.open(index, recChunk, sealed);
            if (plain == null) throw const BackupLocked();
            if (plain.length != n) throw const BackupDamaged('chunk size');
            await out.writeFrom(plain);
          }
          left -= n;
          done += n;
          onProgress?.call(done, total);
          pos = r.at + r.len;
          index++;
        }
        if (out != null) await out.flush();
      } finally {
        await out?.close();
      }
    }
    r = await _header(raf, pos, end);
    if (r.type != recEnd) throw const BackupDamaged('no end record');
    await raf.setPosition(r.at);
    final sealed = await raf.read(r.len);
    if (cipher.open(index, recEnd, sealed) == null) throw const BackupLocked();
    if (r.at + r.len != end) throw const BackupDamaged('bytes after the end');
  } finally {
    await raf.close();
  }
}
