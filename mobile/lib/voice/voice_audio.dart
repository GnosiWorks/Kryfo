// SPDX-License-Identifier: GPL-3.0-or-later
// the pcm in a voice note's wav, as the transcriber reads it. voice notes
// are 16-bit pcm wav (voice_mic.dart), disguised ones too (voice_mask.dart),
// so that is all this reads.

import 'dart:typed_data';

import 'voice_ffi.dart';

/// the samples of a 16-bit pcm wav, or null for anything else
VoiceAudio? voiceAudioOfWav(Uint8List wav) {
  if (wav.length < 12) return null;
  final d = ByteData.sublistView(wav);
  if (!_tag(wav, 0, 'RIFF') || !_tag(wav, 8, 'WAVE')) return null;
  int? rate;
  int? channels;
  var at = 12;
  while (at + 8 <= wav.length) {
    final size = d.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (_tag(wav, at, 'fmt ')) {
      if (size < 16 || body + 16 > wav.length) return null;
      final format = d.getUint16(body, Endian.little);
      final bits = d.getUint16(body + 14, Endian.little);
      // 1 is plain pcm, 0xfffe the extensible header some recorders write
      if ((format != 1 && format != 0xfffe) || bits != 16) return null;
      channels = d.getUint16(body + 2, Endian.little);
      rate = d.getUint32(body + 4, Endian.little);
    } else if (_tag(wav, at, 'data')) {
      if (rate == null || channels == null || channels < 1) return null;
      // a recorder cut off mid-take leaves a size past the end
      final avail = wav.length - body;
      var n = size > avail ? avail : size;
      n -= n % (2 * channels);
      final pcm = Int16List(n ~/ 2);
      for (var i = 0; i < pcm.length; i++) {
        pcm[i] = d.getInt16(body + 2 * i, Endian.little);
      }
      return VoiceAudio(pcm, rate, channels);
    }
    // chunks are padded to an even length
    at = body + size + (size & 1);
  }
  return null;
}

bool _tag(Uint8List b, int at, String tag) {
  if (at + 4 > b.length) return false;
  for (var i = 0; i < 4; i++) {
    if (b[at + i] != tag.codeUnitAt(i)) return false;
  }
  return true;
}
