// SPDX-License-Identifier: GPL-3.0-or-later
// voice notes on linux: just_audio's player, as the bubbles use it, over a
// gstreamer pipe
import 'dart:async';

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

  test('gstreamer loads where it is installed', () {
    final g = Gst.instance;
    if (g == null) {
      markTestSkipped('no gstreamer here');
      return;
    }
    // a pipe of an element the system lacks is refused, not crashed
    expect(() => GstPipe(g, element: 'no-such-element'), throwsStateError);
  });
}
