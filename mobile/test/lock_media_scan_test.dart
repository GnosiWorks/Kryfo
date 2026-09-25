// SPDX-License-Identifier: GPL-3.0-or-later
// what the app lock's layer cannot cover by drawing: sound, the microphone,
// the camera and anything android draws itself run outside the widget tree.
// every file that makes one has to hand it to the lock (closeOnLock), and a
// new one that does not fails here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dart(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.contains('/l10n/'));

void main() {
  test('everything that plays, records, films or draws natively stops for '
      'the lock, in the class that makes it', () {
    final makes = RegExp(
      r'\bAudioPlayer\(|\bAudioRecorder\(|\bCameraController\(|'
      r'\bReaderWidget\(|'
      r"MethodChannel\('kryfo/video'\)|"
      r'\bAndroidView\(|\bPlatformViewLink\(|\bHtmlElementView\(|'
      r'\bTexture\(|\bVideoPlayerController\b|\bWebView',
    );
    var found = 0;
    final missing = <String>[];
    for (final f in _dart('lib')) {
      final s = f.readAsStringSync();
      final classes = _classes(s);
      for (final m in makes.allMatches(s)) {
        found++;
        // the innermost class around it has to hand something to the lock;
        // made outside any class, the file has to
        final around = classes
            .where((c) => c.start < m.start && m.start < c.end)
            .fold<({int start, int end})?>(
              null,
              (best, c) => best == null || c.start > best.start ? c : best,
            );
        final body = around == null ? s : s.substring(around.start, around.end);
        if (!body.contains('closeOnLock(')) {
          final line = '\n'.allMatches(s.substring(0, m.start)).length + 1;
          missing.add('${f.path}:$line ${m.group(0)}');
        }
      }
    }
    expect(found, greaterThan(4), reason: 'the scan found the media');
    expect(missing, isEmpty, reason: 'made where nothing stops it');
  });

  test('secret fields are never offered to the autofill service', () {
    final bad = <String>[];
    for (final f in _dart('lib')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('obscureText:')) continue;
        final near = lines.skip(i).take(4).join('\n');
        if (!near.contains('autofillHints: null')) {
          bad.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(bad, isEmpty);
  });
}

// the spans of every class body, by counting braces from `class X ... {`.
// strings and comments with braces in them are rare in these files and
// only make a span wider
List<({int start, int end})> _classes(String s) {
  final out = <({int start, int end})>[];
  for (final m in RegExp(
    r'^(?:abstract |final |base )?class \w+[^{]*\{',
    multiLine: true,
  ).allMatches(s)) {
    var depth = 0;
    for (var i = m.end - 1; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) {
          out.add((start: m.start, end: i));
          break;
        }
      }
    }
  }
  return out;
}
