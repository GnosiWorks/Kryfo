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
      'the lock', () {
    final makes = RegExp(
      r'\bAudioPlayer\(|\bAudioRecorder\(|\bCameraController\(|'
      r'\bReaderWidget\(|'
      r"MethodChannel\('kryfo/video'\)|"
      r'\bAndroidView\(|\bPlatformViewLink\(|\bHtmlElementView\(|'
      r'\bTexture\(|\bVideoPlayerController\b|\bWebView',
    );
    final missing = <String>[];
    for (final f in _dart('lib')) {
      final s = f.readAsStringSync();
      if (!makes.hasMatch(s)) continue;
      if (!s.contains('closeOnLock(')) missing.add(f.path);
    }
    expect(missing, isEmpty, reason: 'no closeOnLock in these files');
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
