// SPDX-License-Identifier: GPL-3.0-or-later
// voice notes: a speed pill on received notes only, kept per identity;
// dragging along the wave seeks, ltr and rtl; the next note plays on
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_audio.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/voice_speed.dart';
import 'package:kryfo/widgets/media_bubbles.dart';
import 'package:kryfo/widgets/voice_parts.dart';

class _Pipe implements AudioPipe {
  _Pipe(this.all) {
    all.add(this);
  }
  final List<_Pipe> all;
  bool playing = false;
  bool atEnd = false;
  Duration at = Duration.zero;
  final calls = <String>[];

  @override
  Future<Duration?> load(String path) async {
    calls.add('load');
    return const Duration(seconds: 4);
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
  void volume(double v) {}

  @override
  Duration position() => at;

  @override
  bool ended() {
    final e = atEnd;
    atEnd = false;
    return e;
  }

  @override
  String? failed() => null;

  @override
  void dispose() => calls.add('dispose');
}

// four seconds of silence, 8 kHz 16-bit mono
Uint8List _wav() {
  const n = 8000 * 4;
  final b = ByteData(44 + n * 2);
  void s(int at, String t) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, t.codeUnitAt(i));
    }
  }

  s(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  s(8, 'WAVE');
  s(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, 8000, Endian.little);
  b.setUint32(28, 16000, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  s(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  return b.buffer.asUint8List();
}

Widget _app(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  late Directory dir;
  late List<_Pipe> pipes;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('voice_speed');
    pipes = [];
    JustAudioPlatform.instance = DesktopAudio(pipe: () => _Pipe(pipes));
    FlutterSecureStorage.setMockInitialValues({});
    VoiceSpeed.reset();
    lockState.openForTest();
    setL10nLocale(const Locale('en'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  String note(String name) =>
      (File('${dir.path}/$name.wav')..writeAsBytesSync(_wav())).path;

  Future<void> until(WidgetTester t, bool Function() done) async {
    final clock = Stopwatch()..start();
    while (!done() && clock.elapsed < const Duration(seconds: 10)) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> known(WidgetTester t) =>
      until(t, () => find.text('0:04').evaluate().isNotEmpty);

  Future<void> gone(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await settle(t);
    // a load's retry wait runs out
    await t.pump(const Duration(seconds: 1));
  }

  test('the steps go 1x, 1.5x, 2x and round again', () {
    expect(nextVoiceSpeed(1.0), 1.5);
    expect(nextVoiceSpeed(1.5), 2.0);
    expect(nextVoiceSpeed(2.0), 1.0);
    expect(nextVoiceSpeed(3.0), 1.0);
  });

  test('the speed is kept per identity: the decoy keeps its own', () async {
    await VoiceSpeed.use(HaloContainer.everyday);
    await VoiceSpeed.set(2.0);
    await VoiceSpeed.use(HaloContainer.decoy);
    expect(VoiceSpeed.now.value, 1.0);
    await VoiceSpeed.set(1.5);
    // read back from storage, as after a restart
    VoiceSpeed.reset(storage: const FlutterSecureStorage());
    await VoiceSpeed.use(HaloContainer.everyday);
    expect(VoiceSpeed.now.value, 2.0);
    await VoiceSpeed.use(HaloContainer.decoy);
    expect(VoiceSpeed.now.value, 1.5);
    // a vault plays at its identity's speed
    await VoiceSpeed.use(HaloContainer.vault);
    expect(VoiceSpeed.now.value, 2.0);
  });

  test('a point on the wave maps to its share, mirrored in rtl', () {
    expect(waveFraction(25, 100, rtl: false), 0.25);
    expect(waveFraction(25, 100, rtl: true), 0.75);
    expect(waveFraction(-5, 100, rtl: false), 0);
    expect(waveFraction(500, 100, rtl: true), 0);
  });

  testWidgets('a received note shows the pill once it plays; a tap steps '
      'and the player follows', (t) async {
    await VoiceSpeed.use(HaloContainer.everyday);
    final path = note('in');
    await t.pumpWidget(_app(VoiceBubble(path: path, isOut: false)));
    await known(t);
    final pill = find.byKey(const ValueKey('voice_speed'));
    // there, but hidden and deaf until the note plays
    expect(
      t.widget<GestureDetector>(pill).onTap,
      isNull,
      reason: 'not tappable before it plays',
    );
    await t.tap(find.byIcon(Icons.play_arrow_rounded));
    await until(t, () => pipes.isNotEmpty && pipes.single.playing);
    expect(pipes.single.playing, isTrue);
    expect(find.text('1x'), findsOneWidget);
    await t.tap(pill);
    await settle(t);
    expect(VoiceSpeed.now.value, 1.5);
    expect(find.text('1.5x'), findsOneWidget);
    final st = t.state<VoiceBubbleState>(find.byType(VoiceBubble));
    expect(st.speed, 1.5);
    await t.tap(pill);
    await settle(t);
    expect(st.speed, 2.0);
    await gone(t);
  });

  testWidgets('own notes never show the pill and play at their own speed', (
    t,
  ) async {
    await VoiceSpeed.use(HaloContainer.everyday);
    await VoiceSpeed.set(2.0);
    final path = note('out');
    await t.pumpWidget(_app(VoiceBubble(path: path, isOut: true)));
    await known(t);
    await t.tap(find.byIcon(Icons.play_arrow_rounded));
    await until(t, () => pipes.isNotEmpty && pipes.single.playing);
    expect(find.byKey(const ValueKey('voice_speed')), findsNothing);
    expect(t.state<VoiceBubbleState>(find.byType(VoiceBubble)).speed, 1.0);
    await gone(t);
  });

  for (final dir in TextDirection.values) {
    testWidgets('a drag along the wave seeks ($dir)', (t) async {
      final path = note('drag');
      await t.pumpWidget(_app(VoiceBubble(path: path, isOut: true), dir: dir));
      await known(t);
      await t.tap(find.byIcon(Icons.play_arrow_rounded));
      await until(t, () => pipes.isNotEmpty && pipes.single.playing);
      final wave = find.byKey(const ValueKey('voice_wave'));
      final box = t.getRect(wave);
      // from a quarter in on the left to the middle
      final g = await t.startGesture(
        Offset(box.left + box.width / 4, box.center.dy),
      );
      await g.moveBy(const Offset(20, 0));
      await g.moveTo(Offset(box.left + box.width / 4, box.center.dy));
      await t.pump();
      await g.up();
      await until(
        t,
        () => pipes.single.calls.where((c) => c.startsWith('seek')).isNotEmpty,
      );
      // a quarter from the left is a quarter in, or three in rtl
      final want = dir == TextDirection.ltr ? 1000 : 3000;
      final seek = pipes.single.calls.lastWhere((c) => c.startsWith('seek'));
      final ms = int.parse(seek.split(' ').last);
      expect((ms - want).abs(), lessThan(150), reason: seek);
      await gone(t);
    });
  }

  testWidgets('a tap on the wave of a note not yet played plays it', (t) async {
    final path = note('tap');
    await t.pumpWidget(_app(VoiceBubble(path: path, isOut: false)));
    await known(t);
    await t.tap(find.byKey(const ValueKey('voice_wave')));
    await until(t, () => pipes.isNotEmpty && pipes.single.playing);
    expect(pipes.single.playing, isTrue);
    await gone(t);
  });

  testWidgets('a screen reader seeks with swipes and steps the speed', (
    t,
  ) async {
    final sem = t.ensureSemantics();
    final path = note('sem');
    await t.pumpWidget(_app(VoiceBubble(path: path, isOut: false)));
    await known(t);
    final node = t.getSemantics(find.byType(VoiceBubble));
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    expect(
      node.getSemanticsData().increasedValue,
      l10n.voiceSeekValue('0:04', '0:04'),
    );
    await t.tap(find.byIcon(Icons.play_arrow_rounded));
    await until(t, () => pipes.isNotEmpty && pipes.single.playing);
    expect(
      t
          .getSemantics(find.byType(VoiceBubble))
          .getSemanticsData()
          .customSemanticsActionIds,
      isNotEmpty,
    );
    await gone(t);
    sem.dispose();
  });

  testWidgets('the next note plays on when one ends', (t) async {
    final a = note('a');
    final b = note('b');
    await t.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VoiceBubble(path: a, isOut: false, playKey: 'a', next: () => 'b'),
            VoiceBubble(path: b, isOut: false, playKey: 'b', next: () => null),
          ],
        ),
      ),
    );
    await until(t, () => find.text('0:04').evaluate().length == 2);
    await t.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await until(t, () => pipes.any((p) => p.playing));
    expect(pipes.where((p) => p.playing), hasLength(1));
    final first = pipes.singleWhere((p) => p.playing);
    first.atEnd = true;
    await until(t, () => pipes.any((p) => p.playing && !identical(p, first)));
    expect(first.playing, isFalse);
    final playing = pipes.where((p) => p.playing).toList();
    expect(playing, hasLength(1));
    expect(identical(playing.single, first), isFalse);
    await gone(t);
  });
}
