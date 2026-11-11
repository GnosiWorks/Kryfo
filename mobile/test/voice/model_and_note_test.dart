// SPDX-License-Identifier: GPL-3.0-or-later
// the model's path and the note's samples come together: a note read for a
// model that is missing or failed its check is zeroed before it goes
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice/voice_ffi.dart';
import 'package:kryfo/voice/voice_transcripts.dart';

VoiceAudio _note() =>
    VoiceAudio(Int16List.fromList([3, -7, 12, 900]), 16000, 1);

void main() {
  test('both there: both given', () async {
    final a = _note();
    final (m, got) = await modelAndNote(
      Future.value('/m.bin'),
      Future.value(a),
    );
    expect(m, '/m.bin');
    expect(got.pcm, [3, -7, 12, 900]);
  });

  test('no model: the note is zeroed, a model error', () async {
    final a = _note();
    await expectLater(
      modelAndNote(Future.value(null), Future.value(a)),
      throwsA(
        isA<VoiceError>().having((e) => e.code, 'code', VoiceError.model),
      ),
    );
    expect(a.pcm, everyElement(0));
  });

  test('the check throws: the note is zeroed, the error passed on', () async {
    final a = _note();
    await expectLater(
      modelAndNote(Future.error(StateError('engine')), Future.value(a)),
      throwsA(isA<StateError>()),
    );
    expect(a.pcm, everyElement(0));
  });

  test('no audio or an empty note: an audio error', () async {
    await expectLater(
      modelAndNote(Future.value('/m.bin'), Future.value(null)),
      throwsA(
        isA<VoiceError>().having((e) => e.code, 'code', VoiceError.audio),
      ),
    );
    await expectLater(
      modelAndNote(
        Future.value('/m.bin'),
        Future.value(VoiceAudio(Int16List(0), 16000, 1)),
      ),
      throwsA(
        isA<VoiceError>().having((e) => e.code, 'code', VoiceError.audio),
      ),
    );
  });
}
