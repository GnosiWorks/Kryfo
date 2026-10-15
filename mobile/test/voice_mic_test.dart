// SPDX-License-Identifier: GPL-3.0-or-later
// the mic as whatsapp has it: let go and the note goes, slide toward the
// start side and it is thrown away, slide up and it records hands free. a
// stopped note waits with a mask chip, and what goes is what the chip says.
// the mask sits on the mic while the chat disguises. a finger-sized target,
// still with less movement, mirrored in a right-to-left language, and whole
// on a small phone with large text. the recorder is a stand-in over its
// channel
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart' show lockGuard;
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/voice_length.dart' show kVoiceMax;
import 'package:kryfo/voice_mask.dart' show LiveMask;
import 'package:kryfo/widgets/voice_mic.dart';
import 'package:kryfo/widgets/voice_parts.dart' show VoiceRecordBar;

import 'dev_chat_fakes.dart';

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

const _rec = 'com.llfbandit.record/messages';

// a second and a half of a voiced tone, as the recorder writes it
Uint8List _wav() {
  const rate = 16000, n = 24000;
  final b = ByteData(44 + n * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    var v = 0.0;
    for (var h = 1; h <= 5; h++) {
      v += math.sin(2 * math.pi * 150 * h * i / rate) / h;
    }
    b.setInt16(44 + i * 2, (4000 * v).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

// the live disguise as the mic uses it, with what was asked of it
class _Spy implements LiveMask {
  _Spy(this.real, this.log);
  final LiveMask real;
  final List<String> log;
  // held shut, the finish waits for it
  Completer<void>? gate;
  Uint8List? made;

  @override
  Future<Uint8List?> finish() async {
    log.add('finish');
    await gate?.future;
    return made = await real.finish();
  }

  @override
  void cancel() {
    log.add('cancel');
    real.cancel();
  }

  @override
  Stream<int> get progress => real.progress;

  @override
  Future<void> get exited => real.exited;
}

void main() {
  late Directory tmp;
  late List<String> asked;
  String? recording;
  late List<VoiceTake> sent;
  late bool stopThrows;
  // what the mic asked of its live disguises
  final live = <String>[];
  final spies = <_Spy>[];

  void spyLive() {
    HoldToTalkMicState.startLive = (p) async {
      final m = await LiveMask.start(p);
      if (m == null) return null;
      final s = _Spy(m, live);
      spies.add(s);
      return s;
    };
  }

  // real file work and the disguise's isolate run outside the test's clock:
  // turns of real time and pumps until [done], however slow the machine
  Future<void> until(WidgetTester t, bool Function() done) async {
    final clock = Stopwatch()..start();
    while (!done() && clock.elapsed < const Duration(seconds: 20)) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  // the shred is done once the name is gone
  Future<void> shredded(WidgetTester t, String path) =>
      until(t, () => !File(path).existsSync());

  // every live disguise's isolate has ended. its exit lands in real time
  // but is only heard on a pump, so a wait inside runAsync can miss it
  Future<void> ended(WidgetTester t) async {
    var done = false;
    Future.wait([for (final s in spies) s.exited]).then((_) => done = true);
    await until(t, () => done);
    expect(done, isTrue, reason: 'a live disguise did not end');
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('voice_mic');
    asked = [];
    recording = null;
    sent = [];
    stopThrows = false;
    live.clear();
    spies.clear();
    lockState.openForTest();
    _mock('plugins.flutter.io/path_provider', (_) async => tmp.path);
    _mock(_rec, (c) async {
      asked.add(c.method);
      switch (c.method) {
        case 'create':
          final id = (c.arguments as Map)['recorderId'];
          _mock('com.llfbandit.record/events/$id', (_) async => null);
        case 'hasPermission':
          return true;
        case 'start':
          recording = (c.arguments as Map)['path'] as String;
          File(recording!).writeAsBytesSync(_wav());
          return null;
        case 'stop':
          if (stopThrows) throw PlatformException(code: 'stop');
          return recording;
      }
      return null;
    });
  });

  tearDown(() {
    HoldToTalkMicState.startLive = LiveMask.start;
    _mock('plugins.flutter.io/path_provider', null);
    _mock(_rec, null);
    tmp.deleteSync(recursive: true);
  });

  // the mic where a composer has it: the bottom end of the screen
  Future<void> open(
    WidgetTester t, {
    bool disguise = false,
    bool still = false,
    Locale locale = const Locale('en'),
    double scale = 1,
    Size size = const Size(1000, 1800),
  }) => devOpen(
    t,
    Scaffold(
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HoldToTalkMic(disguise: disguise, onSend: sent.add),
          ),
        ),
      ),
    ),
    still: still,
    locale: locale,
    scale: scale,
    size: size,
  );

  HoldToTalkMicState mic(WidgetTester t) =>
      t.state<HoldToTalkMicState>(find.byType(HoldToTalkMic));

  // a few turns for what has nothing to wait on
  Future<void> settle(WidgetTester t, {int turns = 20}) async {
    for (var i = 0; i < turns; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  // held long enough to record a second
  Future<TestGesture> hold(WidgetTester t) async {
    final g = await t.startGesture(t.getCenter(find.byType(HoldToTalkMic)));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await t.pump();
    await settle(t);
    expect(mic(t).stage, VoiceStage.holding);
    return g;
  }

  // a held note slid up, let go, and stopped: the preview
  Future<void> toPreview(WidgetTester t) async {
    final g = await hold(t);
    await g.moveBy(const Offset(0, -40));
    await t.pump();
    await g.moveBy(const Offset(0, -60));
    await t.pump();
    await g.up();
    await t.pump();
    expect(mic(t).stage, VoiceStage.locked);
    await t.tap(find.bySemanticsLabel(l10n.voiceStopRecording));
    await until(t, () => mic(t).stage == VoiceStage.preview);
    await settle(t, turns: 4);
    expect(find.byType(MaskChip), findsOneWidget);
  }

  Future<void> close(WidgetTester t) async {
    await devClose(t);
    await settle(t);
  }

  group('the longest note', () {
    tearDown(() => HoldToTalkMicState.maxLength = kVoiceMax);

    testWidgets('a held note stops by itself into the preview, and the lift '
        'keeps it', (t) async {
      HoldToTalkMicState.maxLength = const Duration(seconds: 2);
      await open(t);
      final g = await hold(t);
      await t.pump(const Duration(seconds: 3));
      await until(t, () => mic(t).stage == VoiceStage.preview);
      expect(find.text(l10n.voiceStoppedAtLimit), findsOneWidget);
      expect(asked, contains('stop'));
      await g.up();
      await settle(t, turns: 4);
      expect(mic(t).stage, VoiceStage.preview);
      await close(t);
    });

    testWidgets('a locked note stops by itself too', (t) async {
      HoldToTalkMicState.maxLength = const Duration(seconds: 2);
      await open(t);
      final g = await hold(t);
      await g.moveBy(const Offset(0, -40));
      await t.pump();
      await g.moveBy(const Offset(0, -60));
      await t.pump();
      await g.up();
      await t.pump();
      expect(mic(t).stage, VoiceStage.locked);
      await t.pump(const Duration(seconds: 3));
      await until(t, () => mic(t).stage == VoiceStage.preview);
      expect(find.text(l10n.voiceStoppedAtLimit), findsOneWidget);
      await close(t);
    });

    test('the mic stops at half an hour', () {
      expect(kVoiceMax, const Duration(minutes: 30));
      expect(HoldToTalkMicState.maxLength, kVoiceMax);
    });
  });

  group('the gestures', () {
    testWidgets('let go and the note goes', (t) async {
      await open(t);
      final g = await hold(t);
      expect(find.byType(VoiceRecordBar), findsOneWidget);
      await g.up();
      await settle(t);
      expect(sent, hasLength(1));
      expect(sent.single.path, recording);
      expect(sent.single.disguise, isFalse);
      expect(sent.single.ms, greaterThanOrEqualTo(400));
      // the take is the sender's now, still there to read
      expect(File(recording!).existsSync(), isTrue);
      expect(find.byType(VoiceRecordBar), findsNothing);
      await close(t);
    });

    testWidgets('slid toward the start it is thrown away', (t) async {
      await open(t);
      final g = await hold(t);
      await g.moveBy(const Offset(-60, 0));
      await t.pump();
      await g.moveBy(const Offset(-60, 0));
      await t.pump();
      expect(find.text(l10n.chatReleaseToCancel), findsOneWidget);
      await g.up();
      await shredded(t, recording!);
      expect(sent, isEmpty);
      expect(File(recording!).existsSync(), isFalse);
      await close(t);
    });

    testWidgets('slid up it locks and records with no finger on it', (t) async {
      await open(t);
      final g = await hold(t);
      expect(find.byType(VoiceLockPill), findsOneWidget);
      await g.moveBy(const Offset(0, -50));
      await t.pump();
      expect(mic(t).stage, VoiceStage.holding);
      await g.moveBy(const Offset(0, -50));
      await t.pump();
      expect(mic(t).stage, VoiceStage.locked);
      await g.up();
      await settle(t);
      // still recording, nothing sent
      expect(mic(t).stage, VoiceStage.locked);
      expect(asked, isNot(contains('stop')));
      expect(sent, isEmpty);
      expect(find.byType(VoiceLockedBar), findsOneWidget);
      // and the send on the bar sends it
      await t.tap(find.bySemanticsLabel(l10n.commonSend));
      await settle(t);
      expect(sent, hasLength(1));
      expect(sent.single.disguise, isFalse);
      expect(find.byType(VoiceLockedBar), findsNothing);
      await close(t);
    });

    testWidgets('locked, the bin throws it away', (t) async {
      await open(t);
      final g = await hold(t);
      await g.moveBy(const Offset(0, -100));
      await t.pump();
      await g.up();
      await t.pump();
      await t.tap(find.bySemanticsLabel(l10n.voiceDeleteNote));
      await shredded(t, recording!);
      expect(sent, isEmpty);
      expect(File(recording!).existsSync(), isFalse);
      await close(t);
    });

    testWidgets('right to left: slid right it is thrown away', (t) async {
      await open(t, locale: const Locale('ar'));
      var g = await hold(t);
      // left is away from the start side here: nothing happens
      await g.moveBy(const Offset(-120, 0));
      await t.pump();
      expect(mic(t).stage, VoiceStage.holding);
      await g.moveBy(const Offset(240, 0));
      await t.pump();
      await g.up();
      await shredded(t, recording!);
      expect(sent, isEmpty);
      expect(File(recording!).existsSync(), isFalse);
      // and up still locks, the lock over the mic
      g = await hold(t);
      final pill = t.getRect(find.byType(VoiceLockPill));
      final at = t.getRect(find.byType(HoldToTalkMic));
      expect(pill.center.dx, closeTo(at.center.dx, 1));
      expect(pill.bottom, lessThan(at.top));
      await g.moveBy(const Offset(0, -100));
      await t.pump();
      expect(mic(t).stage, VoiceStage.locked);
      await g.up();
      await t.tap(find.bySemanticsLabel(l10n.voiceDeleteNote));
      await settle(t);
      await close(t);
    });
  });

  group('the preview', () {
    testWidgets('the chip starts as the chat says and switches', (t) async {
      await open(t);
      await toPreview(t);
      expect(mic(t).chip, isFalse);
      expect(find.text(l10n.voiceYourVoice), findsOneWidget);
      await t.tap(find.byType(MaskChip));
      await t.pump(const Duration(milliseconds: 400));
      expect(mic(t).chip, isTrue);
      expect(find.text(l10n.voiceDisguised), findsOneWidget);
      await t.tap(find.byType(MaskChip));
      await t.pump(const Duration(milliseconds: 400));
      expect(mic(t).chip, isFalse);
      await t.tap(find.bySemanticsLabel(l10n.voiceDeleteNote));
      await settle(t);
      await close(t);
    });

    testWidgets('switched to disguised, the disguised take goes', (t) async {
      await open(t);
      await toPreview(t);
      await t.tap(find.byType(MaskChip));
      await until(t, () => mic(t).heard);
      expect(t.widget<MaskChip>(find.byType(MaskChip)).busy, isFalse);
      final raw = File(recording!).readAsBytesSync();
      // both takes are there to be heard
      final heard = tmp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_m.wav'))
          .toList();
      expect(heard, hasLength(1));
      await t.tap(find.bySemanticsLabel(l10n.commonSend));
      await settle(t);
      final take = sent.single;
      expect(take.disguise, isTrue);
      expect(take.path, recording);
      expect(take.masked, isNotNull);
      expect(take.masked!.length, raw.length);
      expect(take.masked, isNot(raw));
      // the disguised copy made for the preview is gone
      await shredded(t, heard.single.path);
      expect(
        tmp.listSync().whereType<File>().where(
          (f) => f.path.endsWith('_m.wav'),
        ),
        isEmpty,
      );
      await close(t);
    });

    testWidgets('a disguised chat switched to your voice sends it as it was', (
      t,
    ) async {
      await open(t, disguise: true);
      expect(t.widget<MicGlyph>(find.byType(MicGlyph)).disguise, isTrue);
      await toPreview(t);
      expect(mic(t).chip, isTrue);
      await t.tap(find.byType(MaskChip));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.bySemanticsLabel(l10n.commonSend));
      await settle(t);
      expect(sent.single.disguise, isFalse);
      expect(sent.single.masked, isNull);
      await close(t);
    });

    testWidgets('a disguised chat let go: the disguise made as it recorded '
        'goes', (t) async {
      await open(t, disguise: true);
      final g = await hold(t);
      await g.up();
      await until(t, () => sent.isNotEmpty);
      final raw = File(recording!).readAsBytesSync();
      final take = sent.single;
      expect(take.disguise, isTrue);
      expect(take.path, recording);
      expect(take.masked, isNotNull);
      expect(take.masked!.length, raw.length);
      expect(take.masked, isNot(raw));
      await close(t);
    });

    testWidgets('with no live disguise the take is disguised whole', (t) async {
      HoldToTalkMicState.startLive = (_) async => null;
      await open(t, disguise: true);
      final g = await hold(t);
      await g.up();
      await until(t, () => sent.isNotEmpty);
      // let go: the chat disguises it whole on the way out
      expect(sent.single.disguise, isTrue);
      expect(sent.single.masked, isNull);
      sent.clear();
      // locked: the preview makes it whole, and it is heard and sent
      await toPreview(t);
      await until(t, () => mic(t).heard);
      await t.tap(find.bySemanticsLabel(l10n.commonSend));
      await settle(t);
      final raw = File(recording!).readAsBytesSync();
      final masked = sent.single.masked!;
      expect(masked.length, raw.length);
      // a wav like the take, its samples not the take's
      expect(masked.sublist(0, 44), raw.sublist(0, 44));
      expect(masked.sublist(44), isNot(raw.sublist(44)));
      await close(t);
    });

    testWidgets(
      'a disguised chat locked: the live disguise is heard and goes',
      (t) async {
        spyLive();
        await open(t, disguise: true);
        await toPreview(t);
        await until(t, () => mic(t).heard);
        final raw = File(recording!).readAsBytesSync();
        await t.tap(find.bySemanticsLabel(l10n.commonSend));
        await settle(t);
        // finished once, and what it made is what goes
        expect(live, ['finish']);
        expect(sent.single.disguise, isTrue);
        expect(sent.single.masked, isNotNull);
        expect(sent.single.masked, spies.single.made);
        expect(sent.single.masked, isNot(raw));
        await ended(t);
        await close(t);
      },
    );

    testWidgets('slid toward the start: the live disguise ends', (t) async {
      spyLive();
      await open(t, disguise: true);
      final g = await hold(t);
      await g.moveBy(const Offset(-60, 0));
      await t.pump();
      await g.moveBy(const Offset(-60, 0));
      await t.pump();
      await g.up();
      // the take is shredded before the live disguise is ended
      await until(t, () => live.isNotEmpty);
      expect(sent, isEmpty);
      expect(live, ['cancel']);
      await ended(t);
      await close(t);
    });

    testWidgets('let go under 400 ms: the live disguise ends', (t) async {
      spyLive();
      await open(t, disguise: true);
      final g = await t.startGesture(t.getCenter(find.byType(HoldToTalkMic)));
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await settle(t, turns: 2);
      expect(mic(t).stage, VoiceStage.holding);
      await g.up();
      // the take is shredded before the live disguise is ended
      await until(t, () => live.isNotEmpty);
      expect(sent, isEmpty);
      expect(live, ['cancel']);
      await ended(t);
      await close(t);
    });

    testWidgets('the app lock: the note and its live disguise end', (t) async {
      spyLive();
      await open(t, disguise: true);
      final g = await hold(t);
      lockGuard.locking();
      await until(t, () => live.isNotEmpty);
      expect(live, ['cancel']);
      expect(File(recording!).existsSync(), isFalse);
      await g.up();
      await settle(t);
      expect(sent, isEmpty);
      await ended(t);
      await close(t);
    });

    testWidgets('the chat closing while it records ends the live disguise', (
      t,
    ) async {
      spyLive();
      await open(t, disguise: true);
      await hold(t);
      await close(t);
      expect(live, ['cancel']);
      await ended(t);
    });

    testWidgets('the chat closing while the disguise is finished: the take is '
        'shredded and nothing goes', (t) async {
      spyLive();
      await open(t, disguise: true);
      final g = await hold(t);
      // the isolate starts in real time
      await until(t, () => spies.isNotEmpty);
      spies.single.gate = Completer<void>();
      await g.up();
      await until(t, () => live.isNotEmpty);
      expect(live, ['finish']);
      await close(t);
      expect(File(recording!).existsSync(), isTrue);
      spies.single.gate!.complete();
      // the shred is the last the mic does with it
      await shredded(t, recording!);
      expect(sent, isEmpty);
      expect(File(recording!).existsSync(), isFalse);
      await ended(t);
    });

    testWidgets('a recorder that will not stop: the live disguise ends', (
      t,
    ) async {
      spyLive();
      await open(t, disguise: true);
      final g = await hold(t);
      stopThrows = true;
      await g.up();
      // the take is shredded before the live disguise is ended
      await until(t, () => live.isNotEmpty);
      expect(sent, isEmpty);
      expect(live, ['cancel']);
      expect(File(recording!).existsSync(), isFalse);
      await ended(t);
      // the next note starts clean
      stopThrows = false;
      final again = await hold(t);
      await again.up();
      await until(t, () => sent.isNotEmpty);
      expect(live, ['cancel', 'finish']);
      expect(sent.single.masked, spies.last.made);
      await ended(t);
      await close(t);
    });

    testWidgets('thrown away, both takes are shredded', (t) async {
      await open(t);
      await toPreview(t);
      await t.tap(find.byType(MaskChip));
      await until(t, () => mic(t).heard);
      final takes = tmp.listSync().whereType<File>().toList();
      expect(takes, hasLength(2));
      await t.tap(find.bySemanticsLabel(l10n.voiceDeleteNote));
      for (final f in takes) {
        await shredded(t, f.path);
      }
      expect(sent, isEmpty);
      expect(tmp.listSync().whereType<File>(), isEmpty);
      await close(t);
    });
  });

  group('the look', () {
    testWidgets('the mic takes a 48 square tap, clear of the edge', (t) async {
      await open(t);
      final box = t.getRect(find.byType(HoldToTalkMic));
      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));
      // the icon sits in the middle, well in from the screen's edge
      final icon = t.getRect(find.byIcon(Icons.mic_none_rounded));
      expect(icon.center.dx, closeTo(box.center.dx, 0.5));
      expect(500 - icon.right, greaterThanOrEqualTo(24));
      await close(t);
    });

    testWidgets('the mask pops onto the mic, and with less movement it only '
        'fades', (t) async {
      Widget glyph(bool on, bool still) => devApp(
        Center(child: MicGlyph(disguise: on)),
        still: still,
      );
      await t.pumpWidget(glyph(false, false));
      await t.pumpWidget(glyph(true, false));
      await t.pump(const Duration(milliseconds: 60));
      final scale = t.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1);
      expect(scale.duration, greaterThan(Duration.zero));
      await t.pumpAndSettle();
      await t.pumpWidget(glyph(false, true));
      await t.pumpWidget(glyph(true, true));
      final still = t.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(still.duration, Duration.zero);
      await t.pumpAndSettle();
    });

    testWidgets('less movement: the lock does not bob or rise', (t) async {
      await open(t, still: true);
      final g = await hold(t);
      expect(find.byType(VoiceLockPill), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(VoiceLockPill),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      await g.up();
      await settle(t);
      await close(t);
    });

    testWidgets('a small phone with large text: the bar fits, the chip is '
        'the mask alone', (t) async {
      await open(t, scale: 1.5, size: const Size(720, 1280));
      await toPreview(t);
      expect(t.takeException(), isNull);
      expect(find.text(l10n.voiceYourVoice), findsNothing);
      expect(find.byIcon(Icons.theater_comedy_outlined), findsOneWidget);
      for (final label in [l10n.voiceDeleteNote, l10n.commonSend]) {
        final r = t.getRect(find.bySemanticsLabel(label));
        expect(r.width, greaterThanOrEqualTo(48), reason: label);
        expect(r.height, greaterThanOrEqualTo(48), reason: label);
      }
      final chip = t.getRect(find.byType(MaskChip));
      expect(chip.width, greaterThanOrEqualTo(48));
      expect(chip.height, greaterThanOrEqualTo(48));
      final bar = t.getRect(find.byType(VoiceLockedBar));
      expect(bar.width, 360);
      await t.tap(find.bySemanticsLabel(l10n.voiceDeleteNote));
      await settle(t);
      await close(t);
    });
  });
}
