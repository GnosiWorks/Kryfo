// SPDX-License-Identifier: GPL-3.0-or-later
// what a file is, told by its first bytes before its name. the name is what
// the sender typed; the bytes are what another app would get. an app
// installer is known by the manifest inside its zip, whatever it is called.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'bidi_safe.dart';
import 'image_strip.dart' show PictureKind, pictureKind;
import 'mp4_strip.dart' show videoNameNeedsStrip;

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
  const FileFacts(this.kind, this.ext, {this.mime, this.iso = false});
  bool get installer => kind == FileKind.installer;
}

// the most a file may be when it goes out. every slice of it crosses tor and
// a relay, and the receiver keeps the slices until the last one is in
const kMaxFileBytes = 8 * 1024 * 1024;

const _installerExts = {'apk', 'apks', 'apkm', 'xapk'};

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

bool nameSaysInstaller(String? name) => _installerExts.contains(extOf(name));

FileKind kindOfName(String? name) {
  final e = extOf(name);
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
  const _Sniff(
    this.kind,
    this.ext,
    this.mime, {
    this.loose = false,
    this.iso = false,
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

/// the entries of a zip that make it an app or a bundle of apps
bool zipHoldsInstaller(Iterable<String> names) {
  final all = names.toSet();
  if (all.contains('AndroidManifest.xml')) return true;
  final apks = all.where((n) => n.toLowerCase().endsWith('.apk'));
  if (apks.isEmpty) return false;
  return all.contains('base.apk') ||
      all.contains('toc.pb') ||
      all.contains('manifest.json') ||
      all.contains('info.json') ||
      apks.any((n) => n.startsWith('splits/'));
}

_Sniff? _sniff(Uint8List b, Iterable<String>? zipNames) {
  if (isZipHead(b)) {
    if (zipNames != null && zipHoldsInstaller(zipNames)) {
      return const _Sniff(FileKind.installer, 'apk', null);
    }
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

/// what a file with this [name] and these first bytes is. [zipNames] are
/// the entries of its zip directory, when it is one and could be read
FileFacts factsOf(String? name, Uint8List head, {Iterable<String>? zipNames}) {
  final ext = extOf(name);
  final byName = kindOfName(name);
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

/// the entry names in the zip directory of [raf], null when it cannot be
/// read through
Future<List<String>?> zipEntryNames(RandomAccessFile raf) async {
  final len = await raf.length();
  final tailLen = min(len, 22 + 0xFFFF);
  await raf.setPosition(len - tailLen);
  final tail = await raf.read(tailLen);
  var e = -1;
  for (var i = tail.length - 22; i >= 0; i--) {
    if (_u32(tail, i) == 0x06054b50) {
      e = i;
      break;
    }
  }
  if (e < 0) return null;
  var count = _u16(tail, e + 10);
  var size = _u32(tail, e + 12);
  var at = _u32(tail, e + 16);
  if (count == 0xFFFF || size == 0xFFFFFFFF || at == 0xFFFFFFFF) {
    // zip64: its locator sits just before
    final l = e - 20;
    if (l < 0 || _u32(tail, l) != 0x07064b50) return null;
    final rec = _u64(tail, l + 8);
    if (rec + 56 > len) return null;
    await raf.setPosition(rec);
    final r = await raf.read(56);
    if (r.length < 56 || _u32(r, 0) != 0x06064b50) return null;
    count = _u64(r, 32);
    size = _u64(r, 40);
    at = _u64(r, 48);
  }
  if (size > _maxDirectory || at + size > len) return null;
  await raf.setPosition(at);
  final d = await raf.read(size);
  if (d.length < size) return null;
  final names = <String>[];
  var p = 0;
  while (names.length < count && names.length < _maxEntries) {
    if (p + 46 > d.length || _u32(d, p) != 0x02014b50) return null;
    final n = _u16(d, p + 28);
    if (p + 46 + n > d.length) return null;
    names.add(utf8.decode(d.sublist(p + 46, p + 46 + n), allowMalformed: true));
    p += 46 + n + _u16(d, p + 30) + _u16(d, p + 32);
  }
  return names;
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

Future<Uint8List?> _head(String path, int n) async {
  RandomAccessFile? raf;
  try {
    raf = await File(path).open();
    return await raf.read(n);
  } catch (_) {
    return null;
  } finally {
    await raf?.close();
  }
}

/// an iso media file with a video's brand, told by its bytes: the video
/// cleaner walks it whatever it is called
Future<bool> bytesSayIsoVideo(String path) async {
  final head = await _head(path, 64);
  if (head == null) return false;
  final f = factsOf(null, head);
  return f.iso && f.kind == FileKind.video;
}

/// whether the send lane cleans this file: a picture told by its bytes, or
/// a video the cleaner walks. anything else goes exactly as it is
Future<bool> sendLaneCleans(String path, String name) async {
  if (videoNameNeedsStrip(name)) return true;
  final head = await _head(path, 64);
  if (head == null) return false;
  if (pictureKind(head) != PictureKind.other) return true;
  final f = factsOf(null, head);
  return f.iso && f.kind == FileKind.video;
}

/// an installer by its name, or by its bytes once they have been read
bool knownInstaller(String path, String? name) =>
    nameSaysInstaller(name) || (fileFactsNow(path, name)?.installer ?? false);

/// reads what [path] is. a file that cannot be read goes by its name
Future<FileFacts> readFileFacts(String path, String? name) async {
  final key = '$path\n$name';
  final had = _known[key];
  if (had != null) return had;
  RandomAccessFile? raf;
  FileFacts out;
  try {
    raf = await File(path).open();
    final head = await raf.read(512);
    final names = isZipHead(head)
        ? await zipEntryNames(raf) ?? _firstEntry(head)
        : null;
    out = factsOf(name, head, zipNames: names);
  } catch (_) {
    out = FileFacts(kindOfName(name), extOf(name));
  } finally {
    await raf?.close();
  }
  if (_known.length >= 300) _known.remove(_known.keys.first);
  _known[key] = out;
  return out;
}

// characters that hide what a name says or break it on another system.
// the joiners stay: persian needs them
bool _hidden(int r) =>
    r < 0x20 ||
    (r >= 0x7F && r <= 0x9F) ||
    r == 0xAD ||
    r == 0x180E ||
    r == 0x200B ||
    r == 0x2028 ||
    r == 0x2029 ||
    (r >= 0x2060 && r <= 0x2064) ||
    r == 0xFEFF ||
    (r >= 0xFFF9 && r <= 0xFFFB) ||
    (r >= 0xE0000 && r <= 0xE007F);

const _reserved = r'/\:*?"<>|';

/// [name] as it is shown: no direction marks or hidden characters, the
/// rest as the sender wrote it
String shownFileName(String? name) {
  final s = String.fromCharCodes(
    unmarked(name ?? '').runes.where((r) => !_hidden(r)),
  ).trim();
  return s.isEmpty ? 'file' : s;
}

bool _knownExt(String s) {
  final e = s.toLowerCase();
  return _extKinds.containsKey(e) || _installerExts.contains(e);
}

/// a name fit to save under or hand to another app: nothing hidden, no
/// folder, no leading dot, and one extension only, so photo.jpg.apk is
/// saved as photo_jpg.apk. an installer always ends in one of its own
String safeFileName(String? name, {FileFacts? facts, int max = 120}) {
  var s = String.fromCharCodes(
    shownFileName(
      name,
    ).runes.map((r) => _reserved.contains(String.fromCharCode(r)) ? 0x5F : r),
  );
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  s = s.replaceAll(RegExp(r'^[\s.]+|[\s.]+$'), '');
  if (s.isEmpty) s = 'file';
  var stem = s;
  var ext = '';
  final dot = s.lastIndexOf('.');
  if (dot > 0 &&
      RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(s.substring(dot + 1))) {
    stem = s.substring(0, dot);
    ext = s.substring(dot + 1);
  }
  final parts = stem.split('.');
  final b = StringBuffer(parts.first);
  for (final p in parts.skip(1)) {
    b
      ..write(_knownExt(p) ? '_' : '.')
      ..write(p);
  }
  stem = b.toString();
  if (facts != null &&
      facts.installer &&
      !_installerExts.contains(ext.toLowerCase())) {
    if (ext.isNotEmpty) stem = '${stem}_$ext';
    ext = 'apk';
  }
  final room = max - (ext.isEmpty ? 0 : ext.length + 1);
  final runes = stem.runes.toList();
  if (runes.length > room) stem = String.fromCharCodes(runes.take(room));
  stem = stem.replaceAll(RegExp(r'[\s.]+$'), '');
  if (stem.isEmpty) stem = 'file';
  return ext.isEmpty ? stem : '$stem.$ext';
}
