// SPDX-License-Identifier: GPL-3.0-or-later
// voice notes on linux: just_audio's player, as the bubbles use it, over a
// gstreamer pipe
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:kryfo/desktop/desktop_audio.dart';

class _Pipe implements AudioPipe {
  String? loaded;
  bool playing = false;
  bool atEnd = false;
  String? broke;
  Duration at = Duration.zero;
  final calls = <String>[];
  Duration? length = const Duration(seconds: 3);

  @override
  Future<Duration?> load(String path) async {
    calls.add('load');
    loaded = path;
    return length;
  }

  @override
  void play() {
    calls.add('play');
    playing = true;
  }

  @override
  void pause() {
    calls.add('pause');
    playing = false;
  }

  @override
  void seek(Duration to) {
    calls.add('seek ${to.inMilliseconds}');
    at = to;
  }

  @override
  void volume(double v) => calls.add('volume $v');

  @override
  Duration position() => at;

  @override
  bool ended() {
    final e = atEnd;
    atEnd = false;
    return e;
  }

  @override
  String? failed() {
    final b = broke;
    broke = null;
    return b;
  }

  @override
  void dispose() => calls.add('dispose');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Pipe pipe;
  setUp(() {
    pipe = _Pipe();
    JustAudioPlatform.instance = DesktopAudio(pipe: () => pipe);
  });

  test('a file loads with its length, plays, pauses and ends', () async {
    final player = AudioPlayer();
    final d = await player.setFilePath('/tmp/v.wav');
    expect(d, const Duration(seconds: 3));
    expect(pipe.loaded, '/tmp/v.wav');
    expect(player.processingState, ProcessingState.ready);
    unawaited(player.play());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(pipe.playing, isTrue);
    expect(player.playing, isTrue);
    await player.pause();
    expect(pipe.playing, isFalse);
    unawaited(player.play());
    final done = player.processingStateStream.firstWhere(
      (s) => s == ProcessingState.completed,
    );
    pipe.atEnd = true;
    await done.timeout(const Duration(seconds: 2));
    await player.seek(Duration.zero);
    expect(pipe.calls, contains('seek 0'));
    await player.dispose();
    expect(pipe.calls.last, 'dispose');
  });

  test('a file the system cannot play fails its load, calmly', () async {
    pipe.length = null;
    final player = AudioPlayer();
    await expectLater(player.setFilePath('/tmp/x.opus'), throwsA(anything));
    await player.dispose();
  });

  test('a failure while playing reaches the player', () async {
    final player = AudioPlayer();
    await player.setFilePath('/tmp/v.wav');
    final err = player.errorStream.first;
    final idle = player.processingStateStream.firstWhere(
      (st) => st == ProcessingState.idle,
    );
    unawaited(player.play());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    pipe.broke = 'gone';
    expect((await err.timeout(const Duration(seconds: 2))).message, 'gone');
    await idle.timeout(const Duration(seconds: 2));
    await player.dispose();
  });

  test('only files play, never a url', () async {
    final player = AudioPlayer();
    await expectLater(
      player.setUrl('https://example.org/a.mp3'),
      throwsA(anything),
    );
    expect(pipe.loaded, isNull);
    await player.dispose();
  });

  test('a file plays only as ogg or wav, chosen by its first bytes', () {
    List<int> b(String s) => s.codeUnits;
    expect(voiceKindOf(b('OggS\x00\x02')), VoiceKind.ogg);
    expect(voiceKindOf(b('RIFF\x24\x00\x00\x00WAVEfmt ')), VoiceKind.wav);
    // a riff that is not wave, an mp4, a matroska, nothing at all
    expect(voiceKindOf(b('RIFF\x24\x00\x00\x00AVI LIST')), isNull);
    expect(voiceKindOf(b('\x00\x00\x00\x18ftypmp42')), isNull);
    expect(voiceKindOf([0x1a, 0x45, 0xdf, 0xa3]), isNull);
    expect(voiceKindOf(const []), isNull);
  });

  test('the pipelines are fixed: no autoplug, no video', () {
    for (final k in VoiceKind.values) {
      final d = voicePipeline(k);
      expect(d, startsWith('filesrc name=src ! '));
      expect(d, endsWith('autoaudiosink'));
      for (final bad in [
        'playbin',
        'decodebin',
        'uridecodebin',
        'video',
        'location',
      ]) {
        expect(d.contains(bad), isFalse, reason: bad);
      }
    }
    expect(voicePipeline(VoiceKind.ogg), contains('oggdemux ! opusdec'));
    expect(voicePipeline(VoiceKind.wav), contains('wavparse'));
  });

  test('gstreamer turns down a file of another kind before any element', () {
    final g = Gst.instance;
    if (g == null) {
      markTestSkipped('no gstreamer here');
      return;
    }
    final dir = Directory.systemTemp.createTempSync('gst');
    addTearDown(() => dir.deleteSync(recursive: true));
    final mp4 = File('${dir.path}/a.wav')
      ..writeAsBytesSync([0, 0, 0, 0x18, ...'ftypmp42'.codeUnits]);
    final pipe = GstPipe(g);
    expect(pipe.build(mp4.path), isFalse);
    expect(pipe.build('${dir.path}/missing'), isFalse);
    pipe.dispose();
  });
}
