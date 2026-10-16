// SPDX-License-Identifier: GPL-3.0-or-later
// the voice disguise: as many samples out as in, so the speed stays; the
// pitch moves; the same seed gives the same note and each note draws its
// own; the hiss of a consonant is kept; nothing clips
import 'dart:async';
import 'dart:io';
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
    b.setInt16(
      44 + i * 2,
      (loud * v / 2).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  return b.buffer.asUint8List();
}

Int16List samples(Uint8List w) =>
    Int16List.fromList(w.buffer.asInt16List(w.offsetInBytes + 44));

// the period, by autocorrelation, as a frequency. the shortest lag near
// the strongest: a periodic sound scores as high at twice its period
double pitchOf(Int16List s, {int from = 4000, int len = 8000}) {
  final sums = <double>[];
  var best = 0.0;
  for (var lag = 40; lag <= 320; lag++) {
    var sum = 0.0;
    for (var i = from; i < from + len; i++) {
      sum += s[i] * s[i + lag];
    }
    sums.add(sum);
    if (sum > best) best = sum;
  }
  final at = sums.indexWhere((v) => v >= best * 0.95);
  return 16000 / (40 + at);
}

// a voice with a hiss bursting on and off, like an s, little-endian as
// the recorder writes it
Uint8List _hissy(double secs) {
  const rate = 16000;
  final n = (secs * rate).round();
  final w = wav(secs);
  final d = ByteData.sublistView(w);
  final r = math.Random(1);
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    var v = 0.0;
    for (var h = 1; h <= 6; h++) {
      v += math.sin(2 * math.pi * 160 * h * t) / h;
    }
    final hiss = (t * 4).floor().isEven ? r.nextDouble() - 0.5 : 0.0;
    d.setInt16(44 + 2 * i, (3000 * v + 6000 * hiss).round(), Endian.little);
  }
  return w;
}

// the share of a take's energy between [lo] and [hi] hz, over a few
// windows, by a plain dft
double _share(Uint8List w, double lo, double hi) {
  const n = 1024, rate = 16000;
  final d = ByteData.sublistView(w);
  var part = 0.0, all = 0.0;
  for (var f = 0; f < 4; f++) {
    final at = 44 + 2 * (2000 + f * 8000);
    final x = [
      for (var i = 0; i < n; i++)
        d.getInt16(at + 2 * i, Endian.little) *
            (0.5 - 0.5 * math.cos(2 * math.pi * i / n)),
    ];
    for (var k = 1; k < n ~/ 2; k++) {
      var re = 0.0, im = 0.0;
      for (var i = 0; i < n; i++) {
        final a = 2 * math.pi * k * i / n;
        re += x[i] * math.cos(a);
        im -= x[i] * math.sin(a);
      }
      final p = re * re + im * im;
      all += p;
      final hz = k * rate / n;
      if (hz >= lo && hz < hi) part += p;
    }
  }
  return part / all;
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
      expect(d.formant, inInclusiveRange(1.15, 1.2));
      pitches.add(d.pitch);
      formants.add(d.formant);
    }
    // and they do vary
    expect(pitches.length, greaterThan(300));
    expect(formants.length, greaterThan(300));
  });

  test('the hiss of a consonant is kept, up to 7 khz', () {
    // a voice with an s bursting on and off
    final w = _hissy(2.2);
    final before = _share(w, 5500, 7000);
    expect(before, greaterThan(0.02));
    for (final seed in [1, 2, 3]) {
      final after = _share(maskWav(w, seed: seed)!, 5500, 7000);
      expect(after, greaterThan(before * 0.3), reason: 'seed $seed');
    }
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

  group('from file to file', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('mask_file'));
    tearDown(() => dir.deleteSync(recursive: true));

    String put(String name, Uint8List b) {
      final f = File('${dir.path}/$name')..writeAsBytesSync(b);
      return f.path;
    }

    test('a piece at a time, off the calling isolate, it is the note made '
        'whole', () async {
      for (final (i, w) in [
        wav(0.8),
        _hissy(2.2),
        wav(0.0),
        wav(0.01),
        // longer than a piece
        _hissy(5.3),
        // two channels, read as one
        _stereo(wav(1.3)),
        // a chunk after the samples, left out
        _tail(wav(0.9)),
      ].indexed) {
        final from = put('vn_$i.wav', w);
        final to = '${dir.path}/vn_${i}_m.wav';
        expect(await maskWavFile(from, to, seed: 11), isTrue, reason: '$i');
        expect(File(to).readAsBytesSync(), maskWav(w, seed: 11), reason: '$i');
        // the take is left as it was, and nothing on the way is left
        expect(File(from).readAsBytesSync(), w);
        expect(dir.listSync().map((e) => e.path).toSet(), {
          from,
          to,
        }, reason: '$i');
        File(from).deleteSync();
        File(to).deleteSync();
      }
    });

    test('anything but 16-bit pcm: false, and nothing written', () async {
      final eight = Uint8List.fromList(wav(0.5))..[34] = 8;
      for (final w in [eight, Uint8List.fromList('not a wav'.codeUnits)]) {
        final from = put('vn_x.wav', w);
        final to = '${dir.path}/vn_x_m.wav';
        expect(await maskWavFile(from, to), isFalse);
        expect(dir.listSync().map((e) => e.path), [from]);
      }
      expect(
        await maskWavFile('${dir.path}/gone.wav', '${dir.path}/gone_m.wav'),
        isFalse,
      );
    });

    test('a length short of the samples: nothing past it goes, made whole '
        'or a piece at a time', () async {
      final w = wav(2);
      final half = (w.length - 44) ~/ 2;
      ByteData.sublistView(w).setUint32(40, half, Endian.little);
      final from = put('vn_short.wav', w);
      final to = '${dir.path}/vn_short_m.wav';
      expect(await maskWavFile(from, to, seed: 4), isTrue);
      for (final m in [File(to).readAsBytesSync(), maskWav(w, seed: 4)!]) {
        expect(m.length, 44 + half);
        final d = ByteData.sublistView(m);
        // the head says what the file holds
        expect(d.getUint32(4, Endian.little), m.length - 8);
        expect(d.getUint32(40, Endian.little), half);
        expect(m.sublist(44), isNot(w.sublist(44, 44 + half)));
      }
    });

    test('stopped part way: false, and nothing of it is left', () async {
      final from = put('vn_long.wav', wav(240));
      final to = '${dir.path}/vn_long_m.wav';
      var last = 0.0;
      final first = Completer<void>();
      final job = startMaskFile(
        from,
        to,
        onProgress: (p) {
          last = p;
          if (!first.isCompleted) first.complete();
        },
      );
      await first.future;
      job.cancel();
      expect(await job.done, isFalse);
      expect(last, lessThan(0.5));
      expect(dir.listSync().map((e) => e.path), [from]);
    });

    test('stopped on its last tick: false, and the note made is shredded '
        'too', () async {
      for (var i = 0; i < 4; i++) {
        final from = put('vn_t$i.wav', wav(3));
        final to = '${dir.path}/vn_t${i}_m.wav';
        late MaskJob job;
        job = startMaskFile(
          from,
          to,
          onProgress: (p) {
            if (p >= 1.0) job.cancel();
          },
        );
        expect(await job.done, isFalse, reason: '$i');
        expect(dir.listSync().map((e) => e.path), [from], reason: '$i');
        File(from).deleteSync();
      }
    });

    test('run out, it says how far it went, to the end', () async {
      final from = put('vn_p.wav', wav(5));
      final to = '${dir.path}/vn_p_m.wav';
      final seen = <double>[];
      final job = startMaskFile(from, to, seed: 2, onProgress: seen.add);
      expect(await job.done, isTrue);
      expect(seen.last, 1.0);
      expect(File(to).readAsBytesSync(), maskWav(wav(5), seed: 2));
      // a stop after the end leaves the note to whoever has it
      job.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(File(to).existsSync(), isTrue);
    });

    test('the disguise goes next to its take', () {
      expect(maskPathOf('/c/vn_1757.wav'), '/c/vn_1757_m.wav');
    });
  });
}

// the same samples on two channels
Uint8List _stereo(Uint8List w) {
  final n = (w.length - 44) ~/ 2;
  final d = ByteData.sublistView(w);
  final b = ByteData(44 + n * 4);
  final o = b.buffer.asUint8List()..setRange(0, 44, w);
  b.setUint32(4, 36 + n * 4, Endian.little);
  b.setUint16(22, 2, Endian.little);
  b.setUint32(28, 16000 * 4, Endian.little);
  b.setUint16(32, 4, Endian.little);
  b.setUint32(40, n * 4, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = d.getInt16(44 + 2 * i, Endian.little);
    b.setInt16(44 + 4 * i, v, Endian.little);
    b.setInt16(46 + 4 * i, (v * 0.7).round(), Endian.little);
  }
  return o;
}

// a chunk after the samples, as some recorders write
Uint8List _tail(Uint8List w) => Uint8List.fromList([
  ...w,
  ...'LIST'.codeUnits,
  6,
  0,
  0,
  0,
  ...'kryfo!'.codeUnits,
]);
