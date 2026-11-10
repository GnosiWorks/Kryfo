// SPDX-License-Identifier: GPL-3.0-or-later
// voice transcripts ship off: the switch is off, nothing is built behind
// it, the screens reach it only through the switch, the engine side draws
// nothing, and the android build does not package the library
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

  test('screens reach it only through the switch', () {
    final reach = RegExp(
      r'''import\s+['"](?:package:kryfo/|(?:\.\./)*)voice/([\w/]+\.dart)['"]([^;]*);''',
    );
    final hits = <String>{};
    for (final f in _dart('lib')) {
      if (f.path.startsWith('lib/voice/')) continue;
      for (final m in reach.allMatches(f.readAsStringSync())) {
        hits.add(
          '${f.path}: ${m[1]}${m[2]!.trim().isEmpty ? '' : ' ${m[2]!.trim()}'}',
        );
      }
    }
    expect(hits, {
      'lib/screens/chat_screen.dart: chat_transcripts.dart',
      'lib/screens/chat_screen.dart: ui/transcript_line.dart',
      'lib/screens/chat_screen.dart: voice_transcripts.dart show voiceTranscriptsIfOn',
      'lib/screens/chat_screen.dart: voice_text.dart show theirWordsLang',
      'lib/screens/group_chat_screen.dart: chat_transcripts.dart',
      'lib/screens/group_chat_screen.dart: ui/transcript_line.dart',
      'lib/screens/group_chat_screen.dart: voice_transcripts.dart show voiceTranscriptsIfOn',
      'lib/screens/group_chat_screen.dart: voice_text.dart show theirWordsLang',
      'lib/screens/licences_screen.dart: voice_transcripts.dart show kVoiceTranscripts',
      'lib/screens/settings_screen.dart: ui/voice_tx_screen.dart',
      'lib/screens/settings_screen.dart: voice_transcripts.dart show voiceTranscriptsIfOn',
    });
  });

  test('the engine side draws nothing; only lib/voice/ui does', () {
    for (final f in _dart('lib/voice')) {
      if (f.path.startsWith('lib/voice/ui/')) continue;
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
      // the app's language tag is no string of its own
      expect(
        s.replaceAll(
          "import '../l10n/app_locale.dart' show currentLanguage;",
          '',
        ),
        isNot(contains('l10n')),
        reason: f.path,
      );
    }
  });

  test('its strings are in the app, in every language', () {
    for (final l in [
      'en', 'ar', 'de', 'es', 'fa', 'fr', 'hi', 'id', 'it', 'pt', 'ru', //
      'tr', 'uk', 'vi', 'zh', 'zh_Hant',
    ]) {
      final arb = File('lib/l10n/app_$l.arb').readAsStringSync();
      for (final key in [
        'voiceSeeTranscription',
        'voiceTranscribing',
        'voiceHideTranscription',
        'voiceShowOriginalOnly',
        'voiceCouldNotTranscribe',
        'voiceModelPrivacy',
        'voiceModelPrivacyDesk',
      ]) {
        expect(arb, contains('"$key"'), reason: '$l $key');
      }
    }
  });

  test('while off, the android build leaves the library out', () {
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
    // the one mention is gradle leaving it out, and it goes with the switch
    expect(hits, [
      if (!kVoiceTranscripts)
        'android/app/build.gradle.kts: excludes += "**/libkryfo_voice.so"',
    ]);
    expect(VoiceLibrary.hostBuilt, contains('build/host'));
  });

  test('while off, no copy of the library sits in jniLibs', () {
    final jni = Directory('android/app/src/main/jniLibs');
    final hits = [
      if (jni.existsSync())
        for (final f in jni.listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('/libkryfo_voice.so')) f.path,
    ];
    expect(hits, kVoiceTranscripts ? anything : isEmpty);
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

  test('the release builds it into the app\'s jniLibs, from the pin', () {
    // the reproducible build, after the engine and the shim
    final repro = File('../repro/build-repro.sh').readAsStringSync();
    expect(repro, contains('bash ../engine/voice/native/fetch-whisper.sh'));
    expect(
      repro,
      contains(
        'KV_JNI_LIBS_DIR="\$SRC/mobile/android/app/src/main/jniLibs" \\\n'
        '  bash "\$SRC/engine/voice/native/build.sh"',
      ),
    );
    // its offline build keeps the tarball fetch-whisper.sh checks
    final release = File('../repro/release.sh').readAsStringSync();
    expect(release, contains('KV_DL=engine/voice/native/.third_party/dl'));
    expect(release, contains('cp -a cache/whisper/. "\$WORK/src/\$KV_DL/"'));
    // the f-droid recipe takes the srclib at the pinned commit
    final lock = File('../engine/voice/native/whisper.lock').readAsStringSync();
    final commit = RegExp(
      r'^WHISPER_COMMIT=(\w+)$',
      multiLine: true,
    ).firstMatch(lock)![1]!;
    final releasing = File('../RELEASING.md').readAsStringSync();
    expect(releasing, contains('whisper.cpp@$commit'));
    expect(releasing, contains('KV_WHISPER_DIR=\$\$whisper.cpp\$\$'));
    expect(
      releasing,
      contains('KV_JNI_LIBS_DIR=\$(pwd)/android/app/src/main/jniLibs'),
    );
  });
}
