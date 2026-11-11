// SPDX-License-Identifier: GPL-3.0-or-later
// the voice library through its dart bindings: a run streams its segments
// in order and ends with a language, a cancel ends it early with nothing
// after, bad input comes back as a code. the library is built by
// engine/voice/native/build-host.sh and the model is whisper.cpp's own
// small test model from the pinned source; without them every test skips
// and says so. KRYFO_VOICE_REAL_MODEL=<a ggml model> adds the words.
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice/voice_audio.dart';
import 'package:kryfo/voice/voice_ffi.dart';

String? _whisperSrc() {
  final lock = File('../engine/voice/native/whisper.lock');
  if (!lock.existsSync()) return null;
  final commit = RegExp(
    r'^WHISPER_COMMIT=(\w+)$',
    multiLine: true,
  ).firstMatch(lock.readAsStringSync())?.group(1);
  final dir = Directory(
    '../engine/voice/native/.third_party/whisper.cpp-$commit',
  );
  return dir.existsSync() ? dir.absolute.path : null;
}

final VoiceLibrary? _lib = VoiceLibrary.forHostTests();
final String? _src = _whisperSrc();
final String? _model = _src == null
    ? null
    : '$_src/models/for-tests-ggml-tiny.bin';
final VoiceAudio? _jfk = _src == null
    ? null
    : voiceAudioOfWav(File('$_src/samples/jfk.wav').readAsBytesSync());
final String? _real = Platform.environment['KRYFO_VOICE_REAL_MODEL'];

final Object _needs = _lib == null || _jfk == null
    ? 'libkryfo_voice or the whisper.cpp source missing: run '
          'engine/voice/native/build-host.sh, or point ${VoiceLibrary.envVar} '
          'at the library'
    : false;

VoiceAudio _repeat(VoiceAudio a, int k) {
  final out = Int16List(a.pcm.length * k);
  for (var i = 0; i < k; i++) {
    out.setAll(i * a.pcm.length, a.pcm);
  }
  return VoiceAudio(out, a.rate, a.channels);
}

Future<int> _codeOf(Future<VoiceResult> f) async {
  try {
    await f;
    return 0;
  } on VoiceError catch (e) {
    return e.code;
  }
}

// the skip guards these: a test that runs has them all
VoiceLibrary get lib => _lib!;
String get model => _model!;
VoiceAudio get jfk => _jfk!;
String get real => _real!;

void main() {
  test('a library of another abi or none is refused', () {
    expect(VoiceLibrary.open('/nonexistent/libkryfo_voice.so'), isNull);
  });

  test('a run streams its segments and ends', () async {
    final run = lib.transcribe(
      model: model,
      audio: jfk,
      lang: 'en',
      threads: 2,
    );
    final seen = <VoiceSegment>[];
    final sub = run.segments.listen(seen.add);
    final r = await run.done;
    await sub.asFuture<void>();
    expect(r.lang, 'en');
    expect(r.segments.length, seen.length);
    for (var i = 0; i < seen.length; i++) {
      expect(seen[i].index, i);
      expect(seen[i].start <= seen[i].end, isTrue);
    }
  }, skip: _needs);

  test('the language is detected when none is asked for', () async {
    final r = await lib.transcribe(model: model, audio: jfk).done;
    expect(r.lang.length, greaterThanOrEqualTo(2));
  }, skip: _needs);

  test('a cancel ends a long run early and nothing comes after', () async {
    final run = lib.transcribe(
      model: model,
      audio: _repeat(jfk, 20),
      lang: 'en',
      threads: 2,
    );
    var closed = false;
    var after = 0;
    var cancelled = false;
    run.segments.listen((_) {
      if (cancelled) after++;
    }, onDone: () => closed = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final sw = Stopwatch()..start();
    cancelled = true;
    run.cancel();
    expect(await _codeOf(run.done), VoiceError.cancelled);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isTrue);
    expect(after, 0);
    // the native run stops at whisper's next check, long before the
    // twenty copies would be through
    await run.finished.timeout(const Duration(seconds: 10));
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    // a second cancel after the end is harmless
    run.cancel();
    final again = await lib
        .transcribe(model: model, audio: jfk, lang: 'en')
        .done;
    expect(again.lang, 'en');
  }, skip: _needs);

  test('cancelled before it starts', () async {
    final run = lib.transcribe(model: model, audio: jfk);
    run.cancel();
    expect(await _codeOf(run.done), VoiceError.cancelled);
  }, skip: _needs);

  test('bad input comes back as a code', () async {
    expect(
      await _codeOf(lib.transcribe(model: '/nonexistent.bin', audio: jfk).done),
      VoiceError.model,
    );
    expect(
      await _codeOf(
        lib.transcribe(model: model, audio: jfk, lang: 'xx-nope').done,
      ),
      VoiceError.args,
    );
    expect(
      await _codeOf(
        lib
            .transcribe(model: model, audio: VoiceAudio(Int16List(0), 16000, 1))
            .done,
      ),
      VoiceError.audio,
    );
    expect(
      await _codeOf(
        lib.transcribe(model: model, audio: VoiceAudio(jfk.pcm, 1000, 1)).done,
      ),
      VoiceError.audio,
    );
  }, skip: _needs);

  test('a library that does not load ends the run, not the app', () async {
    final run = const VoiceLibrary.unchecked(
      '/nonexistent/libkryfo_voice.so',
    ).transcribe(model: model, audio: jfk);
    expect(await _codeOf(run.done), VoiceError.library);
  }, skip: _needs);

  test(
    'real words',
    () async {
      final run = lib.transcribe(model: real, audio: jfk);
      final parts = <String>[];
      run.segments.listen((s) => parts.add(s.text));
      final r = await run.done;
      // the segments streamed in before the result
      expect(parts, isNotEmpty);
      expect(parts.length, r.segments.length);
      expect(r.lang, 'en');
      expect(parts.join(), contains('fellow Americans'));
      // a piece starts a sentence, so its first word can come capitalised
      expect(
        r.text.toLowerCase(),
        contains('ask not what your country can do for you'),
      );
    },
    skip: _needs != false
        ? _needs
        : (_real == null ? 'KRYFO_VOICE_REAL_MODEL not set' : false),
  );

  test('the voice goes from native memory before it is handed back', () {
    final p = calloc<Int16>(4000);
    addTearDown(() => calloc.free(p));
    p.asTypedList(4000).setAll(0, List.generate(4000, (i) => i - 2000));
    wipePcm(p, 4000);
    expect(p.asTypedList(4000).every((v) => v == 0), isTrue);
    wipePcm(p, 0);
  });
}
