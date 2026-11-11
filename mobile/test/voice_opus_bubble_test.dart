// SPDX-License-Identifier: GPL-3.0-or-later
// an opus note in its bubble: its length from the ogg, its wave from the
// engine, and a tap plays the ogg itself. a sent note that becomes opus
// while its bubble shows keeps its place and lets the wav go. the player
// is a stand-in over just_audio's channels
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart' show lockGuard;
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/voice_opus.dart';
import 'package:kryfo/widgets/media_bubbles.dart';
import 'package:kryfo/widgets/voice_parts.dart';

final _note = File('test/fixtures/voice/note.ogg').readAsBytesSync();

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

Uint8List _wav(int frames) {
  final b = ByteData(44 + frames * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + frames * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, 16000, Endian.little);
  b.setUint32(28, 32000, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, frames * 2, Endian.little);
  for (var i = 0; i < frames; i++) {
    b.setInt16(44 + i * 2, (i % 40 - 20) * 300, Endian.little);
  }
  return b.buffer.asUint8List();
}

const _wave = [0.2, 0.9, 0.5];

// the plugin's word that player [id] is ready to play
void _ready(String id) => TestDefaultBinaryMessengerBinding
    .instance
    .defaultBinaryMessenger
    .handlePlatformMessage(
      'com.ryanheise.just_audio.events.$id',
      const StandardMethodCodec().encodeSuccessEnvelope({
        'processingState': 3,
        'updateTime': 0,
        'updatePosition': 0,
        'bufferedPosition': 0,
        'duration': 3400000,
        'icyMetadata': null,
        'currentIndex': 0,
      }),
      (_) {},
    );

void main() {
  late Directory tmp;
  // what the players were asked, in order: 'load <uri>', 'play', ...
  late List<String> asked;
  final ids = <String>[];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('voice_opus_bubble');
    asked = [];
    lockState.openForTest();
    forgetVoicePeaks();
    setL10nLocale(const Locale('en'));
    voicePeaksForTest = (path, bars) => path.endsWith('.ogg')
        ? '{"ms":3400,"p":[${List.generate(bars, (i) => _wave[i % 3]).join(',')}]}'
        : 'error: not-opus';
    _mock('com.ryanheise.just_audio.methods', (c) async {
      if (c.method != 'init') return <String, Object?>{};
      final id = (c.arguments as Map)['id'] as String;
      ids.add(id);
      for (final kind in ['events', 'data']) {
        _mock('com.ryanheise.just_audio.$kind.$id', (_) async => null);
      }
      _mock('com.ryanheise.just_audio.methods.$id', (m) async {
        if (m.method == 'load') {
          // the player wraps one file in a list of one
          final src = (m.arguments as Map)['audioSource'] as Map;
          final one =
              src['uri'] ?? ((src['children'] as List).single as Map)['uri'];
          asked.add('load $one');
          // loaded: the player says it is ready, as the plugin does
          Future<void>.delayed(Duration.zero, () => _ready(id));
          return {'duration': 3400000};
        }
        asked.add(m.method);
        return <String, Object?>{};
      });
      return null;
    });
  });

  tearDown(() {
    voicePeaksForTest = null;
    _mock('com.ryanheise.just_audio.methods', null);
    // a player's streams close after its test: their channels stay
    for (final id in ids) {
      _mock('com.ryanheise.just_audio.methods.$id', null);
    }
    ids.clear();
    tmp.deleteSync(recursive: true);
  });

  Future<void> until(WidgetTester t, bool Function() done) async {
    final clock = Stopwatch()..start();
    while (!done() && clock.elapsed < const Duration(seconds: 20)) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  Widget app(String path, {bool out = false}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: VoiceBubble(
          key: const ValueKey('vb_u1'),
          path: path,
          isOut: out,
        ),
      ),
    ),
  );

  List<double>? shownWave(WidgetTester t) =>
      t.widget<VoiceWave>(find.byType(VoiceWave)).peaks;

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  for (final out in [false, true]) {
    final side = out ? 'sent' : 'received';
    testWidgets('$side: an opus note shows its length and wave, and plays', (
      t,
    ) async {
      final f = File('${tmp.path}/f_1_voice.ogg')..writeAsBytesSync(_note);
      await t.pumpWidget(app(f.path, out: out));
      await until(t, () => find.text('0:03').evaluate().isNotEmpty);
      expect(find.text('0:03'), findsOneWidget);
      // no player came up just to read the length
      expect(asked, isEmpty);
      await until(t, () => shownWave(t) != null);
      expect(shownWave(t), hasLength(kVoiceBars));
      expect(shownWave(t)!.take(3), _wave);
      await t.tap(find.byType(VoiceBubble));
      await until(t, () => asked.contains('play'));
      expect(
        asked.firstWhere((a) => a.startsWith('load ')),
        'load ${Uri.file(f.path)}',
      );
      expect(asked, contains('play'));
      expect(find.byIcon(Icons.music_off_rounded), findsNothing);
      await close(t);
    });
  }

  testWidgets('an ogg that is gone says so', (t) async {
    await t.pumpWidget(app('${tmp.path}/gone.ogg'));
    await until(
      t,
      () => find.byIcon(Icons.music_off_rounded).evaluate().isNotEmpty,
    );
    expect(find.text(l10n.mediaBubblesAudioUnavailable), findsOneWidget);
    await close(t);
  });

  testWidgets('a sent note that becomes opus keeps its bubble, and the wav '
      'goes once its player lets it go', (t) async {
    final wav = File('${tmp.path}/vn_u1.wav')..writeAsBytesSync(_wav(54400));
    final ogg = File('${tmp.path}/vn_u1.ogg')..writeAsBytesSync(_note);
    await t.pumpWidget(app(wav.path, out: true));
    await until(t, () => find.text('0:03').evaluate().isNotEmpty);
    final state = t.state(find.byType(VoiceBubble));
    // played as wav, the opus copy arrives under it
    await t.tap(find.byType(VoiceBubble));
    await until(t, () => asked.contains('play'));
    expect(
      asked.firstWhere((a) => a.startsWith('load ')),
      'load ${Uri.file(wav.path)}',
    );
    var free = false;
    unawaited(voiceFileFree(wav.path).then((_) => free = true));
    voicePeaksSame(wav.path, ogg.path);
    voiceLengthKnown(ogg.path, 3400);
    await t.pumpWidget(app(ogg.path, out: true));
    await t.pump();
    expect(t.state(find.byType(VoiceBubble)), same(state));
    // a tap on its button pauses it (one on the wave seeks): the wav is let
    // go, the next tap plays the ogg
    await t.tap(find.byIcon(Icons.pause_rounded));
    await until(t, () => free);
    expect(free, isTrue);
    asked.clear();
    await t.tap(find.byIcon(Icons.play_arrow_rounded));
    await until(t, () => asked.contains('play'));
    expect(
      asked.firstWhere((a) => a.startsWith('load ')),
      'load ${Uri.file(ogg.path)}',
    );
    await close(t);
  });

  testWidgets('a paused note lets its file go at the lock, and plays on '
      'from where it was after', (t) async {
    final f = File('${tmp.path}/f_2_voice.ogg')..writeAsBytesSync(_note);
    await t.pumpWidget(app(f.path));
    await until(t, () => find.text('0:03').evaluate().isNotEmpty);
    await t.tap(find.byType(VoiceBubble));
    await until(t, () => asked.contains('play'));
    await t.tap(find.byIcon(Icons.pause_rounded));
    await until(t, () => asked.contains('pause'));
    var free = false;
    unawaited(voiceFileFree(f.path).then((_) => free = true));
    await t.pump();
    expect(free, isFalse, reason: 'paused, the player still holds it');
    asked.clear();
    lockGuard.locking();
    await until(t, () => free);
    expect(free, isTrue);
    asked.clear();
    await t.tap(find.byType(VoiceBubble));
    await until(t, () => asked.contains('play'));
    expect(asked.where((a) => a.startsWith('load ')), hasLength(1));
    await close(t);
  });
}
