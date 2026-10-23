// SPDX-License-Identifier: GPL-3.0-or-later
// the transcriber's view of a voice note's wav: 16-bit pcm in, samples and
// format out, anything else refused, a take cut short read up to its end
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice/voice_audio.dart';

Uint8List _chunk(String tag, List<int> body) {
  final b = BytesBuilder()
    ..add(tag.codeUnits)
    ..add(
      (ByteData(
        4,
      )..setUint32(0, body.length, Endian.little)).buffer.asUint8List(),
    )
    ..add(body);
  if (body.length.isOdd) b.addByte(0);
  return b.toBytes();
}

List<int> _fmt({
  int format = 1,
  int channels = 1,
  int rate = 16000,
  int bits = 16,
}) {
  final d = ByteData(16)
    ..setUint16(0, format, Endian.little)
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, rate, Endian.little)
    ..setUint32(8, rate * channels * bits ~/ 8, Endian.little)
    ..setUint16(12, channels * bits ~/ 8, Endian.little)
    ..setUint16(14, bits, Endian.little);
  return d.buffer.asUint8List();
}

List<int> _pcm(List<int> samples) {
  final d = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    d.setInt16(2 * i, samples[i], Endian.little);
  }
  return d.buffer.asUint8List();
}

Uint8List _wav(List<Uint8List> chunks) {
  final body = BytesBuilder()..add('WAVE'.codeUnits);
  for (final c in chunks) {
    body.add(c);
  }
  final b = body.toBytes();
  return (BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add(
          (ByteData(
            4,
          )..setUint32(0, b.length, Endian.little)).buffer.asUint8List(),
        )
        ..add(b))
      .toBytes();
}

void main() {
  test('reads a recorder wav', () {
    final a = voiceAudioOfWav(
      _wav([
        _chunk('fmt ', _fmt()),
        _chunk('data', _pcm([0, 1, -1, 32767, -32768])),
      ]),
    )!;
    expect(a.rate, 16000);
    expect(a.channels, 1);
    expect(a.frames, 5);
    expect(a.pcm, [0, 1, -1, 32767, -32768]);
  });

  test('skips chunks it does not need, padding included', () {
    final a = voiceAudioOfWav(
      _wav([
        _chunk('fmt ', _fmt(channels: 2, rate: 44100)),
        _chunk('LIST', [1, 2, 3]),
        _chunk('data', _pcm([5, 6, 7, 8])),
      ]),
    )!;
    expect(a.rate, 44100);
    expect(a.channels, 2);
    expect(a.frames, 2);
    expect(a.pcm, [5, 6, 7, 8]);
  });

  test('takes the extensible header', () {
    final fmt = _fmt(format: 0xfffe) + List.filled(24, 0);
    expect(
      voiceAudioOfWav(
        _wav([
          _chunk('fmt ', fmt),
          _chunk('data', _pcm([1])),
        ]),
      )?.pcm,
      [1],
    );
  });

  test('a take cut short is read to its last whole frame', () {
    final full = _wav([
      _chunk('fmt ', _fmt(channels: 2)),
      _chunk('data', _pcm([1, 2, 3, 4, 5, 6])),
    ]);
    final cut = Uint8List.sublistView(full, 0, full.length - 3);
    final a = voiceAudioOfWav(cut)!;
    expect(a.pcm, [1, 2, 3, 4]);
  });

  test('refuses what it cannot read', () {
    final data = _chunk('data', _pcm([1, 2]));
    for (final w in [
      Uint8List(0),
      Uint8List.fromList('RIFF....WAVX'.codeUnits),
      _wav([_chunk('fmt ', _fmt(bits: 8)), data]),
      _wav([_chunk('fmt ', _fmt(bits: 24)), data]),
      _wav([_chunk('fmt ', _fmt(format: 3, bits: 32)), data]),
      _wav([_chunk('fmt ', _fmt(channels: 0)), data]),
      _wav([data]),
      _wav([_chunk('fmt ', _fmt().sublist(0, 12))]),
      _wav([_chunk('fmt ', _fmt())]),
    ]) {
      expect(voiceAudioOfWav(w), isNull);
    }
  });
}
