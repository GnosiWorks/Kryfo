// SPDX-License-Identifier: GPL-3.0-or-later
// the one seam every reader and writer of the desktop's files goes through.
// dart's File and Directory are answered here for the places kryfo keeps
// things at rest: a file there is sealed (sealed_file.dart) and reads back
// as its plaintext, through every api the app uses, so readers stay as
// they are. a file the system's own code reads (sqlite's databases, the
// engine's files, models) is left plain by name. readers outside dart get
// the plaintext through memory (sealed_native.dart), never a plain file
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'desktop_mode.dart' show rawFilesZoneKey;
import 'sealed_file.dart';
import 'sealed_format.dart';

/// what an area's files are sealed under is not open: its container is
/// locked, or the vault is
class SealedLocked implements FileSystemException {
  const SealedLocked(this.path);
  @override
  final String? path;
  @override
  String get message => 'locked';
  @override
  OSError? get osError => null;
  @override
  String toString() => 'SealedLocked: $path';
}

/// [f] with files as the disk holds them: the shred overwrites what is
/// there, and the migration reads what is plain
R rawFileAccess<R>(R Function() f) =>
    runZoned(f, zoneValues: {rawFilesZoneKey: true});

bool get _raw => Zone.current[rawFilesZoneKey] == true;

/// where things are sealed and under which key. sendable, so an isolate
/// gets the same
class SealedAreas {
  SealedAreas({required this.docs, required this.support});

  final String docs;
  final String support;

  /// a container's folder suffix to its key, while it is open
  final Map<String, Uint8List> containerKeys = {};

  /// the key of everything else kryfo keeps
  Uint8List? filesKey;

  // folders the system's own code reads by path: never sealed
  static const _plainSupport = {'translate', 'voice'};

  static final _media = RegExp(r'^(media|wallpapers)(_k[234])?$');
  static final _waitingOnion = RegExp(r'^onion_k[234]\.key$');

  /// a key not handed over yet but kept in the vault (the everyday
  /// container's and the decoy's): a restore moves files in before their
  /// database opens. not carried to an isolate
  Uint8List? Function(String suffix)? lateKey;

  /// which area [path] lies in: null when it stays plain, else the
  /// suffix of its container's folder, or '*' for the rest of kryfo's
  String? areaOf(String path) {
    final full = p.normalize(p.absolute(path));
    // sqlite's files and their sidecars, wherever they are
    if (RegExp(r'\.db(-wal|-shm|-journal)?$').hasMatch(p.basename(full))) {
      return null;
    }
    if (p.isWithin(docs, full)) {
      final parts = p.split(p.relative(full, from: docs));
      // a decoy's onion key waiting for its next start, written by dart
      if (parts.length == 1 && _waitingOnion.hasMatch(parts.first)) {
        return '*';
      }
      if (parts.length < 2) return null;
      final m = _media.firstMatch(parts.first);
      return m == null ? null : (m.group(2) ?? '');
    }
    if (p.isWithin(support, full)) {
      final top = p.split(p.relative(full, from: support)).first;
      if (_plainSupport.contains(top) || top.startsWith('shared_preferences')) {
        return null;
      }
      return '*';
    }
    return null;
  }

  /// the key [path] is sealed under, null when it stays plain. throws
  /// SealedLocked when it is sealed and its key is not here
  Uint8List? keyFor(String path) {
    final a = areaOf(path);
    if (a == null) return null;
    var k = a == '*' ? filesKey : containerKeys[a];
    if (k == null && a != '*') {
      k = lateKey?.call(a);
      if (k != null) containerKeys[a] = k;
    }
    if (k == null) throw SealedLocked(path);
    return k;
  }

  /// true when [path] lies in a sealed area, open or not
  bool sealedPlace(String path) => areaOf(path) != null;

  /// a copy for another isolate
  Map<String, Object?> toMessage() => {
    'docs': docs,
    'support': support,
    'files': filesKey,
    'keys': Map.of(containerKeys),
  };

  static SealedAreas fromMessage(Map<String, Object?> m) {
    final a = SealedAreas(
      docs: m['docs'] as String,
      support: m['support'] as String,
    );
    a.filesKey = m['files'] as Uint8List?;
    a.containerKeys.addAll((m['keys'] as Map).cast<String, Uint8List>());
    return a;
  }
}

/// dart's files, sealed where kryfo keeps them
final class SealedIO extends IOOverrides {
  SealedIO(this.areas, this.crypto);

  final SealedAreas areas;
  final ChunkCrypto crypto;

  /// a file as the disk has it, past this seam
  File rawFile(String path) => super.createFile(path);
  Directory rawDirectory(String path) => super.createDirectory(path);

  // every file goes through here, sealed place or not: a plain one moved
  // or copied into a sealed place is sealed on the way
  @override
  File createFile(String path) {
    if (_raw) return super.createFile(path);
    return SealedFile._(path, this);
  }

  // the sdk's own async answer under overrides loses the path's end and
  // says notFound for everything; the sync one is right
  @override
  Future<FileSystemEntityType> fseGetType(String path, bool followLinks) =>
      Future.value(fseGetTypeSync(path, followLinks));

  @override
  Directory createDirectory(String path) {
    final d = super.createDirectory(path);
    if (_raw) return d;
    return _ListedDirectory(d);
  }
}

/// the io in this isolate, sealed with [areas]: what a spawned isolate runs
/// first
void installSealedIO(Map<String, Object?> areas, ChunkCrypto crypto) {
  IOOverrides.global = SealedIO(SealedAreas.fromMessage(areas), crypto);
}

/// Isolate.run with this isolate's seal in the new one too
Future<R> runSealed<R>(FutureOr<R> Function() f) {
  final io = IOOverrides.current;
  if (io is! SealedIO) return Isolate.run(f);
  final m = io.areas.toMessage();
  final c = io.crypto;
  return Isolate.run(() {
    installSealedIO(m, c);
    return f();
  });
}

// a listing gives files that read through the seam, as File(path) does
class _ListedDirectory implements Directory {
  _ListedDirectory(this._d);
  final Directory _d;

  FileSystemEntity _wrap(FileSystemEntity e) => e is File ? File(e.path) : e;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => _d.list(recursive: recursive, followLinks: followLinks).map(_wrap);

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => [
    for (final e in _d.listSync(recursive: recursive, followLinks: followLinks))
      _wrap(e),
  ];

  @override
  String get path => _d.path;
  @override
  Uri get uri => _d.uri;
  @override
  bool get isAbsolute => _d.isAbsolute;
  @override
  Directory get absolute => Directory(_d.absolute.path);
  @override
  Directory get parent => Directory(_d.parent.path);
  @override
  Future<Directory> create({bool recursive = false}) async {
    await _d.create(recursive: recursive);
    return this;
  }

  @override
  void createSync({bool recursive = false}) =>
      _d.createSync(recursive: recursive);
  @override
  Future<Directory> createTemp([String? prefix]) async =>
      Directory((await _d.createTemp(prefix)).path);
  @override
  Directory createTempSync([String? prefix]) =>
      Directory(_d.createTempSync(prefix).path);
  @override
  Future<String> resolveSymbolicLinks() => _d.resolveSymbolicLinks();
  @override
  String resolveSymbolicLinksSync() => _d.resolveSymbolicLinksSync();
  @override
  Future<Directory> rename(String newPath) async =>
      Directory((await _d.rename(newPath)).path);
  @override
  Directory renameSync(String newPath) =>
      Directory(_d.renameSync(newPath).path);
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    await _d.delete(recursive: recursive);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) =>
      _d.deleteSync(recursive: recursive);
  @override
  Future<bool> exists() => _d.exists();
  @override
  bool existsSync() => _d.existsSync();
  @override
  Future<FileStat> stat() => _d.stat();
  @override
  FileStat statSync() => _d.statSync();
  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) => _d.watch(events: events, recursive: recursive);
  @override
  String toString() => "Directory: '$path'";
}

/// a file through the seam. in a sealed area its contents are sealed; a
/// plain one found there (made before the seal, or by the system's own
/// code) reads as it is until the start's sweep seals it. anywhere else it
/// is the disk's file, but for a move or a copy into a sealed area
class SealedFile implements File {
  SealedFile._(this.path, this._io) : _raw = _io.rawFile(path);

  bool get _here => _io.areas.sealedPlace(path);

  @override
  final String path;
  final SealedIO _io;
  final File _raw;

  Uint8List _key() => _io.areas.keyFor(path) ?? (throw SealedLocked(path));

  bool _isPlain() {
    if (!_raw.existsSync()) return false;
    final n = _raw.lengthSync();
    if (n == 0) return false;
    final f = _raw.openSync();
    try {
      return !isSealedHead(f.readSync(sealedHead));
    } finally {
      f.closeSync();
    }
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    if (!_here) return _raw.openSync(mode: mode);
    if (mode == FileMode.read) {
      if (_isPlain()) return _raw.openSync();
      return SealedRandomAccessFile.over(
        _raw.openSync(),
        path,
        _key(),
        _io.crypto,
        writable: false,
      );
    }
    final key = _key();
    final appending =
        mode == FileMode.append || mode == FileMode.writeOnlyAppend;
    if (appending && _isPlain()) return _raw.openSync(mode: mode);
    // a chunk is read back before it changes, so the disk is opened both ways
    final raw = _raw.openSync(mode: FileMode.append);
    final f = SealedRandomAccessFile.over(
      raw,
      path,
      key,
      _io.crypto,
      writable: true,
      truncate: !appending,
    );
    if (appending) f.setPositionSync(f.lengthSync());
    return f;
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      openSync(mode: mode);

  @override
  int lengthSync() {
    if (!_here) return _raw.lengthSync();
    final n = _raw.lengthSync();
    if (n == 0) return 0;
    final f = _raw.openSync();
    try {
      if (!isSealedHead(f.readSync(sealedHead))) return n;
    } finally {
      f.closeSync();
    }
    return plainLength(n) ?? (throw SealedDamaged(path, 'cut off'));
  }

  @override
  Future<int> length() async => lengthSync();

  @override
  Uint8List readAsBytesSync() {
    if (!_here) return _raw.readAsBytesSync();
    final f = openSync();
    try {
      return f.readSync(f.lengthSync());
    } finally {
      f.closeSync();
    }
  }

  @override
  Future<Uint8List> readAsBytes() async =>
      _here ? readAsBytesSync() : _raw.readAsBytes();

  @override
  String readAsStringSync({Encoding encoding = utf8}) =>
      encoding.decode(readAsBytesSync());
  @override
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      readAsStringSync(encoding: encoding);
  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) =>
      const LineSplitter().convert(readAsStringSync(encoding: encoding));
  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async =>
      readAsLinesSync(encoding: encoding);

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    final f = openSync(mode: mode);
    try {
      f.writeFromSync(bytes);
      if (flush) f.flushSync();
    } finally {
      f.closeSync();
    }
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    writeAsBytesSync(bytes, mode: mode, flush: flush);
    return this;
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) => writeAsBytesSync(encoding.encode(contents), mode: mode, flush: flush);

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    writeAsStringSync(contents, mode: mode, encoding: encoding, flush: flush);
    return this;
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      _here ? _sealedRead(start, end) : _raw.openRead(start, end);

  Stream<List<int>> _sealedRead(int? start, int? end) async* {
    final f = openSync();
    try {
      var at = start ?? 0;
      final stop = end ?? f.lengthSync();
      f.setPositionSync(at);
      while (at < stop) {
        final want = stop - at < chunkPlain ? stop - at : chunkPlain;
        final b = f.readSync(want);
        if (b.isEmpty) break;
        at += b.length;
        yield b;
      }
    } finally {
      f.closeSync();
    }
  }

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    if (mode != FileMode.write &&
        mode != FileMode.append &&
        mode != FileMode.writeOnly &&
        mode != FileMode.writeOnlyAppend) {
      throw ArgumentError('not a mode to write in: $mode');
    }
    if (!_here) return _raw.openWrite(mode: mode, encoding: encoding);
    return IOSink(_SealedConsumer(this, mode), encoding: encoding);
  }

  // a copy or a move to another place: through both seams, a block at a time
  void _carry(File to) {
    final src = openSync();
    final dst = to.openSync(mode: FileMode.write);
    try {
      while (true) {
        final b = src.readSync(chunkPlain);
        if (b.isEmpty) break;
        dst.writeFromSync(b);
        b.fillRange(0, b.length, 0);
      }
      dst.flushSync();
    } finally {
      src.closeSync();
      dst.closeSync();
    }
  }

  @override
  File copySync(String newPath) {
    if (!_here && !_io.areas.sealedPlace(newPath)) {
      _raw.copySync(newPath);
      return File(newPath);
    }
    final to = File(newPath);
    _carry(to);
    return to;
  }

  @override
  Future<File> copy(String newPath) async => copySync(newPath);

  @override
  File renameSync(String newPath) {
    final areas = _io.areas;
    if (!_here && !areas.sealedPlace(newPath)) {
      _raw.renameSync(newPath);
      return File(newPath);
    }
    Uint8List? mine, theirs;
    try {
      mine = areas.keyFor(path);
      theirs = areas.keyFor(newPath);
    } on SealedLocked {
      mine = theirs = null;
    }
    // the same key on both sides: the bytes move as they are
    if (mine != null && theirs != null && _same(mine, theirs) && !_isPlain()) {
      _raw.renameSync(newPath);
      return File(newPath);
    }
    final to = File(newPath);
    _carry(to);
    _drop();
    return to;
  }

  @override
  Future<File> rename(String newPath) async => renameSync(newPath);

  // the old bytes zeroed before they go: they may be plain
  void _drop() {
    rawFileAccess(() {
      final f = File(path);
      try {
        final n = f.lengthSync();
        final r = f.openSync(mode: FileMode.writeOnlyAppend);
        try {
          r.setPositionSync(0);
          var left = n;
          final zeros = Uint8List(chunkPlain);
          while (left > 0) {
            final k = left < zeros.length ? left : zeros.length;
            r.writeFromSync(zeros, 0, k);
            left -= k;
          }
          r.flushSync();
        } finally {
          r.closeSync();
        }
      } catch (_) {}
      f.deleteSync();
    });
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a[i] ^ b[i];
    }
    return d == 0;
  }

  // ---- what is the file's own, not its contents

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    createSync(recursive: recursive, exclusive: exclusive);
    return this;
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    final had = _raw.existsSync();
    _raw.createSync(recursive: recursive, exclusive: exclusive);
    if (!had && _here) openSync(mode: FileMode.write).closeSync();
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    await _raw.delete(recursive: recursive);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) =>
      _raw.deleteSync(recursive: recursive);
  @override
  Future<bool> exists() => _raw.exists();
  @override
  bool existsSync() => _raw.existsSync();
  @override
  Future<FileStat> stat() => _raw.stat();
  @override
  FileStat statSync() => _raw.statSync();
  @override
  Future<DateTime> lastAccessed() => _raw.lastAccessed();
  @override
  DateTime lastAccessedSync() => _raw.lastAccessedSync();
  @override
  Future<DateTime> lastModified() => _raw.lastModified();
  @override
  DateTime lastModifiedSync() => _raw.lastModifiedSync();
  @override
  Future<dynamic> setLastAccessed(DateTime time) => _raw.setLastAccessed(time);
  @override
  void setLastAccessedSync(DateTime time) => _raw.setLastAccessedSync(time);
  @override
  Future<dynamic> setLastModified(DateTime time) => _raw.setLastModified(time);
  @override
  void setLastModifiedSync(DateTime time) => _raw.setLastModifiedSync(time);
  @override
  Future<String> resolveSymbolicLinks() => _raw.resolveSymbolicLinks();
  @override
  String resolveSymbolicLinksSync() => _raw.resolveSymbolicLinksSync();
  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) => _raw.watch(events: events, recursive: recursive);
  @override
  File get absolute => File(_raw.absolute.path);
  @override
  bool get isAbsolute => _raw.isAbsolute;
  @override
  Directory get parent => Directory(_raw.parent.path);
  @override
  Uri get uri => _raw.uri;
  @override
  String toString() => "File: '$path'";
}

class _SealedConsumer implements StreamConsumer<List<int>> {
  _SealedConsumer(this._file, this._mode);
  final SealedFile _file;
  final FileMode _mode;
  RandomAccessFile? _f;

  RandomAccessFile get _out => _f ??= _file.openSync(mode: _mode);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final b in stream) {
      _out.writeFromSync(b);
    }
  }

  @override
  Future<void> close() async {
    _out.closeSync();
  }
}
