// SPDX-License-Identifier: GPL-3.0-or-later
// voice transcripts ship off: the switch is off, nothing is built behind
// it, no screen reaches lib/voice, the app carries none of its strings and
// the android build does not package the library
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice/voice_ffi.dart';
import 'package:kryfo/voice/voice_models.dart';
import 'package:kryfo/voice/voice_transcripts.dart';

Iterable<File> _dart(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('the switch is off', () {
    expect(kVoiceTranscripts, isFalse);
  });

  test('nothing is built while it is off', () {
    VoiceTranscripts.instance = null;
    expect(voiceTranscriptsIfOn(), isNull);
    // a second ask does not build one either
    expect(voiceTranscriptsIfOn(), isNull);
    expect(VoiceTranscripts.instance, isNull);
  });

  test('a test can stand one in', () {
    final t = VoiceTranscripts(
      models: VoiceModels(
        call: (_, _) async => 'error: none',
        dir: () async => '/tmp/v',
        quiet: () => false,
      ),
      library: () => null,
    );
    VoiceTranscripts.instance = t;
    addTearDown(() => VoiceTranscripts.instance = null);
    expect(voiceTranscriptsIfOn(), same(t));
  });

  test('no file outside lib/voice reaches it', () {
    final reach = RegExp(r'''import\s+['"](package:kryfo/|(\.\./)*)voice/''');
    final hits = [
      for (final f in _dart('lib'))
        if (!f.path.startsWith('lib/voice/') &&
            reach.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(hits, isEmpty);
  });

  test('lib/voice draws nothing', () {
    for (final f in _dart('lib/voice')) {
      final s = f.readAsStringSync();
      expect(
        s,
        isNot(contains('package:flutter/material.dart')),
        reason: f.path,
      );
      expect(
        s,
        isNot(contains('package:flutter/widgets.dart')),
        reason: f.path,
      );
      expect(s, isNot(contains('AppLocalizations')), reason: f.path);
    }
  });

  test('none of its strings are in the app yet', () {
    final arb = File('lib/l10n/app_en.arb').readAsStringSync();
    for (final key in [
      'voiceSeeTranscription',
      'voiceTranscribing',
      'voiceHideTranscription',
      'voiceTranslatedMark',
      'voiceShowOriginalOnly',
      'voiceCouldNotTranscribe',
    ]) {
      expect(arb, isNot(contains('"$key"')), reason: key);
    }
  });

  test('the android build does not package the library', () {
    final hits = [
      for (final f
          in Directory('android')
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (f) => !f.path.contains('/build/') && !f.path.endsWith('.so'),
              ))
        if (RegExp(r'\.(kts|gradle|xml|properties|pro)$').hasMatch(f.path))
          for (final line in f.readAsLinesSync())
            if (line.contains('kryfo_voice')) '${f.path}: ${line.trim()}',
    ];
    // the one mention is gradle leaving it out
    expect(hits, [
      'android/app/build.gradle.kts: excludes += "**/libkryfo_voice.so"',
    ]);
    expect(VoiceLibrary.hostBuilt, contains('build/host'));
  });

  test('no copy of the library sits in jniLibs', () {
    final jni = Directory('android/app/src/main/jniLibs');
    final hits = [
      if (jni.existsSync())
        for (final f in jni.listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('/libkryfo_voice.so')) f.path,
    ];
    expect(hits, isEmpty);
  });

  test(
    'the voice build copies into the app only when asked by its own name',
    () {
      // engine/build.sh reads JNI_LIBS_DIR and a release exports it, so a
      // shared name would carry the library into a release
      final sh = File('../engine/voice/native/build.sh').readAsStringSync();
      final reads = RegExp(
        r'\$\{?(\w*JNI_LIBS_DIR)',
      ).allMatches(sh).map((m) => m[1]).toSet();
      expect(reads, {'KV_JNI_LIBS_DIR'});
    },
  );
}
