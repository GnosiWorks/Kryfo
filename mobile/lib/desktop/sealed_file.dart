// SPDX-License-Identifier: GPL-3.0-or-later
// random access to a sealed file at plaintext offsets. one chunk is held in
// memory at a time: a read opens the chunk it lands in, a write changes it
// there and seals it again when another chunk is wanted, on flush and on
// close. the last chunk is always sealed as the last, so a cut file never
// opens
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'sealed_format.dart';

class SealedDamaged implements FileSystemException {
  const SealedDamaged(this.path, [this.message = 'sealed file does not open']);
  @override
  final String? path;
  @override
  final String message;
  @override
  OSError? get osError => null;
  @override
  String toString() => 'SealedDamaged: $message: $path';
}

class SealedRandomAccessFile implements RandomAccessFile {
  SealedRandomAccessFile._(
    this._raw,
    this.path,
    this._crypto,
    this._fk,
    this._length,
    this._writable,
  );

  /// opens [raw] (already open in a mode that reads) as sealed under
  /// [areaKey]. a new or emptied file gets its header here
  static SealedRandomAccessFile over(
    RandomAccessFile raw,
    String path,
    Uint8List areaKey,
    ChunkCrypto crypto, {
    required bool writable,
    bool truncate = false,
  }) {
    final size = raw.lengthSync();
    if (truncate || size == 0) {
      if (!writable) {
        throw SealedDamaged(path, 'empty sealed file');
      }
      final head = newHeader();
      raw.truncateSync(0);
      raw.setPositionSync(0);
      raw.writeFromSync(head);
      final f = SealedRandomAccessFile._(
        raw,
        path,
        crypto,
        fileKey(areaKey, head),
        0,
        true,
      );
      // an empty file is one empty last chunk
      f._dirty = true;
      f._index = 0;
      f._chunk = Uint8List(0);
      f._sealedLast = -1;
      f._flushChunk();
      return f;
    }
    raw.setPositionSync(0);
    final head = raw.readSync(sealedHead);
    if (!isSealedHead(head)) {
      raw.closeSync();
      throw SealedDamaged(path, 'not a sealed file');
    }
    final len = plainLength(size);
    if (len == null) {
      raw.closeSync();
      throw SealedDamaged(path, 'cut off');
    }
    final f = SealedRandomAccessFile._(
      raw,
      path,
      crypto,
      fileKey(areaKey, head),
      len,
      writable,
    );
    f._sealedLast = f._lastIndex;
    // the last chunk is opened now: a file cut at a chunk's edge reads as
    // whole up to there, and only this tells
    try {
      f._hold(f._lastIndex);
    } catch (_) {
      raw.closeSync();
      rethrow;
    }
    return f;
  }

  final RandomAccessFile _raw;
  @override
  final String path;
  final ChunkCrypto _crypto;
  final Uint8List _fk;
  final bool _writable;
  int _length;
  int _pos = 0;
  bool _closed = false;

  // the chunk held, its plaintext, whether it changed
  int _index = -1;
  Uint8List? _chunk;
  bool _dirty = false;
  // the chunk on disk sealed as the last one
  late int _sealedLast;
  // the last chunk once the write under way is done, -1 between writes
  int _writeLast = -1;

  int get _finalIndex => _writeLast > _lastIndex ? _writeLast : _lastIndex;

  int get _lastIndex => _length == 0 ? 0 : (_length - 1) ~/ chunkPlain;

  int _storedAt(int index) => sealedHead + index * chunkStored;

  int _plainIn(int index) {
    if (index < _lastIndex) return chunkPlain;
    if (index > _lastIndex) return 0;
    return _length - index * chunkPlain;
  }

  Uint8List _readChunk(int index) {
    final n = _plainIn(index);
    _raw.setPositionSync(_storedAt(index));
    final stored = _raw.readSync(n + 32);
    final plain = openChunk(_crypto, _fk, index, index == _sealedLast, stored);
    if (plain == null || plain.length != n) throw SealedDamaged(path);
    return plain;
  }

  void _flushChunk() {
    final c = _chunk;
    if (!_dirty || c == null) return;
    final last = _index == _finalIndex;
    _raw.setPositionSync(_storedAt(_index));
    _raw.writeFromSync(sealChunk(_crypto, _fk, _index, last, c));
    if (last) {
      _sealedLast = _index;
    } else if (_sealedLast == _index) {
      _sealedLast = -1;
    }
    _dirty = false;
  }

  // the chunk at [index] in memory, at its full plaintext
  void _hold(int index) {
    if (_index == index && _chunk != null) return;
    _flushChunk();
    _wipeHeld();
    _chunk = index <= _lastIndex && _length > 0 ? _readChunk(index) : null;
    _index = index;
  }

  void _wipeHeld() {
    final c = _chunk;
    if (c != null) c.fillRange(0, c.length, 0);
    _chunk = null;
    _index = -1;
  }

  // the old last chunk, sealed as the last, sealed again as one in the
  // middle before the file grows past it
  void _unmarkLast() {
    final old = _sealedLast;
    if (old < 0 || old >= _finalIndex) return;
    if (_index == old) {
      // the held one: sealed as a middle one at its next flush
      _dirty = true;
      return;
    }
    final n = _plainIn(old);
    _raw.setPositionSync(_storedAt(old));
    final stored = _raw.readSync(n + 32);
    final plain = openChunk(_crypto, _fk, old, true, stored);
    if (plain == null) throw SealedDamaged(path);
    _raw.setPositionSync(_storedAt(old));
    _raw.writeFromSync(sealChunk(_crypto, _fk, old, false, plain));
    plain.fillRange(0, plain.length, 0);
    _sealedLast = -1;
  }

  void _check() {
    if (_closed) throw FileSystemException('file is closed', path);
  }

  void _checkWrite() {
    _check();
    if (!_writable) {
      throw FileSystemException('file is not open to write', path);
    }
  }

  // ---- reading

  @override
  int readIntoSync(List<int> buffer, [int start = 0, int? end]) {
    _check();
    end ??= buffer.length;
    var done = 0;
    while (start + done < end && _pos < _length) {
      final index = _pos ~/ chunkPlain;
      _hold(index);
      final c = _chunk!;
      final at = _pos - index * chunkPlain;
      final n = [
        c.length - at,
        end - start - done,
      ].reduce((a, b) => a < b ? a : b);
      if (n <= 0) break;
      buffer.setRange(start + done, start + done + n, c, at);
      done += n;
      _pos += n;
    }
    return done;
  }

  @override
  Uint8List readSync(int count) {
    final out = Uint8List(count < 0 ? 0 : count);
    final n = readIntoSync(out);
    return n == out.length ? out : Uint8List.fromList(out.sublist(0, n));
  }

  @override
  int readByteSync() {
    final b = readSync(1);
    return b.isEmpty ? -1 : b[0];
  }

  // ---- writing

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) {
    _checkWrite();
    end ??= buffer.length;
    if (end <= start) return;
    // a write past the end fills the gap with zeros first
    if (_pos > _length) {
      final at = _pos;
      _pos = _length;
      writeFromSync(Uint8List(at - _length));
      _pos = at;
    }
    final endPos = _pos + end - start;
    _writeLast = (endPos - 1) ~/ chunkPlain;
    try {
      _unmarkLast();
      var i = start;
      while (i < end) {
        final index = _pos ~/ chunkPlain;
        _hold(index);
        final at = _pos - index * chunkPlain;
        final room = chunkPlain - at;
        final n = room < end - i ? room : end - i;
        var c = _chunk ?? Uint8List(0);
        if (c.length < at + n) {
          final bigger = Uint8List(at + n)..setRange(0, c.length, c);
          c.fillRange(0, c.length, 0);
          c = bigger;
        }
        c.setRange(at, at + n, buffer, i);
        _chunk = c;
        _dirty = true;
        i += n;
        _pos += n;
        if (_pos > _length) _length = _pos;
      }
    } finally {
      _writeLast = -1;
    }
  }

  @override
  int writeByteSync(int value) {
    writeFromSync([value]);
    return 1;
  }

  @override
  void writeStringSync(String string, {Encoding encoding = utf8}) =>
      writeFromSync(encoding.encode(string));

  @override
  void truncateSync(int length) {
    _checkWrite();
    if (length >= _length) {
      if (length > _length) {
        final at = _pos;
        _pos = _length;
        writeFromSync(Uint8List(length - _length));
        _pos = at;
      }
      return;
    }
    final index = length == 0 ? 0 : (length - 1) ~/ chunkPlain;
    _hold(index);
    final keep = length - index * chunkPlain;
    final c = _chunk ?? Uint8List(0);
    final cut = Uint8List.fromList(
      c.sublist(0, keep < c.length ? keep : c.length),
    );
    c.fillRange(0, c.length, 0);
    _chunk = cut;
    _length = length;
    _dirty = true;
    _flushChunk();
    _raw.truncateSync(_storedAt(index) + cut.length + 32);
  }

  @override
  void flushSync() {
    _check();
    _flushChunk();
    _raw.flushSync();
  }

  // ---- position and size

  @override
  int positionSync() {
    _check();
    return _pos;
  }

  @override
  RandomAccessFile setPositionSync(int position) {
    _check();
    if (position < 0) throw FileSystemException('negative position', path);
    _pos = position;
    return this;
  }

  @override
  int lengthSync() {
    _check();
    return _length;
  }

  @override
  void closeSync() {
    if (_closed) return;
    try {
      if (_writable) _flushChunk();
    } finally {
      _wipeHeld();
      _fk.fillRange(0, _fk.length, 0);
      _closed = true;
      _raw.closeSync();
    }
  }

  @override
  RandomAccessFile lockSync([
    FileLock mode = FileLock.exclusive,
    int start = 0,
    int end = -1,
  ]) {
    _raw.lockSync(mode, 0, -1);
    return this;
  }

  @override
  RandomAccessFile unlockSync([int start = 0, int end = -1]) {
    _raw.unlockSync(0, -1);
    return this;
  }

  // ---- the same, as futures

  @override
  Future<void> close() async => closeSync();
  @override
  Future<int> readByte() async => readByteSync();
  @override
  Future<Uint8List> read(int count) async => readSync(count);
  @override
  Future<int> readInto(List<int> buffer, [int start = 0, int? end]) async =>
      readIntoSync(buffer, start, end);
  @override
  Future<RandomAccessFile> writeByte(int value) async {
    writeByteSync(value);
    return this;
  }

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) async {
    writeFromSync(buffer, start, end);
    return this;
  }

  @override
  Future<RandomAccessFile> writeString(
    String string, {
    Encoding encoding = utf8,
  }) async {
    writeStringSync(string, encoding: encoding);
    return this;
  }

  @override
  Future<int> position() async => positionSync();
  @override
  Future<RandomAccessFile> setPosition(int position) async =>
      setPositionSync(position);
  @override
  Future<RandomAccessFile> truncate(int length) async {
    truncateSync(length);
    return this;
  }

  @override
  Future<int> length() async => lengthSync();
  @override
  Future<RandomAccessFile> flush() async {
    flushSync();
    return this;
  }

  @override
  Future<RandomAccessFile> lock([
    FileLock mode = FileLock.exclusive,
    int start = 0,
    int end = -1,
  ]) async => lockSync(mode, start, end);
  @override
  Future<RandomAccessFile> unlock([int start = 0, int end = -1]) async =>
      unlockSync(start, end);

  @override
  String toString() => "SealedRandomAccessFile: '$path'";
}
