// SPDX-License-Identifier: GPL-3.0-or-later
// segment text across segments: a character whisper cut between two
// segments comes out whole in the second, never as replacement marks
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice/voice_ffi.dart';

void main() {
  test('a three-byte character cut between segments', () {
    final t = VoiceSegmentText();
    // 日本 is e6 97 a5 e6 9c ac
    final b = utf8.encode('日本');
    expect(t.add(b.sublist(0, 2)), '');
    expect(t.add(b.sublist(2)), '日本');
  });

  test('arabic, persian and an emoji cut at every byte', () {
    for (final s in ['سلام دنیا', 'خوبی؟', 'ok 🎙️ done', 'naïve café']) {
      final b = utf8.encode(s);
      for (var cut = 0; cut <= b.length; cut++) {
        final t = VoiceSegmentText();
        final joined = t.add(b.sublist(0, cut)) + t.add(b.sublist(cut));
        expect(joined, s, reason: '$s cut at $cut');
      }
    }
  });

  test('a byte no character could start still reads as a mark', () {
    final t = VoiceSegmentText();
    expect(t.add([0x68, 0xff, 0x69]), 'h�i');
    expect(t.add(utf8.encode(' ok')), ' ok');
  });

  test('plain segments pass through', () {
    final t = VoiceSegmentText();
    expect(t.add(utf8.encode(' And so my fellow')), ' And so my fellow');
    expect(t.add(utf8.encode(' Americans')), ' Americans');
    expect(t.add(const []), '');
  });
}
