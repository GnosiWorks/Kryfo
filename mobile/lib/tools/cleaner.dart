// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import '../image_strip.dart';
import '../meta/file_source.dart';
import '../meta/meta_reader.dart';
import '../mp4_strip.dart';
import '../l10n/l10n.dart';

const kMaxPictureBytes = 64 << 20;

enum CleanFailure { unknownKind, motion, tooLarge, unreadable, notClean, disk }

class CleanResult {
  final MetaReport before;
  final String? path;
  final String? name;
  final String? mime;
  final int bytes;
  final CleanFailure? failure;
  const CleanResult({
    required this.before,
    this.path,
    this.name,
    this.mime,
    this.bytes = 0,
    this.failure,
  });
}

const _ext = {
  MetaKind.jpeg: 'jpg',
  MetaKind.png: 'png',
  MetaKind.webp: 'webp',
  MetaKind.heif: 'heic',
  MetaKind.gif: 'gif',
  MetaKind.mp4: 'mp4',
};

const _mime = {
  MetaKind.jpeg: 'image/jpeg',
  MetaKind.png: 'image/png',
  MetaKind.webp: 'image/webp',
  MetaKind.heif: 'image/heic',
  MetaKind.gif: 'image/gif',
  MetaKind.mp4: 'video/mp4',
};

final _dateLike = RegExp(r'\d{6,}');
final _suffix = RegExp(r'\.([A-Za-z0-9]{1,5})$');
final _unsafe = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

String cleanName(String? original, MetaKind kind) {
  final ext = _ext[kind] ?? 'bin';
  var base = (original ?? '').replaceAll(_unsafe, '_').trim();
  var had = '';
  final m = _suffix.firstMatch(base);
  if (m != null) {
    had = m.group(1)!.toLowerCase();
    base = base.substring(0, m.start);
  }
  base = base.replaceAll(RegExp(r'^[. ]+'), '').trim();
  if (base.isEmpty || _dateLike.hasMatch(base)) {
    base = kind == MetaKind.mp4 ? 'video' : 'photo';
  }
  if (base.length > 60) base = base.substring(0, 60).trim();
  final keep = const {'mov', 'm4v', '3gp', 'avif', 'jpeg'}.contains(had);
  return '$base clean.${keep && _sameFamily(had, kind) ? had : ext}';
}

bool _sameFamily(String ext, MetaKind kind) => switch (ext) {
  'mov' || 'm4v' || '3gp' => kind == MetaKind.mp4,
  'avif' => kind == MetaKind.heif,
  'jpeg' => kind == MetaKind.jpeg,
  _ => false,
};

String cleanMime(MetaKind kind, String name) {
  if (name.endsWith('.mov')) return 'video/quicktime';
  if (name.endsWith('.3gp')) return 'video/3gpp';
  if (name.endsWith('.avif')) return 'image/avif';
  return _mime[kind] ?? 'application/octet-stream';
}

MetaReport readFile(String path) {
  final src = FileSource.open(path);
  try {
    return readMeta(src);
  } finally {
    src.close();
  }
}

Future<MetaReport> readFileOffUi(String path) =>
    Isolate.run(() => readFile(path));

Future<CleanResult> cleanFile(
  String inPath,
  String outRoot, {
  String? originalName,
}) => Isolate.run(() => cleanFileHere(inPath, outRoot, originalName));

Future<CleanResult> cleanFileHere(
  String inPath,
  String outRoot,
  String? originalName,
) async {
  final before = readFile(inPath);
  CleanResult fail(CleanFailure f) => CleanResult(before: before, failure: f);

  if (before.kind == MetaKind.unknown) return fail(CleanFailure.unknownKind);
  if (before.status == MetaStatus.unreadable) {
    return fail(CleanFailure.unreadable);
  }
  if (before.embeddedVideo || before.secondImage) {
    return fail(CleanFailure.motion);
  }
  final size = File(inPath).lengthSync();
  if (before.kind != MetaKind.mp4 && size > kMaxPictureBytes) {
    return fail(CleanFailure.tooLarge);
  }

  final rnd = Random.secure();
  final tag = List.generate(
    8,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final dir = Directory('$outRoot/$tag');
  final name = cleanName(originalName, before.kind);
  final out = File('${dir.path}/$name');
  try {
    dir.createSync(recursive: true);
    File(inPath).copySync(out.path);
  } on FileSystemException {
    _drop(dir);
    return fail(CleanFailure.disk);
  }

  try {
    final ok = before.kind == MetaKind.mp4
        ? await stripMp4Metadata(out.path)
        : await stripPictureFile(out.path);
    if (ok != true) {
      _drop(dir);
      return fail(CleanFailure.unreadable);
    }
    final after = readFile(out.path);
    if (after.status != MetaStatus.nothing || after.kind != before.kind) {
      _drop(dir);
      return fail(CleanFailure.notClean);
    }
  } on FileSystemException {
    _drop(dir);
    return fail(CleanFailure.disk);
  }

  return CleanResult(
    before: before,
    path: out.path,
    name: name,
    mime: cleanMime(before.kind, name),
    bytes: out.lengthSync(),
  );
}

void _drop(Directory dir) {
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } on FileSystemException {
    return;
  }
}

class RemovedLine {
  final String label;
  final String? detail;
  const RemovedLine(this.label, [this.detail]);
}

List<RemovedLine> removedLines(MetaReport r) {
  final out = <RemovedLine>[];
  if (r.gps != null) {
    out.add(RemovedLine(l10n.cleanerLocation));
  } else if (r.gpsBlank) {
    out.add(
      RemovedLine(l10n.cleanerLocation, l10n.cleanerAlreadyBlankedByAndroid),
    );
  }
  final phone = [r.make, r.model].whereType<String>().join(' ').trim();
  if (phone.isNotEmpty) out.add(RemovedLine(l10n.cleanerPhoneModel, phone));
  if (r.taken != null || r.created != null) {
    out.add(RemovedLine(l10n.cleanerTimeTaken));
  }
  if (r.serial != null) out.add(RemovedLine(l10n.cleanerSerialNumber));
  if (r.owner != null || r.copyright != null) {
    out.add(RemovedLine(l10n.cleanerOwnerName));
  }
  if (r.thumbnailBytes > 0) out.add(RemovedLine(l10n.cleanerHiddenThumbnail));
  if (r.credentials) out.add(RemovedLine(l10n.cleanerContentCredentials));
  if (r.trailingBytes > 0) {
    out.add(RemovedLine(l10n.cleanerDataAfterThePicture));
  }
  var other = r.otherExifTags + r.textKeys.length + r.videoTags.length;
  other += r.extra.length;
  for (final b in [
    r.software != null,
    r.lens != null,
    r.offset != null,
    r.xmp,
    r.iptc,
    r.makerNote,
    r.comment,
    r.savedTime,
    r.stamps && r.created == null,
  ]) {
    if (b) other++;
  }
  if (other > 0) {
    out.add(
      RemovedLine(
        other == 1 ? l10n.cleaner1OtherField : l10n.cleanerOtherFields(other),
      ),
    );
  }
  return out;
}
