// SPDX-License-Identifier: GPL-3.0-or-later
// what a file is, told by its first bytes before its name. the name is what
// the sender typed; the bytes are what another app would get. an app
// installer is known by the manifest inside its zip, whatever it is called.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'dart:isolate';

import 'package:flutter/foundation.dart' show ValueNotifier;

import 'file_name.dart';
import 'image_strip.dart' show PictureKind, pictureHead, pictureKind;
import 'mp4_strip.dart' show videoNameNeedsStrip;
import 'open_file.dart' show nameSaysVideo;

export 'file_name.dart' show shownFileName;

enum FileKind {
  installer,
  pdf,
  picture,
  video,
  audio,
  archive,
  document,
  text,
  other,
}

class FileFacts {
  final FileKind kind;
  // what the bytes are, as an extension: the name's own when the two agree
  // or the bytes say nothing
  final String ext;
  // what another app is told it is when the bytes and the name disagree.
  // null: the phone goes by the name
  final String? mime;
  // an iso media file (mp4, mov, 3gp), which the video cleaner walks
  final bool iso;
  // a picture the cleaner cannot read through: raw, tiff, psd, svg, jpeg xl
  final bool raw;
  const FileFacts(
    this.kind,
    this.ext, {
    this.mime,
    this.iso = false,
    this.raw = false,
  });
  bool get installer => kind == FileKind.installer;
}

// the most a file may be when it goes out. every slice of it crosses tor and
// a relay, and the receiver keeps the slices until the last one is in
const kMaxFileBytes = 15 * 1024 * 1024;

bool fileFits(int bytes) => bytes <= kMaxFileBytes;

const _installerExts = {'apk', 'apks', 'apkm', 'xapk', 'aab'};

const _extKinds = <String, FileKind>{
  'pdf': FileKind.pdf,
  'jpg': FileKind.picture,
  'jpeg': FileKind.picture,
  'png': FileKind.picture,
  'gif': FileKind.picture,
  'webp': FileKind.picture,
  'heic': FileKind.picture,
  'heif': FileKind.picture,
  'avif': FileKind.picture,
  'bmp': FileKind.picture,
  'svg': FileKind.picture,
  'dng': FileKind.picture,
  'tif': FileKind.picture,
  'tiff': FileKind.picture,
  'nef': FileKind.picture,
  'cr2': FileKind.picture,
  'cr3': FileKind.picture,
  'arw': FileKind.picture,
  'orf': FileKind.picture,
  'rw2': FileKind.picture,
  'raf': FileKind.picture,
  'jxl': FileKind.picture,
  'psd': FileKind.picture,
  'mp4': FileKind.video,
  'm4v': FileKind.video,
  'mov': FileKind.video,
  '3gp': FileKind.video,
  '3g2': FileKind.video,
  'mkv': FileKind.video,
  'webm': FileKind.video,
  'avi': FileKind.video,
  'mp3': FileKind.audio,
  'm4a': FileKind.audio,
  'aac': FileKind.audio,
  'ogg': FileKind.audio,
  'opus': FileKind.audio,
  'wav': FileKind.audio,
  'flac': FileKind.audio,
  'amr': FileKind.audio,
  'zip': FileKind.archive,
  'rar': FileKind.archive,
  '7z': FileKind.archive,
  'gz': FileKind.archive,
  'tgz': FileKind.archive,
  'tar': FileKind.archive,
  'jar': FileKind.archive,
  'doc': FileKind.document,
  'docx': FileKind.document,
  'xls': FileKind.document,
  'xlsx': FileKind.document,
  'ppt': FileKind.document,
  'pptx': FileKind.document,
  'odt': FileKind.document,
  'ods': FileKind.document,
  'odp': FileKind.document,
  'rtf': FileKind.document,
  'epub': FileKind.document,
  'txt': FileKind.text,
  'md': FileKind.text,
  'csv': FileKind.text,
  'json': FileKind.text,
  'xml': FileKind.text,
  'html': FileKind.text,
  'vcf': FileKind.text,
  'age': FileKind.other,
  'exe': FileKind.other,
};

final _extShape = RegExp(r'^[a-z0-9]{1,10}$');

/// the name's last extension, lowercased, or '' when it has none
String extOf(String? name) {
  if (name == null) return '';
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return '';
  final e = name.substring(dot + 1).toLowerCase();
  return _extShape.hasMatch(e) ? e : '';
}

// the extension of the name as it is saved, so x.apk. and an extension
// with something hidden in it are read as what they show
String _nameExt(String? name) => extOf(safeFileName(name));

bool nameSaysInstaller(String? name) => _installerExts.contains(_nameExt(name));

FileKind kindOfName(String? name) {
  final e = _nameExt(name);
  if (_installerExts.contains(e)) return FileKind.installer;
  return _extKinds[e] ?? FileKind.other;
}

class _Sniff {
  final FileKind kind;
  final String ext;
  final String? mime;
  // a container that holds more than one kind: the name says which
  final bool loose;
  final bool iso;
  final bool raw;
  const _Sniff(
    this.kind,
    this.ext,
    this.mime, {
    this.loose = false,
    this.iso = false,
    this.raw = false,
  });
}

bool _at(Uint8List b, int i, List<int> sig) {
  if (b.length < i + sig.length) return false;
  for (var j = 0; j < sig.length; j++) {
    if (b[i + j] != sig[j]) return false;
  }
  return true;
}

String _tag(Uint8List b, int i) =>
    b.length < i + 4 ? '' : String.fromCharCodes(b.sublist(i, i + 4));

bool isZipHead(Uint8List b) =>
    _at(b, 0, const [0x50, 0x4B, 0x03, 0x04]) ||
    _at(b, 0, const [0x50, 0x4B, 0x05, 0x06]);

const _innerApps = ['.apk', '.apks', '.xapk', '.apkm', '.aab'];

/// the entries of a zip that make it an app, a bundle of apps, or an app
/// carried inside it at any depth
bool zipHoldsInstaller(Iterable<String> names) {
  for (final n in names) {
    if (n == 'AndroidManifest.xml') return true;
    final l = n.toLowerCase();
    if (_innerApps.any(l.endsWith)) return true;
  }
  return false;
}

_Sniff? _sniff(Uint8List b, Iterable<String>? zipNames) {
  if (zipNames != null && zipHoldsInstaller(zipNames)) {
    return const _Sniff(FileKind.installer, 'apk', null);
  }
  if (isZipHead(b)) {
    // a docx, an epub and a jar are zips too
    return const _Sniff(
      FileKind.archive,
      'zip',
      'application/zip',
      loose: true,
    );
  }
  switch (pictureKind(b)) {
    case PictureKind.jpeg:
      return const _Sniff(FileKind.picture, 'jpg', 'image/jpeg');
    case PictureKind.png:
      return const _Sniff(FileKind.picture, 'png', 'image/png');
    case PictureKind.gif:
      return const _Sniff(FileKind.picture, 'gif', 'image/gif');
    case PictureKind.webp:
      return const _Sniff(FileKind.picture, 'webp', 'image/webp');
    case PictureKind.heif:
      return const _Sniff(FileKind.picture, 'heic', 'image/heif');
    case PictureKind.other:
      break;
  }
  final raw = _rawPicture(b);
  if (raw != null) return raw;
  if (_at(b, 0, '%PDF-'.codeUnits)) {
    return const _Sniff(FileKind.pdf, 'pdf', 'application/pdf');
  }
  if (_tag(b, 4) == 'ftyp') {
    final brand = _tag(b, 8);
    if (const {'M4A ', 'M4B ', 'M4P ', 'F4A '}.contains(brand)) {
      return const _Sniff(
        FileKind.audio,
        'm4a',
        'audio/mp4',
        loose: true,
        iso: true,
      );
    }
    if (brand == 'qt  ') {
      return const _Sniff(
        FileKind.video,
        'mov',
        'video/quicktime',
        loose: true,
        iso: true,
      );
    }
    if (brand.startsWith('3g')) {
      return const _Sniff(
        FileKind.video,
        '3gp',
        'video/3gpp',
        loose: true,
        iso: true,
      );
    }
    return const _Sniff(
      FileKind.video,
      'mp4',
      'video/mp4',
      loose: true,
      iso: true,
    );
  }
  if (_tag(b, 0) == 'RIFF' && _tag(b, 8) == 'WAVE') {
    return const _Sniff(FileKind.audio, 'wav', 'audio/wav');
  }
  if (_tag(b, 0) == 'RIFF' && _tag(b, 8) == 'AVI ') {
    return const _Sniff(FileKind.video, 'avi', 'video/x-msvideo');
  }
  if (_at(b, 0, 'ID3'.codeUnits)) {
    return const _Sniff(FileKind.audio, 'mp3', 'audio/mpeg');
  }
  if (_tag(b, 0) == 'OggS') {
    return const _Sniff(FileKind.audio, 'ogg', 'audio/ogg', loose: true);
  }
  if (_tag(b, 0) == 'fLaC') {
    return const _Sniff(FileKind.audio, 'flac', 'audio/flac');
  }
  if (_at(b, 0, '#!AMR'.codeUnits)) {
    return const _Sniff(FileKind.audio, 'amr', 'audio/amr');
  }
  if (_at(b, 0, const [0x1A, 0x45, 0xDF, 0xA3])) {
    return const _Sniff(FileKind.video, 'mkv', 'video/x-matroska', loose: true);
  }
  if (_at(b, 0, const [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07])) {
    return const _Sniff(FileKind.archive, 'rar', 'application/vnd.rar');
  }
  if (_at(b, 0, const [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) {
    return const _Sniff(FileKind.archive, '7z', 'application/x-7z-compressed');
  }
  if (_at(b, 0, const [0x1F, 0x8B])) {
    return const _Sniff(FileKind.archive, 'gz', 'application/gzip');
  }
  if (_at(b, 0, const [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])) {
    return const _Sniff(
      FileKind.document,
      'doc',
      'application/msword',
      loose: true,
    );
  }
  if (_at(b, 0, '{\\rtf'.codeUnits)) {
    return const _Sniff(FileKind.document, 'rtf', 'application/rtf');
  }
  if (_at(b, 0, 'MZ'.codeUnits)) {
    return const _Sniff(FileKind.other, 'exe', 'application/octet-stream');
  }
  return null;
}

// pictures the cleaner does not read through. tiff carries most cameras'
// raw files (dng, nef, cr2, arw), and canon's cr3 is an iso file the video
// cleaner would break without cleaning
_Sniff? _rawPicture(Uint8List b) {
  if (_at(b, 0, 'II*'.codeUnits + [0]) ||
      _at(b, 0, [0x4D, 0x4D, 0, 0x2A]) ||
      _at(b, 0, 'IIRO'.codeUnits) ||
      _at(b, 0, 'IIRS'.codeUnits) ||
      _at(b, 0, 'IIU'.codeUnits + [0])) {
    return const _Sniff(FileKind.picture, 'tiff', 'image/tiff', raw: true);
  }
  if (_at(b, 0, 'FUJIFILMCCD-RAW'.codeUnits)) {
    return const _Sniff(FileKind.picture, 'raf', 'image/x-fuji-raf', raw: true);
  }
  if (_at(b, 0, const [0xFF, 0x0A]) ||
      _at(b, 0, const [0, 0, 0, 0x0C, 0x4A, 0x58, 0x4C, 0x20])) {
    return const _Sniff(FileKind.picture, 'jxl', 'image/jxl', raw: true);
  }
  if (_at(b, 0, '8BPS'.codeUnits)) {
    return const _Sniff(
      FileKind.picture,
      'psd',
      'image/vnd.adobe.photoshop',
      raw: true,
    );
  }
  if (_tag(b, 4) == 'ftyp' && _tag(b, 8) == 'crx ') {
    return const _Sniff(
      FileKind.picture,
      'cr3',
      'image/x-canon-cr3',
      raw: true,
    );
  }
  final text = latin1.decode(b, allowInvalid: true).toLowerCase();
  final start = text.replaceFirst(RegExp(r'^\ufeff?\s*'), '');
  if ((start.startsWith('<svg') ||
          start.startsWith('<?xml') ||
          start.startsWith('<!doctype svg')) &&
      text.contains('<svg')) {
    return const _Sniff(FileKind.picture, 'svg', 'image/svg+xml', raw: true);
  }
  return null;
}

/// what a file with this [name] and these first bytes is. [zipNames] are
/// the entries of its zip directory, when it is one and could be read
FileFacts factsOf(
  String? name,
  Uint8List head, {
  Iterable<String>? zipNames,
  bool zipBroken = false,
}) {
  final ext = _nameExt(name);
  final byName = kindOfName(name);
  // a zip directory that is there and cannot be read through is taken for
  // an app: nothing vouches for what is in it
  if (zipBroken) {
    return FileFacts(
      FileKind.installer,
      byName == FileKind.installer ? ext : 'apk',
    );
  }
  final s = _sniff(head, zipNames);
  if (s?.kind == FileKind.installer) {
    return FileFacts(
      FileKind.installer,
      byName == FileKind.installer ? ext : 'apk',
    );
  }
  // named as one, it is one, whatever is inside
  if (byName == FileKind.installer) return FileFacts(FileKind.installer, ext);
  if (s == null) return FileFacts(byName, ext);
  if (s.raw) {
    return FileFacts(
      FileKind.picture,
      byName == FileKind.picture ? ext : s.ext,
      mime: byName == FileKind.picture ? null : s.mime,
      raw: true,
    );
  }
  if (s.kind == byName) return FileFacts(byName, ext, iso: s.iso);
  // mp4 and m4a, ogg audio and video, a zip and a docx share a container
  if (s.loose &&
      byName != FileKind.other &&
      (s.kind == FileKind.archive
          ? byName == FileKind.document
          : byName == FileKind.audio || byName == FileKind.video)) {
    return FileFacts(byName, ext, iso: s.iso);
  }
  return FileFacts(s.kind, s.ext, mime: s.mime, iso: s.iso);
}

int _u16(Uint8List b, int i) => b[i] | b[i + 1] << 8;
int _u32(Uint8List b, int i) => _u16(b, i) | _u16(b, i + 2) << 16;
int _u64(Uint8List b, int i) => _u32(b, i) + _u32(b, i + 4) * 0x100000000;

const _maxDirectory = 16 << 20;
const _maxEntries = 100000;

/// what the end of a file says about a zip directory: none there, its
/// entry names, or one there that cannot be read through
class ZipDir {
  final List<String>? names;
  final bool broken;
  const ZipDir._(this.names, this.broken);
  static const none = ZipDir._(null, false);
  static const unreadable = ZipDir._(null, true);
  bool get found => names != null || broken;
}

/// where the end record of a zip sits in [tail], the last [tail].length
/// bytes of a file of [len] bytes. as java and android read it: the
/// signature, with a comment that runs exactly to the end of the file
int? zipEndIn(Uint8List tail, int len) {
  final from = len - tail.length;
  for (var i = tail.length - 22; i >= 0; i--) {
    if (_u32(tail, i) != 0x06054b50) continue;
    if (from + i + 22 + _u16(tail, i + 20) == len) return i;
  }
  return null;
}

/// the names in a zip directory of [count] entries, or null when the
/// bytes do not read as one, or it has more entries than any app needs
List<String>? zipNamesIn(Uint8List d, int count) {
  if (count > _maxEntries) return null;
  final names = <String>[];
  var p = 0;
  while (names.length < count) {
    if (p + 46 > d.length || _u32(d, p) != 0x02014b50) return null;
    final n = _u16(d, p + 28);
    if (p + 46 + n > d.length) return null;
    names.add(utf8.decode(d.sublist(p + 46, p + 46 + n), allowMalformed: true));
    p += 46 + n + _u16(d, p + 30) + _u16(d, p + 32);
  }
  return names;
}

/// the zip directory at the end of [path], whatever its first bytes are.
/// the directory itself is read off the ui isolate: it can be megabytes
Future<ZipDir> zipDirOf(String path) async {
  final raf = await File(path).open();
  int len;
  int dirAt;
  int size;
  int count;
  try {
    len = await raf.length();
    final tailLen = min(len, 22 + 0xFFFF);
    await raf.setPosition(len - tailLen);
    final tail = await raf.read(tailLen);
    final e = zipEndIn(tail, len);
    if (e == null) return ZipDir.none;
    count = _u16(tail, e + 10);
    size = _u32(tail, e + 12);
    var end = len - tail.length + e;
    if (count == 0xFFFF ||
        size == 0xFFFFFFFF ||
        _u32(tail, e + 16) == 0xFFFFFFFF) {
      // zip64: its locator sits just before
      final l = e - 20;
      if (l < 0 || _u32(tail, l) != 0x07064b50) return ZipDir.unreadable;
      final rec = _u64(tail, l + 8);
      if (rec + 56 > len) return ZipDir.unreadable;
      await raf.setPosition(rec);
      final r = await raf.read(56);
      if (r.length < 56 || _u32(r, 0) != 0x06064b50) {
        return ZipDir.unreadable;
      }
      count = _u64(r, 32);
      size = _u64(r, 40);
      end = rec;
    }
    // the directory ends where the end record starts, as java finds it,
    // so bytes put in front of a zip move nothing
    dirAt = end - size;
    if (size > _maxDirectory || dirAt < 0 || count > _maxEntries) {
      return ZipDir.unreadable;
    }
  } finally {
    await raf.close();
  }
  final names = await Isolate.run(() {
    final f = File(path).openSync();
    try {
      f.setPositionSync(dirAt);
      final d = f.readSync(size);
      return d.length < size ? null : zipNamesIn(d, count);
    } finally {
      f.closeSync();
    }
  });
  return names == null ? ZipDir.unreadable : ZipDir._(names, false);
}

// a zip whose directory cannot be read still names its first entry up front
List<String>? _firstEntry(Uint8List head) {
  if (!_at(head, 0, const [0x50, 0x4B, 0x03, 0x04]) || head.length < 30) {
    return null;
  }
  final n = _u16(head, 26);
  if (30 + n > head.length) return null;
  return [utf8.decode(head.sublist(30, 30 + n), allowMalformed: true)];
}

final Map<String, FileFacts> _known = {};

/// facts already read for [path], or null
FileFacts? fileFactsNow(String path, String? name) => _known['$path\n$name'];

/// bumped each time a file's facts are first read, so a bubble drawn by
/// the name alone can be drawn again by what the bytes are
final fileFactsRead = ValueNotifier<int>(0);

enum FileShape { video, picture, card }

const _shownPictures = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
};

/// how a file is drawn in a chat. by the bytes once they are read, which
/// starts here; by the name until then. an app installer is always a card
FileShape fileShapeNow(String? path, String? name) {
  final facts = path == null ? null : fileFactsNow(path, name);
  if (facts == null) {
    if (path != null) readFileFacts(path, name);
    if (nameSaysInstaller(name)) return FileShape.card;
    if (nameSaysVideo(name)) return FileShape.video;
    if (_shownPictures.contains(_nameExt(name))) return FileShape.picture;
    return FileShape.card;
  }
  return fileShapeOf(facts);
}

FileShape fileShapeOf(FileFacts facts) => switch (facts.kind) {
  FileKind.video => FileShape.video,
  FileKind.picture when _shownPictures.contains(facts.ext) => FileShape.picture,
  _ => FileShape.card,
};

Future<Uint8List?> _head(String path) async {
  RandomAccessFile? raf;
  try {
    raf = await File(path).open();
    return await pictureHead(raf);
  } catch (_) {
    return null;
  } finally {
    await raf?.close();
  }
}

/// an iso media file with a video's brand, told by its bytes: the video
/// cleaner walks it whatever it is called
Future<bool> bytesSayIsoVideo(String path) async {
  final head = await _head(path);
  if (head == null) return false;
  final f = factsOf(null, head);
  return f.iso && f.kind == FileKind.video;
}

/// whether the send lane cleans this file: a picture told by its bytes, or
/// a video the cleaner walks. anything else goes exactly as it is
Future<bool> sendLaneCleans(String path, String name) async {
  final head = await _head(path);
  if (head == null) return false;
  if (_rawPicture(head) != null) return false;
  if (videoNameNeedsStrip(name)) return true;
  if (pictureKind(head) != PictureKind.other) return true;
  final f = factsOf(null, head);
  return f.iso && f.kind == FileKind.video;
}

/// an installer by its name, or by its bytes once they have been read
bool knownInstaller(String path, String? name) =>
    nameSaysInstaller(name) || (fileFactsNow(path, name)?.installer ?? false);

final Map<String, Future<FileFacts>> _reading = {};

/// reads what [path] is. a file that cannot be read goes by its name, and
/// is read again next time
Future<FileFacts> readFileFacts(String path, String? name) {
  final key = '$path\n$name';
  final had = _known[key];
  if (had != null) return Future.value(had);
  return _reading[key] ??= _readAndKeep(path, name, key).whenComplete(() {
    _reading.remove(key);
  });
}

Future<FileFacts> _readAndKeep(String path, String? name, String key) async {
  final out = await readFileFactsFresh(path, name);
  if (out == null) return FileFacts(kindOfName(name), _nameExt(name));
  if (_known.length >= 300) _known.remove(_known.keys.first);
  _known[key] = out;
  fileFactsRead.value++;
  return out;
}

/// what [path] is, read now and kept nowhere: a picker's copy can be a
/// different file under the same path next time. null when it cannot be
/// read
Future<FileFacts?> readFileFactsFresh(String path, String? name) async {
  try {
    final Uint8List head;
    final raf = await File(path).open();
    try {
      head = await pictureHead(raf);
    } finally {
      await raf.close();
    }
    final dir = await zipDirOf(path);
    final names = dir.names ?? (dir.found ? null : _firstEntry(head));
    return factsOf(name, head, zipNames: names, zipBroken: dir.broken);
  } catch (_) {
    return null;
  }
}

bool _knownExt(String e) =>
    _extKinds.containsKey(e) || _installerExts.contains(e);

/// a name fit to show, save or hand to another app. an installer always
/// ends in an installer's extension. see cleanFileName
String safeFileName(String? name, {FileFacts? facts, int maxBytes = 200}) =>
    cleanFileName(
      name,
      installerExt: facts != null && facts.installer ? 'apk' : null,
      isExt: _knownExt,
      isInstallerExt: _installerExts.contains,
      maxBytes: maxBytes,
    );
