// SPDX-License-Identifier: GPL-3.0-or-later
// the clock while a note records starts with the mic's first samples, the
// note handed on is as long as its file, and a bubble shows that length to
// the nearest second, for a note from 0.5.0 too, which carries no length.
// the recorder is a stand-in over its channel
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/widgets/media_bubbles.dart';
import 'package:kryfo/widgets/voice_mic.dart';
import 'package:kryfo/widgets/voice_parts.dart' show VoiceRecordBar;

import 'dev_chat_fakes.dart';

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

const _rec = 'com.llfbandit.record/messages';

// [frames] of 16-bit mono at 16 khz. [sized] false leaves the lengths at
// zero, as a recorder that never finished its head does
Uint8List _wav(int frames, {bool sized = true}) {
  final b = ByteData(44 + frames * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, sized ? 36 + frames * 2 : 0, Endian.little);
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
  b.setUint32(40, sized ? frames * 2 : 0, Endian.little);
  for (var i = 0; i < frames; i++) {
    b.setInt16(44 + i * 2, (i % 40 - 20) * 200, Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  late Directory tmp;
  String? recording;
  late List<VoiceTake> sent;
  // what the recorder's file holds once it stops
  Uint8List? atStop;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('voice_length');
    recording = null;
    sent = [];
    atStop = null;
    lockState.openForTest();
    _mock('plugins.flutter.io/path_provider', (_) async => tmp.path);
    _mock(_rec, (c) async {
      switch (c.method) {
        case 'create':
          final id = (c.arguments as Map)['recorderId'];
          _mock('com.llfbandit.record/events/$id', (_) async => null);
        case 'hasPermission':
          return true;
        case 'start':
          // started, and no samples yet while the mic warms up
          recording = (c.arguments as Map)['path'] as String;
          File(recording!).writeAsBytesSync(const []);
          return null;
        case 'stop':
          final f = atStop;
          if (f != null) File(recording!).writeAsBytesSync(f);
          return recording;
      }
      return null;
    });
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock(_rec, null);
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

  Future<void> open(WidgetTester t) => devOpen(
    t,
    Scaffold(
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HoldToTalkMic(disguise: false, onSend: sent.add),
          ),
        ),
      ),
    ),
  );

  HoldToTalkMicState mic(WidgetTester t) =>
      t.state<HoldToTalkMicState>(find.byType(HoldToTalkMic));

  Future<TestGesture> hold(WidgetTester t) async {
    final g = await t.startGesture(t.getCenter(find.byType(HoldToTalkMic)));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await until(t, () => mic(t).stage == VoiceStage.holding);
    expect(mic(t).stage, VoiceStage.holding);
    return g;
  }

  Future<void> wait(WidgetTester t, int ms) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  String recordClock(WidgetTester t) =>
      t.widget<VoiceRecordBar>(find.byType(VoiceRecordBar)).time;

  // the recorder's dispose and the take's shred run out before the next test
  Future<void> close(WidgetTester t) async {
    await devClose(t);
    for (var i = 0; i < 20; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the clock waits for the first samples, not the press', (
    t,
  ) async {
    await open(t);
    final g = await hold(t);
    // the mic is still warming up
    await wait(t, 1500);
    expect(recordClock(t), '0:00');
    File(recording!).writeAsBytesSync(_wav(1600, sized: false));
    await wait(t, 1200);
    expect(recordClock(t), '0:01');
    await wait(t, 1000);
    expect(recordClock(t), '0:02');
    atStop = _wav(16000 * 2 + 3200);
    await g.up();
    await until(t, () => sent.isNotEmpty);
    expect(sent, hasLength(1));
    await close(t);
  });

  testWidgets('let go, the note handed on is as long as its file', (t) async {
    await open(t);
    final g = await hold(t);
    File(recording!).writeAsBytesSync(_wav(1600, sized: false));
    await wait(t, 1000);
    // the recorder wrote more than the clock saw
    atStop = _wav(37920);
    await g.up();
    await until(t, () => sent.isNotEmpty);
    expect(sent, hasLength(1));
    expect(sent.single.ms, 2370);
    await close(t);
  });

  testWidgets('stopped to be heard first, the preview and the note agree '
      'with the file', (t) async {
    await open(t);
    final g = await hold(t);
    File(recording!).writeAsBytesSync(_wav(1600, sized: false));
    await wait(t, 1000);
    await g.moveBy(const Offset(0, -50));
    await t.pump();
    await g.moveBy(const Offset(0, -50));
    await t.pump();
    await g.up();
    await t.pump();
    expect(mic(t).stage, VoiceStage.locked);
    atStop = _wav(41600);
    await t.tap(find.bySemanticsLabel(l10n.voiceStopRecording));
    await until(t, () => mic(t).stage == VoiceStage.preview);
    await until(
      t,
      () =>
          t.widget<VoiceLockedBar>(find.byType(VoiceLockedBar)).time == '0:03',
    );
    expect(t.widget<VoiceLockedBar>(find.byType(VoiceLockedBar)).time, '0:03');
    await t.tap(find.bySemanticsLabel(l10n.commonSend));
    await until(t, () => sent.isNotEmpty);
    expect(sent.single.ms, 2600);
    await close(t);
  });

  group('a bubble shows the note length to the nearest second', () {
    Future<void> bubble(WidgetTester t, Uint8List wav, bool out) async {
      final f = File('${tmp.path}/vn_${out ? 'out' : 'in'}.wav')
        ..writeAsBytesSync(wav);
      setL10nLocale(const Locale('en'));
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: VoiceBubble(path: f.path, isOut: out),
            ),
          ),
        ),
      );
    }

    Future<void> shows(WidgetTester t, String clock) async {
      await until(t, () => find.text(clock).evaluate().isNotEmpty);
      await t.pump(const Duration(seconds: 1));
      expect(find.text(clock), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }

    for (final out in [true, false]) {
      final side = out ? 'sent' : 'received';
      testWidgets('$side: 3.9 s is 0:04', (t) async {
        await bubble(t, _wav(62400), out);
        await shows(t, '0:04');
      });

      testWidgets('$side: 4.5 s is 0:05', (t) async {
        await bubble(t, _wav(72000), out);
        await shows(t, '0:05');
      });
    }

    testWidgets('a note from 0.5.0 carries no length: its file has it', (
      t,
    ) async {
      // what a 0.5.0 sender sends: the recorder's wav, nothing else
      await bubble(t, _wav(69120), false);
      await shows(t, '0:04');
    });

    testWidgets('a head never finished: the samples in the file', (t) async {
      await bubble(t, _wav(69120, sized: false), false);
      await shows(t, '0:04');
    });
  });
}
