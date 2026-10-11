// SPDX-License-Identifier: GPL-3.0-or-later
// the voice disguise: as many samples out as in, so the speed stays; the
// pitch moves; the same seed gives the same note and each note draws its
// own; nothing clips
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice_mask.dart';

// [secs] of a voice-like tone at [hz], as the recorder writes it
Uint8List wav(double secs, {double hz = 160, double loud = 9000}) {
  const rate = 16000;
  final n = (secs * rate).round();
  final b = ByteData(44 + n * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
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
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    // a few harmonics falling off, like a voiced sound
    var v = 0.0;
    for (var h = 1; h <= 6; h++) {
      v += math.sin(2 * math.pi * hz * h * t) / h;
    }
    b.setInt16(44 + i * 2, (loud * v / 2).round().clamp(-32768, 32767));
  }
  return b.buffer.asUint8List();
}

Int16List samples(Uint8List w) =>
    Int16List.fromList(w.buffer.asInt16List(w.offsetInBytes + 44));

// the strongest period, by autocorrelation, as a frequency
double pitchOf(Int16List s, {int from = 4000, int len = 8000}) {
  var best = 0.0, at = 0;
  for (var lag = 40; lag <= 320; lag++) {
    var sum = 0.0;
    for (var i = from; i < from + len; i++) {
      sum += s[i] * s[i + lag];
    }
    if (sum > best) {
      best = sum;
      at = lag;
    }
  }
  return 16000 / at;
}

void main() {
  test('as many samples out as in, the header as it was', () {
    for (final secs in [0.4, 1.0, 2.37]) {
      final w = wav(secs);
      final m = maskWav(w, seed: 1)!;
      expect(m.length, w.length);
      expect(m.sublist(0, 44), w.sublist(0, 44));
      expect(m.sublist(44), isNot(w.sublist(44)));
    }
  });

  test('an empty or tiny take stays as long as it was', () {
    for (final secs in [0.0, 0.001, 0.02]) {
      final w = wav(secs);
      expect(maskWav(w, seed: 1)!.length, w.length);
    }
  });

  test('the pitch moves up and the speed does not', () {
    final w = wav(1.5);
    final before = pitchOf(samples(w));
    final draw = MaskDraw.from(math.Random(3));
    final m = maskWav(w, seed: 3)!;
    final after = pitchOf(samples(m));
    expect(before, closeTo(160, 4));
    // within the slow wander around the draw
    expect(after / before, closeTo(draw.pitch, draw.pitch * 0.04));
    expect(samples(m).length, samples(w).length);
  });

  test('the same seed makes the same note', () {
    final w = wav(1.2);
    expect(maskWav(w, seed: 42), maskWav(w, seed: 42));
  });

  test('each note draws its own disguise', () {
    final w = wav(1.2);
    expect(maskWav(w, seed: 1), isNot(maskWav(w, seed: 2)));
    // without a seed every call draws fresh
    expect(maskWav(w), isNot(maskWav(w)));
  });

  test('the draws stay in a narrow band', () {
    final r = math.Random(9);
    final pitches = <double>{}, formants = <double>{};
    for (var i = 0; i < 400; i++) {
      final d = MaskDraw.from(r);
      expect(
        d.pitch,
        inInclusiveRange(math.pow(2, 3 / 12), math.pow(2, 4.2 / 12)),
      );
      expect(d.formant, inInclusiveRange(1.12, 1.17));
      pitches.add(d.pitch);
      formants.add(d.formant);
    }
    // and they do vary
    expect(pitches.length, greaterThan(300));
    expect(formants.length, greaterThan(300));
  });

  test('a loud take never clips', () {
    final w = wav(1.5, loud: 32767);
    final m = samples(maskWav(w, seed: 5)!);
    var top = 0;
    for (final v in m) {
      top = math.max(top, v.abs());
    }
    expect(top, lessThan(32767));
    expect(top, greaterThan(20000));
  });

  test('anything but 16-bit pcm is left alone', () {
    final w = wav(0.5);
    // 8-bit
    final eight = Uint8List.fromList(w)..[34] = 8;
    expect(maskWav(eight), isNull);
    expect(maskWav(Uint8List.fromList('not a wav'.codeUnits)), isNull);
  });

  test('off the calling isolate it is the same note', () async {
    final w = wav(0.8);
    expect(await maskWavOff(w, seed: 11), maskWav(w, seed: 11));
  });
}
