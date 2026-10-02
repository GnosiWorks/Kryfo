// SPDX-License-Identifier: GPL-3.0-or-later
// the name a file leaves under. the receiver sees it on the bubble, in the
// notification and on the saved copy, so a gallery name such as
// PXL_20261001_101502123.mp4 would give away when it was taken, to the
// second, and often on what. those leave under a name made here instead,
// keeping only the extension the receiver needs to open it.
import 'dart:math';

import 'open_file.dart' show nameSaysVideo;

final _rnd = Random.secure();

const _pictureExts = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'heif',
  'avif',
  'gif',
  'bmp',
  'dng',
};
const _audioExts = {'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'flac', 'amr'};

// a date as cameras, scanners, recorders and chat apps write one:
// 20261001, 2026-10-01, 2026-10-1, 2026_1001, 01.10.2026, 12-25-2026,
// 1-10-2026, 12252026, 261001. digits around it do not hide it
const _mm = r'(0[1-9]|1[0-2]|[1-9](?!\d))';
const _dd = r'(0[1-9]|[12]\d|3[01]|[1-9](?!\d))';
const _yyyy = r'(19|20)\d\d';
// either order, day first or month first, one digit or two
const _dm = r'(0?[1-9]|[12]\d|3[01])';
final _dates = [
  RegExp('(?<!\\d)$_yyyy(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])'),
  RegExp('(?<!\\d)$_yyyy[-_. ]$_mm[-_. ]$_dd'),
  RegExp('(?<!\\d)$_yyyy[-_. ](0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])(?!\\d)'),
  RegExp('(?<!\\d)$_dm[-_. ]$_dm[-_. ]$_yyyy(?!\\d)'),
  RegExp('(?<!\\d)(0[1-9]|[12]\\d|3[01]){2}$_yyyy(?!\\d)'),
  // a two digit year only standing on its own, as in IMG-261001-WA0001
  RegExp(
    '(?<![0-9A-Za-z])[0-3]\\d(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])'
    '(?![0-9A-Za-z])',
  ),
];

// unix time in seconds or milliseconds, 2008 to 2042
final _epoch = RegExp(r'(?<!\d)(1[2-9]|2[0-2])\d{8}(\d{3})?(?!\d)');

/// true when [name] carries a date or a moment in time
bool nameTellsTime(String name) =>
    _dates.any((r) => r.hasMatch(name)) || _epoch.hasMatch(name);

String _ext(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return '';
  final e = name.substring(dot + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(e) ? e : '';
}

String _tag() => [
  for (var i = 0; i < 4; i++) _rnd.nextInt(256),
].map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// a name made here for a file shaped like [name]: what kind it is, a few
/// random letters so two saved ones do not collide, and its extension
String madeName(String name, {String? fallbackExt}) {
  var ext = _ext(name);
  if (ext.isEmpty) ext = fallbackExt ?? '';
  final kind = _pictureExts.contains(ext)
      ? 'photo'
      : nameSaysVideo('x.$ext')
      ? 'video'
      : _audioExts.contains(ext)
      ? 'audio'
      : 'file';
  return ext.isEmpty ? '${kind}_${_tag()}' : '${kind}_${_tag()}.$ext';
}

/// a video from the gallery or the camera never leaves under a name of
/// its own
String madeVideoName([String picked = '']) =>
    madeName(picked, fallbackExt: 'mp4');

/// a file picked by hand keeps the name it was given, unless that name
/// tells when it was made
String sentFileName(String name) => nameTellsTime(name) ? madeName(name) : name;
