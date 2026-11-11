// SPDX-License-Identifier: GPL-3.0-or-later
// segment text across segments: a character whisper cut between two
// segments comes out whole in the second, never as replacement marks
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kryfo/voice/voice_ffi.dart';
import 'package:kryfo/voice/voice_text.dart';

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

  group('what whisper says, made fit to show', () {
    test('notes on sounds are no words', () {
      for (final n in [
        ' [BLANK_AUDIO]',
        '[ Silence ]',
        ' (silence)',
        ' [MUSIC PLAYING]',
        ' *coughs*',
        ' ♪',
        ' [BLANK_AUDIO] (music)',
      ]) {
        expect(cleanSegment(n), '', reason: n);
      }
      expect(cleanSegment(' Hello [BLANK_AUDIO] there.'), ' Hello there.');
      // words in round brackets amid speech stay
      expect(cleanSegment(' see you (maybe) at 9'), ' see you (maybe) at 9');
    });

    test('chinese in simplified characters, whatever the model wrote', () {
      final gz = File('assets/opencc/STCharacters.txt.gz').readAsBytesSync();
      final h = HansChars.parse(utf8.decode(gzip.decode(gz)));
      // what the samsung run heard for simplified speech
      expect(cleanSegment('我剛到公司,地鐵說', hans: h), '我刚到公司,地铁说');
      // a character that is a simplified one itself stays
      expect(h.convert('著名的乾杯'), '著名的干杯');
      expect(h.convert('hello 你好'), 'hello 你好');
      // the model saying back its own lead line is no words
      for (final echo in [' 以下是普通话的句子。', '以下是普通话的句子', ' 以下是普通話的句子。']) {
        expect(cleanSegment(echo, hans: h), '', reason: echo);
      }
      expect(cleanSegment('以下是普通话的句子。我到了', hans: h), isNotEmpty);
      // the dart line is the one the library gives the model
      final c = File('../engine/voice/native/kryfo_voice.c').readAsStringSync();
      final esc = RegExp(
        r'#define KV_ZH_PROMPT\s+"([^"]+)"',
      ).firstMatch(c)![1]!;
      final bytes = [
        for (final m in RegExp(r'\\x([0-9a-f]{2})').allMatches(esc))
          int.parse(m[1]!, radix: 16),
      ];
      expect(utf8.decode(bytes), kZhPrompt);
    });

    test('no detection: the language is named', () {
      expect(whisperLang('zh_Hant'), 'zh');
      expect(whisperLang('pt-BR'), 'pt');
      expect(whisperLang('nb'), 'no');
      expect(whisperLang('fa'), 'fa');
      expect(whisperLang('xx'), isNull);
      expect(whisperLang(null), isNull);
      for (final l in [
        'en', 'ar', 'de', 'es', 'fa', 'fr', 'hi', 'id', 'it', 'pl', 'pt', //
        'ru', 'tr', 'uk', 'vi', 'zh', 'zh_Hant',
      ]) {
        expect(whisperLang(l), isNotNull, reason: l);
      }
      expect(noteLang(mine: false, theirs: 'de', app: 'en'), 'de');
      expect(noteLang(mine: true, theirs: 'de', app: 'ru'), 'ru');
      expect(noteLang(mine: false, theirs: null, app: 'zh_Hant'), 'zh');
      expect(noteLang(mine: false, theirs: 'xx', app: 'xx'), 'en');
    });

    test('their language from their words, only when clear', () {
      expect(
        theirWordsLang([
          'Wir sehen uns morgen am Bahnhof',
          'Ich bringe die Bücher mit, und du?',
        ]),
        'de',
      );
      expect(theirWordsLang(['ok', '👍']), isNull);
      expect(theirWordsLang(const []), isNull);
    });

    test('threads: the fast cores, never every core', () {
      // eight a53s at 2.3 and 1.8 ghz: six, two left for the ui and the
      // kernel
      expect(
        voiceThreads(cores: 8, maxFreq: (i) => i < 4 ? 1800000 : 2300000),
        6,
      );
      // one prime, three big, four little: the four fast ones
      expect(
        voiceThreads(
          cores: 8,
          maxFreq: (i) => i < 4 ? 1800000 : (i < 7 ? 2500000 : 3000000),
        ),
        4,
      );
      // six alike: four; four alike: three
      expect(voiceThreads(cores: 6, maxFreq: (_) => 2000000), 4);
      expect(voiceThreads(cores: 4, maxFreq: (_) => 2000000), 3);
      // unreadable: four at most
      expect(voiceThreads(cores: 8, maxFreq: (_) => null), 4);
      expect(voiceThreads(cores: 4, maxFreq: (_) => null), 3);
      // one or two cores: one thread
      expect(voiceThreads(cores: 2, maxFreq: (_) => 1000), 1);
      expect(voiceThreads(cores: 1, maxFreq: (_) => 1000), 1);
    });
  });
}
