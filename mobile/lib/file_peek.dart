// SPDX-License-Identifier: GPL-3.0-or-later
// a glance into a text or code file: its first lines, read through the
// seal into memory and dropped as the lock goes up
import 'dart:convert';
import 'dart:io';

import 'picture_lock.dart' show picturesShut;

/// first lines read, by path. a handful, gone with the lock
final Map<String, List<String>> _firstLines = {};

/// what a reader shows of a text: tabs as spaces, the marks that turn text
/// around or hide it drawn as a replacement mark, so a line never reads
/// other than it is
String visibleText(String s) => s
    .replaceAll('\t', '  ')
    .replaceAll(
      RegExp('[\u200E\u200F\u202A-\u202E\u2066-\u2069\u061C\uFEFF]'),
      '\uFFFD',
    )
    .replaceAll(RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '');

/// true when [bytes] read as words: no zero byte in what was read
bool looksLikeText(List<int> bytes) => !bytes.contains(0);

/// the first [n] lines of [path], null when it does not read as words
Future<List<String>?> firstLinesOf(String path, {int n = 4}) async {
  final had = _firstLines[path];
  if (had != null) return had;
  final b = <int>[];
  try {
    await for (final c in File(path).openRead(0, 1536)) {
      b.addAll(c);
    }
  } catch (_) {
    return null;
  }
  if (picturesShut.value || !looksLikeText(b)) return null;
  final text = utf8.decode(b, allowMalformed: true);
  final lines = const LineSplitter()
      .convert(text)
      .map(visibleText)
      .skipWhile((l) => l.trim().isEmpty)
      .take(n)
      .toList();
  if (lines.isEmpty) return null;
  if (_firstLines.length >= 40) _firstLines.remove(_firstLines.keys.first);
  return _firstLines[path] = lines;
}

/// the lock is going up: no words of a file stay in memory
void forgetFirstLines() => _firstLines.clear();

/// the first lines already read for [path]
List<String>? firstLinesNow(String path) => _firstLines[path];

/// [path] is going: its first lines go with it
void forgetFirstLinesOf(String path) => _firstLines.remove(path);
