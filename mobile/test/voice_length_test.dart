// SPDX-License-Identifier: GPL-3.0-or-later
// a voice note's length is shown to the nearest second, and read from the
// samples its wav holds
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/voice_length.dart';

// [frames] of 16-bit mono at [rate]. [sized] false leaves the lengths at
// zero, as a recorder that never finished its head does
Uint8List lengthWav(int frames, {int rate = 16000, bool sized = true}) {
  final b = ByteData(44 + frames * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, sized ? 36 + frames * 2 : 0, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, sized ? frames * 2 : 0, Endian.little);
  return b.buffer.asUint8List();
}

void main() {
  tearDown(() => setL10nLocale(const Locale('en')));

  group('the clock', () {
    test('rounds to the nearest second', () {
      expect(voiceClock(0), '0:00');
      expect(voiceClock(490), '0:00');
      expect(voiceClock(499), '0:00');
      expect(voiceClock(500), '0:01');
      expect(voiceClock(3900), '0:04');
      expect(voiceClock(4400), '0:04');
      expect(voiceClock(4500), '0:05');
      expect(voiceClock(59499), '0:59');
      expect(voiceClock(59500), '1:00');
      expect(voiceClock(61000), '1:01');
    });

    test('hours', () {
      expect(voiceClock(3599499), '59:59');
      expect(voiceClock(3599500), '1:00:00');
      expect(voiceClock(3661000), '1:01:01');
      expect(voiceClock(36000000), '10:00:00');
    });

    test('nothing below zero', () {
      expect(voiceClock(-1), '0:00');
      expect(voiceClock(-900), '0:00');
    });

    test('in the language digits', () {
      setL10nLocale(const Locale('fa'));
      expect(voiceClock(4500), '۰:۰۵');
    });
  });

  group('the length of a wav', () {
    test('from its head', () {
      expect(wavMs(lengthWav(62400)), 3900);
      expect(wavMs(lengthWav(69120)), 4320);
      expect(wavMs(lengthWav(0)), 0);
      expect(wavMs(lengthWav(44100, rate: 44100)), 1000);
    });

    test('a head never finished: the rest of the file', () {
      final b = lengthWav(69120, sized: false);
      expect(wavMs(b), 4320);
      // only the head read, the file's size given
      expect(wavMs(b.sublist(0, 44), b.length), 4320);
    });

    test('a data length past the end: the rest of the file', () {
      final b = lengthWav(16000);
      ByteData.sublistView(b).setUint32(40, 0x7fffffff, Endian.little);
      expect(wavMs(b), 1000);
    });

    test('anything not a pcm wav has none', () {
      expect(wavMs(Uint8List(0)), isNull);
      expect(wavMs(Uint8List.fromList(List.filled(64, 1))), isNull);
      final ogg = Uint8List.fromList('OggS'.codeUnits + List.filled(60, 0));
      expect(wavMs(ogg), isNull);
    });

    test('of a file, from its first bytes', () async {
      final dir = Directory.systemTemp.createTempSync('voice_len');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/vn.wav')
        ..writeAsBytesSync(lengthWav(16000 * 70 + 8000, sized: false));
      expect(await wavFileMs(f.path), 70500);
      expect(await wavFileMs('${dir.path}/none.wav'), isNull);
    });

    test('the recorder has samples once its file is past the head', () {
      final dir = Directory.systemTemp.createTempSync('voice_len');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/vn.wav');
      expect(samplesIn(f.path), isFalse);
      f.writeAsBytesSync(const []);
      expect(samplesIn(f.path), isFalse);
      f.writeAsBytesSync(lengthWav(0));
      expect(samplesIn(f.path), isFalse);
      f.writeAsBytesSync(lengthWav(160));
      expect(samplesIn(f.path), isTrue);
    });
  });
}
