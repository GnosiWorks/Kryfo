// SPDX-License-Identifier: GPL-3.0-or-later
// a file sealed at rest on desktop, in chunks so it reads and writes at any
// place without the whole of it in memory. the header names the file with
// random bytes; each chunk carries its own random bytes and is sealed under
// a key made from the file's key, those bytes, its place and whether it is
// the last one, so a chunk moved, swapped, dropped or cut off never opens.
// no two seals share a key, so a chunk written again is safe
import 'dart:convert';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';

import '../engine_strings.dart' show freeSecret;
import '../native_libs.dart';

const sealedMagic = [0x4b, 0x52, 0x59, 0x4d]; // KRYM
const sealedVersion = 1;

/// plaintext in a chunk
const chunkPlain = 1 << 16;
const _chunkNonce = 16;
const _tag = 16;

/// a full chunk on disk
const chunkStored = _chunkNonce + chunkPlain + _tag;

/// magic, version, three zero bytes, the file's own 16 random bytes
const sealedHead = 4 + 1 + 3 + 16;

const _type = 0x4d;

/// the cipher under the chunks, behind a seam for the tests: aes-256-gcm
/// through the engine in the app
abstract class ChunkCrypto {
  Uint8List seal(Uint8List key, Uint8List plain);
  Uint8List? open(Uint8List key, Uint8List sealed);
}

typedef _ChunkC =
    Int32 Function(
      Pointer<Utf8>,
      Uint64,
      Uint8,
      Pointer<Uint8>,
      Int32,
      Pointer<Uint8>,
    );
typedef _Chunk =
    int Function(Pointer<Utf8>, int, int, Pointer<Uint8>, int, Pointer<Uint8>);

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

class EngineChunkCrypto implements ChunkCrypto {
  const EngineChunkCrypto();

  static final _sealChunk = haloLibrary().lookupFunction<_ChunkC, _Chunk>(
    'HaloSealChunk',
  );
  static final _openChunk = haloLibrary().lookupFunction<_ChunkC, _Chunk>(
    'HaloOpenChunk',
  );

  Uint8List? _run(_Chunk call, Uint8List key, Uint8List data) {
    final k = _hex(key).toNativeUtf8();
    final cap = data.length + _tag;
    final inp = calloc<Uint8>(cap), out = calloc<Uint8>(cap);
    try {
      inp.asTypedList(cap).setAll(0, data);
      final n = call(k, 0, _type, inp, data.length, out);
      if (n < 0 || n > cap) return null;
      return Uint8List.fromList(out.asTypedList(n));
    } finally {
      inp.asTypedList(cap).fillRange(0, cap, 0);
      out.asTypedList(cap).fillRange(0, cap, 0);
      calloc.free(inp);
      calloc.free(out);
      freeSecret(k);
    }
  }

  @override
  Uint8List seal(Uint8List key, Uint8List plain) {
    final s = _run(_sealChunk, key, plain);
    if (s == null || s.length != plain.length + _tag) {
      throw StateError('seal failed');
    }
    return s;
  }

  @override
  Uint8List? open(Uint8List key, Uint8List sealed) {
    if (sealed.length < _tag) return null;
    return _run(_openChunk, key, sealed);
  }
}

final _rnd = Random.secure();

Uint8List randomBytes(int n) =>
    Uint8List.fromList(List.generate(n, (_) => _rnd.nextInt(256)));

/// a new file's header
Uint8List newHeader() => Uint8List.fromList([
  ...sealedMagic,
  sealedVersion,
  0,
  0,
  0,
  ...randomBytes(16),
]);

/// true when [head] starts a sealed file of this version
bool isSealedHead(List<int> head) =>
    head.length >= sealedHead &&
    head[0] == sealedMagic[0] &&
    head[1] == sealedMagic[1] &&
    head[2] == sealedMagic[2] &&
    head[3] == sealedMagic[3] &&
    head[4] == sealedVersion;

/// the file's key, from the key of the place it lives and its own bytes
Uint8List fileKey(Uint8List areaKey, List<int> head) => Uint8List.fromList(
  Hmac(sha256, areaKey).convert(head.sublist(8, sealedHead)).bytes,
);

Uint8List _chunkKey(Uint8List fk, List<int> nonce, int index, bool last) {
  final b = BytesBuilder(copy: false)
    ..add(nonce)
    ..add((ByteData(8)..setUint64(0, index)).buffer.asUint8List())
    ..addByte(last ? 1 : 0);
  return Uint8List.fromList(Hmac(sha256, fk).convert(b.takeBytes()).bytes);
}

/// a chunk's bytes on disk
Uint8List sealChunk(
  ChunkCrypto c,
  Uint8List fk,
  int index,
  bool last,
  Uint8List plain,
) {
  final nonce = randomBytes(_chunkNonce);
  final k = _chunkKey(fk, nonce, index, last);
  try {
    final sealed = c.seal(k, plain);
    return Uint8List(_chunkNonce + sealed.length)
      ..setAll(0, nonce)
      ..setAll(_chunkNonce, sealed);
  } finally {
    k.fillRange(0, k.length, 0);
  }
}

/// a chunk's plaintext, or null when it is not the chunk at [index] with
/// that place in the file
Uint8List? openChunk(
  ChunkCrypto c,
  Uint8List fk,
  int index,
  bool last,
  Uint8List stored,
) {
  if (stored.length < _chunkNonce + _tag) return null;
  final k = _chunkKey(fk, stored.sublist(0, _chunkNonce), index, last);
  try {
    return c.open(k, stored.sublist(_chunkNonce));
  } finally {
    k.fillRange(0, k.length, 0);
  }
}

/// the plaintext length a sealed file of [stored] bytes holds, or null
/// when no whole set of chunks has that size
int? plainLength(int stored) {
  final body = stored - sealedHead;
  if (body < _chunkNonce + _tag) return null;
  final full = (body - 1) ~/ chunkStored;
  final last = body - full * chunkStored;
  if (last < _chunkNonce + _tag) return null;
  return full * chunkPlain + last - _chunkNonce - _tag;
}

/// the stored size of [plain] bytes
int storedLength(int plain) {
  final chunks = plain == 0 ? 1 : (plain + chunkPlain - 1) ~/ chunkPlain;
  return sealedHead + plain + chunks * (_chunkNonce + _tag);
}

/// a key as the vault keeps it
String keyText(Uint8List k) => base64.encode(k);
Uint8List keyOfText(String s) => Uint8List.fromList(base64.decode(s));
